import { Modal } from 'obsidian';
import { ImportProgress } from '../settings';
import { ProgressInfo } from '../../types';
import { ProgressTracker } from '../../core/ProgressTracker';
export declare class ProgressModal extends Modal {
    private progressTracker;
    private progressBar;
    private statusEl;
    private detailsEl;
    private cancelButton;
    private closeButton;
    private isCompleted;
    private isCancelled;
    private updateInterval;
    constructor(app: any, progressTracker: ProgressTracker);
    onOpen(): void;
    onClose(): void;
    updateProgress(progress: ImportProgress | ProgressInfo): void;
    updateStatus(message: string): void;
    setComplete(): void;
    setError(error: string): void;
    private startProgressUpdates;
    private updateDetails;
    private handleCancel;
    private addStyles;
}
//# sourceMappingURL=ProgressModal.d.ts.map