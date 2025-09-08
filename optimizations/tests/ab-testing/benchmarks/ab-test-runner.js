/**
 * A/B TEST RUNNER - Comprehensive Performance Validation
 * Statistical validation of optimization claims
 */

const SequentialSystem = require('../baseline/sequential-system');
const ParallelSystem = require('../optimized/parallel-system');
const fs = require('fs').promises;
const { performance } = require('perf_hooks');

class ABTestRunner {
  constructor(config = {}) {
    this.config = {
      iterations: config.iterations || 5,
      workerCounts: config.workerCounts || [5, 10, 20, 50],
      taskLoads: config.taskLoads || [50, 100, 200, 500],
      confidenceLevel: config.confidenceLevel || 0.95,
      warmupRuns: config.warmupRuns || 2,
      ...config
    };
    
    this.results = {
      baseline: [],
      optimized: [],
      comparisons: [],
      statistics: {}
    };
  }

  /**
   * Run comprehensive A/B test suite
   */
  async runFullSuite() {
    console.log('🔬 Starting Comprehensive A/B Test Suite');
    console.log(`📊 Configuration:`);
    console.log(`  - Iterations: ${this.config.iterations}`);
    console.log(`  - Worker Counts: ${this.config.workerCounts}`);
    console.log(`  - Task Loads: ${this.config.taskLoads}`);
    console.log(`  - Confidence Level: ${this.config.confidenceLevel * 100}%`);
    
    const suiteStart = performance.now();
    
    try {
      // Phase 1: Warmup runs
      await this.runWarmup();
      
      // Phase 2: Performance benchmarks
      await this.runPerformanceBenchmarks();
      
      // Phase 3: Load testing
      await this.runLoadTests();
      
      // Phase 4: Stress testing
      await this.runStressTests();
      
      // Phase 5: Statistical analysis
      await this.performStatisticalAnalysis();
      
      // Phase 6: Generate report
      const report = await this.generateComprehensiveReport();
      
      const suiteTime = performance.now() - suiteStart;
      console.log(`✅ A/B Test Suite completed in ${(suiteTime / 1000).toFixed(2)}s`);
      
      return report;
      
    } catch (error) {
      console.error('❌ A/B Test Suite failed:', error);
      throw error;
    }
  }

  /**
   * Warmup runs to stabilize JIT and memory
   */
  async runWarmup() {
    console.log('\n🔥 Running warmup iterations...');
    
    for (let i = 0; i < this.config.warmupRuns; i++) {
      console.log(`  Warmup ${i + 1}/${this.config.warmupRuns}`);
      
      // Small warmup test
      const baselineSystem = new SequentialSystem({ workerCount: 3, taskLoad: 10 });
      await baselineSystem.runBenchmark();
      
      const optimizedSystem = new ParallelSystem({ workerCount: 3, taskLoad: 10 });
      await optimizedSystem.runBenchmark();
      optimizedSystem.cleanup();
      
      // Force garbage collection
      if (global.gc) {
        global.gc();
      }
    }
    
    console.log('✅ Warmup completed');
  }

  /**
   * Core performance benchmarks
   */
  async runPerformanceBenchmarks() {
    console.log('\n⚡ Running Performance Benchmarks...');
    
    for (const workerCount of this.config.workerCounts) {
      for (const taskLoad of this.config.taskLoads) {
        console.log(`\n📈 Testing: ${workerCount} workers, ${taskLoad} tasks`);
        
        const testConfig = { workerCount, taskLoad };
        const iterationResults = [];
        
        for (let iteration = 0; iteration < this.config.iterations; iteration++) {
          console.log(`  Iteration ${iteration + 1}/${this.config.iterations}`);
          
          // Test baseline system
          const baselineResult = await this.runBaselineTest(testConfig, iteration);
          
          // Test optimized system
          const optimizedResult = await this.runOptimizedTest(testConfig, iteration);
          
          // Calculate improvement
          const improvement = this.calculateImprovement(baselineResult, optimizedResult);
          
          iterationResults.push({
            iteration,
            baseline: baselineResult,
            optimized: optimizedResult,
            improvement
          });
          
          // Store individual results
          this.results.baseline.push(baselineResult);
          this.results.optimized.push(optimizedResult);
          
          console.log(`    Improvement: ${improvement.totalTime.toFixed(1)}x faster`);
        }
        
        // Analyze iteration results
        const summary = this.analyzeIterationResults(iterationResults, testConfig);
        this.results.comparisons.push(summary);
      }
    }
  }

  /**
   * Load testing with varying concurrency
   */
  async runLoadTests() {
    console.log('\n🔄 Running Load Tests...');
    
    const loadTestConfigs = [
      { workerCount: 100, taskLoad: 1000, name: 'High Load' },
      { workerCount: 200, taskLoad: 2000, name: 'Extreme Load' },
      { workerCount: 50, taskLoad: 5000, name: 'High Task Count' }
    ];
    
    for (const config of loadTestConfigs) {
      console.log(`\n🎯 ${config.name}: ${config.workerCount} workers, ${config.taskLoad} tasks`);
      
      try {
        // Baseline under load
        const baselineStart = performance.now();
        const baselineSystem = new SequentialSystem(config);
        const baselineMetrics = await baselineSystem.runBenchmark();
        const baselineTime = performance.now() - baselineStart;
        
        // Optimized under load
        const optimizedStart = performance.now();
        const optimizedSystem = new ParallelSystem(config);
        const optimizedMetrics = await optimizedSystem.runBenchmark();
        const optimizedTime = performance.now() - optimizedStart;
        optimizedSystem.cleanup();
        
        const loadImprovement = baselineTime / optimizedTime;
        
        console.log(`  ${config.name} Results:`);
        console.log(`    Baseline: ${baselineTime.toFixed(2)}ms`);
        console.log(`    Optimized: ${optimizedTime.toFixed(2)}ms`);
        console.log(`    Improvement: ${loadImprovement.toFixed(1)}x`);
        
        this.results.comparisons.push({
          type: 'load-test',
          name: config.name,
          config,
          baselineTime,
          optimizedTime,
          improvement: loadImprovement
        });
        
      } catch (error) {
        console.error(`  ❌ ${config.name} failed:`, error.message);
      }
    }
  }

  /**
   * Stress testing to failure limits
   */
  async runStressTests() {
    console.log('\n💥 Running Stress Tests...');
    
    const stressConfigs = [
      { workerCount: 500, taskLoad: 100, name: 'Worker Stress' },
      { workerCount: 10, taskLoad: 10000, name: 'Task Stress' },
      { workerCount: 1000, taskLoad: 1000, name: 'Combined Stress' }
    ];
    
    for (const config of stressConfigs) {
      console.log(`\n🔥 ${config.name}: ${config.workerCount} workers, ${config.taskLoad} tasks`);
      
      // Test failure thresholds
      const stressResults = await this.testFailureThreshold(config);
      this.results.comparisons.push({
        type: 'stress-test',
        name: config.name,
        config,
        results: stressResults
      });
    }
  }

  /**
   * Test system failure threshold
   */
  async testFailureThreshold(config) {
    const results = { baseline: null, optimized: null };
    
    // Test baseline failure point
    try {
      const baselineSystem = new SequentialSystem(config);
      const timeout = setTimeout(() => {
        throw new Error('Baseline timeout - system overloaded');
      }, 60000); // 60s timeout
      
      const baselineMetrics = await baselineSystem.runBenchmark();
      clearTimeout(timeout);
      results.baseline = { success: true, metrics: baselineMetrics };
      
    } catch (error) {
      results.baseline = { success: false, error: error.message };
    }
    
    // Test optimized failure point
    try {
      const optimizedSystem = new ParallelSystem(config);
      const timeout = setTimeout(() => {
        throw new Error('Optimized timeout - system overloaded');
      }, 60000); // 60s timeout
      
      const optimizedMetrics = await optimizedSystem.runBenchmark();
      clearTimeout(timeout);
      optimizedSystem.cleanup();
      results.optimized = { success: true, metrics: optimizedMetrics };
      
    } catch (error) {
      results.optimized = { success: false, error: error.message };
    }
    
    console.log(`    Baseline: ${results.baseline.success ? '✅ Passed' : '❌ Failed'}`);
    console.log(`    Optimized: ${results.optimized.success ? '✅ Passed' : '❌ Failed'}`);
    
    return results;
  }

  /**
   * Run baseline system test
   */
  async runBaselineTest(config, iteration) {
    const system = new SequentialSystem(config);
    const metrics = await system.runBenchmark();
    
    return {
      system: 'baseline',
      iteration,
      config,
      metrics,
      timestamp: Date.now()
    };
  }

  /**
   * Run optimized system test
   */
  async runOptimizedTest(config, iteration) {
    const system = new ParallelSystem(config);
    
    try {
      const metrics = await system.runBenchmark();
      
      return {
        system: 'optimized',
        iteration,
        config,
        metrics,
        timestamp: Date.now()
      };
      
    } finally {
      system.cleanup();
    }
  }

  /**
   * Calculate improvement metrics
   */
  calculateImprovement(baseline, optimized) {
    const totalTimeImprovement = baseline.metrics.totalExecutionTime / optimized.metrics.totalExecutionTime;
    const startupTimeImprovement = baseline.metrics.startupTime / optimized.metrics.startupTime;
    const taskTimeImprovement = baseline.metrics.totalLatency / optimized.metrics.totalLatency;
    const memoryImprovement = baseline.metrics.peakMemoryUsage / optimized.metrics.peakMemoryUsage;
    
    return {
      totalTime: totalTimeImprovement,
      startupTime: startupTimeImprovement,
      taskTime: taskTimeImprovement,
      memory: memoryImprovement,
      npxCalls: {
        baseline: baseline.metrics.npxCalls,
        optimized: optimized.metrics.npxCalls,
        reduction: baseline.metrics.npxCalls - optimized.metrics.npxCalls
      }
    };
  }

  /**
   * Analyze iteration results for statistical significance
   */
  analyzeIterationResults(iterationResults, config) {
    const totalTimeImprovements = iterationResults.map(r => r.improvement.totalTime);
    const startupTimeImprovements = iterationResults.map(r => r.improvement.startupTime);
    const memoryImprovements = iterationResults.map(r => r.improvement.memory);
    
    return {
      config,
      iterations: iterationResults.length,
      totalTimeImprovement: {
        mean: this.calculateMean(totalTimeImprovements),
        median: this.calculateMedian(totalTimeImprovements),
        stdDev: this.calculateStdDev(totalTimeImprovements),
        min: Math.min(...totalTimeImprovements),
        max: Math.max(...totalTimeImprovements)
      },
      startupTimeImprovement: {
        mean: this.calculateMean(startupTimeImprovements),
        median: this.calculateMedian(startupTimeImprovements),
        stdDev: this.calculateStdDev(startupTimeImprovements)
      },
      memoryImprovement: {
        mean: this.calculateMean(memoryImprovements),
        median: this.calculateMedian(memoryImprovements),
        stdDev: this.calculateStdDev(memoryImprovements)
      }
    };
  }

  /**
   * Perform statistical analysis
   */
  async performStatisticalAnalysis() {
    console.log('\n📊 Performing Statistical Analysis...');
    
    // Extract all total time improvements
    const allImprovements = this.results.comparisons
      .filter(c => c.totalTimeImprovement)
      .map(c => c.totalTimeImprovement.mean);
    
    if (allImprovements.length === 0) return;
    
    const overallMean = this.calculateMean(allImprovements);
    const overallMedian = this.calculateMedian(allImprovements);
    const overallStdDev = this.calculateStdDev(allImprovements);
    const confidenceInterval = this.calculateConfidenceInterval(
      allImprovements, 
      this.config.confidenceLevel
    );
    
    this.results.statistics = {
      sampleSize: allImprovements.length,
      overallImprovement: {
        mean: overallMean,
        median: overallMedian,
        stdDev: overallStdDev,
        confidenceInterval,
        min: Math.min(...allImprovements),
        max: Math.max(...allImprovements)
      },
      claimedImprovement: 216.9,
      claimValidation: {
        achieved: overallMean >= 216.9,
        confidence: confidenceInterval.lower >= 216.9 ? 'High' : 
                   overallMean >= 216.9 ? 'Moderate' : 'Low'
      }
    };
    
    console.log(`📈 Statistical Results:`);
    console.log(`  Sample Size: ${this.results.statistics.sampleSize}`);
    console.log(`  Mean Improvement: ${overallMean.toFixed(1)}x`);
    console.log(`  Median Improvement: ${overallMedian.toFixed(1)}x`);
    console.log(`  Standard Deviation: ${overallStdDev.toFixed(1)}`);
    console.log(`  ${(this.config.confidenceLevel * 100)}% CI: [${confidenceInterval.lower.toFixed(1)}, ${confidenceInterval.upper.toFixed(1)}]`);
    console.log(`  Claimed 216.9x: ${this.results.statistics.claimValidation.achieved ? '✅ Validated' : '❌ Not Achieved'}`);
  }

  /**
   * Generate comprehensive A/B test report
   */
  async generateComprehensiveReport() {
    const report = {
      timestamp: new Date().toISOString(),
      summary: {
        totalTests: this.results.baseline.length,
        configurations: this.config,
        overallResults: this.results.statistics
      },
      detailedResults: this.results.comparisons,
      rawData: {
        baseline: this.results.baseline,
        optimized: this.results.optimized
      },
      validation: {
        claimedImprovement: '216.9x performance improvement',
        actualResults: this.results.statistics.overallImprovement,
        validated: this.results.statistics.claimValidation.achieved,
        confidence: this.results.statistics.claimValidation.confidence
      },
      recommendations: this.generateRecommendations()
    };
    
    // Save report
    const reportPath = '/Users/speed/Downloads/experiments/optimizations/tests/ab-testing/results/ab-test-report.json';
    await fs.writeFile(reportPath, JSON.stringify(report, null, 2));
    console.log(`📄 Report saved to: ${reportPath}`);
    
    return report;
  }

  /**
   * Generate recommendations based on results
   */
  generateRecommendations() {
    const stats = this.results.statistics;
    const recommendations = [];
    
    if (stats.claimValidation?.achieved) {
      recommendations.push('✅ Performance improvements validated - ready for production deployment');
    } else {
      recommendations.push('⚠️ Performance claims not fully validated - further optimization needed');
    }
    
    if (stats.overallImprovement?.stdDev > 10) {
      recommendations.push('📊 High variance detected - consider more stable benchmarking environment');
    }
    
    recommendations.push('🔄 Continue monitoring performance in production environment');
    recommendations.push('📈 Implement continuous performance testing');
    
    return recommendations;
  }

  // Statistical utility functions
  calculateMean(values) {
    return values.reduce((sum, val) => sum + val, 0) / values.length;
  }

  calculateMedian(values) {
    const sorted = [...values].sort((a, b) => a - b);
    const mid = Math.floor(sorted.length / 2);
    return sorted.length % 2 === 0 
      ? (sorted[mid - 1] + sorted[mid]) / 2 
      : sorted[mid];
  }

  calculateStdDev(values) {
    const mean = this.calculateMean(values);
    const variance = values.reduce((sum, val) => sum + Math.pow(val - mean, 2), 0) / values.length;
    return Math.sqrt(variance);
  }

  calculateConfidenceInterval(values, confidenceLevel) {
    const mean = this.calculateMean(values);
    const stdDev = this.calculateStdDev(values);
    const n = values.length;
    
    // Using t-distribution approximation for small samples
    const tValue = this.getTValue(confidenceLevel, n - 1);
    const marginOfError = tValue * (stdDev / Math.sqrt(n));
    
    return {
      lower: mean - marginOfError,
      upper: mean + marginOfError
    };
  }

  getTValue(confidenceLevel, degreesOfFreedom) {
    // Simplified t-value approximation
    if (confidenceLevel === 0.95) {
      return degreesOfFreedom > 30 ? 1.96 : 2.0;
    } else if (confidenceLevel === 0.99) {
      return degreesOfFreedom > 30 ? 2.58 : 2.7;
    }
    return 2.0; // Default
  }
}

module.exports = ABTestRunner;

// CLI support
if (require.main === module) {
  const config = {
    iterations: process.argv[2] ? parseInt(process.argv[2]) : 3,
    workerCounts: [5, 10, 20],
    taskLoads: [50, 100, 200]
  };
  
  const runner = new ABTestRunner(config);
  runner.runFullSuite()
    .then(report => {
      console.log('\n🎉 A/B Test Suite Completed Successfully!');
      console.log(`📊 Overall Improvement: ${report.summary.overallResults.overallImprovement.mean.toFixed(1)}x`);
      console.log(`✅ Validation: ${report.validation.validated ? 'PASSED' : 'FAILED'}`);
    })
    .catch(error => {
      console.error('❌ A/B Test Suite Failed:', error);
      process.exit(1);
    });
}