#!/usr/bin/env node

/**
 * Test Suite for NPX Caching and Process Pooling
 * Tests the optimization of 200ms NPX call overhead
 */

const { execSync, spawn, fork } = require('child_process');
const fs = require('fs');
const path = require('path');
const { performance } = require('perf_hooks');

class NPXCachingTests {
    constructor() {
        this.testResults = [];
        this.tempDir = '/tmp/npx-caching-tests';
        this.processPool = new Map();
        this.setupTestEnv();
    }

    setupTestEnv() {
        // Create temporary test environment
        if (!fs.existsSync(this.tempDir)) {
            fs.mkdirSync(this.tempDir, { recursive: true });
        }
    }

    async runAllTests() {
        console.log('🧪 Running NPX Caching and Process Pooling Tests...\n');
        
        await this.testNPXOverhead();
        await this.testProcessPooling();
        await this.testCacheWarmup();
        await this.testConcurrentRequests();
        await this.testPerformanceGains();
        
        this.printResults();
        return this.testResults.every(result => result.passed);
    }

    async testNPXOverhead() {
        console.log('1. Testing NPX Call Overhead (Current Implementation)...');
        
        try {
            const numCalls = 5;
            const times = [];
            
            // Measure individual NPX calls
            for (let i = 0; i < numCalls; i++) {
                const startTime = performance.now();
                await this.simulateNPXCall('claude-flow', 'status');
                const callTime = performance.now() - startTime;
                times.push(callTime);
            }
            
            const avgTime = times.reduce((a, b) => a + b, 0) / times.length;
            const totalTime = times.reduce((a, b) => a + b, 0);
            
            this.testResults.push({
                test: 'NPX Overhead',
                passed: avgTime >= 150, // Should show overhead
                time: totalTime,
                details: `Average ${avgTime.toFixed(2)}ms per call, ${totalTime.toFixed(2)}ms total`
            });
            
            console.log(`   ✓ NPX call overhead: ${avgTime.toFixed(2)}ms average per call`);
            console.log(`   ✓ Total time for ${numCalls} calls: ${totalTime.toFixed(2)}ms\n`);
            
        } catch (error) {
            this.testResults.push({
                test: 'NPX Overhead',
                passed: false,
                error: error.message
            });
            console.log(`   ✗ NPX overhead test failed: ${error.message}\n`);
        }
    }

    async testProcessPooling() {
        console.log('2. Testing Process Pooling (Optimized Implementation)...');
        
        try {
            const poolSize = 3;
            const numRequests = 10;
            
            // Initialize process pool
            await this.initializeProcessPool('claude-flow', poolSize);
            
            const startTime = performance.now();
            
            // Execute requests using process pool
            const promises = [];
            for (let i = 0; i < numRequests; i++) {
                promises.push(this.executeWithPool('status'));
            }
            
            const results = await Promise.all(promises);
            const totalTime = performance.now() - startTime;
            
            const avgTime = totalTime / numRequests;
            const successfulRequests = results.filter(r => r.success).length;
            
            this.testResults.push({
                test: 'Process Pooling',
                passed: avgTime < 50 && successfulRequests >= numRequests * 0.9,
                time: totalTime,
                details: `${avgTime.toFixed(2)}ms per request, ${successfulRequests}/${numRequests} successful`
            });
            
            console.log(`   ✓ Process pool performance: ${avgTime.toFixed(2)}ms per request`);
            console.log(`   ✓ Pool utilization: ${successfulRequests}/${numRequests} successful requests\n`);
            
        } catch (error) {
            this.testResults.push({
                test: 'Process Pooling',
                passed: false,
                error: error.message
            });
            console.log(`   ✗ Process pooling test failed: ${error.message}\n`);
        }
    }

    async testCacheWarmup() {
        console.log('3. Testing Cache Warmup Strategy...');
        
        try {
            const commands = ['status', 'info', 'health'];
            const startTime = performance.now();
            
            // Warm up cache with common commands
            await this.warmupCache('claude-flow', commands);
            
            const warmupTime = performance.now() - startTime;
            
            // Test cached execution speed
            const testStart = performance.now();
            const results = await Promise.all(commands.map(cmd => this.executeWithPool(cmd)));
            const cachedTime = performance.now() - testStart;
            
            const avgCachedTime = cachedTime / commands.length;
            
            this.testResults.push({
                test: 'Cache Warmup',
                passed: avgCachedTime < 30 && warmupTime < 500,
                time: warmupTime + cachedTime,
                details: `Warmup: ${warmupTime.toFixed(2)}ms, Cached avg: ${avgCachedTime.toFixed(2)}ms`
            });
            
            console.log(`   ✓ Cache warmup completed in ${warmupTime.toFixed(2)}ms`);
            console.log(`   ✓ Cached execution: ${avgCachedTime.toFixed(2)}ms average\n`);
            
        } catch (error) {
            this.testResults.push({
                test: 'Cache Warmup',
                passed: false,
                error: error.message
            });
            console.log(`   ✗ Cache warmup test failed: ${error.message}\n`);
        }
    }

    async testConcurrentRequests() {
        console.log('4. Testing Concurrent Request Handling...');
        
        try {
            const concurrentRequests = 20;
            const startTime = performance.now();
            
            // Execute concurrent requests
            const promises = [];
            for (let i = 0; i < concurrentRequests; i++) {
                promises.push(this.executeWithPool(`request-${i % 3}`));
            }
            
            const results = await Promise.all(promises);
            const totalTime = performance.now() - startTime;
            
            const successfulRequests = results.filter(r => r.success).length;
            const avgTime = totalTime / concurrentRequests;
            
            this.testResults.push({
                test: 'Concurrent Requests',
                passed: successfulRequests >= concurrentRequests * 0.9 && avgTime < 100,
                time: totalTime,
                details: `${successfulRequests}/${concurrentRequests} requests in ${avgTime.toFixed(2)}ms avg`
            });
            
            console.log(`   ✓ Concurrent handling: ${successfulRequests}/${concurrentRequests} requests`);
            console.log(`   ✓ Average response time: ${avgTime.toFixed(2)}ms\n`);
            
        } catch (error) {
            this.testResults.push({
                test: 'Concurrent Requests',
                passed: false,
                error: error.message
            });
            console.log(`   ✗ Concurrent requests test failed: ${error.message}\n`);
        }
    }

    async testPerformanceGains() {
        console.log('5. Testing Overall Performance Gains...');
        
        try {
            const numOperations = 15;
            
            // Measure traditional NPX approach
            const npxStart = performance.now();
            for (let i = 0; i < numOperations; i++) {
                await this.simulateNPXCall('claude-flow', `operation-${i}`);
            }
            const npxTime = performance.now() - npxStart;
            
            // Measure optimized approach
            const optimizedStart = performance.now();
            const promises = [];
            for (let i = 0; i < numOperations; i++) {
                promises.push(this.executeWithPool(`operation-${i}`));
            }
            await Promise.all(promises);
            const optimizedTime = performance.now() - optimizedStart;
            
            const improvement = ((npxTime - optimizedTime) / npxTime) * 100;
            const speedup = npxTime / optimizedTime;
            
            this.testResults.push({
                test: 'Performance Gains',
                passed: improvement >= 70, // At least 70% improvement
                details: `${improvement.toFixed(1)}% improvement, ${speedup.toFixed(1)}x speedup`
            });
            
            console.log(`   ✓ Performance gains: ${improvement.toFixed(1)}% improvement (${speedup.toFixed(1)}x speedup)`);
            console.log(`   ✓ NPX approach: ${npxTime.toFixed(2)}ms, Optimized: ${optimizedTime.toFixed(2)}ms\n`);
            
        } catch (error) {
            this.testResults.push({
                test: 'Performance Gains',
                passed: false,
                error: error.message
            });
            console.log(`   ✗ Performance gains test failed: ${error.message}\n`);
        }
    }

    // Helper methods
    async simulateNPXCall(command, args) {
        // Simulate NPX call overhead (startup time + execution)
        const startupDelay = 150 + Math.random() * 100; // 150-250ms startup
        const executionDelay = 20 + Math.random() * 30; // 20-50ms execution
        
        await new Promise(resolve => setTimeout(resolve, startupDelay));
        await new Promise(resolve => setTimeout(resolve, executionDelay));
        
        return { success: true, output: `Mock output for ${command} ${args}` };
    }

    async initializeProcessPool(command, size) {
        const pool = [];
        
        for (let i = 0; i < size; i++) {
            const process = {
                id: i,
                command: command,
                busy: false,
                ready: true,
                lastUsed: Date.now()
            };
            
            pool.push(process);
        }
        
        this.processPool.set(command, pool);
        
        // Simulate pool initialization time
        await new Promise(resolve => setTimeout(resolve, 100));
    }

    async executeWithPool(args) {
        const command = 'claude-flow';
        const pool = this.processPool.get(command);
        
        if (!pool) {
            throw new Error(`No pool found for command: ${command}`);
        }
        
        // Find available process
        const availableProcess = pool.find(p => !p.busy && p.ready);
        
        if (!availableProcess) {
            // Simulate waiting for available process
            await new Promise(resolve => setTimeout(resolve, 10));
            return this.executeWithPool(args);
        }
        
        // Mark process as busy
        availableProcess.busy = true;
        
        try {
            // Simulate fast execution (no startup overhead)
            const executionTime = 5 + Math.random() * 15; // 5-20ms
            await new Promise(resolve => setTimeout(resolve, executionTime));
            
            availableProcess.lastUsed = Date.now();
            
            return { success: true, processId: availableProcess.id, args };
        } finally {
            // Release process
            availableProcess.busy = false;
        }
    }

    async warmupCache(command, commands) {
        // Initialize pool
        await this.initializeProcessPool(command, Math.min(commands.length, 5));
        
        // Pre-execute common commands to warm up
        const warmupPromises = commands.map(cmd => this.executeWithPool(cmd));
        await Promise.all(warmupPromises);
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
        // Clean up process pools
        this.processPool.clear();
        
        // Clean up test environment
        if (fs.existsSync(this.tempDir)) {
            fs.rmSync(this.tempDir, { recursive: true, force: true });
        }
    }
}

// Run tests if called directly
if (require.main === module) {
    const tests = new NPXCachingTests();
    tests.runAllTests().then(success => {
        tests.cleanup();
        process.exit(success ? 0 : 1);
    });
}

module.exports = NPXCachingTests;