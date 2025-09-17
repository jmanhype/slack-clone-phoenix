import { Modal, Notice, ButtonComponent, ProgressBarComponent } from 'obsidian';
import { ImportProgress } from '../settings';
import { ProgressInfo } from '../../types';
import { ProgressTracker } from '../../core/ProgressTracker';

export class ProgressModal extends Modal {
  private progressTracker: ProgressTracker;
  private progressBar!: ProgressBarComponent;
  private statusEl!: HTMLElement;
  private detailsEl!: HTMLElement;
  private cancelButton!: ButtonComponent;
  private closeButton!: ButtonComponent;
  private isCompleted = false;
  private isCancelled = false;
  private updateInterval!: NodeJS.Timeout;

  constructor(app: any, progressTracker: ProgressTracker) {
    super(app);
    this.progressTracker = progressTracker;
  }

  onOpen() {
    const { contentEl } = this;
    contentEl.empty();
    contentEl.addClass('notion-importer-progress-modal');

    // Header
    const headerEl = contentEl.createEl('div', { cls: 'progress-header' });
    headerEl.createEl('h2', { text: 'Importing from Notion' });

    // Progress bar container
    const progressContainer = contentEl.createEl('div', { cls: 'progress-container' });
    
    // Progress bar
    const progressBarContainer = progressContainer.createEl('div', { cls: 'progress-bar-container' });
    this.progressBar = new ProgressBarComponent(progressBarContainer);
    this.progressBar.setValue(0);

    // Status text
    this.statusEl = progressContainer.createEl('div', { 
      cls: 'progress-status',
      text: 'Initializing...'
    });

    // Details section
    const detailsContainer = contentEl.createEl('div', { cls: 'progress-details' });
    detailsContainer.createEl('h3', { text: 'Details' });
    this.detailsEl = detailsContainer.createEl('div', { cls: 'progress-details-content' });

    // Buttons
    const buttonContainer = contentEl.createEl('div', { cls: 'progress-buttons' });
    
    this.cancelButton = new ButtonComponent(buttonContainer);
    this.cancelButton
      .setButtonText('Cancel')
      .setWarning()
      .onClick(() => {
        this.handleCancel();
      });

    this.closeButton = new ButtonComponent(buttonContainer);
    this.closeButton
      .setButtonText('Close')
      .setCta()
      .setDisabled(true)
      .onClick(() => {
        this.close();
      });

    // Start updating progress
    this.startProgressUpdates();

    // Add styles
    this.addStyles();
  }

  onClose() {
    if (this.updateInterval) {
      clearInterval(this.updateInterval);
    }
    
    const { contentEl } = this;
    contentEl.empty();
  }

  updateProgress(progress: ImportProgress | ProgressInfo) {
    if (this.isCompleted || this.isCancelled) {
      return;
    }

    // Handle different progress types
    const current = 'current' in progress ? progress.current : progress.processedItems || 0;
    const total = 'total' in progress ? progress.total : progress.totalItems || 0;
    const stage = 'stage' in progress ? progress.stage : progress.currentPhase || '';
    const currentItem = progress.currentItem || '';
    const message = 'message' in progress ? progress.message : '';

    // Update progress bar
    const percentage = total > 0 ? (current / total) * 100 : 0;
    this.progressBar.setValue(percentage);

    // Update status text
    let statusText = message || `${stage}: ${current}/${total}`;
    if (currentItem) {
      statusText += ` - ${currentItem}`;
    }
    this.statusEl.setText(statusText);

    // Update details
    this.updateDetails(progress);

    // Check if completed
    if (stage === 'complete' || stage === 'completed') {
      this.setComplete();
    } else if (stage === 'error' || stage === 'failed') {
      const error = 'error' in progress ? progress.error : 'Unknown error occurred';
      this.setError(error || 'Unknown error occurred');
    }
  }

  updateStatus(message: string) {
    this.statusEl.setText(message);
  }

  setComplete() {
    if (this.isCompleted) return;
    
    this.isCompleted = true;
    this.progressBar.setValue(100);
    this.statusEl.setText('Import completed successfully!');
    
    // Update buttons
    this.cancelButton.setDisabled(true);
    this.closeButton.setDisabled(false);
    
    // Add success styling
    this.statusEl.addClass('success');
    
    // Show completion notice
    new Notice('Notion import completed successfully!');
  }

  setError(error: string) {
    this.isCompleted = true;
    this.statusEl.setText(`Import failed: ${error}`);
    
    // Update buttons
    this.cancelButton.setButtonText('Close').setWarning();
    this.closeButton.setDisabled(false);
    
    // Add error styling
    this.statusEl.addClass('error');
    
    // Show error details
    this.detailsEl.createEl('div', { 
      cls: 'error-details',
      text: error 
    });
    
    // Show error notice
    new Notice(`Import failed: ${error}`, 0);
  }

  private startProgressUpdates() {
    this.updateInterval = setInterval(() => {
      if (this.isCompleted || this.isCancelled) {
        clearInterval(this.updateInterval);
        return;
      }

      const progress = this.progressTracker.getProgress();
      this.updateProgress(progress);
    }, 500);
  }

  private updateDetails(progress: ImportProgress | ProgressInfo) {
    this.detailsEl.empty();

    // Handle different progress types
    const current = 'current' in progress ? progress.current : progress.processedItems || 0;
    const total = 'total' in progress ? progress.total : progress.totalItems || 0;
    const stage = 'stage' in progress ? progress.stage : progress.currentPhase || '';
    const currentItem = progress.currentItem || '';
    const startTime = progress.startTime || null;
    const estimatedTimeRemaining = progress.estimatedTimeRemaining || null;

    // Stage information
    const stageEl = this.detailsEl.createEl('div', { cls: 'detail-row' });
    stageEl.createEl('span', { cls: 'detail-label', text: 'Stage:' });
    stageEl.createEl('span', { cls: 'detail-value', text: stage });

    // Progress information
    const progressEl = this.detailsEl.createEl('div', { cls: 'detail-row' });
    progressEl.createEl('span', { cls: 'detail-label', text: 'Progress:' });
    const percentage = total > 0 ? Math.round((current / total) * 100) : 0;
    progressEl.createEl('span', { 
      cls: 'detail-value', 
      text: `${current}/${total} (${percentage}%)`
    });

    // Current item
    if (currentItem) {
      const itemEl = this.detailsEl.createEl('div', { cls: 'detail-row' });
      itemEl.createEl('span', { cls: 'detail-label', text: 'Current:' });
      itemEl.createEl('span', { cls: 'detail-value', text: currentItem });
    }

    // Time information
    if (startTime) {
      const startDate = startTime instanceof Date ? startTime : new Date(startTime);
      const elapsed = Date.now() - startDate.getTime();
      const elapsedMinutes = Math.floor(elapsed / 60000);
      const elapsedSeconds = Math.floor((elapsed % 60000) / 1000);
      
      const timeEl = this.detailsEl.createEl('div', { cls: 'detail-row' });
      timeEl.createEl('span', { cls: 'detail-label', text: 'Elapsed:' });
      timeEl.createEl('span', { 
        cls: 'detail-value', 
        text: `${elapsedMinutes}:${elapsedSeconds.toString().padStart(2, '0')}`
      });

      // Estimated time remaining
      if (estimatedTimeRemaining) {
        const remainingMinutes = Math.floor(estimatedTimeRemaining / 60000);
        const remainingSeconds = Math.floor((estimatedTimeRemaining % 60000) / 1000);
        
        const etaEl = this.detailsEl.createEl('div', { cls: 'detail-row' });
        etaEl.createEl('span', { cls: 'detail-label', text: 'ETA:' });
        etaEl.createEl('span', { 
          cls: 'detail-value', 
          text: `${remainingMinutes}:${remainingSeconds.toString().padStart(2, '0')}`
        });
      }
    }
  }

  private handleCancel() {
    if (this.isCompleted) {
      this.close();
      return;
    }

    // Show confirmation
    const confirmModal = new ConfirmCancelModal(this.app, () => {
      this.isCancelled = true;
      this.statusEl.setText('Cancelling import...');
      this.cancelButton.setDisabled(true);
      
      // Signal cancellation to progress tracker
      this.progressTracker.cancel();
      
      // Close after a short delay
      setTimeout(() => {
        this.close();
      }, 1000);
    });
    
    confirmModal.open();
  }

  private addStyles() {
    if (document.querySelector('#notion-importer-progress-styles')) {
      return;
    }

    const style = document.createElement('style');
    style.id = 'notion-importer-progress-styles';
    style.textContent = `
      .notion-importer-progress-modal {
        width: 500px;
        max-width: 90vw;
      }

      .progress-header {
        text-align: center;
        margin-bottom: 20px;
      }

      .progress-container {
        margin-bottom: 20px;
      }

      .progress-bar-container {
        margin-bottom: 10px;
      }

      .progress-status {
        text-align: center;
        font-weight: 500;
        padding: 5px;
        border-radius: 4px;
      }

      .progress-status.success {
        background-color: var(--background-modifier-success);
        color: var(--text-success);
      }

      .progress-status.error {
        background-color: var(--background-modifier-error);
        color: var(--text-error);
      }

      .progress-details {
        margin-bottom: 20px;
        max-height: 200px;
        overflow-y: auto;
      }

      .progress-details h3 {
        margin-bottom: 10px;
        color: var(--text-muted);
      }

      .progress-details-content {
        background-color: var(--background-secondary);
        padding: 10px;
        border-radius: 4px;
        font-family: var(--font-monospace);
        font-size: 0.9em;
      }

      .detail-row {
        display: flex;
        justify-content: space-between;
        margin-bottom: 5px;
      }

      .detail-label {
        font-weight: 500;
        color: var(--text-muted);
        min-width: 80px;
      }

      .detail-value {
        text-align: right;
        color: var(--text-normal);
      }

      .error-details {
        background-color: var(--background-modifier-error);
        color: var(--text-error);
        padding: 10px;
        border-radius: 4px;
        margin-top: 10px;
        word-wrap: break-word;
      }

      .progress-buttons {
        display: flex;
        gap: 10px;
        justify-content: flex-end;
      }
    `;
    
    document.head.appendChild(style);
  }
}

class ConfirmCancelModal extends Modal {
  private onConfirm: () => void;

  constructor(app: any, onConfirm: () => void) {
    super(app);
    this.onConfirm = onConfirm;
  }

  onOpen() {
    const { contentEl } = this;
    contentEl.empty();

    contentEl.createEl('h2', { text: 'Cancel Import?' });
    contentEl.createEl('p', { 
      text: 'Are you sure you want to cancel the import? This will stop the process and any partially imported content may be incomplete.' 
    });

    const buttonContainer = contentEl.createEl('div', { cls: 'modal-button-container' });
    
    const cancelButton = new ButtonComponent(buttonContainer);
    cancelButton
      .setButtonText('Continue Import')
      .setCta()
      .onClick(() => {
        this.close();
      });

    const confirmButton = new ButtonComponent(buttonContainer);
    confirmButton
      .setButtonText('Cancel Import')
      .setWarning()
      .onClick(() => {
        this.close();
        this.onConfirm();
      });
  }

  onClose() {
    const { contentEl } = this;
    contentEl.empty();
  }
}