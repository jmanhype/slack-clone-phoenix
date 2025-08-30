import * as fs from 'fs';
import * as readline from 'readline';
import { Writable, Transform, Readable } from 'stream';
import { pipeline } from 'stream/promises';
import { BackpressurePipeline } from './chain';

export interface NDJSONRecord {
  id?: string;
  timestamp: string;
  [key: string]: any;
}

export class NDJSONReader {
  private filepath: string;
  
  constructor(filepath: string) {
    this.filepath = filepath;
  }
  
  async* read(): AsyncGenerator<NDJSONRecord> {
    const fileStream = fs.createReadStream(this.filepath);
    const rl = readline.createInterface({
      input: fileStream,
      crlfDelay: Infinity
    });
    
    for await (const line of rl) {
      if (line.trim()) {
        try {
          yield JSON.parse(line);
        } catch (error) {
          console.error(`Failed to parse NDJSON line: ${line}`);
        }
      }
    }
  }
  
  async toArray(): Promise<NDJSONRecord[]> {
    const records: NDJSONRecord[] = [];
    for await (const record of this.read()) {
      records.push(record);
    }
    return records;
  }
  
  async filter(predicate: (record: NDJSONRecord) => boolean): Promise<NDJSONRecord[]> {
    const records: NDJSONRecord[] = [];
    for await (const record of this.read()) {
      if (predicate(record)) {
        records.push(record);
      }
    }
    return records;
  }
  
  async map<T>(mapper: (record: NDJSONRecord) => T): Promise<T[]> {
    const results: T[] = [];
    for await (const record of this.read()) {
      results.push(mapper(record));
    }
    return results;
  }
}

export class NDJSONWriter {
  private stream: fs.WriteStream;
  private writeQueue: Promise<void> = Promise.resolve();
  
  constructor(filepath: string, options?: { append?: boolean }) {
    this.stream = fs.createWriteStream(filepath, {
      flags: options?.append ? 'a' : 'w'
    });
  }
  
  write(record: NDJSONRecord): Promise<void> {
    const line = JSON.stringify(record) + '\n';
    
    this.writeQueue = this.writeQueue.then(() => 
      new Promise((resolve, reject) => {
        if (!this.stream.write(line)) {
          this.stream.once('drain', resolve);
        } else {
          resolve();
        }
      })
    );
    
    return this.writeQueue;
  }
  
  async writeBatch(records: NDJSONRecord[]): Promise<void> {
    for (const record of records) {
      await this.write(record);
    }
  }
  
  async close(): Promise<void> {
    await this.writeQueue;
    return new Promise((resolve, reject) => {
      this.stream.end(resolve);
    });
  }
}

export class NDJSONTransformer extends Transform {
  private transformer: (record: NDJSONRecord) => NDJSONRecord | null;
  
  constructor(transformer: (record: NDJSONRecord) => NDJSONRecord | null) {
    super();
    this.transformer = transformer;
  }
  
  _transform(chunk: Buffer, encoding: string, callback: Function) {
    const lines = chunk.toString().split('\n');
    
    for (const line of lines) {
      if (line.trim()) {
        try {
          const record = JSON.parse(line);
          const transformed = this.transformer(record);
          
          if (transformed) {
            this.push(JSON.stringify(transformed) + '\n');
          }
        } catch (error) {
          // Skip invalid lines
        }
      }
    }
    
    callback();
  }
}

export class NDJSONAggregator {
  private records: Map<string, NDJSONRecord[]> = new Map();
  
  add(key: string, record: NDJSONRecord): void {
    if (!this.records.has(key)) {
      this.records.set(key, []);
    }
    this.records.get(key)!.push(record);
  }
  
  get(key: string): NDJSONRecord[] {
    return this.records.get(key) || [];
  }
  
  getKeys(): string[] {
    return Array.from(this.records.keys());
  }
  
  aggregate<T>(aggregator: (records: NDJSONRecord[]) => T): Map<string, T> {
    const results = new Map<string, T>();
    
    for (const [key, records] of this.records) {
      results.set(key, aggregator(records));
    }
    
    return results;
  }
  
  clear(): void {
    this.records.clear();
  }
}

// Utility functions
export async function mergeNDJSON(
  inputFiles: string[],
  outputFile: string,
  deduplicate: boolean = false
): Promise<void> {
  const writer = new NDJSONWriter(outputFile);
  const seen = new Set<string>();
  
  for (const inputFile of inputFiles) {
    const reader = new NDJSONReader(inputFile);
    
    for await (const record of reader.read()) {
      if (deduplicate) {
        const key = JSON.stringify(record);
        if (seen.has(key)) continue;
        seen.add(key);
      }
      
      await writer.write(record);
    }
  }
  
  await writer.close();
}

export async function splitNDJSON(
  inputFile: string,
  outputDir: string,
  splitBy: (record: NDJSONRecord) => string
): Promise<Map<string, string>> {
  const reader = new NDJSONReader(inputFile);
  const writers = new Map<string, NDJSONWriter>();
  const files = new Map<string, string>();
  
  for await (const record of reader.read()) {
    const key = splitBy(record);
    
    if (!writers.has(key)) {
      const filepath = `${outputDir}/${key}.ndjson`;
      writers.set(key, new NDJSONWriter(filepath));
      files.set(key, filepath);
    }
    
    await writers.get(key)!.write(record);
  }
  
  for (const writer of writers.values()) {
    await writer.close();
  }
  
  return files;
}

export interface NDJSONProcessorOptions {
  validate?: boolean;
  skipInvalid?: boolean;
  batchSize?: number;
  concurrency?: number;
  timeout?: number;
}

/**
 * Enhanced NDJSON processor with backpressure support
 */
export class NDJSONProcessor {
  private pipeline: BackpressurePipeline;
  private options: Required<NDJSONProcessorOptions>;

  constructor(options: NDJSONProcessorOptions = {}) {
    this.options = {
      validate: true,
      skipInvalid: false,
      batchSize: 100,
      concurrency: 4,
      timeout: 30000,
      ...options,
    };

    this.pipeline = new BackpressurePipeline({
      batchSize: this.options.batchSize,
      maxConcurrency: this.options.concurrency,
      timeout: this.options.timeout,
      highWaterMark: 16,
    });
  }

  /**
   * Create backpressure-aware parse stream
   */
  createParseStream(): Transform {
    let buffer = '';
    let lineNumber = 0;

    return new Transform({
      objectMode: true,
      transform(chunk: Buffer, _encoding, callback) {
        buffer += chunk.toString();
        const lines = buffer.split('\n');
        buffer = lines.pop() || ''; // Keep incomplete line

        for (const line of lines) {
          lineNumber++;
          if (line.trim() === '') continue; // Skip empty lines

          try {
            const obj = JSON.parse(line);
            this.push({ data: obj, line: lineNumber });
          } catch (error) {
            if (this.options?.skipInvalid) {
              console.warn(`Skipping invalid JSON on line ${lineNumber}`);
              continue;
            }
            return callback(new Error(`Invalid JSON on line ${lineNumber}: ${error.message}`));
          }
        }
        callback();
      },
      flush(callback) {
        if (buffer.trim()) {
          lineNumber++;
          try {
            const obj = JSON.parse(buffer);
            this.push({ data: obj, line: lineNumber });
          } catch (error) {
            if (!this.options?.skipInvalid) {
              return callback(new Error(`Invalid JSON on line ${lineNumber}: ${error.message}`));
            }
          }
        }
        callback();
      }
    });
  }

  /**
   * Create streaming processor with backpressure
   */
  createProcessorStream<T, U>(processor: (obj: T) => Promise<U> | U): Transform {
    return this.pipeline.createTransform(async (item: { data: T; line: number }) => {
      try {
        const result = await processor(item.data);
        return { data: result, line: item.line };
      } catch (error) {
        throw new Error(`Processing failed on line ${item.line}: ${error.message}`);
      }
    });
  }

  /**
   * Process NDJSON file with streaming and backpressure
   */
  async processFile<T, U>(
    inputPath: string,
    outputPath: string,
    processor: (obj: T) => Promise<U> | U
  ): Promise<void> {
    const source = fs.createReadStream(inputPath, { encoding: 'utf8' });
    const destination = fs.createWriteStream(outputPath);

    const stringifyStream = new Transform({
      objectMode: true,
      transform(chunk: { data: any; line: number }, _encoding, callback) {
        try {
          const line = JSON.stringify(chunk.data) + '\n';
          callback(null, line);
        } catch (error) {
          callback(error);
        }
      }
    });

    await pipeline(
      source,
      this.createParseStream(),
      this.createProcessorStream(processor),
      stringifyStream,
      destination
    );
  }

  /**
   * Get processing metrics
   */
  getMetrics() {
    return this.pipeline.getMetrics();
  }
}

/**
 * Utility functions for enhanced NDJSON processing
 */
export function createNDJSONProcessor(options?: NDJSONProcessorOptions): NDJSONProcessor {
  return new NDJSONProcessor(options);
}