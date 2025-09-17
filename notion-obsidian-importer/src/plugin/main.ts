import { Plugin, Notice, Modal, Setting, TFolder, normalizePath, PluginSettingTab } from 'obsidian';
import { NotionImporterSettings, DEFAULT_SETTINGS } from './settings';
import { ProgressModal } from './views/ProgressModal';
import { NotionImporter } from '../core/NotionImporter';
import { ObsidianConverter } from '../core/ObsidianConverter';
import { ProgressTracker } from '../core/ProgressTracker';
import { Logger } from '../core/Logger';

export default class NotionImporterPlugin extends Plugin {
  settings!: NotionImporterSettings;
  private progressModal: ProgressModal | null = null;
  private progressTracker!: ProgressTracker;
  private logger!: Logger;
  private isImporting = false;

  async onload() {
    await this.loadSettings();
    
    this.progressTracker = new ProgressTracker();
    this.logger = new (Logger as any)('NotionImporterPlugin');
    
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
    this.settings = Object.assign({}, DEFAULT_SETTINGS, await this.loadData());
  }

  async saveSettings() {
    await this.saveData(this.settings);
  }

  private openImportModal() {
    if (this.isImporting) {
      new Notice('Import already in progress');
      return;
    }

    new ImportConfigModal(this.app, this, (config) => {
      this.startImport(config);
    }).open();
  }

  private async startImport(config: ImportConfig) {
    if (this.isImporting) {
      new Notice('Import already in progress');
      return;
    }

    this.isImporting = true;

    try {
      // Validate token first
      if (!config.notionToken) {
        new Notice('Notion API token is required');
        return;
      }

      // Create progress modal
      this.progressModal = new ProgressModal(this.app, this.progressTracker);
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
      const importer = new NotionImporter(importerConfig, this.progressTracker);

      // Initialize converter
      const converter = new ObsidianConverter(importerConfig, this.progressTracker);

      // Start import process
      await this.performImport(importer, converter, config);

      new Notice('Import completed successfully!');
      this.progressModal?.setComplete();

    } catch (error) {
      this.logger.error('Import failed:', error);
      new Notice(`Import failed: ${error instanceof Error ? error.message : 'Unknown error'}`);
      this.progressModal?.setError(error instanceof Error ? error.message : 'Unknown error');
    } finally {
      this.isImporting = false;
    }
  }

  private async performImport(importer: NotionImporter, converter: ObsidianConverter, config: ImportConfig) {
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

      } catch (error) {
        this.logger.error(`Failed to process page ${page.id}:`, error);
        if (this.settings.continueOnError) {
          continue;
        } else {
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

      } catch (error) {
        this.logger.error(`Failed to process database ${database.id}:`, error);
        if (this.settings.continueOnError) {
          continue;
        } else {
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

  private async ensureFolder(folderPath: string): Promise<TFolder> {
    const normalizedPath = normalizePath(folderPath);
    
    let folder = this.app.vault.getAbstractFileByPath(normalizedPath);
    
    if (!folder) {
      folder = await this.app.vault.createFolder(normalizedPath);
    }
    
    if (!(folder instanceof TFolder)) {
      throw new Error(`Path exists but is not a folder: ${normalizedPath}`);
    }
    
    return folder;
  }

  async validateNotionToken(token: string): Promise<boolean> {
    try {
      const testConfig = {
        notion: {
          token: token
        },
        obsidian: {
          vaultPath: ''
        }
      };
      const importer = new NotionImporter(testConfig);
      return await importer.testConnection();
    } catch {
      return false;
    }
  }
}

interface ImportConfig {
  notionToken: string;
  targetFolder: string;
  selectedPages?: string[];
}

class ImportConfigModal extends Modal {
  private plugin: NotionImporterPlugin;
  private onSubmit: (config: ImportConfig) => void;
  private config: ImportConfig = {
    notionToken: '',
    targetFolder: 'Notion Import'
  };

  constructor(_app: any, plugin: NotionImporterPlugin, onSubmit: (config: ImportConfig) => void) {
    super(_app);
    this.plugin = plugin;
    this.onSubmit = onSubmit;
  }

  onOpen() {
    const { contentEl } = this;
    contentEl.empty();

    contentEl.createEl('h2', { text: 'Import from Notion' });

    // Notion Token
    new Setting(contentEl)
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
    new Setting(contentEl)
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
        new Notice('Please enter a Notion API token');
        return;
      }

      const notice = new Notice('Validating token...', 0);
      try {
        const isValid = await this.plugin.validateNotionToken(this.config.notionToken);
        notice.hide();
        
        if (isValid) {
          new Notice('Token is valid!');
        } else {
          new Notice('Invalid token');
        }
      } catch (error) {
        notice.hide();
        new Notice('Token validation failed');
      }
    });

    const importButton = buttonContainer.createEl('button', { 
      text: 'Start Import',
      cls: 'mod-cta'
    });
    importButton.addEventListener('click', () => {
      if (!this.config.notionToken) {
        new Notice('Please enter a Notion API token');
        return;
      }
      
      if (!this.config.targetFolder) {
        new Notice('Please enter a target folder');
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

class NotionImporterSettingTab extends PluginSettingTab {
  plugin: NotionImporterPlugin;

  constructor(app: any, plugin: NotionImporterPlugin) {
    super(app, plugin);
    this.plugin = plugin;
  }

  display(): void {
    const { containerEl } = this;
    containerEl.empty();

    containerEl.createEl('h2', { text: 'Notion Importer Settings' });

    // API Settings
    containerEl.createEl('h3', { text: 'API Settings' });

    new Setting(containerEl)
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

    new Setting(containerEl)
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

    new Setting(containerEl)
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

    new Setting(containerEl)
      .setName('Preserve Notion IDs')
      .setDesc('Include Notion page IDs in frontmatter')
      .addToggle(toggle => {
        toggle.setValue(this.plugin.settings.preserveNotionIds)
          .onChange(async (value) => {
            this.plugin.settings.preserveNotionIds = value;
            await this.plugin.saveSettings();
          });
      });

    new Setting(containerEl)
      .setName('Convert Tables')
      .setDesc('Convert Notion databases to Markdown tables')
      .addToggle(toggle => {
        toggle.setValue(this.plugin.settings.convertTables)
          .onChange(async (value) => {
            this.plugin.settings.convertTables = value;
            await this.plugin.saveSettings();
          });
      });

    new Setting(containerEl)
      .setName('Download Images')
      .setDesc('Download and embed images locally')
      .addToggle(toggle => {
        toggle.setValue(this.plugin.settings.downloadImages)
          .onChange(async (value) => {
            this.plugin.settings.downloadImages = value;
            await this.plugin.saveSettings();
          });
      });

    new Setting(containerEl)
      .setName('Image Format')
      .setDesc('Preferred format for downloaded images')
      .addDropdown(dropdown => {
        dropdown.addOption('original', 'Keep Original')
          .addOption('png', 'Convert to PNG')
          .addOption('jpg', 'Convert to JPG')
          .setValue(this.plugin.settings.imageFormat)
          .onChange(async (value) => {
            this.plugin.settings.imageFormat = value as any;
            await this.plugin.saveSettings();
          });
      });

    new Setting(containerEl)
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

    new Setting(containerEl)
      .setName('Continue on Error')
      .setDesc('Continue importing other pages if one fails')
      .addToggle(toggle => {
        toggle.setValue(this.plugin.settings.continueOnError)
          .onChange(async (value) => {
            this.plugin.settings.continueOnError = value;
            await this.plugin.saveSettings();
          });
      });

    new Setting(containerEl)
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