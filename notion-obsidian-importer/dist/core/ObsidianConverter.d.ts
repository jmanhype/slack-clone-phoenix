import { ImportConfig, ImportResult } from '../types';
import { ProgressTracker } from './ProgressTracker';
export declare class ObsidianConverter {
    private contentConverter;
    private databaseConverter;
    private obsidianAdapter;
    private config;
    private progressTracker;
    constructor(config: ImportConfig, progressTracker?: ProgressTracker);
    convertAndSave(importResult: ImportResult): Promise<void>;
    private convertPage;
    private convertDatabase;
    private handleAttachments;
    private extractTitle;
    private generateFilePath;
    private extractFileName;
}
export default ObsidianConverter;
//# sourceMappingURL=ObsidianConverter.d.ts.map