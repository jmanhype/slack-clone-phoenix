# Examples and Tutorials

This directory contains practical examples and tutorials for using the Notion-Obsidian Importer.

## Table of Contents

- [Basic Examples](#basic-examples)
- [Advanced Usage](#advanced-usage)
- [Integration Examples](#integration-examples)
- [Plugin Examples](#plugin-examples)
- [Troubleshooting Examples](#troubleshooting-examples)
- [Real-World Scenarios](#real-world-scenarios)

## Basic Examples

### 1. Simple CLI Import

The most basic way to import your Notion workspace:

```bash
# Interactive setup
npx notion-obsidian-importer

# Direct import
npx notion-obsidian-importer \
  --token "secret_your_notion_token" \
  --vault-path "/Users/john/Documents/MyVault"
```

### 2. Configuration File Usage

Create `notion-importer.config.json`:

```json
{
  "notion": {
    "token": "secret_your_notion_integration_token"
  },
  "obsidian": {
    "vaultPath": "/Users/john/Documents/ObsidianVault",
    "attachmentsFolder": "Files",
    "preserveStructure": true
  }
}
```

Run the import:

```bash
notion-obsidian-importer --config notion-importer.config.json
```

### 3. Basic Programmatic Usage

```typescript
// basic-import.ts
import { NotionObsidianImporter } from 'notion-obsidian-importer';

async function basicImport() {
  const importer = new NotionObsidianImporter({
    notion: {
      token: process.env.NOTION_TOKEN!
    },
    obsidian: {
      vaultPath: './MyVault'
    }
  });

  try {
    await importer.importWorkspace();
    console.log('Import completed successfully!');
  } catch (error) {
    console.error('Import failed:', error);
  }
}

basicImport();
```

## Advanced Usage

### 1. Custom Progress Tracking

```typescript
// progress-tracking.ts
import { NotionObsidianImporter, ProgressInfo } from 'notion-obsidian-importer';
import chalk from 'chalk';

class AdvancedProgressTracker {
  private startTime = Date.now();
  private lastUpdate = 0;

  constructor(private importer: NotionObsidianImporter) {
    this.importer.onProgress(this.handleProgress.bind(this));
    this.importer.onError(this.handleError.bind(this));
  }

  private handleProgress(progress: ProgressInfo) {
    const now = Date.now();
    
    // Update every 500ms to avoid spam
    if (now - this.lastUpdate < 500) return;
    this.lastUpdate = now;

    const elapsed = now - this.startTime;
    const percentage = (progress.processedPages / progress.totalPages) * 100;
    const rate = progress.processedPages / (elapsed / 1000);
    
    // Clear console and show progress
    console.clear();
    console.log(chalk.blue.bold('🚀 Notion → Obsidian Import'));
    console.log(chalk.gray('━'.repeat(60)));
    
    // Progress bar
    const barLength = 40;
    const filledLength = Math.round(barLength * percentage / 100);
    const bar = '█'.repeat(filledLength) + '░'.repeat(barLength - filledLength);
    
    console.log(`${chalk.cyan(bar)} ${chalk.white(percentage.toFixed(1))}%`);
    console.log();
    
    // Statistics
    console.log(chalk.white('📊 Statistics:'));
    console.log(`   Pages: ${chalk.green(progress.processedPages)}/${chalk.blue(progress.totalPages)}`);
    console.log(`   Files: ${chalk.green(progress.downloadedFiles)}/${chalk.blue(progress.totalFiles)}`);
    console.log(`   Rate: ${chalk.yellow(rate.toFixed(1))} pages/sec`);
    console.log(`   Elapsed: ${chalk.gray(this.formatTime(elapsed))}`);
    
    if (progress.estimatedTimeRemaining) {
      console.log(`   ETA: ${chalk.magenta(this.formatTime(progress.estimatedTimeRemaining))}`);
    }
    
    console.log();
    console.log(chalk.white('🔄 Current Operation:'));
    console.log(`   ${chalk.cyan(progress.currentOperation)}`);
    
    if (progress.errors.length > 0) {
      console.log();
      console.log(chalk.red(`⚠️  Errors: ${progress.errors.length}`));
    }
  }

  private handleError(error: any) {
    console.log(chalk.red(`❌ Error: ${error.message}`));
    if (error.retryable) {
      console.log(chalk.yellow('   Will retry automatically...'));
    }
  }

  private formatTime(ms: number): string {
    const seconds = Math.floor(ms / 1000);
    const minutes = Math.floor(seconds / 60);
    const hours = Math.floor(minutes / 60);
    
    if (hours > 0) {
      return `${hours}h ${minutes % 60}m ${seconds % 60}s`;
    } else if (minutes > 0) {
      return `${minutes}m ${seconds % 60}s`;
    } else {
      return `${seconds}s`;
    }
  }
}

// Usage
async function advancedImport() {
  const importer = new NotionObsidianImporter({
    notion: { token: process.env.NOTION_TOKEN! },
    obsidian: { vaultPath: './vault' }
  });

  const tracker = new AdvancedProgressTracker(importer);
  await importer.importWorkspace();
}

advancedImport();
```

### 2. Selective Import with Filtering

```typescript
// selective-import.ts
import { NotionObsidianImporter } from 'notion-obsidian-importer';

async function selectiveImport() {
  const importer = new NotionObsidianImporter({
    notion: { token: process.env.NOTION_TOKEN! },
    obsidian: { vaultPath: './vault' }
  });

  // Get workspace info first
  const workspaceInfo = await importer.getWorkspaceInfo();
  console.log(`Found ${workspaceInfo.pageCount} pages in workspace`);

  // Import only specific pages
  const importantPages = [
    'page-id-1',  // Meeting notes
    'page-id-2',  // Project documentation
    'page-id-3'   // Important references
  ];

  for (const pageId of importantPages) {
    try {
      console.log(`Importing page: ${pageId}`);
      const result = await importer.importPage(pageId);
      console.log(`✅ Imported: ${result.metadata.title}`);
      console.log(`   Attachments: ${result.attachments.length}`);
      console.log(`   Errors: ${result.errors.length}`);
    } catch (error) {
      console.error(`❌ Failed to import ${pageId}:`, error);
    }
  }
}

selectiveImport();
```

### 3. Database-Only Import

```typescript
// database-import.ts
import { NotionObsidianImporter } from 'notion-obsidian-importer';

async function importDatabases() {
  const importer = new NotionObsidianImporter({
    notion: { token: process.env.NOTION_TOKEN! },
    obsidian: { 
      vaultPath: './vault',
      convertDatabases: true,
      databaseFormat: 'table'
    }
  });

  // List of database IDs to import
  const databases = [
    'database-id-1',  // Task tracker
    'database-id-2',  // Reading list
    'database-id-3'   // Project tracker
  ];

  for (const databaseId of databases) {
    try {
      console.log(`Importing database: ${databaseId}`);
      await importer.importDatabase(databaseId);
      console.log(`✅ Database imported successfully`);
    } catch (error) {
      console.error(`❌ Failed to import database ${databaseId}:`, error);
    }
  }
}

importDatabases();
```

## Integration Examples

### 1. Express.js Web Service

```typescript
// server.ts
import express from 'express';
import { NotionObsidianImporter } from 'notion-obsidian-importer';
import { body, validationResult } from 'express-validator';

const app = express();
app.use(express.json());

interface ImportJob {
  id: string;
  status: 'pending' | 'running' | 'completed' | 'failed';
  progress?: any;
  error?: string;
}

const jobs = new Map<string, ImportJob>();

app.post('/import', 
  body('token').notEmpty(),
  body('vaultPath').notEmpty(),
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }

    const jobId = Date.now().toString();
    const job: ImportJob = { id: jobId, status: 'pending' };
    jobs.set(jobId, job);

    // Start import in background
    importWorkspace(jobId, req.body.token, req.body.vaultPath);

    res.json({ jobId, status: 'started' });
  }
);

app.get('/import/:jobId/status', (req, res) => {
  const job = jobs.get(req.params.jobId);
  if (!job) {
    return res.status(404).json({ error: 'Job not found' });
  }
  res.json(job);
});

async function importWorkspace(jobId: string, token: string, vaultPath: string) {
  const job = jobs.get(jobId)!;
  job.status = 'running';

  try {
    const importer = new NotionObsidianImporter({
      notion: { token },
      obsidian: { vaultPath }
    });

    importer.onProgress((progress) => {
      job.progress = progress;
    });

    await importer.importWorkspace();
    job.status = 'completed';
  } catch (error) {
    job.status = 'failed';
    job.error = error instanceof Error ? error.message : 'Unknown error';
  }
}

app.listen(3000, () => {
  console.log('Import service running on port 3000');
});
```

### 2. GitHub Actions Workflow

```yaml
# .github/workflows/notion-import.yml
name: Import Notion to Obsidian

on:
  schedule:
    # Run daily at 2 AM UTC
    - cron: '0 2 * * *'
  workflow_dispatch:

jobs:
  import:
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout repository
      uses: actions/checkout@v3
      
    - name: Setup Node.js
      uses: actions/setup-node@v3
      with:
        node-version: '18'
        
    - name: Install notion-obsidian-importer
      run: npm install -g notion-obsidian-importer
      
    - name: Create vault directory
      run: mkdir -p ./vault
      
    - name: Import Notion workspace
      env:
        NOTION_TOKEN: ${{ secrets.NOTION_TOKEN }}
      run: |
        notion-obsidian-importer \
          --token "$NOTION_TOKEN" \
          --vault-path "./vault" \
          --batch-size 10 \
          --concurrency 3
          
    - name: Commit changes
      run: |
        git config --local user.email \"action@github.com\"
        git config --local user.name \"GitHub Action\"
        git add vault/
        git diff --staged --quiet || git commit -m \"Update vault from Notion $(date)\"
        git push\n```\n\n### 3. Docker Container\n\n```dockerfile\n# Dockerfile\nFROM node:18-alpine\n\nWORKDIR /app\n\n# Install the importer\nRUN npm install -g notion-obsidian-importer\n\n# Create vault directory\nRUN mkdir -p /vault\n\n# Copy configuration\nCOPY notion-importer.config.json .\n\n# Set default command\nCMD [\"notion-obsidian-importer\", \"--config\", \"notion-importer.config.json\"]\n```\n\n```bash\n# Build and run\ndocker build -t notion-importer .\ndocker run -v $(pwd)/vault:/vault -e NOTION_TOKEN=your_token notion-importer\n```\n\n## Plugin Examples\n\n### 1. Custom Plugin Command\n\n```typescript\n// custom-plugin.ts\nimport { Plugin, Notice, Modal } from 'obsidian';\nimport { NotionObsidianImporter } from 'notion-obsidian-importer';\n\nexport default class NotionImporterPlugin extends Plugin {\n  async onload() {\n    // Add ribbon icon\n    this.addRibbonIcon('download', 'Import from Notion', () => {\n      this.showImportModal();\n    });\n\n    // Add command\n    this.addCommand({\n      id: 'import-notion-page',\n      name: 'Import Notion Page',\n      callback: () => this.importSinglePage()\n    });\n  }\n\n  showImportModal() {\n    new ImportModal(this.app, this).open();\n  }\n\n  async importSinglePage() {\n    const pageId = await this.promptForPageId();\n    if (!pageId) return;\n\n    const notice = new Notice('Importing page...', 0);\n    \n    try {\n      const importer = new NotionObsidianImporter({\n        notion: { token: this.settings.notionToken },\n        obsidian: { vaultPath: this.app.vault.adapter.basePath }\n      });\n\n      const result = await importer.importPage(pageId);\n      notice.setMessage(`Imported: ${result.metadata.title}`);\n      \n      setTimeout(() => notice.hide(), 3000);\n    } catch (error) {\n      notice.hide();\n      new Notice(`Import failed: ${error.message}`);\n    }\n  }\n\n  async promptForPageId(): Promise<string | null> {\n    return new Promise((resolve) => {\n      const modal = new Modal(this.app);\n      modal.titleEl.setText('Import Notion Page');\n      \n      const input = modal.contentEl.createEl('input', {\n        type: 'text',\n        placeholder: 'Enter Notion page ID or URL'\n      });\n      \n      const button = modal.contentEl.createEl('button', {\n        text: 'Import'\n      });\n      \n      button.onclick = () => {\n        const value = input.value.trim();\n        modal.close();\n        resolve(value || null);\n      };\n      \n      modal.open();\n    });\n  }\n}\n\nclass ImportModal extends Modal {\n  constructor(app: App, private plugin: NotionImporterPlugin) {\n    super(app);\n  }\n\n  onOpen() {\n    this.titleEl.setText('Import from Notion');\n    \n    // Create form\n    const form = this.contentEl.createEl('form');\n    \n    // Token input\n    form.createEl('label', { text: 'Notion Token:' });\n    const tokenInput = form.createEl('input', { type: 'password' });\n    \n    // Import button\n    const importBtn = form.createEl('button', { \n      text: 'Start Import',\n      type: 'submit'\n    });\n    \n    form.onsubmit = (e) => {\n      e.preventDefault();\n      this.startImport(tokenInput.value);\n    };\n  }\n\n  async startImport(token: string) {\n    // Implementation...\n  }\n}\n```\n\n## Troubleshooting Examples\n\n### 1. Error Recovery and Retry Logic\n\n```typescript\n// error-recovery.ts\nimport { NotionObsidianImporter, ImportError } from 'notion-obsidian-importer';\n\nclass RobustImporter {\n  private failedPages: string[] = [];\n  private retryCount = 0;\n  private maxRetries = 3;\n\n  constructor(private config: any) {}\n\n  async importWithRetry() {\n    const importer = new NotionObsidianImporter(this.config);\n    \n    importer.onError(this.handleError.bind(this));\n    \n    try {\n      await importer.importWorkspace();\n    } catch (error) {\n      console.log('Initial import failed, attempting recovery...');\n      await this.retryFailedPages();\n    }\n  }\n\n  private handleError(error: ImportError) {\n    console.error(`Error: ${error.type} - ${error.message}`);\n    \n    if (error.retryable && error.pageId) {\n      this.failedPages.push(error.pageId);\n    }\n    \n    // Handle specific error types\n    switch (error.type) {\n      case 'RATE_LIMIT':\n        console.log('Rate limited - will retry with backoff');\n        break;\n      case 'NETWORK':\n        console.log('Network error - checking connectivity');\n        break;\n      case 'AUTHENTICATION':\n        console.error('Auth error - check your token');\n        process.exit(1);\n        break;\n    }\n  }\n\n  private async retryFailedPages() {\n    if (this.failedPages.length === 0 || this.retryCount >= this.maxRetries) {\n      return;\n    }\n\n    this.retryCount++;\n    console.log(`Retry attempt ${this.retryCount}/${this.maxRetries}`);\n    console.log(`Retrying ${this.failedPages.length} failed pages...`);\n    \n    const pagesToRetry = [...this.failedPages];\n    this.failedPages = [];\n    \n    const importer = new NotionObsidianImporter(this.config);\n    importer.onError(this.handleError.bind(this));\n    \n    try {\n      await importer.importPages(pagesToRetry);\n      \n      if (this.failedPages.length > 0) {\n        // Some pages still failed, wait and retry\n        await this.delay(5000 * this.retryCount); // Exponential backoff\n        await this.retryFailedPages();\n      }\n    } catch (error) {\n      console.error('Retry failed:', error);\n      await this.retryFailedPages();\n    }\n  }\n\n  private delay(ms: number): Promise<void> {\n    return new Promise(resolve => setTimeout(resolve, ms));\n  }\n}\n\n// Usage\nconst robustImporter = new RobustImporter({\n  notion: { token: process.env.NOTION_TOKEN! },\n  obsidian: { vaultPath: './vault' }\n});\n\nrobustImporter.importWithRetry();\n```\n\n### 2. Network Connectivity Testing\n\n```typescript\n// connectivity-test.ts\nimport { NotionObsidianImporter } from 'notion-obsidian-importer';\nimport axios from 'axios';\n\nclass ConnectivityTester {\n  async runDiagnostics(token: string) {\n    console.log('🔍 Running connectivity diagnostics...');\n    \n    // Test 1: Basic internet connectivity\n    await this.testInternetConnectivity();\n    \n    // Test 2: Notion API accessibility\n    await this.testNotionApiAccess();\n    \n    // Test 3: Token validation\n    await this.testTokenValidation(token);\n    \n    // Test 4: Workspace access\n    await this.testWorkspaceAccess(token);\n    \n    console.log('✅ Diagnostics completed');\n  }\n\n  private async testInternetConnectivity() {\n    try {\n      await axios.get('https://httpbin.org/get', { timeout: 5000 });\n      console.log('✅ Internet connectivity: OK');\n    } catch (error) {\n      console.error('❌ Internet connectivity: FAILED');\n      throw new Error('No internet connection');\n    }\n  }\n\n  private async testNotionApiAccess() {\n    try {\n      await axios.get('https://api.notion.com/v1', { \n        timeout: 5000,\n        validateStatus: () => true // Accept any status\n      });\n      console.log('✅ Notion API accessibility: OK');\n    } catch (error) {\n      console.error('❌ Notion API accessibility: FAILED');\n      throw new Error('Cannot reach Notion API');\n    }\n  }\n\n  private async testTokenValidation(token: string) {\n    try {\n      const response = await axios.get('https://api.notion.com/v1/users/me', {\n        headers: {\n          'Authorization': `Bearer ${token}`,\n          'Notion-Version': '2022-06-28'\n        },\n        timeout: 10000\n      });\n      \n      console.log('✅ Token validation: OK');\n      console.log(`   User: ${response.data.name || 'Bot User'}`);\n    } catch (error) {\n      console.error('❌ Token validation: FAILED');\n      if (axios.isAxiosError(error) && error.response?.status === 401) {\n        throw new Error('Invalid Notion token');\n      }\n      throw error;\n    }\n  }\n\n  private async testWorkspaceAccess(token: string) {\n    try {\n      const importer = new NotionObsidianImporter({\n        notion: { token },\n        obsidian: { vaultPath: './temp-vault' }\n      });\n      \n      const workspaceInfo = await importer.getWorkspaceInfo();\n      console.log('✅ Workspace access: OK');\n      console.log(`   Pages found: ${workspaceInfo.pageCount}`);\n    } catch (error) {\n      console.error('❌ Workspace access: FAILED');\n      console.error('   Make sure pages are shared with your integration');\n      throw error;\n    }\n  }\n}\n\n// Usage\nconst tester = new ConnectivityTester();\ntester.runDiagnostics(process.env.NOTION_TOKEN!)\n  .then(() => console.log('All tests passed!'))\n  .catch(error => {\n    console.error('Diagnostics failed:', error.message);\n    process.exit(1);\n  });\n```\n\n## Real-World Scenarios\n\n### 1. Academic Research Notes Migration\n\n```typescript\n// academic-migration.ts\nimport { NotionObsidianImporter } from 'notion-obsidian-importer';\nimport path from 'path';\n\nclass AcademicMigration {\n  async migrateResearchNotes() {\n    const importer = new NotionObsidianImporter({\n      notion: {\n        token: process.env.NOTION_TOKEN!,\n        rateLimitRequests: 2, // Be conservative for large datasets\n        rateLimitWindow: 1500\n      },\n      obsidian: {\n        vaultPath: './ResearchVault',\n        attachmentsFolder: 'Papers',\n        preserveStructure: true,\n        convertDatabases: true\n      },\n      batchSize: 10, // Smaller batches for academic content\n      concurrency: 2\n    });\n\n    // Track progress for large academic databases\n    importer.onProgress((progress) => {\n      console.log(`Research migration: ${progress.processedPages}/${progress.totalPages}`);\n      console.log(`Papers processed: ${progress.downloadedFiles}`);\n    });\n\n    await importer.importWorkspace();\n    \n    // Post-process for academic format\n    await this.postProcessAcademicContent();\n  }\n\n  private async postProcessAcademicContent() {\n    // Add citation formats, organize by subject, etc.\n    console.log('📚 Post-processing academic content...');\n  }\n}\n\nnew AcademicMigration().migrateResearchNotes();\n```\n\n### 2. Team Knowledge Base Migration\n\n```typescript\n// team-migration.ts\nimport { NotionObsidianImporter } from 'notion-obsidian-importer';\n\nclass TeamKnowledgeBaseMigration {\n  async migrateTeamDocs() {\n    const importer = new NotionObsidianImporter({\n      notion: { token: process.env.NOTION_TOKEN! },\n      obsidian: {\n        vaultPath: './TeamVault',\n        attachmentsFolder: 'assets',\n        preserveStructure: true\n      }\n    });\n\n    // Custom progress tracking for team visibility\n    importer.onProgress((progress) => {\n      this.updateTeamDashboard(progress);\n    });\n\n    await importer.importWorkspace();\n    await this.notifyTeamCompletion();\n  }\n\n  private updateTeamDashboard(progress: any) {\n    // Update team dashboard with progress\n    console.log(`Team migration: ${progress.currentOperation}`);\n  }\n\n  private async notifyTeamCompletion() {\n    // Send notifications to team members\n    console.log('📨 Notifying team of migration completion...');\n  }\n}\n\nnew TeamKnowledgeBaseMigration().migrateTeamDocs();\n```\n\n### 3. Personal Knowledge Management\n\n```typescript\n// personal-pkm.ts\nimport { NotionObsidianImporter } from 'notion-obsidian-importer';\n\nclass PersonalKnowledgeManager {\n  async setupPersonalVault() {\n    const importer = new NotionObsidianImporter({\n      notion: { token: process.env.NOTION_TOKEN! },\n      obsidian: {\n        vaultPath: './PersonalVault',\n        attachmentsFolder: 'media',\n        preserveStructure: false, // Flatten for personal use\n        convertDatabases: true\n      }\n    });\n\n    // Import with custom organization\n    await importer.importWorkspace();\n    await this.organizePersonalContent();\n  }\n\n  private async organizePersonalContent() {\n    // Organize content by topics, add tags, create MOCs\n    console.log('🗂️ Organizing personal knowledge base...');\n  }\n}\n\nnew PersonalKnowledgeManager().setupPersonalVault();\n```\n\n## Tips and Best Practices\n\n### 1. Performance Optimization\n\n- Start with small batch sizes and low concurrency\n- Monitor memory usage with large workspaces\n- Use selective import for testing\n- Enable progress tracking for long imports\n\n### 2. Error Handling\n\n- Always implement error callbacks\n- Handle rate limiting gracefully\n- Use retry logic for transient errors\n- Log errors for debugging\n\n### 3. Content Organization\n\n- Plan your Obsidian vault structure\n- Use consistent naming conventions\n- Organize attachments in dedicated folders\n- Consider flattening vs preserving hierarchy\n\n### 4. Security\n\n- Never commit tokens to version control\n- Use environment variables for sensitive data\n- Rotate tokens regularly\n- Limit integration permissions\n\n---\n\nFor more examples and tutorials, check out our [documentation](../docs/) and [GitHub discussions](https://github.com/notion-obsidian-importer/notion-obsidian-importer/discussions).