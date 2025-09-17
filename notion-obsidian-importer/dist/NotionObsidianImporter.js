"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.NotionObsidianImporter = void 0;
const NotionAPIClient_1 = require("./client/NotionAPIClient");
const ContentConverter_1 = require("./converters/ContentConverter");
const DatabaseConverter_1 = require("./converters/DatabaseConverter");
const ProgressiveDownloader_1 = require("./download/ProgressiveDownloader");
const ObsidianAdapter_1 = require("./adapters/ObsidianAdapter");
const logger_1 = require("./utils/logger");
const logger = (0, logger_1.createLogger)('NotionObsidianImporter');
class NotionObsidianImporter {
    constructor(_config) {
        this._config = _config;
        // Initialize components
        this.apiClient = new NotionAPIClient_1.NotionAPIClient(_config.notion);
        this.contentConverter = new ContentConverter_1.ContentConverter();
        this.databaseConverter = new DatabaseConverter_1.DatabaseConverter();
        this.downloader = new ProgressiveDownloader_1.ProgressiveDownloader(_config.obsidian.vaultPath, _config.concurrency, _config.retryAttempts);
        this.obsidianAdapter = new ObsidianAdapter_1.ObsidianAdapter(_config.obsidian);
        logger.info('NotionObsidianImporter initialized', {
            batchSize: _config.batchSize,
            concurrency: _config.concurrency,
            retryAttempts: _config.retryAttempts
        });
    }
    /**
     * Sets the progress callback function
     */
    setProgressCallback(callback) {
        this.onProgress = callback;
        this.downloader.setProgressCallback(callback);
    }
    /**
     * Tests the connection to Notion API
     */
    async testConnection() {
        return await this.apiClient.testConnection();
    }
    /**
     * Validates the Obsidian vault
     */
    async validateVault() {
        return await this.obsidianAdapter.validateVault();
    }
    /**
     * Performs a full import from Notion to Obsidian
     */
    async importAll() {
        const startTime = Date.now();
        const errors = [];
        const allAttachments = [];
        let importedFiles = [];
        logger.info('Starting full Notion import');
        try {
            // Initialize vault
            await this.obsidianAdapter.initializeVault();
            // Search for all content
            this.emitProgress({
                totalPages: 0,
                processedPages: 0,
                totalFiles: 0,
                downloadedFiles: 0,
                currentOperation: 'Searching Notion workspace...',
                startTime: new Date(startTime),
                errors
            });
            const searchResults = await this.apiClient.search();
            const pages = searchResults.filter(item => 'children' in item);
            const databases = searchResults.filter(item => 'properties' in item);
            logger.info('Found content to import', {
                pages: pages.length,
                databases: databases.length
            });
            // Process pages
            const pageResults = await this.processPages(pages, errors, allAttachments);
            // Process databases
            const databaseResults = await this.processDatabases(databases, errors, allAttachments);
            // Download all attachments
            if (allAttachments.length > 0) {
                this.emitProgress({
                    totalPages: pages.length + databases.length,
                    processedPages: pages.length + databases.length,
                    totalFiles: allAttachments.length,
                    downloadedFiles: 0,
                    currentOperation: 'Downloading attachments...',
                    startTime: new Date(startTime),
                    errors
                });
                await this.downloader.startSession(allAttachments);
                const downloadResult = await this.downloader.downloadAll();
                errors.push(...downloadResult.errors);
            }
            // Write all content to vault
            const writeResult = await this.obsidianAdapter.writeNotes([...pageResults, ...databaseResults], 'by-type');
            importedFiles = writeResult.writtenFiles;
            errors.push(...writeResult.errors);
            // Create import index
            await this.obsidianAdapter.createImportIndex({
                importDate: new Date().toISOString(),
                totalPages: pages.length,
                totalDatabases: 0,
                totalAttachments: allAttachments.length
            });
            const duration = Date.now() - startTime;
            const result = {
                success: errors.filter(e => e.type !== 'CONVERSION').length === 0,
                importedPages: pages.length,
                importedDatabases: databases.length,
                downloadedAttachments: allAttachments.filter(a => a.downloaded).length,
                errors,
                importedFiles,
                duration
            };
            logger.info('Import completed', {
                success: result.success,
                importedPages: result.importedPages,
                importedDatabases: result.importedDatabases,
                downloadedAttachments: result.downloadedAttachments,
                errors: result.errors.length,
                duration: `${Math.round(duration / 1000)}s`
            });
            return result;
        }
        catch (error) {
            logger.error('Import failed', { error: error.message });
            errors.push({
                type: 'NETWORK',
                message: `Import failed: ${error.message}`,
                timestamp: new Date(),
                retryable: false
            });
            return {
                success: false,
                importedPages: 0,
                importedDatabases: 0,
                downloadedAttachments: 0,
                errors,
                importedFiles: [],
                duration: Date.now() - startTime
            };
        }
    }
    /**
     * Imports specific pages by ID
     */
    async importPages(pageIds) {
        const startTime = Date.now();
        const errors = [];
        const allAttachments = [];
        logger.info('Starting selective page import', { pageIds });
        try {
            await this.obsidianAdapter.initializeVault();
            const pages = [];
            // Fetch each page
            for (const pageId of pageIds) {
                try {
                    const page = await this.apiClient.getPage(pageId);
                    page.children = await this.apiClient.getPageBlocks(pageId);
                    pages.push(page);
                }
                catch (error) {
                    errors.push({
                        type: 'NETWORK',
                        message: `Failed to fetch page ${pageId}: ${error.message}`,
                        pageId,
                        timestamp: new Date(),
                        retryable: true
                    });
                }
            }
            const pageResults = await this.processPages(pages, errors, allAttachments);
            // Download attachments and write to vault
            if (allAttachments.length > 0) {
                await this.downloader.startSession(allAttachments);
                const downloadResult = await this.downloader.downloadAll();
                errors.push(...downloadResult.errors);
            }
            const writeResult = await this.obsidianAdapter.writeNotes(pageResults, 'flat');
            errors.push(...writeResult.errors);
            const duration = Date.now() - startTime;
            return {
                success: errors.filter(e => e.type !== 'CONVERSION').length === 0,
                importedPages: pages.length,
                importedDatabases: 0,
                downloadedAttachments: allAttachments.filter(a => a.downloaded).length,
                errors,
                importedFiles: writeResult.writtenFiles,
                duration
            };
        }
        catch (error) {
            logger.error('Selective import failed', { error: error.message });
            return {
                success: false,
                importedPages: 0,
                importedDatabases: 0,
                downloadedAttachments: 0,
                errors: [{
                        type: 'NETWORK',
                        message: `Import failed: ${error.message}`,
                        timestamp: new Date(),
                        retryable: false
                    }],
                importedFiles: [],
                duration: Date.now() - startTime
            };
        }
    }
    /**
     * Resumes a previous download session
     */
    async resumeDownload() {
        const sessionId = await this.downloader.resumeSession();
        if (!sessionId) {
            throw new Error('No download session to resume');
        }
        logger.info('Resuming download session', { sessionId });
        return await this.downloader.downloadAll();
    }
    /**
     * Gets current progress information
     */
    getProgress() {
        return this.downloader.getProgress();
    }
    /**
     * Processes pages and converts them
     */
    async processPages(pages, errors, allAttachments) {
        const results = [];
        let processedCount = 0;
        for (const page of pages) {
            try {
                this.emitProgress({
                    totalPages: pages.length,
                    processedPages: processedCount,
                    totalFiles: allAttachments.length,
                    downloadedFiles: 0,
                    currentOperation: `Converting page: ${page.title}`,
                    startTime: new Date(),
                    errors
                });
                // Ensure page has blocks
                if (!page.children) {
                    page.children = await this.apiClient.getPageBlocks(page.id);
                }
                const metadata = {
                    title: page.title,
                    tags: this.extractTags(page),
                    createdTime: page.createdTime,
                    lastEditedTime: page.lastEditedTime,
                    notionId: page.id,
                    url: page.url
                };
                const result = await this.contentConverter.convertBlocks(page.children, metadata);
                results.push(result);
                allAttachments.push(...result.attachments);
                errors.push(...result.errors);
                processedCount++;
            }
            catch (error) {
                logger.error(`Failed to process page ${page.id}`, { error: error.message });
                errors.push({
                    type: 'CONVERSION',
                    message: `Failed to process page: ${error.message}`,
                    pageId: page.id,
                    timestamp: new Date(),
                    retryable: false
                });
            }
        }
        return results;
    }
    /**
     * Processes databases and converts them
     */
    async processDatabases(databases, errors, allAttachments) {
        const results = [];
        for (const database of databases) {
            try {
                this.emitProgress({
                    totalPages: databases.length,
                    processedPages: 0,
                    totalFiles: allAttachments.length,
                    downloadedFiles: 0,
                    currentOperation: `Converting database: ${database.title}`,
                    startTime: new Date(),
                    errors
                });
                // Query database for all pages
                const pages = await this.apiClient.queryDatabase(database.id);
                // Fetch blocks for each page
                for (const page of pages) {
                    page.children = await this.apiClient.getPageBlocks(page.id);
                }
                const databaseResult = await this.databaseConverter.convertDatabase(database, pages);
                results.push(databaseResult.indexFile);
                results.push(...databaseResult.pageFiles);
                // Collect attachments from all results
                for (const result of [databaseResult.indexFile, ...databaseResult.pageFiles]) {
                    allAttachments.push(...result.attachments);
                }
                errors.push(...databaseResult.errors);
            }
            catch (error) {
                logger.error(`Failed to process database ${database.id}`, { error: error.message });
                errors.push({
                    type: 'CONVERSION',
                    message: `Failed to process database: ${error.message}`,
                    timestamp: new Date(),
                    retryable: false
                });
            }
        }
        return results;
    }
    /**
     * Extracts tags from page properties
     */
    extractTags(page) {
        const tags = [];
        if (page.properties) {
            for (const [, property] of Object.entries(page.properties)) {
                const prop = property;
                if (prop.type === 'multi_select' && prop.multi_select) {
                    tags.push(...prop.multi_select.map((option) => option.name));
                }
                else if (prop.type === 'select' && prop.select) {
                    tags.push(prop.select.name);
                }
            }
        }
        return [...new Set(tags)]; // Remove duplicates
    }
    /**
     * Emits progress update
     */
    emitProgress(progress) {
        if (this.onProgress) {
            this.onProgress(progress);
        }
    }
}
exports.NotionObsidianImporter = NotionObsidianImporter;
//# sourceMappingURL=NotionObsidianImporter.js.map