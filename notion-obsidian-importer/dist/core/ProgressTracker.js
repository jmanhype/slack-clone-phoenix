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
Object.defineProperty(exports, "__esModule", { value: true });
exports.ProgressTracker = void 0;
const fs = __importStar(require("fs-extra"));
const path = __importStar(require("path"));
const events_1 = require("events");
class ProgressTracker extends events_1.EventEmitter {
    constructor(progressFile) {
        super();
        this.saveInterval = null;
        this.progressFile = progressFile || path.join(process.cwd(), '.import-progress.json');
        this.startTime = Date.now();
        this.state = this.createInitialState();
    }
    createInitialState() {
        return {
            status: 'initializing',
            startTime: this.startTime,
            endTime: null,
            currentPhase: 'setup',
            totalItems: 0,
            processedItems: 0,
            failedItems: 0,
            skippedItems: 0,
            errors: [],
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
    async loadProgress() {
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
        }
        catch (error) {
            console.error('Failed to load progress:', error);
        }
        return false;
    }
    async saveProgress() {
        try {
            const data = {
                ...this.state,
                processedPages: Array.from(this.state.processedPages),
                processedDatabases: Array.from(this.state.processedDatabases),
                downloadedFiles: Array.from(this.state.downloadedFiles),
            };
            await fs.writeJson(this.progressFile, data, { spaces: 2 });
        }
        catch (error) {
            console.error('Failed to save progress:', error);
        }
    }
    startAutoSave(intervalMs = 5000) {
        this.stopAutoSave();
        this.saveInterval = setInterval(() => {
            this.saveProgress().catch(console.error);
        }, intervalMs);
    }
    stopAutoSave() {
        if (this.saveInterval) {
            clearInterval(this.saveInterval);
            this.saveInterval = null;
        }
    }
    startPhase(phase) {
        this.state.currentPhase = phase;
        this.state.phases[phase] = {
            status: 'in-progress',
            startTime: Date.now(),
            endTime: null,
        };
        this.emit('phaseStart', phase);
    }
    completePhase(phase) {
        if (this.state.phases[phase]) {
            this.state.phases[phase].status = 'completed';
            this.state.phases[phase].endTime = Date.now();
        }
        this.emit('phaseComplete', phase);
    }
    updateProgress(info) {
        if (info.totalItems !== undefined)
            this.state.totalItems = info.totalItems;
        if (info.processedItems !== undefined)
            this.state.processedItems = info.processedItems;
        if (info.currentItem !== undefined)
            this.state.currentItem = info.currentItem;
        if (info.status !== undefined)
            this.state.status = info.status;
        this.emit('progress', this.getProgress());
    }
    incrementProcessed() {
        this.state.processedItems++;
        this.emit('progress', this.getProgress());
    }
    incrementFailed(error) {
        this.state.failedItems++;
        if (error) {
            const importError = {
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
    incrementSkipped() {
        this.state.skippedItems++;
        this.emit('skip', this.state.currentItem);
    }
    addProcessedPage(pageId) {
        this.state.processedPages.add(pageId);
    }
    addProcessedDatabase(databaseId) {
        this.state.processedDatabases.add(databaseId);
    }
    addDownloadedFile(filePath) {
        this.state.downloadedFiles.add(filePath);
    }
    isPageProcessed(pageId) {
        return this.state.processedPages.has(pageId);
    }
    isDatabaseProcessed(databaseId) {
        return this.state.processedDatabases.has(databaseId);
    }
    getProgress() {
        const elapsedTime = Date.now() - this.startTime;
        const itemsPerSecond = this.state.processedItems / (elapsedTime / 1000);
        const remainingItems = this.state.totalItems - this.state.processedItems;
        const estimatedTimeRemaining = remainingItems / itemsPerSecond * 1000;
        return {
            status: this.state.status,
            currentPhase: this.state.currentPhase,
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
    complete() {
        this.state.status = 'completed';
        this.state.endTime = Date.now();
        this.stopAutoSave();
        this.saveProgress().then(() => {
            this.emit('complete', this.getProgress());
        });
    }
    cancel() {
        this.state.status = 'failed';
        this.state.endTime = Date.now();
        this.stopAutoSave();
        this.emit('cancelled', this.getProgress());
    }
    async cleanup() {
        this.stopAutoSave();
        try {
            if (await fs.pathExists(this.progressFile)) {
                await fs.remove(this.progressFile);
            }
        }
        catch (error) {
            console.error('Failed to cleanup progress file:', error);
        }
    }
}
exports.ProgressTracker = ProgressTracker;
exports.default = ProgressTracker;
//# sourceMappingURL=ProgressTracker.js.map