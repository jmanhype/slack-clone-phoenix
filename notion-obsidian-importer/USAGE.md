# Notion to Obsidian Importer - Usage Guide

## Installation

### As Obsidian Plugin

1. **Manual Installation:**
   ```bash
   # Clone and build the plugin
   git clone https://github.com/jmanhype/slack-clone-phoenix.git
   cd notion-obsidian-importer
   npm install
   npm run build
   
   # Copy to Obsidian plugins folder
   cp -r dist/* ~/.obsidian/plugins/notion-obsidian-importer/
   cp manifest.json ~/.obsidian/plugins/notion-obsidian-importer/
   ```

2. **Enable Plugin:**
   - Open Obsidian Settings → Community Plugins
   - Enable "Notion Obsidian Importer"

### CLI Installation

```bash
# Install globally
npm install -g notion-obsidian-importer

# Or use locally
npx notion-obsidian-importer
```

## Configuration

### Getting Notion API Token

1. **Create Notion Integration:**
   - Go to https://www.notion.so/my-integrations
   - Click "New Integration"
   - Name it (e.g., "Obsidian Importer")
   - Select workspace
   - Copy the Internal Integration Token

2. **Share Pages/Databases:**
   - Open each Notion page/database you want to import
   - Click "Share" → "Invite"
   - Select your integration
   - Click "Invite"

### Plugin Configuration

In Obsidian:
1. Go to Settings → Notion Obsidian Importer
2. Enter your Notion API token
3. Configure import settings:
   - Output folder (default: "Notion Import")
   - Download attachments (default: true)
   - Convert databases (default: true)
   - Keep hierarchy (default: true)
   - Auto-save progress (default: every 5 seconds)

## Usage

### Using the Obsidian Plugin

1. **Start Import:**
   - Open command palette (Cmd/Ctrl + P)
   - Run "Notion Importer: Start Import"
   - Select what to import:
     - All workspace content
     - Specific pages/databases
     - By URL

2. **Monitor Progress:**
   - Progress modal shows:
     - Items processed/total
     - Current item being imported
     - Estimated time remaining
     - Errors (if any)

3. **Resume Failed Import:**
   - Run "Notion Importer: Resume Last Import"
   - Continues from last checkpoint

### Using the CLI

#### Interactive Mode (Recommended)

```bash
notion-obsidian-importer

# Follow the prompts:
# 1. Enter Notion API token
# 2. Select workspace/pages
# 3. Choose output folder
# 4. Configure options
```

#### Command Line Arguments

```bash
# Basic import
notion-obsidian-importer \
  --token YOUR_NOTION_TOKEN \
  --output ./obsidian-vault

# Import specific page
notion-obsidian-importer \
  --token YOUR_NOTION_TOKEN \
  --page-id "abc123..." \
  --output ./obsidian-vault

# Import with all options
notion-obsidian-importer \
  --token YOUR_NOTION_TOKEN \
  --output ./obsidian-vault \
  --download-attachments \
  --convert-databases \
  --keep-hierarchy \
  --resume \
  --verbose
```

#### CLI Options

| Option | Description | Default |
|--------|-------------|---------|
| `--token` | Notion API token | Required |
| `--output` | Output directory | `./notion-import` |
| `--page-id` | Specific page ID to import | All pages |
| `--download-attachments` | Download images/files | `true` |
| `--convert-databases` | Convert databases to folders | `true` |
| `--keep-hierarchy` | Maintain page hierarchy | `true` |
| `--resume` | Resume from last checkpoint | `false` |
| `--verbose` | Show detailed logs | `false` |
| `--config` | Path to config file | None |

### Using as Library

```typescript
import { NotionObsidianImporter } from 'notion-obsidian-importer';

const importer = new NotionObsidianImporter({
  notion: {
    auth: 'YOUR_NOTION_TOKEN'
  },
  output: {
    directory: './my-vault',
    attachmentsFolder: 'attachments',
    databasesAsFolder: true,
    keepHierarchy: true
  }
});

// Start import
await importer.import();

// Listen to events
importer.on('progress', (data) => {
  console.log(`Progress: ${data.processed}/${data.total}`);
});

importer.on('error', (error) => {
  console.error('Import error:', error);
});

importer.on('complete', (stats) => {
  console.log('Import complete:', stats);
});
```

## Features

### Content Conversion

- **Rich Text:** Bold, italic, underline, strikethrough, code
- **Blocks:** Headings, paragraphs, lists, quotes, code blocks
- **Embeds:** Images, files, videos, bookmarks
- **Databases:** Full property support (21 types)
- **Relations:** Cross-references maintained
- **Formulas:** Converted to readable format
- **Mentions:** User/page mentions preserved

### Database Properties

Supported property types:
- Title, Text, Number, Select, Multi-select
- Date, Person, Files, Checkbox, URL
- Email, Phone, Formula, Relation, Rollup
- Created time, Created by, Last edited time, Last edited by
- Status, Unique ID, Verification

### Progressive Download

- Downloads in chunks to avoid timeouts
- Automatic resume on failure
- Progress saved every 5 seconds
- Rate limiting (3 requests/second)
- Retry with exponential backoff

### Error Handling

- Detailed error logs
- Automatic retry for transient errors
- Skip and continue for permanent errors
- Error report generated at end

## Examples

### Import Entire Workspace

```bash
# CLI
notion-obsidian-importer --token YOUR_TOKEN --output ~/Documents/Obsidian/MyVault

# Plugin
1. Open command palette
2. Run "Notion Importer: Import Workspace"
```

### Import Specific Database

```bash
# Get database ID from Notion URL:
# https://notion.so/workspace/Database-Name-{DATABASE_ID}

notion-obsidian-importer \
  --token YOUR_TOKEN \
  --page-id DATABASE_ID \
  --output ./vault \
  --convert-databases
```

### Resume Failed Import

```bash
# CLI - automatically detects checkpoint
notion-obsidian-importer \
  --token YOUR_TOKEN \
  --output ./vault \
  --resume

# Plugin
Run "Notion Importer: Resume Last Import"
```

### Batch Import Multiple Pages

```bash
# Create config file
cat > import-config.json << EOF
{
  "notion": {
    "auth": "YOUR_TOKEN"
  },
  "pages": [
    "page-id-1",
    "page-id-2",
    "page-id-3"
  ],
  "output": {
    "directory": "./vault"
  }
}
EOF

# Run with config
notion-obsidian-importer --config import-config.json
```

## Troubleshooting

### Common Issues

1. **"Invalid API Token"**
   - Verify token starts with `secret_`
   - Check integration has workspace access
   - Ensure pages are shared with integration

2. **"Page Not Found"**
   - Share the page with your integration
   - Check page ID is correct
   - Verify workspace access

3. **"Rate Limited"**
   - Importer automatically handles rate limits
   - Reduces to 1 request/second when limited
   - Wait and retry if persistent

4. **"Import Stopped Midway"**
   - Use `--resume` flag to continue
   - Check `.notion-import-progress.json` exists
   - Review error logs for issues

### Viewing Logs

```bash
# CLI logs location
./notion-obsidian-import.log

# Plugin logs
~/.obsidian/plugins/notion-obsidian-importer/logs/

# Verbose output
notion-obsidian-importer --verbose
```

### Getting Help

- **Documentation:** https://github.com/jmanhype/slack-clone-phoenix/tree/main/notion-obsidian-importer
- **Issues:** https://github.com/jmanhype/slack-clone-phoenix/issues
- **Discord:** Join Obsidian community

## Advanced Usage

### Custom Configuration

Create `.notion-importer.rc.json`:

```json
{
  "notion": {
    "auth": "YOUR_TOKEN",
    "version": "2022-06-28"
  },
  "output": {
    "directory": "./vault",
    "attachmentsFolder": "files",
    "databasesAsFolder": true,
    "keepHierarchy": true,
    "frontmatter": true,
    "useISO8601Dates": true
  },
  "processing": {
    "downloadAttachments": true,
    "maxConcurrent": 3,
    "retryAttempts": 3,
    "rateLimit": 3
  },
  "resume": {
    "enabled": true,
    "checkpointFile": ".import-progress.json",
    "autosaveInterval": 5000
  }
}
```

### Automation

```bash
# Cron job for regular sync
0 2 * * * /usr/local/bin/notion-obsidian-importer --config ~/.notion-importer.rc.json --resume

# GitHub Action example
- name: Sync Notion to Obsidian
  run: |
    npx notion-obsidian-importer \
      --token ${{ secrets.NOTION_TOKEN }} \
      --output ./vault \
      --resume
```

## Performance Tips

1. **Large Workspaces:**
   - Import databases separately
   - Use `--page-id` for specific sections
   - Enable resume for safety

2. **Slow Imports:**
   - Check network connection
   - Reduce concurrent requests
   - Import during off-peak hours

3. **Memory Issues:**
   - Import in smaller batches
   - Increase Node.js memory: `NODE_OPTIONS=--max-old-space-size=4096`
   - Clear cache between imports

## License

MIT - See LICENSE file for details