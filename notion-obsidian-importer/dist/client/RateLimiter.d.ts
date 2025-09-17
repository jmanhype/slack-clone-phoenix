import { RateLimitInfo } from '../types';
export declare class RateLimiter {
    private readonly maxRequests;
    private readonly windowMs;
    private readonly maxRetries;
    private requests;
    private windowStart;
    private queue;
    private processing;
    constructor(maxRequests?: number, windowMs?: number, maxRetries?: number);
    /**
     * Executes a function with rate limiting and retry logic
     */
    execute<T>(fn: () => Promise<T>, context?: string): Promise<T>;
    /**
     * Executes function with exponential backoff retry logic
     */
    private executeWithRetry;
    /**
     * Waits until rate limit allows for next request
     */
    private waitForRateLimit;
    /**
     * Processes the request queue sequentially
     */
    private processQueue;
    /**
     * Increments the request count
     */
    private incrementRequestCount;
    /**
     * Calculates exponential backoff delay
     */
    private calculateBackoffDelay;
    /**
     * Determines if an error is retryable
     */
    private isRetryableError;
    /**
     * Creates a standardized ImportError from various error types
     */
    private createImportError;
    /**
     * Promise-based delay utility
     */
    private delay;
    /**
     * Gets current rate limit information
     */
    getRateLimitInfo(): RateLimitInfo;
    /**
     * Resets the rate limiter state
     */
    reset(): void;
    /**
     * Gets the current queue length
     */
    getQueueLength(): number;
}
//# sourceMappingURL=RateLimiter.d.ts.map