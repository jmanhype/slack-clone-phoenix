"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.RateLimiter = void 0;
const logger_1 = require("../utils/logger");
const logger = (0, logger_1.createLogger)('RateLimiter');
class RateLimiter {
    constructor(maxRequests = 3, windowMs = 1000, maxRetries = 3) {
        this.maxRequests = maxRequests;
        this.windowMs = windowMs;
        this.maxRetries = maxRetries;
        this.requests = 0;
        this.windowStart = Date.now();
        this.queue = [];
        this.processing = false;
    }
    /**
     * Executes a function with rate limiting and retry logic
     */
    async execute(fn, context) {
        return new Promise((resolve, reject) => {
            this.queue.push(async () => {
                try {
                    const result = await this.executeWithRetry(fn, this.maxRetries, context);
                    resolve(result);
                }
                catch (error) {
                    reject(error);
                }
            });
            this.processQueue();
        });
    }
    /**
     * Executes function with exponential backoff retry logic
     */
    async executeWithRetry(fn, retriesLeft, context) {
        try {
            await this.waitForRateLimit();
            this.incrementRequestCount();
            const result = await fn();
            logger.debug(`Request successful${context ? ` (${context})` : ''}`);
            return result;
        }
        catch (error) {
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
    async waitForRateLimit() {
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
    async processQueue() {
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
    incrementRequestCount() {
        this.requests++;
    }
    /**
     * Calculates exponential backoff delay
     */
    calculateBackoffDelay(attempt) {
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
    isRetryableError(error) {
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
    createImportError(error, context) {
        let type = 'NETWORK';
        let message = error.message || 'Unknown error';
        if (error.response?.status === 429 || error.code === 'rate_limited') {
            type = 'RATE_LIMIT';
            message = 'Rate limit exceeded';
        }
        else if (error.response?.status === 401 || error.code === 'unauthorized') {
            type = 'AUTHENTICATION';
            message = 'Authentication failed';
        }
        else if (error.response?.status >= 500) {
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
    delay(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }
    /**
     * Gets current rate limit information
     */
    getRateLimitInfo() {
        return {
            requests: this.requests,
            windowStart: this.windowStart,
            resetTime: this.windowStart + this.windowMs
        };
    }
    /**
     * Resets the rate limiter state
     */
    reset() {
        this.requests = 0;
        this.windowStart = Date.now();
        this.queue = [];
        this.processing = false;
        logger.debug('Rate limiter reset');
    }
    /**
     * Gets the current queue length
     */
    getQueueLength() {
        return this.queue.length;
    }
}
exports.RateLimiter = RateLimiter;
//# sourceMappingURL=RateLimiter.js.map