import { EventEmitter } from 'events';
import { ProgressInfo, ProgressState } from '../types';
export declare class ProgressTracker extends EventEmitter {
    state: ProgressState;
    private progressFile;
    private saveInterval;
    private startTime;
    constructor(progressFile?: string);
    private createInitialState;
    loadProgress(): Promise<boolean>;
    saveProgress(): Promise<void>;
    startAutoSave(intervalMs?: number): void;
    stopAutoSave(): void;
    startPhase(phase: keyof ProgressState['phases']): void;
    completePhase(phase: keyof ProgressState['phases']): void;
    updateProgress(info: Partial<ProgressInfo>): void;
    incrementProcessed(): void;
    incrementFailed(error?: Error | string): void;
    incrementSkipped(): void;
    addProcessedPage(pageId: string): void;
    addProcessedDatabase(databaseId: string): void;
    addDownloadedFile(filePath: string): void;
    isPageProcessed(pageId: string): boolean;
    isDatabaseProcessed(databaseId: string): boolean;
    getProgress(): ProgressInfo;
    complete(): void;
    cancel(): void;
    cleanup(): Promise<void>;
}
export default ProgressTracker;
//# sourceMappingURL=ProgressTracker.d.ts.map