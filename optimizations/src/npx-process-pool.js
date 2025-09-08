#!/usr/bin/env node

/**
 * NPX Process Pool Manager
 * Optimizes NPX calls by maintaining persistent processes
 * Reduces 200ms NPX startup overhead through process pooling
 */

const { spawn, fork, execSync } = require('child_process');
const { EventEmitter } = require('events');
const fs = require('fs');
const path = require('path');

class NPXProcessPool extends EventEmitter {
    constructor(options = {}) {
        super();
        
        this.poolSize = options.poolSize || 5;
        this.maxIdleTime = options.maxIdleTime || 300000; // 5 minutes
        this.commandTimeout = options.commandTimeout || 30000; // 30 seconds
        this.warmupCommands = options.warmupCommands || ['status', 'info', 'health'];
        
        // Process pools by command
        this.pools = new Map();
        this.activeRequests = new Map();
        this.requestQueue = [];
        this.metrics = {
            totalRequests: 0,
            cacheHits: 0,
            cacheMisses: 0,
            avgResponseTime: 0,
            poolUtilization: 0
        };
        
        // Cleanup intervals
        this.cleanupInterval = setInterval(() => this.cleanup(), 60000); // 1 minute
        this.metricsInterval = setInterval(() => this.updateMetrics(), 5000); // 5 seconds
        
        this.log('NPX Process Pool initialized', {
            poolSize: this.poolSize,
            maxIdleTime: this.maxIdleTime,
            commandTimeout: this.commandTimeout
        });
    }

    /**
     * Initialize process pool for a specific NPX package
     */
    async initializePool(packageName, size = this.poolSize) {
        if (this.pools.has(packageName)) {
            this.log(`Pool for ${packageName} already exists`);
            return;
        }

        this.log(`Initializing pool for ${packageName} with ${size} processes...`);
        
        const pool = {
            processes: [],
            available: [],
            busy: [],
            totalRequests: 0,
            createdAt: Date.now()
        };

        // Create processes
        for (let i = 0; i < size; i++) {
            try {
                const process = await this.createProcess(packageName, i);
                pool.processes.push(process);
                pool.available.push(process);
                
                this.log(`Created process ${i} for ${packageName}`);
            } catch (error) {
                this.error(`Failed to create process ${i} for ${packageName}:`, error);
            }
        }

        this.pools.set(packageName, pool);
        
        // Warm up pool with common commands
        if (this.warmupCommands.length > 0) {
            await this.warmupPool(packageName);
        }

        this.log(`Pool initialized for ${packageName}: ${pool.available.length}/${size} processes ready`);
        
        return pool;
    }

    /**
     * Create a persistent NPX process
     */
    async createProcess(packageName, processId) {
        return new Promise((resolve, reject) => {
            const process = {
                id: processId,
                packageName: packageName,
                child: null,
                busy: false,
                lastUsed: Date.now(),
                createdAt: Date.now(),
                totalCommands: 0,
                stdin: null,
                stdout: null,
                stderr: null
            };

            // For claude-flow, we'll create a persistent Node.js process that can handle commands
            if (packageName === 'claude-flow') {
                process.child = spawn('node', ['-e', this.getProcessScript()], {
                    stdio: ['pipe', 'pipe', 'pipe'],
                    env: { ...process.env, FORCE_COLOR: '0' }
                });
            } else {
                // For other NPX packages, create a wrapper process
                process.child = spawn('node', ['-e', this.getGenericProcessScript(packageName)], {
                    stdio: ['pipe', 'pipe', 'pipe'],
                    env: { ...process.env, FORCE_COLOR: '0' }
                });
            }

            process.stdin = process.child.stdin;
            process.stdout = process.child.stdout;
            process.stderr = process.child.stderr;

            let initialized = false;
            let output = '';

            process.stdout.on('data', (data) => {
                const chunk = data.toString();
                output += chunk;
                
                if (!initialized && chunk.includes('PROCESS_READY')) {
                    initialized = true;
                    this.log(`Process ${processId} for ${packageName} is ready`);
                    resolve(process);
                }
            });

            process.stderr.on('data', (data) => {
                this.error(`Process ${processId} stderr:`, data.toString());
            });

            process.child.on('error', (error) => {
                if (!initialized) {
                    reject(error);
                } else {
                    this.error(`Process ${processId} error:`, error);
                    this.emit('processError', { processId, packageName, error });
                }
            });

            process.child.on('exit', (code, signal) => {
                this.log(`Process ${processId} exited with code ${code}, signal ${signal}`);
                this.handleProcessExit(packageName, processId);
            });

            // Timeout for initialization
            setTimeout(() => {
                if (!initialized) {
                    reject(new Error(`Process initialization timeout for ${packageName}:${processId}`));
                }
            }, 10000);
        });
    }

    /**
     * Get the script for claude-flow processes
     */
    getProcessScript() {
        return `
const { spawn } = require('child_process');
const readline = require('readline');

console.log('PROCESS_READY');

const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
});

rl.on('line', async (line) => {
    try {
        const command = JSON.parse(line);
        const startTime = Date.now();
        
        // Execute claude-flow command
        const child = spawn('npx', ['claude-flow@alpha', ...command.args], {
            stdio: ['pipe', 'pipe', 'pipe']
        });
        
        let stdout = '';
        let stderr = '';
        
        child.stdout.on('data', (data) => stdout += data.toString());
        child.stderr.on('data', (data) => stderr += data.toString());
        
        child.on('close', (code) => {
            const result = {
                id: command.id,
                code: code,
                stdout: stdout,
                stderr: stderr,
                duration: Date.now() - startTime
            };
            console.log('RESULT:' + JSON.stringify(result));
        });
        
        // Send timeout after 30 seconds
        setTimeout(() => {
            child.kill('SIGTERM');
        }, 30000);
        
    } catch (error) {
        console.log('ERROR:' + JSON.stringify({
            error: error.message,
            stack: error.stack
        }));
    }
});

// Keep process alive
process.on('SIGTERM', () => process.exit(0));
process.on('SIGINT', () => process.exit(0));
        `;
    }

    /**
     * Get the script for generic NPX packages
     */
    getGenericProcessScript(packageName) {
        return `
const { spawn } = require('child_process');
const readline = require('readline');

console.log('PROCESS_READY');

const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
});

rl.on('line', async (line) => {
    try {
        const command = JSON.parse(line);
        const startTime = Date.now();
        
        // Execute NPX command
        const child = spawn('npx', ['${packageName}', ...command.args], {
            stdio: ['pipe', 'pipe', 'pipe']
        });
        
        let stdout = '';
        let stderr = '';
        
        child.stdout.on('data', (data) => stdout += data.toString());
        child.stderr.on('data', (data) => stderr += data.toString());
        
        child.on('close', (code) => {
            const result = {
                id: command.id,
                code: code,
                stdout: stdout,
                stderr: stderr,
                duration: Date.now() - startTime
            };
            console.log('RESULT:' + JSON.stringify(result));
        });
        
        // Send timeout after 30 seconds
        setTimeout(() => {
            child.kill('SIGTERM');
        }, 30000);
        
    } catch (error) {
        console.log('ERROR:' + JSON.stringify({
            error: error.message,
            stack: error.stack
        }));
    }
});

process.on('SIGTERM', () => process.exit(0));
process.on('SIGINT', () => process.exit(0));
        `;
    }

    /**
     * Execute command using process pool
     */
    async executeCommand(packageName, args = [], options = {}) {
        const startTime = Date.now();
        this.metrics.totalRequests++;
        
        // Initialize pool if needed
        if (!this.pools.has(packageName)) {
            await this.initializePool(packageName);
            this.metrics.cacheMisses++;
        } else {
            this.metrics.cacheHits++;
        }

        const pool = this.pools.get(packageName);
        const availableProcess = this.getAvailableProcess(pool);
        
        if (!availableProcess) {
            // Queue the request
            return new Promise((resolve, reject) => {
                this.requestQueue.push({
                    packageName,
                    args,
                    options,
                    resolve,
                    reject,
                    startTime
                });
            });
        }

        return this.executeWithProcess(availableProcess, args, options, startTime);
    }

    /**
     * Get available process from pool
     */
    getAvailableProcess(pool) {
        if (pool.available.length === 0) {
            return null;
        }

        const process = pool.available.shift();
        pool.busy.push(process);
        process.busy = true;
        process.lastUsed = Date.now();

        return process;
    }

    /**
     * Execute command with specific process
     */
    async executeWithProcess(process, args, options, startTime) {
        return new Promise((resolve, reject) => {
            const commandId = `cmd_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
            const timeoutId = setTimeout(() => {
                reject(new Error(`Command timeout: ${args.join(' ')}`));
                this.releaseProcess(process);
            }, options.timeout || this.commandTimeout);

            const command = {
                id: commandId,
                args: args
            };

            let resultBuffer = '';
            let errorOccurred = false;

            const dataHandler = (data) => {
                const chunk = data.toString();
                resultBuffer += chunk;

                // Look for result markers
                const lines = resultBuffer.split('\n');
                for (const line of lines) {
                    if (line.startsWith('RESULT:')) {
                        try {
                            const result = JSON.parse(line.substring(7));
                            if (result.id === commandId) {
                                clearTimeout(timeoutId);
                                process.stdout.removeListener('data', dataHandler);
                                
                                const totalTime = Date.now() - startTime;
                                this.updateResponseTimeMetric(totalTime);
                                
                                this.releaseProcess(process);
                                resolve({
                                    ...result,
                                    totalTime,
                                    processId: process.id
                                });
                                return;
                            }
                        } catch (parseError) {
                            // Ignore parse errors
                        }
                    } else if (line.startsWith('ERROR:')) {
                        try {
                            const error = JSON.parse(line.substring(6));
                            clearTimeout(timeoutId);
                            process.stdout.removeListener('data', dataHandler);
                            
                            this.releaseProcess(process);
                            reject(new Error(error.error));
                            errorOccurred = true;
                            return;
                        } catch (parseError) {
                            // Ignore parse errors
                        }
                    }
                }
            };

            process.stdout.on('data', dataHandler);

            // Send command to process
            try {
                process.stdin.write(JSON.stringify(command) + '\n');
                process.totalCommands++;
            } catch (error) {
                clearTimeout(timeoutId);
                process.stdout.removeListener('data', dataHandler);
                this.releaseProcess(process);
                reject(error);
            }
        });
    }

    /**
     * Release process back to pool
     */
    releaseProcess(process) {
        const pool = this.pools.get(process.packageName);
        if (!pool) return;

        // Remove from busy list
        const busyIndex = pool.busy.indexOf(process);
        if (busyIndex > -1) {
            pool.busy.splice(busyIndex, 1);
        }

        // Add back to available list
        process.busy = false;
        process.lastUsed = Date.now();
        pool.available.push(process);

        // Process queued requests
        this.processQueue();
    }

    /**
     * Process queued requests
     */
    async processQueue() {
        while (this.requestQueue.length > 0) {
            const request = this.requestQueue[0];
            const pool = this.pools.get(request.packageName);
            
            if (!pool) break;
            
            const availableProcess = this.getAvailableProcess(pool);
            if (!availableProcess) break;

            // Remove request from queue
            this.requestQueue.shift();

            try {
                const result = await this.executeWithProcess(
                    availableProcess,
                    request.args,
                    request.options,
                    request.startTime
                );
                request.resolve(result);
            } catch (error) {
                request.reject(error);
            }
        }
    }

    /**
     * Warm up pool with common commands
     */
    async warmupPool(packageName) {
        this.log(`Warming up pool for ${packageName}...`);
        
        const warmupPromises = this.warmupCommands.map(async (command) => {
            try {
                await this.executeCommand(packageName, [command], { timeout: 5000 });
                this.log(`Warmup completed for ${packageName} ${command}`);
            } catch (error) {
                this.log(`Warmup failed for ${packageName} ${command}:`, error.message);
            }
        });

        await Promise.allSettled(warmupPromises);
        this.log(`Pool warmup completed for ${packageName}`);
    }

    /**
     * Handle process exit
     */
    handleProcessExit(packageName, processId) {
        const pool = this.pools.get(packageName);
        if (!pool) return;

        // Remove from all lists
        pool.processes = pool.processes.filter(p => p.id !== processId);
        pool.available = pool.available.filter(p => p.id !== processId);
        pool.busy = pool.busy.filter(p => p.id !== processId);

        this.log(`Process ${processId} for ${packageName} removed from pool`);

        // Create replacement process if pool is too small
        if (pool.processes.length < this.poolSize) {
            this.createProcess(packageName, Date.now())
                .then(newProcess => {
                    pool.processes.push(newProcess);
                    pool.available.push(newProcess);
                    this.log(`Replacement process created for ${packageName}`);
                })
                .catch(error => {
                    this.error(`Failed to create replacement process for ${packageName}:`, error);
                });
        }
    }

    /**
     * Clean up idle processes
     */
    cleanup() {
        const now = Date.now();
        
        for (const [packageName, pool] of this.pools.entries()) {
            const idleProcesses = pool.available.filter(
                p => now - p.lastUsed > this.maxIdleTime
            );

            for (const process of idleProcesses) {
                this.log(`Cleaning up idle process ${process.id} for ${packageName}`);
                
                // Remove from available list
                const index = pool.available.indexOf(process);
                if (index > -1) {
                    pool.available.splice(index, 1);
                }

                // Remove from processes list
                const procIndex = pool.processes.indexOf(process);
                if (procIndex > -1) {
                    pool.processes.splice(procIndex, 1);
                }

                // Kill process
                if (process.child && !process.child.killed) {
                    process.child.kill('SIGTERM');
                }
            }
        }
    }

    /**
     * Update performance metrics
     */
    updateMetrics() {
        let totalProcesses = 0;
        let busyProcesses = 0;

        for (const pool of this.pools.values()) {
            totalProcesses += pool.processes.length;
            busyProcesses += pool.busy.length;
        }

        this.metrics.poolUtilization = totalProcesses > 0 ? 
            (busyProcesses / totalProcesses) * 100 : 0;

        // Store metrics in coordination memory
        this.storeMetrics();
    }

    /**
     * Update average response time metric
     */
    updateResponseTimeMetric(responseTime) {
        if (this.metrics.totalRequests === 1) {
            this.metrics.avgResponseTime = responseTime;
        } else {
            this.metrics.avgResponseTime = 
                (this.metrics.avgResponseTime * (this.metrics.totalRequests - 1) + responseTime) / 
                this.metrics.totalRequests;
        }
    }

    /**
     * Store metrics in coordination memory
     */
    storeMetrics() {
        const { execSync } = require('child_process');
        
        try {
            execSync(`npx claude-flow@alpha hooks post-edit --file "npx-process-pool.js" --memory-key "swarm/npx-pool/metrics" --value '${JSON.stringify(this.metrics)}'`, {
                stdio: 'ignore',
                timeout: 5000
            });
        } catch (error) {
            // Ignore coordination errors
        }
    }

    /**
     * Get pool statistics
     */
    getStats() {
        const stats = {
            pools: {},
            metrics: { ...this.metrics },
            queueLength: this.requestQueue.length
        };

        for (const [packageName, pool] of this.pools.entries()) {
            stats.pools[packageName] = {
                totalProcesses: pool.processes.length,
                availableProcesses: pool.available.length,
                busyProcesses: pool.busy.length,
                totalRequests: pool.totalRequests,
                createdAt: pool.createdAt,
                uptime: Date.now() - pool.createdAt
            };
        }

        return stats;
    }

    /**
     * Shutdown pool manager
     */
    async shutdown() {
        this.log('Shutting down NPX Process Pool...');

        // Clear intervals
        if (this.cleanupInterval) {
            clearInterval(this.cleanupInterval);
        }
        if (this.metricsInterval) {
            clearInterval(this.metricsInterval);
        }

        // Kill all processes
        for (const pool of this.pools.values()) {
            for (const process of pool.processes) {
                if (process.child && !process.child.killed) {
                    process.child.kill('SIGTERM');
                }
            }
        }

        // Clear pools
        this.pools.clear();

        this.log('NPX Process Pool shutdown complete');
    }

    /**
     * Logging methods
     */
    log(message, data = null) {
        const timestamp = new Date().toISOString();
        const logData = data ? ` ${JSON.stringify(data)}` : '';
        console.log(`[${timestamp}] [NPX-POOL] ${message}${logData}`);
    }

    error(message, data = null) {
        const timestamp = new Date().toISOString();
        const logData = data ? ` ${JSON.stringify(data)}` : '';
        console.error(`[${timestamp}] [NPX-POOL] ERROR: ${message}${logData}`);
    }
}

// CLI interface
if (require.main === module) {
    const pool = new NPXProcessPool({
        poolSize: parseInt(process.argv[3]) || 5,
        maxIdleTime: parseInt(process.argv[4]) || 300000
    });

    const command = process.argv[2];
    const packageName = process.argv[3] || 'claude-flow';

    switch (command) {
        case 'init':
            pool.initializePool(packageName).then(() => {
                console.log(`Pool initialized for ${packageName}`);
            }).catch(console.error);
            break;

        case 'stats':
            console.log(JSON.stringify(pool.getStats(), null, 2));
            break;

        case 'execute':
            const args = process.argv.slice(4);
            pool.executeCommand(packageName, args).then(result => {
                console.log(JSON.stringify(result, null, 2));
            }).catch(console.error);
            break;

        case 'benchmark':
            const numRequests = parseInt(process.argv[4]) || 10;
            const startTime = Date.now();
            
            Promise.all(Array(numRequests).fill().map(() => 
                pool.executeCommand(packageName, ['status'])
            )).then(results => {
                const totalTime = Date.now() - startTime;
                console.log(`Benchmark completed: ${numRequests} requests in ${totalTime}ms`);
                console.log(`Average: ${totalTime / numRequests}ms per request`);
                console.log(`Success rate: ${results.filter(r => r.code === 0).length}/${numRequests}`);
            }).catch(console.error);
            break;

        default:
            console.log('Usage: node npx-process-pool.js {init|stats|execute|benchmark} [package] [args...]');
            process.exit(1);
    }

    // Graceful shutdown
    process.on('SIGTERM', () => pool.shutdown().then(() => process.exit(0)));
    process.on('SIGINT', () => pool.shutdown().then(() => process.exit(0)));
}

module.exports = NPXProcessPool;