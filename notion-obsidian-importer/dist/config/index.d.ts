import { ImportConfig } from '../types';
/**
 * Configuration manager for the importer
 */
export declare class ConfigManager {
    private config;
    private configPath;
    /**
     * Loads configuration from file or environment
     */
    loadConfig(configPath?: string): Promise<ImportConfig>;
    /**
     * Loads configuration from a file
     */
    private loadFromFile;
    /**
     * Loads configuration from environment variables
     */
    private loadFromEnvironment;
    /**
     * Merges partial config with defaults
     */
    private mergeConfig;
    /**
     * Validates the configuration
     */
    private validateConfig;
    /**
     * Saves current configuration to file
     */
    saveConfig(filePath?: string): Promise<void>;
    /**
     * Creates a sample configuration file
     */
    createSampleConfig(filePath?: string): Promise<void>;
    /**
     * Gets the current configuration
     */
    getConfig(): ImportConfig | null;
    /**
     * Updates configuration values
     */
    updateConfig(updates: Partial<ImportConfig>): void;
    /**
     * Gets configuration schema for validation
     */
    getConfigSchema(): any;
}
export declare const configManager: ConfigManager;
export declare function loadConfig(configPath?: string): Promise<ImportConfig>;
export declare function getConfig(): ImportConfig | null;
export declare function createSampleConfig(filePath?: string): Promise<void>;
//# sourceMappingURL=index.d.ts.map