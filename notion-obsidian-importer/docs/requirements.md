# Notion-Obsidian Importer Requirements Specification

## Project Overview

This document outlines the technical requirements for developing a robust Notion API importer that enables direct synchronization between Notion workspaces and Obsidian vaults, specifically addressing GitHub issue #421. The importer will provide Database to Bases conversion capabilities and progressive download architecture for handling large datasets.

## 1. Notion API Authentication Requirements

### 1.1 Integration Setup
- **Internal Integration Token**: Support for OAuth 2.0 based authentication through Notion's developer portal
- **API Key Management**: Secure storage and handling of Internal Integration Tokens
- **Workspace Access**: Integration must be added to specific workspaces with appropriate permissions
- **Database Connections**: Individual database access requires explicit connection setup via "Add Connection" in database settings

### 1.2 Required Permissions
- **Read Data Capabilities**: Access to pages, databases, and blocks
- **Content Retrieval**: Ability to fetch page content, properties, and metadata
- **File Access**: Permission to download attached files and images
- **User Information**: Optional access to user email addresses for attribution

### 1.3 Rate Limiting Compliance
- **API Rate Limits**: Implement exponential backoff for 429 responses
- **Block Limits**: Respect 1000 block elements per request limit
- **Payload Size**: Stay within 500KB maximum payload size
- **Duplication Limits**: Respect 20,000 block duplications per hour across all users

## 2. Content Conversion Specifications

### 2.1 Database to Bases Conversion

#### 2.1.1 Property Type Mapping
| Notion Property | Obsidian Equivalent | Conversion Logic |
|----------------|-------------------|------------------|
| Title | YAML frontmatter `title` | Direct mapping |
| Rich Text | Markdown content | HTML to Markdown conversion |
| Number | YAML frontmatter numeric | Direct value preservation |
| Select | YAML frontmatter tags | Single tag conversion |
| Multi-Select | YAML frontmatter tags array | Multiple tags conversion |
| Date | YAML frontmatter date | ISO 8601 format |
| Checkbox | YAML frontmatter boolean | true/false conversion |
| URL | Markdown link | `[text](url)` format |
| Email | Markdown link | `[email](mailto:email)` format |
| Phone | YAML frontmatter | Direct text preservation |
| Files | Attachment links | Download and local reference |
| People | YAML frontmatter | User name/email extraction |
| Relation | Wiki links | `[[Page Name]]` format |
| Rollup | YAML frontmatter | Calculated value preservation |
| Formula | YAML frontmatter | Result value only |
| Created Time | YAML frontmatter | ISO 8601 timestamp |
| Last Edited | YAML frontmatter | ISO 8601 timestamp |

#### 2.1.2 Database Structure Conversion
- **Database → Base**: Create Obsidian Base with corresponding schema
- **Pages → Notes**: Each database page becomes an individual note
- **Views → Queries**: Convert database views to DataView queries where possible
- **Filters → Tags**: Transform database filters into tag-based organization

### 2.2 Block Type Conversion

#### 2.2.1 Text Blocks
- **Paragraph**: Direct Markdown conversion
- **Headings**: Convert to Markdown headers (H1-H6)
- **Bulleted List**: Unordered list conversion (`-` format)
- **Numbered List**: Ordered list conversion (`1.` format)
- **To-Do List**: Checkbox list conversion (`- [ ]` / `- [x]`)
- **Toggle**: Collapsible content using Obsidian callouts

#### 2.2.2 Media Blocks
- **Images**: Download and embed with `![[image.ext]]` syntax
- **Videos**: Download with fallback to external links
- **Audio**: Download with fallback to external links
- **Files**: Download all attachments to designated folder
- **PDF**: Download and link with `[[file.pdf]]` syntax

#### 2.2.3 Database Blocks
- **Table**: Convert to Markdown table format
- **Board**: Convert to structured notes with tags
- **Timeline**: Convert to chronological note structure
- **Calendar**: Convert to daily notes with date properties

#### 2.2.4 Advanced Blocks
- **Code Block**: Preserve with language specification
- **Equation**: Convert LaTeX to Obsidian math syntax
- **Callout**: Map to Obsidian callout syntax
- **Quote**: Convert to Markdown blockquote (`>`)
- **Divider**: Convert to Markdown horizontal rule (`---`)

### 2.3 Rich Text Formatting
- **Bold**: Convert to `**text**`
- **Italic**: Convert to `*text*`
- **Strikethrough**: Convert to `~~text~~`
- **Code**: Convert to `\`code\``
- **Links**: Convert to Markdown link format
- **Mentions**: Convert to wiki links `[[Page Name]]`
- **Colors**: Preserve using HTML spans or callouts

## 3. Image and Attachment Handling

### 3.1 File Download Strategy
- **Progressive Download**: Implement queue-based download system
- **Concurrent Limits**: Maximum 5 concurrent downloads
- **Retry Logic**: Exponential backoff for failed downloads
- **File Validation**: Verify file integrity after download

### 3.2 File Organization
```
vault/
├── attachments/
│   ├── notion-import-[timestamp]/
│   │   ├── images/
│   │   ├── documents/
│   │   └── media/
└── notes/
    └── notion-import-[timestamp]/
        ├── databases/
        └── pages/
```

### 3.3 File Naming Convention
- **Sanitization**: Remove special characters, limit length
- **Uniqueness**: Append UUID for duplicate names
- **Preservation**: Maintain original file extensions
- **Encoding**: Handle UTF-8 filenames properly

### 3.4 File Size Limits
- **Maximum Size**: 100MB per file (configurable)
- **Total Limit**: 1GB per import session (configurable)
- **Fallback**: External links for oversized files

## 4. Progressive Download Architecture

### 4.1 Import Phases
1. **Discovery Phase**: Enumerate all databases and pages
2. **Metadata Phase**: Collect all page properties and relationships
3. **Content Phase**: Download page content and embedded blocks
4. **Media Phase**: Download all attachments and images
5. **Relationship Phase**: Establish internal links and references

### 4.2 Progress Tracking
- **Session State**: Persistent import session management
- **Resume Capability**: Ability to resume interrupted imports
- **Progress Indicators**: Real-time progress reporting
- **Error Recovery**: Graceful handling of API failures

### 4.3 Memory Management
- **Streaming Processing**: Process large datasets without memory overflow
- **Batch Processing**: Handle content in configurable batch sizes
- **Garbage Collection**: Regular cleanup of temporary data
- **Cache Management**: Intelligent caching of API responses

### 4.4 Performance Optimization
- **Parallel Processing**: Concurrent API requests where possible
- **Request Deduplication**: Avoid duplicate API calls
- **Intelligent Pagination**: Optimize page size based on content
- **Compression**: Use compression for temporary storage

## 5. Technical Implementation Requirements

### 5.1 Architecture Patterns
- **Modular Design**: Separate concerns for API client, converters, and file handlers
- **Plugin System**: Extensible converter plugins for different content types
- **Error Boundaries**: Isolated error handling for each component
- **Configuration Management**: Flexible configuration system

### 5.2 Technology Stack
- **Language**: TypeScript for type safety and maintainability
- **HTTP Client**: Robust HTTP client with retry logic (e.g., axios)
- **File System**: Cross-platform file operations
- **Markdown Parser**: Unified markdown processing library
- **Testing Framework**: Comprehensive test coverage

### 5.3 Data Models
```typescript
interface NotionDatabase {
  id: string;
  title: string;
  properties: Record<string, PropertySchema>;
  pages: NotionPage[];
}

interface NotionPage {
  id: string;
  title: string;
  properties: Record<string, PropertyValue>;
  content: Block[];
  children?: NotionPage[];
}

interface ImportSession {
  id: string;
  status: 'pending' | 'in_progress' | 'completed' | 'failed';
  progress: ImportProgress;
  config: ImportConfig;
  errors: ImportError[];
}
```

## 6. Error Handling and Edge Cases

### 6.1 API Error Scenarios
- **Rate Limiting**: Implement exponential backoff with jitter
- **Authentication Failures**: Clear error messages and re-auth flow
- **Network Timeouts**: Configurable timeout values with retry
- **Malformed Responses**: Graceful degradation and error reporting

### 6.2 Content Edge Cases
- **Empty Databases**: Handle databases with no pages
- **Circular References**: Detect and prevent infinite loops
- **Large Content**: Handle pages with massive content blocks
- **Unicode Content**: Proper encoding handling for all languages
- **Deleted Content**: Handle references to deleted pages/databases

### 6.3 File System Edge Cases
- **Disk Space**: Monitor available space and fail gracefully
- **Permissions**: Handle read-only directories and permission errors
- **Path Length**: Handle OS-specific path length limitations
- **Reserved Names**: Avoid OS reserved filenames (CON, PRN, etc.)

### 6.4 Conversion Edge Cases
- **Invalid Markdown**: Sanitize content that breaks Markdown parsers
- **Conflicting Names**: Handle duplicate page names intelligently
- **Broken Links**: Identify and report broken internal references
- **Unsupported Content**: Graceful fallback for unsupported block types

## 7. Test Case Requirements

### 7.1 Unit Tests
- **API Client Tests**: Mock API responses and test error handling
- **Converter Tests**: Test all content type conversions
- **File Handler Tests**: Test file download and organization
- **Utility Tests**: Test helper functions and utilities

### 7.2 Integration Tests
- **End-to-End Import**: Complete import workflow testing
- **API Integration**: Test against Notion API sandbox
- **File System Integration**: Test across different operating systems
- **Error Scenario Testing**: Test various failure conditions

### 7.3 Performance Tests
- **Large Database Import**: Test with 10,000+ page databases
- **Concurrent Import**: Test multiple simultaneous imports
- **Memory Usage**: Monitor memory consumption during import
- **Network Resilience**: Test with unstable network conditions

### 7.4 User Acceptance Tests
- **Configuration Interface**: Test import configuration UI
- **Progress Monitoring**: Test progress reporting accuracy
- **Error Reporting**: Test error message clarity and actionability
- **Resume Functionality**: Test import resume after interruption

## 8. Configuration and Customization

### 8.1 Import Settings
```yaml
import:
  notion:
    api_key: "${NOTION_API_KEY}"
    workspace_id: "optional"
  output:
    vault_path: "./vault"
    attachment_folder: "attachments/notion-import"
    organize_by_database: true
  conversion:
    preserve_notion_ids: true
    convert_formulas: false
    download_attachments: true
    max_file_size: "100MB"
  performance:
    concurrent_requests: 5
    batch_size: 50
    retry_attempts: 3
    request_delay: 200
```

### 8.2 Conversion Options
- **Content Filtering**: Option to exclude specific content types
- **Property Mapping**: Custom property name mappings
- **Template Customization**: Custom note templates
- **Link Preferences**: Choose between wiki links or markdown links

### 8.3 Advanced Options
- **Incremental Sync**: Support for ongoing synchronization
- **Selective Import**: Import specific databases or pages only
- **Backup Integration**: Integration with vault backup systems
- **Plugin Compatibility**: Ensure compatibility with popular Obsidian plugins

## 9. Security and Privacy Considerations

### 9.1 Data Protection
- **Token Security**: Secure storage of API tokens
- **Local Processing**: All conversion happens locally
- **No Data Retention**: Clear temporary data after import
- **Audit Logging**: Optional logging of import activities

### 9.2 Compliance
- **GDPR Compliance**: Handle personal data appropriately
- **Data Minimization**: Only request necessary permissions
- **User Consent**: Clear user consent for data processing
- **Data Portability**: Enable easy data export/backup

## 10. Success Metrics

### 10.1 Functional Metrics
- **Content Accuracy**: 99%+ accurate content conversion
- **Property Preservation**: 100% property type support
- **Link Integrity**: 95%+ successful link conversion
- **File Success Rate**: 98%+ successful file downloads

### 10.2 Performance Metrics
- **Import Speed**: <1 second per page for typical content
- **Memory Usage**: <500MB peak usage for large imports
- **Error Rate**: <1% API request failure rate
- **Resume Success**: 100% successful resume after interruption

### 10.3 User Experience Metrics
- **Setup Time**: <5 minutes for first-time setup
- **Configuration Complexity**: Minimal required configuration
- **Error Clarity**: Clear, actionable error messages
- **Documentation Quality**: Comprehensive user documentation

## 11. Maintenance and Support

### 11.1 API Version Management
- **Version Compatibility**: Support for current and previous API versions
- **Deprecation Handling**: Graceful handling of deprecated endpoints
- **Feature Detection**: Dynamic feature detection based on API capabilities
- **Migration Path**: Clear migration path for API changes

### 11.2 Community Support
- **Documentation**: Comprehensive developer and user documentation
- **Issue Templates**: Structured issue reporting templates
- **Contribution Guidelines**: Clear guidelines for community contributions
- **Version Management**: Semantic versioning and release notes

This requirements specification provides a comprehensive foundation for developing a robust, reliable, and user-friendly Notion-Obsidian importer that addresses the specific needs outlined in GitHub issue #421.