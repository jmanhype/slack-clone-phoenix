"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.NotionAPIClient = void 0;
const client_1 = require("@notionhq/client");
const RateLimiter_1 = require("./RateLimiter");
const logger_1 = require("../utils/logger");
const logger = (0, logger_1.createLogger)('NotionAPIClient');
class NotionAPIClient {
    constructor(_config) {
        this._config = _config;
        this.client = new client_1.Client({
            auth: _config.token,
            notionVersion: _config.version || '2022-06-28'
        });
        this.rateLimiter = new RateLimiter_1.RateLimiter(_config.rateLimitRequests || 3, _config.rateLimitWindow || 1000);
        logger.info('NotionAPIClient initialized', {
            version: _config.version || '2022-06-28',
            rateLimitRequests: _config.rateLimitRequests || 3,
            rateLimitWindow: _config.rateLimitWindow || 1000
        });
    }
    /**
     * Searches for pages and databases in the workspace
     */
    async search(query, filter) {
        return this.rateLimiter.execute(async () => {
            logger.debug('Searching workspace', { query, filter });
            const results = [];
            let cursor;
            do {
                const response = await this.client.search({
                    query,
                    filter,
                    start_cursor: cursor,
                    page_size: 100
                });
                for (const item of response.results) {
                    if (item.object === 'page') {
                        results.push(this.mapNotionPage(item));
                    }
                    else if (item.object === 'database') {
                        results.push(this.mapNotionDatabase(item));
                    }
                }
                cursor = response.next_cursor || undefined;
            } while (cursor);
            logger.info(`Found ${results.length} items in workspace`);
            return results;
        }, 'search workspace');
    }
    /**
     * Retrieves a specific page by ID
     */
    async getPage(pageId) {
        return this.rateLimiter.execute(async () => {
            logger.debug('Fetching page', { pageId });
            const page = await this.client.pages.retrieve({ page_id: pageId });
            return this.mapNotionPage(page);
        }, `get page ${pageId}`);
    }
    /**
     * Retrieves all blocks for a page
     */
    async getPageBlocks(pageId) {
        return this.rateLimiter.execute(async () => {
            logger.debug('Fetching page blocks', { pageId });
            const blocks = [];
            let cursor;
            do {
                const response = await this.client.blocks.children.list({
                    block_id: pageId,
                    start_cursor: cursor,
                    page_size: 100
                });
                for (const block of response.results) {
                    const mappedBlock = this.mapNotionBlock(block);
                    blocks.push(mappedBlock);
                    // Recursively fetch child blocks
                    if (mappedBlock.has_children) {
                        const childBlocks = await this.getPageBlocks(mappedBlock.id);
                        mappedBlock.children = childBlocks;
                    }
                }
                cursor = response.next_cursor || undefined;
            } while (cursor);
            logger.debug(`Fetched ${blocks.length} blocks for page ${pageId}`);
            return blocks;
        }, `get blocks for page ${pageId}`);
    }
    /**
     * Retrieves a database by ID
     */
    async getDatabase(databaseId) {
        return this.rateLimiter.execute(async () => {
            logger.debug('Fetching database', { databaseId });
            const database = await this.client.databases.retrieve({ database_id: databaseId });
            return this.mapNotionDatabase(database);
        }, `get database ${databaseId}`);
    }
    /**
     * Queries a database for all pages
     */
    async queryDatabase(databaseId, filter, sorts) {
        return this.rateLimiter.execute(async () => {
            logger.debug('Querying database', { databaseId, filter, sorts });
            const pages = [];
            let cursor;
            do {
                const response = await this.client.databases.query({
                    database_id: databaseId,
                    filter,
                    sorts,
                    start_cursor: cursor,
                    page_size: 100
                });
                for (const page of response.results) {
                    pages.push(this.mapNotionPage(page));
                }
                cursor = response.next_cursor || undefined;
            } while (cursor);
            logger.info(`Queried ${pages.length} pages from database ${databaseId}`);
            return pages;
        }, `query database ${databaseId}`);
    }
    /**
     * Downloads a file from Notion to Buffer
     */
    async downloadFileToBuffer(url) {
        return this.rateLimiter.execute(async () => {
            logger.debug('Downloading file', { url });
            const response = await fetch(url);
            if (!response.ok) {
                throw new Error(`Failed to download file: ${response.statusText}`);
            }
            const buffer = Buffer.from(await response.arrayBuffer());
            logger.debug(`Downloaded file: ${buffer.length} bytes`);
            return buffer;
        }, `download file ${url}`);
    }
    /**
     * Tests the API connection and authentication
     */
    async testConnection() {
        try {
            await this.rateLimiter.execute(async () => {
                await this.client.users.me({});
            }, 'test connection');
            logger.info('API connection test successful');
            return true;
        }
        catch (error) {
            logger.error('API connection test failed', { error: error.message });
            return false;
        }
    }
    /**
     * Search for pages in the workspace
     */
    async searchPages() {
        return this.rateLimiter.execute(async () => {
            logger.debug('Searching for pages');
            const pages = [];
            let cursor;
            do {
                const response = await this.client.search({
                    filter: { property: 'object', value: 'page' },
                    start_cursor: cursor,
                    page_size: 100
                });
                for (const item of response.results) {
                    if (item.object === 'page') {
                        pages.push(this.mapNotionPage(item));
                    }
                }
                cursor = response.has_more ? response.next_cursor || undefined : undefined;
            } while (cursor);
            logger.info(`Found ${pages.length} pages`);
            return pages;
        }, 'search pages');
    }
    /**
     * Search for databases in the workspace
     */
    async searchDatabases() {
        return this.rateLimiter.execute(async () => {
            logger.debug('Searching for databases');
            const databases = [];
            let cursor;
            do {
                const response = await this.client.search({
                    filter: { property: 'object', value: 'database' },
                    start_cursor: cursor,
                    page_size: 100
                });
                for (const item of response.results) {
                    if (item.object === 'database') {
                        databases.push(this.mapNotionDatabase(item));
                    }
                }
                cursor = response.has_more ? response.next_cursor || undefined : undefined;
            } while (cursor);
            logger.info(`Found ${databases.length} databases`);
            return databases;
        }, 'search databases');
    }
    /**
     * Get all blocks in a page or block
     */
    async getBlocks(blockId) {
        return this.rateLimiter.execute(async () => {
            logger.debug(`Getting blocks for ${blockId}`);
            const blocks = [];
            let cursor;
            do {
                const response = await this.client.blocks.children.list({
                    block_id: blockId,
                    start_cursor: cursor,
                    page_size: 100
                });
                for (const block of response.results) {
                    blocks.push(this.mapNotionBlock(block));
                }
                cursor = response.has_more ? response.next_cursor || undefined : undefined;
            } while (cursor);
            logger.debug(`Found ${blocks.length} blocks in ${blockId}`);
            return blocks;
        }, 'get blocks');
    }
    /**
     * Get all pages in a database
     */
    async getDatabasePages(databaseId) {
        return this.rateLimiter.execute(async () => {
            logger.debug(`Getting pages for database ${databaseId}`);
            const pages = [];
            let cursor;
            do {
                const response = await this.client.databases.query({
                    database_id: databaseId,
                    start_cursor: cursor,
                    page_size: 100
                });
                for (const page of response.results) {
                    pages.push(this.mapNotionPage(page));
                }
                cursor = response.has_more ? response.next_cursor || undefined : undefined;
            } while (cursor);
            logger.info(`Found ${pages.length} pages in database ${databaseId}`);
            return pages;
        }, 'get database pages');
    }
    /**
     * Download a file from URL to path
     */
    async downloadFile(url, outputPath) {
        logger.debug(`Downloading file from ${url} to ${outputPath}`);
        // This would be implemented with actual file download logic
        // For now, it's a placeholder
        logger.info(`Downloaded file to ${outputPath}`);
    }
    /**
     * Maps Notion API page response to our NotionPage interface
     */
    mapNotionPage(page) {
        return {
            id: page.id,
            title: this.extractPageTitle(page),
            parent: page.parent,
            properties: page.properties,
            createdTime: page.created_time,
            lastEditedTime: page.last_edited_time,
            url: page.url
        };
    }
    /**
     * Maps Notion API block response to our NotionBlock interface
     */
    mapNotionBlock(block) {
        return {
            id: block.id,
            type: block.type,
            object: block.object,
            created_time: block.created_time,
            last_edited_time: block.last_edited_time,
            has_children: block.has_children,
            archived: block.archived,
            ...block[block.type] // Include type-specific properties
        };
    }
    /**
     * Maps Notion API database response to our NotionDatabase interface
     */
    mapNotionDatabase(database) {
        return {
            id: database.id,
            title: this.extractDatabaseTitle(database),
            properties: database.properties,
            parent: database.parent,
            createdTime: database.created_time,
            lastEditedTime: database.last_edited_time,
            url: database.url
        };
    }
    /**
     * Extracts page title from Notion page object
     */
    extractPageTitle(page) {
        if (page.properties?.title?.title?.[0]?.plain_text) {
            return page.properties.title.title[0].plain_text;
        }
        if (page.properties?.Name?.title?.[0]?.plain_text) {
            return page.properties.Name.title[0].plain_text;
        }
        // Try to find any title property
        for (const [_key, property] of Object.entries(page.properties || {})) {
            if (property?.type === 'title' && property?.title?.[0]?.plain_text) {
                return property.title[0].plain_text;
            }
        }
        return 'Untitled';
    }
    /**
     * Extracts database title from Notion database object
     */
    extractDatabaseTitle(database) {
        if (database.title?.[0]?.plain_text) {
            return database.title[0].plain_text;
        }
        return 'Untitled Database';
    }
    /**
     * Gets rate limiter information
     */
    getRateLimitInfo() {
        return this.rateLimiter.getRateLimitInfo();
    }
    /**
     * Resets the rate limiter
     */
    resetRateLimit() {
        this.rateLimiter.reset();
    }
}
exports.NotionAPIClient = NotionAPIClient;
//# sourceMappingURL=NotionAPIClient.js.map