import inquirer from 'inquirer';
import * as fs from 'fs-extra';
import * as path from 'path';
import chalk from 'chalk';
import { ImportConfig } from '../types';
import { NotionImporter } from '../core/NotionImporter';
import { ConfigManager } from '../core/ConfigManager';

export async function runConfigurationWizard(): Promise<Partial<ImportConfig> | null> {
  console.log(chalk.blue('\n🔮 Notion-Obsidian Importer Configuration Wizard\n'));
  console.log(chalk.gray('This wizard will help you set up the importer with your preferences.\n'));

  try {
    // Basic configuration
    const basicAnswers = await inquirer.prompt([
      {
        type: 'password',
        name: 'notionToken',
        message: 'Enter your Notion API integration token:',
        validate: async (input: string) => {
          if (!input) return 'Token is required';
          
          // Test the token
          console.log(chalk.gray('\n  Testing token...'));
          const configManager = new ConfigManager();
          const config = await configManager.loadConfig();
          config.notion.token = input;
          
          const importer = new NotionImporter(config);
          const isValid = await importer.testConnection();
          
          if (isValid) {
            console.log(chalk.green('  ✓ Token validated successfully!\n'));
            return true;
          } else {
            return 'Invalid token or unable to connect to Notion API';
          }
        }
      },
      {
        type: 'input',
        name: 'vaultPath',
        message: 'Enter the path to your Obsidian vault:',
        default: './obsidian-vault',
        validate: async (input: string) => {
          const resolvedPath = path.resolve(input);
          const exists = await fs.pathExists(resolvedPath);
          
          if (!exists) {
            const { create } = await inquirer.prompt([{
              type: 'confirm',
              name: 'create',
              message: `Directory doesn't exist. Create it?`,
              default: true
            }]);
            
            if (create) {
              await fs.ensureDir(resolvedPath);
              return true;
            }
            return 'Please provide a valid directory path';
          }
          return true;
        }
      },
      {
        type: 'list',
        name: 'fileOrganization',
        message: 'How should files be organized?',
        choices: [
          { name: 'Hierarchical (preserve Notion structure)', value: 'hierarchical' },
          { name: 'Flat (all files in one directory)', value: 'flat' },
          { name: 'By type (pages, databases, attachments)', value: 'type' }
        ],
        default: 'hierarchical'
      }
    ]);

    // Advanced options
    const { configureAdvanced } = await inquirer.prompt([{
      type: 'confirm',
      name: 'configureAdvanced',
      message: 'Would you like to configure advanced options?',
      default: false
    }]);

    let advancedAnswers: any = {};
    if (configureAdvanced) {
      advancedAnswers = await inquirer.prompt([
        {
          type: 'confirm',
          name: 'downloadImages',
          message: 'Download images and attachments?',
          default: true
        },
        {
          type: 'confirm',
          name: 'convertDatabases',
          message: 'Convert Notion databases to Obsidian tables?',
          default: true
        },
        {
          type: 'confirm',
          name: 'preserveNotionIds',
          message: 'Preserve Notion IDs in filenames?',
          default: false
        },
        {
          type: 'number',
          name: 'concurrency',
          message: 'Number of concurrent downloads (1-10):',
          default: 3,
          validate: (input: number) => {
            if (input < 1 || input > 10) {
              return 'Please enter a number between 1 and 10';
            }
            return true;
          }
        },
        {
          type: 'list',
          name: 'imageFormat',
          message: 'Preferred image format:',
          choices: ['original', 'webp', 'png', 'jpg'],
          default: 'original',
          when: (answers: any) => answers.downloadImages
        },
        {
          type: 'number',
          name: 'maxImageSize',
          message: 'Maximum image size in MB (0 for unlimited):',
          default: 10,
          when: (answers: any) => answers.downloadImages
        }
      ]);
    }

    // Confirm configuration
    console.log(chalk.blue('\n📋 Configuration Summary:\n'));
    console.log(`  Notion Token: ${chalk.green('[HIDDEN]')}`);
    console.log(`  Vault Path: ${chalk.green(basicAnswers.vaultPath)}`);
    console.log(`  File Organization: ${chalk.green(basicAnswers.fileOrganization)}`);
    
    if (configureAdvanced) {
      console.log(`  Download Images: ${chalk.green(advancedAnswers.downloadImages ? 'Yes' : 'No')}`);
      console.log(`  Convert Databases: ${chalk.green(advancedAnswers.convertDatabases ? 'Yes' : 'No')}`);
      console.log(`  Preserve IDs: ${chalk.green(advancedAnswers.preserveNotionIds ? 'Yes' : 'No')}`);
      console.log(`  Concurrency: ${chalk.green(advancedAnswers.concurrency)}`);
    }

    const { confirm } = await inquirer.prompt([{
      type: 'confirm',
      name: 'confirm',
      message: '\nSave this configuration?',
      default: true
    }]);

    if (!confirm) {
      console.log(chalk.yellow('\nConfiguration cancelled.'));
      return null;
    }

    // Build configuration object
    const config: Partial<ImportConfig> = {
      notion: {
        token: basicAnswers.notionToken,
        version: '2022-06-28',
        rateLimitRequests: 3,
        rateLimitWindow: 1000
      },
      obsidian: {
        vaultPath: basicAnswers.vaultPath,
        attachmentsFolder: 'attachments',
        templateFolder: 'templates',
        preserveStructure: basicAnswers.fileOrganization === 'hierarchical',
        convertImages: advancedAnswers.downloadImages ?? true,
        convertDatabases: advancedAnswers.convertDatabases ?? true
      },
      conversion: {
        preserveNotionIds: advancedAnswers.preserveNotionIds ?? false,
        convertToggleLists: true,
        convertCallouts: true,
        convertEquations: true,
        convertTables: true,
        downloadImages: advancedAnswers.downloadImages ?? true,
        imageFormat: advancedAnswers.imageFormat ?? 'original',
        maxImageSize: (advancedAnswers.maxImageSize ?? 10) * 1024 * 1024,
        includeMetadata: true,
        frontmatterFormat: 'yaml'
      },
      performance: {
        maxConcurrentDownloads: advancedAnswers.concurrency ?? 3,
        maxRetries: 3,
        retryDelay: 1000,
        timeout: 30000,
        cacheEnabled: true,
        cacheDirectory: '.cache'
      }
    };

    return config;

  } catch (error) {
    console.error(chalk.red('\n❌ Configuration wizard failed:'), error);
    return null;
  }
}

export async function validateNotionToken(token: string): Promise<boolean> {
  try {
    const configManager = new ConfigManager();
    const config = await configManager.loadConfig();
    config.notion.token = token;
    
    const importer = new NotionImporter(config);
    return await importer.testConnection();
  } catch (error) {
    return false;
  }
}