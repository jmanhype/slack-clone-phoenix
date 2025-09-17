import { ImportConfig } from '../types';
export declare class ConfigManager {
    private config;
    private configPath;
    constructor(configPath?: string);
    private loadDefaultConfig;
    loadConfig(): Promise<ImportConfig>;
    saveConfig(config?: Partial<ImportConfig>): Promise<void>;
    private mergeConfigs;
    get(): ImportConfig;
    set(key: string, value: any): void;
    validate(): {
        valid: boolean;
        errors: string[];
    };
    generateSampleConfig(outputPath?: string): Promise<void>;
}
export default ConfigManager;
//# sourceMappingURL=ConfigManager.d.ts.map