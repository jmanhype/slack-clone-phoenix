/**
 * BASELINE SYSTEM - Sequential Implementation
 * Simulates the original unoptimized system for A/B testing
 */

const { execSync, spawn } = require('child_process');
const { performance } = require('perf_hooks');
const fs = require('fs').promises;

class SequentialSystem {
  constructor(config = {}) {
    this.config = {
      workerCount: config.workerCount || 10,
      taskLoad: config.taskLoad || 100,
      ioLatency: config.ioLatency || 200, // ms
      npxOverhead: config.npxOverhead || 200, // ms per call
      memoryBaseline: config.memoryBaseline || 1024 * 1024 * 1024, // 1GB
      ...config
    };
    
    this.metrics = {
      startupTime: 0,
      totalLatency: 0,
      memoryUsage: [],
      npxCalls: 0,
      errors: 0
    };
  }

  /**
   * Simulate original sequential worker spawning (60s startup time)
   */
  async spawnWorkersSequentially() {
    const startTime = performance.now();
    console.log('🐌 Starting sequential worker spawning...');
    
    for (let i = 0; i < this.config.workerCount; i++) {
      // Simulate blocking worker spawn with artificial delay
      await this.simulateWorkerSpawn(i);
      
      // Track memory usage during spawn
      const memUsage = process.memoryUsage();
      this.metrics.memoryUsage.push({
        timestamp: performance.now(),
        heapUsed: memUsage.heapUsed,
        heapTotal: memUsage.heapTotal,
        external: memUsage.external,
        rss: memUsage.rss
      });
      
      console.log(`Worker ${i + 1}/${this.config.workerCount} spawned (${Math.round(performance.now() - startTime)}ms)`);
    }
    
    this.metrics.startupTime = performance.now() - startTime;
    console.log(`✅ Sequential spawning complete: ${this.metrics.startupTime.toFixed(2)}ms`);
    
    return this.metrics.startupTime;
  }

  /**
   * Simulate individual worker spawn with blocking I/O
   */
  async simulateWorkerSpawn(workerId) {
    const spawnStart = performance.now();
    
    // Simulate NPX call overhead (200ms per call)
    await this.simulateNPXCall();
    
    // Simulate blocking I/O operations
    await this.simulateBlockingIO();
    
    // Simulate worker initialization
    await this.simulateWorkerInit(workerId);
    
    const spawnTime = performance.now() - spawnStart;
    return spawnTime;
  }

  /**
   * Simulate NPX call overhead
   */
  async simulateNPXCall() {
    this.metrics.npxCalls++;
    
    // Simulate subprocess overhead
    return new Promise(resolve => {
      setTimeout(() => {
        resolve();
      }, this.config.npxOverhead);
    });
  }

  /**
   * Simulate blocking I/O operations (200ms latency)
   */
  async simulateBlockingIO() {
    return new Promise(resolve => {
      // Simulate synchronous file operations
      setTimeout(() => {
        // Simulate memory allocation during I/O
        const buffer = Buffer.alloc(1024 * 1024); // 1MB allocation
        buffer.fill('test-data');
        resolve(buffer);
      }, this.config.ioLatency);
    });
  }

  /**
   * Simulate worker initialization
   */
  async simulateWorkerInit(workerId) {
    // Simulate configuration loading
    const configData = JSON.stringify({
      workerId,
      timestamp: Date.now(),
      config: this.config
    });
    
    // Simulate memory usage during init
    const initBuffer = Buffer.from(configData);
    
    return new Promise(resolve => {
      setTimeout(() => {
        resolve(initBuffer);
      }, 50);
    });
  }

  /**
   * Execute task load with sequential processing
   */
  async executeTaskLoad() {
    const startTime = performance.now();
    console.log(`🔄 Executing ${this.config.taskLoad} tasks sequentially...`);
    
    for (let i = 0; i < this.config.taskLoad; i++) {
      try {
        await this.processTaskSequentially(i);
      } catch (error) {
        this.metrics.errors++;
        console.error(`Task ${i} failed:`, error.message);
      }
      
      // Track memory every 10 tasks
      if (i % 10 === 0) {
        const memUsage = process.memoryUsage();
        this.metrics.memoryUsage.push({
          timestamp: performance.now(),
          task: i,
          heapUsed: memUsage.heapUsed,
          heapTotal: memUsage.heapTotal
        });
      }
    }
    
    const totalTime = performance.now() - startTime;
    this.metrics.totalLatency = totalTime;
    
    console.log(`✅ Sequential task execution complete: ${totalTime.toFixed(2)}ms`);
    return totalTime;
  }

  /**
   * Process individual task with blocking behavior
   */
  async processTaskSequentially(taskId) {
    // Simulate task processing latency
    await this.simulateBlockingIO();
    
    // Simulate NPX call for each task
    await this.simulateNPXCall();
    
    return {
      taskId,
      processed: true,
      timestamp: Date.now()
    };
  }

  /**
   * Run full baseline benchmark
   */
  async runBenchmark() {
    console.log('🚀 Starting BASELINE system benchmark...');
    const overallStart = performance.now();
    
    // Phase 1: Worker spawning
    await this.spawnWorkersSequentially();
    
    // Phase 2: Task execution
    await this.executeTaskLoad();
    
    const totalTime = performance.now() - overallStart;
    
    // Final metrics
    const finalMemory = process.memoryUsage();
    this.metrics.totalExecutionTime = totalTime;
    this.metrics.finalMemoryUsage = finalMemory;
    this.metrics.avgMemoryUsage = this.calculateAverageMemory();
    this.metrics.peakMemoryUsage = this.calculatePeakMemory();
    
    console.log('📊 BASELINE Benchmark Results:');
    console.log(`  Total Execution Time: ${totalTime.toFixed(2)}ms`);
    console.log(`  Worker Startup Time: ${this.metrics.startupTime.toFixed(2)}ms`);
    console.log(`  Task Processing Time: ${this.metrics.totalLatency.toFixed(2)}ms`);
    console.log(`  NPX Calls: ${this.metrics.npxCalls}`);
    console.log(`  Errors: ${this.metrics.errors}`);
    console.log(`  Peak Memory: ${(this.metrics.peakMemoryUsage / 1024 / 1024).toFixed(2)}MB`);
    console.log(`  Avg Memory: ${(this.metrics.avgMemoryUsage / 1024 / 1024).toFixed(2)}MB`);
    
    return this.metrics;
  }

  calculateAverageMemory() {
    if (this.metrics.memoryUsage.length === 0) return 0;
    const sum = this.metrics.memoryUsage.reduce((acc, mem) => acc + mem.heapUsed, 0);
    return sum / this.metrics.memoryUsage.length;
  }

  calculatePeakMemory() {
    if (this.metrics.memoryUsage.length === 0) return 0;
    return Math.max(...this.metrics.memoryUsage.map(mem => mem.heapUsed));
  }

  getMetrics() {
    return {
      ...this.metrics,
      system: 'baseline',
      timestamp: Date.now()
    };
  }
}

module.exports = SequentialSystem;

// CLI support
if (require.main === module) {
  const config = {
    workerCount: process.argv[2] ? parseInt(process.argv[2]) : 10,
    taskLoad: process.argv[3] ? parseInt(process.argv[3]) : 100
  };
  
  const system = new SequentialSystem(config);
  system.runBenchmark()
    .then(metrics => {
      console.log('\n📈 Final Metrics:', JSON.stringify(metrics, null, 2));
    })
    .catch(error => {
      console.error('❌ Benchmark failed:', error);
      process.exit(1);
    });
}