export interface NotionImporterSettings {
    notionToken: string;
    concurrency: number;
    retryAttempts: number;
    requestTimeout: number;
    preserveNotionIds: boolean;
    convertTables: boolean;
    downloadImages: boolean;
    imageFormat: 'original' | 'png' | 'jpg';
    maxImageSize: number;
    defaultImportFolder: string;
    usePageHierarchy: boolean;
    sanitizeFilenames: boolean;
    maxFilenameLength: number;
    headingStyle: 'atx' | 'setext';
    codeBlockStyle: 'fenced' | 'indented';
    emphasisStyle: 'asterisk' | 'underscore';
    bulletListMarker: '-' | '*' | '+';
    convertCallouts: boolean;
    convertToggles: boolean;
    convertEquations: boolean;
    preserveColors: boolean;
    continueOnError: boolean;
    showDetailedErrors: boolean;
    logLevel: 'error' | 'warn' | 'info' | 'debug';
    enableProgressNotifications: boolean;
    autoSaveInterval: number;
    enableBackup: boolean;
    backupFolder: string;
}
export declare const DEFAULT_SETTINGS: NotionImporterSettings;
export interface ImportProgress {
    stage: 'initializing' | 'fetching' | 'processing' | 'converting' | 'saving' | 'complete' | 'error';
    current: number;
    total: number;
    currentItem?: string;
    message?: string;
    error?: string;
    startTime?: Date;
    estimatedTimeRemaining?: number;
}
export interface ImportSession {
    id: string;
    startTime: Date;
    endTime?: Date;
    status: 'running' | 'completed' | 'failed' | 'cancelled';
    progress: ImportProgress;
    settings: NotionImporterSettings;
    results?: ImportResults;
    error?: string;
}
export interface ImportResults {
    totalPages: number;
    successfulPages: number;
    failedPages: number;
    skippedPages: number;
    totalImages: number;
    downloadedImages: number;
    failedImages: number;
    totalSize: number;
    duration: number;
    errors: ImportError[];
}
export interface ImportError {
    type: 'page' | 'image' | 'api' | 'filesystem';
    pageId?: string;
    pageTitle?: string;
    message: string;
    details?: any;
    timestamp: Date;
}
export interface NotionPage {
    id: string;
    title: string;
    type: 'page' | 'database';
    parent?: string;
    children?: string[];
    properties: Record<string, any>;
    created_time: string;
    last_edited_time: string;
    archived: boolean;
    url: string;
    icon?: {
        type: 'emoji' | 'external' | 'file';
        emoji?: string;
        external?: {
            url: string;
        };
        file?: {
            url: string;
        };
    };
    cover?: {
        type: 'external' | 'file';
        external?: {
            url: string;
        };
        file?: {
            url: string;
        };
    };
}
export interface ConversionOptions {
    preserveNotionIds: boolean;
    convertTables: boolean;
    downloadImages: boolean;
    imageFormat: 'original' | 'png' | 'jpg';
    maxImageSize: number;
    headingStyle: 'atx' | 'setext';
    codeBlockStyle: 'fenced' | 'indented';
    emphasisStyle: 'asterisk' | 'underscore';
    bulletListMarker: '-' | '*' | '+';
    convertCallouts: boolean;
    convertToggles: boolean;
    convertEquations: boolean;
    preserveColors: boolean;
}
export interface ValidationResult {
    isValid: boolean;
    errors: string[];
    warnings: string[];
    workspace?: {
        name: string;
        owner: string;
        plan: string;
    };
}
export interface PluginState {
    currentSession?: ImportSession;
    recentSessions: ImportSession[];
    isImporting: boolean;
    lastValidation?: ValidationResult;
    lastValidationTime?: Date;
}
export declare const SUPPORTED_IMAGE_FORMATS: readonly ["png", "jpg", "jpeg", "gif", "svg", "webp", "bmp"];
export declare const MAX_CONCURRENT_DOWNLOADS = 10;
export declare const MIN_CONCURRENT_DOWNLOADS = 1;
export declare const MAX_RETRY_ATTEMPTS = 10;
export declare const MIN_RETRY_ATTEMPTS = 1;
export declare const MAX_REQUEST_TIMEOUT = 300000;
export declare const MIN_REQUEST_TIMEOUT = 5000;
export declare const MAX_IMAGE_SIZE_MB = 100;
export declare const MAX_FILENAME_LENGTH = 255;
export declare function validateSettings(settings: Partial<NotionImporterSettings>): ValidationResult;
export declare function sanitizeSettings(settings: Partial<NotionImporterSettings>): NotionImporterSettings;
//# sourceMappingURL=settings.d.ts.map