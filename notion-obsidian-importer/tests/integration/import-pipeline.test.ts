import { NotionToObsidianImporter } from '../../src/importer/NotionToObsidianImporter';
import { NotionAPIClient } from '../../src/client/NotionAPIClient';
import { ContentConverter } from '../../src/converters/ContentConverter';
import { DatabaseConverter } from '../../src/converters/DatabaseConverter';
import { FileManager } from '../../src/utils/FileManager';
import { NotionConfig, ImportOptions } from '../../src/types';
import * as fs from 'fs/promises';
import * as path from 'path';
import { tmpdir } from 'os';

// Import test fixtures
import * as testData from '../fixtures/notion-data.json';

jest.setTimeout(30000); // 30 second timeout for integration tests

describe('Notion to Obsidian Import Pipeline Integration', () => {
  let importer: NotionToObsidianImporter;
  let tempDir: string;
  let config: NotionConfig;
  let importOptions: ImportOptions;

  beforeAll(async () => {
    // Create temporary directory for test outputs
    tempDir = await fs.mkdtemp(path.join(tmpdir(), 'notion-obsidian-test-'));
    
    config = {
      token: 'test-token',
      version: '2022-06-28',
      rateLimitRequests: 10,
      rateLimitWindow: 1000
    };

    importOptions = {
      outputPath: tempDir,
      includeImages: true,
      includeFiles: true,
      createIndex: true,
      preserveNotionIds: false,
      flattenHierarchy: false
    };
  });

  afterAll(async () => {
    // Clean up temporary directory
    try {
      await fs.rm(tempDir, { recursive: true, force: true });
    } catch (error) {
      console.warn('Failed to clean up temp directory:', error);
    }
  });

  beforeEach(() => {
    // Reset mocks
    jest.clearAllMocks();
    
    // Create fresh importer instance
    importer = new NotionToObsidianImporter(config);
  });

  describe('Full Import Workflow', () => {
    it('should complete a full import of pages and databases', async () => {
      // Mock the API client responses
      const mockClient = importer['client'] as jest.Mocked<NotionAPIClient>;
      
      // Mock search to return our test data
      mockClient.search = jest.fn().mockResolvedValue([
        testData.pages.basicPage,
        testData.pages.pageWithBlocks,
        testData.databases.taskDatabase
      ]);

      // Mock individual page/database retrieval
      mockClient.getPage = jest.fn()
        .mockResolvedValueOnce(testData.pages.basicPage)
        .mockResolvedValueOnce(testData.pages.pageWithBlocks);

      mockClient.getPageBlocks = jest.fn()
        .mockResolvedValueOnce([])
        .mockResolvedValueOnce(testData.blocks.mixedContent);

      mockClient.getDatabase = jest.fn()
        .mockResolvedValue(testData.databases.taskDatabase);

      mockClient.queryDatabase = jest.fn()
        .mockResolvedValue([testData.pages.databasePage]);

      // Execute the import
      const result = await importer.importWorkspace(importOptions);

      // Verify import results
      expect(result.success).toBe(true);
      expect(result.totalPages).toBeGreaterThan(0);
      expect(result.totalDatabases).toBeGreaterThan(0);
      expect(result.errors).toHaveLength(0);

      // Verify files were created
      const files = await fs.readdir(tempDir);
      expect(files.length).toBeGreaterThan(0);

      // Verify index file was created
      expect(files).toContain('index.md');
    });

    it('should handle partial failures gracefully', async () => {
      const mockClient = importer['client'] as jest.Mocked<NotionAPIClient>;
      
      // Mock search to return test data
      mockClient.search = jest.fn().mockResolvedValue([
        testData.pages.basicPage,
        testData.pages.pageWithBlocks
      ]);

      // Mock one successful and one failed page retrieval
      mockClient.getPage = jest.fn()
        .mockResolvedValueOnce(testData.pages.basicPage)
        .mockRejectedValueOnce(new Error('API Rate Limit'));

      mockClient.getPageBlocks = jest.fn()
        .mockResolvedValue([]);

      const result = await importer.importWorkspace(importOptions);

      expect(result.success).toBe(true); // Partial success
      expect(result.totalPages).toBe(1); // Only one successful
      expect(result.errors).toHaveLength(1);
      expect(result.errors[0]).toContain('API Rate Limit');
    });

    it('should preserve hierarchical structure when enabled', async () => {
      const hierarchicalOptions = {
        ...importOptions,
        flattenHierarchy: false
      };

      const mockClient = importer['client'] as jest.Mocked<NotionAPIClient>;
      
      // Mock nested page structure
      const parentPage = {
        ...testData.pages.basicPage,
        id: 'parent-page-id'
      };

      const childPage = {
        ...testData.pages.basicPage,
        id: 'child-page-id',
        parent: {
          type: 'page_id',
          page_id: 'parent-page-id'
        }
      };

      mockClient.search = jest.fn().mockResolvedValue([parentPage, childPage]);
      mockClient.getPage = jest.fn()
        .mockResolvedValueOnce(parentPage)
        .mockResolvedValueOnce(childPage);
      mockClient.getPageBlocks = jest.fn().mockResolvedValue([]);

      const result = await importer.importWorkspace(hierarchicalOptions);

      expect(result.success).toBe(true);

      // Check that nested directory structure was created
      const files = await fs.readdir(tempDir, { withFileTypes: true });
      const dirs = files.filter(f => f.isDirectory());
      expect(dirs.length).toBeGreaterThan(0);
    });
  });

  describe('Content Processing Pipeline', () => {
    it('should correctly process complex nested content', async () => {
      const mockClient = importer['client'] as jest.Mocked<NotionAPIClient>;
      
      const complexPage = {
        ...testData.pages.pageWithBlocks,
        id: 'complex-content-page'
      };

      mockClient.search = jest.fn().mockResolvedValue([complexPage]);
      mockClient.getPage = jest.fn().mockResolvedValue(complexPage);
      mockClient.getPageBlocks = jest.fn().mockResolvedValue(testData.blocks.nestedStructure);

      await importer.importWorkspace(importOptions);

      // Read the generated markdown file
      const files = await fs.readdir(tempDir);
      const markdownFiles = files.filter(f => f.endsWith('.md') && f !== 'index.md');
      expect(markdownFiles.length).toBeGreaterThan(0);

      const content = await fs.readFile(
        path.join(tempDir, markdownFiles[0]), 
        'utf-8'
      );

      // Verify the content contains expected markdown structures
      expect(content).toContain('# '); // Headings
      expect(content).toContain('- '); // Lists
      expect(content).toContain('```'); // Code blocks
    });

    it('should handle media attachments correctly', async () => {
      const mockClient = importer['client'] as jest.Mocked<NotionAPIClient>;
      
      const pageWithMedia = {
        ...testData.pages.basicPage,
        id: 'media-page'
      };

      mockClient.search = jest.fn().mockResolvedValue([pageWithMedia]);
      mockClient.getPage = jest.fn().mockResolvedValue(pageWithMedia);
      mockClient.getPageBlocks = jest.fn().mockResolvedValue(testData.blocks.mediaContent);

      // Mock file download
      mockClient.downloadFile = jest.fn().mockResolvedValue(Buffer.from('fake-image-data'));

      await importer.importWorkspace(importOptions);

      // Check that attachments directory was created
      const files = await fs.readdir(tempDir, { withFileTypes: true });
      const attachmentsDir = files.find(f => f.isDirectory() && f.name === 'attachments');
      expect(attachmentsDir).toBeDefined();

      // Check that media files were downloaded
      if (attachmentsDir) {
        const mediaFiles = await fs.readdir(path.join(tempDir, 'attachments'));
        expect(mediaFiles.length).toBeGreaterThan(0);
      }
    });

    it('should generate proper frontmatter for all pages', async () => {
      const mockClient = importer['client'] as jest.Mocked<NotionAPIClient>;
      
      const testPage = testData.pages.pageWithProperties;

      mockClient.search = jest.fn().mockResolvedValue([testPage]);
      mockClient.getPage = jest.fn().mockResolvedValue(testPage);
      mockClient.getPageBlocks = jest.fn().mockResolvedValue([]);

      await importer.importWorkspace(importOptions);

      const files = await fs.readdir(tempDir);
      const markdownFiles = files.filter(f => f.endsWith('.md') && f !== 'index.md');
      
      const content = await fs.readFile(
        path.join(tempDir, markdownFiles[0]), 
        'utf-8'
      );

      // Verify frontmatter exists and contains expected fields
      expect(content).toMatch(/^---\n/);
      expect(content).toContain('notion-id:');
      expect(content).toContain('created:');
      expect(content).toContain('updated:');
      expect(content).toContain('---\n');
    });
  });

  describe('Database Processing Pipeline', () => {
    it('should convert database to Obsidian format with proper structure', async () => {
      const mockClient = importer['client'] as jest.Mocked<NotionAPIClient>;
      
      const database = testData.databases.taskDatabase;

      mockClient.search = jest.fn().mockResolvedValue([database]);
      mockClient.getDatabase = jest.fn().mockResolvedValue(database);
      mockClient.queryDatabase = jest.fn().mockResolvedValue([
        testData.pages.databasePage,
        testData.pages.databasePageWithAllProperties
      ]);

      await importer.importWorkspace(importOptions);

      // Check database directory was created
      const files = await fs.readdir(tempDir, { withFileTypes: true });
      const dbDir = files.find(f => f.isDirectory() && f.name.includes('Task'));
      expect(dbDir).toBeDefined();

      if (dbDir) {
        const dbPath = path.join(tempDir, dbDir.name);
        const dbFiles = await fs.readdir(dbPath);
        
        // Should have index file and individual page files
        expect(dbFiles).toContain('index.md');
        expect(dbFiles.some(f => f.endsWith('.md') && f !== 'index.md')).toBe(true);

        // Check index file content
        const indexContent = await fs.readFile(
          path.join(dbPath, 'index.md'), 
          'utf-8'
        );
        expect(indexContent).toContain('# Task Database');
        expect(indexContent).toContain('| Title |'); // Table headers
      }
    });

    it('should handle database with no pages', async () => {
      const mockClient = importer['client'] as jest.Mocked<NotionAPIClient>;
      
      const emptyDatabase = testData.databases.emptyDatabase;

      mockClient.search = jest.fn().mockResolvedValue([emptyDatabase]);
      mockClient.getDatabase = jest.fn().mockResolvedValue(emptyDatabase);
      mockClient.queryDatabase = jest.fn().mockResolvedValue([]);

      const result = await importer.importWorkspace(importOptions);

      expect(result.success).toBe(true);
      expect(result.totalDatabases).toBe(1);

      // Should still create database directory with index
      const files = await fs.readdir(tempDir, { withFileTypes: true });
      const dbDir = files.find(f => f.isDirectory());
      expect(dbDir).toBeDefined();
    });
  });

  describe('Error Handling and Recovery', () => {
    it('should continue processing after individual page failures', async () => {
      const mockClient = importer['client'] as jest.Mocked<NotionAPIClient>;
      
      mockClient.search = jest.fn().mockResolvedValue([
        testData.pages.basicPage,
        { ...testData.pages.basicPage, id: 'failing-page' },
        testData.pages.pageWithBlocks
      ]);

      mockClient.getPage = jest.fn()
        .mockResolvedValueOnce(testData.pages.basicPage)
        .mockRejectedValueOnce(new Error('Page not found'))
        .mockResolvedValueOnce(testData.pages.pageWithBlocks);

      mockClient.getPageBlocks = jest.fn().mockResolvedValue([]);

      const result = await importer.importWorkspace(importOptions);

      expect(result.success).toBe(true);
      expect(result.totalPages).toBe(2); // Two successful pages
      expect(result.errors).toHaveLength(1);
    });

    it('should handle network timeouts gracefully', async () => {
      const mockClient = importer['client'] as jest.Mocked<NotionAPIClient>;
      
      mockClient.search = jest.fn().mockRejectedValue(new Error('Network timeout'));

      const result = await importer.importWorkspace(importOptions);

      expect(result.success).toBe(false);
      expect(result.errors).toHaveLength(1);
      expect(result.errors[0]).toContain('Network timeout');
    });

    it('should validate output directory permissions', async () => {
      const invalidOptions = {
        ...importOptions,
        outputPath: '/invalid/readonly/path'
      };

      const result = await importer.importWorkspace(invalidOptions);

      expect(result.success).toBe(false);
      expect(result.errors.length).toBeGreaterThan(0);
    });
  });

  describe('Rate Limiting Integration', () => {
    it('should respect rate limits during import', async () => {
      const mockClient = importer['client'] as jest.Mocked<NotionAPIClient>;
      
      // Create a rate limiter that delays requests
      const rateLimiter = importer['client']['rateLimiter'];
      const originalExecute = rateLimiter.execute;
      
      let callCount = 0;
      rateLimiter.execute = jest.fn().mockImplementation(async (fn: any) => {
        callCount++;
        if (callCount > 3) {
          // Simulate rate limit delay
          await new Promise(resolve => setTimeout(resolve, 100));
        }
        return originalExecute.call(rateLimiter, fn);
      });

      mockClient.search = jest.fn().mockResolvedValue([
        testData.pages.basicPage,
        testData.pages.pageWithBlocks,
        testData.pages.pageWithProperties
      ]);

      mockClient.getPage = jest.fn()
        .mockResolvedValue(testData.pages.basicPage);
      mockClient.getPageBlocks = jest.fn().mockResolvedValue([]);

      const startTime = Date.now();
      const result = await importer.importWorkspace(importOptions);
      const endTime = Date.now();

      expect(result.success).toBe(true);
      expect(endTime - startTime).toBeGreaterThan(50); // Should take some time due to rate limiting
    });
  });

  describe('Configuration Validation', () => {
    it('should validate required configuration options', async () => {
      const invalidConfig = { ...config, token: '' };
      
      expect(() => {
        new NotionToObsidianImporter(invalidConfig);
      }).toThrow();
    });

    it('should apply default options when not provided', async () => {
      const minimalOptions = {
        outputPath: tempDir
      };

      const mockClient = importer['client'] as jest.Mocked<NotionAPIClient>;
      mockClient.search = jest.fn().mockResolvedValue([]);

      const result = await importer.importWorkspace(minimalOptions);

      expect(result.success).toBe(true);
      // Should work with default options
    });
  });

  describe('Output Validation', () => {
    it('should create proper directory structure', async () => {
      const mockClient = importer['client'] as jest.Mocked<NotionAPIClient>;
      
      mockClient.search = jest.fn().mockResolvedValue([
        testData.pages.basicPage,
        testData.databases.taskDatabase
      ]);

      mockClient.getPage = jest.fn().mockResolvedValue(testData.pages.basicPage);
      mockClient.getPageBlocks = jest.fn().mockResolvedValue([]);
      mockClient.getDatabase = jest.fn().mockResolvedValue(testData.databases.taskDatabase);
      mockClient.queryDatabase = jest.fn().mockResolvedValue([]);

      await importer.importWorkspace(importOptions);

      const stats = await fs.stat(tempDir);
      expect(stats.isDirectory()).toBe(true);

      const files = await fs.readdir(tempDir, { withFileTypes: true });
      
      // Should have index file
      expect(files.some(f => f.isFile() && f.name === 'index.md')).toBe(true);
      
      // Should have page files
      expect(files.some(f => f.isFile() && f.name.endsWith('.md'))).toBe(true);
      
      // Should have database directories
      expect(files.some(f => f.isDirectory())).toBe(true);
    });

    it('should generate valid markdown files', async () => {
      const mockClient = importer['client'] as jest.Mocked<NotionAPIClient>;
      
      mockClient.search = jest.fn().mockResolvedValue([testData.pages.basicPage]);
      mockClient.getPage = jest.fn().mockResolvedValue(testData.pages.basicPage);
      mockClient.getPageBlocks = jest.fn().mockResolvedValue(testData.blocks.basicContent);

      await importer.importWorkspace(importOptions);

      const files = await fs.readdir(tempDir);
      const markdownFiles = files.filter(f => f.endsWith('.md'));

      for (const file of markdownFiles) {
        const content = await fs.readFile(path.join(tempDir, file), 'utf-8');
        
        // Basic markdown validation
        expect(content).toBeTruthy();
        expect(content.length).toBeGreaterThan(0);
        
        // Should have valid frontmatter if present
        if (content.startsWith('---')) {
          const frontmatterEnd = content.indexOf('---', 3);
          expect(frontmatterEnd).toBeGreaterThan(-1);
        }
      }
    });
  });
});