import * as fs from 'fs-extra';
import * as path from 'path';
import { v4 as uuidv4 } from 'uuid';
import PQueue from 'p-queue';
import pRetry from 'p-retry';
import { AttachmentInfo, ProgressInfo, ImportError } from '../types';
import { createLogger } from '../utils/logger';

const logger = createLogger('ProgressiveDownloader');

interface DownloadSession {
  id: string;
  startTime: Date;
  totalFiles: number;
  downloadedFiles: number;
  failedFiles: number;
  pausedFiles: AttachmentInfo[];
  completedFiles: AttachmentInfo[];
  errors: ImportError[];
}

export class ProgressiveDownloader {
  private queue: PQueue;
  private session: DownloadSession | null = null;
  private sessionFile: string = '';
  private onProgress?: (progress: ProgressInfo) => void;

  constructor(
    private readonly outputDir: string,
    private readonly _concurrency: number = 3,
    private readonly retryAttempts: number = 3
  ) {
    this.queue = new PQueue({ 
      concurrency: _concurrency,
      interval: 1000, // Rate limiting: max concurrency per second
      intervalCap: _concurrency
    });

    logger.info('ProgressiveDownloader initialized', {
      outputDir,
      concurrency: _concurrency,
      retryAttempts
    });
  }

  /**
   * Starts a new download session
   */
  async startSession(attachments: AttachmentInfo[]): Promise<string> {
    const sessionId = uuidv4();
    this.sessionFile = path.join(this.outputDir, '.download-session.json');

    this.session = {
      id: sessionId,
      startTime: new Date(),
      totalFiles: attachments.length,
      downloadedFiles: 0,
      failedFiles: 0,
      pausedFiles: [...attachments],
      completedFiles: [],
      errors: []
    };

    await this.saveSession();
    logger.info(`Started download session ${sessionId}`, {
      totalFiles: attachments.length
    });

    return sessionId;
  }

  /**
   * Resumes a previous download session
   */
  async resumeSession(): Promise<string | null> {
    try {
      if (await fs.pathExists(this.sessionFile)) {
        const sessionData = await fs.readJson(this.sessionFile);
        this.session = {
          ...sessionData,
          startTime: new Date(sessionData.startTime)
        };

        logger.info(`Resumed download session ${this.session!.id}`, {
          remainingFiles: this.session!.pausedFiles.length,
          completedFiles: this.session!.downloadedFiles
        });

        return this.session!.id;
      }
    } catch (error: any) {
      logger.error('Failed to resume session', { error: error.message });
    }

    return null;
  }

  /**
   * Downloads all attachments with progress tracking
   */
  async downloadAll(): Promise<{ 
    completed: AttachmentInfo[]; 
    failed: AttachmentInfo[]; 
    errors: ImportError[] 
  }> {
    if (!this.session) {
      throw new Error('No active download session');
    }

    logger.info('Starting progressive download', {
      sessionId: this.session.id,
      totalFiles: this.session.totalFiles,
      remainingFiles: this.session.pausedFiles.length
    });

    // Ensure output directory exists
    await fs.ensureDir(this.outputDir);
    await fs.ensureDir(path.join(this.outputDir, 'attachments'));

    // Add all pending files to queue
    for (const attachment of this.session.pausedFiles) {
      this.queue.add(() => this.downloadFile(attachment));
    }

    // Wait for all downloads to complete
    await this.queue.onIdle();

    // Clean up session
    const result = {
      completed: this.session.completedFiles,
      failed: this.session.pausedFiles.filter(f => !this.session!.completedFiles.find(c => c.originalUrl === f.originalUrl)),
      errors: this.session.errors
    };

    await this.cleanupSession();

    logger.info('Download session completed', {
      sessionId: this.session.id,
      completed: result.completed.length,
      failed: result.failed.length,
      errors: result.errors.length
    });

    return result;
  }

  /**
   * Downloads a single file with retry logic
   */
  private async downloadFile(attachment: AttachmentInfo): Promise<void> {
    if (!this.session) return;

    try {
      await pRetry(async () => {
        await this.downloadSingleFile(attachment);
      }, {
        retries: this.retryAttempts,
        onFailedAttempt: (error) => {
          logger.warn(`Download attempt failed for ${attachment.filename}`, {
            attempt: error.attemptNumber,
            retriesLeft: error.retriesLeft,
            error: error.message
          });
        }
      });

      // Mark as completed
      attachment.downloaded = true;
      this.session.completedFiles.push(attachment);
      this.session.downloadedFiles++;

      // Remove from paused files
      this.session.pausedFiles = this.session.pausedFiles.filter(
        f => f.originalUrl !== attachment.originalUrl
      );

      await this.saveSession();
      this.emitProgress();

      logger.debug(`Successfully downloaded ${attachment.filename}`);

    } catch (error: any) {
      logger.error(`Failed to download ${attachment.filename}`, {
        error: error.message,
        url: attachment.originalUrl
      });

      this.session.failedFiles++;
      this.session.errors.push({
        type: 'NETWORK',
        message: `Failed to download ${attachment.filename}: ${error.message}`,
        timestamp: new Date(),
        retryable: true
      });

      await this.saveSession();
      this.emitProgress();
    }
  }

  /**
   * Downloads a single file without retry logic
   */
  private async downloadSingleFile(attachment: AttachmentInfo): Promise<void> {
    const outputPath = path.join(this.outputDir, attachment.localPath);
    
    // Skip if file already exists and has content
    if (await fs.pathExists(outputPath)) {
      const stats = await fs.stat(outputPath);
      if (stats.size > 0) {
        logger.debug(`File already exists, skipping: ${attachment.filename}`);
        return;
      }
    }

    // Ensure directory exists
    await fs.ensureDir(path.dirname(outputPath));

    // Download the file
    const response = await fetch(attachment.originalUrl);
    
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }

    // Get file size if available
    const contentLength = response.headers.get('content-length');
    if (contentLength) {
      attachment.size = parseInt(contentLength, 10);
    }

    // Write file to disk
    const buffer = Buffer.from(await response.arrayBuffer());
    await fs.writeFile(outputPath, buffer);

    logger.debug(`Downloaded ${attachment.filename}`, {
      size: buffer.length,
      path: outputPath
    });
  }

  /**
   * Pauses the download session
   */
  async pauseSession(): Promise<void> {
    if (!this.session) return;

    this.queue.pause();
    await this.saveSession();
    
    logger.info(`Paused download session ${this.session.id}`);
  }

  /**
   * Resumes a paused download session
   */
  resumeDownloads(): void {
    if (!this.session) return;

    this.queue.start();
    logger.info(`Resumed download session ${this.session.id}`);
  }

  /**
   * Cancels the current download session
   */
  async cancelSession(): Promise<void> {
    if (!this.session) return;

    this.queue.clear();
    this.queue.pause();
    
    await this.cleanupSession();
    logger.info(`Cancelled download session ${this.session.id}`);
  }

  /**
   * Sets progress callback
   */
  setProgressCallback(callback: (progress: ProgressInfo) => void): void {
    this.onProgress = callback;
  }

  /**
   * Gets current progress information
   */
  getProgress(): ProgressInfo | null {
    if (!this.session) return null;

    const elapsed = Date.now() - this.session.startTime.getTime();
    const filesPerMs = this.session.downloadedFiles / elapsed;
    const remainingFiles = this.session.totalFiles - this.session.downloadedFiles;
    const estimatedTimeRemaining = remainingFiles / filesPerMs;

    return {
      totalPages: 0, // Not applicable for downloader
      processedPages: 0,
      totalFiles: this.session.totalFiles,
      downloadedFiles: this.session.downloadedFiles,
      currentOperation: `Downloading files (${this.queue.size} queued)`,
      startTime: this.session.startTime,
      estimatedTimeRemaining: isFinite(estimatedTimeRemaining) ? estimatedTimeRemaining : undefined,
      errors: this.session.errors
    };
  }

  /**
   * Saves the current session state
   */
  private async saveSession(): Promise<void> {
    if (!this.session) return;

    try {
      await fs.writeJson(this.sessionFile, this.session, { spaces: 2 });
    } catch (error: any) {
      logger.error('Failed to save session', { error: error.message });
    }
  }

  /**
   * Emits progress update
   */
  private emitProgress(): void {
    if (this.onProgress) {
      const progress = this.getProgress();
      if (progress) {
        this.onProgress(progress);
      }
    }
  }

  /**
   * Cleans up session files
   */
  private async cleanupSession(): Promise<void> {
    try {
      if (await fs.pathExists(this.sessionFile)) {
        await fs.remove(this.sessionFile);
      }
      this.session = null;
    } catch (error: any) {
      logger.error('Failed to cleanup session', { error: error.message });
    }
  }

  /**
   * Validates downloaded files
   */
  async validateDownloads(attachments: AttachmentInfo[]): Promise<AttachmentInfo[]> {
    const invalid: AttachmentInfo[] = [];

    for (const attachment of attachments) {
      const filePath = path.join(this.outputDir, attachment.localPath);
      
      try {
        if (!(await fs.pathExists(filePath))) {
          invalid.push(attachment);
          continue;
        }

        const stats = await fs.stat(filePath);
        if (stats.size === 0) {
          invalid.push(attachment);
          continue;
        }

        // If we have expected size, validate it
        if (attachment.size && stats.size !== attachment.size) {
          logger.warn(`File size mismatch for ${attachment.filename}`, {
            expected: attachment.size,
            actual: stats.size
          });
        }

      } catch (error: any) {
        logger.error(`Failed to validate ${attachment.filename}`, { error: error.message });
        invalid.push(attachment);
      }
    }

    if (invalid.length > 0) {
      logger.warn(`Found ${invalid.length} invalid downloads`);
    }

    return invalid;
  }

  /**
   * Gets download statistics
   */
  getStats(): {
    queueSize: number;
    completed: number;
    failed: number;
    total: number;
    isPaused: boolean;
  } | null {
    if (!this.session) return null;

    return {
      queueSize: this.queue.size,
      completed: this.session.downloadedFiles,
      failed: this.session.failedFiles,
      total: this.session.totalFiles,
      isPaused: this.queue.isPaused
    };
  }
}