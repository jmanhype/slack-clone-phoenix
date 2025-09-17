# Contributing to Notion-Obsidian Importer

Thank you for your interest in contributing to the Notion-Obsidian Importer! This document provides guidelines and information for contributors.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Contributing Guidelines](#contributing-guidelines)
- [Pull Request Process](#pull-request-process)
- [Issue Guidelines](#issue-guidelines)
- [Development Workflow](#development-workflow)
- [Testing](#testing)
- [Documentation](#documentation)
- [Release Process](#release-process)

## Code of Conduct

This project adheres to a Code of Conduct that we expect all contributors to follow:

- **Be Respectful**: Treat everyone with respect and kindness
- **Be Inclusive**: Welcome newcomers and help them learn
- **Be Collaborative**: Work together to solve problems
- **Be Patient**: Help others understand and learn
- **Be Constructive**: Provide helpful feedback and suggestions

## Getting Started

### Prerequisites

- Node.js 16.0.0 or higher
- npm 7.0.0 or higher
- Git
- Notion account with integration access
- Obsidian (for testing plugin functionality)

### Fork and Clone

1. Fork the repository on GitHub
2. Clone your fork locally:

```bash
git clone https://github.com/your-username/notion-obsidian-importer.git
cd notion-obsidian-importer
```

3. Add the upstream repository:

```bash
git remote add upstream https://github.com/notion-obsidian-importer/notion-obsidian-importer.git
```

## Development Setup

### Install Dependencies

```bash
npm install
```

### Environment Configuration

1. Copy the example environment file:

```bash
cp .env.example .env
```

2. Configure your environment variables:

```bash
# .env
NOTION_TOKEN=secret_your_test_integration_token
OBSIDIAN_VAULT_PATH=/path/to/test/vault
DEBUG=notion-obsidian-importer:*
```

### Build the Project

```bash
# TypeScript compilation
npm run build

# Build plugin
npm run build:plugin

# Development build with watch
npm run dev
```

### Run Tests

```bash
# Run all tests
npm test

# Run tests in watch mode
npm run test:watch

# Run tests with coverage
npm run test:coverage
```

## Contributing Guidelines

### Types of Contributions

We welcome various types of contributions:

- **Bug fixes**: Fix existing issues
- **Features**: Add new functionality
- **Documentation**: Improve docs and examples
- **Tests**: Add or improve test coverage
- **Performance**: Optimize existing code
- **Refactoring**: Improve code structure

### Contribution Workflow

1. **Check existing issues**: Look for related issues or discussions
2. **Create an issue**: If none exists, create one to discuss your idea
3. **Fork and branch**: Create a feature branch for your work
4. **Develop**: Write code following our standards
5. **Test**: Ensure all tests pass and add new tests
6. **Document**: Update documentation as needed
7. **Submit**: Create a pull request

### Branch Naming

Use descriptive branch names:

```bash
# Features
git checkout -b feature/database-conversion-improvements

# Bug fixes
git checkout -b fix/rate-limiting-issue

# Documentation
git checkout -b docs/api-documentation

# Refactoring
git checkout -b refactor/converter-architecture
```

## Pull Request Process

### Before Submitting

1. **Sync with upstream**:

```bash
git checkout main
git fetch upstream
git merge upstream/main
git push origin main
```

2. **Rebase your branch**:

```bash
git checkout your-feature-branch
git rebase main
```

3. **Run quality checks**:

```bash
npm run lint
npm run test
npm run build
```

### Pull Request Template

When creating a pull request, include:

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Manual testing completed

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] Tests added/updated
```

### Review Process

1. **Automated checks**: Ensure all CI checks pass
2. **Code review**: Maintainers will review your code
3. **Feedback**: Address any requested changes
4. **Approval**: Once approved, your PR will be merged

## Issue Guidelines

### Bug Reports

Use the bug report template:

```markdown
**Describe the bug**
Clear description of the issue

**To Reproduce**
Steps to reproduce the behavior:
1. Configure with '...'
2. Run command '...'
3. See error

**Expected behavior**
What you expected to happen

**Screenshots/Logs**
If applicable, add screenshots or error logs

**Environment:**
- OS: [e.g. macOS 12.0]
- Node.js: [e.g. 18.0.0]
- Package version: [e.g. 1.0.0]

**Additional context**
Any other context about the problem
```

### Feature Requests

Use the feature request template:

```markdown
**Is your feature request related to a problem?**
Clear description of the problem

**Describe the solution you'd like**
Clear description of what you want to happen

**Describe alternatives considered**
Other solutions you've considered

**Additional context**
Screenshots, mockups, or other context
```

## Development Workflow

### Project Structure

```
notion-obsidian-importer/
├── src/                    # Source code
│   ├── api/               # Notion API client
│   ├── cli/               # Command-line interface
│   ├── converters/        # Content converters
│   ├── plugin/            # Obsidian plugin
│   ├── types/             # TypeScript types
│   └── utils/             # Utility functions
├── tests/                 # Test files
│   ├── unit/              # Unit tests
│   ├── integration/       # Integration tests
│   └── fixtures/          # Test data
├── docs/                  # Documentation
├── examples/              # Usage examples
└── config/                # Configuration files
```

### Code Style

We use ESLint and Prettier for code formatting:

```bash
# Lint code
npm run lint

# Fix linting issues
npm run lint:fix

# Format code
npm run format
```

### TypeScript Guidelines

- Use strict TypeScript configuration
- Define interfaces for all data structures
- Use proper type annotations
- Avoid `any` type when possible
- Document public APIs with JSDoc

```typescript
/**
 * Converts a Notion page to Markdown format
 * @param page - The Notion page to convert
 * @param options - Conversion options
 * @returns Promise containing the conversion result
 */
async function convertPage(
  page: NotionPage,
  options: ConversionOptions
): Promise<ConversionResult> {
  // Implementation
}
```

### Error Handling

Use proper error handling patterns:

```typescript
// Good: Specific error types
throw new NotionApiError('Rate limit exceeded', {
  type: 'RATE_LIMIT',
  retryable: true,
  retryAfter: 1000
});

// Good: Error wrapping
try {
  await apiCall();
} catch (error) {
  throw new ImportError('Failed to fetch page', {
    cause: error,
    pageId: page.id
  });
}
```

## Testing

### Test Structure

- **Unit tests**: Test individual functions and classes
- **Integration tests**: Test component interactions
- **End-to-end tests**: Test complete workflows

### Writing Tests

```typescript
// Unit test example
describe('ContentConverter', () => {
  let converter: ContentConverter;

  beforeEach(() => {
    converter = new ContentConverter();
  });

  it('should convert paragraph blocks to markdown', () => {
    const block = createParagraphBlock('Hello world');
    const result = converter.convertBlock(block);
    expect(result).toBe('Hello world\n\n');
  });
});

// Integration test example
describe('NotionObsidianImporter', () => {
  it('should import a simple page', async () => {
    const importer = new NotionObsidianImporter(testConfig);
    const result = await importer.importPage('test-page-id');
    
    expect(result.markdown).toContain('# Test Page');
    expect(result.errors).toHaveLength(0);
  });
});
```

### Test Data

Use fixtures for consistent test data:

```typescript
// tests/fixtures/notion-blocks.ts
export const sampleParagraphBlock: NotionBlock = {
  id: 'block-123',
  type: 'paragraph',
  object: 'block',
  paragraph: {
    rich_text: [
      {
        type: 'text',
        text: { content: 'Sample paragraph text' }
      }
    ]
  }
};
```

### Mocking

Mock external dependencies:

```typescript
// Mock Notion API
jest.mock('@notionhq/client', () => ({
  Client: jest.fn().mockImplementation(() => ({
    pages: {
      retrieve: jest.fn(),
      update: jest.fn()
    },
    blocks: {
      children: {
        list: jest.fn()
      }
    }
  }))
}));
```

## Documentation

### Code Documentation

- Document all public APIs
- Use JSDoc for TypeScript
- Include examples in documentation
- Keep documentation up to date

### README Updates

When adding features:

1. Update feature list
2. Add usage examples
3. Update configuration options
4. Include troubleshooting info

### API Documentation

Update `docs/API.md` for:

- New public methods
- Configuration options
- TypeScript interfaces
- Usage examples

## Release Process

### Version Numbering

We follow [Semantic Versioning](https://semver.org/):

- **MAJOR**: Breaking changes
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes (backward compatible)

### Release Checklist

1. **Update version**:

```bash
npm version [major|minor|patch]
```

2. **Update CHANGELOG**:

```markdown
## [1.1.0] - 2023-12-01

### Added
- New database conversion features
- Progress tracking improvements

### Fixed
- Rate limiting edge cases
- File path handling on Windows

### Changed
- Updated API for better type safety
```

3. **Build and test**:

```bash
npm run build
npm test
npm run test:integration
```

4. **Create release**:

```bash
git push origin main --tags
```

5. **Publish to npm**:

```bash
npm publish
```

### Release Notes

Include in release notes:

- New features and improvements
- Bug fixes
- Breaking changes (with migration guide)
- Deprecation notices
- Contributors acknowledgment

## Development Tools

### Recommended Extensions (VS Code)

- TypeScript and JavaScript Language Features
- ESLint
- Prettier
- Jest
- GitLens
- Auto Import

### Debugging

```bash
# Debug CLI
DEBUG=* npm run dev:cli

# Debug specific modules
DEBUG=notion-obsidian-importer:* npm run dev

# Debug tests
DEBUG=* npm test -- --verbose
```

### Performance Profiling

```bash
# Profile memory usage
node --inspect-brk dist/cli/index.js

# Profile CPU usage
node --prof dist/cli/index.js
```

## Community

### Getting Help

- **GitHub Discussions**: For questions and community support
- **GitHub Issues**: For bug reports and feature requests
- **Discord**: [Join our Discord server](https://discord.gg/notion-obsidian-importer)
- **Email**: [Email the maintainers](mailto:maintainers@notion-obsidian-importer.com)

### Recognition

Contributors are recognized in:

- GitHub contributors page
- Release notes
- Project README
- Annual contributor celebration

### Maintainer Resources

For maintainers:

- [Maintainer Guidelines](docs/MAINTAINER.md)
- [Release Automation](docs/RELEASE.md)
- [Security Policy](SECURITY.md)

## License

By contributing to this project, you agree that your contributions will be licensed under the MIT License.

---

Thank you for contributing to the Notion-Obsidian Importer! Your contributions help make knowledge management better for everyone.