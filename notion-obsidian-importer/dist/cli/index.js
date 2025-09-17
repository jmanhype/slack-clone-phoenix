#!/usr/bin/env node
"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const commander_1 = require("commander");
const chalk_1 = __importDefault(require("chalk"));
const ora_1 = __importDefault(require("ora"));
const inquirer_1 = __importDefault(require("inquirer"));
// import path from 'path';
// import fs from 'fs-extra';
const NotionImporter_1 = require("../core/NotionImporter");
const ObsidianConverter_1 = require("../core/ObsidianConverter");
const ConfigManager_1 = require("../core/ConfigManager");
const ProgressTracker_1 = require("../core/ProgressTracker");
const Logger_1 = __importDefault(require("../core/Logger"));
const wizard_1 = require("./wizard");
const program = new commander_1.Command();
class NotionObsidianCLI {
    constructor() {
        this.configManager = new ConfigManager_1.ConfigManager();
        this.progressTracker = new ProgressTracker_1.ProgressTracker();
    }
    async run() {
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
            .action(async (options) => {
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
            .action(async (options) => {
            await this.handleStatus(options);
        });
        program
            .command('validate')
            .description('Validate Notion API token and configuration')
            .option('-c, --config <path>', 'Path to configuration file')
            .option('-t, --token <token>', 'Notion API token to validate')
            .action(async (options) => {
            await this.handleValidate(options);
        });
        program.parse();
    }
    async handleImport(options) {
        try {
            // Load configuration
            if (options.config) {
                this.configManager = new ConfigManager_1.ConfigManager(options.config);
            }
            const config = await this.configManager.loadConfig();
            // Check if configuration is complete
            if (!config.notion.token && !options.token) {
                const { runWizard } = await inquirer_1.default.prompt([{
                        type: 'confirm',
                        name: 'runWizard',
                        message: 'No configuration found. Would you like to run the setup wizard?',
                        default: true
                    }]);
                if (runWizard) {
                    await (0, wizard_1.runConfigurationWizard)();
                }
                else {
                    console.log(chalk_1.default.red('Configuration required to proceed.'));
                    process.exit(1);
                }
            }
            // Override config with CLI options
            if (options.token)
                config.notion.token = options.token;
            if (options.output)
                config.obsidian.vaultPath = options.output;
            if (options.verbose && config.logging)
                config.logging.level = 'debug';
            // Initialize components
            const spinner = (0, ora_1.default)('Initializing importer...').start();
            const importer = new NotionImporter_1.NotionImporter(config, this.progressTracker);
            const converter = new ObsidianConverter_1.ObsidianConverter(config, this.progressTracker);
            // Set up progress tracking
            this.progressTracker.on('progress', (progress) => {
                this.updateSpinner(spinner, progress);
            });
            spinner.succeed('Importer initialized');
            // Test connection
            const connectionSpinner = (0, ora_1.default)('Testing Notion API connection...').start();
            const connected = await importer.testConnection();
            if (!connected) {
                connectionSpinner.fail('Failed to connect to Notion API');
                process.exit(1);
            }
            connectionSpinner.succeed('Connected to Notion API');
            // Start import process
            console.log(chalk_1.default.yellow('\n📥 Starting import process...\n'));
            const importSpinner = (0, ora_1.default)('Importing from Notion...').start();
            try {
                const result = await importer.import({ resumeFromProgress: true });
                importSpinner.succeed('Import completed');
                // Convert to Obsidian format
                const convertSpinner = (0, ora_1.default)('Converting to Obsidian format...').start();
                await converter.convertAndSave(result);
                convertSpinner.succeed('Conversion completed');
                // Display summary
                this.displaySummary(result);
            }
            catch (error) {
                importSpinner.fail('Import failed');
                Logger_1.default.error('Import error', error);
                process.exit(1);
            }
        }
        catch (error) {
            Logger_1.default.error('CLI error', error);
            process.exit(1);
        }
    }
    async handleConfig() {
        console.log(chalk_1.default.blue('\n🔧 Running configuration wizard...\n'));
        const config = await (0, wizard_1.runConfigurationWizard)();
        if (config) {
            await this.configManager.saveConfig(config);
            console.log(chalk_1.default.green('\n✅ Configuration saved successfully!\n'));
        }
    }
    async handleStatus(options) {
        if (options.config) {
            this.configManager = new ConfigManager_1.ConfigManager(options.config);
        }
        const hasProgress = await this.progressTracker.loadProgress();
        if (!hasProgress) {
            console.log(chalk_1.default.yellow('No import in progress.'));
            return;
        }
        const progress = this.progressTracker.getProgress();
        console.log(chalk_1.default.blue('\n📊 Import Status\n'));
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
    async handleValidate(options) {
        if (options.config) {
            this.configManager = new ConfigManager_1.ConfigManager(options.config);
        }
        const config = await this.configManager.loadConfig();
        if (options.token) {
            config.notion.token = options.token;
        }
        if (!config.notion.token) {
            console.log(chalk_1.default.red('Notion API token required for validation.'));
            process.exit(1);
        }
        const spinner = (0, ora_1.default)('Validating Notion API token...').start();
        try {
            const importer = new NotionImporter_1.NotionImporter(config);
            const isValid = await importer.testConnection();
            if (isValid) {
                spinner.succeed('Token is valid and API connection successful');
            }
            else {
                spinner.fail('Token is invalid or API connection failed');
                process.exit(1);
            }
        }
        catch (error) {
            spinner.fail('Validation failed');
            Logger_1.default.error('Validation error', error);
            process.exit(1);
        }
    }
    updateSpinner(spinner, progress) {
        const percentage = progress.percentage || 0;
        const current = progress.processedItems || 0;
        const total = progress.totalItems || 0;
        const phase = progress.currentPhase || 'processing';
        spinner.text = `[${percentage}%] ${phase}: ${current}/${total} items`;
    }
    displaySummary(result) {
        console.log(chalk_1.default.green('\n✅ Import completed successfully!\n'));
        console.log(chalk_1.default.blue('📊 Summary:'));
        console.log(`  Pages imported: ${result.totalPages || 0}`);
        console.log(`  Databases imported: ${result.totalDatabases || 0}`);
        console.log(`  Attachments downloaded: ${result.totalAttachments || 0}`);
        if (result.errors && result.errors.length > 0) {
            console.log(chalk_1.default.yellow(`  Errors encountered: ${result.errors.length}`));
        }
        console.log(chalk_1.default.green('\n🎉 Your Notion workspace has been successfully imported to Obsidian!'));
    }
}
// Main execution
const cli = new NotionObsidianCLI();
cli.run().catch(error => {
    Logger_1.default.error('Unexpected error', error);
    process.exit(1);
});
//# sourceMappingURL=index.js.map