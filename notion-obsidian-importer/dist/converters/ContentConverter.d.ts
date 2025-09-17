import { NotionBlock, ConversionResult, PageMetadata } from '../types';
export declare class ContentConverter {
    private turndownService;
    private config;
    constructor(config?: any);
    /**
     * Converts a full Notion page to markdown
     */
    convertPage(page: any): Promise<string>;
    /**
     * Converts Notion blocks to Markdown content
     */
    convertBlocks(blocks: NotionBlock[], _metadata: PageMetadata): Promise<ConversionResult>;
    /**
     * Converts a single Notion block to markdown
     */
    private convertBlock;
    /**
     * Converts paragraph block
     */
    private convertParagraph;
    /**
     * Converts heading blocks
     */
    private convertHeading;
    /**
     * Converts bulleted list item
     */
    private convertBulletedListItem;
    /**
     * Converts numbered list item
     */
    private convertNumberedListItem;
    /**
     * Converts to-do block
     */
    private convertToDo;
    /**
     * Converts toggle block
     */
    private convertToggle;
    /**
     * Converts code block
     */
    private convertCode;
    /**
     * Converts quote block
     */
    private convertQuote;
    /**
     * Converts callout block
     */
    private convertCallout;
    /**
     * Converts media blocks (image, video, file)
     */
    private convertMedia;
    /**
     * Converts bookmark block
     */
    private convertBookmark;
    /**
     * Converts link preview block
     */
    private convertLinkPreview;
    /**
     * Converts table block
     */
    private convertTable;
    /**
     * Converts equation block
     */
    private convertEquation;
    /**
     * Converts embed block
     */
    private convertEmbed;
    /**
     * Converts column list block
     */
    private convertColumnList;
    /**
     * Converts column block
     */
    private convertColumn;
    /**
     * Converts synced block
     */
    private convertSyncedBlock;
    /**
     * Converts Notion rich text array to markdown string
     */
    private convertRichText;
    /**
     * Generates frontmatter for the markdown file
     */
    private generateFrontmatter;
    /**
     * Sets up custom Turndown rules
     */
    private setupCustomRules;
    /**
     * Utility functions
     */
    private extractFilenameFromUrl;
    private getFileExtensionFromType;
    private mapBlockTypeToAttachmentType;
}
//# sourceMappingURL=ContentConverter.d.ts.map