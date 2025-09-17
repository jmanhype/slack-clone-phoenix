import { NotionDatabase, NotionPage, ConversionResult, ImportError } from '../types';
export declare class DatabaseConverter {
    private contentConverter;
    private _config;
    constructor(_config?: any);
    /**
     * Converts a Notion database to Obsidian format
     */
    convertDatabase(database: NotionDatabase, pages: NotionPage[]): Promise<{
        indexFile: ConversionResult;
        pageFiles: ConversionResult[];
        errors: ImportError[];
    }>;
    /**
     * Generates a markdown index file for the database
     */
    private generateDatabaseIndex;
    /**
     * Creates metadata for a database page
     */
    private createPageMetadata;
    /**
     * Creates metadata for the database index
     */
    private createDatabaseMetadata;
    /**
     * Processes page properties for frontmatter
     */
    private processPageProperties;
    /**
     * Gets relevant properties for table display
     */
    private getRelevantProperties;
    /**
     * Creates a table row for a page
     */
    private createTableRow;
    /**
     * Formats a property value for table display
     */
    private formatPropertyForTable;
    /**
     * Formats a date for display
     */
    private formatDate;
    /**
     * Generates a filename for a page
     */
    private generatePageFilename;
}
//# sourceMappingURL=DatabaseConverter.d.ts.map