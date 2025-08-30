#!/usr/bin/env node

import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import { promises as fs } from 'fs';
import { existsSync, statSync } from 'fs';
import { spawn } from 'child_process';
import { EventEmitter } from 'events';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

interface PipelineConfig {
  id: string;
  name: string;
  description: string;
  stages: PipelineStage[];
  environment: Record<string, string>;
  timeout: number;
  retries: number;
  onFailure: 'stop' | 'continue' | 'retry';
}

interface PipelineStage {
  id: string;
  name: string;
  description?: string;
  command: string;
  workingDir?: string;
  environment?: Record<string, string>;
  condition?: string;
  timeout?: number;
  retries?: number;
  continueOnError?: boolean;
  dependsOn?: string[];
}

interface PipelineResult {
  stage: string;
  success: boolean;
  duration: number;
  output?: string;
  error?: string;
  exitCode?: number;
}

interface PipelineExecution {
  id: string;
  experimentId: string;
  pipelineId: string;
  startTime: Date;
  endTime?: Date;
  status: 'running' | 'completed' | 'failed' | 'cancelled';
  results: PipelineResult[];
  totalDuration: number;
}

class PipelineRunner extends EventEmitter {
  private projectRoot: string;
  private experimentsDir: string;
  private pipelinesDir: string;
  private logDir: string;

  constructor() {
    super();
    this.projectRoot = join(__dirname, '../..');
    this.experimentsDir = join(this.projectRoot, 'experiments');
    this.pipelinesDir = join(this.projectRoot, 'platform/pipelines');
    this.logDir = join(this.projectRoot, 'platform/logs');
    this.ensureDirectories();
  }

  private async ensureDirectories(): Promise<void> {
    const dirs = [this.pipelinesDir, this.logDir];
    for (const dir of dirs) {
      if (!existsSync(dir)) {
        await fs.mkdir(dir, { recursive: true });
      }
    }
  }

  private async execCommand(
    command: string, 
    cwd: string, 
    env: Record<string, string> = {},
    timeout: number = 300000
  ): Promise<{ stdout: string; stderr: string; code: number; duration: number }> {
    return new Promise((resolve, reject) => {
      const startTime = Date.now();
      const [cmd, ...args] = command.split(' ');
      
      const child = spawn(cmd, args, {
        cwd,
        stdio: ['pipe', 'pipe', 'pipe'],
        shell: true,
        env: { ...process.env, ...env }
      });

      let stdout = '';
      let stderr = '';
      let timeoutHandle: NodeJS.Timeout | null = null;

      if (timeout > 0) {
        timeoutHandle = setTimeout(() => {
          child.kill('SIGTERM');
          reject(new Error(`Command timed out after ${timeout}ms`));
        }, timeout);
      }

      child.stdout?.on('data', (data) => {
        stdout += data.toString();
        this.emit('output', data.toString());
      });

      child.stderr?.on('data', (data) => {
        stderr += data.toString();
        this.emit('error', data.toString());
      });

      child.on('close', (code) => {
        if (timeoutHandle) clearTimeout(timeoutHandle);
        const duration = Date.now() - startTime;
        resolve({ stdout, stderr, code: code || 0, duration });
      });

      child.on('error', (error) => {
        if (timeoutHandle) clearTimeout(timeoutHandle);
        const duration = Date.now() - startTime;
        resolve({ stdout, stderr: error.message, code: 1, duration });
      });
    });
  }

  private async loadPipeline(pipelineId: string): Promise<PipelineConfig> {
    const pipelinePath = join(this.pipelinesDir, `${pipelineId}.json`);
    
    if (!existsSync(pipelinePath)) {
      // Try to find pipeline by pattern
      const files = await fs.readdir(this.pipelinesDir);
      const matchingFile = files.find(f => f.includes(pipelineId) && f.endsWith('.json'));
      
      if (!matchingFile) {
        throw new Error(`Pipeline '${pipelineId}' not found`);
      }
      
      const content = await fs.readFile(join(this.pipelinesDir, matchingFile), 'utf-8');
      return JSON.parse(content);
    }

    const content = await fs.readFile(pipelinePath, 'utf-8');
    return JSON.parse(content);
  }

  private async createDefaultPipelines(): Promise<void> {
    const defaultPipelines = [
      {
        id: 'build',
        name: 'Build Pipeline',
        description: 'Standard build pipeline for experiments',
        stages: [
          {
            id: 'install',
            name: 'Install Dependencies',
            command: 'npm install',
            timeout: 300000
          },
          {
            id: 'typecheck',
            name: 'Type Check',
            command: 'npx tsc --noEmit',
            timeout: 60000,
            dependsOn: ['install']
          },
          {
            id: 'build',
            name: 'Build',
            command: 'npm run build',
            timeout: 120000,
            dependsOn: ['typecheck']
          }
        ],
        environment: {},
        timeout: 600000,
        retries: 1,
        onFailure: 'stop'
      },
      {
        id: 'test',
        name: 'Test Pipeline',
        description: 'Testing pipeline with coverage',
        stages: [
          {
            id: 'install',
            name: 'Install Dependencies',
            command: 'npm install',
            timeout: 300000
          },
          {
            id: 'lint',
            name: 'Lint Code',
            command: 'npm run lint || echo "No lint script"',
            timeout: 60000,
            continueOnError: true,
            dependsOn: ['install']
          },
          {
            id: 'test',
            name: 'Run Tests',
            command: 'npm test',
            timeout: 180000,
            dependsOn: ['install']
          },
          {
            id: 'coverage',
            name: 'Generate Coverage',
            command: 'npm run test:coverage || npm test -- --coverage',
            timeout: 180000,
            continueOnError: true,
            dependsOn: ['test']
          }
        ],
        environment: { NODE_ENV: 'test' },
        timeout: 900000,
        retries: 2,
        onFailure: 'stop'
      },
      {
        id: 'full',
        name: 'Full CI/CD Pipeline',
        description: 'Complete pipeline with build, test, and deployment',
        stages: [
          {
            id: 'install',
            name: 'Install Dependencies',
            command: 'npm install',
            timeout: 300000
          },
          {
            id: 'lint',
            name: 'Lint Code',
            command: 'npm run lint || echo "Linting skipped"',
            timeout: 60000,
            continueOnError: true,
            dependsOn: ['install']
          },
          {
            id: 'typecheck',
            name: 'Type Check',
            command: 'npx tsc --noEmit',
            timeout: 60000,
            dependsOn: ['install']
          },
          {
            id: 'test',
            name: 'Run Tests',
            command: 'npm test',
            timeout: 180000,
            dependsOn: ['typecheck']
          },
          {
            id: 'build',
            name: 'Build',
            command: 'npm run build',
            timeout: 120000,
            dependsOn: ['test']
          },
          {
            id: 'security',
            name: 'Security Audit',
            command: 'npm audit --audit-level moderate',
            timeout: 60000,
            continueOnError: true,
            dependsOn: ['build']
          },
          {
            id: 'package',
            name: 'Package Artifact',
            command: 'tar -czf ../experiment.tar.gz .',
            timeout: 30000,
            continueOnError: true,
            dependsOn: ['build']
          }
        ],
        environment: { NODE_ENV: 'production' },
        timeout: 1200000,
        retries: 1,
        onFailure: 'stop'
      },
      {
        id: 'experiment',
        name: 'Experiment Execution Pipeline',
        description: 'Pipeline for running experiments',
        stages: [
          {
            id: 'setup',
            name: 'Setup Environment',
            command: 'npm install',
            timeout: 300000
          },
          {
            id: 'validate',
            name: 'Validate Experiment',
            command: 'npm run validate || echo "No validation script"',
            timeout: 60000,
            continueOnError: true,
            dependsOn: ['setup']
          },
          {
            id: 'run',
            name: 'Execute Experiment',
            command: 'npm start',
            timeout: 1800000,
            dependsOn: ['setup']
          },
          {
            id: 'collect',
            name: 'Collect Results',
            command: 'npm run collect-results || echo "Results collected manually"',
            timeout: 60000,
            continueOnError: true,
            dependsOn: ['run']
          },
          {
            id: 'analyze',
            name: 'Analyze Results',
            command: 'npm run analyze || echo "Analysis skipped"',
            timeout: 300000,
            continueOnError: true,
            dependsOn: ['collect']
          }
        ],
        environment: { NODE_ENV: 'experiment' },
        timeout: 2400000,
        retries: 1,
        onFailure: 'stop'
      }
    ];

    for (const pipeline of defaultPipelines) {
      const pipelinePath = join(this.pipelinesDir, `${pipeline.id}.json`);
      if (!existsSync(pipelinePath)) {
        await fs.writeFile(pipelinePath, JSON.stringify(pipeline, null, 2));
      }
    }
  }

  private evaluateCondition(condition: string, context: Record<string, any>): boolean {
    try {
      // Simple condition evaluation (extend as needed)
      if (condition.includes('===') || condition.includes('!==') || condition.includes('&&') || condition.includes('||')) {
        // Replace variables with values
        let evalCondition = condition;
        for (const [key, value] of Object.entries(context)) {
          evalCondition = evalCondition.replace(new RegExp(`\\b${key}\\b`, 'g'), JSON.stringify(value));
        }
        return Function(`"use strict"; return (${evalCondition})`)();
      }
      return true;
    } catch {
      return true; // Default to true if evaluation fails
    }
  }

  private async logExecution(execution: PipelineExecution): Promise<void> {
    const logFile = join(this.logDir, `${execution.experimentId}-${execution.pipelineId}-${execution.id}.json`);
    await fs.writeFile(logFile, JSON.stringify(execution, null, 2));
  }

  private resolveDependencies(stages: PipelineStage[]): PipelineStage[][] {
    const resolved: PipelineStage[][] = [];
    const stageMap = new Map(stages.map(s => [s.id, s]));
    const visited = new Set<string>();
    const visiting = new Set<string>();

    function visit(stageId: string): number {
      if (visiting.has(stageId)) {
        throw new Error(`Circular dependency detected: ${stageId}`);
      }
      if (visited.has(stageId)) {
        const stage = stageMap.get(stageId)!;
        for (let i = 0; i < resolved.length; i++) {
          if (resolved[i].includes(stage)) {
            return i;
          }
        }
      }

      visiting.add(stageId);
      const stage = stageMap.get(stageId)!;
      let maxLevel = -1;

      if (stage.dependsOn) {
        for (const depId of stage.dependsOn) {
          const depLevel = visit(depId);
          maxLevel = Math.max(maxLevel, depLevel);
        }
      }

      visiting.delete(stageId);
      visited.add(stageId);

      const level = maxLevel + 1;
      if (!resolved[level]) {
        resolved[level] = [];
      }
      resolved[level].push(stage);
      
      return level;
    }

    for (const stage of stages) {
      if (!visited.has(stage.id)) {
        visit(stage.id);
      }
    }

    return resolved.filter(level => level.length > 0);
  }

  async runPipeline(experimentId: string, pipelineId: string, options: {
    dryRun?: boolean;
    verbose?: boolean;
    continueOnError?: boolean;
  } = {}): Promise<PipelineExecution> {
    const experimentPath = join(this.experimentsDir, experimentId);
    
    if (!existsSync(experimentPath)) {
      throw new Error(`Experiment '${experimentId}' not found`);
    }

    // Ensure default pipelines exist
    await this.createDefaultPipelines();

    // Load pipeline configuration
    const pipeline = await this.loadPipeline(pipelineId);
    
    const execution: PipelineExecution = {
      id: `${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
      experimentId,
      pipelineId,
      startTime: new Date(),
      status: 'running',
      results: [],
      totalDuration: 0
    };

    console.log(`🚀 Starting pipeline '${pipeline.name}' for experiment '${experimentId}'`);
    console.log(`📋 Pipeline: ${pipeline.description}`);
    console.log(`🔗 Execution ID: ${execution.id}`);

    if (options.dryRun) {
      console.log('\n🧪 DRY RUN MODE - No commands will be executed');
    }

    try {
      const startTime = Date.now();
      
      // Resolve stage dependencies
      const stageLevels = this.resolveDependencies(pipeline.stages);
      
      console.log(`\n📊 Pipeline has ${pipeline.stages.length} stages in ${stageLevels.length} levels`);
      
      const context = { ...pipeline.environment };

      // Execute stages level by level
      for (let levelIndex = 0; levelIndex < stageLevels.length; levelIndex++) {
        const level = stageLevels[levelIndex];
        console.log(`\n🔄 Executing level ${levelIndex + 1} (${level.length} stage${level.length > 1 ? 's' : ''}):`);

        // Execute stages in parallel within each level
        const stagePromises = level.map(async (stage) => {
          // Check condition
          if (stage.condition && !this.evaluateCondition(stage.condition, context)) {
            console.log(`⏭️  Skipping stage '${stage.name}' (condition not met)`);
            return {
              stage: stage.id,
              success: true,
              duration: 0,
              output: 'Skipped due to condition'
            } as PipelineResult;
          }

          const stageStart = Date.now();
          console.log(`  🔧 ${stage.name}...`);

          if (options.dryRun) {
            console.log(`    💡 Would execute: ${stage.command}`);
            return {
              stage: stage.id,
              success: true,
              duration: 0,
              output: '[DRY RUN]'
            } as PipelineResult;
          }

          const workingDir = stage.workingDir ? join(experimentPath, stage.workingDir) : experimentPath;
          const env = { ...context, ...stage.environment };
          const timeout = stage.timeout || pipeline.timeout || 300000;

          let attempt = 0;
          const maxRetries = stage.retries !== undefined ? stage.retries : pipeline.retries || 0;

          while (attempt <= maxRetries) {
            try {
              if (attempt > 0) {
                console.log(`    🔄 Retry ${attempt}/${maxRetries}...`);
              }

              const result = await this.execCommand(stage.command, workingDir, env, timeout);
              const duration = Date.now() - stageStart;

              if (result.code === 0) {
                console.log(`    ✅ ${stage.name} completed (${duration}ms)`);
                if (options.verbose && result.stdout) {
                  console.log(`    📄 Output: ${result.stdout.slice(0, 200)}${result.stdout.length > 200 ? '...' : ''}`);
                }
                
                return {
                  stage: stage.id,
                  success: true,
                  duration: result.duration,
                  output: result.stdout,
                  exitCode: result.code
                } as PipelineResult;
              } else {
                throw new Error(`Command failed with exit code ${result.code}: ${result.stderr}`);
              }
            } catch (error) {
              attempt++;
              if (attempt > maxRetries) {
                const duration = Date.now() - stageStart;
                console.log(`    ❌ ${stage.name} failed after ${maxRetries + 1} attempts (${duration}ms)`);
                console.log(`    💬 Error: ${error}`);

                const result: PipelineResult = {
                  stage: stage.id,
                  success: false,
                  duration,
                  error: String(error),
                  exitCode: 1
                };

                if (!stage.continueOnError && !options.continueOnError) {
                  throw error;
                }

                return result;
              }
              
              await new Promise(resolve => setTimeout(resolve, 1000 * attempt));
            }
          }

          throw new Error('Unexpected end of retry loop');
        });

        const levelResults = await Promise.allSettled(stagePromises);
        
        // Process results
        for (const result of levelResults) {
          if (result.status === 'fulfilled') {
            execution.results.push(result.value);
          } else {
            execution.results.push({
              stage: 'unknown',
              success: false,
              duration: 0,
              error: String(result.reason)
            });
            
            if (pipeline.onFailure === 'stop') {
              throw result.reason;
            }
          }
        }

        // Check if any stage failed and we should stop
        const failedStages = levelResults.filter(r => r.status === 'rejected' || (r.status === 'fulfilled' && !r.value.success));
        if (failedStages.length > 0 && pipeline.onFailure === 'stop' && !options.continueOnError) {
          throw new Error(`${failedStages.length} stage(s) failed in level ${levelIndex + 1}`);
        }
      }

      execution.endTime = new Date();
      execution.totalDuration = Date.now() - startTime;
      execution.status = 'completed';

      const successCount = execution.results.filter(r => r.success).length;
      const failureCount = execution.results.length - successCount;

      console.log('\n' + '='.repeat(60));
      console.log(`🎉 Pipeline '${pipeline.name}' completed!`);
      console.log(`⏱️  Total duration: ${execution.totalDuration}ms`);
      console.log(`✅ Successful stages: ${successCount}`);
      if (failureCount > 0) {
        console.log(`❌ Failed stages: ${failureCount}`);
      }

    } catch (error) {
      execution.endTime = new Date();
      execution.totalDuration = Date.now() - Date.parse(execution.startTime.toString());
      execution.status = 'failed';

      console.log('\n' + '='.repeat(60));
      console.log(`❌ Pipeline '${pipeline.name}' failed!`);
      console.log(`💬 Error: ${error}`);
      console.log(`⏱️  Duration: ${execution.totalDuration}ms`);

      const successCount = execution.results.filter(r => r.success).length;
      const failureCount = execution.results.length - successCount;
      console.log(`✅ Completed stages: ${successCount}`);
      console.log(`❌ Failed stages: ${failureCount}`);

      throw error;
    } finally {
      // Log execution
      await this.logExecution(execution);
    }

    return execution;
  }

  async listPipelines(): Promise<void> {
    await this.createDefaultPipelines();
    
    const files = await fs.readdir(this.pipelinesDir);
    const pipelineFiles = files.filter(f => f.endsWith('.json'));

    if (pipelineFiles.length === 0) {
      console.log('No pipelines found.');
      return;
    }

    console.log('📋 Available Pipelines:');
    console.log('=' .repeat(60));

    for (const file of pipelineFiles) {
      try {
        const content = await fs.readFile(join(this.pipelinesDir, file), 'utf-8');
        const pipeline: PipelineConfig = JSON.parse(content);
        
        console.log(`🔧 ${pipeline.name} (${pipeline.id})`);
        console.log(`   ${pipeline.description}`);
        console.log(`   Stages: ${pipeline.stages.length}`);
        console.log(`   Timeout: ${pipeline.timeout / 1000}s`);
        console.log('');
      } catch (error) {
        console.log(`❌ Error loading ${file}: ${error}`);
      }
    }
  }

  async showPipeline(pipelineId: string): Promise<void> {
    try {
      const pipeline = await this.loadPipeline(pipelineId);
      
      console.log(`🔧 Pipeline: ${pipeline.name}`);
      console.log(`📝 Description: ${pipeline.description}`);
      console.log(`⏱️  Timeout: ${pipeline.timeout / 1000}s`);
      console.log(`🔄 Retries: ${pipeline.retries}`);
      console.log(`❌ On Failure: ${pipeline.onFailure}`);
      console.log('');

      if (Object.keys(pipeline.environment).length > 0) {
        console.log('🌍 Environment:');
        for (const [key, value] of Object.entries(pipeline.environment)) {
          console.log(`   ${key}=${value}`);
        }
        console.log('');
      }

      console.log(`📋 Stages (${pipeline.stages.length}):`);
      console.log('=' .repeat(60));

      const stageLevels = this.resolveDependencies(pipeline.stages);
      
      for (let i = 0; i < stageLevels.length; i++) {
        console.log(`\nLevel ${i + 1}:`);
        for (const stage of stageLevels[i]) {
          console.log(`  🔧 ${stage.name} (${stage.id})`);
          console.log(`     Command: ${stage.command}`);
          if (stage.timeout) console.log(`     Timeout: ${stage.timeout / 1000}s`);
          if (stage.dependsOn) console.log(`     Depends on: ${stage.dependsOn.join(', ')}`);
          if (stage.condition) console.log(`     Condition: ${stage.condition}`);
          if (stage.continueOnError) console.log(`     Continue on error: Yes`);
        }
      }

    } catch (error) {
      console.error(`❌ Error loading pipeline: ${error}`);
      process.exit(1);
    }
  }
}

// CLI interface
async function main() {
  const command = process.argv[2];
  const experimentId = process.argv[3];
  const pipelineId = process.argv[4];
  
  const options = {
    dryRun: process.argv.includes('--dry-run'),
    verbose: process.argv.includes('--verbose'),
    continueOnError: process.argv.includes('--continue-on-error')
  };

  const runner = new PipelineRunner();

  try {
    switch (command) {
      case 'run':
        if (!experimentId || !pipelineId) {
          console.error('Usage: node run-pipeline.js run <experiment-id> <pipeline-id> [options]');
          console.error('Options: --dry-run, --verbose, --continue-on-error');
          process.exit(1);
        }
        await runner.runPipeline(experimentId, pipelineId, options);
        break;

      case 'list':
        await runner.listPipelines();
        break;

      case 'show':
        if (!experimentId) {
          console.error('Usage: node run-pipeline.js show <pipeline-id>');
          process.exit(1);
        }
        await runner.showPipeline(experimentId);
        break;

      default:
        console.log('Platform Pipeline Runner');
        console.log('');
        console.log('Usage:');
        console.log('  node run-pipeline.js run <experiment-id> <pipeline-id> [options]');
        console.log('  node run-pipeline.js list');
        console.log('  node run-pipeline.js show <pipeline-id>');
        console.log('');
        console.log('Available Pipelines:');
        console.log('  build      - Standard build pipeline');
        console.log('  test       - Testing pipeline with coverage');
        console.log('  full       - Complete CI/CD pipeline');
        console.log('  experiment - Experiment execution pipeline');
        console.log('');
        console.log('Options:');
        console.log('  --dry-run           Show what would be executed');
        console.log('  --verbose           Show detailed output');
        console.log('  --continue-on-error Continue even if stages fail');
        console.log('');
        console.log('Examples:');
        console.log('  node run-pipeline.js run my-experiment build');
        console.log('  node run-pipeline.js run my-experiment test --verbose');
        console.log('  node run-pipeline.js run my-experiment full --dry-run');
        process.exit(1);
    }
  } catch (error) {
    console.error(`❌ Pipeline execution failed: ${error}`);
    process.exit(1);
  }
}

if (import.meta.url === `file://${process.argv[1]}`) {
  main();
}

export { PipelineRunner };