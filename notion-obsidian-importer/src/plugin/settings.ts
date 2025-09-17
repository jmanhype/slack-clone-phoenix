export interface NotionImporterSettings {
  // API Settings
  notionToken: string;
  concurrency: number;
  retryAttempts: number;
  requestTimeout: number;

  // Content Settings
  preserveNotionIds: boolean;
  convertTables: boolean;
  downloadImages: boolean;
  imageFormat: 'original' | 'png' | 'jpg';
  maxImageSize: number; // in MB
  
  // File Organization
  defaultImportFolder: string;
  usePageHierarchy: boolean;
  sanitizeFilenames: boolean;
  maxFilenameLength: number;
  
  // Formatting
  headingStyle: 'atx' | 'setext';
  codeBlockStyle: 'fenced' | 'indented';
  emphasisStyle: 'asterisk' | 'underscore';
  bulletListMarker: '-' | '*' | '+';
  
  // Content Processing
  convertCallouts: boolean;
  convertToggles: boolean;
  convertEquations: boolean;
  preserveColors: boolean;
  
  // Error Handling
  continueOnError: boolean;
  showDetailedErrors: boolean;
  logLevel: 'error' | 'warn' | 'info' | 'debug';
  
  // Advanced
  enableProgressNotifications: boolean;
  autoSaveInterval: number; // in seconds
  enableBackup: boolean;
  backupFolder: string;
}

export const DEFAULT_SETTINGS: NotionImporterSettings = {
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
    external?: { url: string };
    file?: { url: string };
  };
  cover?: {
    type: 'external' | 'file';
    external?: { url: string };
    file?: { url: string };
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

export const SUPPORTED_IMAGE_FORMATS = ['png', 'jpg', 'jpeg', 'gif', 'svg', 'webp', 'bmp'] as const;
export const MAX_CONCURRENT_DOWNLOADS = 10;
export const MIN_CONCURRENT_DOWNLOADS = 1;
export const MAX_RETRY_ATTEMPTS = 10;
export const MIN_RETRY_ATTEMPTS = 1;
export const MAX_REQUEST_TIMEOUT = 300000; // 5 minutes
export const MIN_REQUEST_TIMEOUT = 5000; // 5 seconds
export const MAX_IMAGE_SIZE_MB = 100;
export const MAX_FILENAME_LENGTH = 255;

export function validateSettings(settings: Partial<NotionImporterSettings>): ValidationResult {
  const errors: string[] = [];
  const warnings: string[] = [];

  // Validate API settings
  if (settings.notionToken && !settings.notionToken.startsWith('secret_')) {
    errors.push('Notion API token must start with "secret_"');
  }

  if (settings.concurrency !== undefined) {
    if (settings.concurrency < MIN_CONCURRENT_DOWNLOADS || settings.concurrency > MAX_CONCURRENT_DOWNLOADS) {
      errors.push(`Concurrency must be between ${MIN_CONCURRENT_DOWNLOADS} and ${MAX_CONCURRENT_DOWNLOADS}`);
    }
  }

  if (settings.retryAttempts !== undefined) {
    if (settings.retryAttempts < MIN_RETRY_ATTEMPTS || settings.retryAttempts > MAX_RETRY_ATTEMPTS) {
      errors.push(`Retry attempts must be between ${MIN_RETRY_ATTEMPTS} and ${MAX_RETRY_ATTEMPTS}`);
    }
  }

  if (settings.requestTimeout !== undefined) {
    if (settings.requestTimeout < MIN_REQUEST_TIMEOUT || settings.requestTimeout > MAX_REQUEST_TIMEOUT) {
      errors.push(`Request timeout must be between ${MIN_REQUEST_TIMEOUT} and ${MAX_REQUEST_TIMEOUT} milliseconds`);
    }
  }

  // Validate image settings
  if (settings.maxImageSize !== undefined) {
    if (settings.maxImageSize < 0 || settings.maxImageSize > MAX_IMAGE_SIZE_MB) {
      errors.push(`Max image size must be between 0 and ${MAX_IMAGE_SIZE_MB} MB`);
    }
  }

  // Validate filename settings
  if (settings.maxFilenameLength !== undefined) {
    if (settings.maxFilenameLength < 10 || settings.maxFilenameLength > MAX_FILENAME_LENGTH) {
      errors.push(`Max filename length must be between 10 and ${MAX_FILENAME_LENGTH} characters`);
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

export function sanitizeSettings(settings: Partial<NotionImporterSettings>): NotionImporterSettings {
  const sanitized = { ...DEFAULT_SETTINGS, ...settings };

  // Clamp numeric values
  sanitized.concurrency = Math.max(MIN_CONCURRENT_DOWNLOADS, Math.min(MAX_CONCURRENT_DOWNLOADS, sanitized.concurrency));
  sanitized.retryAttempts = Math.max(MIN_RETRY_ATTEMPTS, Math.min(MAX_RETRY_ATTEMPTS, sanitized.retryAttempts));
  sanitized.requestTimeout = Math.max(MIN_REQUEST_TIMEOUT, Math.min(MAX_REQUEST_TIMEOUT, sanitized.requestTimeout));
  sanitized.maxImageSize = Math.max(0, Math.min(MAX_IMAGE_SIZE_MB, sanitized.maxImageSize));
  sanitized.maxFilenameLength = Math.max(10, Math.min(MAX_FILENAME_LENGTH, sanitized.maxFilenameLength));
  sanitized.autoSaveInterval = Math.max(10, sanitized.autoSaveInterval);

  // Sanitize folder paths
  sanitized.defaultImportFolder = sanitized.defaultImportFolder.replace(/\.\./g, '');
  sanitized.backupFolder = sanitized.backupFolder.replace(/\.\./g, '');

  return sanitized;
}