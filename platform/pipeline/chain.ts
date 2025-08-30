import { Transform, Readable, Writable } from 'stream';
import { pipeline } from 'stream/promises';
import * as StreamChain from 'stream-chain';
import StreamValues from 'stream-json/streamers/StreamValues';
import parser from 'stream-json';

export interface BackpressureConfig {
  highWaterMark: number;
  maxConcurrency: number;
  batchSize: number;
  timeout: number;
}

export interface PipelineMetrics {
  itemsProcessed: number;
  errors: number;
  avgProcessingTime: number;
  backpressureEvents: number;
  queueDepth: number;
}

export class BackpressurePipeline<T = any> {
  private config: BackpressureConfig;
  private metrics: PipelineMetrics;
  private activeJobs = new Set<Promise<any>>();
  private queue: T[] = [];
  private paused = false;

  constructor(config: Partial<BackpressureConfig> = {}) {
    this.config = {
      highWaterMark: 16,
      maxConcurrency: 4,
      batchSize: 10,
      timeout: 30000,
      ...config,
    };

    this.metrics = {
      itemsProcessed: 0,
      errors: 0,
      avgProcessingTime: 0,
      backpressureEvents: 0,
      queueDepth: 0,
    };
  }

  /**
   * Creates a backpressure-aware transform stream
   */
  createTransform<U>(
    processor: (chunk: T) => Promise<U> | U,
    options: { objectMode?: boolean } = {}
  ): Transform {
    const startTime = Date.now();
    let processedCount = 0;

    return new Transform({
      objectMode: true,
      highWaterMark: this.config.highWaterMark,
      ...options,
      transform: async (chunk: T, _encoding, callback) => {
        try {
          // Check if we need to apply backpressure
          if (this.activeJobs.size >= this.config.maxConcurrency) {
            this.metrics.backpressureEvents++;
            this.paused = true;
            await Promise.race(Array.from(this.activeJobs));
            this.paused = false;
          }

          const jobStart = Date.now();
          const job = Promise.resolve(processor(chunk));
          this.activeJobs.add(job);

          const result = await job;
          this.activeJobs.delete(job);

          // Update metrics
          const processingTime = Date.now() - jobStart;
          this.metrics.avgProcessingTime = 
            (this.metrics.avgProcessingTime * processedCount + processingTime) / 
            (processedCount + 1);
          
          processedCount++;
          this.metrics.itemsProcessed++;
          this.metrics.queueDepth = this.queue.length;

          callback(null, result);
        } catch (error) {
          this.metrics.errors++;
          callback(error);
        }
      },
    });
  }

  /**
   * Creates a JSON streaming pipeline with backpressure
   */
  createJsonPipeline<U>(
    processor: (value: any) => Promise<U> | U,
    selector?: string
  ): Transform[] {
    const chain = new StreamChain([
      parser(),
      StreamValues.withParser(),
    ]);

    const processTransform = this.createTransform(async (data: any) => {
      const value = selector ? data.value[selector] : data.value;
      return await processor(value);
    });

    return [chain, processTransform];
  }

  /**
   * Runs a complete pipeline from source to destination
   */
  async run<U>(
    source: Readable,
    processor: (chunk: T) => Promise<U> | U,
    destination: Writable,
    options: { timeout?: number } = {}
  ): Promise<PipelineMetrics> {
    const timeout = options.timeout || this.config.timeout;
    
    try {
      const transform = this.createTransform(processor);
      
      const pipelinePromise = pipeline(
        source,
        transform,
        destination
      );

      // Add timeout handling
      const timeoutPromise = new Promise((_, reject) => {
        setTimeout(() => reject(new Error('Pipeline timeout')), timeout);
      });

      await Promise.race([pipelinePromise, timeoutPromise]);
      
      return { ...this.metrics };
    } catch (error) {
      this.metrics.errors++;
      throw error;
    }
  }

  /**
   * Batch processing with backpressure control
   */
  async processBatch<U>(
    items: T[],
    processor: (batch: T[]) => Promise<U[]> | U[]
  ): Promise<U[]> {
    const results: U[] = [];
    const batches: T[][] = [];

    // Split into batches
    for (let i = 0; i < items.length; i += this.config.batchSize) {
      batches.push(items.slice(i, i + this.config.batchSize));
    }

    // Process batches with concurrency control
    const activeBatches = new Set<Promise<U[]>>();
    
    for (const batch of batches) {
      // Apply backpressure
      while (activeBatches.size >= this.config.maxConcurrency) {
        const completed = await Promise.race(Array.from(activeBatches));
        activeBatches.delete(Promise.resolve(completed));
      }

      const batchPromise = Promise.resolve(processor(batch));
      activeBatches.add(batchPromise);
      
      batchPromise.then(batchResults => {
        results.push(...batchResults);
        activeBatches.delete(batchPromise);
        this.metrics.itemsProcessed += batchResults.length;
      }).catch(error => {
        this.metrics.errors++;
        activeBatches.delete(batchPromise);
        throw error;
      });
    }

    // Wait for all batches to complete
    await Promise.all(Array.from(activeBatches));
    
    return results;
  }

  /**
   * Get current pipeline metrics
   */
  getMetrics(): PipelineMetrics {
    return { 
      ...this.metrics,
      queueDepth: this.queue.length
    };
  }

  /**
   * Reset metrics
   */
  resetMetrics(): void {
    this.metrics = {
      itemsProcessed: 0,
      errors: 0,
      avgProcessingTime: 0,
      backpressureEvents: 0,
      queueDepth: 0,
    };
  }

  /**
   * Check if pipeline is currently experiencing backpressure
   */
  isBackpressured(): boolean {
    return this.paused || this.activeJobs.size >= this.config.maxConcurrency;
  }
}

/**
 * Utility function to create a simple backpressure-aware pipeline
 */
export function createPipeline<T, U>(
  config?: Partial<BackpressureConfig>
): BackpressurePipeline<T> {
  return new BackpressurePipeline<T>(config);
}

/**
 * Stream transformer with built-in error handling and metrics
 */
export class MetricsTransform<T, U> extends Transform {
  private startTime = Date.now();
  private processedCount = 0;
  private errorCount = 0;

  constructor(
    private processor: (chunk: T) => Promise<U> | U,
    options: any = {}
  ) {
    super({
      objectMode: true,
      highWaterMark: 16,
      ...options,
    });
  }

  async _transform(chunk: T, _encoding: any, callback: Function) {
    try {
      const result = await this.processor(chunk);
      this.processedCount++;
      callback(null, result);
    } catch (error) {
      this.errorCount++;
      callback(error);
    }
  }

  getStats() {
    const elapsed = Date.now() - this.startTime;
    return {
      processed: this.processedCount,
      errors: this.errorCount,
      rate: this.processedCount / (elapsed / 1000),
      elapsed,
    };
  }
}