"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.ProgressiveDownloader = void 0;
const fs = __importStar(require("fs-extra"));
const path = __importStar(require("path"));
const uuid_1 = require("uuid");
const p_queue_1 = __importDefault(require("p-queue"));
const p_retry_1 = __importDefault(require("p-retry"));
const logger_1 = require("../utils/logger");
const logger = (0, logger_1.createLogger)('ProgressiveDownloader');
class ProgressiveDownloader {
    constructor(outputDir, _concurrency = 3, retryAttempts = 3) {
        this.outputDir = outputDir;
        this._concurrency = _concurrency;
        this.retryAttempts = retryAttempts;
        this.session = null;
        this.sessionFile = '';
        this.queue = new p_queue_1.default({
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
    async startSession(attachments) {
        const sessionId = (0, uuid_1.v4)();
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
    async resumeSession() {
        try {
            if (await fs.pathExists(this.sessionFile)) {
                const sessionData = await fs.readJson(this.sessionFile);
                this.session = {
                    ...sessionData,
                    startTime: new Date(sessionData.startTime)
                };
                logger.info(`Resumed download session ${this.session.id}`, {
                    remainingFiles: this.session.pausedFiles.length,
                    completedFiles: this.session.downloadedFiles
                });
                return this.session.id;
            }
        }
        catch (error) {
            logger.error('Failed to resume session', { error: error.message });
        }
        return null;
    }
    /**
     * Downloads all attachments with progress tracking
     */
    async downloadAll() {
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
            failed: this.session.pausedFiles.filter(f => !this.session.completedFiles.find(c => c.originalUrl === f.originalUrl)),
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
    async downloadFile(attachment) {
        if (!this.session)
            return;
        try {
            await (0, p_retry_1.default)(async () => {
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
            this.session.pausedFiles = this.session.pausedFiles.filter(f => f.originalUrl !== attachment.originalUrl);
            await this.saveSession();
            this.emitProgress();
            logger.debug(`Successfully downloaded ${attachment.filename}`);
        }
        catch (error) {
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
    async downloadSingleFile(attachment) {
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
    async pauseSession() {
        if (!this.session)
            return;
        this.queue.pause();
        await this.saveSession();
        logger.info(`Paused download session ${this.session.id}`);
    }
    /**
     * Resumes a paused download session
     */
    resumeDownloads() {
        if (!this.session)
            return;
        this.queue.start();
        logger.info(`Resumed download session ${this.session.id}`);
    }
    /**
     * Cancels the current download session
     */
    async cancelSession() {
        if (!this.session)
            return;
        this.queue.clear();
        this.queue.pause();
        await this.cleanupSession();
        logger.info(`Cancelled download session ${this.session.id}`);
    }
    /**
     * Sets progress callback
     */
    setProgressCallback(callback) {
        this.onProgress = callback;
    }
    /**
     * Gets current progress information
     */
    getProgress() {
        if (!this.session)
            return null;
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
    async saveSession() {
        if (!this.session)
            return;
        try {
            await fs.writeJson(this.sessionFile, this.session, { spaces: 2 });
        }
        catch (error) {
            logger.error('Failed to save session', { error: error.message });
        }
    }
    /**
     * Emits progress update
     */
    emitProgress() {
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
    async cleanupSession() {
        try {
            if (await fs.pathExists(this.sessionFile)) {
                await fs.remove(this.sessionFile);
            }
            this.session = null;
        }
        catch (error) {
            logger.error('Failed to cleanup session', { error: error.message });
        }
    }
    /**
     * Validates downloaded files
     */
    async validateDownloads(attachments) {
        const invalid = [];
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
            }
            catch (error) {
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
    getStats() {
        if (!this.session)
            return null;
        return {
            queueSize: this.queue.size,
            completed: this.session.downloadedFiles,
            failed: this.session.failedFiles,
            total: this.session.totalFiles,
            isPaused: this.queue.isPaused
        };
    }
}
exports.ProgressiveDownloader = ProgressiveDownloader;
//# sourceMappingURL=ProgressiveDownloader.js.map