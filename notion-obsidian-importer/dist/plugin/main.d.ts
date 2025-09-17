import { Plugin } from 'obsidian';
import { NotionImporterSettings } from './settings';
export default class NotionImporterPlugin extends Plugin {
    settings: NotionImporterSettings;
    private progressModal;
    private progressTracker;
    private logger;
    private isImporting;
    onload(): Promise<void>;
    onunload(): void;
    loadSettings(): Promise<void>;
    saveSettings(): Promise<void>;
    private openImportModal;
    private startImport;
    private performImport;
    private ensureFolder;
    validateNotionToken(token: string): Promise<boolean>;
}
//# sourceMappingURL=main.d.ts.map