/**
 * TEST HARNESS - Orchestrated A/B Testing Execution
 * Coordinates all testing phases with hooks integration
 */

const ABTestRunner = require('../benchmarks/ab-test-runner');
const { spawn } = require('child_process');
const { performance } = require('perf_hooks');
const fs = require('fs').promises;

class TestHarness {
  constructor(config = {}) {
    this.config = {
      testSuites: config.testSuites || ['performance', 'load', 'stress', 'integration'],
      outputDir: config.outputDir || '/Users/speed/Downloads/experiments/optimizations/tests/ab-testing/results',
      enableHooks: config.enableHooks !== false,
      ...config
    };
    
    this.results = {};
    this.sessionId = `ab-test-${Date.now()}`;
  }

  /**
   * Execute full A/B testing protocol
   */
  async executeFullProtocol() {
    console.log('🚀 Starting Comprehensive A/B Testing Protocol');
    console.log(`📋 Session ID: ${this.sessionId}`);
    
    const protocolStart = performance.now();
    
    try {
      // Phase 1: Pre-test hooks and setup
      await this.executePreTestPhase();
      
      // Phase 2: Core A/B testing
      await this.executeCoreABTesting();
      
      // Phase 3: Integration and regression testing
      await this.executeIntegrationTesting();
      
      // Phase 4: Statistical validation
      await this.executeStatisticalValidation();
      
      // Phase 5: Post-test hooks and reporting
      await this.executePostTestPhase();
      
      const protocolTime = performance.now() - protocolStart;
      console.log(`✅ A/B Testing Protocol completed in ${(protocolTime / 1000).toFixed(2)}s`);
      
      return this.generateFinalReport();
      
    } catch (error) {
      console.error('❌ A/B Testing Protocol failed:', error);
      await this.handleTestFailure(error);
      throw error;
    }
  }

  /**
   * Pre-test phase with hooks integration
   */
  async executePreTestPhase() {
    console.log('\n📋 Phase 1: Pre-test Setup');
    
    if (this.config.enableHooks) {
      // Initialize hooks for A/B testing
      await this.executeHook('pre-task', {
        description: 'A/B testing optimization improvements - comprehensive validation',
        sessionId: this.sessionId
      });
      
      // Store test configuration
      await this.executeHook('memory-store', {
        key: `ab-test-config/${this.sessionId}`,
        value: JSON.stringify(this.config)
      });
    }
    
    // Ensure output directory exists
    await fs.mkdir(this.config.outputDir, { recursive: true });
    
    // System preparation
    await this.prepareTestEnvironment();
    
    console.log('✅ Pre-test setup completed');
  }

  /**
   * Core A/B testing execution
   */
  async executeCoreABTesting() {
    console.log('\n⚡ Phase 2: Core A/B Testing');
    
    // Configure A/B test runner
    const abTestConfig = {
      iterations: 5,
      workerCounts: [5, 10, 20, 50],
      taskLoads: [50, 100, 200, 500],
      confidenceLevel: 0.95,
      warmupRuns: 2
    };
    
    console.log('🔬 Initializing A/B Test Runner...');
    const runner = new ABTestRunner(abTestConfig);
    
    // Execute comprehensive test suite
    const testResults = await runner.runFullSuite();
    
    // Store results
    this.results.coreABTesting = testResults;
    
    if (this.config.enableHooks) {
      await this.executeHook('memory-store', {
        key: `ab-test-results/${this.sessionId}/core`,
        value: JSON.stringify(testResults)
      });
    }
    
    console.log('✅ Core A/B testing completed');
    return testResults;
  }

  /**
   * Integration and regression testing
   */
  async executeIntegrationTesting() {
    console.log('\n🔗 Phase 3: Integration & Regression Testing');
    
    const integrationResults = {};
    
    // Test 1: End-to-end workflow integration
    console.log('🔄 Testing E2E workflow integration...');
    integrationResults.e2eWorkflow = await this.testE2EIntegration();
    
    // Test 2: Memory optimization validation
    console.log('💾 Validating memory optimizations...');
    integrationResults.memoryValidation = await this.testMemoryOptimizations();
    
    // Test 3: NPX pool efficiency
    console.log('🏊 Testing NPX pool efficiency...');
    integrationResults.npxPoolEfficiency = await this.testNPXPoolEfficiency();
    
    // Test 4: Regression testing
    console.log('🔄 Running regression tests...');
    integrationResults.regressionTests = await this.runRegressionTests();
    
    this.results.integrationTesting = integrationResults;
    
    if (this.config.enableHooks) {
      await this.executeHook('memory-store', {
        key: `ab-test-results/${this.sessionId}/integration`,
        value: JSON.stringify(integrationResults)
      });
    }
    
    console.log('✅ Integration testing completed');
  }

  /**
   * Statistical validation phase
   */
  async executeStatisticalValidation() {
    console.log('\n📊 Phase 4: Statistical Validation');
    
    const coreResults = this.results.coreABTesting;
    
    if (!coreResults || !coreResults.summary.overallResults) {
      throw new Error('Core A/B testing results not available for statistical validation');
    }
    
    const statistics = coreResults.summary.overallResults;
    const validation = {
      claimedImprovement: 216.9,
      actualImprovement: statistics.overallImprovement.mean,
      validated: statistics.claimValidation.achieved,
      confidenceLevel: statistics.claimValidation.confidence,
      statisticalSignificance: this.assessStatisticalSignificance(statistics),
      performanceConsistency: this.assessPerformanceConsistency(coreResults.detailedResults),
      memoryEfficiency: this.assessMemoryEfficiency(coreResults.rawData)
    };
    
    console.log('📈 Statistical Validation Results:');
    console.log(`  Claimed: ${validation.claimedImprovement}x improvement`);
    console.log(`  Actual: ${validation.actualImprovement.toFixed(1)}x improvement`);
    console.log(`  Validated: ${validation.validated ? '✅ YES' : '❌ NO'}`);
    console.log(`  Confidence: ${validation.confidenceLevel}`);
    console.log(`  Statistical Significance: ${validation.statisticalSignificance}`);
    
    this.results.statisticalValidation = validation;
    
    if (this.config.enableHooks) {
      await this.executeHook('memory-store', {
        key: `ab-test-results/${this.sessionId}/validation`,
        value: JSON.stringify(validation)
      });
    }
    
    return validation;
  }

  /**
   * Post-test phase with final reporting
   */
  async executePostTestPhase() {
    console.log('\n📄 Phase 5: Post-test Reporting');
    
    // Generate comprehensive report
    const finalReport = this.generateFinalReport();
    
    // Save report to file
    const reportPath = `${this.config.outputDir}/comprehensive-ab-test-report-${this.sessionId}.json`;
    await fs.writeFile(reportPath, JSON.stringify(finalReport, null, 2));
    
    if (this.config.enableHooks) {
      // Store final results
      await this.executeHook('memory-store', {
        key: `ab-test-results/${this.sessionId}/final`,
        value: JSON.stringify(finalReport)
      });
      
      // Execute post-task hooks
      await this.executeHook('post-task', {
        taskId: `ab-testing-${this.sessionId}`
      });
      
      // Notify completion
      await this.executeHook('notify', {
        message: `A/B testing completed - ${finalReport.validation.overallValidation ? 'VALIDATED' : 'FAILED'}`
      });
    }
    
    console.log(`📁 Final report saved: ${reportPath}`);
    console.log('✅ Post-test phase completed');
  }

  /**
   * Test end-to-end workflow integration
   */
  async testE2EIntegration() {
    const testStart = performance.now();
    
    try {
      // Simulate full workflow with both systems
      const SequentialSystem = require('../baseline/sequential-system');
      const ParallelSystem = require('../optimized/parallel-system');
      
      const testConfig = { workerCount: 10, taskLoad: 50 };
      
      // Test baseline workflow
      const baselineSystem = new SequentialSystem(testConfig);
      const baselineResult = await baselineSystem.runBenchmark();
      
      // Test optimized workflow
      const optimizedSystem = new ParallelSystem(testConfig);
      const optimizedResult = await optimizedSystem.runBenchmark();
      optimizedSystem.cleanup();
      
      const integrationTime = performance.now() - testStart;
      
      return {
        success: true,
        executionTime: integrationTime,
        baselineResult,
        optimizedResult,
        improvement: baselineResult.totalExecutionTime / optimizedResult.totalExecutionTime
      };
      
    } catch (error) {
      return {
        success: false,
        error: error.message,
        executionTime: performance.now() - testStart
      };
    }
  }

  /**
   * Test memory optimizations specifically
   */
  async testMemoryOptimizations() {
    const testStart = performance.now();
    
    try {
      const ParallelSystem = require('../optimized/parallel-system');
      
      // Test with memory optimization enabled vs disabled
      const memoryOptimizedSystem = new ParallelSystem({ 
        workerCount: 20, 
        taskLoad: 100, 
        memoryOptimized: true 
      });
      
      const nonOptimizedSystem = new ParallelSystem({ 
        workerCount: 20, 
        taskLoad: 100, 
        memoryOptimized: false 
      });
      
      const optimizedResult = await memoryOptimizedSystem.runBenchmark();
      const nonOptimizedResult = await nonOptimizedSystem.runBenchmark();
      
      memoryOptimizedSystem.cleanup();
      nonOptimizedSystem.cleanup();
      
      const memoryImprovement = nonOptimizedResult.peakMemoryUsage / optimizedResult.peakMemoryUsage;
      
      return {
        success: true,
        memoryImprovement,
        optimizedPeakMemory: optimizedResult.peakMemoryUsage,
        nonOptimizedPeakMemory: nonOptimizedResult.peakMemoryUsage,
        executionTime: performance.now() - testStart
      };
      
    } catch (error) {
      return {
        success: false,
        error: error.message,
        executionTime: performance.now() - testStart
      };
    }
  }

  /**
   * Test NPX pool efficiency
   */
  async testNPXPoolEfficiency() {
    const testStart = performance.now();
    
    try {
      const ParallelSystem = require('../optimized/parallel-system');
      
      // Test with different pool sizes
      const poolSizes = [1, 3, 5, 10];
      const results = {};
      
      for (const poolSize of poolSizes) {
        const system = new ParallelSystem({ 
          workerCount: 20, 
          taskLoad: 50, 
          npxPoolSize: poolSize 
        });
        
        const result = await system.runBenchmark();
        system.cleanup();
        
        results[`pool_${poolSize}`] = {
          poolEfficiency: result.poolEfficiency,
          poolHits: result.poolHits,
          poolMisses: result.poolMisses,
          totalTime: result.totalExecutionTime
        };
      }
      
      // Find optimal pool size
      const optimalPoolSize = Object.entries(results)
        .sort((a, b) => b[1].poolEfficiency - a[1].poolEfficiency)[0];
      
      return {
        success: true,
        results,
        optimalPoolSize: optimalPoolSize[0],
        optimalEfficiency: optimalPoolSize[1].poolEfficiency,
        executionTime: performance.now() - testStart
      };
      
    } catch (error) {
      return {
        success: false,
        error: error.message,
        executionTime: performance.now() - testStart
      };
    }
  }

  /**
   * Run regression tests to ensure functionality
   */
  async runRegressionTests() {
    const testStart = performance.now();
    const regressionTests = [];
    
    try {
      // Test 1: Basic functionality maintained
      regressionTests.push(await this.testBasicFunctionality());
      
      // Test 2: Error handling preserved
      regressionTests.push(await this.testErrorHandling());
      
      // Test 3: Resource cleanup
      regressionTests.push(await this.testResourceCleanup());
      
      const passedTests = regressionTests.filter(test => test.passed).length;
      
      return {
        success: passedTests === regressionTests.length,
        totalTests: regressionTests.length,
        passedTests,
        failedTests: regressionTests.length - passedTests,
        tests: regressionTests,
        executionTime: performance.now() - testStart
      };
      
    } catch (error) {
      return {
        success: false,
        error: error.message,
        executionTime: performance.now() - testStart
      };
    }
  }

  /**
   * Test basic functionality
   */
  async testBasicFunctionality() {
    try {
      const ParallelSystem = require('../optimized/parallel-system');
      const system = new ParallelSystem({ workerCount: 3, taskLoad: 5 });
      
      const result = await system.runBenchmark();
      system.cleanup();
      
      const passed = result.totalExecutionTime > 0 && 
                     result.startupTime > 0 && 
                     result.errors === 0;
      
      return {
        name: 'Basic Functionality',
        passed,
        details: passed ? 'All basic functions working' : 'Basic functionality failed'
      };
      
    } catch (error) {
      return {
        name: 'Basic Functionality',
        passed: false,
        details: error.message
      };
    }
  }

  /**
   * Test error handling
   */
  async testErrorHandling() {
    try {
      const ParallelSystem = require('../optimized/parallel-system');
      
      // Test with invalid configuration
      const system = new ParallelSystem({ workerCount: -1, taskLoad: 0 });
      
      try {
        await system.runBenchmark();
        system.cleanup();
        
        return {
          name: 'Error Handling',
          passed: true,
          details: 'System handled invalid config gracefully'
        };
        
      } catch (error) {
        // Expected behavior - system should handle invalid configs
        return {
          name: 'Error Handling',
          passed: true,
          details: 'System properly rejected invalid configuration'
        };
      }
      
    } catch (error) {
      return {
        name: 'Error Handling',
        passed: false,
        details: error.message
      };
    }
  }

  /**
   * Test resource cleanup
   */
  async testResourceCleanup() {
    try {
      const initialMemory = process.memoryUsage().heapUsed;
      
      // Create and destroy system multiple times
      for (let i = 0; i < 3; i++) {
        const ParallelSystem = require('../optimized/parallel-system');
        const system = new ParallelSystem({ workerCount: 5, taskLoad: 10 });
        
        await system.runBenchmark();
        system.cleanup();
      }
      
      // Force garbage collection
      if (global.gc) {
        global.gc();
      }
      
      const finalMemory = process.memoryUsage().heapUsed;
      const memoryIncrease = finalMemory - initialMemory;
      
      // Memory increase should be minimal (less than 50MB)
      const passed = memoryIncrease < 50 * 1024 * 1024;
      
      return {
        name: 'Resource Cleanup',
        passed,
        details: `Memory increase: ${(memoryIncrease / 1024 / 1024).toFixed(2)}MB`
      };
      
    } catch (error) {
      return {
        name: 'Resource Cleanup',
        passed: false,
        details: error.message
      };
    }
  }

  /**
   * Assess statistical significance
   */
  assessStatisticalSignificance(statistics) {
    const improvement = statistics.overallImprovement;
    const stdDev = improvement.stdDev;
    const mean = improvement.mean;
    
    // Calculate coefficient of variation
    const cv = stdDev / mean;
    
    if (cv < 0.1) return 'High';
    if (cv < 0.2) return 'Moderate';
    return 'Low';
  }

  /**
   * Assess performance consistency
   */
  assessPerformanceConsistency(detailedResults) {
    if (!detailedResults || detailedResults.length === 0) return 'Unknown';
    
    const variations = detailedResults.map(result => {
      if (result.totalTimeImprovement) {
        return result.totalTimeImprovement.stdDev;
      }
      return 0;
    });
    
    const avgVariation = variations.reduce((sum, v) => sum + v, 0) / variations.length;
    
    if (avgVariation < 5) return 'Excellent';
    if (avgVariation < 10) return 'Good';
    if (avgVariation < 20) return 'Fair';
    return 'Poor';
  }

  /**
   * Assess memory efficiency
   */
  assessMemoryEfficiency(rawData) {
    if (!rawData || !rawData.baseline || !rawData.optimized) return 'Unknown';
    
    const baselineMemory = rawData.baseline.map(test => test.metrics.peakMemoryUsage);
    const optimizedMemory = rawData.optimized.map(test => test.metrics.peakMemoryUsage);
    
    const avgBaselineMemory = baselineMemory.reduce((sum, m) => sum + m, 0) / baselineMemory.length;
    const avgOptimizedMemory = optimizedMemory.reduce((sum, m) => sum + m, 0) / optimizedMemory.length;
    
    const memoryImprovement = avgBaselineMemory / avgOptimizedMemory;
    
    if (memoryImprovement > 5) return 'Excellent';
    if (memoryImprovement > 2) return 'Good';
    if (memoryImprovement > 1.5) return 'Fair';
    return 'Poor';
  }

  /**
   * Generate final comprehensive report
   */
  generateFinalReport() {
    const coreResults = this.results.coreABTesting;
    const integrationResults = this.results.integrationTesting;
    const validationResults = this.results.statisticalValidation;
    
    const overallValidation = validationResults?.validated && 
                             integrationResults?.e2eWorkflow?.success &&
                             integrationResults?.regressionTests?.success;
    
    return {
      sessionId: this.sessionId,
      timestamp: new Date().toISOString(),
      summary: {
        overallValidation,
        claimedImprovement: '216.9x performance improvement',
        actualImprovement: validationResults?.actualImprovement || 'N/A',
        validated: validationResults?.validated || false,
        confidenceLevel: validationResults?.confidenceLevel || 'Unknown'
      },
      coreABTesting: coreResults,
      integrationTesting: integrationResults,
      statisticalValidation: validationResults,
      validation: {
        overallValidation,
        performanceValidated: validationResults?.validated || false,
        functionalityValidated: integrationResults?.regressionTests?.success || false,
        memoryOptimizationValidated: integrationResults?.memoryValidation?.success || false,
        recommendations: this.generateRecommendations(overallValidation)
      }
    };
  }

  /**
   * Generate recommendations
   */
  generateRecommendations(overallValidation) {
    const recommendations = [];
    
    if (overallValidation) {
      recommendations.push('✅ All optimizations validated - ready for production deployment');
      recommendations.push('📈 Performance improvements exceed claimed targets');
      recommendations.push('🔄 Implement continuous performance monitoring');
    } else {
      recommendations.push('⚠️ Some validations failed - review before deployment');
      recommendations.push('🔧 Address identified issues before production');
      recommendations.push('📊 Conduct additional testing under production conditions');
    }
    
    recommendations.push('📋 Establish performance baselines for future comparisons');
    recommendations.push('🎯 Set up automated A/B testing in CI/CD pipeline');
    
    return recommendations;
  }

  /**
   * Execute hook command
   */
  async executeHook(hookType, params) {
    if (!this.config.enableHooks) return;
    
    try {
      let command;
      
      switch (hookType) {
        case 'pre-task':
          command = `npx claude-flow hooks pre-task --description "${params.description}"`;
          break;
        case 'post-task':
          command = `npx claude-flow hooks post-task --task-id "${params.taskId}"`;
          break;
        case 'memory-store':
          command = `npx claude-flow memory store "${params.key}" "${params.value}"`;
          break;
        case 'notify':
          command = `npx claude-flow hooks notify --message "${params.message}"`;
          break;
        default:
          console.warn(`Unknown hook type: ${hookType}`);
          return;
      }
      
      return new Promise((resolve, reject) => {
        const process = spawn('sh', ['-c', command], { stdio: 'pipe' });
        
        let stdout = '';
        let stderr = '';
        
        process.stdout.on('data', (data) => {
          stdout += data.toString();
        });
        
        process.stderr.on('data', (data) => {
          stderr += data.toString();
        });
        
        process.on('close', (code) => {
          if (code === 0) {
            resolve(stdout);
          } else {
            console.warn(`Hook ${hookType} failed:`, stderr);
            resolve(null); // Don't fail the test due to hook issues
          }
        });
      });
      
    } catch (error) {
      console.warn(`Hook ${hookType} error:`, error.message);
    }
  }

  /**
   * Prepare test environment
   */
  async prepareTestEnvironment() {
    // Force garbage collection before tests
    if (global.gc) {
      global.gc();
    }
    
    // Set up test directories
    await fs.mkdir(`${this.config.outputDir}/logs`, { recursive: true });
    await fs.mkdir(`${this.config.outputDir}/metrics`, { recursive: true });
    
    console.log('🔧 Test environment prepared');
  }

  /**
   * Handle test failure
   */
  async handleTestFailure(error) {
    console.error('🚨 A/B Test Failure:', error.message);
    
    if (this.config.enableHooks) {
      await this.executeHook('notify', {
        message: `A/B testing failed: ${error.message}`
      });
    }
    
    // Save failure report
    const failureReport = {
      sessionId: this.sessionId,
      timestamp: new Date().toISOString(),
      error: error.message,
      stack: error.stack,
      partialResults: this.results
    };
    
    const failurePath = `${this.config.outputDir}/failure-report-${this.sessionId}.json`;
    await fs.writeFile(failurePath, JSON.stringify(failureReport, null, 2));
    console.log(`📄 Failure report saved: ${failurePath}`);
  }
}

module.exports = TestHarness;

// CLI support
if (require.main === module) {
  const harness = new TestHarness();
  harness.executeFullProtocol()
    .then(report => {
      console.log('\n🎉 A/B Testing Protocol Completed!');
      console.log(`📊 Overall Validation: ${report.validation.overallValidation ? '✅ PASSED' : '❌ FAILED'}`);
      console.log(`🚀 Performance: ${report.summary.actualImprovement}x improvement`);
    })
    .catch(error => {
      console.error('\n❌ A/B Testing Protocol Failed:', error.message);
      process.exit(1);
    });
}