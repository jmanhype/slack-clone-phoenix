import { RateLimitInfo, ImportError } from '../types';
import { createLogger } from '../utils/logger';

const logger = createLogger('RateLimiter');

export class RateLimiter {
  private requests: number = 0;
  private windowStart: number = Date.now();
  private queue: Array<() => void> = [];
  private processing: boolean = false;

  constructor(
    private readonly maxRequests: number = 3,
    private readonly windowMs: number = 1000,
    private readonly maxRetries: number = 3
  ) {}

  /**
   * Executes a function with rate limiting and retry logic
   */
  async execute<T>(fn: () => Promise<T>, context?: string): Promise<T> {
    return new Promise((resolve, reject) => {
      this.queue.push(async () => {
        try {
          const result = await this.executeWithRetry(fn, this.maxRetries, context);
          resolve(result);
        } catch (error) {
          reject(error);
        }
      });

      this.processQueue();
    });
  }

  /**
   * Executes function with exponential backoff retry logic
   */
  private async executeWithRetry<T>(
    fn: () => Promise<T>,
    retriesLeft: number,
    context?: string
  ): Promise<T> {
    try {
      await this.waitForRateLimit();
      this.incrementRequestCount();
      
      const result = await fn();
      logger.debug(`Request successful${context ? ` (${context})` : ''}`);
      return result;
    } catch (error: any) {
      if (retriesLeft > 0 && this.isRetryableError(error)) {
        const delay = this.calculateBackoffDelay(this.maxRetries - retriesLeft);
        logger.warn(`Request failed, retrying in ${delay}ms. Retries left: ${retriesLeft}${context ? ` (${context})` : ''}`, { error: error.message });
        
        await this.delay(delay);
        return this.executeWithRetry(fn, retriesLeft - 1, context);
      }

      logger.error(`Request failed after all retries${context ? ` (${context})` : ''}`, { error: error.message });
      throw this.createImportError(error, context);
    }
  }

  /**
   * Waits until rate limit allows for next request
   */
  private async waitForRateLimit(): Promise<void> {
    const now = Date.now();
    
    // Reset window if enough time has passed
    if (now - this.windowStart >= this.windowMs) {
      this.requests = 0;
      this.windowStart = now;
      return;
    }

    // If we've hit the limit, wait for window to reset
    if (this.requests >= this.maxRequests) {
      const waitTime = this.windowMs - (now - this.windowStart);
      logger.debug(`Rate limit reached, waiting ${waitTime}ms`);
      await this.delay(waitTime);
      this.requests = 0;
      this.windowStart = Date.now();
    }
  }

  /**
   * Processes the request queue sequentially
   */
  private async processQueue(): Promise<void> {
    if (this.processing || this.queue.length === 0) {
      return;
    }

    this.processing = true;

    while (this.queue.length > 0) {
      const request = this.queue.shift();
      if (request) {
        await request();
      }
    }

    this.processing = false;
  }

  /**
   * Increments the request count
   */
  private incrementRequestCount(): void {
    this.requests++;
  }

  /**
   * Calculates exponential backoff delay
   */
  private calculateBackoffDelay(attempt: number): number {
    const baseDelay = 1000; // 1 second
    const maxDelay = 60000; // 60 seconds
    const delay = Math.min(baseDelay * Math.pow(2, attempt), maxDelay);
    
    // Add jitter to prevent thundering herd
    const jitter = Math.random() * 0.1 * delay;
    return Math.floor(delay + jitter);
  }

  /**
   * Determines if an error is retryable
   */
  private isRetryableError(error: any): boolean {
    // Network errors
    if (error.code === 'ECONNRESET' || error.code === 'ETIMEDOUT') {
      return true;
    }

    // HTTP status codes that are retryable
    if (error.response?.status) {
      const status = error.response.status;
      return status === 429 || status >= 500;
    }

    // Notion API specific errors
    if (error.code === 'rate_limited' || error.code === 'service_unavailable') {
      return true;
    }

    return false;
  }

  /**
   * Creates a standardized ImportError from various error types
   */
  private createImportError(error: any, context?: string): ImportError {
    let type: ImportError['type'] = 'NETWORK';
    let message = error.message || 'Unknown error';

    if (error.response?.status === 429 || error.code === 'rate_limited') {
      type = 'RATE_LIMIT';
      message = 'Rate limit exceeded';
    } else if (error.response?.status === 401 || error.code === 'unauthorized') {
      type = 'AUTHENTICATION';
      message = 'Authentication failed';
    } else if (error.response?.status >= 500) {
      type = 'NETWORK';
      message = 'Server error';
    }

    return {
      type,
      message: context ? `${context}: ${message}` : message,
      timestamp: new Date(),
      retryable: this.isRetryableError(error)
    };
  }

  /**
   * Promise-based delay utility
   */
  private delay(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  /**
   * Gets current rate limit information
   */
  getRateLimitInfo(): RateLimitInfo {
    return {
      requests: this.requests,
      windowStart: this.windowStart,
      resetTime: this.windowStart + this.windowMs
    };
  }

  /**
   * Resets the rate limiter state
   */
  reset(): void {
    this.requests = 0;
    this.windowStart = Date.now();
    this.queue = [];
    this.processing = false;
    logger.debug('Rate limiter reset');
  }

  /**
   * Gets the current queue length
   */
  getQueueLength(): number {
    return this.queue.length;
  }
}