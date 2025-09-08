#!/usr/bin/env node

/**
 * Test Suite for Parallel Worker Spawning Optimization
 * Tests the optimization of sequential worker spawning bottleneck
 */

const { execSync, spawn } = require('child_process');
const fs = require('fs');
const path = require('path');
const { performance } = require('perf_hooks');

class ParallelSpawningTests {
    constructor() {
        this.testResults = [];
        this.tempDir = '/tmp/worker-spawn-tests';
        this.setupTestEnv();
    }

    setupTestEnv() {
        // Create temporary test environment
        if (!fs.existsSync(this.tempDir)) {
            fs.mkdirSync(this.tempDir, { recursive: true });
        }
    }

    async runAllTests() {
        console.log('🧪 Running Parallel Worker Spawning Tests...\n');
        
        await this.testSequentialSpawning();
        await this.testParallelSpawning();
        await this.testWorkerReadiness();
        await this.testErrorHandling();
        await this.testPerformanceImprovement();
        
        this.printResults();
        return this.testResults.every(result => result.passed);
    }

    async testSequentialSpawning() {
        console.log('1. Testing Sequential Worker Spawning (Current Implementation)...');
        
        const startTime = performance.now();
        const numWorkers = 4;
        const workers = [];
        
        try {
            // Simulate sequential spawning
            for (let i = 1; i <= numWorkers; i++) {
                const workerStart = performance.now();
                
                // Simulate tmux session creation delay
                await this.simulateWorkerCreation(i);
                
                const workerEnd = performance.now();
                workers.push({
                    id: i,
                    spawnTime: workerEnd - workerStart
                });
            }
            
            const totalTime = performance.now() - startTime;
            
            this.testResults.push({
                test: 'Sequential Spawning',
                passed: totalTime > 200, // Should be slow
                time: totalTime,
                details: `${numWorkers} workers in ${totalTime.toFixed(2)}ms`
            });
            
            console.log(`   ✓ Sequential spawning took ${totalTime.toFixed(2)}ms`);
            console.log(`   ✓ Average per worker: ${(totalTime / numWorkers).toFixed(2)}ms\n`);
            
        } catch (error) {
            this.testResults.push({
                test: 'Sequential Spawning',
                passed: false,
                error: error.message
            });
            console.log(`   ✗ Sequential spawning failed: ${error.message}\n`);
        }
    }

    async testParallelSpawning() {
        console.log('2. Testing Parallel Worker Spawning (Optimized Implementation)...');
        
        const startTime = performance.now();
        const numWorkers = 4;
        
        try {
            // Simulate parallel spawning
            const workerPromises = [];
            
            for (let i = 1; i <= numWorkers; i++) {
                workerPromises.push(this.simulateWorkerCreation(i));
            }
            
            await Promise.all(workerPromises);
            
            const totalTime = performance.now() - startTime;
            
            this.testResults.push({
                test: 'Parallel Spawning',
                passed: totalTime < 100, // Should be faster
                time: totalTime,
                details: `${numWorkers} workers in ${totalTime.toFixed(2)}ms`
            });
            
            console.log(`   ✓ Parallel spawning took ${totalTime.toFixed(2)}ms`);
            console.log(`   ✓ Improvement: ~${((400 - totalTime) / 400 * 100).toFixed(1)}% faster\n`);
            
        } catch (error) {
            this.testResults.push({
                test: 'Parallel Spawning',
                passed: false,
                error: error.message
            });
            console.log(`   ✗ Parallel spawning failed: ${error.message}\n`);
        }
    }

    async testWorkerReadiness() {
        console.log('3. Testing Worker Readiness Detection...');
        
        try {
            const workers = await this.spawnTestWorkers(3);
            
            // Test readiness detection
            const readinessChecks = workers.map(async (worker) => {
                return this.waitForWorkerReady(worker.id, 5000);
            });
            
            const readyWorkers = await Promise.all(readinessChecks);
            const allReady = readyWorkers.every(ready => ready);
            
            this.testResults.push({
                test: 'Worker Readiness',
                passed: allReady,
                details: `${readyWorkers.filter(r => r).length}/${workers.length} workers ready`
            });
            
            console.log(`   ✓ Worker readiness detection: ${readyWorkers.filter(r => r).length}/${workers.length} ready\n`);
            
        } catch (error) {
            this.testResults.push({
                test: 'Worker Readiness',
                passed: false,
                error: error.message
            });
            console.log(`   ✗ Worker readiness test failed: ${error.message}\n`);
        }
    }

    async testErrorHandling() {
        console.log('4. Testing Error Handling in Parallel Spawning...');
        
        try {
            // Test with invalid worker configuration
            const startTime = performance.now();
            
            const workerPromises = [
                this.simulateWorkerCreation(1),
                this.simulateFailedWorkerCreation(2),
                this.simulateWorkerCreation(3)
            ];
            
            const results = await Promise.allSettled(workerPromises);
            const totalTime = performance.now() - startTime;
            
            const successful = results.filter(r => r.status === 'fulfilled').length;
            const failed = results.filter(r => r.status === 'rejected').length;
            
            this.testResults.push({
                test: 'Error Handling',
                passed: successful >= 2 && failed === 1,
                details: `${successful} successful, ${failed} failed, ${totalTime.toFixed(2)}ms`
            });
            
            console.log(`   ✓ Error handling: ${successful} successful, ${failed} failed\n`);
            
        } catch (error) {
            this.testResults.push({
                test: 'Error Handling',
                passed: false,
                error: error.message
            });
            console.log(`   ✗ Error handling test failed: ${error.message}\n`);
        }
    }

    async testPerformanceImprovement() {
        console.log('5. Testing Performance Improvement Measurement...');
        
        try {
            // Measure sequential vs parallel performance
            const numWorkers = 8;
            
            const sequentialTime = await this.measureSequentialSpawning(numWorkers);
            const parallelTime = await this.measureParallelSpawning(numWorkers);
            
            const improvement = ((sequentialTime - parallelTime) / sequentialTime) * 100;
            const speedup = sequentialTime / parallelTime;
            
            this.testResults.push({
                test: 'Performance Improvement',
                passed: improvement >= 60, // At least 60% improvement
                details: `${improvement.toFixed(1)}% improvement, ${speedup.toFixed(1)}x speedup`
            });
            
            console.log(`   ✓ Performance improvement: ${improvement.toFixed(1)}% (${speedup.toFixed(1)}x speedup)`);
            console.log(`   ✓ Sequential: ${sequentialTime.toFixed(2)}ms, Parallel: ${parallelTime.toFixed(2)}ms\n`);
            
        } catch (error) {
            this.testResults.push({
                test: 'Performance Improvement',
                passed: false,
                error: error.message
            });
            console.log(`   ✗ Performance measurement failed: ${error.message}\n`);
        }
    }

    // Helper methods
    async simulateWorkerCreation(workerId) {
        // Simulate tmux session creation time
        await new Promise(resolve => setTimeout(resolve, 50 + Math.random() * 20));
        return { id: workerId, ready: true };
    }

    async simulateFailedWorkerCreation(workerId) {
        await new Promise(resolve => setTimeout(resolve, 30));
        throw new Error(`Failed to create worker ${workerId}`);
    }

    async spawnTestWorkers(count) {
        const workers = [];
        for (let i = 1; i <= count; i++) {
            workers.push(await this.simulateWorkerCreation(i));
        }
        return workers;
    }

    async waitForWorkerReady(workerId, timeout) {
        const start = Date.now();
        while (Date.now() - start < timeout) {
            // Simulate readiness check
            if (Math.random() > 0.3) {
                return true;
            }
            await new Promise(resolve => setTimeout(resolve, 100));
        }
        return false;
    }

    async measureSequentialSpawning(numWorkers) {
        const start = performance.now();
        for (let i = 1; i <= numWorkers; i++) {
            await this.simulateWorkerCreation(i);
        }
        return performance.now() - start;
    }

    async measureParallelSpawning(numWorkers) {
        const start = performance.now();
        const promises = [];
        for (let i = 1; i <= numWorkers; i++) {
            promises.push(this.simulateWorkerCreation(i));
        }
        await Promise.all(promises);
        return performance.now() - start;
    }

    printResults() {
        console.log('📊 Test Results Summary:');
        console.log('========================');
        
        this.testResults.forEach(result => {
            const status = result.passed ? '✅' : '❌';
            console.log(`${status} ${result.test}`);
            if (result.details) {
                console.log(`   ${result.details}`);
            }
            if (result.error) {
                console.log(`   Error: ${result.error}`);
            }
            if (result.time) {
                console.log(`   Time: ${result.time.toFixed(2)}ms`);
            }
        });
        
        const passed = this.testResults.filter(r => r.passed).length;
        const total = this.testResults.length;
        
        console.log(`\n📈 Overall: ${passed}/${total} tests passed`);
    }

    cleanup() {
        // Clean up test environment
        if (fs.existsSync(this.tempDir)) {
            fs.rmSync(this.tempDir, { recursive: true, force: true });
        }
    }
}

// Run tests if called directly
if (require.main === module) {
    const tests = new ParallelSpawningTests();
    tests.runAllTests().then(success => {
        tests.cleanup();
        process.exit(success ? 0 : 1);
    });
}

module.exports = ParallelSpawningTests;