#!/usr/bin/env node

import { Command } from 'commander';
import chalk from 'chalk';
import ora from 'ora';
import inquirer from 'inquirer';
// import path from 'path';
// import fs from 'fs-extra';
import { NotionImporter } from '../core/NotionImporter';
import { ObsidianConverter } from '../core/ObsidianConverter';
import { ConfigManager } from '../core/ConfigManager';
import { ProgressTracker } from '../core/ProgressTracker';
import Logger from '../core/Logger';
import { runConfigurationWizard } from './wizard';

const program = new Command();

interface CliOptions {
  config?: string;
  output?: string;
  token?: string;
  verbose?: boolean;
  dryRun?: boolean;
  force?: boolean;
}

class NotionObsidianCLI {
  private configManager: ConfigManager;
  private progressTracker: ProgressTracker;

  constructor() {
    this.configManager = new ConfigManager();
    this.progressTracker = new ProgressTracker();
  }

  async run(): Promise<void> {
    program
      .name('notion-obsidian-importer')
      .description('Import Notion workspace to Obsidian with progressive download and conversion')
      .version('1.0.0');

    program
      .command('import')
      .description('Import Notion workspace to Obsidian')
      .option('-c, --config <path>', 'Path to configuration file')
      .option('-o, --output <path>', 'Output directory for Obsidian vault')
      .option('-t, --token <token>', 'Notion API token')
      .option('-v, --verbose', 'Enable verbose logging')
      .option('--dry-run', 'Preview changes without writing files')
      .option('--force', 'Force import even if output directory exists')
      .action(async (options: CliOptions) => {
        await this.handleImport(options);
      });

    program
      .command('config')
      .description('Run configuration wizard')
      .action(async () => {
        await this.handleConfig();
      });

    program
      .command('status')
      .description('Check import progress and status')
      .option('-c, --config <path>', 'Path to configuration file')
      .action(async (options: CliOptions) => {
        await this.handleStatus(options);
      });

    program
      .command('validate')
      .description('Validate Notion API token and configuration')
      .option('-c, --config <path>', 'Path to configuration file')
      .option('-t, --token <token>', 'Notion API token to validate')
      .action(async (options: CliOptions) => {
        await this.handleValidate(options);
      });

    program.parse();
  }

  private async handleImport(options: CliOptions): Promise<void> {
    try {
      // Load configuration
      if (options.config) {
        this.configManager = new ConfigManager(options.config);
      }
      
      const config = await this.configManager.loadConfig();
      
      // Check if configuration is complete
      if (!config.notion.token && !options.token) {
        const { runWizard } = await inquirer.prompt([{
          type: 'confirm',
          name: 'runWizard',
          message: 'No configuration found. Would you like to run the setup wizard?',
          default: true
        }]);
        
        if (runWizard) {
          await runConfigurationWizard();
        } else {
          console.log(chalk.red('Configuration required to proceed.'));
          process.exit(1);
        }
      }

      // Override config with CLI options
      if (options.token) config.notion.token = options.token;
      if (options.output) config.obsidian.vaultPath = options.output;
      if (options.verbose && config.logging) config.logging.level = 'debug';

      // Initialize components
      const spinner = ora('Initializing importer...').start();
      
      const importer = new NotionImporter(config, this.progressTracker);
      const converter = new ObsidianConverter(config, this.progressTracker);
      
      // Set up progress tracking
      this.progressTracker.on('progress', (progress: any) => {
        this.updateSpinner(spinner, progress);
      });
      
      spinner.succeed('Importer initialized');

      // Test connection
      const connectionSpinner = ora('Testing Notion API connection...').start();
      const connected = await importer.testConnection();
      
      if (!connected) {
        connectionSpinner.fail('Failed to connect to Notion API');
        process.exit(1);
      }
      
      connectionSpinner.succeed('Connected to Notion API');

      // Start import process
      console.log(chalk.yellow('\n📥 Starting import process...\n'));

      const importSpinner = ora('Importing from Notion...').start();
      
      try {
        const result = await importer.import({ resumeFromProgress: true });
        importSpinner.succeed('Import completed');
        
        // Convert to Obsidian format
        const convertSpinner = ora('Converting to Obsidian format...').start();
        await converter.convertAndSave(result);
        convertSpinner.succeed('Conversion completed');
        
        // Display summary
        this.displaySummary(result);
        
      } catch (error) {
        importSpinner.fail('Import failed');
        Logger.error('Import error', error);
        process.exit(1);
      }
      
    } catch (error) {
      Logger.error('CLI error', error);
      process.exit(1);
    }
  }

  private async handleConfig(): Promise<void> {
    console.log(chalk.blue('\n🔧 Running configuration wizard...\n'));
    const config = await runConfigurationWizard();
    
    if (config) {
      await this.configManager.saveConfig(config);
      console.log(chalk.green('\n✅ Configuration saved successfully!\n'));
    }
  }

  private async handleStatus(options: CliOptions): Promise<void> {
    if (options.config) {
      this.configManager = new ConfigManager(options.config);
    }
    
    const hasProgress = await this.progressTracker.loadProgress();
    
    if (!hasProgress) {
      console.log(chalk.yellow('No import in progress.'));
      return;
    }
    
    const progress = this.progressTracker.getProgress();
    
    console.log(chalk.blue('\n📊 Import Status\n'));
    console.log(`Status: ${progress.status}`);
    console.log(`Phase: ${progress.currentPhase}`);
    console.log(`Progress: ${progress.percentage}%`);
    console.log(`Items: ${progress.processedItems} / ${progress.totalItems}`);
    console.log(`Failed: ${progress.failedItems}`);
    console.log(`Skipped: ${progress.skippedItems}`);
    
    if (progress.currentItem) {
      console.log(`Current: ${progress.currentItem}`);
    }
    
    if (progress.estimatedTimeRemaining && progress.estimatedTimeRemaining > 0) {
      const minutes = Math.floor(progress.estimatedTimeRemaining / 60000);
      console.log(`ETA: ${minutes} minutes`);
    }
  }

  private async handleValidate(options: CliOptions): Promise<void> {
    if (options.config) {
      this.configManager = new ConfigManager(options.config);
    }
    
    const config = await this.configManager.loadConfig();
    
    if (options.token) {
      config.notion.token = options.token;
    }
    
    if (!config.notion.token) {
      console.log(chalk.red('Notion API token required for validation.'));
      process.exit(1);
    }
    
    const spinner = ora('Validating Notion API token...').start();
    
    try {
      const importer = new NotionImporter(config);
      const isValid = await importer.testConnection();
      
      if (isValid) {
        spinner.succeed('Token is valid and API connection successful');
      } else {
        spinner.fail('Token is invalid or API connection failed');
        process.exit(1);
      }
    } catch (error) {
      spinner.fail('Validation failed');
      Logger.error('Validation error', error);
      process.exit(1);
    }
  }

  private updateSpinner(spinner: any, progress: any): void {
    const percentage = progress.percentage || 0;
    const current = progress.processedItems || 0;
    const total = progress.totalItems || 0;
    const phase = progress.currentPhase || 'processing';
    
    spinner.text = `[${percentage}%] ${phase}: ${current}/${total} items`;
  }

  private displaySummary(result: any): void {
    console.log(chalk.green('\n✅ Import completed successfully!\n'));
    console.log(chalk.blue('📊 Summary:'));
    console.log(`  Pages imported: ${result.totalPages || 0}`);
    console.log(`  Databases imported: ${result.totalDatabases || 0}`);
    console.log(`  Attachments downloaded: ${result.totalAttachments || 0}`);
    
    if (result.errors && result.errors.length > 0) {
      console.log(chalk.yellow(`  Errors encountered: ${result.errors.length}`));
    }
    
    console.log(chalk.green('\n🎉 Your Notion workspace has been successfully imported to Obsidian!'));
  }
}

// Main execution
const cli = new NotionObsidianCLI();
cli.run().catch(error => {
  Logger.error('Unexpected error', error);
  process.exit(1);
});