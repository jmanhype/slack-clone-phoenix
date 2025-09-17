import { ImportConfig, ProgressInfo, ImportError, AttachmentInfo } from './types';
export interface ImportResult {
    success: boolean;
    importedPages: number;
    importedDatabases: number;
    downloadedAttachments: number;
    errors: ImportError[];
    importedFiles: string[];
    duration: number;
}
export declare class NotionObsidianImporter {
    private apiClient;
    private contentConverter;
    private databaseConverter;
    private downloader;
    private obsidianAdapter;
    private _config;
    private onProgress?;
    constructor(_config: ImportConfig);
    /**
     * Sets the progress callback function
     */
    setProgressCallback(callback: (progress: ProgressInfo) => void): void;
    /**
     * Tests the connection to Notion API
     */
    testConnection(): Promise<boolean>;
    /**
     * Validates the Obsidian vault
     */
    validateVault(): Promise<{
        valid: boolean;
        issues: string[];
    }>;
    /**
     * Performs a full import from Notion to Obsidian
     */
    importAll(): Promise<ImportResult>;
    /**
     * Imports specific pages by ID
     */
    importPages(pageIds: string[]): Promise<ImportResult>;
    /**
     * Resumes a previous download session
     */
    resumeDownload(): Promise<{
        completed: AttachmentInfo[];
        failed: AttachmentInfo[];
        errors: ImportError[];
    }>;
    /**
     * Gets current progress information
     */
    getProgress(): ProgressInfo | null;
    /**
     * Processes pages and converts them
     */
    private processPages;
    /**
     * Processes databases and converts them
     */
    private processDatabases;
    /**
     * Extracts tags from page properties
     */
    private extractTags;
    /**
     * Emits progress update
     */
    private emitProgress;
}
//# sourceMappingURL=NotionObsidianImporter.d.ts.map