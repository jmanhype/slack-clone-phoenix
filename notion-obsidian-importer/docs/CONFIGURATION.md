# Configuration Guide

This guide covers all configuration options for the Notion-Obsidian Importer.

## Table of Contents

- [Configuration Methods](#configuration-methods)
- [Core Configuration](#core-configuration)
- [Notion Settings](#notion-settings)
- [Obsidian Settings](#obsidian-settings)
- [Performance Settings](#performance-settings)
- [Conversion Options](#conversion-options)
- [Network Configuration](#network-configuration)
- [Plugin Configuration](#plugin-configuration)
- [Environment Variables](#environment-variables)
- [Advanced Configuration](#advanced-configuration)

## Configuration Methods

### 1. Configuration File

Create a `notion-importer.config.json` file in your project root:

```json
{
  "notion": {
    "token": "secret_your_notion_token_here"
  },
  "obsidian": {
    "vaultPath": "/path/to/your/obsidian/vault"
  }
}
```

### 2. Command Line Arguments

```bash
notion-obsidian-importer \
  --token "secret_your_token" \
  --vault-path "/path/to/vault" \
  --batch-size 10 \
  --concurrency 3
```

### 3. Environment Variables

```bash
export NOTION_TOKEN="secret_your_token"
export OBSIDIAN_VAULT_PATH="/path/to/vault"
export NOTION_IMPORTER_BATCH_SIZE=10
```

### 4. Programmatic Configuration

```typescript
import { NotionObsidianImporter } from 'notion-obsidian-importer';

const importer = new NotionObsidianImporter({
  notion: { token: process.env.NOTION_TOKEN! },
  obsidian: { vaultPath: process.env.OBSIDIAN_VAULT_PATH! }
});
```

## Core Configuration

### ImportConfig Interface

```typescript
interface ImportConfig {
  notion: NotionConfig;           // Required: Notion API settings
  obsidian: ObsidianConfig;       // Required: Obsidian vault settings
  batchSize?: number;             // Optional: Batch processing size
  concurrency?: number;           // Optional: Concurrent operations
  retryAttempts?: number;         // Optional: Retry failed operations
  progressTracking?: boolean;     // Optional: Enable progress tracking
}
```

### Example Complete Configuration

```json
{
  "notion": {
    "token": "secret_your_notion_integration_token",
    "version": "2022-06-28",
    "baseUrl": "https://api.notion.com/v1",
    "rateLimitRequests": 3,
    "rateLimitWindow": 1000
  },
  "obsidian": {
    "vaultPath": "/Users/john/Documents/MyVault",
    "attachmentsFolder": "attachments",
    "templateFolder": "templates",
    "preserveStructure": true,
    "convertImages": true,
    "convertDatabases": true
  },
  "batchSize": 20,
  "concurrency": 5,
  "retryAttempts": 3,
  "progressTracking": true,
  "conversion": {
    "tableFormat": "obsidian",
    "codeBlockLanguage": "auto",
    "mathDelimiters": "obsidian"
  },
  "network": {
    "timeout": 30000,
    "retryDelay": 1000,
    "maxRetries": 3
  }
}
```

## Notion Settings

### NotionConfig Interface

```typescript
interface NotionConfig {
  token: string;                    // Required: Integration token
  version?: string;                 // API version (default: "2022-06-28")
  baseUrl?: string;                 // Custom API base URL
  rateLimitRequests?: number;       // Requests per window (default: 3)
  rateLimitWindow?: number;         // Window duration in ms (default: 1000)
}
```

### Token Configuration

```json
{
  "notion": {
    "token": "secret_abc123...",
    "version": "2022-06-28"
  }
}
```

**Token Sources (priority order):**
1. Configuration file `notion.token`
2. Command line `--token`
3. Environment variable `NOTION_TOKEN`
4. Environment variable `NOTION_API_TOKEN`

### Rate Limiting

```json
{
  "notion": {
    "rateLimitRequests": 3,      // Max requests per window
    "rateLimitWindow": 1000      // Window duration (ms)
  }
}
```

**Rate Limit Presets:**
```json
{
  "conservative": { "rateLimitRequests": 2, "rateLimitWindow": 1500 },
  "normal": { "rateLimitRequests": 3, "rateLimitWindow": 1000 },
  "aggressive": { "rateLimitRequests": 5, "rateLimitWindow": 1000 }
}
```

### API Configuration

```json
{
  "notion": {
    "baseUrl": "https://api.notion.com/v1",
    "version": "2022-06-28",
    "timeout": 30000,
    "userAgent": "NotionObsidianImporter/1.0.0"
  }
}
```

## Obsidian Settings

### ObsidianConfig Interface

```typescript
interface ObsidianConfig {
  vaultPath: string;                // Required: Path to Obsidian vault
  attachmentsFolder?: string;       // Attachments folder (default: "attachments")
  templateFolder?: string;          // Templates folder
  preserveStructure?: boolean;      // Keep Notion hierarchy (default: true)
  convertImages?: boolean;          // Download images (default: true)
  convertDatabases?: boolean;       // Convert databases (default: true)
}
```

### Vault Path Configuration

```json
{
  "obsidian": {
    "vaultPath": "/Users/john/Documents/MyVault"
  }
}
```

**Path Types:**
- **Absolute**: `/Users/john/Documents/MyVault`
- **Relative**: `./MyVault` (relative to current directory)
- **Home**: `~/Documents/MyVault` (expands to home directory)

### File Organization

```json
{
  "obsidian": {
    "attachmentsFolder": "Files",
    "templateFolder": "Templates",
    "preserveStructure": true,
    "createSubfolders": true,
    "filenamePattern": "{title}-{date}",
    "uniqueFilenames": true
  }
}
```

**Filename Patterns:**
- `{title}` - Page title
- `{date}` - Creation date (YYYY-MM-DD)
- `{time}` - Creation time (HH-MM-SS)
- `{notionId}` - Notion page ID
- `{uuid}` - Random UUID

### Media Handling

```json
{
  "obsidian": {
    "convertImages": true,
    "convertVideos": true,
    "convertAudio": true,
    "downloadFiles": true,
    "maxFileSize": 50000000,        // 50MB limit
    "imageFormats": ["png", "jpg", "jpeg", "gif", "webp"],
    "skipExternalMedia": false
  }
}
```

### Database Conversion

```json
{
  "obsidian": {
    "convertDatabases": true,
    "databaseFormat": "table",      // "table" | "list" | "cards"
    "includeProperties": true,
    "propertyPrefix": "notion-",
    "createIndexFiles": true
  }
}
```

## Performance Settings

### Concurrency and Batching

```json
{
  "batchSize": 20,                 // Pages per batch (1-100)
  "concurrency": 5,                // Concurrent operations (1-10)
  "retryAttempts": 3,              // Max retry attempts (0-10)
  "progressTracking": true         // Enable progress tracking
}
```

**Performance Presets:**
```json
{
  "fast": {
    "batchSize": 50,
    "concurrency": 8,
    "retryAttempts": 2
  },
  "balanced": {
    "batchSize": 20,
    "concurrency": 5,
    "retryAttempts": 3
  },
  "safe": {
    "batchSize": 10,
    "concurrency": 2,
    "retryAttempts": 5
  }
}
```

### Memory Management

```json
{
  "memory": {
    "maxMemoryUsage": "2GB",       // Memory limit
    "cacheSize": 1000,             // Cache size (pages)
    "streamingMode": true,         // Enable streaming
    "garbageCollection": true      // Force GC between batches
  }
}
```

### Timeout Configuration

```json
{
  "timeouts": {
    "pageRequest": 30000,          // Page request timeout (ms)
    "fileDownload": 60000,         // File download timeout (ms)
    "batchProcess": 300000,        // Batch processing timeout (ms)
    "totalImport": 3600000         // Total import timeout (ms)
  }
}
```

## Conversion Options

### Content Conversion

```json
{
  "conversion": {
    "tableFormat": "obsidian",     // "obsidian" | "github" | "simple"
    "codeBlockLanguage": "auto",   // "auto" | "none" | specific language
    "mathDelimiters": "obsidian",  // "obsidian" | "latex" | "inline"
    "preserveFormatting": true,
    "convertCallouts": true,
    "convertToggles": "details"    // "details" | "heading" | "ignore"
  }
}
```

### Markdown Options

```json
{
  "markdown": {
    "headingStyle": "atx",         // "atx" (#) | "setext" (underline)
    "codeBlockStyle": "fenced",    // "fenced" (```) | "indented"
    "linkStyle": "referenced",     // "referenced" | "inline"
    "emphasisStyle": "asterisk",   // "asterisk" (*) | "underscore" (_)
    "bulletListMarker": "-",       // "-" | "*" | "+"
    "orderedListMarker": "."       // "." | ")"
  }
}
```

### Frontmatter Configuration

```json
{
  "frontmatter": {
    "enabled": true,
    "format": "yaml",              // "yaml" | "json"
    "includeCreated": true,
    "includeModified": true,
    "includeTags": true,
    "includeNotionId": true,
    "includeUrl": true,
    "customFields": {
      "author": "{{notion.created_by}}",
      "status": "{{notion.status}}"
    }
  }
}
```

## Network Configuration

### Connection Settings

```json
{
  "network": {
    "timeout": 30000,              // Request timeout (ms)
    "retryDelay": 1000,            // Delay between retries (ms)
    "maxRetries": 3,               // Max retry attempts
    "keepAlive": true,             // Use HTTP keep-alive
    "maxConnections": 10           // Max concurrent connections
  }
}
```

### Proxy Configuration

```json
{
  "network": {
    "proxy": {
      "host": "proxy.company.com",
      "port": 8080,
      "auth": {
        "username": "user",
        "password": "pass"
      }
    }
  }
}
```

### SSL/TLS Settings

```json
{
  "network": {
    "ssl": {
      "rejectUnauthorized": true,
      "ca": "/path/to/ca-cert.pem",
      "cert": "/path/to/client-cert.pem",
      "key": "/path/to/client-key.pem"
    }
  }
}
```

## Plugin Configuration

### Obsidian Plugin Settings

```json
{
  "plugin": {
    "autoStart": false,            // Auto-start on Obsidian launch
    "showProgress": true,          // Show progress modal
    "notifications": true,         // Show completion notifications
    "hotkey": "Ctrl+Shift+I",     // Keyboard shortcut
    "ribbonIcon": true,            // Show ribbon icon
    "statusBar": true              // Show status bar item
  }
}
```

### UI Configuration

```json
{
  "ui": {
    "theme": "auto",               // "light" | "dark" | "auto"
    "progressModal": {
      "width": 600,
      "height": 400,
      "closable": false
    },
    "settingsTab": {
      "position": "community",     // Plugin settings location
      "categories": ["basic", "advanced", "conversion"]
    }
  }
}
```

## Environment Variables

### Variable Reference

| Variable | Description | Default |
|----------|-------------|---------|
| `NOTION_TOKEN` | Notion integration token | Required |
| `OBSIDIAN_VAULT_PATH` | Path to Obsidian vault | Required |
| `NOTION_IMPORTER_BATCH_SIZE` | Batch processing size | 20 |
| `NOTION_IMPORTER_CONCURRENCY` | Concurrent operations | 5 |
| `NOTION_IMPORTER_RETRY_ATTEMPTS` | Retry attempts | 3 |
| `NOTION_IMPORTER_PROGRESS` | Enable progress tracking | true |
| `NOTION_IMPORTER_DEBUG` | Enable debug logging | false |
| `NOTION_IMPORTER_CONFIG` | Configuration file path | notion-importer.config.json |

### Environment File (.env)

```bash
# Notion API Configuration
NOTION_TOKEN=secret_your_notion_integration_token
NOTION_API_VERSION=2022-06-28

# Obsidian Configuration
OBSIDIAN_VAULT_PATH=/Users/john/Documents/MyVault
OBSIDIAN_ATTACHMENTS_FOLDER=attachments

# Performance Settings
NOTION_IMPORTER_BATCH_SIZE=20
NOTION_IMPORTER_CONCURRENCY=5
NOTION_IMPORTER_RETRY_ATTEMPTS=3

# Feature Flags
NOTION_IMPORTER_CONVERT_IMAGES=true
NOTION_IMPORTER_CONVERT_DATABASES=true
NOTION_IMPORTER_PRESERVE_STRUCTURE=true

# Debugging
NOTION_IMPORTER_DEBUG=false
NOTION_IMPORTER_VERBOSE=false
DEBUG=notion-obsidian-importer:*
```

## Advanced Configuration

### Custom Converters

```json
{
  "converters": {
    "custom": {
      "equation": "katex",
      "embed": "iframe",
      "database": "dataview"
    },
    "plugins": [
      "./converters/custom-notion-block.js",
      "./converters/enhanced-tables.js"
    ]
  }
}
```

### Hooks and Events

```json
{
  "hooks": {
    "beforeImport": "./hooks/pre-import.js",
    "afterPage": "./hooks/post-page.js",
    "afterImport": "./hooks/post-import.js",
    "onError": "./hooks/error-handler.js"
  }
}
```

### Filtering and Selection

```json
{
  "filters": {
    "includePages": ["page-id-1", "page-id-2"],
    "excludePages": ["draft-*", "temp-*"],
    "includeDatabases": ["tasks", "notes"],
    "dateRange": {
      "start": "2023-01-01",
      "end": "2023-12-31"
    },
    "properties": {
      "status": ["Published", "In Review"]
    }
  }
}
```

### Validation Rules

```json
{
  "validation": {
    "strictMode": false,           // Strict validation
    "allowEmptyPages": true,       // Import empty pages
    "validateUrls": true,          // Validate external URLs
    "checkDuplicates": true,       // Check for duplicate content
    "maxFileSize": 100000000,      // Max file size (100MB)
    "allowedMimeTypes": [
      "image/*",
      "text/*",
      "application/pdf"
    ]
  }
}
```

### Logging Configuration

```json
{
  "logging": {
    "level": "info",               // "error" | "warn" | "info" | "debug"
    "file": "./logs/import.log",   // Log file path
    "maxSize": "10MB",             // Max log file size
    "maxFiles": 5,                 // Max log files to keep
    "format": "json",              // "json" | "text"
    "timestamp": true,             // Include timestamps
    "colorize": true               // Colorize console output
  }
}
```

## Configuration Validation

### Validate Configuration

```bash
# Validate configuration file
notion-obsidian-importer validate --config ./config.json

# Validate environment
notion-obsidian-importer validate --env

# Test connection
notion-obsidian-importer test --token YOUR_TOKEN
```

### Schema Validation

```typescript
import { validateConfig } from 'notion-obsidian-importer';

const config = {
  notion: { token: 'secret_...' },
  obsidian: { vaultPath: '/path/to/vault' }
};

const validation = validateConfig(config);
if (!validation.valid) {
  console.error('Configuration errors:', validation.errors);
}
```

## Configuration Examples

### Minimal Configuration

```json
{
  "notion": {
    "token": "secret_your_token"
  },
  "obsidian": {
    "vaultPath": "/path/to/vault"
  }
}
```

### Performance-Optimized Configuration

```json
{
  "notion": {
    "token": "secret_your_token",
    "rateLimitRequests": 5,
    "rateLimitWindow": 800
  },
  "obsidian": {
    "vaultPath": "/path/to/vault",
    "convertImages": false,
    "preserveStructure": false
  },
  "batchSize": 50,
  "concurrency": 8,
  "retryAttempts": 2,
  "memory": {
    "streamingMode": true,
    "maxMemoryUsage": "4GB"
  }
}
```

### Complete Feature Configuration

```json
{
  "notion": {
    "token": "secret_your_token",
    "version": "2022-06-28",
    "rateLimitRequests": 3,
    "rateLimitWindow": 1000
  },
  "obsidian": {
    "vaultPath": "/Users/john/Documents/MyVault",
    "attachmentsFolder": "Files",
    "templateFolder": "Templates",
    "preserveStructure": true,
    "convertImages": true,
    "convertDatabases": true,
    "filenamePattern": "{title}-{date}",
    "uniqueFilenames": true
  },
  "batchSize": 20,
  "concurrency": 5,
  "retryAttempts": 3,
  "progressTracking": true,
  "conversion": {
    "tableFormat": "obsidian",
    "codeBlockLanguage": "auto",
    "mathDelimiters": "obsidian",
    "convertCallouts": true,
    "convertToggles": "details"
  },
  "frontmatter": {
    "enabled": true,
    "format": "yaml",
    "includeCreated": true,
    "includeModified": true,
    "includeTags": true,
    "includeNotionId": true
  },
  "network": {
    "timeout": 30000,
    "retryDelay": 1000,
    "maxRetries": 3
  },
  "logging": {
    "level": "info",
    "file": "./logs/import.log",
    "format": "json"
  }
}
```