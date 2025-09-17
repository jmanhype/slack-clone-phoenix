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
exports.ConfigManager = void 0;
const fs = __importStar(require("fs-extra"));
const path = __importStar(require("path"));
const yaml = __importStar(require("yaml"));
class ConfigManager {
    constructor(configPath) {
        this.configPath = configPath || path.join(process.cwd(), '.notion-obsidian-config.yaml');
        this.config = this.loadDefaultConfig();
    }
    loadDefaultConfig() {
        return {
            notion: {
                token: process.env.NOTION_TOKEN || '',
                version: '2022-06-28',
                rateLimitRequests: 3,
                rateLimitWindow: 1000,
            },
            obsidian: {
                vaultPath: process.env.OBSIDIAN_VAULT_PATH || './obsidian-vault',
                attachmentsFolder: 'attachments',
                templateFolder: 'templates',
                preserveStructure: true,
                convertImages: true,
                convertDatabases: true,
            },
            conversion: {
                preserveNotionIds: false,
                convertToggleLists: true,
                convertCallouts: true,
                convertEquations: true,
                convertTables: true,
                downloadImages: true,
                imageFormat: 'original',
                maxImageSize: 10485760,
                includeMetadata: true,
                frontmatterFormat: 'yaml',
            },
            progress: {
                autosaveInterval: 5000,
                showEstimates: true
            },
            performance: {
                maxConcurrentDownloads: 3,
                maxRetries: 3,
                retryDelay: 1000,
                timeout: 30000,
                cacheEnabled: true,
                cacheDirectory: '.cache',
            },
            logging: {
                level: 'info',
                outputFile: 'notion-obsidian-import.log',
                console: true
            },
        };
    }
    async loadConfig() {
        try {
            if (await fs.pathExists(this.configPath)) {
                const content = await fs.readFile(this.configPath, 'utf-8');
                const fileConfig = this.configPath.endsWith('.yaml') || this.configPath.endsWith('.yml')
                    ? yaml.parse(content)
                    : JSON.parse(content);
                this.config = this.mergeConfigs(this.config, fileConfig);
            }
        }
        catch (error) {
            console.error(`Failed to load config from ${this.configPath}:`, error);
        }
        return this.config;
    }
    async saveConfig(config) {
        if (config) {
            this.config = this.mergeConfigs(this.config, config);
        }
        const content = this.configPath.endsWith('.yaml') || this.configPath.endsWith('.yml')
            ? yaml.stringify(this.config)
            : JSON.stringify(this.config, null, 2);
        await fs.writeFile(this.configPath, content, 'utf-8');
    }
    mergeConfigs(base, override) {
        return {
            ...base,
            notion: { ...base.notion, ...(override.notion || {}) },
            obsidian: { ...base.obsidian, ...(override.obsidian || {}) },
            conversion: { ...base.conversion, ...(override.conversion || {}) },
            progress: { ...base.progress, ...(override.progress || {}) },
            performance: { ...base.performance, ...(override.performance || {}) },
            logging: { ...base.logging, ...(override.logging || {}) },
        };
    }
    get() {
        return this.config;
    }
    set(key, value) {
        const keys = key.split('.');
        let obj = this.config;
        for (let i = 0; i < keys.length - 1; i++) {
            if (!obj[keys[i]]) {
                obj[keys[i]] = {};
            }
            obj = obj[keys[i]];
        }
        obj[keys[keys.length - 1]] = value;
    }
    validate() {
        const errors = [];
        if (!this.config.notion.token) {
            errors.push('Notion API token is required');
        }
        if (!this.config.obsidian.vaultPath) {
            errors.push('Obsidian vault path is required');
        }
        return {
            valid: errors.length === 0,
            errors,
        };
    }
    async generateSampleConfig(outputPath) {
        const samplePath = outputPath || path.join(process.cwd(), 'notion-obsidian-config.sample.yaml');
        const sampleConfig = this.loadDefaultConfig();
        sampleConfig.notion.token = 'YOUR_NOTION_API_TOKEN_HERE';
        sampleConfig.obsidian.vaultPath = '/path/to/your/obsidian/vault';
        await fs.writeFile(samplePath, yaml.stringify(sampleConfig), 'utf-8');
    }
}
exports.ConfigManager = ConfigManager;
exports.default = ConfigManager;
//# sourceMappingURL=ConfigManager.js.map