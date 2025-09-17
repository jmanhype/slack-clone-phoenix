import { AttachmentInfo, ProgressInfo, ImportError } from '../types';
export declare class ProgressiveDownloader {
    private readonly outputDir;
    private readonly _concurrency;
    private readonly retryAttempts;
    private queue;
    private session;
    private sessionFile;
    private onProgress?;
    constructor(outputDir: string, _concurrency?: number, retryAttempts?: number);
    /**
     * Starts a new download session
     */
    startSession(attachments: AttachmentInfo[]): Promise<string>;
    /**
     * Resumes a previous download session
     */
    resumeSession(): Promise<string | null>;
    /**
     * Downloads all attachments with progress tracking
     */
    downloadAll(): Promise<{
        completed: AttachmentInfo[];
        failed: AttachmentInfo[];
        errors: ImportError[];
    }>;
    /**
     * Downloads a single file with retry logic
     */
    private downloadFile;
    /**
     * Downloads a single file without retry logic
     */
    private downloadSingleFile;
    /**
     * Pauses the download session
     */
    pauseSession(): Promise<void>;
    /**
     * Resumes a paused download session
     */
    resumeDownloads(): void;
    /**
     * Cancels the current download session
     */
    cancelSession(): Promise<void>;
    /**
     * Sets progress callback
     */
    setProgressCallback(callback: (progress: ProgressInfo) => void): void;
    /**
     * Gets current progress information
     */
    getProgress(): ProgressInfo | null;
    /**
     * Saves the current session state
     */
    private saveSession;
    /**
     * Emits progress update
     */
    private emitProgress;
    /**
     * Cleans up session files
     */
    private cleanupSession;
    /**
     * Validates downloaded files
     */
    validateDownloads(attachments: AttachmentInfo[]): Promise<AttachmentInfo[]>;
    /**
     * Gets download statistics
     */
    getStats(): {
        queueSize: number;
        completed: number;
        failed: number;
        total: number;
        isPaused: boolean;
    } | null;
}
//# sourceMappingURL=ProgressiveDownloader.d.ts.map