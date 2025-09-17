import * as fs from 'fs-extra';
import * as path from 'path';
import { EventEmitter } from 'events';
import { ProgressInfo, ProgressState, ImportError } from '../types';

export class ProgressTracker extends EventEmitter {
  state: ProgressState; // Made public for NotionImporter access
  private progressFile: string;
  private saveInterval: NodeJS.Timeout | null = null;
  private startTime: number;

  constructor(progressFile?: string) {
    super();
    this.progressFile = progressFile || path.join(process.cwd(), '.import-progress.json');
    this.startTime = Date.now();
    this.state = this.createInitialState();
  }

  private createInitialState(): ProgressState {
    return {
      status: 'initializing',
      startTime: this.startTime,
      endTime: null,
      currentPhase: 'setup',
      totalItems: 0,
      processedItems: 0,
      failedItems: 0,
      skippedItems: 0,
      errors: [] as ImportError[],
      processedPages: new Set(),
      processedDatabases: new Set(),
      downloadedFiles: new Set(),
      currentItem: null,
      phases: {
        setup: { status: 'pending', startTime: null, endTime: null },
        discovery: { status: 'pending', startTime: null, endTime: null },
        download: { status: 'pending', startTime: null, endTime: null },
        conversion: { status: 'pending', startTime: null, endTime: null },
        writing: { status: 'pending', startTime: null, endTime: null },
        cleanup: { status: 'pending', startTime: null, endTime: null },
      },
    };
  }

  async loadProgress(): Promise<boolean> {
    try {
      if (await fs.pathExists(this.progressFile)) {
        const data = await fs.readJson(this.progressFile);
        this.state = {
          ...data,
          processedPages: new Set(data.processedPages || []),
          processedDatabases: new Set(data.processedDatabases || []),
          downloadedFiles: new Set(data.downloadedFiles || []),
        };
        return true;
      }
    } catch (error) {
      console.error('Failed to load progress:', error);
    }
    return false;
  }

  async saveProgress(): Promise<void> {
    try {
      const data = {
        ...this.state,
        processedPages: Array.from(this.state.processedPages),
        processedDatabases: Array.from(this.state.processedDatabases),
        downloadedFiles: Array.from(this.state.downloadedFiles),
      };
      await fs.writeJson(this.progressFile, data, { spaces: 2 });
    } catch (error) {
      console.error('Failed to save progress:', error);
    }
  }

  startAutoSave(intervalMs: number = 5000): void {
    this.stopAutoSave();
    this.saveInterval = setInterval(() => {
      this.saveProgress().catch(console.error);
    }, intervalMs);
  }

  stopAutoSave(): void {
    if (this.saveInterval) {
      clearInterval(this.saveInterval);
      this.saveInterval = null;
    }
  }

  startPhase(phase: keyof ProgressState['phases']): void {
    this.state.currentPhase = phase as string;
    this.state.phases[phase] = {
      status: 'in-progress',
      startTime: Date.now(),
      endTime: null,
    };
    this.emit('phaseStart', phase);
  }

  completePhase(phase: keyof ProgressState['phases']): void {
    if (this.state.phases[phase]) {
      this.state.phases[phase].status = 'completed';
      this.state.phases[phase].endTime = Date.now();
    }
    this.emit('phaseComplete', phase);
  }

  updateProgress(info: Partial<ProgressInfo>): void {
    if (info.totalItems !== undefined) this.state.totalItems = info.totalItems;
    if (info.processedItems !== undefined) this.state.processedItems = info.processedItems;
    if (info.currentItem !== undefined) this.state.currentItem = info.currentItem;
    if (info.status !== undefined) this.state.status = info.status;

    this.emit('progress', this.getProgress());
  }

  incrementProcessed(): void {
    this.state.processedItems++;
    this.emit('progress', this.getProgress());
  }

  incrementFailed(error?: Error | string): void {
    this.state.failedItems++;
    if (error) {
      const importError: ImportError = {
        type: 'CONVERSION',
        message: typeof error === 'string' ? error : error.message || 'Unknown error',
        timestamp: new Date(),
        retryable: false
      };
      if (this.state.currentItem) {
        importError.pageId = this.state.currentItem;
      }
      this.state.errors.push(importError);
    }
    this.emit('error', error);
  }

  incrementSkipped(): void {
    this.state.skippedItems++;
    this.emit('skip', this.state.currentItem);
  }

  addProcessedPage(pageId: string): void {
    this.state.processedPages.add(pageId);
  }

  addProcessedDatabase(databaseId: string): void {
    this.state.processedDatabases.add(databaseId);
  }

  addDownloadedFile(filePath: string): void {
    this.state.downloadedFiles.add(filePath);
  }

  isPageProcessed(pageId: string): boolean {
    return this.state.processedPages.has(pageId);
  }

  isDatabaseProcessed(databaseId: string): boolean {
    return this.state.processedDatabases.has(databaseId);
  }

  getProgress(): ProgressInfo {
    const elapsedTime = Date.now() - this.startTime;
    const itemsPerSecond = this.state.processedItems / (elapsedTime / 1000);
    const remainingItems = this.state.totalItems - this.state.processedItems;
    const estimatedTimeRemaining = remainingItems / itemsPerSecond * 1000;

    return {
      status: this.state.status,
      currentPhase: this.state.currentPhase as string,
      totalItems: this.state.totalItems,
      processedItems: this.state.processedItems,
      failedItems: this.state.failedItems,
      skippedItems: this.state.skippedItems,
      percentage: this.state.totalItems > 0 
        ? Math.round((this.state.processedItems / this.state.totalItems) * 100) 
        : 0,
      elapsedTime,
      estimatedTimeRemaining: isFinite(estimatedTimeRemaining) ? estimatedTimeRemaining : 0,
      currentItem: this.state.currentItem || '',
      currentOperation: 'processing',
      totalPages: this.state.processedPages.size,
      processedPages: this.state.processedPages.size,
      totalFiles: this.state.downloadedFiles.size,
      downloadedFiles: this.state.downloadedFiles.size,
      startTime: new Date(this.startTime),
      errors: this.state.errors.slice(-10), // Last 10 errors
    };
  }

  complete(): void {
    this.state.status = 'completed';
    this.state.endTime = Date.now();
    this.stopAutoSave();
    this.saveProgress().then(() => {
      this.emit('complete', this.getProgress());
    });
  }

  cancel(): void {
    this.state.status = 'failed';
    this.state.endTime = Date.now();
    this.stopAutoSave();
    this.emit('cancelled', this.getProgress());
  }

  async cleanup(): Promise<void> {
    this.stopAutoSave();
    try {
      if (await fs.pathExists(this.progressFile)) {
        await fs.remove(this.progressFile);
      }
    } catch (error) {
      console.error('Failed to cleanup progress file:', error);
    }
  }
}

export default ProgressTracker;