/**
 * Component Interface Definitions
 *
 * Defines the interfaces for all major system components
 * implementing the hexagonal architecture pattern.
 */
export type ConversionResult = {
    markdown: string;
    attachments: AttachmentInfo[];
    metadata: PageMetadata;
    errors: ImportError[];
};
export type AttachmentInfo = {
    originalUrl: string;
    localPath: string;
    filename: string;
    type: 'image' | 'file' | 'video' | 'audio';
    size?: number;
    downloaded: boolean;
};
export type PageMetadata = {
    title: string;
    tags: string[];
    createdTime: string;
    lastEditedTime: string;
    notionId: string;
    url?: string;
    properties?: Record<string, any>;
};
export type ImportError = {
    type: 'RATE_LIMIT' | 'NETWORK' | 'CONVERSION' | 'FILE_SYSTEM' | 'AUTHENTICATION';
    message: string;
    pageId?: string;
    blockId?: string;
    timestamp: Date;
    retryable: boolean;
};
export type NotionPage = {
    id: string;
    title: string;
    parent: any;
    properties: any;
    children?: NotionBlock[];
    createdTime: string;
    lastEditedTime: string;
    url?: string;
};
export type NotionDatabase = {
    id: string;
    title: string;
    properties: Record<string, any>;
    parent: any;
    createdTime: string;
    lastEditedTime: string;
    url?: string;
};
export type NotionBlock = {
    id: string;
    type: string;
    object: 'block';
    created_time: string;
    last_edited_time: string;
    has_children: boolean;
    archived: boolean;
    [key: string]: any;
};
export type DatabaseConverter = {
    convertDatabase(database: NotionDatabase, pages: NotionPage[]): Promise<{
        indexFile: ConversionResult;
        pageFiles: ConversionResult[];
        errors: ImportError[];
    }>;
};
export interface WorkspaceInfo {
    id: string;
    name: string;
    icon?: string;
    owner: {
        type: 'user' | 'workspace';
        user?: {
            id: string;
            name: string;
            email: string;
        };
        workspace?: {
            id: string;
            name: string;
        };
    };
    bot?: {
        id: string;
        name: string;
    };
}
export interface ObsidianFile {
    path: string;
    content: string;
    frontmatter?: Record<string, any>;
    attachments?: string[];
    links?: string[];
}
export interface ObsidianFolder {
    path: string;
    name: string;
    files: ObsidianFile[];
    subfolders: ObsidianFolder[];
}
export interface IndexFile {
    path: string;
    content: string;
    metadata: {
        title: string;
        type: 'database' | 'page' | 'workspace';
        itemCount: number;
        created: string;
        updated: string;
    };
}
export interface DatabaseRelationship {
    sourceId: string;
    targetId: string;
    propertyName: string;
    relationType: 'relation' | 'rollup' | 'formula';
    bidirectional: boolean;
}
export interface ContentLink {
    type: 'internal' | 'external' | 'page_mention' | 'database_mention';
    href: string;
    title?: string;
    pageId?: string;
    databaseId?: string;
}
export interface ContentAttachment {
    type: 'image' | 'file' | 'video' | 'audio';
    url: string;
    name: string;
    size?: number;
    caption?: string;
    localPath?: string;
}
export interface ConversionContext {
    pageId?: string;
    databaseId?: string;
    depth: number;
    parentType?: string;
    config: any;
    linkResolver?: (id: string) => string;
    attachmentHandler?: (attachment: ContentAttachment) => Promise<string>;
}
export interface PropertyMapping {
    notionType: string;
    obsidianType: string;
    converter: (value: any) => any;
    validator?: (value: any) => boolean;
}
export interface VaultStructure {
    rootPath: string;
    folders: string[];
    files: string[];
    attachments: string[];
    templates: string[];
    metadata: {
        totalFiles: number;
        totalFolders: number;
        totalSize: number;
    };
}
export interface Plugin {
    name: string;
    version: string;
    description: string;
    author: string;
    main: string;
    dependencies?: string[];
    hooks?: string[];
    config?: Record<string, any>;
    enabled: boolean;
}
export interface ConversionError {
    type: 'validation' | 'conversion' | 'file_system' | 'network';
    message: string;
    details?: any;
    sourceId?: string;
    targetPath?: string;
    timestamp: Date;
    severity: 'low' | 'medium' | 'high' | 'critical';
}
export interface ImporterConfig {
    notion: {
        token: string;
        version?: string;
        baseUrl?: string;
    };
    obsidian: {
        vaultPath: string;
        attachmentsFolder?: string;
        templateFolder?: string;
    };
    conversion?: {
        preserveNotionIds?: boolean;
        convertTables?: boolean;
        downloadImages?: boolean;
        imageFormat?: 'original' | 'webp' | 'png' | 'jpg';
        maxImageSize?: number;
    };
    performance?: {
        maxConcurrentDownloads?: number;
        maxRetries?: number;
        timeout?: number;
    };
}
/**
 * Main orchestrator that coordinates the entire import process
 */
export interface ImportOrchestrator {
    /**
     * Initialize the import process with configuration
     */
    initialize(config: ImporterConfig): Promise<void>;
    /**
     * Execute the complete import workflow
     */
    execute(): Promise<ConversionResult>;
    /**
     * Cancel the current import operation
     */
    cancel(): Promise<void>;
    /**
     * Get current import status and progress
     */
    getStatus(): ImportStatus;
    /**
     * Resume a previously interrupted import
     */
    resume(checkpoint: ImportCheckpoint): Promise<ConversionResult>;
}
/**
 * Manages workspace discovery and organization
 */
export interface WorkspaceManager {
    /**
     * Discover and analyze workspace structure
     */
    discoverWorkspace(): Promise<WorkspaceInfo>;
    /**
     * Get all pages in the workspace
     */
    getAllPages(): Promise<NotionPage[]>;
    /**
     * Get all databases in the workspace
     */
    getAllDatabases(): Promise<NotionDatabase[]>;
    /**
     * Analyze workspace relationships
     */
    analyzeRelationships(): Promise<RelationshipGraph>;
    /**
     * Estimate import complexity and time
     */
    estimateImport(): Promise<ImportEstimate>;
}
/**
 * Coordinates the content processing pipeline
 */
export interface ContentCoordinator {
    /**
     * Process a single page and its content
     */
    processPage(pageId: string): Promise<ObsidianFile>;
    /**
     * Process a database and all its pages
     */
    processDatabase(databaseId: string): Promise<DatabaseProcessResult>;
    /**
     * Process blocks for a page
     */
    processBlocks(pageId: string, blocks: NotionBlock[]): Promise<ProcessedContent>;
    /**
     * Resolve and process all relationships
     */
    processRelationships(): Promise<void>;
}
/**
 * Repository pattern for Notion data access
 */
export interface NotionRepository {
    /**
     * Get workspace information
     */
    getWorkspace(): Promise<WorkspaceInfo>;
    /**
     * Get a page by ID
     */
    getPage(pageId: string): Promise<NotionPage>;
    /**
     * Get a database by ID
     */
    getDatabase(databaseId: string): Promise<NotionDatabase>;
    /**
     * Query database pages with filters
     */
    queryDatabase(databaseId: string, query?: DatabaseQuery): Promise<NotionPage[]>;
    /**
     * Get blocks for a page
     */
    getBlocks(pageId: string): Promise<NotionBlock[]>;
    /**
     * Get all child blocks recursively
     */
    getAllBlocks(pageId: string): Promise<NotionBlock[]>;
    /**
     * Search pages and databases
     */
    search(query: SearchQuery): Promise<SearchResult[]>;
}
/**
 * Abstraction for file system operations
 */
export interface FileSystemAdapter {
    /**
     * Create a directory structure
     */
    createDirectory(path: string): Promise<void>;
    /**
     * Write a file to disk
     */
    writeFile(path: string, content: string): Promise<void>;
    /**
     * Write binary data to disk
     */
    writeBinaryFile(path: string, data: Buffer): Promise<void>;
    /**
     * Check if a file or directory exists
     */
    exists(path: string): Promise<boolean>;
    /**
     * Read file contents
     */
    readFile(path: string): Promise<string>;
    /**
     * List directory contents
     */
    listDirectory(path: string): Promise<string[]>;
    /**
     * Delete a file or directory
     */
    delete(path: string): Promise<void>;
    /**
     * Copy files
     */
    copy(source: string, destination: string): Promise<void>;
}
/**
 * Factory for creating appropriate converters
 */
export interface ConverterFactory {
    /**
     * Create page converter
     */
    createPageConverter(): PageConverter;
    /**
     * Create database converter
     */
    createDatabaseConverter(): DatabaseConverter;
    /**
     * Create block converter
     */
    createBlockConverter(): BlockConverter;
    /**
     * Create property converter
     */
    createPropertyConverter(): PropertyConverter;
    /**
     * Create custom converter for specific type
     */
    createCustomConverter(type: string): Converter;
}
/**
 * Converts individual Notion pages
 */
export interface PageConverter {
    /**
     * Convert a Notion page to Obsidian format
     */
    convert(page: NotionPage, blocks: NotionBlock[]): Promise<ObsidianFile>;
    /**
     * Convert page properties
     */
    convertProperties(properties: Record<string, any>): Promise<Record<string, any>>;
    /**
     * Generate appropriate filename
     */
    generateFilename(page: NotionPage): string;
    /**
     * Validate converted content
     */
    validate(file: ObsidianFile): Promise<ValidationResult>;
}
/**
 * Converts Notion blocks to Markdown
 */
export interface BlockConverter {
    /**
     * Convert a single block
     */
    convertBlock(block: NotionBlock, context: ConversionContext): Promise<string>;
    /**
     * Convert nested blocks
     */
    convertNestedBlocks(blocks: NotionBlock[], context: ConversionContext): Promise<string>;
    /**
     * Check if block type is supported
     */
    isSupported(blockType: string): boolean;
    /**
     * Get fallback conversion for unsupported blocks
     */
    getFallback(block: NotionBlock): string;
}
/**
 * Converts Notion properties to Obsidian properties
 */
export interface PropertyConverter {
    /**
     * Convert a single property
     */
    convertProperty(property: any, type: string, context: ConversionContext): Promise<any>;
    /**
     * Get conversion mapping for property type
     */
    getMapping(notionType: string): PropertyMapping;
    /**
     * Validate converted property
     */
    validateProperty(value: any, type: string): boolean;
    /**
     * Format property for frontmatter
     */
    formatForFrontmatter(value: any, type: string): any;
}
/**
 * Base converter interface
 */
export interface Converter {
    /**
     * Convert input to output format
     */
    convert(input: any, context: ConversionContext): Promise<any>;
    /**
     * Validate input before conversion
     */
    validateInput(input: any): boolean;
    /**
     * Validate output after conversion
     */
    validateOutput(output: any): boolean;
}
/**
 * Manages link resolution and creation
 */
export interface LinkManager {
    /**
     * Resolve a Notion page ID to Obsidian path
     */
    resolvePageLink(pageId: string): Promise<string>;
    /**
     * Resolve a Notion database ID to Obsidian folder
     */
    resolveDatabaseLink(databaseId: string): Promise<string>;
    /**
     * Create bidirectional links
     */
    createBidirectionalLink(sourceId: string, targetId: string, property: string): Promise<void>;
    /**
     * Update all links after conversion
     */
    updateAllLinks(): Promise<void>;
    /**
     * Validate link integrity
     */
    validateLinks(): Promise<LinkValidationResult>;
}
/**
 * Manages relationship preservation and conversion
 */
export interface RelationshipManager {
    /**
     * Build relationship graph
     */
    buildRelationshipGraph(): Promise<RelationshipGraph>;
    /**
     * Convert Notion relations to Obsidian links
     */
    convertRelations(relations: NotionRelation[]): Promise<ObsidianLink[]>;
    /**
     * Create relationship indexes
     */
    createRelationshipIndexes(): Promise<IndexFile[]>;
    /**
     * Validate relationship integrity
     */
    validateRelationships(): Promise<RelationshipValidationResult>;
}
/**
 * Validates conversion results
 */
export interface ValidationService {
    /**
     * Validate a single file
     */
    validateFile(file: ObsidianFile): Promise<ValidationResult>;
    /**
     * Validate entire conversion result
     */
    validateConversion(result: ConversionResult): Promise<ValidationSummary>;
    /**
     * Validate vault structure
     */
    validateVaultStructure(structure: VaultStructure): Promise<StructureValidationResult>;
    /**
     * Check for data integrity issues
     */
    checkDataIntegrity(): Promise<IntegrityReport>;
}
/**
 * Quality assurance for conversion process
 */
export interface QualityAssurance {
    /**
     * Run pre-conversion checks
     */
    preConversionChecks(workspace: WorkspaceInfo): Promise<QualityReport>;
    /**
     * Run post-conversion checks
     */
    postConversionChecks(result: ConversionResult): Promise<QualityReport>;
    /**
     * Generate quality metrics
     */
    generateMetrics(result: ConversionResult): Promise<QualityMetrics>;
    /**
     * Suggest improvements
     */
    suggestImprovements(report: QualityReport): Promise<ImprovementSuggestion[]>;
}
/**
 * Plugin system manager
 */
export interface PluginManager {
    /**
     * Load and register a plugin
     */
    loadPlugin(pluginPath: string): Promise<void>;
    /**
     * Unload a plugin
     */
    unloadPlugin(pluginName: string): Promise<void>;
    /**
     * Execute plugin hooks
     */
    executeHook(hookName: string, ...args: any[]): Promise<any[]>;
    /**
     * Get loaded plugins
     */
    getLoadedPlugins(): Plugin[];
    /**
     * Check plugin compatibility
     */
    checkCompatibility(plugin: Plugin): Promise<CompatibilityResult>;
}
/**
 * Extension point for custom converters
 */
export interface ConverterExtension {
    /**
     * Get supported content types
     */
    getSupportedTypes(): string[];
    /**
     * Convert custom content
     */
    convert(content: any, type: string, context: ConversionContext): Promise<any>;
    /**
     * Validate custom content
     */
    validate(content: any, type: string): boolean;
    /**
     * Get extension metadata
     */
    getMetadata(): ExtensionMetadata;
}
/**
 * Configuration manager
 */
export interface ConfigurationManager {
    /**
     * Load configuration from file
     */
    loadConfig(path: string): Promise<ImporterConfig>;
    /**
     * Save configuration to file
     */
    saveConfig(config: ImporterConfig, path: string): Promise<void>;
    /**
     * Validate configuration
     */
    validateConfig(config: ImporterConfig): Promise<ConfigValidationResult>;
    /**
     * Merge configurations
     */
    mergeConfigs(base: ImporterConfig, override: Partial<ImporterConfig>): ImporterConfig;
    /**
     * Get default configuration
     */
    getDefaultConfig(): ImporterConfig;
}
/**
 * Settings persistence and management
 */
export interface SettingsManager {
    /**
     * Get user setting
     */
    getSetting<T>(key: string): Promise<T | undefined>;
    /**
     * Set user setting
     */
    setSetting<T>(key: string, value: T): Promise<void>;
    /**
     * Delete setting
     */
    deleteSetting(key: string): Promise<void>;
    /**
     * Get all settings
     */
    getAllSettings(): Promise<Record<string, any>>;
    /**
     * Reset to defaults
     */
    resetToDefaults(): Promise<void>;
}
export interface ImportStatus {
    status: 'pending' | 'running' | 'completed' | 'failed' | 'cancelled';
    progress: number;
    currentStage: string;
    startTime?: Date;
    endTime?: Date;
    error?: Error;
}
export interface ImportCheckpoint {
    timestamp: Date;
    processedItems: string[];
    currentStage: string;
    context: Partial<ConversionContext>;
    errors: ConversionError[];
}
export interface RelationshipGraph {
    nodes: GraphNode[];
    edges: GraphEdge[];
    metadata: GraphMetadata;
}
export interface GraphNode {
    id: string;
    type: 'page' | 'database';
    title: string;
    properties: Record<string, any>;
}
export interface GraphEdge {
    source: string;
    target: string;
    type: 'relation' | 'rollup' | 'reference';
    properties: Record<string, any>;
}
export interface GraphMetadata {
    nodeCount: number;
    edgeCount: number;
    complexity: number;
    maxDepth: number;
}
export interface ImportEstimate {
    totalItems: number;
    estimatedDuration: number;
    complexity: 'low' | 'medium' | 'high';
    apiCallsRequired: number;
    storageRequired: number;
    warnings: string[];
}
export interface DatabaseProcessResult {
    folder: ObsidianFolder;
    files: ObsidianFile[];
    index: IndexFile;
    relationships: DatabaseRelationship[];
}
export interface ProcessedContent {
    content: string;
    properties: Record<string, any>;
    links: ContentLink[];
    attachments: ContentAttachment[];
}
export interface DatabaseQuery {
    filter?: any;
    sorts?: any[];
    startCursor?: string;
    pageSize?: number;
}
export interface SearchQuery {
    query: string;
    filter?: {
        value: 'page' | 'database';
        property: 'object';
    };
    sort?: {
        direction: 'ascending' | 'descending';
        timestamp: 'last_edited_time';
    };
    startCursor?: string;
    pageSize?: number;
}
export interface SearchResult {
    id: string;
    title: string;
    type: 'page' | 'database';
    url: string;
    parent?: string;
    lastEdited: Date;
}
export interface ValidationResult {
    valid: boolean;
    errors: ValidationError[];
    warnings: ValidationWarning[];
    score: number;
}
export interface ValidationSummary {
    overallScore: number;
    fileResults: ValidationResult[];
    totalErrors: number;
    totalWarnings: number;
    recommendations: string[];
}
export interface StructureValidationResult {
    valid: boolean;
    issues: StructureIssue[];
    suggestions: string[];
}
export interface IntegrityReport {
    brokenLinks: BrokenLink[];
    missingFiles: string[];
    orphanedFiles: string[];
    duplicateFiles: string[];
    corruptedFiles: string[];
}
export interface QualityReport {
    score: number;
    metrics: QualityMetrics;
    issues: QualityIssue[];
    recommendations: string[];
}
export interface QualityMetrics {
    completeness: number;
    accuracy: number;
    consistency: number;
    performance: number;
    reliability: number;
}
export interface QualityIssue {
    type: 'error' | 'warning' | 'info';
    category: string;
    description: string;
    location?: string;
    severity: number;
}
export interface ImprovementSuggestion {
    title: string;
    description: string;
    priority: 'low' | 'medium' | 'high';
    effort: 'low' | 'medium' | 'high';
    impact: 'low' | 'medium' | 'high';
}
export interface CompatibilityResult {
    compatible: boolean;
    version: string;
    issues: CompatibilityIssue[];
    requirements: string[];
}
export interface CompatibilityIssue {
    type: 'error' | 'warning';
    message: string;
    suggestion?: string;
}
export interface ExtensionMetadata {
    name: string;
    version: string;
    description: string;
    author: string;
    dependencies: string[];
    supportedVersions: string[];
}
export interface ConfigValidationResult {
    valid: boolean;
    errors: ConfigError[];
    warnings: ConfigWarning[];
}
export interface ConfigError {
    path: string;
    message: string;
    value?: any;
}
export interface ConfigWarning {
    path: string;
    message: string;
    suggestion?: string;
}
export interface ValidationError {
    code: string;
    message: string;
    path?: string;
    severity: 'error' | 'warning';
}
export interface ValidationWarning {
    code: string;
    message: string;
    path?: string;
    suggestion?: string;
}
export interface StructureIssue {
    type: 'missing-folder' | 'invalid-path' | 'permission-error';
    path: string;
    message: string;
    fixable: boolean;
}
export interface BrokenLink {
    source: string;
    target: string;
    type: 'internal' | 'external';
    lineNumber?: number;
}
export interface LinkValidationResult {
    totalLinks: number;
    validLinks: number;
    brokenLinks: BrokenLink[];
    suggestions: LinkSuggestion[];
}
export interface LinkSuggestion {
    brokenLink: BrokenLink;
    suggestions: string[];
    confidence: number;
}
export interface RelationshipValidationResult {
    totalRelationships: number;
    validRelationships: number;
    brokenRelationships: BrokenRelationship[];
    circularReferences: CircularReference[];
}
export interface BrokenRelationship {
    source: string;
    target: string;
    property: string;
    reason: string;
}
export interface CircularReference {
    path: string[];
    property: string;
}
export interface NotionRelation {
    id: string;
    type: string;
    has_more: boolean;
    relation: Array<{
        id: string;
    }>;
}
export interface ObsidianLink {
    type: 'internal' | 'external';
    target: string;
    display?: string;
    embed?: boolean;
}
//# sourceMappingURL=components.d.ts.map