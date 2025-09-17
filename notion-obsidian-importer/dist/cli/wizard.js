"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.runConfigurationWizard = runConfigurationWizard;
exports.validateNotionToken = validateNotionToken;
const inquirer_1 = __importDefault(require("inquirer"));
const fs = __importStar(require("fs-extra"));
const path = __importStar(require("path"));
const chalk_1 = __importDefault(require("chalk"));
const NotionImporter_1 = require("../core/NotionImporter");
const ConfigManager_1 = require("../core/ConfigManager");
async function runConfigurationWizard() {
    console.log(chalk_1.default.blue('\n🔮 Notion-Obsidian Importer Configuration Wizard\n'));
    console.log(chalk_1.default.gray('This wizard will help you set up the importer with your preferences.\n'));
    try {
        // Basic configuration
        const basicAnswers = await inquirer_1.default.prompt([
            {
                type: 'password',
                name: 'notionToken',
                message: 'Enter your Notion API integration token:',
                validate: async (input) => {
                    if (!input)
                        return 'Token is required';
                    // Test the token
                    console.log(chalk_1.default.gray('\n  Testing token...'));
                    const configManager = new ConfigManager_1.ConfigManager();
                    const config = await configManager.loadConfig();
                    config.notion.token = input;
                    const importer = new NotionImporter_1.NotionImporter(config);
                    const isValid = await importer.testConnection();
                    if (isValid) {
                        console.log(chalk_1.default.green('  ✓ Token validated successfully!\n'));
                        return true;
                    }
                    else {
                        return 'Invalid token or unable to connect to Notion API';
                    }
                }
            },
            {
                type: 'input',
                name: 'vaultPath',
                message: 'Enter the path to your Obsidian vault:',
                default: './obsidian-vault',
                validate: async (input) => {
                    const resolvedPath = path.resolve(input);
                    const exists = await fs.pathExists(resolvedPath);
                    if (!exists) {
                        const { create } = await inquirer_1.default.prompt([{
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
        const { configureAdvanced } = await inquirer_1.default.prompt([{
                type: 'confirm',
                name: 'configureAdvanced',
                message: 'Would you like to configure advanced options?',
                default: false
            }]);
        let advancedAnswers = {};
        if (configureAdvanced) {
            advancedAnswers = await inquirer_1.default.prompt([
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
                    validate: (input) => {
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
                    when: (answers) => answers.downloadImages
                },
                {
                    type: 'number',
                    name: 'maxImageSize',
                    message: 'Maximum image size in MB (0 for unlimited):',
                    default: 10,
                    when: (answers) => answers.downloadImages
                }
            ]);
        }
        // Confirm configuration
        console.log(chalk_1.default.blue('\n📋 Configuration Summary:\n'));
        console.log(`  Notion Token: ${chalk_1.default.green('[HIDDEN]')}`);
        console.log(`  Vault Path: ${chalk_1.default.green(basicAnswers.vaultPath)}`);
        console.log(`  File Organization: ${chalk_1.default.green(basicAnswers.fileOrganization)}`);
        if (configureAdvanced) {
            console.log(`  Download Images: ${chalk_1.default.green(advancedAnswers.downloadImages ? 'Yes' : 'No')}`);
            console.log(`  Convert Databases: ${chalk_1.default.green(advancedAnswers.convertDatabases ? 'Yes' : 'No')}`);
            console.log(`  Preserve IDs: ${chalk_1.default.green(advancedAnswers.preserveNotionIds ? 'Yes' : 'No')}`);
            console.log(`  Concurrency: ${chalk_1.default.green(advancedAnswers.concurrency)}`);
        }
        const { confirm } = await inquirer_1.default.prompt([{
                type: 'confirm',
                name: 'confirm',
                message: '\nSave this configuration?',
                default: true
            }]);
        if (!confirm) {
            console.log(chalk_1.default.yellow('\nConfiguration cancelled.'));
            return null;
        }
        // Build configuration object
        const config = {
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
    }
    catch (error) {
        console.error(chalk_1.default.red('\n❌ Configuration wizard failed:'), error);
        return null;
    }
}
async function validateNotionToken(token) {
    try {
        const configManager = new ConfigManager_1.ConfigManager();
        const config = await configManager.loadConfig();
        config.notion.token = token;
        const importer = new NotionImporter_1.NotionImporter(config);
        return await importer.testConnection();
    }
    catch (error) {
        return false;
    }
}
//# sourceMappingURL=wizard.js.map