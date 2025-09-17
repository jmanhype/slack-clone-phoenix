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
Object.defineProperty(exports, "__esModule", { value: true });
exports.configManager = exports.ConfigManager = void 0;
exports.loadConfig = loadConfig;
exports.getConfig = getConfig;
exports.createSampleConfig = createSampleConfig;
const fs = __importStar(require("fs-extra"));
const path = __importStar(require("path"));
const yaml = __importStar(require("yaml"));
/**
 * Default configuration values
 */
const DEFAULT_CONFIG = {
    batchSize: 50,
    concurrency: 3,
    retryAttempts: 3,
    progressTracking: true,
    notion: {
        token: '', // Will be provided via environment or config file
        version: '2022-06-28',
        rateLimitRequests: 3,
        rateLimitWindow: 1000
    },
    obsidian: {
        vaultPath: '', // Will be provided via environment or config file
        attachmentsFolder: 'attachments',
        templateFolder: 'templates',
        preserveStructure: true,
        convertImages: true,
        convertDatabases: true
    }
};
/**
 * Configuration manager for the importer
 */
class ConfigManager {
    constructor() {
        this.config = null;
        this.configPath = '';
    }
    /**
     * Loads configuration from file or environment
     */
    async loadConfig(configPath) {
        // Try to load from file first
        if (configPath && await fs.pathExists(configPath)) {
            this.configPath = configPath;
            return await this.loadFromFile(configPath);
        }
        // Try to load from default locations
        const defaultPaths = [
            './notion-obsidian.config.yaml',
            './notion-obsidian.config.yml',
            './notion-obsidian.config.json',
            path.join(process.cwd(), 'notion-obsidian.config.yaml'),
            path.join(process.cwd(), 'notion-obsidian.config.yml'),
            path.join(process.cwd(), 'notion-obsidian.config.json')
        ];
        for (const defaultPath of defaultPaths) {
            if (await fs.pathExists(defaultPath)) {
                this.configPath = defaultPath;
                return await this.loadFromFile(defaultPath);
            }
        }
        // Fall back to environment variables
        return this.loadFromEnvironment();
    }
    /**
     * Loads configuration from a file
     */
    async loadFromFile(filePath) {
        try {
            const fileContent = await fs.readFile(filePath, 'utf8');
            const ext = path.extname(filePath).toLowerCase();
            let fileConfig;
            if (ext === '.json') {
                fileConfig = JSON.parse(fileContent);
            }
            else if (ext === '.yaml' || ext === '.yml') {
                fileConfig = yaml.parse(fileContent);
            }
            else {
                throw new Error(`Unsupported config file format: ${ext}`);
            }
            this.config = this.mergeConfig(fileConfig);
            this.validateConfig(this.config);
            return this.config;
        }
        catch (error) {
            throw new Error(`Failed to load config from ${filePath}: ${error.message}`);
        }
    }
    /**
     * Loads configuration from environment variables
     */
    loadFromEnvironment() {
        const envConfig = {
            notion: {
                token: process.env.NOTION_TOKEN || '',
                version: process.env.NOTION_VERSION,
                rateLimitRequests: process.env.NOTION_RATE_LIMIT_REQUESTS
                    ? parseInt(process.env.NOTION_RATE_LIMIT_REQUESTS, 10)
                    : undefined,
                rateLimitWindow: process.env.NOTION_RATE_LIMIT_WINDOW
                    ? parseInt(process.env.NOTION_RATE_LIMIT_WINDOW, 10)
                    : undefined
            },
            obsidian: {
                vaultPath: process.env.OBSIDIAN_VAULT_PATH || '',
                attachmentsFolder: process.env.OBSIDIAN_ATTACHMENTS_FOLDER,
                templateFolder: process.env.OBSIDIAN_TEMPLATE_FOLDER,
                preserveStructure: process.env.OBSIDIAN_PRESERVE_STRUCTURE
                    ? process.env.OBSIDIAN_PRESERVE_STRUCTURE === 'true'
                    : undefined,
                convertImages: process.env.OBSIDIAN_CONVERT_IMAGES
                    ? process.env.OBSIDIAN_CONVERT_IMAGES === 'true'
                    : undefined,
                convertDatabases: process.env.OBSIDIAN_CONVERT_DATABASES
                    ? process.env.OBSIDIAN_CONVERT_DATABASES === 'true'
                    : undefined
            },
            batchSize: process.env.BATCH_SIZE
                ? parseInt(process.env.BATCH_SIZE, 10)
                : undefined,
            concurrency: process.env.CONCURRENCY
                ? parseInt(process.env.CONCURRENCY, 10)
                : undefined,
            retryAttempts: process.env.RETRY_ATTEMPTS
                ? parseInt(process.env.RETRY_ATTEMPTS, 10)
                : undefined,
            progressTracking: process.env.PROGRESS_TRACKING
                ? process.env.PROGRESS_TRACKING === 'true'
                : undefined
        };
        this.config = this.mergeConfig(envConfig);
        this.validateConfig(this.config);
        return this.config;
    }
    /**
     * Merges partial config with defaults
     */
    mergeConfig(partialConfig) {
        return {
            notion: {
                ...DEFAULT_CONFIG.notion,
                ...partialConfig.notion
            },
            obsidian: {
                ...DEFAULT_CONFIG.obsidian,
                ...partialConfig.obsidian
            },
            batchSize: partialConfig.batchSize ?? DEFAULT_CONFIG.batchSize,
            concurrency: partialConfig.concurrency ?? DEFAULT_CONFIG.concurrency,
            retryAttempts: partialConfig.retryAttempts ?? DEFAULT_CONFIG.retryAttempts,
            progressTracking: partialConfig.progressTracking ?? DEFAULT_CONFIG.progressTracking
        };
    }
    /**
     * Validates the configuration
     */
    validateConfig(config) {
        const errors = [];
        // Validate Notion config
        if (!config.notion.token || config.notion.token.trim() === '') {
            errors.push('Notion token is required');
        }
        if (config.notion.rateLimitRequests && config.notion.rateLimitRequests < 1) {
            errors.push('Notion rate limit requests must be greater than 0');
        }
        if (config.notion.rateLimitWindow && config.notion.rateLimitWindow < 100) {
            errors.push('Notion rate limit window must be at least 100ms');
        }
        // Validate Obsidian config
        if (!config.obsidian.vaultPath || config.obsidian.vaultPath.trim() === '') {
            errors.push('Obsidian vault path is required');
        }
        // Validate general config
        if (config.batchSize && config.batchSize < 1) {
            errors.push('Batch size must be greater than 0');
        }
        if (config.concurrency && config.concurrency < 1) {
            errors.push('Concurrency must be greater than 0');
        }
        if (config.retryAttempts && config.retryAttempts < 0) {
            errors.push('Retry attempts cannot be negative');
        }
        if (errors.length > 0) {
            throw new Error(`Configuration validation failed:\n- ${errors.join('\n- ')}`);
        }
    }
    /**
     * Saves current configuration to file
     */
    async saveConfig(filePath) {
        if (!this.config) {
            throw new Error('No configuration loaded');
        }
        const targetPath = filePath || this.configPath || './notion-obsidian.config.yaml';
        const ext = path.extname(targetPath).toLowerCase();
        let content;
        if (ext === '.json') {
            content = JSON.stringify(this.config, null, 2);
        }
        else {
            content = yaml.stringify(this.config);
        }
        await fs.writeFile(targetPath, content, 'utf8');
    }
    /**
     * Creates a sample configuration file
     */
    async createSampleConfig(filePath = './notion-obsidian.config.yaml') {
        const sampleConfig = {
            notion: {
                token: 'YOUR_NOTION_TOKEN_HERE',
                version: '2022-06-28',
                rateLimitRequests: 3,
                rateLimitWindow: 1000
            },
            obsidian: {
                vaultPath: '/path/to/your/obsidian/vault',
                attachmentsFolder: 'attachments',
                templateFolder: 'templates',
                preserveStructure: true,
                convertImages: true,
                convertDatabases: true
            },
            batchSize: 50,
            concurrency: 3,
            retryAttempts: 3,
            progressTracking: true
        };
        const ext = path.extname(filePath).toLowerCase();
        let content;
        if (ext === '.json') {
            content = JSON.stringify(sampleConfig, null, 2);
        }
        else {
            content = yaml.stringify(sampleConfig);
        }
        await fs.writeFile(filePath, content, 'utf8');
    }
    /**
     * Gets the current configuration
     */
    getConfig() {
        return this.config;
    }
    /**
     * Updates configuration values
     */
    updateConfig(updates) {
        if (!this.config) {
            throw new Error('No configuration loaded');
        }
        this.config = this.mergeConfig({
            ...this.config,
            ...updates,
            notion: {
                ...this.config.notion,
                ...updates.notion
            },
            obsidian: {
                ...this.config.obsidian,
                ...updates.obsidian
            }
        });
        this.validateConfig(this.config);
    }
    /**
     * Gets configuration schema for validation
     */
    getConfigSchema() {
        return {
            type: 'object',
            required: ['notion', 'obsidian'],
            properties: {
                notion: {
                    type: 'object',
                    required: ['token'],
                    properties: {
                        token: { type: 'string', minLength: 1 },
                        version: { type: 'string' },
                        rateLimitRequests: { type: 'number', minimum: 1 },
                        rateLimitWindow: { type: 'number', minimum: 100 }
                    }
                },
                obsidian: {
                    type: 'object',
                    required: ['vaultPath'],
                    properties: {
                        vaultPath: { type: 'string', minLength: 1 },
                        attachmentsFolder: { type: 'string' },
                        templateFolder: { type: 'string' },
                        preserveStructure: { type: 'boolean' },
                        convertImages: { type: 'boolean' },
                        convertDatabases: { type: 'boolean' }
                    }
                },
                batchSize: { type: 'number', minimum: 1 },
                concurrency: { type: 'number', minimum: 1 },
                retryAttempts: { type: 'number', minimum: 0 },
                progressTracking: { type: 'boolean' }
            }
        };
    }
}
exports.ConfigManager = ConfigManager;
// Export singleton instance
exports.configManager = new ConfigManager();
// Export utility functions
async function loadConfig(configPath) {
    return await exports.configManager.loadConfig(configPath);
}
function getConfig() {
    return exports.configManager.getConfig();
}
async function createSampleConfig(filePath) {
    return await exports.configManager.createSampleConfig(filePath);
}
//# sourceMappingURL=index.js.map