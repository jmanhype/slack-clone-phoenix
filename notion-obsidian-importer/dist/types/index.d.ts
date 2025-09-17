export interface NotionConfig {
    token: string;
    version?: string;
    baseUrl?: string;
    rateLimitRequests?: number;
    rateLimitWindow?: number;
}
export interface ObsidianConfig {
    vaultPath: string;
    attachmentsFolder?: string;
    templateFolder?: string;
    preserveStructure?: boolean;
    convertImages?: boolean;
    convertDatabases?: boolean;
}
export interface ConversionConfig {
    preserveNotionIds?: boolean;
    convertToggleLists?: boolean;
    convertCallouts?: boolean;
    convertEquations?: boolean;
    convertTables?: boolean;
    downloadImages?: boolean;
    imageFormat?: 'original' | 'webp' | 'png' | 'jpg';
    maxImageSize?: number;
    includeMetadata?: boolean;
    frontmatterFormat?: 'yaml' | 'json';
}
export interface PerformanceConfig {
    maxConcurrentDownloads?: number;
    maxRetries?: number;
    retryDelay?: number;
    timeout?: number;
    cacheEnabled?: boolean;
    cacheDirectory?: string;
}
export interface LoggingConfig {
    level?: 'debug' | 'info' | 'warn' | 'error';
    outputFile?: string;
    console?: boolean;
}
export interface ImportConfig {
    notion: NotionConfig;
    obsidian: ObsidianConfig;
    conversion?: ConversionConfig;
    performance?: PerformanceConfig;
    logging?: LoggingConfig;
    progress?: {
        autosaveInterval?: number;
        showEstimates?: boolean;
    };
    batchSize?: number;
    concurrency?: number;
    retryAttempts?: number;
    progressTracking?: boolean;
}
export interface ProgressInfo {
    status?: 'initializing' | 'running' | 'paused' | 'completed' | 'failed';
    currentPhase?: string;
    totalPages: number;
    processedPages: number;
    totalFiles: number;
    downloadedFiles: number;
    totalItems?: number;
    processedItems?: number;
    failedItems?: number;
    skippedItems?: number;
    percentage?: number;
    currentItem?: string;
    currentOperation: string;
    startTime: Date;
    elapsedTime?: number;
    estimatedTimeRemaining?: number;
    errors: ImportError[];
}
export interface ProgressState {
    status: 'initializing' | 'running' | 'paused' | 'completed' | 'failed';
    startTime: number;
    endTime: number | null;
    currentPhase: string;
    totalItems: number;
    processedItems: number;
    failedItems: number;
    skippedItems: number;
    errors: ImportError[];
    processedPages: Set<string>;
    processedDatabases: Set<string>;
    downloadedFiles: Set<string>;
    currentItem: string | null;
    phases: {
        [key: string]: {
            status: string;
            startTime: number | null;
            endTime: number | null;
        };
    };
}
export interface ImportResult {
    success: boolean;
    totalPages: number;
    totalDatabases: number;
    totalAttachments: number;
    errors: ImportError[];
    importedPages?: any[];
    importedDatabases?: any[];
}
export interface ImportError {
    type: 'RATE_LIMIT' | 'NETWORK' | 'CONVERSION' | 'FILE_SYSTEM' | 'AUTHENTICATION';
    message: string;
    pageId?: string;
    blockId?: string;
    timestamp: Date;
    retryable: boolean;
}
export interface NotionPage {
    id: string;
    title: string;
    parent: any;
    properties: any;
    children?: NotionBlock[];
    createdTime: string;
    lastEditedTime: string;
    url?: string;
}
export interface NotionBlock {
    id: string;
    type: string;
    object: 'block';
    created_time: string;
    last_edited_time: string;
    has_children: boolean;
    archived: boolean;
    [key: string]: any;
}
export interface NotionDatabase {
    id: string;
    title: string;
    properties: Record<string, any>;
    parent: any;
    createdTime: string;
    lastEditedTime: string;
    url?: string;
}
export interface ConversionResult {
    markdown: string;
    attachments: AttachmentInfo[];
    metadata: PageMetadata;
    errors: ImportError[];
}
export interface AttachmentInfo {
    originalUrl: string;
    localPath: string;
    filename: string;
    type: 'image' | 'file' | 'video' | 'audio';
    size?: number;
    downloaded: boolean;
}
export interface PageMetadata {
    title: string;
    tags: string[];
    createdTime: string;
    lastEditedTime: string;
    notionId: string;
    url?: string;
    properties?: Record<string, any>;
}
export interface RateLimitInfo {
    requests: number;
    windowStart: number;
    resetTime: number;
}
export type { WorkspaceInfo, ObsidianFile, ObsidianFolder, IndexFile, DatabaseRelationship, ContentLink, ContentAttachment, ConversionContext, PropertyMapping, VaultStructure, Plugin, NotionRelation, ObsidianLink } from './components';
//# sourceMappingURL=index.d.ts.map