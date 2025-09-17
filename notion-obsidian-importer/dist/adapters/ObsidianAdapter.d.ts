import { ObsidianConfig, ConversionResult, ImportError } from '../types';
interface VaultStructure {
    notes: string[];
    attachments: string[];
    folders: string[];
    metadata: VaultMetadata;
}
interface VaultMetadata {
    totalNotes: number;
    totalAttachments: number;
    lastImport: string;
    importSource: 'notion';
    version: string;
}
export declare class ObsidianAdapter {
    private config;
    constructor(config: ObsidianConfig);
    /**
     * Initializes the Obsidian vault structure
     */
    initializeVault(): Promise<void>;
    /**
     * Writes a converted note to the vault
     */
    writeNote(result: ConversionResult, folderPath?: string): Promise<{
        filePath: string;
        errors: ImportError[];
    }>;
    /**
     * Writes multiple notes with folder organization
     */
    writeNotes(results: ConversionResult[], organizationStrategy?: 'flat' | 'by-date' | 'by-type' | 'by-database'): Promise<{
        writtenFiles: string[];
        errors: ImportError[];
    }>;
    /**
     * Creates an index file for imported content
     */
    createImportIndexWithFiles(importedFiles: string[], metadata: {
        importDate: Date;
        totalPages: number;
        totalAttachments: number;
        errors: ImportError[];
    }): Promise<string>;
    /**
     * Validates vault structure and permissions
     */
    validateVault(): Promise<{
        valid: boolean;
        issues: string[];
    }>;
    /**
     * Gets vault statistics
     */
    getVaultStats(): Promise<VaultStructure>;
    /**
     * Copies an attachment to the vault
     */
    private copyAttachment;
    /**
     * Handles file name conflicts by appending numbers
     */
    private handleFileConflict;
    /**
     * Determines folder path based on organization strategy
     */
    private determineFolderPath;
    /**
     * Sanitizes filename for file system compatibility
     */
    private sanitizeFilename;
    /**
     * Creates basic Obsidian configuration
     */
    private createObsidianConfig;
    /**
     * Generates content for import index file
     */
    private generateImportIndexContent;
    /**
     * Recursively scans directory for vault structure
     */
    private scanDirectory;
    /**
     * Saves a file to the vault
     */
    saveFile(filePath: string, content: string): Promise<void>;
    /**
     * Creates an import index file
     */
    createImportIndex(metadata: any): Promise<void>;
}
export {};
//# sourceMappingURL=ObsidianAdapter.d.ts.map