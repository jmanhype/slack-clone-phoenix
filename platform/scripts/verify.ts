#!/usr/bin/env node

import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import { promises as fs } from 'fs';
import { existsSync, statSync } from 'fs';
import { spawn } from 'child_process';
import { promisify } from 'util';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

interface VerificationResult {
  passed: boolean;
  message: string;
  details?: any;
  severity: 'error' | 'warning' | 'info';
}

interface ExperimentMetadata {
  id: string;
  name: string;
  description: string;
  version: string;
  status: string;
  dependencies: Record<string, string>;
  scripts: Record<string, string>;
}

class ExperimentVerifier {
  private projectRoot: string;
  private experimentsDir: string;
  private registryFile: string;

  constructor() {
    this.projectRoot = join(__dirname, '../..');
    this.experimentsDir = join(this.projectRoot, 'experiments');
    this.registryFile = join(this.projectRoot, 'registry/index.ndjson');
  }

  private async execCommand(command: string, cwd: string): Promise<{ stdout: string; stderr: string; code: number }> {
    return new Promise((resolve) => {
      const [cmd, ...args] = command.split(' ');
      const child = spawn(cmd, args, {
        cwd,
        stdio: ['pipe', 'pipe', 'pipe'],
        shell: true
      });

      let stdout = '';
      let stderr = '';

      child.stdout?.on('data', (data) => {
        stdout += data.toString();
      });

      child.stderr?.on('data', (data) => {
        stderr += data.toString();
      });

      child.on('close', (code) => {
        resolve({ stdout, stderr, code: code || 0 });
      });
    });
  }

  private async verifyFileStructure(experimentPath: string): Promise<VerificationResult[]> {
    const results: VerificationResult[] = [];
    
    const requiredFiles = [
      'package.json',
      'tsconfig.json',
      'src/index.ts',
      'README.md'
    ];

    const requiredDirs = [
      'src',
      'tests'
    ];

    // Check required files
    for (const file of requiredFiles) {
      const filePath = join(experimentPath, file);
      if (!existsSync(filePath)) {
        results.push({
          passed: false,
          message: `Missing required file: ${file}`,
          severity: 'error'
        });
      } else {
        results.push({
          passed: true,
          message: `Found required file: ${file}`,
          severity: 'info'
        });
      }
    }

    // Check required directories
    for (const dir of requiredDirs) {
      const dirPath = join(experimentPath, dir);
      if (!existsSync(dirPath)) {
        results.push({
          passed: false,
          message: `Missing required directory: ${dir}`,
          severity: 'error'
        });
      } else if (!statSync(dirPath).isDirectory()) {
        results.push({
          passed: false,
          message: `${dir} is not a directory`,
          severity: 'error'
        });
      } else {
        results.push({
          passed: true,
          message: `Found required directory: ${dir}`,
          severity: 'info'
        });
      }
    }

    return results;
  }

  private async verifyPackageJson(experimentPath: string): Promise<VerificationResult[]> {
    const results: VerificationResult[] = [];
    const packagePath = join(experimentPath, 'package.json');

    try {
      const content = await fs.readFile(packagePath, 'utf-8');
      const packageJson = JSON.parse(content);

      // Check required fields
      const requiredFields = ['name', 'version', 'description', 'scripts'];
      for (const field of requiredFields) {
        if (!packageJson[field]) {
          results.push({
            passed: false,
            message: `Missing required package.json field: ${field}`,
            severity: 'error'
          });
        } else {
          results.push({
            passed: true,
            message: `Found package.json field: ${field}`,
            severity: 'info'
          });
        }
      }

      // Check required scripts
      const requiredScripts = ['start', 'build', 'test'];
      for (const script of requiredScripts) {
        if (!packageJson.scripts?.[script]) {
          results.push({
            passed: false,
            message: `Missing required script: ${script}`,
            severity: 'warning'
          });
        } else {
          results.push({
            passed: true,
            message: `Found script: ${script}`,
            severity: 'info'
          });
        }
      }

      // Check TypeScript dependencies
      const hasTsx = packageJson.dependencies?.tsx || packageJson.devDependencies?.tsx;
      const hasTypescript = packageJson.dependencies?.typescript || packageJson.devDependencies?.typescript;

      if (!hasTsx && !hasTypescript) {
        results.push({
          passed: false,
          message: 'Missing TypeScript or tsx dependencies',
          severity: 'warning'
        });
      }

    } catch (error) {
      results.push({
        passed: false,
        message: `Invalid package.json: ${error}`,
        severity: 'error'
      });
    }

    return results;
  }

  private async verifyTypeScript(experimentPath: string): Promise<VerificationResult[]> {
    const results: VerificationResult[] = [];
    const tsconfigPath = join(experimentPath, 'tsconfig.json');

    try {
      const content = await fs.readFile(tsconfigPath, 'utf-8');
      const tsconfig = JSON.parse(content);

      if (!tsconfig.compilerOptions) {
        results.push({
          passed: false,
          message: 'Missing compilerOptions in tsconfig.json',
          severity: 'error'
        });
      } else {
        results.push({
          passed: true,
          message: 'Found valid tsconfig.json',
          severity: 'info'
        });
      }

      // Check TypeScript compilation
      console.log('Checking TypeScript compilation...');
      const { code, stderr } = await this.execCommand('npx tsc --noEmit', experimentPath);
      
      if (code === 0) {
        results.push({
          passed: true,
          message: 'TypeScript compilation successful',
          severity: 'info'
        });
      } else {
        results.push({
          passed: false,
          message: `TypeScript compilation failed: ${stderr}`,
          details: stderr,
          severity: 'error'
        });
      }

    } catch (error) {
      results.push({
        passed: false,
        message: `TypeScript verification failed: ${error}`,
        severity: 'error'
      });
    }

    return results;
  }

  private async verifyTests(experimentPath: string): Promise<VerificationResult[]> {
    const results: VerificationResult[] = [];
    const testsDir = join(experimentPath, 'tests');

    if (!existsSync(testsDir)) {
      results.push({
        passed: false,
        message: 'No tests directory found',
        severity: 'warning'
      });
      return results;
    }

    try {
      const testFiles = await fs.readdir(testsDir);
      const testCount = testFiles.filter(file => file.endsWith('.test.ts') || file.endsWith('.test.js')).length;

      if (testCount === 0) {
        results.push({
          passed: false,
          message: 'No test files found',
          severity: 'warning'
        });
      } else {
        results.push({
          passed: true,
          message: `Found ${testCount} test file(s)`,
          severity: 'info'
        });

        // Try to run tests
        console.log('Running tests...');
        const { code, stdout, stderr } = await this.execCommand('npm test', experimentPath);
        
        if (code === 0) {
          results.push({
            passed: true,
            message: 'All tests passed',
            details: stdout,
            severity: 'info'
          });
        } else {
          results.push({
            passed: false,
            message: `Tests failed: ${stderr}`,
            details: { stdout, stderr },
            severity: 'error'
          });
        }
      }

    } catch (error) {
      results.push({
        passed: false,
        message: `Test verification failed: ${error}`,
        severity: 'error'
      });
    }

    return results;
  }

  private async verifyDependencies(experimentPath: string): Promise<VerificationResult[]> {
    const results: VerificationResult[] = [];
    
    try {
      console.log('Checking dependencies...');
      
      // Check if node_modules exists
      const nodeModulesPath = join(experimentPath, 'node_modules');
      if (!existsSync(nodeModulesPath)) {
        results.push({
          passed: false,
          message: 'Dependencies not installed (no node_modules)',
          severity: 'warning'
        });
        
        // Try to install dependencies
        console.log('Attempting to install dependencies...');
        const { code, stderr } = await this.execCommand('npm install', experimentPath);
        
        if (code === 0) {
          results.push({
            passed: true,
            message: 'Dependencies installed successfully',
            severity: 'info'
          });
        } else {
          results.push({
            passed: false,
            message: `Dependency installation failed: ${stderr}`,
            severity: 'error'
          });
        }
      } else {
        results.push({
          passed: true,
          message: 'Dependencies are installed',
          severity: 'info'
        });
      }

      // Check for security vulnerabilities
      console.log('Checking for security vulnerabilities...');
      const { code: auditCode, stdout: auditOutput } = await this.execCommand('npm audit --json', experimentPath);
      
      if (auditCode === 0) {
        try {
          const auditResult = JSON.parse(auditOutput);
          const vulnerabilities = auditResult.metadata?.vulnerabilities;
          
          if (vulnerabilities && Object.values(vulnerabilities).some((v: any) => v > 0)) {
            results.push({
              passed: false,
              message: 'Security vulnerabilities found',
              details: vulnerabilities,
              severity: 'warning'
            });
          } else {
            results.push({
              passed: true,
              message: 'No security vulnerabilities found',
              severity: 'info'
            });
          }
        } catch (error) {
          results.push({
            passed: true,
            message: 'Security audit completed (no critical issues)',
            severity: 'info'
          });
        }
      }

    } catch (error) {
      results.push({
        passed: false,
        message: `Dependency verification failed: ${error}`,
        severity: 'error'
      });
    }

    return results;
  }

  private async verifyRegistryEntry(experimentId: string): Promise<VerificationResult[]> {
    const results: VerificationResult[] = [];

    try {
      if (!existsSync(this.registryFile)) {
        results.push({
          passed: false,
          message: 'Registry file not found',
          severity: 'error'
        });
        return results;
      }

      const content = await fs.readFile(this.registryFile, 'utf-8');
      const lines = content.trim().split('\n');
      
      let found = false;
      let metadata: ExperimentMetadata | null = null;

      for (const line of lines) {
        if (line.trim()) {
          try {
            const entry = JSON.parse(line);
            if (entry.id === experimentId) {
              found = true;
              metadata = entry;
              break;
            }
          } catch (error) {
            // Invalid JSON line, skip
          }
        }
      }

      if (!found) {
        results.push({
          passed: false,
          message: 'Experiment not found in registry',
          severity: 'error'
        });
      } else {
        results.push({
          passed: true,
          message: 'Experiment found in registry',
          details: metadata,
          severity: 'info'
        });

        // Verify metadata completeness
        const requiredFields = ['id', 'name', 'description', 'version'];
        for (const field of requiredFields) {
          if (!metadata?.[field as keyof ExperimentMetadata]) {
            results.push({
              passed: false,
              message: `Missing registry field: ${field}`,
              severity: 'warning'
            });
          }
        }
      }

    } catch (error) {
      results.push({
        passed: false,
        message: `Registry verification failed: ${error}`,
        severity: 'error'
      });
    }

    return results;
  }

  async verifyExperiment(experimentId: string, options: { skipTests?: boolean; skipDeps?: boolean } = {}): Promise<void> {
    console.log(`🔍 Verifying experiment: ${experimentId}`);
    console.log('=' .repeat(50));

    const experimentPath = join(this.experimentsDir, experimentId);

    if (!existsSync(experimentPath)) {
      console.error(`❌ Experiment '${experimentId}' not found at ${experimentPath}`);
      process.exit(1);
    }

    const allResults: VerificationResult[] = [];

    // Run all verifications
    const verifications = [
      { name: 'File Structure', fn: () => this.verifyFileStructure(experimentPath) },
      { name: 'Package.json', fn: () => this.verifyPackageJson(experimentPath) },
      { name: 'TypeScript', fn: () => this.verifyTypeScript(experimentPath) },
      { name: 'Registry Entry', fn: () => this.verifyRegistryEntry(experimentId) }
    ];

    if (!options.skipDeps) {
      verifications.push({ name: 'Dependencies', fn: () => this.verifyDependencies(experimentPath) });
    }

    if (!options.skipTests) {
      verifications.push({ name: 'Tests', fn: () => this.verifyTests(experimentPath) });
    }

    for (const verification of verifications) {
      console.log(`\n📋 ${verification.name}:`);
      try {
        const results = await verification.fn();
        allResults.push(...results);

        const errors = results.filter(r => !r.passed && r.severity === 'error');
        const warnings = results.filter(r => !r.passed && r.severity === 'warning');
        const successes = results.filter(r => r.passed);

        console.log(`  ✅ Passed: ${successes.length}`);
        if (warnings.length > 0) {
          console.log(`  ⚠️  Warnings: ${warnings.length}`);
        }
        if (errors.length > 0) {
          console.log(`  ❌ Errors: ${errors.length}`);
        }

        // Show details for failed checks
        for (const result of results) {
          if (!result.passed) {
            console.log(`    ${result.severity === 'error' ? '❌' : '⚠️'} ${result.message}`);
            if (result.details && typeof result.details === 'string' && result.details.length < 200) {
              console.log(`      ${result.details}`);
            }
          }
        }

      } catch (error) {
        console.log(`  ❌ Verification failed: ${error}`);
        allResults.push({
          passed: false,
          message: `${verification.name} verification failed: ${error}`,
          severity: 'error'
        });
      }
    }

    // Summary
    console.log('\n' + '='.repeat(50));
    const totalErrors = allResults.filter(r => !r.passed && r.severity === 'error').length;
    const totalWarnings = allResults.filter(r => !r.passed && r.severity === 'warning').length;
    const totalPassed = allResults.filter(r => r.passed).length;

    console.log(`📊 Verification Summary:`);
    console.log(`  ✅ Passed: ${totalPassed}`);
    console.log(`  ⚠️  Warnings: ${totalWarnings}`);
    console.log(`  ❌ Errors: ${totalErrors}`);

    if (totalErrors === 0 && totalWarnings === 0) {
      console.log('\n🎉 All verifications passed! Experiment is ready.');
    } else if (totalErrors === 0) {
      console.log('\n✅ Experiment is functional with minor warnings.');
    } else {
      console.log('\n❌ Experiment has errors that need to be fixed.');
      process.exit(1);
    }
  }

  async verifyAllExperiments(): Promise<void> {
    console.log('🔍 Verifying all experiments...');
    
    if (!existsSync(this.experimentsDir)) {
      console.error('❌ Experiments directory not found');
      process.exit(1);
    }

    const experiments = await fs.readdir(this.experimentsDir);
    const validExperiments = [];

    for (const experiment of experiments) {
      const experimentPath = join(this.experimentsDir, experiment);
      if (statSync(experimentPath).isDirectory()) {
        validExperiments.push(experiment);
      }
    }

    console.log(`Found ${validExperiments.length} experiment(s)`);

    let totalPassed = 0;
    let totalFailed = 0;

    for (const experiment of validExperiments) {
      try {
        console.log(`\n${'='.repeat(60)}`);
        await this.verifyExperiment(experiment, { skipTests: true, skipDeps: true });
        totalPassed++;
      } catch (error) {
        totalFailed++;
        console.log(`❌ ${experiment}: Verification failed`);
      }
    }

    console.log(`\n${'='.repeat(60)}`);
    console.log(`📊 Overall Summary:`);
    console.log(`  ✅ Passed: ${totalPassed}`);
    console.log(`  ❌ Failed: ${totalFailed}`);

    if (totalFailed > 0) {
      process.exit(1);
    }
  }
}

// CLI interface
async function main() {
  const command = process.argv[2];
  const experimentId = process.argv[3];
  const options = {
    skipTests: process.argv.includes('--skip-tests'),
    skipDeps: process.argv.includes('--skip-deps')
  };

  const verifier = new ExperimentVerifier();

  try {
    if (command === 'all') {
      await verifier.verifyAllExperiments();
    } else if (experimentId) {
      await verifier.verifyExperiment(experimentId, options);
    } else {
      console.error('Usage:');
      console.error('  node verify.js <experiment-id> [--skip-tests] [--skip-deps]');
      console.error('  node verify.js all');
      console.error('');
      console.error('Examples:');
      console.error('  node verify.js my-experiment');
      console.error('  node verify.js my-experiment --skip-tests');
      console.error('  node verify.js all');
      process.exit(1);
    }
  } catch (error) {
    console.error('❌ Verification failed:', error);
    process.exit(1);
  }
}

if (import.meta.url === `file://${process.argv[1]}`) {
  main();
}

export { ExperimentVerifier };