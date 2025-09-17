import * as path from 'path';
import { ContentConverter } from '../converters/ContentConverter';
import { DatabaseConverter } from '../converters/DatabaseConverter';
import { ObsidianAdapter } from '../adapters/ObsidianAdapter';
import { ImportConfig, ImportResult } from '../types';
import { ProgressTracker } from './ProgressTracker';
import Logger from './Logger';

export class ObsidianConverter {
  private contentConverter: ContentConverter;
  private databaseConverter: DatabaseConverter;
  private obsidianAdapter: ObsidianAdapter;
  private config: ImportConfig;
  private progressTracker: ProgressTracker;

  constructor(config: ImportConfig, progressTracker?: ProgressTracker) {
    this.config = config;
    this.contentConverter = new ContentConverter(config.conversion);
    this.databaseConverter = new DatabaseConverter(config.conversion);
    this.obsidianAdapter = new ObsidianAdapter(config.obsidian);
    this.progressTracker = progressTracker || new ProgressTracker();
  }

  async convertAndSave(importResult: ImportResult): Promise<void> {
    Logger.info('Starting conversion to Obsidian format...');
    this.progressTracker.startPhase('conversion');

    try {
      // Initialize vault
      await this.obsidianAdapter.initializeVault();
      
      // Convert pages
      for (const page of importResult.importedPages || []) {
        await this.convertPage(page);
      }
      
      // Convert databases
      for (const database of importResult.importedDatabases || []) {
        await this.convertDatabase(database);
      }
      
      this.progressTracker.completePhase('conversion');
      
      // Writing phase
      this.progressTracker.startPhase('writing');
      await this.obsidianAdapter.createImportIndex({
        importDate: new Date().toISOString(),
        totalPages: importResult.totalPages,
        totalDatabases: importResult.totalDatabases,
        totalAttachments: importResult.totalAttachments,
      });
      this.progressTracker.completePhase('writing');
      
      Logger.success('Conversion completed successfully!');
    } catch (error) {
      Logger.error('Conversion failed', error);
      throw error;
    }
  }

  private async convertPage(page: any): Promise<void> {
    try {
      this.progressTracker.updateProgress({ 
        currentItem: `Converting: ${page.properties?.title?.title?.[0]?.plain_text || page.id}`
      });
      
      const markdown = await this.contentConverter.convertPage(page);
      const title = this.extractTitle(page);
      const filePath = this.generateFilePath(title, page.id);
      
      await this.obsidianAdapter.saveFile(filePath, markdown);
      
      // Handle attachments
      if (page.blocks) {
        await this.handleAttachments(page.blocks);
      }
      
      this.progressTracker.incrementProcessed();
    } catch (error) {
      Logger.error(`Failed to convert page ${page.id}`, error);
      this.progressTracker.incrementFailed(error as Error);
    }
  }

  private async convertDatabase(database: any): Promise<void> {
    try {
      this.progressTracker.updateProgress({ 
        currentItem: `Converting database: ${database.title?.[0]?.plain_text || database.id}`
      });
      
      const { indexFile } = await this.databaseConverter.convertDatabase(database, database.pages || []);
      const title = database.title?.[0]?.plain_text || 'Untitled Database';
      
      // Save database index
      const indexPath = this.generateFilePath(`${title} - Index`, database.id || 'unknown');
      await this.obsidianAdapter.saveFile(indexPath, indexFile.markdown);
      
      // Save database pages
      if (database.pages) {
        for (const page of database.pages) {
          const pageMarkdown = await this.contentConverter.convertPage(page);
          const pageTitle = this.extractTitle(page);
          const pagePath = this.generateFilePath(
            `${title}/${pageTitle}`, 
            page.id || 'unknown'
          );
          await this.obsidianAdapter.saveFile(pagePath, pageMarkdown);
        }
      }
      
      this.progressTracker.incrementProcessed();
    } catch (error) {
      Logger.error(`Failed to convert database ${database.id}`, error);
      this.progressTracker.incrementFailed(error as Error);
    }
  }

  private async handleAttachments(blocks: any[]): Promise<void> {
    for (const block of blocks) {
      // Handle images
      if (block.type === 'image' && block.image) {
        const imageUrl = block.image.file?.url || block.image.external?.url;
        if (imageUrl) {
          const fileName = this.extractFileName(imageUrl, block.id);
          const attachmentPath = path.join(
            this.config.obsidian.attachmentsFolder || 'attachments',
            fileName
          );
          
          // Download will be handled by NotionImporter
          this.progressTracker.addDownloadedFile(attachmentPath);
        }
      }
      
      // Handle files
      if (block.type === 'file' && block.file) {
        const fileUrl = block.file.file?.url || block.file.external?.url;
        if (fileUrl) {
          const fileName = block.file.caption?.[0]?.plain_text || 
                          this.extractFileName(fileUrl, block.id);
          const attachmentPath = path.join(
            this.config.obsidian.attachmentsFolder || 'attachments',
            fileName
          );
          
          this.progressTracker.addDownloadedFile(attachmentPath);
        }
      }
      
      // Recursively handle children
      if (block.children) {
        await this.handleAttachments(block.children);
      }
    }
  }

  private extractTitle(page: any): string {
    if (page.properties?.title?.title?.[0]?.plain_text) {
      return page.properties.title.title[0].plain_text;
    }
    if (page.properties?.Name?.title?.[0]?.plain_text) {
      return page.properties.Name.title[0].plain_text;
    }
    return `Untitled ${page.id.substring(0, 8)}`;
  }

  private generateFilePath(title: string, id: string): string {
    // Sanitize title for file system
    const sanitized = title
      .replace(/[<>:"/\\|?*]/g, '-')
      .replace(/\s+/g, ' ')
      .trim();
    
    if (this.config.conversion?.preserveNotionIds) {
      return `${sanitized} [${id.substring(0, 8)}].md`;
    }
    
    return `${sanitized}.md`;
  }

  private extractFileName(url: string, blockId: string): string {
    try {
      const urlPath = new URL(url).pathname;
      const fileName = path.basename(urlPath);
      if (fileName && fileName !== '/') {
        return fileName;
      }
    } catch {
      // Invalid URL, fall back to block ID
    }
    return `attachment-${blockId.substring(0, 8)}`;
  }
}

export default ObsidianConverter;