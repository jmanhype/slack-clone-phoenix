import { ProgressTracker } from './ProgressTracker';
import { ImportConfig, ImportResult } from '../types';
export declare class NotionImporter {
    private client;
    private progressTracker;
    private _config;
    constructor(_config: ImportConfig, progressTracker?: ProgressTracker);
    testConnection(): Promise<boolean>;
    discoverContent(): Promise<{
        pages: any[];
        databases: any[];
        totalItems: number;
    }>;
    downloadPage(pageId: string): Promise<any>;
    downloadDatabase(databaseId: string): Promise<any>;
    downloadFile(url: string, outputPath: string): Promise<void>;
    import(options?: {
        pages?: string[];
        databases?: string[];
        resumeFromProgress?: boolean;
    }): Promise<ImportResult>;
    getProgressTracker(): ProgressTracker;
}
export default NotionImporter;
//# sourceMappingURL=NotionImporter.d.ts.map