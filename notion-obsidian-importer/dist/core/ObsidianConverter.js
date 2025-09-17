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
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.ObsidianConverter = void 0;
const path = __importStar(require("path"));
const ContentConverter_1 = require("../converters/ContentConverter");
const DatabaseConverter_1 = require("../converters/DatabaseConverter");
const ObsidianAdapter_1 = require("../adapters/ObsidianAdapter");
const ProgressTracker_1 = require("./ProgressTracker");
const Logger_1 = __importDefault(require("./Logger"));
class ObsidianConverter {
    constructor(config, progressTracker) {
        this.config = config;
        this.contentConverter = new ContentConverter_1.ContentConverter(config.conversion);
        this.databaseConverter = new DatabaseConverter_1.DatabaseConverter(config.conversion);
        this.obsidianAdapter = new ObsidianAdapter_1.ObsidianAdapter(config.obsidian);
        this.progressTracker = progressTracker || new ProgressTracker_1.ProgressTracker();
    }
    async convertAndSave(importResult) {
        Logger_1.default.info('Starting conversion to Obsidian format...');
        this.progressTracker.startPhase('conversion');
        try {
            // Initialize vault
            await this.obsidianAdapter.initializeVault();
            // Convert pages
            for (const page of importResult.importedPages || []) {
                await this.convertPage(page);
            }
            // Convert databases
            for (const database of importResult.importedDatabases || []) {
                await this.convertDatabase(database);
            }
            this.progressTracker.completePhase('conversion');
            // Writing phase
            this.progressTracker.startPhase('writing');
            await this.obsidianAdapter.createImportIndex({
                importDate: new Date().toISOString(),
                totalPages: importResult.totalPages,
                totalDatabases: importResult.totalDatabases,
                totalAttachments: importResult.totalAttachments,
            });
            this.progressTracker.completePhase('writing');
            Logger_1.default.success('Conversion completed successfully!');
        }
        catch (error) {
            Logger_1.default.error('Conversion failed', error);
            throw error;
        }
    }
    async convertPage(page) {
        try {
            this.progressTracker.updateProgress({
                currentItem: `Converting: ${page.properties?.title?.title?.[0]?.plain_text || page.id}`
            });
            const markdown = await this.contentConverter.convertPage(page);
            const title = this.extractTitle(page);
            const filePath = this.generateFilePath(title, page.id);
            await this.obsidianAdapter.saveFile(filePath, markdown);
            // Handle attachments
            if (page.blocks) {
                await this.handleAttachments(page.blocks);
            }
            this.progressTracker.incrementProcessed();
        }
        catch (error) {
            Logger_1.default.error(`Failed to convert page ${page.id}`, error);
            this.progressTracker.incrementFailed(error);
        }
    }
    async convertDatabase(database) {
        try {
            this.progressTracker.updateProgress({
                currentItem: `Converting database: ${database.title?.[0]?.plain_text || database.id}`
            });
            const { indexFile } = await this.databaseConverter.convertDatabase(database, database.pages || []);
            const title = database.title?.[0]?.plain_text || 'Untitled Database';
            // Save database index
            const indexPath = this.generateFilePath(`${title} - Index`, database.id || 'unknown');
            await this.obsidianAdapter.saveFile(indexPath, indexFile.markdown);
            // Save database pages
            if (database.pages) {
                for (const page of database.pages) {
                    const pageMarkdown = await this.contentConverter.convertPage(page);
                    const pageTitle = this.extractTitle(page);
                    const pagePath = this.generateFilePath(`${title}/${pageTitle}`, page.id || 'unknown');
                    await this.obsidianAdapter.saveFile(pagePath, pageMarkdown);
                }
            }
            this.progressTracker.incrementProcessed();
        }
        catch (error) {
            Logger_1.default.error(`Failed to convert database ${database.id}`, error);
            this.progressTracker.incrementFailed(error);
        }
    }
    async handleAttachments(blocks) {
        for (const block of blocks) {
            // Handle images
            if (block.type === 'image' && block.image) {
                const imageUrl = block.image.file?.url || block.image.external?.url;
                if (imageUrl) {
                    const fileName = this.extractFileName(imageUrl, block.id);
                    const attachmentPath = path.join(this.config.obsidian.attachmentsFolder || 'attachments', fileName);
                    // Download will be handled by NotionImporter
                    this.progressTracker.addDownloadedFile(attachmentPath);
                }
            }
            // Handle files
            if (block.type === 'file' && block.file) {
                const fileUrl = block.file.file?.url || block.file.external?.url;
                if (fileUrl) {
                    const fileName = block.file.caption?.[0]?.plain_text ||
                        this.extractFileName(fileUrl, block.id);
                    const attachmentPath = path.join(this.config.obsidian.attachmentsFolder || 'attachments', fileName);
                    this.progressTracker.addDownloadedFile(attachmentPath);
                }
            }
            // Recursively handle children
            if (block.children) {
                await this.handleAttachments(block.children);
            }
        }
    }
    extractTitle(page) {
        if (page.properties?.title?.title?.[0]?.plain_text) {
            return page.properties.title.title[0].plain_text;
        }
        if (page.properties?.Name?.title?.[0]?.plain_text) {
            return page.properties.Name.title[0].plain_text;
        }
        return `Untitled ${page.id.substring(0, 8)}`;
    }
    generateFilePath(title, id) {
        // Sanitize title for file system
        const sanitized = title
            .replace(/[<>:"/\\|?*]/g, '-')
            .replace(/\s+/g, ' ')
            .trim();
        if (this.config.conversion?.preserveNotionIds) {
            return `${sanitized} [${id.substring(0, 8)}].md`;
        }
        return `${sanitized}.md`;
    }
    extractFileName(url, blockId) {
        try {
            const urlPath = new URL(url).pathname;
            const fileName = path.basename(urlPath);
            if (fileName && fileName !== '/') {
                return fileName;
            }
        }
        catch {
            // Invalid URL, fall back to block ID
        }
        return `attachment-${blockId.substring(0, 8)}`;
    }
}
exports.ObsidianConverter = ObsidianConverter;
exports.default = ObsidianConverter;
//# sourceMappingURL=ObsidianConverter.js.map