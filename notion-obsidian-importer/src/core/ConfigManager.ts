import * as fs from 'fs-extra';
import * as path from 'path';
import * as yaml from 'yaml';
import { ImportConfig } from '../types';

export class ConfigManager {
  private config: ImportConfig;
  private configPath: string;

  constructor(configPath?: string) {
    this.configPath = configPath || path.join(process.cwd(), '.notion-obsidian-config.yaml');
    this.config = this.loadDefaultConfig();
  }

  private loadDefaultConfig(): ImportConfig {
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

  async loadConfig(): Promise<ImportConfig> {
    try {
      if (await fs.pathExists(this.configPath)) {
        const content = await fs.readFile(this.configPath, 'utf-8');
        const fileConfig = this.configPath.endsWith('.yaml') || this.configPath.endsWith('.yml')
          ? yaml.parse(content)
          : JSON.parse(content);
        
        this.config = this.mergeConfigs(this.config, fileConfig);
      }
    } catch (error) {
      console.error(`Failed to load config from ${this.configPath}:`, error);
    }
    
    return this.config;
  }

  async saveConfig(config?: Partial<ImportConfig>): Promise<void> {
    if (config) {
      this.config = this.mergeConfigs(this.config, config);
    }

    const content = this.configPath.endsWith('.yaml') || this.configPath.endsWith('.yml')
      ? yaml.stringify(this.config)
      : JSON.stringify(this.config, null, 2);

    await fs.writeFile(this.configPath, content, 'utf-8');
  }

  private mergeConfigs(base: ImportConfig, override: any): ImportConfig {
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

  get(): ImportConfig {
    return this.config;
  }

  set(key: string, value: any): void {
    const keys = key.split('.');
    let obj: any = this.config;
    
    for (let i = 0; i < keys.length - 1; i++) {
      if (!obj[keys[i]]) {
        obj[keys[i]] = {};
      }
      obj = obj[keys[i]];
    }
    
    obj[keys[keys.length - 1]] = value;
  }

  validate(): { valid: boolean; errors: string[] } {
    const errors: string[] = [];

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

  async generateSampleConfig(outputPath?: string): Promise<void> {
    const samplePath = outputPath || path.join(process.cwd(), 'notion-obsidian-config.sample.yaml');
    const sampleConfig = this.loadDefaultConfig();
    sampleConfig.notion.token = 'YOUR_NOTION_API_TOKEN_HERE';
    sampleConfig.obsidian.vaultPath = '/path/to/your/obsidian/vault';
    
    await fs.writeFile(samplePath, yaml.stringify(sampleConfig), 'utf-8');
  }
}

export default ConfigManager;