import { NotionAPIClient } from './client/NotionAPIClient';
import { ContentConverter } from './converters/ContentConverter';
import { DatabaseConverter } from './converters/DatabaseConverter';
import { ProgressiveDownloader } from './download/ProgressiveDownloader';
import { ObsidianAdapter } from './adapters/ObsidianAdapter';
import { 
  ImportConfig, 
  ProgressInfo, 
  NotionPage, 
  NotionDatabase, 
  ConversionResult,
  ImportError,
  AttachmentInfo
} from './types';
import { createLogger } from './utils/logger';

const logger = createLogger('NotionObsidianImporter');

export interface ImportResult {
  success: boolean;
  importedPages: number;
  importedDatabases: number;
  downloadedAttachments: number;
  errors: ImportError[];
  importedFiles: string[];
  duration: number;
}

export class NotionObsidianImporter {
  private apiClient: NotionAPIClient;
  private contentConverter: ContentConverter;
  private databaseConverter: DatabaseConverter;
  private downloader: ProgressiveDownloader;
  private obsidianAdapter: ObsidianAdapter;
  private _config: ImportConfig;
  private onProgress?: (progress: ProgressInfo) => void;

  constructor(_config: ImportConfig) {
    this._config = _config;
    
    // Initialize components
    this.apiClient = new NotionAPIClient(_config.notion);
    this.contentConverter = new ContentConverter();
    this.databaseConverter = new DatabaseConverter();
    this.downloader = new ProgressiveDownloader(
      _config.obsidian.vaultPath,
      _config.concurrency,
      _config.retryAttempts
    );
    this.obsidianAdapter = new ObsidianAdapter(_config.obsidian);

    logger.info('NotionObsidianImporter initialized', {
      batchSize: _config.batchSize,
      concurrency: _config.concurrency,
      retryAttempts: _config.retryAttempts
    });
  }

  /**
   * Sets the progress callback function
   */
  setProgressCallback(callback: (progress: ProgressInfo) => void): void {
    this.onProgress = callback;
    this.downloader.setProgressCallback(callback);
  }

  /**
   * Tests the connection to Notion API
   */
  async testConnection(): Promise<boolean> {
    return await this.apiClient.testConnection();
  }

  /**
   * Validates the Obsidian vault
   */
  async validateVault(): Promise<{ valid: boolean; issues: string[] }> {
    return await this.obsidianAdapter.validateVault();
  }

  /**
   * Performs a full import from Notion to Obsidian
   */
  async importAll(): Promise<ImportResult> {
    const startTime = Date.now();
    const errors: ImportError[] = [];
    const allAttachments: AttachmentInfo[] = [];
    let importedFiles: string[] = [];

    logger.info('Starting full Notion import');

    try {
      // Initialize vault
      await this.obsidianAdapter.initializeVault();

      // Search for all content
      this.emitProgress({
        totalPages: 0,
        processedPages: 0,
        totalFiles: 0,
        downloadedFiles: 0,
        currentOperation: 'Searching Notion workspace...',
        startTime: new Date(startTime),
        errors
      });

      const searchResults = await this.apiClient.search();
      const pages = searchResults.filter(item => 'children' in item) as NotionPage[];
      const databases = searchResults.filter(item => 'properties' in item) as NotionDatabase[];

      logger.info('Found content to import', {
        pages: pages.length,
        databases: databases.length
      });

      // Process pages
      const pageResults = await this.processPages(pages, errors, allAttachments);
      
      // Process databases
      const databaseResults = await this.processDatabases(databases, errors, allAttachments);

      // Download all attachments
      if (allAttachments.length > 0) {
        this.emitProgress({
          totalPages: pages.length + databases.length,
          processedPages: pages.length + databases.length,
          totalFiles: allAttachments.length,
          downloadedFiles: 0,
          currentOperation: 'Downloading attachments...',
          startTime: new Date(startTime),
          errors
        });

        await this.downloader.startSession(allAttachments);
        const downloadResult = await this.downloader.downloadAll();
        errors.push(...downloadResult.errors);
      }

      // Write all content to vault
      const writeResult = await this.obsidianAdapter.writeNotes(
        [...pageResults, ...databaseResults],
        'by-type'
      );
      
      importedFiles = writeResult.writtenFiles;
      errors.push(...writeResult.errors);

      // Create import index
      await this.obsidianAdapter.createImportIndex({
        importDate: new Date().toISOString(),
        totalPages: pages.length,
        totalDatabases: 0,
        totalAttachments: allAttachments.length
      });

      const duration = Date.now() - startTime;
      
      const result: ImportResult = {
        success: errors.filter(e => e.type !== 'CONVERSION').length === 0,
        importedPages: pages.length,
        importedDatabases: databases.length,
        downloadedAttachments: allAttachments.filter(a => a.downloaded).length,
        errors,
        importedFiles,
        duration
      };

      logger.info('Import completed', {
        success: result.success,
        importedPages: result.importedPages,
        importedDatabases: result.importedDatabases,
        downloadedAttachments: result.downloadedAttachments,
        errors: result.errors.length,
        duration: `${Math.round(duration / 1000)}s`
      });

      return result;

    } catch (error: any) {
      logger.error('Import failed', { error: error.message });
      
      errors.push({
        type: 'NETWORK',
        message: `Import failed: ${error.message}`,
        timestamp: new Date(),
        retryable: false
      });

      return {
        success: false,
        importedPages: 0,
        importedDatabases: 0,
        downloadedAttachments: 0,
        errors,
        importedFiles: [],
        duration: Date.now() - startTime
      };
    }
  }

  /**
   * Imports specific pages by ID
   */
  async importPages(pageIds: string[]): Promise<ImportResult> {
    const startTime = Date.now();
    const errors: ImportError[] = [];
    const allAttachments: AttachmentInfo[] = [];

    logger.info('Starting selective page import', { pageIds });

    try {
      await this.obsidianAdapter.initializeVault();

      const pages: NotionPage[] = [];
      
      // Fetch each page
      for (const pageId of pageIds) {
        try {
          const page = await this.apiClient.getPage(pageId);
          page.children = await this.apiClient.getPageBlocks(pageId);
          pages.push(page);
        } catch (error: any) {
          errors.push({
            type: 'NETWORK',
            message: `Failed to fetch page ${pageId}: ${error.message}`,
            pageId,
            timestamp: new Date(),
            retryable: true
          });
        }
      }

      const pageResults = await this.processPages(pages, errors, allAttachments);
      
      // Download attachments and write to vault
      if (allAttachments.length > 0) {
        await this.downloader.startSession(allAttachments);
        const downloadResult = await this.downloader.downloadAll();
        errors.push(...downloadResult.errors);
      }

      const writeResult = await this.obsidianAdapter.writeNotes(pageResults, 'flat');
      errors.push(...writeResult.errors);

      const duration = Date.now() - startTime;

      return {
        success: errors.filter(e => e.type !== 'CONVERSION').length === 0,
        importedPages: pages.length,
        importedDatabases: 0,
        downloadedAttachments: allAttachments.filter(a => a.downloaded).length,
        errors,
        importedFiles: writeResult.writtenFiles,
        duration
      };

    } catch (error: any) {
      logger.error('Selective import failed', { error: error.message });
      
      return {
        success: false,
        importedPages: 0,
        importedDatabases: 0,
        downloadedAttachments: 0,
        errors: [{
          type: 'NETWORK',
          message: `Import failed: ${error.message}`,
          timestamp: new Date(),
          retryable: false
        }],
        importedFiles: [],
        duration: Date.now() - startTime
      };
    }
  }

  /**
   * Resumes a previous download session
   */
  async resumeDownload(): Promise<{ 
    completed: AttachmentInfo[]; 
    failed: AttachmentInfo[]; 
    errors: ImportError[] 
  }> {
    const sessionId = await this.downloader.resumeSession();
    
    if (!sessionId) {
      throw new Error('No download session to resume');
    }

    logger.info('Resuming download session', { sessionId });
    return await this.downloader.downloadAll();
  }

  /**
   * Gets current progress information
   */
  getProgress(): ProgressInfo | null {
    return this.downloader.getProgress();
  }

  /**
   * Processes pages and converts them
   */
  private async processPages(
    pages: NotionPage[],
    errors: ImportError[],
    allAttachments: AttachmentInfo[]
  ): Promise<ConversionResult[]> {
    const results: ConversionResult[] = [];
    let processedCount = 0;

    for (const page of pages) {
      try {
        this.emitProgress({
          totalPages: pages.length,
          processedPages: processedCount,
          totalFiles: allAttachments.length,
          downloadedFiles: 0,
          currentOperation: `Converting page: ${page.title}`,
          startTime: new Date(),
          errors
        });

        // Ensure page has blocks
        if (!page.children) {
          page.children = await this.apiClient.getPageBlocks(page.id);
        }

        const metadata = {
          title: page.title,
          tags: this.extractTags(page),
          createdTime: page.createdTime,
          lastEditedTime: page.lastEditedTime,
          notionId: page.id,
          url: page.url
        };

        const result = await this.contentConverter.convertBlocks(page.children, metadata);
        results.push(result);
        allAttachments.push(...result.attachments);
        errors.push(...result.errors);

        processedCount++;

      } catch (error: any) {
        logger.error(`Failed to process page ${page.id}`, { error: error.message });
        errors.push({
          type: 'CONVERSION',
          message: `Failed to process page: ${error.message}`,
          pageId: page.id,
          timestamp: new Date(),
          retryable: false
        });
      }
    }

    return results;
  }

  /**
   * Processes databases and converts them
   */
  private async processDatabases(
    databases: NotionDatabase[],
    errors: ImportError[],
    allAttachments: AttachmentInfo[]
  ): Promise<ConversionResult[]> {
    const results: ConversionResult[] = [];

    for (const database of databases) {
      try {
        this.emitProgress({
          totalPages: databases.length,
          processedPages: 0,
          totalFiles: allAttachments.length,
          downloadedFiles: 0,
          currentOperation: `Converting database: ${database.title}`,
          startTime: new Date(),
          errors
        });

        // Query database for all pages
        const pages = await this.apiClient.queryDatabase(database.id);
        
        // Fetch blocks for each page
        for (const page of pages) {
          page.children = await this.apiClient.getPageBlocks(page.id);
        }

        const databaseResult = await this.databaseConverter.convertDatabase(database, pages);
        
        results.push(databaseResult.indexFile);
        results.push(...databaseResult.pageFiles);
        
        // Collect attachments from all results
        for (const result of [databaseResult.indexFile, ...databaseResult.pageFiles]) {
          allAttachments.push(...result.attachments);
        }
        
        errors.push(...databaseResult.errors);

      } catch (error: any) {
        logger.error(`Failed to process database ${database.id}`, { error: error.message });
        errors.push({
          type: 'CONVERSION',
          message: `Failed to process database: ${error.message}`,
          timestamp: new Date(),
          retryable: false
        });
      }
    }

    return results;
  }

  /**
   * Extracts tags from page properties
   */
  private extractTags(page: NotionPage): string[] {
    const tags: string[] = [];
    
    if (page.properties) {
      for (const [, property] of Object.entries(page.properties)) {
        const prop = property as any;
        
        if (prop.type === 'multi_select' && prop.multi_select) {
          tags.push(...prop.multi_select.map((option: any) => option.name));
        } else if (prop.type === 'select' && prop.select) {
          tags.push(prop.select.name);
        }
      }
    }

    return [...new Set(tags)]; // Remove duplicates
  }

  /**
   * Emits progress update
   */
  private emitProgress(progress: ProgressInfo): void {
    if (this.onProgress) {
      this.onProgress(progress);
    }
  }
}