"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const obsidian_1 = require("obsidian");
const settings_1 = require("./settings");
const ProgressModal_1 = require("./views/ProgressModal");
const NotionImporter_1 = require("../core/NotionImporter");
const ObsidianConverter_1 = require("../core/ObsidianConverter");
const ProgressTracker_1 = require("../core/ProgressTracker");
const Logger_1 = require("../core/Logger");
class NotionImporterPlugin extends obsidian_1.Plugin {
    constructor() {
        super(...arguments);
        this.progressModal = null;
        this.isImporting = false;
    }
    async onload() {
        await this.loadSettings();
        this.progressTracker = new ProgressTracker_1.ProgressTracker();
        this.logger = new Logger_1.Logger('NotionImporterPlugin');
        // Add ribbon icon
        this.addRibbonIcon('download', 'Import from Notion', () => {
            this.openImportModal();
        });
        // Add command
        this.addCommand({
            id: 'import-notion-workspace',
            name: 'Import Notion Workspace',
            callback: () => {
                this.openImportModal();
            }
        });
        // Add settings tab
        this.addSettingTab(new NotionImporterSettingTab(this.app, this));
        // Add status bar item
        this.addStatusBarItem().setText('Notion Importer Ready');
        console.log('Notion Importer Plugin loaded');
    }
    onunload() {
        if (this.progressModal) {
            this.progressModal.close();
        }
        console.log('Notion Importer Plugin unloaded');
    }
    async loadSettings() {
        this.settings = Object.assign({}, settings_1.DEFAULT_SETTINGS, await this.loadData());
    }
    async saveSettings() {
        await this.saveData(this.settings);
    }
    openImportModal() {
        if (this.isImporting) {
            new obsidian_1.Notice('Import already in progress');
            return;
        }
        new ImportConfigModal(this.app, this, (config) => {
            this.startImport(config);
        }).open();
    }
    async startImport(config) {
        if (this.isImporting) {
            new obsidian_1.Notice('Import already in progress');
            return;
        }
        this.isImporting = true;
        try {
            // Validate token first
            if (!config.notionToken) {
                new obsidian_1.Notice('Notion API token is required');
                return;
            }
            // Create progress modal
            this.progressModal = new ProgressModal_1.ProgressModal(this.app, this.progressTracker);
            this.progressModal.open();
            // Initialize importer
            const importerConfig = {
                notion: {
                    token: config.notionToken
                },
                obsidian: {
                    vaultPath: config.targetFolder
                },
                conversion: {
                    preserveNotionIds: this.settings.preserveNotionIds,
                    convertTables: this.settings.convertTables,
                    downloadImages: this.settings.downloadImages,
                    imageFormat: this.settings.imageFormat,
                    maxImageSize: this.settings.maxImageSize * 1024 * 1024
                }
            };
            const importer = new NotionImporter_1.NotionImporter(importerConfig, this.progressTracker);
            // Initialize converter
            const converter = new ObsidianConverter_1.ObsidianConverter(importerConfig, this.progressTracker);
            // Start import process
            await this.performImport(importer, converter, config);
            new obsidian_1.Notice('Import completed successfully!');
            this.progressModal?.setComplete();
        }
        catch (error) {
            this.logger.error('Import failed:', error);
            new obsidian_1.Notice(`Import failed: ${error instanceof Error ? error.message : 'Unknown error'}`);
            this.progressModal?.setError(error instanceof Error ? error.message : 'Unknown error');
        }
        finally {
            this.isImporting = false;
        }
    }
    async performImport(importer, converter, config) {
        // Test connection
        this.progressModal?.updateStatus('Connecting to Notion...');
        const connected = await importer.testConnection();
        if (!connected) {
            throw new Error('Failed to connect to Notion API');
        }
        this.progressModal?.updateStatus('Connected to Notion API');
        // Discover content
        this.progressModal?.updateStatus('Discovering content...');
        const discovery = await importer.discoverContent();
        this.progressModal?.updateStatus(`Found ${discovery.pages.length} pages and ${discovery.databases.length} databases`);
        // Import pages
        let processed = 0;
        const totalItems = discovery.pages.length + discovery.databases.length;
        for (const page of discovery.pages) {
            if (config.selectedPages && !config.selectedPages.includes(page.id)) {
                continue;
            }
            this.progressModal?.updateStatus(`Processing page: ${page.properties?.title?.title?.[0]?.plain_text || page.id}`);
            try {
                const pageData = await importer.downloadPage(page.id);
                if (pageData) {
                    processed++;
                }
                this.progressTracker.updateProgress({
                    processedItems: processed,
                    totalItems: totalItems
                });
            }
            catch (error) {
                this.logger.error(`Failed to process page ${page.id}:`, error);
                if (this.settings.continueOnError) {
                    continue;
                }
                else {
                    throw error;
                }
            }
        }
        // Import databases
        for (const database of discovery.databases) {
            this.progressModal?.updateStatus(`Processing database: ${database.title?.[0]?.plain_text || database.id}`);
            try {
                const databaseData = await importer.downloadDatabase(database.id);
                if (databaseData) {
                    processed++;
                }
                this.progressTracker.updateProgress({
                    processedItems: processed,
                    totalItems: totalItems
                });
            }
            catch (error) {
                this.logger.error(`Failed to process database ${database.id}:`, error);
                if (this.settings.continueOnError) {
                    continue;
                }
                else {
                    throw error;
                }
            }
        }
        // Convert to Obsidian
        this.progressModal?.updateStatus('Converting to Obsidian format...');
        const importResult = {
            success: true,
            totalPages: discovery.pages.length,
            totalDatabases: discovery.databases.length,
            totalAttachments: 0,
            errors: []
        };
        await converter.convertAndSave(importResult);
        this.progressModal?.updateStatus(`Import complete! Processed ${processed} items`);
    }
    async ensureFolder(folderPath) {
        const normalizedPath = (0, obsidian_1.normalizePath)(folderPath);
        let folder = this.app.vault.getAbstractFileByPath(normalizedPath);
        if (!folder) {
            folder = await this.app.vault.createFolder(normalizedPath);
        }
        if (!(folder instanceof obsidian_1.TFolder)) {
            throw new Error(`Path exists but is not a folder: ${normalizedPath}`);
        }
        return folder;
    }
    async validateNotionToken(token) {
        try {
            const testConfig = {
                notion: {
                    token: token
                },
                obsidian: {
                    vaultPath: ''
                }
            };
            const importer = new NotionImporter_1.NotionImporter(testConfig);
            return await importer.testConnection();
        }
        catch {
            return false;
        }
    }
}
exports.default = NotionImporterPlugin;
class ImportConfigModal extends obsidian_1.Modal {
    constructor(_app, plugin, onSubmit) {
        super(_app);
        this.config = {
            notionToken: '',
            targetFolder: 'Notion Import'
        };
        this.plugin = plugin;
        this.onSubmit = onSubmit;
    }
    onOpen() {
        const { contentEl } = this;
        contentEl.empty();
        contentEl.createEl('h2', { text: 'Import from Notion' });
        // Notion Token
        new obsidian_1.Setting(contentEl)
            .setName('Notion API Token')
            .setDesc('Your Notion integration token')
            .addText(text => {
            text.setPlaceholder('secret_...')
                .setValue(this.plugin.settings.notionToken)
                .onChange(async (value) => {
                this.config.notionToken = value;
            });
            text.inputEl.type = 'password';
        });
        // Target Folder
        new obsidian_1.Setting(contentEl)
            .setName('Target Folder')
            .setDesc('Folder where pages will be imported')
            .addText(text => {
            text.setPlaceholder('Notion Import')
                .setValue(this.config.targetFolder)
                .onChange(async (value) => {
                this.config.targetFolder = value;
            });
        });
        // Buttons
        const buttonContainer = contentEl.createDiv({ cls: 'modal-button-container' });
        const cancelButton = buttonContainer.createEl('button', { text: 'Cancel' });
        cancelButton.addEventListener('click', () => {
            this.close();
        });
        const validateButton = buttonContainer.createEl('button', { text: 'Validate Token' });
        validateButton.addEventListener('click', async () => {
            if (!this.config.notionToken) {
                new obsidian_1.Notice('Please enter a Notion API token');
                return;
            }
            const notice = new obsidian_1.Notice('Validating token...', 0);
            try {
                const isValid = await this.plugin.validateNotionToken(this.config.notionToken);
                notice.hide();
                if (isValid) {
                    new obsidian_1.Notice('Token is valid!');
                }
                else {
                    new obsidian_1.Notice('Invalid token');
                }
            }
            catch (error) {
                notice.hide();
                new obsidian_1.Notice('Token validation failed');
            }
        });
        const importButton = buttonContainer.createEl('button', {
            text: 'Start Import',
            cls: 'mod-cta'
        });
        importButton.addEventListener('click', () => {
            if (!this.config.notionToken) {
                new obsidian_1.Notice('Please enter a Notion API token');
                return;
            }
            if (!this.config.targetFolder) {
                new obsidian_1.Notice('Please enter a target folder');
                return;
            }
            this.close();
            this.onSubmit(this.config);
        });
    }
    onClose() {
        const { contentEl } = this;
        contentEl.empty();
    }
}
class NotionImporterSettingTab extends obsidian_1.PluginSettingTab {
    constructor(app, plugin) {
        super(app, plugin);
        this.plugin = plugin;
    }
    display() {
        const { containerEl } = this;
        containerEl.empty();
        containerEl.createEl('h2', { text: 'Notion Importer Settings' });
        // API Settings
        containerEl.createEl('h3', { text: 'API Settings' });
        new obsidian_1.Setting(containerEl)
            .setName('Notion API Token')
            .setDesc('Your Notion integration token (will be encrypted)')
            .addText(text => {
            text.setPlaceholder('secret_...')
                .setValue(this.plugin.settings.notionToken)
                .onChange(async (value) => {
                this.plugin.settings.notionToken = value;
                await this.plugin.saveSettings();
            });
            text.inputEl.type = 'password';
        });
        new obsidian_1.Setting(containerEl)
            .setName('Concurrency')
            .setDesc('Number of simultaneous downloads (1-5)')
            .addSlider(slider => {
            slider.setLimits(1, 5, 1)
                .setValue(this.plugin.settings.concurrency)
                .setDynamicTooltip()
                .onChange(async (value) => {
                this.plugin.settings.concurrency = value;
                await this.plugin.saveSettings();
            });
        });
        new obsidian_1.Setting(containerEl)
            .setName('Retry Attempts')
            .setDesc('Number of retry attempts for failed requests')
            .addSlider(slider => {
            slider.setLimits(1, 10, 1)
                .setValue(this.plugin.settings.retryAttempts)
                .setDynamicTooltip()
                .onChange(async (value) => {
                this.plugin.settings.retryAttempts = value;
                await this.plugin.saveSettings();
            });
        });
        // Content Settings
        containerEl.createEl('h3', { text: 'Content Settings' });
        new obsidian_1.Setting(containerEl)
            .setName('Preserve Notion IDs')
            .setDesc('Include Notion page IDs in frontmatter')
            .addToggle(toggle => {
            toggle.setValue(this.plugin.settings.preserveNotionIds)
                .onChange(async (value) => {
                this.plugin.settings.preserveNotionIds = value;
                await this.plugin.saveSettings();
            });
        });
        new obsidian_1.Setting(containerEl)
            .setName('Convert Tables')
            .setDesc('Convert Notion databases to Markdown tables')
            .addToggle(toggle => {
            toggle.setValue(this.plugin.settings.convertTables)
                .onChange(async (value) => {
                this.plugin.settings.convertTables = value;
                await this.plugin.saveSettings();
            });
        });
        new obsidian_1.Setting(containerEl)
            .setName('Download Images')
            .setDesc('Download and embed images locally')
            .addToggle(toggle => {
            toggle.setValue(this.plugin.settings.downloadImages)
                .onChange(async (value) => {
                this.plugin.settings.downloadImages = value;
                await this.plugin.saveSettings();
            });
        });
        new obsidian_1.Setting(containerEl)
            .setName('Image Format')
            .setDesc('Preferred format for downloaded images')
            .addDropdown(dropdown => {
            dropdown.addOption('original', 'Keep Original')
                .addOption('png', 'Convert to PNG')
                .addOption('jpg', 'Convert to JPG')
                .setValue(this.plugin.settings.imageFormat)
                .onChange(async (value) => {
                this.plugin.settings.imageFormat = value;
                await this.plugin.saveSettings();
            });
        });
        new obsidian_1.Setting(containerEl)
            .setName('Max Image Size (MB)')
            .setDesc('Maximum size for downloaded images (0 = no limit)')
            .addSlider(slider => {
            slider.setLimits(0, 50, 1)
                .setValue(this.plugin.settings.maxImageSize)
                .setDynamicTooltip()
                .onChange(async (value) => {
                this.plugin.settings.maxImageSize = value;
                await this.plugin.saveSettings();
            });
        });
        // Error Handling
        containerEl.createEl('h3', { text: 'Error Handling' });
        new obsidian_1.Setting(containerEl)
            .setName('Continue on Error')
            .setDesc('Continue importing other pages if one fails')
            .addToggle(toggle => {
            toggle.setValue(this.plugin.settings.continueOnError)
                .onChange(async (value) => {
                this.plugin.settings.continueOnError = value;
                await this.plugin.saveSettings();
            });
        });
        new obsidian_1.Setting(containerEl)
            .setName('Show Detailed Errors')
            .setDesc('Display detailed error messages in notices')
            .addToggle(toggle => {
            toggle.setValue(this.plugin.settings.showDetailedErrors)
                .onChange(async (value) => {
                this.plugin.settings.showDetailedErrors = value;
                await this.plugin.saveSettings();
            });
        });
    }
}
//# sourceMappingURL=main.js.map