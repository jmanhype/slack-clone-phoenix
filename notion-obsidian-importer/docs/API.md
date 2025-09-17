# API Documentation

This document provides comprehensive API documentation for developers integrating the Notion-Obsidian Importer into their applications.

## Table of Contents

- [Installation](#installation)
- [Core Classes](#core-classes)
- [Configuration](#configuration)
- [Progress Tracking](#progress-tracking)
- [Error Handling](#error-handling)
- [TypeScript Types](#typescript-types)
- [Examples](#examples)

## Installation

```bash
npm install notion-obsidian-importer
```

## Core Classes

### NotionObsidianImporter

The main class for importing Notion content to Obsidian.

#### Constructor

```typescript
constructor(config: ImportConfig)
```

**Parameters:**
- `config`: ImportConfig - Configuration object containing Notion and Obsidian settings

#### Methods

##### importWorkspace()

```typescript
async importWorkspace(): Promise<void>
```

Imports the entire Notion workspace accessible to the integration.

**Returns:** `Promise<void>`

**Example:**
```typescript
const importer = new NotionObsidianImporter(config);
await importer.importWorkspace();
```

##### importPages()

```typescript
async importPages(pageIds: string[]): Promise<void>
```

Imports specific Notion pages by their IDs.

**Parameters:**
- `pageIds`: string[] - Array of Notion page IDs to import

**Returns:** `Promise<void>`

**Example:**
```typescript
await importer.importPages(['page-id-1', 'page-id-2']);
```

##### importPage()

```typescript
async importPage(pageId: string): Promise<ConversionResult>
```

Imports a single Notion page and returns the conversion result.

**Parameters:**
- `pageId`: string - Notion page ID to import

**Returns:** `Promise<ConversionResult>` - Contains markdown content, attachments, and metadata

**Example:**
```typescript
const result = await importer.importPage('page-id');
console.log(result.markdown);
console.log(result.attachments);
console.log(result.metadata);
```

##### importDatabase()

```typescript
async importDatabase(databaseId: string): Promise<void>
```

Imports a Notion database and all its pages.

**Parameters:**
- `databaseId`: string - Notion database ID to import

**Returns:** `Promise<void>`

**Example:**
```typescript
await importer.importDatabase('database-id');
```

##### onProgress()

```typescript
onProgress(callback: (progress: ProgressInfo) => void): void
```

Registers a callback function to receive progress updates.

**Parameters:**
- `callback`: Function that receives ProgressInfo updates

**Example:**
```typescript
importer.onProgress((progress) => {
  console.log(`Progress: ${progress.processedPages}/${progress.totalPages}`);
  console.log(`Current: ${progress.currentOperation}`);
  console.log(`ETA: ${progress.estimatedTimeRemaining}ms`);
});
```

##### onError()

```typescript
onError(callback: (error: ImportError) => void): void
```

Registers a callback function to receive error notifications.

**Parameters:**
- `callback`: Function that receives ImportError objects

**Example:**
```typescript
importer.onError((error) => {
  console.error(`Error: ${error.type} - ${error.message}`);
  if (error.retryable) {
    console.log('This error is retryable');
  }
});
```

##### validateConnection()

```typescript
async validateConnection(): Promise<boolean>
```

Tests the connection to Notion API with current configuration.

**Returns:** `Promise<boolean>` - True if connection is valid

**Example:**
```typescript
const isValid = await importer.validateConnection();
if (!isValid) {
  throw new Error('Cannot connect to Notion API');
}
```

##### getWorkspaceInfo()

```typescript
async getWorkspaceInfo(): Promise<WorkspaceInfo>
```

Retrieves information about the accessible Notion workspace.

**Returns:** `Promise<WorkspaceInfo>` - Workspace metadata and page count

**Example:**
```typescript
const info = await importer.getWorkspaceInfo();
console.log(`Workspace: ${info.name}`);
console.log(`Total pages: ${info.pageCount}`);
```

## Configuration

### ImportConfig

```typescript
interface ImportConfig {
  notion: NotionConfig;
  obsidian: ObsidianConfig;
  batchSize?: number;
  concurrency?: number;
  retryAttempts?: number;
  progressTracking?: boolean;
}
```

### NotionConfig

```typescript
interface NotionConfig {
  token: string;                    // Notion integration token
  version?: string;                 // API version (default: '2022-06-28')
  baseUrl?: string;                 // Custom API base URL
  rateLimitRequests?: number;       // Max requests per window (default: 3)
  rateLimitWindow?: number;         // Rate limit window in ms (default: 1000)
}
```

### ObsidianConfig

```typescript
interface ObsidianConfig {
  vaultPath: string;                // Path to Obsidian vault
  attachmentsFolder?: string;       // Folder for attachments (default: 'attachments')
  templateFolder?: string;          // Template folder path
  preserveStructure?: boolean;      // Preserve Notion page hierarchy (default: true)
  convertImages?: boolean;          // Download and convert images (default: true)
  convertDatabases?: boolean;       // Convert databases (default: true)
}
```

## Progress Tracking

### ProgressInfo

```typescript
interface ProgressInfo {
  totalPages: number;               // Total pages to process
  processedPages: number;           // Pages processed so far
  totalFiles: number;               // Total files to download
  downloadedFiles: number;          // Files downloaded so far
  currentOperation: string;         // Current operation description
  startTime: Date;                  // Import start time
  estimatedTimeRemaining?: number;  // ETA in milliseconds
  errors: ImportError[];            // Array of errors encountered
}
```

**Example Usage:**
```typescript
importer.onProgress((progress) => {
  const percentage = (progress.processedPages / progress.totalPages) * 100;
  const eta = progress.estimatedTimeRemaining 
    ? new Date(Date.now() + progress.estimatedTimeRemaining).toLocaleTimeString()
    : 'Unknown';
  
  console.log(`${percentage.toFixed(1)}% complete - ETA: ${eta}`);
  console.log(`Current: ${progress.currentOperation}`);
  
  if (progress.errors.length > 0) {
    console.log(`Errors: ${progress.errors.length}`);
  }
});
```

## Error Handling

### ImportError

```typescript
interface ImportError {
  type: 'RATE_LIMIT' | 'NETWORK' | 'CONVERSION' | 'FILE_SYSTEM' | 'AUTHENTICATION';
  message: string;                  // Human-readable error message
  pageId?: string;                  // Associated page ID (if applicable)
  blockId?: string;                 // Associated block ID (if applicable)
  timestamp: Date;                  // When the error occurred
  retryable: boolean;               // Whether the operation can be retried
}
```

### Error Types

| Type | Description | Retryable |
|------|-------------|-----------|
| `RATE_LIMIT` | Notion API rate limit exceeded | Yes |
| `NETWORK` | Network connectivity issues | Yes |
| `CONVERSION` | Content conversion failed | No |
| `FILE_SYSTEM` | File system operation failed | Depends |
| `AUTHENTICATION` | Invalid or expired token | No |

**Example Error Handling:**
```typescript
importer.onError((error) => {
  switch (error.type) {
    case 'RATE_LIMIT':
      console.log('Rate limited, will retry automatically');
      break;
    case 'NETWORK':
      console.log('Network error, check connection');
      break;
    case 'AUTHENTICATION':
      console.error('Invalid token, please update configuration');
      break;
    default:
      console.error(`Error: ${error.message}`);
  }
});
```

## TypeScript Types

### ConversionResult

```typescript
interface ConversionResult {
  markdown: string;                 // Converted markdown content
  attachments: AttachmentInfo[];    // Downloaded attachments
  metadata: PageMetadata;           // Page metadata
  errors: ImportError[];            // Conversion errors
}
```

### AttachmentInfo

```typescript
interface AttachmentInfo {
  originalUrl: string;              // Original Notion URL
  localPath: string;                // Local file path in vault
  filename: string;                 // Generated filename
  type: 'image' | 'file' | 'video' | 'audio';
  size?: number;                    // File size in bytes
  downloaded: boolean;              // Download status
}
```

### PageMetadata

```typescript
interface PageMetadata {
  title: string;                    // Page title
  tags: string[];                   // Extracted tags
  createdTime: string;              // ISO timestamp
  lastEditedTime: string;           // ISO timestamp
  notionId: string;                 // Original Notion page ID
  url?: string;                     // Notion page URL
  properties?: Record<string, any>; // Notion page properties
}
```

### NotionPage

```typescript
interface NotionPage {
  id: string;                       // Notion page ID
  title: string;                    // Page title
  parent: any;                      // Parent object
  properties: any;                  // Page properties
  children?: NotionBlock[];         // Child blocks
  createdTime: string;              // ISO timestamp
  lastEditedTime: string;           // ISO timestamp
  url?: string;                     // Notion URL
}
```

### NotionBlock

```typescript
interface NotionBlock {
  id: string;                       // Block ID
  type: string;                     // Block type
  object: 'block';                  // Always 'block'
  created_time: string;             // ISO timestamp
  last_edited_time: string;         // ISO timestamp
  has_children: boolean;            // Has child blocks
  archived: boolean;                // Archived status
  [key: string]: any;               // Type-specific properties
}
```

## Examples

### Basic Import

```typescript
import { NotionObsidianImporter } from 'notion-obsidian-importer';

const importer = new NotionObsidianImporter({
  notion: {
    token: process.env.NOTION_TOKEN!
  },
  obsidian: {
    vaultPath: '/Users/john/Documents/MyVault'
  }
});

await importer.importWorkspace();
```

### Advanced Configuration

```typescript
const importer = new NotionObsidianImporter({
  notion: {
    token: process.env.NOTION_TOKEN!,
    rateLimitRequests: 5,
    rateLimitWindow: 2000
  },
  obsidian: {
    vaultPath: '/Users/john/Documents/MyVault',
    attachmentsFolder: 'Files',
    preserveStructure: true,
    convertImages: true,
    convertDatabases: true
  },
  batchSize: 20,
  concurrency: 5,
  retryAttempts: 5,
  progressTracking: true
});

// Track progress
importer.onProgress((progress) => {
  const percentage = (progress.processedPages / progress.totalPages) * 100;
  console.log(`${percentage.toFixed(1)}% - ${progress.currentOperation}`);
});

// Handle errors
importer.onError((error) => {
  if (error.retryable) {
    console.log(`Retryable error: ${error.message}`);
  } else {
    console.error(`Fatal error: ${error.message}`);
  }
});

await importer.importWorkspace();
```

### Selective Import

```typescript
// Import specific pages
const pageIds = ['page-1-id', 'page-2-id'];
await importer.importPages(pageIds);

// Import specific database
await importer.importDatabase('database-id');

// Import single page with result
const result = await importer.importPage('page-id');
console.log('Markdown:', result.markdown);
console.log('Attachments:', result.attachments.length);
console.log('Metadata:', result.metadata);
```

### Custom Progress UI

```typescript
class ProgressTracker {
  private startTime = Date.now();
  
  constructor(private importer: NotionObsidianImporter) {
    this.importer.onProgress(this.handleProgress.bind(this));
  }
  
  private handleProgress(progress: ProgressInfo) {
    const elapsed = Date.now() - this.startTime;
    const percentage = (progress.processedPages / progress.totalPages) * 100;
    
    console.clear();
    console.log('Notion → Obsidian Import');
    console.log('━'.repeat(50));
    console.log(`Progress: ${percentage.toFixed(1)}%`);
    console.log(`Pages: ${progress.processedPages}/${progress.totalPages}`);
    console.log(`Files: ${progress.downloadedFiles}/${progress.totalFiles}`);
    console.log(`Current: ${progress.currentOperation}`);
    console.log(`Elapsed: ${(elapsed / 1000).toFixed(1)}s`);
    
    if (progress.estimatedTimeRemaining) {
      console.log(`ETA: ${(progress.estimatedTimeRemaining / 1000).toFixed(1)}s`);
    }
    
    if (progress.errors.length > 0) {
      console.log(`Errors: ${progress.errors.length}`);
    }
  }
}

const tracker = new ProgressTracker(importer);
await importer.importWorkspace();
```

### Error Recovery

```typescript
class ErrorHandler {
  private retryQueue: string[] = [];
  
  constructor(private importer: NotionObsidianImporter) {
    this.importer.onError(this.handleError.bind(this));
  }
  
  private handleError(error: ImportError) {
    console.error(`Error: ${error.type} - ${error.message}`);
    
    if (error.retryable && error.pageId) {
      this.retryQueue.push(error.pageId);
    }
  }
  
  async retryFailedPages() {
    if (this.retryQueue.length === 0) return;
    
    console.log(`Retrying ${this.retryQueue.length} failed pages...`);
    
    const pagesToRetry = [...this.retryQueue];
    this.retryQueue = [];
    
    await this.importer.importPages(pagesToRetry);
  }
}

const errorHandler = new ErrorHandler(importer);
await importer.importWorkspace();
await errorHandler.retryFailedPages();
```

## Rate Limiting

The library automatically handles Notion's API rate limits:

```typescript
// Configure rate limiting
const importer = new NotionObsidianImporter({
  notion: {
    token: 'your-token',
    rateLimitRequests: 3,    // Max 3 requests
    rateLimitWindow: 1000    // Per 1 second
  },
  obsidian: {
    vaultPath: '/path/to/vault'
  }
});
```

Rate limiting is handled automatically with:
- Exponential backoff for retries
- Request queuing
- Intelligent batching
- Progress preservation during delays

## Testing

```typescript
// Test connection before importing
const isValid = await importer.validateConnection();
if (!isValid) {
  throw new Error('Invalid Notion token or insufficient permissions');
}

// Get workspace info
const workspaceInfo = await importer.getWorkspaceInfo();
console.log(`Found ${workspaceInfo.pageCount} pages in workspace`);
```

## Best Practices

1. **Always validate connection** before starting import
2. **Use progress tracking** for long-running imports
3. **Handle errors gracefully** with proper user feedback
4. **Configure rate limiting** appropriately for your use case
5. **Use selective import** for large workspaces
6. **Store tokens securely** and never commit them to version control
7. **Test with small datasets** before importing entire workspaces

## Performance Considerations

- **Concurrency**: Higher values may trigger rate limits
- **Batch Size**: Larger batches reduce API calls but increase memory usage
- **Media Downloads**: Disable if not needed to improve speed
- **Network**: Consider network latency when setting timeouts
- **Storage**: Ensure sufficient disk space for attachments

## Compatibility

- **Node.js**: 16.0.0 or higher
- **TypeScript**: 4.5.0 or higher
- **Notion API**: 2022-06-28 and later
- **Obsidian**: All versions (plugin requires 0.15.0+)