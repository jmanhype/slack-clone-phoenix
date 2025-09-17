"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.NotionImporter = void 0;
// import { Client } from '@notionhq/client'; // unused
const NotionAPIClient_1 = require("../client/NotionAPIClient");
const ProgressTracker_1 = require("./ProgressTracker");
const Logger_1 = __importDefault(require("./Logger"));
class NotionImporter {
    constructor(_config, progressTracker) {
        this._config = _config;
        this.client = new NotionAPIClient_1.NotionAPIClient(_config.notion);
        this.progressTracker = progressTracker || new ProgressTracker_1.ProgressTracker();
    }
    async testConnection() {
        try {
            return await this.client.testConnection();
        }
        catch (error) {
            Logger_1.default.error('Failed to connect to Notion API', error);
            return false;
        }
    }
    async discoverContent() {
        Logger_1.default.info('Discovering Notion content...');
        this.progressTracker.startPhase('discovery');
        try {
            const pages = await this.client.searchPages();
            const databases = await this.client.searchDatabases();
            const totalItems = pages.length + databases.length;
            this.progressTracker.updateProgress({ totalItems });
            this.progressTracker.completePhase('discovery');
            Logger_1.default.success(`Discovered ${pages.length} pages and ${databases.length} databases`);
            return {
                pages,
                databases,
                totalItems,
            };
        }
        catch (error) {
            Logger_1.default.error('Failed to discover content', error);
            throw error;
        }
    }
    async downloadPage(pageId) {
        if (this.progressTracker.isPageProcessed(pageId)) {
            Logger_1.default.debug(`Page ${pageId} already processed, skipping`);
            this.progressTracker.incrementSkipped();
            return null;
        }
        try {
            Logger_1.default.debug(`Downloading page ${pageId}`);
            this.progressTracker.updateProgress({ currentItem: `Page: ${pageId}` });
            const page = await this.client.getPage(pageId);
            const blocks = await this.client.getBlocks(pageId);
            this.progressTracker.addProcessedPage(pageId);
            this.progressTracker.incrementProcessed();
            return {
                ...page,
                blocks,
            };
        }
        catch (error) {
            Logger_1.default.error(`Failed to download page ${pageId}`, error);
            this.progressTracker.incrementFailed(error);
            throw error;
        }
    }
    async downloadDatabase(databaseId) {
        if (this.progressTracker.isDatabaseProcessed(databaseId)) {
            Logger_1.default.debug(`Database ${databaseId} already processed, skipping`);
            this.progressTracker.incrementSkipped();
            return null;
        }
        try {
            Logger_1.default.debug(`Downloading database ${databaseId}`);
            this.progressTracker.updateProgress({ currentItem: `Database: ${databaseId}` });
            const database = await this.client.getDatabase(databaseId);
            const pages = await this.client.getDatabasePages(databaseId);
            this.progressTracker.addProcessedDatabase(databaseId);
            this.progressTracker.incrementProcessed();
            return {
                ...database,
                pages,
            };
        }
        catch (error) {
            Logger_1.default.error(`Failed to download database ${databaseId}`, error);
            this.progressTracker.incrementFailed(error);
            throw error;
        }
    }
    async downloadFile(url, outputPath) {
        if (this.progressTracker.state.downloadedFiles.has(outputPath)) {
            Logger_1.default.debug(`File ${outputPath} already downloaded, skipping`);
            return;
        }
        try {
            await this.client.downloadFile(url, outputPath);
            this.progressTracker.addDownloadedFile(outputPath);
        }
        catch (error) {
            Logger_1.default.error(`Failed to download file from ${url}`, error);
            throw error;
        }
    }
    async import(options) {
        Logger_1.default.info('Starting Notion import...');
        this.progressTracker.updateProgress({ status: 'running' });
        if (options?.resumeFromProgress) {
            const resumed = await this.progressTracker.loadProgress();
            if (resumed) {
                Logger_1.default.info('Resuming from previous progress');
            }
        }
        this.progressTracker.startAutoSave();
        try {
            // Discover content if not specified
            let pagesToImport = options?.pages || [];
            let databasesToImport = options?.databases || [];
            if (pagesToImport.length === 0 && databasesToImport.length === 0) {
                const content = await this.discoverContent();
                pagesToImport = content.pages.map(p => p.id);
                databasesToImport = content.databases.map(d => d.id);
            }
            // Download phase
            this.progressTracker.startPhase('download');
            const downloadedPages = [];
            const downloadedDatabases = [];
            for (const pageId of pagesToImport) {
                const page = await this.downloadPage(pageId);
                if (page)
                    downloadedPages.push(page);
            }
            for (const dbId of databasesToImport) {
                const db = await this.downloadDatabase(dbId);
                if (db)
                    downloadedDatabases.push(db);
            }
            this.progressTracker.completePhase('download');
            // Return result
            const result = {
                success: true,
                totalPages: downloadedPages.length,
                totalDatabases: downloadedDatabases.length,
                totalAttachments: this.progressTracker.state.downloadedFiles.size,
                errors: this.progressTracker.state.errors,
                importedPages: downloadedPages,
                importedDatabases: downloadedDatabases,
            };
            this.progressTracker.complete();
            Logger_1.default.success('Import completed successfully!');
            return result;
        }
        catch (error) {
            Logger_1.default.error('Import failed', error);
            this.progressTracker.updateProgress({ status: 'failed' });
            throw error;
        }
        finally {
            this.progressTracker.stopAutoSave();
        }
    }
    getProgressTracker() {
        return this.progressTracker;
    }
}
exports.NotionImporter = NotionImporter;
exports.default = NotionImporter;
//# sourceMappingURL=NotionImporter.js.map