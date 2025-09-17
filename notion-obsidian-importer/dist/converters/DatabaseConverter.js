"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.DatabaseConverter = void 0;
const ContentConverter_1 = require("./ContentConverter");
const logger_1 = require("../utils/logger");
const logger = (0, logger_1.createLogger)('DatabaseConverter');
class DatabaseConverter {
    constructor(_config) {
        this._config = _config || {};
        this.contentConverter = new ContentConverter_1.ContentConverter(_config);
        logger.info('DatabaseConverter initialized');
    }
    /**
     * Converts a Notion database to Obsidian format
     */
    async convertDatabase(database, pages) {
        const errors = [];
        const pageFiles = [];
        try {
            logger.info(`Converting database: ${database.title}`, {
                databaseId: database.id,
                pagesCount: pages.length
            });
            // Convert individual pages
            for (const page of pages) {
                try {
                    const pageMetadata = this.createPageMetadata(page, database);
                    const pageResult = await this.contentConverter.convertBlocks(page.children || [], pageMetadata);
                    pageFiles.push(pageResult);
                }
                catch (error) {
                    logger.error(`Failed to convert database page ${page.id}`, { error: error.message });
                    errors.push({
                        type: 'CONVERSION',
                        message: `Failed to convert database page: ${error.message}`,
                        pageId: page.id,
                        timestamp: new Date(),
                        retryable: false
                    });
                }
            }
            // Generate database index file
            const indexMetadata = this.createDatabaseMetadata(database);
            const indexContent = this.generateDatabaseIndex(database, pages);
            const indexFile = {
                markdown: indexContent,
                attachments: [],
                metadata: indexMetadata,
                errors: []
            };
            logger.info(`Successfully converted database with ${pageFiles.length} pages`);
            return {
                indexFile,
                pageFiles,
                errors
            };
        }
        catch (error) {
            logger.error(`Failed to convert database ${database.id}`, { error: error.message });
            errors.push({
                type: 'CONVERSION',
                message: `Failed to convert database: ${error.message}`,
                timestamp: new Date(),
                retryable: false
            });
            return {
                indexFile: {
                    markdown: '',
                    attachments: [],
                    metadata: this.createDatabaseMetadata(database),
                    errors: [errors[errors.length - 1]]
                },
                pageFiles: [],
                errors
            };
        }
    }
    /**
     * Generates a markdown index file for the database
     */
    generateDatabaseIndex(database, pages) {
        const lines = [];
        // Add frontmatter
        lines.push('---');
        lines.push(`title: "${database.title.replace(/"/g, '\\"')}"`);
        lines.push(`type: database`);
        lines.push(`created: ${database.createdTime}`);
        lines.push(`updated: ${database.lastEditedTime}`);
        lines.push(`notion_id: ${database.id}`);
        if (database.url) {
            lines.push(`notion_url: "${database.url}"`);
        }
        lines.push('---');
        lines.push('');
        // Add title
        lines.push(`# ${database.title}`);
        lines.push('');
        // Add database properties schema
        if (Object.keys(database.properties).length > 0) {
            lines.push('## Properties');
            lines.push('');
            for (const [propName, propConfig] of Object.entries(database.properties)) {
                const _config = propConfig;
                lines.push(`- **${propName}**: ${_config.type}`);
                // Add additional info for specific property types
                if (_config.type === 'select' && _config.select?.options) {
                    const options = _config.select.options.map((opt) => opt.name).join(', ');
                    lines.push(`  - Options: ${options}`);
                }
                else if (_config.type === 'multi_select' && _config.multi_select?.options) {
                    const options = _config.multi_select.options.map((opt) => opt.name).join(', ');
                    lines.push(`  - Options: ${options}`);
                }
                else if (_config.type === 'formula' && _config.formula?.expression) {
                    lines.push(`  - Formula: \`${_config.formula.expression}\``);
                }
            }
            lines.push('');
        }
        // Add pages table
        if (pages.length > 0) {
            lines.push('## Pages');
            lines.push('');
            // Create table header
            const propertyNames = this.getRelevantProperties(database.properties);
            const headers = ['Title', ...propertyNames, 'Created', 'Updated'];
            lines.push(`| ${headers.join(' | ')} |`);
            lines.push(`| ${headers.map(() => '---').join(' | ')} |`);
            // Add table rows
            for (const page of pages) {
                const row = this.createTableRow(page, propertyNames);
                lines.push(`| ${row.join(' | ')} |`);
            }
            lines.push('');
        }
        // Add statistics
        lines.push('## Statistics');
        lines.push('');
        lines.push(`- Total pages: ${pages.length}`);
        lines.push(`- Properties: ${Object.keys(database.properties).length}`);
        lines.push(`- Last updated: ${database.lastEditedTime}`);
        lines.push('');
        // Add page links
        if (pages.length > 0) {
            lines.push('## All Pages');
            lines.push('');
            for (const page of pages) {
                const filename = this.generatePageFilename(page);
                lines.push(`- [[${filename}]]`);
            }
            lines.push('');
        }
        return lines.join('\n');
    }
    /**
     * Creates metadata for a database page
     */
    createPageMetadata(page, database) {
        const tags = [];
        // Extract tags from database properties
        for (const [, propValue] of Object.entries(page.properties || {})) {
            const value = propValue;
            if (value.type === 'multi_select' && value.multi_select) {
                tags.push(...value.multi_select.map((option) => option.name));
            }
            else if (value.type === 'select' && value.select) {
                tags.push(value.select.name);
            }
        }
        // Add database name as a tag
        tags.push(`database:${database.title}`);
        return {
            title: page.title,
            tags: [...new Set(tags)], // Remove duplicates
            createdTime: page.createdTime,
            lastEditedTime: page.lastEditedTime,
            notionId: page.id,
            url: page.url,
            properties: this.processPageProperties(page.properties, database.properties)
        };
    }
    /**
     * Creates metadata for the database index
     */
    createDatabaseMetadata(database) {
        return {
            title: database.title,
            tags: ['database', 'index'],
            createdTime: database.createdTime,
            lastEditedTime: database.lastEditedTime,
            notionId: database.id,
            url: database.url
        };
    }
    /**
     * Processes page properties for frontmatter
     */
    processPageProperties(pageProperties, databaseProperties) {
        const processed = {};
        for (const [propName, propValue] of Object.entries(pageProperties || {})) {
            const value = propValue;
            const dbProp = databaseProperties[propName];
            if (!dbProp)
                continue;
            switch (value.type) {
                case 'title':
                    if (value.title?.[0]?.plain_text) {
                        processed[propName] = value.title[0].plain_text;
                    }
                    break;
                case 'rich_text':
                    if (value.rich_text?.[0]?.plain_text) {
                        processed[propName] = value.rich_text.map((rt) => rt.plain_text).join('');
                    }
                    break;
                case 'number':
                    if (value.number !== null) {
                        processed[propName] = value.number;
                    }
                    break;
                case 'select':
                    if (value.select?.name) {
                        processed[propName] = value.select.name;
                    }
                    break;
                case 'multi_select':
                    if (value.multi_select?.length > 0) {
                        processed[propName] = value.multi_select.map((option) => option.name);
                    }
                    break;
                case 'date':
                    if (value.date?.start) {
                        processed[propName] = value.date.start;
                        if (value.date.end) {
                            processed[`${propName}_end`] = value.date.end;
                        }
                    }
                    break;
                case 'checkbox':
                    processed[propName] = value.checkbox;
                    break;
                case 'url':
                    if (value.url) {
                        processed[propName] = value.url;
                    }
                    break;
                case 'email':
                    if (value.email) {
                        processed[propName] = value.email;
                    }
                    break;
                case 'phone_number':
                    if (value.phone_number) {
                        processed[propName] = value.phone_number;
                    }
                    break;
                case 'formula':
                    if (value.formula?.string) {
                        processed[propName] = value.formula.string;
                    }
                    else if (value.formula?.number !== null) {
                        processed[propName] = value.formula.number;
                    }
                    else if (value.formula?.boolean !== null) {
                        processed[propName] = value.formula.boolean;
                    }
                    else if (value.formula?.date?.start) {
                        processed[propName] = value.formula.date.start;
                    }
                    break;
                case 'relation':
                    if (value.relation?.length > 0) {
                        processed[propName] = value.relation.map((rel) => rel.id);
                    }
                    break;
                case 'rollup':
                    if (value.rollup?.array?.length > 0) {
                        processed[propName] = value.rollup.array;
                    }
                    else if (value.rollup?.number !== null) {
                        processed[propName] = value.rollup.number;
                    }
                    else if (value.rollup?.date?.start) {
                        processed[propName] = value.rollup.date.start;
                    }
                    break;
                case 'people':
                    if (value.people?.length > 0) {
                        processed[propName] = value.people.map((person) => person.name || person.id);
                    }
                    break;
                case 'files':
                    if (value.files?.length > 0) {
                        processed[propName] = value.files.map((file) => file.name || file.external?.url || file.file?.url);
                    }
                    break;
                case 'created_time':
                    processed[propName] = value.created_time;
                    break;
                case 'created_by':
                    if (value.created_by?.name) {
                        processed[propName] = value.created_by.name;
                    }
                    break;
                case 'last_edited_time':
                    processed[propName] = value.last_edited_time;
                    break;
                case 'last_edited_by':
                    if (value.last_edited_by?.name) {
                        processed[propName] = value.last_edited_by.name;
                    }
                    break;
            }
        }
        return processed;
    }
    /**
     * Gets relevant properties for table display
     */
    getRelevantProperties(databaseProperties) {
        const relevant = [];
        for (const [propName, propConfig] of Object.entries(databaseProperties)) {
            const config = propConfig;
            // Include important property types in table
            if (['select', 'multi_select', 'date', 'checkbox', 'number', 'formula'].includes(config.type)) {
                relevant.push(propName);
            }
        }
        return relevant.slice(0, 5); // Limit to 5 columns to keep table readable
    }
    /**
     * Creates a table row for a page
     */
    createTableRow(page, propertyNames) {
        const row = [];
        // Add title (with link)
        const filename = this.generatePageFilename(page);
        row.push(`[[${filename}|${page.title}]]`);
        // Add property values
        for (const propName of propertyNames) {
            const propValue = page.properties?.[propName];
            row.push(this.formatPropertyForTable(propValue));
        }
        // Add dates
        row.push(this.formatDate(page.createdTime));
        row.push(this.formatDate(page.lastEditedTime));
        return row;
    }
    /**
     * Formats a property value for table display
     */
    formatPropertyForTable(propValue) {
        if (!propValue)
            return '';
        switch (propValue.type) {
            case 'select':
                return propValue.select?.name || '';
            case 'multi_select':
                return propValue.multi_select?.map((opt) => opt.name).join(', ') || '';
            case 'date':
                return propValue.date?.start || '';
            case 'checkbox':
                return propValue.checkbox ? '✓' : '';
            case 'number':
                return propValue.number?.toString() || '';
            case 'formula':
                if (propValue.formula?.string)
                    return propValue.formula.string;
                if (propValue.formula?.number !== null)
                    return propValue.formula.number.toString();
                if (propValue.formula?.boolean !== null)
                    return propValue.formula.boolean ? '✓' : '';
                return '';
            default:
                return '';
        }
    }
    /**
     * Formats a date for display
     */
    formatDate(dateString) {
        try {
            return new Date(dateString).toLocaleDateString();
        }
        catch {
            return dateString;
        }
    }
    /**
     * Generates a filename for a page
     */
    generatePageFilename(page) {
        const title = page.title
            .replace(/[<>:"/\\|?*]/g, '') // Remove invalid filename characters
            .replace(/\s+/g, ' ') // Normalize whitespace
            .trim();
        return title || `Untitled-${page.id.slice(0, 8)}`;
    }
}
exports.DatabaseConverter = DatabaseConverter;
//# sourceMappingURL=DatabaseConverter.js.map