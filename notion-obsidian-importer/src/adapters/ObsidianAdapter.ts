import * as fs from 'fs-extra';
import * as path from 'path';
// import * as yaml from 'yaml'; // unused for now
import { ObsidianConfig, ConversionResult, AttachmentInfo, ImportError } from '../types';
import { createLogger } from '../utils/logger';

const logger = createLogger('ObsidianAdapter');

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

export class ObsidianAdapter {
  private config: ObsidianConfig;

  constructor(config: ObsidianConfig) {
    this.config = {
      attachmentsFolder: 'attachments',
      templateFolder: 'templates',
      preserveStructure: true,
      convertImages: true,
      convertDatabases: true,
      ...config
    };

    logger.info('ObsidianAdapter initialized', {
      vaultPath: this.config.vaultPath,
      attachmentsFolder: this.config.attachmentsFolder,
      preserveStructure: this.config.preserveStructure
    });
  }

  /**
   * Initializes the Obsidian vault structure
   */
  async initializeVault(): Promise<void> {
    try {
      // Ensure vault directory exists
      await fs.ensureDir(this.config.vaultPath);

      // Create standard Obsidian folders
      await fs.ensureDir(path.join(this.config.vaultPath, this.config.attachmentsFolder!));
      
      if (this.config.templateFolder) {
        await fs.ensureDir(path.join(this.config.vaultPath, this.config.templateFolder));
      }

      // Create .obsidian folder for vault configuration
      const obsidianDir = path.join(this.config.vaultPath, '.obsidian');
      await fs.ensureDir(obsidianDir);

      // Create basic Obsidian configuration
      await this.createObsidianConfig(obsidianDir);

      logger.info('Vault initialized successfully', {
        vaultPath: this.config.vaultPath
      });

    } catch (error: any) {
      logger.error('Failed to initialize vault', { error: error.message });
      throw new Error(`Failed to initialize Obsidian vault: ${error.message}`);
    }
  }

  /**
   * Writes a converted note to the vault
   */
  async writeNote(
    result: ConversionResult,
    folderPath?: string
  ): Promise<{ filePath: string; errors: ImportError[] }> {
    const errors: ImportError[] = [...result.errors];
    
    try {
      // Generate filename
      const filename = this.sanitizeFilename(result.metadata.title) + '.md';
      
      // Determine target directory
      const targetDir = folderPath 
        ? path.join(this.config.vaultPath, folderPath)
        : this.config.vaultPath;
      
      await fs.ensureDir(targetDir);
      
      // Full file path
      const filePath = path.join(targetDir, filename);
      
      // Check for existing file and handle conflicts
      const finalPath = await this.handleFileConflict(filePath);
      
      // Write the markdown content
      await fs.writeFile(finalPath, result.markdown, 'utf8');
      
      // Copy attachments
      for (const attachment of result.attachments) {
        try {
          await this.copyAttachment(attachment);
        } catch (error: any) {
          errors.push({
            type: 'FILE_SYSTEM',
            message: `Failed to copy attachment ${attachment.filename}: ${error.message}`,
            timestamp: new Date(),
            retryable: true
          });
        }
      }

      logger.debug('Note written successfully', {
        title: result.metadata.title,
        filePath: finalPath,
        attachments: result.attachments.length
      });

      return { filePath: finalPath, errors };

    } catch (error: any) {
      logger.error('Failed to write note', {
        title: result.metadata.title,
        error: error.message
      });

      errors.push({
        type: 'FILE_SYSTEM',
        message: `Failed to write note: ${error.message}`,
        timestamp: new Date(),
        retryable: true
      });

      return { filePath: '', errors };
    }
  }

  /**
   * Writes multiple notes with folder organization
   */
  async writeNotes(
    results: ConversionResult[],
    organizationStrategy: 'flat' | 'by-date' | 'by-type' | 'by-database' = 'flat'
  ): Promise<{ 
    writtenFiles: string[]; 
    errors: ImportError[] 
  }> {
    const writtenFiles: string[] = [];
    const errors: ImportError[] = [];

    for (const result of results) {
      try {
        const folderPath = this.determineFolderPath(result, organizationStrategy);
        const writeResult = await this.writeNote(result, folderPath);
        
        if (writeResult.filePath) {
          writtenFiles.push(writeResult.filePath);
        }
        
        errors.push(...writeResult.errors);

      } catch (error: any) {
        errors.push({
          type: 'FILE_SYSTEM',
          message: `Failed to process note ${result.metadata.title}: ${error.message}`,
          timestamp: new Date(),
          retryable: true
        });
      }
    }

    logger.info('Batch write completed', {
      totalNotes: results.length,
      writtenFiles: writtenFiles.length,
      errors: errors.length
    });

    return { writtenFiles, errors };
  }

  /**
   * Creates an index file for imported content
   */
  async createImportIndexWithFiles(
    importedFiles: string[],
    metadata: {
      importDate: Date;
      totalPages: number;
      totalAttachments: number;
      errors: ImportError[];
    }
  ): Promise<string> {
    const indexContent = this.generateImportIndexContent(importedFiles, metadata);
    const indexPath = path.join(this.config.vaultPath, 'Notion Import Index.md');
    
    await fs.writeFile(indexPath, indexContent, 'utf8');
    
    logger.info('Import index created', { indexPath });
    return indexPath;
  }

  /**
   * Validates vault structure and permissions
   */
  async validateVault(): Promise<{ valid: boolean; issues: string[] }> {
    const issues: string[] = [];

    try {
      // Check if vault path exists and is writable
      if (!(await fs.pathExists(this.config.vaultPath))) {
        issues.push('Vault path does not exist');
        return { valid: false, issues };
      }

      const stats = await fs.stat(this.config.vaultPath);
      if (!stats.isDirectory()) {
        issues.push('Vault path is not a directory');
        return { valid: false, issues };
      }

      // Test write permissions
      const testFile = path.join(this.config.vaultPath, '.write-test');
      try {
        await fs.writeFile(testFile, 'test');
        await fs.remove(testFile);
      } catch {
        issues.push('No write permission in vault directory');
      }

      // Check attachments folder
      const attachmentsPath = path.join(this.config.vaultPath, this.config.attachmentsFolder!);
      if (await fs.pathExists(attachmentsPath)) {
        const attachStats = await fs.stat(attachmentsPath);
        if (!attachStats.isDirectory()) {
          issues.push('Attachments path exists but is not a directory');
        }
      }

      // Check for existing .obsidian folder
      const obsidianPath = path.join(this.config.vaultPath, '.obsidian');
      if (!(await fs.pathExists(obsidianPath))) {
        issues.push('No .obsidian folder found (vault may not be initialized)');
      }

    } catch (error: any) {
      issues.push(`Validation error: ${error.message}`);
    }

    const valid = issues.length === 0;
    
    logger.info('Vault validation completed', { valid, issuesCount: issues.length });
    
    return { valid, issues };
  }

  /**
   * Gets vault statistics
   */
  async getVaultStats(): Promise<VaultStructure> {
    const structure: VaultStructure = {
      notes: [],
      attachments: [],
      folders: [],
      metadata: {
        totalNotes: 0,
        totalAttachments: 0,
        lastImport: new Date().toISOString(),
        importSource: 'notion',
        version: '1.0.0'
      }
    };

    try {
      await this.scanDirectory(this.config.vaultPath, structure);
    } catch (error: any) {
      logger.error('Failed to get vault stats', { error: error.message });
    }

    return structure;
  }

  /**
   * Copies an attachment to the vault
   */
  private async copyAttachment(attachment: AttachmentInfo): Promise<void> {
    const sourcePath = attachment.localPath;
    const targetPath = path.join(
      this.config.vaultPath,
      this.config.attachmentsFolder!,
      attachment.filename
    );

    // Ensure source file exists
    if (!(await fs.pathExists(sourcePath))) {
      throw new Error(`Source attachment not found: ${sourcePath}`);
    }

    // Ensure target directory exists
    await fs.ensureDir(path.dirname(targetPath));

    // Handle file conflicts
    const finalTargetPath = await this.handleFileConflict(targetPath);

    // Copy the file
    await fs.copy(sourcePath, finalTargetPath);

    logger.debug('Attachment copied', {
      source: sourcePath,
      target: finalTargetPath
    });
  }

  /**
   * Handles file name conflicts by appending numbers
   */
  private async handleFileConflict(filePath: string): Promise<string> {
    if (!(await fs.pathExists(filePath))) {
      return filePath;
    }

    const ext = path.extname(filePath);
    const baseName = path.basename(filePath, ext);
    const dir = path.dirname(filePath);

    let counter = 1;
    let newPath = path.join(dir, `${baseName} ${counter}${ext}`);

    while (await fs.pathExists(newPath)) {
      counter++;
      newPath = path.join(dir, `${baseName} ${counter}${ext}`);
    }

    return newPath;
  }

  /**
   * Determines folder path based on organization strategy
   */
  private determineFolderPath(
    result: ConversionResult,
    strategy: 'flat' | 'by-date' | 'by-type' | 'by-database'
  ): string | undefined {
    if (!this.config.preserveStructure || strategy === 'flat') {
      return undefined;
    }

    switch (strategy) {
      case 'by-date':
        const date = new Date(result.metadata.createdTime);
        return `${date.getFullYear()}/${String(date.getMonth() + 1).padStart(2, '0')}`;

      case 'by-type':
        return result.metadata.tags?.includes('database') ? 'Databases' : 'Pages';

      case 'by-database':
        const dbTag = result.metadata.tags?.find(tag => tag.startsWith('database:'));
        return dbTag ? `Databases/${dbTag.substring(9)}` : 'Pages';

      default:
        return undefined;
    }
  }

  /**
   * Sanitizes filename for file system compatibility
   */
  private sanitizeFilename(filename: string): string {
    return filename
      .replace(/[<>:"/\\|?*]/g, '') // Remove invalid characters
      .replace(/\s+/g, ' ') // Normalize whitespace
      .trim()
      .substring(0, 200); // Limit length
  }

  /**
   * Creates basic Obsidian configuration
   */
  private async createObsidianConfig(obsidianDir: string): Promise<void> {
    const config = {
      attachmentFolderPath: this.config.attachmentsFolder,
      newFileLocation: 'root',
      newLinkFormat: 'relative',
      showLineNumber: true,
      promptDelete: false
    };

    await fs.writeJson(path.join(obsidianDir, 'app.json'), config, { spaces: 2 });

    // Create workspace file
    const workspace = {
      main: {
        id: 'main',
        type: 'split',
        children: [{
          id: 'file-explorer',
          type: 'leaf',
          state: { type: 'file-explorer' }
        }]
      }
    };

    await fs.writeJson(path.join(obsidianDir, 'workspace.json'), workspace, { spaces: 2 });
  }

  /**
   * Generates content for import index file
   */
  private generateImportIndexContent(
    importedFiles: string[],
    metadata: {
      importDate: Date;
      totalPages: number;
      totalAttachments: number;
      errors: ImportError[];
    }
  ): string {
    const lines: string[] = [];

    lines.push('---');
    lines.push('title: "Notion Import Index"');
    lines.push(`import_date: ${metadata.importDate.toISOString()}`);
    lines.push(`total_pages: ${metadata.totalPages}`);
    lines.push(`total_attachments: ${metadata.totalAttachments}`);
    lines.push(`errors: ${metadata.errors.length}`);
    lines.push('---');
    lines.push('');
    lines.push('# Notion Import Index');
    lines.push('');
    lines.push(`**Import Date:** ${metadata.importDate.toLocaleString()}`);
    lines.push(`**Total Pages:** ${metadata.totalPages}`);
    lines.push(`**Total Attachments:** ${metadata.totalAttachments}`);
    lines.push(`**Errors:** ${metadata.errors.length}`);
    lines.push('');

    if (metadata.errors.length > 0) {
      lines.push('## Import Errors');
      lines.push('');
      for (const error of metadata.errors) {
        lines.push(`- **${error.type}**: ${error.message}`);
      }
      lines.push('');
    }

    lines.push('## Imported Files');
    lines.push('');
    for (const filePath of importedFiles) {
      const relativePath = path.relative(this.config.vaultPath, filePath);
      const filename = path.basename(relativePath, '.md');
      lines.push(`- [[${filename}]]`);
    }
    lines.push('');

    return lines.join('\n');
  }

  /**
   * Recursively scans directory for vault structure
   */
  private async scanDirectory(dirPath: string, structure: VaultStructure): Promise<void> {
    const items = await fs.readdir(dirPath);

    for (const item of items) {
      const itemPath = path.join(dirPath, item);
      const stats = await fs.stat(itemPath);

      if (stats.isDirectory()) {
        if (!item.startsWith('.')) {
          structure.folders.push(path.relative(this.config.vaultPath, itemPath));
          await this.scanDirectory(itemPath, structure);
        }
      } else if (stats.isFile()) {
        const relativePath = path.relative(this.config.vaultPath, itemPath);
        const ext = path.extname(item).toLowerCase();

        if (ext === '.md') {
          structure.notes.push(relativePath);
          structure.metadata.totalNotes++;
        } else if (['.png', '.jpg', '.jpeg', '.gif', '.svg', '.pdf', '.mp4', '.mov'].includes(ext)) {
          structure.attachments.push(relativePath);
          structure.metadata.totalAttachments++;
        }
      }
    }
  }

  /**
   * Saves a file to the vault
   */
  async saveFile(filePath: string, content: string): Promise<void> {
    try {
      const fullPath = path.join(this.config.vaultPath, filePath);
      const dir = path.dirname(fullPath);
      
      // Ensure directory exists
      await fs.ensureDir(dir);
      
      // Write the file
      await fs.writeFile(fullPath, content, 'utf8');
      
      logger.debug(`Saved file: ${filePath}`);
    } catch (error: any) {
      logger.error(`Failed to save file ${filePath}`, { error: error.message });
      throw error;
    }
  }

  /**
   * Creates an import index file
   */
  async createImportIndex(metadata: any): Promise<void> {
    let content = '# Import Index\n\n';
    content += '## Import Details\n\n';
    content += `- Import Date: ${metadata.importDate}\n`;
    content += `- Total Pages: ${metadata.totalPages}\n`;
    content += `- Total Databases: ${metadata.totalDatabases}\n`;
    content += `- Total Attachments: ${metadata.totalAttachments}\n\n`;
    
    await this.saveFile('import-index.md', content);
  }
}