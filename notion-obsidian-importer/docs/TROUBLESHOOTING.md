# Troubleshooting Guide

This guide helps resolve common issues when using the Notion-Obsidian Importer.

## Table of Contents

- [Installation Issues](#installation-issues)
- [Authentication Problems](#authentication-problems)
- [Import Failures](#import-failures)
- [Performance Issues](#performance-issues)
- [File System Errors](#file-system-errors)
- [Network Problems](#network-problems)
- [Content Conversion Issues](#content-conversion-issues)
- [Plugin-Specific Issues](#plugin-specific-issues)
- [Getting Help](#getting-help)

## Installation Issues

### npm install fails

**Problem:** Package installation fails with permission errors

**Solution:**
```bash
# Use npm with --unsafe-perm flag
npm install -g notion-obsidian-importer --unsafe-perm

# Or use npx instead
npx notion-obsidian-importer

# For local installation
npm install notion-obsidian-importer --save
```

### Node.js version compatibility

**Problem:** "Unsupported Node.js version" error

**Solution:**
```bash
# Check your Node.js version
node --version

# Update to Node.js 16 or higher
# Using nvm (recommended)
nvm install 16
nvm use 16

# Or download from nodejs.org
```

### TypeScript compilation errors

**Problem:** TypeScript compilation fails during build

**Solution:**
```bash
# Ensure TypeScript is installed
npm install -g typescript

# Check TypeScript version (4.5+ required)
tsc --version

# Clear cache and reinstall
npm cache clean --force
rm -rf node_modules package-lock.json
npm install
```

## Authentication Problems

### Invalid Notion token

**Problem:** "Authentication failed" or "Invalid token" errors

**Symptoms:**
- `AUTHENTICATION` error type
- 401 Unauthorized responses
- "Token is invalid" messages

**Solution:**
1. **Verify token format**: Notion tokens start with `secret_`
```bash
# Correct format
export NOTION_TOKEN=secret_abcd1234...

# Incorrect (missing secret_ prefix)
export NOTION_TOKEN=abcd1234...
```

2. **Check integration setup**:
   - Go to [Notion Developers](https://www.notion.so/my-integrations)
   - Verify integration is active
   - Copy the "Internal Integration Token"

3. **Verify page access**:
   - Open the Notion page in browser
   - Click Share → Invite
   - Add your integration with read access

### Insufficient permissions

**Problem:** "Access denied" or "Page not found" errors

**Solution:**
1. **Share workspace with integration**:
   - Select top-level pages in your workspace
   - Share each page with your integration
   - Grant "Read" permission

2. **Check parent page access**:
   - If importing a sub-page, ensure parent pages are also shared
   - Integration needs access to entire page hierarchy

3. **Database permissions**:
```bash
# Test database access
notion-obsidian-importer test --token YOUR_TOKEN --database-id DATABASE_ID
```

### Token expiration

**Problem:** Token stops working after some time

**Solution:**
1. **Regenerate token**:
   - Go to integration settings
   - Click "Show token" → "Regenerate"
   - Update your configuration

2. **Check integration status**:
   - Ensure integration wasn't disabled
   - Verify workspace access hasn't changed

## Import Failures

### Large workspace timeouts

**Problem:** Import fails with timeout errors on large workspaces

**Symptoms:**
- Process hangs or times out
- Memory usage increases dramatically
- "Request timeout" errors

**Solution:**
1. **Reduce batch size**:
```json
{
  "batchSize": 5,
  "concurrency": 2,
  "retryAttempts": 5
}
```

2. **Import selectively**:
```bash
# Import specific pages instead of entire workspace
notion-obsidian-importer --pages page-id-1,page-id-2,page-id-3
```

3. **Use progressive import**:
```typescript
// Enable progress tracking
const importer = new NotionObsidianImporter({
  ...config,
  progressTracking: true
});

// Monitor and handle timeouts
importer.onError((error) => {
  if (error.type === 'NETWORK' && error.retryable) {
    console.log('Network timeout, will retry...');
  }
});
```

### Rate limiting issues

**Problem:** "Rate limit exceeded" errors

**Symptoms:**
- `RATE_LIMIT` error type
- 429 HTTP status codes
- Import slows down significantly

**Solution:**
1. **Adjust rate limiting**:
```json
{
  "notion": {
    "rateLimitRequests": 3,
    "rateLimitWindow": 2000
  }
}
```

2. **Reduce concurrency**:
```json
{
  "concurrency": 1,
  "batchSize": 5
}
```

3. **Add delays**:
```typescript
// Custom delay between batches
await new Promise(resolve => setTimeout(resolve, 1000));
```

### Partial import completion

**Problem:** Import stops partway through without completing

**Solution:**
1. **Check error logs**:
```bash
# Enable verbose logging
DEBUG=notion-obsidian-importer* notion-obsidian-importer
```

2. **Resume from checkpoint**:
```typescript
// Get progress info
importer.onProgress((progress) => {
  console.log(`Processed: ${progress.processedPages}/${progress.totalPages}`);
  // Save progress to file
  fs.writeFileSync('progress.json', JSON.stringify(progress));
});
```

3. **Import remaining pages**:
```bash
# Get list of imported pages
ls /path/to/vault/*.md | grep -o 'page-[a-z0-9-]*' > imported.txt

# Import remaining pages
notion-obsidian-importer --exclude-pages $(cat imported.txt)
```

## Performance Issues

### Slow import speed

**Problem:** Import takes much longer than expected

**Causes & Solutions:**

1. **Network latency**:
```json
{
  "retryAttempts": 3,
  "concurrency": 2
}
```

2. **Large media files**:
```json
{
  "obsidian": {
    "convertImages": false,
    "skipLargeFiles": true
  }
}
```

3. **System resources**:
```bash
# Monitor system resources
top -p $(pgrep node)

# Increase memory limit
NODE_OPTIONS="--max-old-space-size=4096" notion-obsidian-importer
```

### High memory usage

**Problem:** Process consumes excessive memory

**Solution:**
1. **Reduce batch size**:
```json
{
  "batchSize": 5,
  "concurrency": 1
}
```

2. **Enable streaming**:
```typescript
const importer = new NotionObsidianImporter({
  ...config,
  streamingMode: true,
  memoryLimit: '2GB'
});
```

3. **Clear cache periodically**:
```bash
# Clear npm cache
npm cache clean --force

# Clear temporary files
rm -rf /tmp/notion-*
```

## File System Errors

### Permission denied

**Problem:** Cannot write to Obsidian vault directory

**Symptoms:**
- "EACCES" or "Permission denied" errors
- Files not created in vault
- `FILE_SYSTEM` error type

**Solution:**
1. **Check directory permissions**:
```bash
# Check vault permissions
ls -la /path/to/obsidian/vault

# Fix permissions
chmod 755 /path/to/obsidian/vault
chmod -R 644 /path/to/obsidian/vault/*
```

2. **Run with appropriate permissions**:
```bash
# macOS/Linux
sudo notion-obsidian-importer

# Or change ownership
sudo chown -R $USER /path/to/obsidian/vault
```

3. **Use relative paths**:
```json
{
  "obsidian": {
    "vaultPath": "./MyVault",
    "attachmentsFolder": "attachments"
  }
}
```

### Disk space issues

**Problem:** "No space left on device" errors

**Solution:**
1. **Check available space**:
```bash
df -h /path/to/obsidian/vault
```

2. **Clean up disk space**:
```bash
# Remove old downloads
rm -rf ~/.notion-obsidian-importer/cache/*

# Clear system temp
rm -rf /tmp/notion-*
```

3. **Use external storage**:
```json
{
  "obsidian": {
    "vaultPath": "/external/drive/vault",
    "attachmentsFolder": "/external/drive/attachments"
  }
}
```

### File naming conflicts

**Problem:** Files with same name overwrite each other

**Solution:**
1. **Enable unique naming**:
```json
{
  "obsidian": {
    "uniqueFilenames": true,
    "filenamePattern": "{title}-{notionId}"
  }
}
```

2. **Use subdirectories**:
```json
{
  "obsidian": {
    "preserveStructure": true,
    "createSubfolders": true
  }
}
```

## Network Problems

### Connection timeouts

**Problem:** Frequent "Request timeout" errors

**Solution:**
1. **Increase timeout values**:
```json
{
  "network": {
    "timeout": 30000,
    "retryDelay": 2000
  }
}
```

2. **Test connectivity**:
```bash
# Test Notion API
curl -H "Authorization: Bearer YOUR_TOKEN" \
     https://api.notion.com/v1/users/me

# Test with notion-obsidian-importer
notion-obsidian-importer test --token YOUR_TOKEN
```

3. **Use proxy if needed**:
```json
{
  "network": {
    "proxy": "http://proxy.company.com:8080"
  }
}
```

### SSL/TLS errors

**Problem:** Certificate or SSL connection errors

**Solution:**
1. **Update certificates**:
```bash
# macOS
brew update && brew upgrade ca-certificates

# Ubuntu/Debian
sudo apt update && sudo apt upgrade ca-certificates
```

2. **Bypass SSL (not recommended for production)**:
```bash
NODE_TLS_REJECT_UNAUTHORIZED=0 notion-obsidian-importer
```

3. **Use custom certificates**:
```bash
export NODE_EXTRA_CA_CERTS=/path/to/certificate.pem
```

## Content Conversion Issues

### Markdown formatting problems

**Problem:** Content doesn't convert properly to Markdown

**Common Issues:**

1. **Complex tables**:
```json
{
  "conversion": {
    "tableFormat": "simple",
    "preserveTableStyling": false
  }
}
```

2. **Code blocks**:
```json
{
  "conversion": {
    "codeBlockLanguage": "auto",
    "preserveCodeFormatting": true
  }
}
```

3. **Mathematical expressions**:
```json
{
  "conversion": {
    "mathDelimiters": "obsidian",
    "convertLatex": true
  }
}
```

### Missing attachments

**Problem:** Images and files don't download or display

**Solution:**
1. **Check attachment settings**:
```json
{
  "obsidian": {
    "convertImages": true,
    "attachmentsFolder": "attachments",
    "downloadTimeout": 30000
  }
}
```

2. **Verify URL access**:
```bash
# Test image URL
curl -I "https://notion-image-url.com/image.png"
```

3. **Use alternative download**:
```typescript
importer.onError((error) => {
  if (error.type === 'NETWORK' && error.retryable) {
    // Implement custom download logic
    console.log('Retrying attachment download...');
  }
});
```

### Database conversion issues

**Problem:** Notion databases don't convert properly

**Solution:**
1. **Enable database conversion**:
```json
{
  "obsidian": {
    "convertDatabases": true,
    "databaseFormat": "table"
  }
}
```

2. **Handle complex properties**:
```json
{
  "conversion": {
    "databaseProperties": {
      "relation": "link",
      "rollup": "text",
      "formula": "value"
    }
  }
}
```

## Plugin-Specific Issues

### Plugin not loading in Obsidian

**Problem:** Plugin doesn't appear in Obsidian or fails to load

**Solution:**
1. **Check installation path**:
```bash
# Correct path structure
VaultFolder/.obsidian/plugins/notion-obsidian-importer/
├── main.js
├── manifest.json
└── styles.css
```

2. **Verify file permissions**:
```bash
chmod 644 VaultFolder/.obsidian/plugins/notion-obsidian-importer/*
```

3. **Check Obsidian logs**:
   - Open Developer Console (Ctrl+Shift+I)
   - Look for plugin loading errors
   - Check manifest.json validity

### Plugin crashes Obsidian

**Problem:** Obsidian becomes unresponsive when using plugin

**Solution:**
1. **Disable plugin**:
   - Start Obsidian in safe mode
   - Settings → Community Plugins → Disable plugin

2. **Check memory usage**:
```json
{
  "plugin": {
    "memoryLimit": "1GB",
    "processingChunkSize": 10
  }
}
```

3. **Update Obsidian**:
   - Ensure Obsidian is version 0.15.0 or higher
   - Update to latest version

## Getting Help

### Enable Debug Logging

```bash
# Enable all debug logs
DEBUG=* notion-obsidian-importer

# Enable specific module logs
DEBUG=notion-obsidian-importer:* notion-obsidian-importer

# Save logs to file
DEBUG=* notion-obsidian-importer 2>&1 | tee debug.log
```

### Collect System Information

```bash
# Create diagnostic report
notion-obsidian-importer diagnose > diagnostic-report.txt

# Include system info
echo "Node.js: $(node --version)" >> diagnostic-report.txt
echo "npm: $(npm --version)" >> diagnostic-report.txt
echo "OS: $(uname -a)" >> diagnostic-report.txt
```

### Common Commands for Troubleshooting

```bash
# Test connection
notion-obsidian-importer test --token YOUR_TOKEN

# Validate configuration
notion-obsidian-importer validate --config config.json

# Dry run (no actual import)
notion-obsidian-importer --dry-run

# Import with verbose output
notion-obsidian-importer --verbose

# Check workspace info
notion-obsidian-importer info --token YOUR_TOKEN
```

### Create Minimal Reproduction

When reporting issues, create a minimal test case:

```typescript
// minimal-test.js
const { NotionObsidianImporter } = require('notion-obsidian-importer');

const importer = new NotionObsidianImporter({
  notion: { token: 'your-token' },
  obsidian: { vaultPath: './test-vault' }
});

importer.importPage('specific-page-id')
  .then(() => console.log('Success'))
  .catch(console.error);
```

### Support Channels

1. **GitHub Issues**: [Report bugs and feature requests](https://github.com/notion-obsidian-importer/notion-obsidian-importer/issues)
2. **Discussions**: [Community help and questions](https://github.com/notion-obsidian-importer/notion-obsidian-importer/discussions)
3. **Documentation**: [Complete documentation](https://notion-obsidian-importer.com/docs)
4. **Email**: [Direct support](mailto:support@notion-obsidian-importer.com)

### Before Reporting Issues

Please include:
- Operating system and version
- Node.js version
- Package version
- Complete error message
- Configuration file (remove sensitive tokens)
- Steps to reproduce
- Expected vs actual behavior

### Quick Fixes Checklist

- [ ] Node.js 16+ installed
- [ ] Valid Notion token
- [ ] Pages shared with integration
- [ ] Sufficient disk space
- [ ] Correct vault path
- [ ] Network connectivity
- [ ] File permissions
- [ ] Latest package version
- [ ] Obsidian compatibility (plugin)
- [ ] Configuration validation