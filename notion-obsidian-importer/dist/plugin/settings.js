"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.MAX_FILENAME_LENGTH = exports.MAX_IMAGE_SIZE_MB = exports.MIN_REQUEST_TIMEOUT = exports.MAX_REQUEST_TIMEOUT = exports.MIN_RETRY_ATTEMPTS = exports.MAX_RETRY_ATTEMPTS = exports.MIN_CONCURRENT_DOWNLOADS = exports.MAX_CONCURRENT_DOWNLOADS = exports.SUPPORTED_IMAGE_FORMATS = exports.DEFAULT_SETTINGS = void 0;
exports.validateSettings = validateSettings;
exports.sanitizeSettings = sanitizeSettings;
exports.DEFAULT_SETTINGS = {
    // API Settings
    notionToken: '',
    concurrency: 3,
    retryAttempts: 3,
    requestTimeout: 30000,
    // Content Settings
    preserveNotionIds: true,
    convertTables: true,
    downloadImages: true,
    imageFormat: 'original',
    maxImageSize: 10,
    // File Organization
    defaultImportFolder: 'Notion Import',
    usePageHierarchy: true,
    sanitizeFilenames: true,
    maxFilenameLength: 100,
    // Formatting
    headingStyle: 'atx',
    codeBlockStyle: 'fenced',
    emphasisStyle: 'asterisk',
    bulletListMarker: '-',
    // Content Processing
    convertCallouts: true,
    convertToggles: true,
    convertEquations: true,
    preserveColors: false,
    // Error Handling
    continueOnError: true,
    showDetailedErrors: false,
    logLevel: 'info',
    // Advanced
    enableProgressNotifications: true,
    autoSaveInterval: 30,
    enableBackup: false,
    backupFolder: 'Notion Import Backups'
};
exports.SUPPORTED_IMAGE_FORMATS = ['png', 'jpg', 'jpeg', 'gif', 'svg', 'webp', 'bmp'];
exports.MAX_CONCURRENT_DOWNLOADS = 10;
exports.MIN_CONCURRENT_DOWNLOADS = 1;
exports.MAX_RETRY_ATTEMPTS = 10;
exports.MIN_RETRY_ATTEMPTS = 1;
exports.MAX_REQUEST_TIMEOUT = 300000; // 5 minutes
exports.MIN_REQUEST_TIMEOUT = 5000; // 5 seconds
exports.MAX_IMAGE_SIZE_MB = 100;
exports.MAX_FILENAME_LENGTH = 255;
function validateSettings(settings) {
    const errors = [];
    const warnings = [];
    // Validate API settings
    if (settings.notionToken && !settings.notionToken.startsWith('secret_')) {
        errors.push('Notion API token must start with "secret_"');
    }
    if (settings.concurrency !== undefined) {
        if (settings.concurrency < exports.MIN_CONCURRENT_DOWNLOADS || settings.concurrency > exports.MAX_CONCURRENT_DOWNLOADS) {
            errors.push(`Concurrency must be between ${exports.MIN_CONCURRENT_DOWNLOADS} and ${exports.MAX_CONCURRENT_DOWNLOADS}`);
        }
    }
    if (settings.retryAttempts !== undefined) {
        if (settings.retryAttempts < exports.MIN_RETRY_ATTEMPTS || settings.retryAttempts > exports.MAX_RETRY_ATTEMPTS) {
            errors.push(`Retry attempts must be between ${exports.MIN_RETRY_ATTEMPTS} and ${exports.MAX_RETRY_ATTEMPTS}`);
        }
    }
    if (settings.requestTimeout !== undefined) {
        if (settings.requestTimeout < exports.MIN_REQUEST_TIMEOUT || settings.requestTimeout > exports.MAX_REQUEST_TIMEOUT) {
            errors.push(`Request timeout must be between ${exports.MIN_REQUEST_TIMEOUT} and ${exports.MAX_REQUEST_TIMEOUT} milliseconds`);
        }
    }
    // Validate image settings
    if (settings.maxImageSize !== undefined) {
        if (settings.maxImageSize < 0 || settings.maxImageSize > exports.MAX_IMAGE_SIZE_MB) {
            errors.push(`Max image size must be between 0 and ${exports.MAX_IMAGE_SIZE_MB} MB`);
        }
    }
    // Validate filename settings
    if (settings.maxFilenameLength !== undefined) {
        if (settings.maxFilenameLength < 10 || settings.maxFilenameLength > exports.MAX_FILENAME_LENGTH) {
            errors.push(`Max filename length must be between 10 and ${exports.MAX_FILENAME_LENGTH} characters`);
        }
    }
    // Validate folder paths
    if (settings.defaultImportFolder && settings.defaultImportFolder.includes('..')) {
        errors.push('Import folder path cannot contain ".."');
    }
    if (settings.backupFolder && settings.backupFolder.includes('..')) {
        errors.push('Backup folder path cannot contain ".."');
    }
    // Performance warnings
    if (settings.concurrency && settings.concurrency > 5) {
        warnings.push('High concurrency may cause rate limiting issues');
    }
    if (settings.maxImageSize && settings.maxImageSize > 25) {
        warnings.push('Large image size limit may slow down imports');
    }
    return {
        isValid: errors.length === 0,
        errors,
        warnings
    };
}
function sanitizeSettings(settings) {
    const sanitized = { ...exports.DEFAULT_SETTINGS, ...settings };
    // Clamp numeric values
    sanitized.concurrency = Math.max(exports.MIN_CONCURRENT_DOWNLOADS, Math.min(exports.MAX_CONCURRENT_DOWNLOADS, sanitized.concurrency));
    sanitized.retryAttempts = Math.max(exports.MIN_RETRY_ATTEMPTS, Math.min(exports.MAX_RETRY_ATTEMPTS, sanitized.retryAttempts));
    sanitized.requestTimeout = Math.max(exports.MIN_REQUEST_TIMEOUT, Math.min(exports.MAX_REQUEST_TIMEOUT, sanitized.requestTimeout));
    sanitized.maxImageSize = Math.max(0, Math.min(exports.MAX_IMAGE_SIZE_MB, sanitized.maxImageSize));
    sanitized.maxFilenameLength = Math.max(10, Math.min(exports.MAX_FILENAME_LENGTH, sanitized.maxFilenameLength));
    sanitized.autoSaveInterval = Math.max(10, sanitized.autoSaveInterval);
    // Sanitize folder paths
    sanitized.defaultImportFolder = sanitized.defaultImportFolder.replace(/\.\./g, '');
    sanitized.backupFolder = sanitized.backupFolder.replace(/\.\./g, '');
    return sanitized;
}
//# sourceMappingURL=settings.js.map