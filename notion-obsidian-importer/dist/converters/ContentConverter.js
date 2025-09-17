"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.ContentConverter = void 0;
const turndown_1 = __importDefault(require("turndown"));
const logger_1 = require("../utils/logger");
const logger = (0, logger_1.createLogger)('ContentConverter');
class ContentConverter {
    constructor(config) {
        this.config = config || {};
        this.turndownService = new turndown_1.default({
            headingStyle: 'atx',
            codeBlockStyle: 'fenced',
            fence: '```',
            bulletListMarker: '-',
            linkStyle: 'referenced'
        });
        this.setupCustomRules();
        logger.info('ContentConverter initialized');
    }
    /**
     * Converts a full Notion page to markdown
     */
    async convertPage(page) {
        let markdown = '';
        // Add frontmatter if configured
        if (this.config.includeMetadata !== false) {
            markdown += '---\n';
            markdown += `title: ${page.properties?.title?.title?.[0]?.plain_text || 'Untitled'}\n`;
            markdown += `notion_id: ${page.id}\n`;
            markdown += `created: ${page.created_time || new Date().toISOString()}\n`;
            markdown += `updated: ${page.last_edited_time || new Date().toISOString()}\n`;
            markdown += '---\n\n';
        }
        // Add title
        const title = page.properties?.title?.title?.[0]?.plain_text ||
            page.properties?.Name?.title?.[0]?.plain_text ||
            'Untitled';
        markdown += `# ${title}\n\n`;
        // Convert blocks if present
        if (page.blocks && Array.isArray(page.blocks)) {
            for (const block of page.blocks) {
                const result = await this.convertBlock(block, 0);
                markdown += result.content;
            }
        }
        return markdown;
    }
    /**
     * Converts Notion blocks to Markdown content
     */
    async convertBlocks(blocks, _metadata) {
        const attachments = [];
        const errors = [];
        let markdown = '';
        // Add frontmatter
        markdown += this.generateFrontmatter(_metadata);
        try {
            for (const _block of blocks) {
                const blockResult = await this.convertBlock(_block, 0);
                markdown += blockResult.content;
                attachments.push(...blockResult.attachments);
                errors.push(...blockResult.errors);
            }
            logger.debug('Successfully converted blocks to markdown', {
                blocksCount: blocks.length,
                attachmentsCount: attachments.length,
                errorsCount: errors.length
            });
            return {
                markdown: markdown.trim(),
                attachments,
                metadata: _metadata,
                errors
            };
        }
        catch (error) {
            logger.error('Failed to convert blocks', { error: error.message });
            errors.push({
                type: 'CONVERSION',
                message: `Failed to convert blocks: ${error.message}`,
                timestamp: new Date(),
                retryable: false
            });
            return {
                markdown: markdown.trim(),
                attachments,
                metadata: _metadata,
                errors
            };
        }
    }
    /**
     * Converts a single Notion block to markdown
     */
    async convertBlock(block, indentLevel = 0) {
        const attachments = [];
        const errors = [];
        const indent = '  '.repeat(indentLevel);
        let content = '';
        try {
            switch (block.type) {
                case 'paragraph':
                    content += this.convertParagraph(block, indent);
                    break;
                case 'heading_1':
                    content += this.convertHeading(block, 1, indent);
                    break;
                case 'heading_2':
                    content += this.convertHeading(block, 2, indent);
                    break;
                case 'heading_3':
                    content += this.convertHeading(block, 3, indent);
                    break;
                case 'bulleted_list_item':
                    content += this.convertBulletedListItem(block, indent);
                    break;
                case 'numbered_list_item':
                    content += this.convertNumberedListItem(block, indent);
                    break;
                case 'to_do':
                    content += this.convertToDo(block, indent);
                    break;
                case 'toggle':
                    content += this.convertToggle(block, indent);
                    break;
                case 'code':
                    content += this.convertCode(block, indent);
                    break;
                case 'quote':
                    content += this.convertQuote(block, indent);
                    break;
                case 'callout':
                    content += this.convertCallout(block, indent);
                    break;
                case 'divider':
                    content += `${indent}---\n\n`;
                    break;
                case 'image':
                case 'video':
                case 'file':
                case 'pdf':
                    const mediaResult = this.convertMedia(block, indent);
                    content += mediaResult.content;
                    attachments.push(...mediaResult.attachments);
                    break;
                case 'bookmark':
                    content += this.convertBookmark(block, indent);
                    break;
                case 'link_preview':
                    content += this.convertLinkPreview(block, indent);
                    break;
                case 'table':
                    content += this.convertTable(block, indent);
                    break;
                case 'table_row':
                    // Table rows are handled by the table block
                    break;
                case 'equation':
                    content += this.convertEquation(block, indent);
                    break;
                case 'embed':
                    content += this.convertEmbed(block, indent);
                    break;
                case 'column_list':
                    content += this.convertColumnList(block, indent);
                    break;
                case 'column':
                    content += this.convertColumn(block, indent);
                    break;
                case 'synced_block':
                    content += this.convertSyncedBlock(block, indent);
                    break;
                default:
                    logger.warn(`Unsupported block type: ${block.type}`, { blockId: block.id });
                    content += `${indent}<!-- Unsupported block type: ${block.type} -->\n\n`;
                    errors.push({
                        type: 'CONVERSION',
                        message: `Unsupported block type: ${block.type}`,
                        blockId: block.id,
                        timestamp: new Date(),
                        retryable: false
                    });
            }
            // Handle child blocks recursively
            if (block.children && block.children.length > 0) {
                for (const childBlock of block.children) {
                    const childResult = await this.convertBlock(childBlock, indentLevel + 1);
                    content += childResult.content;
                    attachments.push(...childResult.attachments);
                    errors.push(...childResult.errors);
                }
            }
        }
        catch (error) {
            logger.error(`Failed to convert block ${block.type}`, {
                blockId: block.id,
                error: error.message
            });
            errors.push({
                type: 'CONVERSION',
                message: `Failed to convert ${block.type} block: ${error.message}`,
                blockId: block.id,
                timestamp: new Date(),
                retryable: false
            });
        }
        return { content, attachments, errors };
    }
    /**
     * Converts paragraph block
     */
    convertParagraph(block, indent) {
        const text = this.convertRichText(block.paragraph?.rich_text || []);
        return text ? `${indent}${text}\n\n` : '';
    }
    /**
     * Converts heading blocks
     */
    convertHeading(block, level, indent) {
        const headingData = block[`heading_${level}`];
        const text = this.convertRichText(headingData?.rich_text || []);
        const hashes = '#'.repeat(level);
        return text ? `${indent}${hashes} ${text}\n\n` : '';
    }
    /**
     * Converts bulleted list item
     */
    convertBulletedListItem(block, indent) {
        const text = this.convertRichText(block.bulleted_list_item?.rich_text || []);
        return text ? `${indent}- ${text}\n` : '';
    }
    /**
     * Converts numbered list item
     */
    convertNumberedListItem(block, indent) {
        const text = this.convertRichText(block.numbered_list_item?.rich_text || []);
        return text ? `${indent}1. ${text}\n` : '';
    }
    /**
     * Converts to-do block
     */
    convertToDo(block, indent) {
        const text = this.convertRichText(block.to_do?.rich_text || []);
        const checked = block.to_do?.checked ? 'x' : ' ';
        return text ? `${indent}- [${checked}] ${text}\n` : '';
    }
    /**
     * Converts toggle block
     */
    convertToggle(block, indent) {
        const text = this.convertRichText(block.toggle?.rich_text || []);
        return text ? `${indent}<details><summary>${text}</summary>\n\n` : '';
    }
    /**
     * Converts code block
     */
    convertCode(block, indent) {
        const code = this.convertRichText(block.code?.rich_text || []);
        const language = block.code?.language || '';
        return `${indent}\`\`\`${language}\n${code}\n\`\`\`\n\n`;
    }
    /**
     * Converts quote block
     */
    convertQuote(block, indent) {
        const text = this.convertRichText(block.quote?.rich_text || []);
        return text ? `${indent}> ${text}\n\n` : '';
    }
    /**
     * Converts callout block
     */
    convertCallout(block, indent) {
        const text = this.convertRichText(block.callout?.rich_text || []);
        const icon = block.callout?.icon?.emoji || '💡';
        return text ? `${indent}> ${icon} ${text}\n\n` : '';
    }
    /**
     * Converts media blocks (image, video, file)
     */
    convertMedia(block, indent) {
        const mediaData = block[block.type];
        const attachments = [];
        let url = '';
        if (mediaData?.external?.url) {
            url = mediaData.external.url;
        }
        else if (mediaData?.file?.url) {
            url = mediaData.file.url;
        }
        if (!url) {
            return { content: `${indent}<!-- Missing ${block.type} URL -->\n\n`, attachments };
        }
        const filename = this.extractFilenameFromUrl(url) || `${block.id}.${this.getFileExtensionFromType(block.type)}`;
        const localPath = `attachments/${filename}`;
        attachments.push({
            originalUrl: url,
            localPath,
            filename,
            type: this.mapBlockTypeToAttachmentType(block.type),
            downloaded: false
        });
        const caption = this.convertRichText(mediaData?.caption || []);
        let content = '';
        if (block.type === 'image') {
            content = `${indent}![${caption || filename}](${localPath})\n\n`;
        }
        else {
            content = `${indent}[${caption || filename}](${localPath})\n\n`;
        }
        return { content, attachments };
    }
    /**
     * Converts bookmark block
     */
    convertBookmark(block, indent) {
        const url = block.bookmark?.url || '';
        const caption = this.convertRichText(block.bookmark?.caption || []);
        return `${indent}[${caption || url}](${url})\n\n`;
    }
    /**
     * Converts link preview block
     */
    convertLinkPreview(block, indent) {
        const url = block.link_preview?.url || '';
        return `${indent}[${url}](${url})\n\n`;
    }
    /**
     * Converts table block
     */
    convertTable(block, indent) {
        // Table conversion would require fetching child table_row blocks
        // This is a simplified version
        return `${indent}<!-- Table content (${block.id}) -->\n\n`;
    }
    /**
     * Converts equation block
     */
    convertEquation(block, indent) {
        const expression = block.equation?.expression || '';
        return `${indent}$$${expression}$$\n\n`;
    }
    /**
     * Converts embed block
     */
    convertEmbed(block, indent) {
        const url = block.embed?.url || '';
        return `${indent}[Embedded content](${url})\n\n`;
    }
    /**
     * Converts column list block
     */
    convertColumnList(_block, indent) {
        return `${indent}<!-- Column layout start -->\n\n`;
    }
    /**
     * Converts column block
     */
    convertColumn(_block, indent) {
        return `${indent}<!-- Column -->\n\n`;
    }
    /**
     * Converts synced block
     */
    convertSyncedBlock(block, indent) {
        return `${indent}<!-- Synced block (${block.id}) -->\n\n`;
    }
    /**
     * Converts Notion rich text array to markdown string
     */
    convertRichText(richText) {
        if (!Array.isArray(richText)) {
            return '';
        }
        return richText.map(text => {
            let content = text.plain_text || '';
            if (text.annotations) {
                if (text.annotations.bold)
                    content = `**${content}**`;
                if (text.annotations.italic)
                    content = `*${content}*`;
                if (text.annotations.strikethrough)
                    content = `~~${content}~~`;
                if (text.annotations.underline)
                    content = `<u>${content}</u>`;
                if (text.annotations.code)
                    content = `\`${content}\``;
            }
            if (text.href) {
                content = `[${content}](${text.href})`;
            }
            return content;
        }).join('');
    }
    /**
     * Generates frontmatter for the markdown file
     */
    generateFrontmatter(metadata) {
        const frontmatter = [
            '---',
            `title: "${metadata.title.replace(/"/g, '\\"')}"`,
            `created: ${metadata.createdTime}`,
            `updated: ${metadata.lastEditedTime}`,
            `notion_id: ${metadata.notionId}`
        ];
        if (metadata.tags && metadata.tags.length > 0) {
            frontmatter.push(`tags: [${metadata.tags.map(tag => `"${tag}"`).join(', ')}]`);
        }
        if (metadata.url) {
            frontmatter.push(`notion_url: "${metadata.url}"`);
        }
        frontmatter.push('---', '');
        return frontmatter.join('\n') + '\n';
    }
    /**
     * Sets up custom Turndown rules
     */
    setupCustomRules() {
        // Add custom rules for better Notion to Markdown conversion
        this.turndownService.addRule('strikethrough', {
            filter: ['del', 's'],
            replacement: (content) => `~~${content}~~`
        });
        this.turndownService.addRule('underline', {
            filter: 'u',
            replacement: (content) => `<u>${content}</u>`
        });
    }
    /**
     * Utility functions
     */
    extractFilenameFromUrl(url) {
        try {
            const urlObj = new URL(url);
            const pathname = urlObj.pathname;
            return pathname.split('/').pop() || null;
        }
        catch {
            return null;
        }
    }
    getFileExtensionFromType(blockType) {
        const extensions = {
            image: 'png',
            video: 'mp4',
            file: 'file',
            pdf: 'pdf'
        };
        return extensions[blockType] || 'file';
    }
    mapBlockTypeToAttachmentType(blockType) {
        const typeMap = {
            image: 'image',
            video: 'video',
            file: 'file',
            pdf: 'file'
        };
        return typeMap[blockType] || 'file';
    }
}
exports.ContentConverter = ContentConverter;
//# sourceMappingURL=ContentConverter.js.map