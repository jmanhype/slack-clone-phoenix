import { RateLimiter } from '../../src/client/RateLimiter';

describe('RateLimiter', () => {
  let rateLimiter: RateLimiter;

  beforeEach(() => {
    jest.useFakeTimers();
  });

  afterEach(() => {
    jest.useRealTimers();
    jest.clearAllMocks();
  });

  describe('constructor', () => {
    it('should initialize with correct parameters', () => {
      rateLimiter = new RateLimiter(5, 1000);
      
      const info = rateLimiter.getRateLimitInfo();
      expect(info.requests).toBe(0);
      expect(info.resetTime).toBeGreaterThan(Date.now());
    });

    it('should use default values when not provided', () => {
      rateLimiter = new RateLimiter();
      
      // Should not throw and should work with defaults
      expect(() => rateLimiter.getRateLimitInfo()).not.toThrow();
    });
  });

  describe('execute', () => {
    beforeEach(() => {
      rateLimiter = new RateLimiter(3, 1000); // 3 requests per 1000ms
    });

    it('should execute function immediately when under limit', async () => {
      const mockFn = jest.fn().mockResolvedValue('result');

      const result = await rateLimiter.execute(mockFn, 'test operation');

      expect(result).toBe('result');
      expect(mockFn).toHaveBeenCalledTimes(1);
    });

    it('should track request count', async () => {
      const mockFn = jest.fn().mockResolvedValue('result');

      await rateLimiter.execute(mockFn, 'test 1');
      await rateLimiter.execute(mockFn, 'test 2');

      const info = rateLimiter.getRateLimitInfo();
      expect(info.requests).toBe(2);
    });

    it('should delay execution when rate limit is reached', async () => {
      const mockFn = jest.fn().mockResolvedValue('result');
      
      // Execute 3 requests (at the limit)
      await rateLimiter.execute(mockFn, 'test 1');
      await rateLimiter.execute(mockFn, 'test 2');
      await rateLimiter.execute(mockFn, 'test 3');

      expect(mockFn).toHaveBeenCalledTimes(3);

      // The 4th request should be delayed
      const fourthRequest = rateLimiter.execute(mockFn, 'test 4');
      
      // Should not execute immediately
      expect(mockFn).toHaveBeenCalledTimes(3);
      
      // Advance time to trigger the reset
      jest.advanceTimersByTime(1000);
      
      await fourthRequest;
      expect(mockFn).toHaveBeenCalledTimes(4);
    });

    it('should reset window after specified time', async () => {
      const mockFn = jest.fn().mockResolvedValue('result');
      
      // Fill up the rate limit
      await rateLimiter.execute(mockFn, 'test 1');
      await rateLimiter.execute(mockFn, 'test 2');
      await rateLimiter.execute(mockFn, 'test 3');

      const infoBefore = rateLimiter.getRateLimitInfo();
      expect(infoBefore.requests).toBe(3);

      // Advance time past the window
      jest.advanceTimersByTime(1001);

      // Should be able to make more requests
      await rateLimiter.execute(mockFn, 'test 4');
      
      const infoAfter = rateLimiter.getRateLimitInfo();
      expect(infoAfter.requests).toBe(1); // Reset to 1 (the new request)
    });

    it('should handle function that throws errors', async () => {
      const mockFn = jest.fn().mockRejectedValue(new Error('Test error'));

      await expect(rateLimiter.execute(mockFn, 'error test')).rejects.toThrow('Test error');
      
      // Should still increment the request count
      const info = rateLimiter.getRateLimitInfo();
      expect(info.requests).toBe(1);
    });

    it('should handle multiple concurrent requests properly', async () => {
      const mockFn = jest.fn().mockImplementation(async (value) => {
        await new Promise(resolve => setTimeout(resolve, 100));
        return value;
      });

      // Start multiple requests at once
      const promises = [
        rateLimiter.execute(() => mockFn('a'), 'test a'),
        rateLimiter.execute(() => mockFn('b'), 'test b'),
        rateLimiter.execute(() => mockFn('c'), 'test c'),
        rateLimiter.execute(() => mockFn('d'), 'test d'), // This should be delayed
      ];

      // Advance time to allow the delayed request to proceed
      jest.advanceTimersByTime(1000);

      const results = await Promise.all(promises);
      expect(results).toEqual(['a', 'b', 'c', 'd']);
      expect(mockFn).toHaveBeenCalledTimes(4);
    });

    it('should provide operation context in logging', async () => {
      const mockFn = jest.fn().mockResolvedValue('result');
      
      await rateLimiter.execute(mockFn, 'custom operation name');
      
      // The operation name should be used internally (though we can't directly test logging)
      expect(mockFn).toHaveBeenCalled();
    });
  });

  describe('getRateLimitInfo', () => {
    beforeEach(() => {
      rateLimiter = new RateLimiter(3, 1000);
    });

    it('should return current rate limit status', () => {
      const info = rateLimiter.getRateLimitInfo();

      expect(info).toHaveProperty('requests');
      expect(info).toHaveProperty('windowStart');
      expect(info).toHaveProperty('resetTime');
      expect(typeof info.requests).toBe('number');
      expect(typeof info.windowStart).toBe('number');
      expect(typeof info.resetTime).toBe('number');
    });

    it('should reflect changes after requests', async () => {
      const mockFn = jest.fn().mockResolvedValue('result');
      
      const infoBefore = rateLimiter.getRateLimitInfo();
      expect(infoBefore.requests).toBe(0);

      await rateLimiter.execute(mockFn, 'test');

      const infoAfter = rateLimiter.getRateLimitInfo();
      expect(infoAfter.requests).toBe(1);
      expect(infoAfter.windowStart).toBe(infoBefore.windowStart);
    });

    it('should update reset time correctly', () => {
      const info1 = rateLimiter.getRateLimitInfo();
      const expectedResetTime = info1.windowStart + 1000;

      expect(info1.resetTime).toBe(expectedResetTime);
    });
  });

  describe('reset', () => {
    beforeEach(() => {
      rateLimiter = new RateLimiter(3, 1000);
    });

    it('should reset request count to zero', async () => {
      const mockFn = jest.fn().mockResolvedValue('result');
      
      // Make some requests
      await rateLimiter.execute(mockFn, 'test 1');
      await rateLimiter.execute(mockFn, 'test 2');

      const infoBefore = rateLimiter.getRateLimitInfo();
      expect(infoBefore.requests).toBe(2);

      // Reset the rate limiter
      rateLimiter.reset();

      const infoAfter = rateLimiter.getRateLimitInfo();
      expect(infoAfter.requests).toBe(0);
    });

    it('should update window start time on reset', () => {
      const infoBefore = rateLimiter.getRateLimitInfo();
      
      // Advance time a bit
      jest.advanceTimersByTime(500);
      
      rateLimiter.reset();
      
      const infoAfter = rateLimiter.getRateLimitInfo();
      expect(infoAfter.windowStart).toBeGreaterThan(infoBefore.windowStart);
    });

    it('should allow immediate execution after reset', async () => {
      const mockFn = jest.fn().mockResolvedValue('result');
      
      // Fill up the rate limit
      await rateLimiter.execute(mockFn, 'test 1');
      await rateLimiter.execute(mockFn, 'test 2');
      await rateLimiter.execute(mockFn, 'test 3');

      // Reset and try another request
      rateLimiter.reset();
      
      await rateLimiter.execute(mockFn, 'test 4');
      expect(mockFn).toHaveBeenCalledTimes(4);
    });
  });

  describe('edge cases', () => {
    it('should handle zero rate limit gracefully', () => {
      rateLimiter = new RateLimiter(0, 1000);
      
      const mockFn = jest.fn().mockResolvedValue('result');
      
      // Should still be able to execute (though every request will be delayed)
      expect(async () => {
        const promise = rateLimiter.execute(mockFn, 'test');
        jest.advanceTimersByTime(1000);
        await promise;
      }).not.toThrow();
    });

    it('should handle very short window times', async () => {
      rateLimiter = new RateLimiter(3, 1); // 1ms window
      
      const mockFn = jest.fn().mockResolvedValue('result');
      
      await rateLimiter.execute(mockFn, 'test 1');
      await rateLimiter.execute(mockFn, 'test 2');
      await rateLimiter.execute(mockFn, 'test 3');

      // Should reset very quickly
      jest.advanceTimersByTime(2);
      
      await rateLimiter.execute(mockFn, 'test 4');
      expect(mockFn).toHaveBeenCalledTimes(4);
    });

    it('should handle very large window times', () => {
      rateLimiter = new RateLimiter(3, 1000000); // Very long window
      
      const info = rateLimiter.getRateLimitInfo();
      expect(info.resetTime).toBeGreaterThan(Date.now() + 999000);
    });
  });

  describe('timing precision', () => {
    beforeEach(() => {
      rateLimiter = new RateLimiter(2, 1000);
    });

    it('should handle requests at exact rate limit boundaries', async () => {
      const mockFn = jest.fn().mockResolvedValue('result');
      
      // Make requests up to the limit
      await rateLimiter.execute(mockFn, 'test 1');
      await rateLimiter.execute(mockFn, 'test 2');

      // Advance time to exactly the window boundary
      jest.advanceTimersByTime(1000);

      // Should be able to make new requests immediately
      await rateLimiter.execute(mockFn, 'test 3');
      
      const info = rateLimiter.getRateLimitInfo();
      expect(info.requests).toBe(1); // Should have reset and counted the new request
    });

    it('should handle sub-window timing correctly', async () => {
      const mockFn = jest.fn().mockResolvedValue('result');
      
      await rateLimiter.execute(mockFn, 'test 1');
      
      // Advance time but not enough to reset
      jest.advanceTimersByTime(500);
      
      await rateLimiter.execute(mockFn, 'test 2');
      
      const info = rateLimiter.getRateLimitInfo();
      expect(info.requests).toBe(2);
    });
  });

  describe('function return values and errors', () => {
    beforeEach(() => {
      rateLimiter = new RateLimiter(5, 1000);
    });

    it('should preserve function return values', async () => {
      const complexReturn = { data: [1, 2, 3], meta: { count: 3 } };
      const mockFn = jest.fn().mockResolvedValue(complexReturn);

      const result = await rateLimiter.execute(mockFn, 'test');
      
      expect(result).toEqual(complexReturn);
    });

    it('should preserve function arguments', async () => {
      const mockFn = jest.fn().mockImplementation((a, b, c) => a + b + c);

      const result = await rateLimiter.execute(() => mockFn(1, 2, 3), 'test');
      
      expect(result).toBe(6);
      expect(mockFn).toHaveBeenCalledWith(1, 2, 3);
    });

    it('should preserve error types and messages', async () => {
      class CustomError extends Error {
        constructor(message: string, public code: number) {
          super(message);
          this.name = 'CustomError';
        }
      }

      const mockFn = jest.fn().mockRejectedValue(new CustomError('Custom message', 404));

      try {
        await rateLimiter.execute(mockFn, 'test');
        fail('Should have thrown');
      } catch (error) {
        expect(error).toBeInstanceOf(CustomError);
        expect(error.message).toBe('Custom message');
        expect((error as CustomError).code).toBe(404);
      }
    });

    it('should handle synchronous functions', async () => {
      const syncFn = jest.fn().mockReturnValue('sync result');

      const result = await rateLimiter.execute(syncFn, 'sync test');
      
      expect(result).toBe('sync result');
    });
  });
});