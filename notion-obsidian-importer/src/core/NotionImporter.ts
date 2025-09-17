// import { Client } from '@notionhq/client'; // unused
import { NotionAPIClient } from '../client/NotionAPIClient';
import { ProgressTracker } from './ProgressTracker';
import { ImportConfig, ImportResult } from '../types';
import Logger from './Logger';

export class NotionImporter {
  private client: NotionAPIClient;
  private progressTracker: ProgressTracker;
  private _config: ImportConfig;

  constructor(_config: ImportConfig, progressTracker?: ProgressTracker) {
    this._config = _config;
    this.client = new NotionAPIClient(_config.notion);
    this.progressTracker = progressTracker || new ProgressTracker();
  }

  async testConnection(): Promise<boolean> {
    try {
      return await this.client.testConnection();
    } catch (error) {
      Logger.error('Failed to connect to Notion API', error);
      return false;
    }
  }

  async discoverContent(): Promise<{
    pages: any[];
    databases: any[];
    totalItems: number;
  }> {
    Logger.info('Discovering Notion content...');
    this.progressTracker.startPhase('discovery');

    try {
      const pages = await this.client.searchPages();
      const databases = await this.client.searchDatabases();
      
      const totalItems = pages.length + databases.length;
      this.progressTracker.updateProgress({ totalItems });
      this.progressTracker.completePhase('discovery');

      Logger.success(`Discovered ${pages.length} pages and ${databases.length} databases`);
      
      return {
        pages,
        databases,
        totalItems,
      };
    } catch (error) {
      Logger.error('Failed to discover content', error);
      throw error;
    }
  }

  async downloadPage(pageId: string): Promise<any> {
    if (this.progressTracker.isPageProcessed(pageId)) {
      Logger.debug(`Page ${pageId} already processed, skipping`);
      this.progressTracker.incrementSkipped();
      return null;
    }

    try {
      Logger.debug(`Downloading page ${pageId}`);
      this.progressTracker.updateProgress({ currentItem: `Page: ${pageId}` });
      
      const page = await this.client.getPage(pageId);
      const blocks = await this.client.getBlocks(pageId);
      
      this.progressTracker.addProcessedPage(pageId);
      this.progressTracker.incrementProcessed();
      
      return {
        ...page,
        blocks,
      };
    } catch (error) {
      Logger.error(`Failed to download page ${pageId}`, error);
      this.progressTracker.incrementFailed(error as Error);
      throw error;
    }
  }

  async downloadDatabase(databaseId: string): Promise<any> {
    if (this.progressTracker.isDatabaseProcessed(databaseId)) {
      Logger.debug(`Database ${databaseId} already processed, skipping`);
      this.progressTracker.incrementSkipped();
      return null;
    }

    try {
      Logger.debug(`Downloading database ${databaseId}`);
      this.progressTracker.updateProgress({ currentItem: `Database: ${databaseId}` });
      
      const database = await this.client.getDatabase(databaseId);
      const pages = await this.client.getDatabasePages(databaseId);
      
      this.progressTracker.addProcessedDatabase(databaseId);
      this.progressTracker.incrementProcessed();
      
      return {
        ...database,
        pages,
      };
    } catch (error) {
      Logger.error(`Failed to download database ${databaseId}`, error);
      this.progressTracker.incrementFailed(error as Error);
      throw error;
    }
  }

  async downloadFile(url: string, outputPath: string): Promise<void> {
    if (this.progressTracker.state.downloadedFiles.has(outputPath)) {
      Logger.debug(`File ${outputPath} already downloaded, skipping`);
      return;
    }

    try {
      await this.client.downloadFile(url, outputPath);
      this.progressTracker.addDownloadedFile(outputPath);
    } catch (error) {
      Logger.error(`Failed to download file from ${url}`, error);
      throw error;
    }
  }

  async import(options?: {
    pages?: string[];
    databases?: string[];
    resumeFromProgress?: boolean;
  }): Promise<ImportResult> {
    Logger.info('Starting Notion import...');
    this.progressTracker.updateProgress({ status: 'running' });
    
    if (options?.resumeFromProgress) {
      const resumed = await this.progressTracker.loadProgress();
      if (resumed) {
        Logger.info('Resuming from previous progress');
      }
    }

    this.progressTracker.startAutoSave();

    try {
      // Discover content if not specified
      let pagesToImport = options?.pages || [];
      let databasesToImport = options?.databases || [];
      
      if (pagesToImport.length === 0 && databasesToImport.length === 0) {
        const content = await this.discoverContent();
        pagesToImport = content.pages.map(p => p.id);
        databasesToImport = content.databases.map(d => d.id);
      }

      // Download phase
      this.progressTracker.startPhase('download');
      
      const downloadedPages = [];
      const downloadedDatabases = [];
      
      for (const pageId of pagesToImport) {
        const page = await this.downloadPage(pageId);
        if (page) downloadedPages.push(page);
      }
      
      for (const dbId of databasesToImport) {
        const db = await this.downloadDatabase(dbId);
        if (db) downloadedDatabases.push(db);
      }
      
      this.progressTracker.completePhase('download');
      
      // Return result
      const result: ImportResult = {
        success: true,
        totalPages: downloadedPages.length,
        totalDatabases: downloadedDatabases.length,
        totalAttachments: this.progressTracker.state.downloadedFiles.size,
        errors: this.progressTracker.state.errors,
        importedPages: downloadedPages,
        importedDatabases: downloadedDatabases,
      };
      
      this.progressTracker.complete();
      Logger.success('Import completed successfully!');
      
      return result;
    } catch (error) {
      Logger.error('Import failed', error);
      this.progressTracker.updateProgress({ status: 'failed' });
      throw error;
    } finally {
      this.progressTracker.stopAutoSave();
    }
  }

  getProgressTracker(): ProgressTracker {
    return this.progressTracker;
  }
}

export default NotionImporter;