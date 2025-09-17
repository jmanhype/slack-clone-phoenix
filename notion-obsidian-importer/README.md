# Notion-Obsidian Importer

[![NPM Version](https://img.shields.io/npm/v/notion-obsidian-importer)](https://www.npmjs.com/package/notion-obsidian-importer)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![TypeScript](https://img.shields.io/badge/%3C%2F%3E-TypeScript-%230074c1.svg)](http://www.typescriptlang.org/)
[![Tests](https://img.shields.io/github/workflow/status/notion-obsidian-importer/notion-obsidian-importer/Tests)](https://github.com/notion-obsidian-importer/notion-obsidian-importer/actions)

A robust TypeScript tool for importing Notion workspaces to Obsidian with progressive download, intelligent conversion, and comprehensive error handling.

## ✨ Features

- **🚀 Progressive Import**: Stream large workspaces with real-time progress tracking
- **🔄 Smart Conversion**: Intelligent Notion block to Markdown conversion
- **📊 Database Support**: Convert Notion databases to Obsidian-compatible formats
- **🖼️ Media Handling**: Download and organize images, files, and attachments
- **⚡ Performance**: Concurrent processing with rate limiting and retry logic
- **🛡️ Error Resilience**: Comprehensive error handling and recovery
- **🎯 CLI & Plugin**: Use as command-line tool or Obsidian plugin
- **🔧 Configurable**: Extensive configuration options for customization

## 📦 Installation

### As a Command-Line Tool

```bash
# Install globally
npm install -g notion-obsidian-importer

# Or run directly with npx
npx notion-obsidian-importer
```

### As an Obsidian Plugin

1. Download the latest release from [Releases](https://github.com/notion-obsidian-importer/notion-obsidian-importer/releases)
2. Extract to your Obsidian plugins folder: `VaultFolder/.obsidian/plugins/notion-obsidian-importer/`
3. Enable the plugin in Obsidian Settings > Community Plugins

### As a Library

```bash
npm install notion-obsidian-importer
```

## 🚀 Quick Start

### Command Line Usage

```bash
# Interactive setup wizard
notion-obsidian-importer

# Direct import with options
notion-obsidian-importer --token YOUR_NOTION_TOKEN --vault-path /path/to/obsidian/vault
```

### Configuration File

Create a `notion-importer.config.json` file:

```json
{
  "notion": {
    "token": "your-notion-integration-token",
    "rateLimitRequests": 3,
    "rateLimitWindow": 1000
  },
  "obsidian": {
    "vaultPath": "/path/to/your/obsidian/vault",
    "attachmentsFolder": "attachments",
    "preserveStructure": true,
    "convertImages": true,
    "convertDatabases": true
  },
  "batchSize": 10,
  "concurrency": 3,
  "retryAttempts": 3,
  "progressTracking": true
}
```

### Programmatic Usage

```typescript
import { NotionObsidianImporter } from 'notion-obsidian-importer';

const importer = new NotionObsidianImporter({
  notion: {
    token: 'your-notion-integration-token'
  },
  obsidian: {
    vaultPath: '/path/to/obsidian/vault'
  }
});

// Import entire workspace
await importer.importWorkspace();

// Import specific pages
await importer.importPages(['page-id-1', 'page-id-2']);

// Import with progress tracking
importer.onProgress((progress) => {
  console.log(`Progress: ${progress.processedPages}/${progress.totalPages}`);
});
```

## 📋 Prerequisites

### Notion Setup

1. **Create a Notion Integration**:
   - Go to [Notion Developers](https://www.notion.so/my-integrations)
   - Click "New integration"
   - Name your integration and select your workspace
   - Copy the "Internal Integration Token"

2. **Share Pages with Integration**:
   - Open the Notion page you want to import
   - Click "Share" → "Invite"
   - Select your integration and grant access

### Obsidian Setup

- Ensure Obsidian is installed and you have a vault created
- Note the full path to your vault folder

## 🎯 CLI Commands

```bash
# Show help
notion-obsidian-importer --help

# Interactive wizard
notion-obsidian-importer wizard

# Import with specific configuration
notion-obsidian-importer import \
  --config ./config.json \
  --token YOUR_TOKEN \
  --vault-path /path/to/vault

# Import specific pages
notion-obsidian-importer import \
  --pages page-id-1,page-id-2 \
  --token YOUR_TOKEN \
  --vault-path /path/to/vault

# Test connection
notion-obsidian-importer test \
  --token YOUR_TOKEN

# Validate configuration
notion-obsidian-importer validate \
  --config ./config.json
```

## 📊 Progress Tracking

The importer provides real-time progress information:

```typescript
importer.onProgress((progress) => {
  console.log({
    totalPages: progress.totalPages,
    processed: progress.processedPages,
    percentage: (progress.processedPages / progress.totalPages) * 100,
    currentOperation: progress.currentOperation,
    estimatedTimeRemaining: progress.estimatedTimeRemaining,
    errors: progress.errors.length
  });
});
```

## 🔧 Configuration Options

See [Configuration Guide](./docs/CONFIGURATION.md) for detailed configuration options.

## 🐛 Troubleshooting

Common issues and solutions are documented in the [Troubleshooting Guide](./docs/TROUBLESHOOTING.md).

## 📚 API Documentation

For developers integrating this tool, see the [API Documentation](./docs/API.md).

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](./CONTRIBUTING.md) for details.

## 📝 Examples

Check out the [examples directory](./examples/) for practical usage examples and tutorials.

## 🔄 Migration from Other Tools

### From Notion2Obsidian

```bash
# Convert existing configuration
notion-obsidian-importer migrate \
  --from notion2obsidian \
  --config ./notion2obsidian-config.json
```

## 🚨 Rate Limiting

The tool respects Notion's API rate limits:

- Default: 3 requests per second
- Automatic retry with exponential backoff
- Configurable rate limiting parameters

## 📈 Performance Tips

1. **Optimize Concurrency**: Adjust `concurrency` based on your network and system
2. **Batch Processing**: Use appropriate `batchSize` for your workspace size
3. **Selective Import**: Import specific pages instead of entire workspace when possible
4. **Media Settings**: Disable image conversion if not needed to speed up import

## 🔒 Security

- Tokens are never logged or stored permanently
- All network requests use HTTPS
- Local files are created with restricted permissions
- Configuration files should be kept secure

## 📋 Supported Notion Blocks

- ✅ Text blocks (paragraph, heading, quote, etc.)
- ✅ Lists (bulleted, numbered, toggle)
- ✅ Media (images, videos, files)
- ✅ Embeds (YouTube, Twitter, etc.)
- ✅ Tables and databases
- ✅ Code blocks
- ✅ Callouts and dividers
- ✅ Link previews
- ✅ Mathematical expressions

## 🗺️ Roadmap

- [ ] Real-time sync capabilities
- [ ] Bi-directional synchronization
- [ ] Advanced template system
- [ ] Plugin marketplace integration
- [ ] Enhanced database query support

## 📄 License

MIT License - see [LICENSE](./LICENSE) file for details.

## 🙏 Acknowledgments

- [Notion API](https://developers.notion.com/) for the excellent API
- [Obsidian](https://obsidian.md/) for the amazing note-taking platform
- [Turndown](https://github.com/domchristie/turndown) for HTML to Markdown conversion

## 📞 Support

- 📖 [Documentation](./docs/)
- 🐛 [Issue Tracker](https://github.com/notion-obsidian-importer/notion-obsidian-importer/issues)
- 💬 [Discussions](https://github.com/notion-obsidian-importer/notion-obsidian-importer/discussions)
- 📧 [Email Support](mailto:support@notion-obsidian-importer.com)

---

**Made with ❤️ for the knowledge management community**