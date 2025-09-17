import { NotionConfig, NotionPage, NotionBlock, NotionDatabase } from '../types';
export declare class NotionAPIClient {
    private client;
    private rateLimiter;
    private _config;
    constructor(_config: NotionConfig);
    /**
     * Searches for pages and databases in the workspace
     */
    search(query?: string, filter?: any): Promise<(NotionPage | NotionDatabase)[]>;
    /**
     * Retrieves a specific page by ID
     */
    getPage(pageId: string): Promise<NotionPage>;
    /**
     * Retrieves all blocks for a page
     */
    getPageBlocks(pageId: string): Promise<NotionBlock[]>;
    /**
     * Retrieves a database by ID
     */
    getDatabase(databaseId: string): Promise<NotionDatabase>;
    /**
     * Queries a database for all pages
     */
    queryDatabase(databaseId: string, filter?: any, sorts?: any): Promise<NotionPage[]>;
    /**
     * Downloads a file from Notion to Buffer
     */
    downloadFileToBuffer(url: string): Promise<Buffer>;
    /**
     * Tests the API connection and authentication
     */
    testConnection(): Promise<boolean>;
    /**
     * Search for pages in the workspace
     */
    searchPages(): Promise<NotionPage[]>;
    /**
     * Search for databases in the workspace
     */
    searchDatabases(): Promise<NotionDatabase[]>;
    /**
     * Get all blocks in a page or block
     */
    getBlocks(blockId: string): Promise<NotionBlock[]>;
    /**
     * Get all pages in a database
     */
    getDatabasePages(databaseId: string): Promise<NotionPage[]>;
    /**
     * Download a file from URL to path
     */
    downloadFile(url: string, outputPath: string): Promise<void>;
    /**
     * Maps Notion API page response to our NotionPage interface
     */
    private mapNotionPage;
    /**
     * Maps Notion API block response to our NotionBlock interface
     */
    private mapNotionBlock;
    /**
     * Maps Notion API database response to our NotionDatabase interface
     */
    private mapNotionDatabase;
    /**
     * Extracts page title from Notion page object
     */
    private extractPageTitle;
    /**
     * Extracts database title from Notion database object
     */
    private extractDatabaseTitle;
    /**
     * Gets rate limiter information
     */
    getRateLimitInfo(): import("../types").RateLimitInfo;
    /**
     * Resets the rate limiter
     */
    resetRateLimit(): void;
}
//# sourceMappingURL=NotionAPIClient.d.ts.map