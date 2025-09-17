import { spawn } from 'child_process';
import * as fs from 'fs/promises';
import * as path from 'path';
import { tmpdir } from 'os';
import { NotionToObsidianImporter } from '../../src/importer/NotionToObsidianImporter';
import { NotionConfig, ImportOptions } from '../../src/types';

// Mock data for E2E scenarios
const mockWorkspaceData = {
  pages: [
    {
      id: 'e2e-page-1',
      title: 'Getting Started',
      created_time: '2023-01-01T00:00:00.000Z',
      last_edited_time: '2023-01-02T00:00:00.000Z',
      properties: {
        title: {
          type: 'title',
          title: [{ plain_text: 'Getting Started' }]
        },
        Tags: {
          type: 'multi_select',
          multi_select: [
            { name: 'documentation', color: 'blue' },
            { name: 'important', color: 'red' }
          ]
        }
      }
    },
    {
      id: 'e2e-page-2',
      title: 'Project Overview',
      created_time: '2023-01-01T00:00:00.000Z',
      last_edited_time: '2023-01-03T00:00:00.000Z',
      properties: {
        title: {
          type: 'title',
          title: [{ plain_text: 'Project Overview' }]
        }
      }
    }
  ],
  databases: [
    {
      id: 'e2e-db-1',
      title: 'Project Tasks',
      properties: {
        Name: { type: 'title' },
        Status: { 
          type: 'select',
          select: {
            options: [
              { name: 'Not Started', color: 'gray' },
              { name: 'In Progress', color: 'yellow' },
              { name: 'Done', color: 'green' }
            ]
          }
        },
        Priority: {
          type: 'select',
          select: {
            options: [
              { name: 'High', color: 'red' },
              { name: 'Medium', color: 'yellow' },
              { name: 'Low', color: 'gray' }
            ]
          }
        },
        Due: { type: 'date' },
        Assignee: { type: 'people' }
      }
    }
  ]
};

jest.setTimeout(60000); // 60 second timeout for E2E tests

describe('End-to-End Import Scenarios', () => {
  let tempVaultDir: string;
  let config: NotionConfig;

  beforeAll(async () => {
    // Create temporary vault directory
    tempVaultDir = await fs.mkdtemp(path.join(tmpdir(), 'obsidian-vault-e2e-'));
    
    config = {
      token: process.env.NOTION_TEST_TOKEN || 'test-token-e2e',
      version: '2022-06-28',
      rateLimitRequests: 3,
      rateLimitWindow: 1000
    };
  });

  afterAll(async () => {
    // Clean up
    try {
      await fs.rm(tempVaultDir, { recursive: true, force: true });
    } catch (error) {
      console.warn('Failed to clean up vault directory:', error);
    }
  });

  describe('Complete Workspace Import', () => {
    it('should import a complete workspace and create valid Obsidian vault', async () => {
      const importer = new NotionToObsidianImporter(config);
      
      // Mock API responses for complete workspace
      const mockClient = importer['client'] as any;
      
      mockClient.search = jest.fn().mockResolvedValue([
        ...mockWorkspaceData.pages,
        ...mockWorkspaceData.databases
      ]);

      mockClient.getPage = jest.fn()
        .mockImplementation((id: string) => {
          const page = mockWorkspaceData.pages.find(p => p.id === id);
          return Promise.resolve(page);
        });

      mockClient.getPageBlocks = jest.fn().mockResolvedValue([
        {
          id: 'block-1',
          type: 'heading_1',
          heading_1: {
            rich_text: [{ plain_text: 'Welcome to the Project' }]
          }
        },
        {
          id: 'block-2',
          type: 'paragraph',
          paragraph: {
            rich_text: [{ plain_text: 'This is an important project that needs careful attention.' }]
          }
        },
        {
          id: 'block-3',
          type: 'bulleted_list_item',
          bulleted_list_item: {
            rich_text: [{ plain_text: 'First task item' }]
          }
        },
        {
          id: 'block-4',
          type: 'bulleted_list_item',
          bulleted_list_item: {
            rich_text: [{ plain_text: 'Second task item' }]
          }
        }
      ]);

      mockClient.getDatabase = jest.fn()
        .mockImplementation((id: string) => {
          const db = mockWorkspaceData.databases.find(d => d.id === id);
          return Promise.resolve(db);
        });

      mockClient.queryDatabase = jest.fn().mockResolvedValue([
        {
          id: 'task-1',
          properties: {
            Name: {
              type: 'title',
              title: [{ plain_text: 'Setup Development Environment' }]
            },
            Status: {
              type: 'select',
              select: { name: 'In Progress' }
            },
            Priority: {
              type: 'select',
              select: { name: 'High' }
            },
            Due: {
              type: 'date',
              date: { start: '2023-12-31' }
            }
          }
        },
        {
          id: 'task-2',
          properties: {
            Name: {
              type: 'title',
              title: [{ plain_text: 'Write Documentation' }]
            },
            Status: {
              type: 'select',
              select: { name: 'Not Started' }
            },
            Priority: {
              type: 'select',
              select: { name: 'Medium' }
            }
          }
        }
      ]);

      const importOptions: ImportOptions = {
        outputPath: tempVaultDir,
        includeImages: true,
        includeFiles: true,
        createIndex: true,
        preserveNotionIds: true,
        flattenHierarchy: false
      };

      // Execute the full import
      const result = await importer.importWorkspace(importOptions);

      // Verify import completed successfully
      expect(result.success).toBe(true);
      expect(result.totalPages).toBe(2);
      expect(result.totalDatabases).toBe(1);
      expect(result.errors).toHaveLength(0);

      // Verify vault structure
      const vaultContents = await fs.readdir(tempVaultDir, { withFileTypes: true });
      
      // Should have index file
      expect(vaultContents.some(item => item.isFile() && item.name === 'index.md')).toBe(true);
      
      // Should have page files
      const markdownFiles = vaultContents.filter(item => 
        item.isFile() && item.name.endsWith('.md') && item.name !== 'index.md'
      );
      expect(markdownFiles.length).toBeGreaterThanOrEqual(2);

      // Should have database directory
      const dbDirs = vaultContents.filter(item => item.isDirectory());
      expect(dbDirs.length).toBeGreaterThanOrEqual(1);

      // Verify index content
      const indexContent = await fs.readFile(path.join(tempVaultDir, 'index.md'), 'utf-8');
      expect(indexContent).toContain('# Notion Workspace');
      expect(indexContent).toContain('Getting Started');
      expect(indexContent).toContain('Project Overview');
      expect(indexContent).toContain('Project Tasks');

      // Verify page content
      for (const mdFile of markdownFiles) {
        const content = await fs.readFile(path.join(tempVaultDir, mdFile.name), 'utf-8');
        
        // Should have proper frontmatter
        expect(content).toMatch(/^---\n/);
        expect(content).toContain('notion-id:');
        expect(content).toContain('created:');
        expect(content).toContain('updated:');
        expect(content).toMatch(/---\n/);
        
        // Should have meaningful content
        expect(content.length).toBeGreaterThan(100);
      }

      // Verify database structure
      const dbDir = dbDirs[0];
      const dbPath = path.join(tempVaultDir, dbDir.name);
      const dbContents = await fs.readdir(dbPath);
      
      expect(dbContents).toContain('index.md');
      
      const dbIndexContent = await fs.readFile(path.join(dbPath, 'index.md'), 'utf-8');
      expect(dbIndexContent).toContain('# Project Tasks');
      expect(dbIndexContent).toContain('| Name |');
      expect(dbIndexContent).toContain('Setup Development Environment');
      expect(dbIndexContent).toContain('Write Documentation');
    });

    it('should handle large workspace with pagination', async () => {
      const importer = new NotionToObsidianImporter(config);
      const mockClient = importer['client'] as any;

      // Generate large dataset
      const largePageSet = Array.from({ length: 150 }, (_, i) => ({
        id: `large-page-${i}`,
        title: `Page ${i + 1}`,
        created_time: '2023-01-01T00:00:00.000Z',
        last_edited_time: '2023-01-02T00:00:00.000Z',
        properties: {
          title: {
            type: 'title',
            title: [{ plain_text: `Page ${i + 1}` }]
          }
        }
      }));

      // Mock paginated search responses
      let searchCallCount = 0;
      mockClient.search = jest.fn().mockImplementation(() => {
        const pageSize = 100;
        const start = searchCallCount * pageSize;
        const end = Math.min(start + pageSize, largePageSet.length);
        const hasMore = end < largePageSet.length;
        
        searchCallCount++;
        
        return Promise.resolve({
          results: largePageSet.slice(start, end),
          next_cursor: hasMore ? `cursor-${searchCallCount}` : null
        });
      });

      mockClient.getPage = jest.fn().mockImplementation((id: string) => {
        const page = largePageSet.find(p => p.id === id);
        return Promise.resolve(page);
      });

      mockClient.getPageBlocks = jest.fn().mockResolvedValue([
        {
          id: 'simple-block',
          type: 'paragraph',
          paragraph: {
            rich_text: [{ plain_text: 'Simple content' }]
          }
        }
      ]);

      const importOptions: ImportOptions = {
        outputPath: tempVaultDir,
        includeImages: false,
        includeFiles: false,
        createIndex: true,
        preserveNotionIds: false,
        flattenHierarchy: true
      };

      const result = await importer.importWorkspace(importOptions);

      expect(result.success).toBe(true);
      expect(result.totalPages).toBe(150);
      expect(mockClient.search).toHaveBeenCalledTimes(2); // Should handle pagination

      // Verify all files were created
      const vaultContents = await fs.readdir(tempVaultDir);
      const markdownFiles = vaultContents.filter(f => f.endsWith('.md'));
      expect(markdownFiles.length).toBe(151); // 150 pages + 1 index
    });
  });

  describe('Real-world Scenarios', () => {
    it('should handle workspace with mixed content types', async () => {
      const importer = new NotionToObsidianImporter(config);
      const mockClient = importer['client'] as any;

      // Mock mixed content workspace
      mockClient.search = jest.fn().mockResolvedValue([
        {
          id: 'meeting-notes',
          title: 'Weekly Team Meeting',
          object: 'page',
          properties: {
            title: {
              type: 'title',
              title: [{ plain_text: 'Weekly Team Meeting' }]
            }
          }
        },
        {
          id: 'project-db',
          title: 'Projects',
          object: 'database',
          properties: {
            Name: { type: 'title' },
            Status: { type: 'status' },
            Owner: { type: 'people' }
          }
        },
        {
          id: 'personal-page',
          title: 'Personal Notes',
          object: 'page',
          properties: {
            title: {
              type: 'title',
              title: [{ plain_text: 'Personal Notes' }]
            }
          }
        }
      ]);

      mockClient.getPage = jest.fn()
        .mockResolvedValueOnce({
          id: 'meeting-notes',
          title: 'Weekly Team Meeting',
          properties: {
            title: {
              type: 'title',
              title: [{ plain_text: 'Weekly Team Meeting' }]
            }
          }
        })
        .mockResolvedValueOnce({
          id: 'personal-page',
          title: 'Personal Notes',
          properties: {
            title: {
              type: 'title',
              title: [{ plain_text: 'Personal Notes' }]
            }
          }
        });

      mockClient.getPageBlocks = jest.fn()
        .mockResolvedValueOnce([
          {
            id: 'agenda-block',
            type: 'heading_2',
            heading_2: {
              rich_text: [{ plain_text: 'Agenda' }]
            }
          },
          {
            id: 'checklist-item',
            type: 'to_do',
            to_do: {
              rich_text: [{ plain_text: 'Review quarterly goals' }],
              checked: false
            }
          }
        ])
        .mockResolvedValueOnce([
          {
            id: 'personal-thought',
            type: 'paragraph',
            paragraph: {
              rich_text: [
                { plain_text: 'Remember to ', type: 'text' },
                { plain_text: 'call mom', type: 'text', annotations: { bold: true } },
                { plain_text: ' today.', type: 'text' }
              ]
            }
          }
        ]);

      mockClient.getDatabase = jest.fn().mockResolvedValue({
        id: 'project-db',
        title: 'Projects',
        properties: {
          Name: { type: 'title' },
          Status: { type: 'status' },
          Owner: { type: 'people' }
        }
      });

      mockClient.queryDatabase = jest.fn().mockResolvedValue([
        {
          id: 'project-1',
          properties: {
            Name: {
              type: 'title',
              title: [{ plain_text: 'Website Redesign' }]
            },
            Status: {
              type: 'status',
              status: { name: 'In Progress' }
            }
          }
        }
      ]);

      const result = await importer.importWorkspace({
        outputPath: tempVaultDir,
        includeImages: true,
        includeFiles: true,
        createIndex: true,
        preserveNotionIds: true,
        flattenHierarchy: false
      });

      expect(result.success).toBe(true);
      expect(result.totalPages).toBe(2);
      expect(result.totalDatabases).toBe(1);

      // Verify different content types were handled
      const vaultContents = await fs.readdir(tempVaultDir, { withFileTypes: true });
      
      // Check for meeting notes with todo items
      const meetingFile = vaultContents.find(item => 
        item.isFile() && item.name.includes('Weekly')
      );
      expect(meetingFile).toBeDefined();
      
      if (meetingFile) {
        const content = await fs.readFile(path.join(tempVaultDir, meetingFile.name), 'utf-8');
        expect(content).toContain('## Agenda');
        expect(content).toContain('- [ ] Review quarterly goals');
      }

      // Check for personal notes with formatting
      const personalFile = vaultContents.find(item => 
        item.isFile() && item.name.includes('Personal')
      );
      expect(personalFile).toBeDefined();
      
      if (personalFile) {
        const content = await fs.readFile(path.join(tempVaultDir, personalFile.name), 'utf-8');
        expect(content).toContain('**call mom**');
      }
    });

    it('should gracefully handle API rate limits', async () => {
      const importer = new NotionToObsidianImporter({
        ...config,
        rateLimitRequests: 2,
        rateLimitWindow: 1000
      });

      const mockClient = importer['client'] as any;

      // Create enough content to trigger rate limiting
      const manyPages = Array.from({ length: 10 }, (_, i) => ({
        id: `rate-limit-page-${i}`,
        title: `Rate Limit Test Page ${i}`,
        properties: {
          title: {
            type: 'title',
            title: [{ plain_text: `Rate Limit Test Page ${i}` }]
          }
        }
      }));

      mockClient.search = jest.fn().mockResolvedValue(manyPages);

      let apiCallCount = 0;
      mockClient.getPage = jest.fn().mockImplementation(async (id: string) => {
        apiCallCount++;
        
        // Simulate rate limiting after 3 calls
        if (apiCallCount > 3 && apiCallCount % 3 === 0) {
          throw new Error('Rate limit exceeded');
        }
        
        return manyPages.find(p => p.id === id);
      });

      mockClient.getPageBlocks = jest.fn().mockResolvedValue([]);

      const startTime = Date.now();
      const result = await importer.importWorkspace({
        outputPath: tempVaultDir,
        includeImages: false,
        includeFiles: false,
        createIndex: false,
        preserveNotionIds: false,
        flattenHierarchy: true
      });

      const duration = Date.now() - startTime;

      // Should complete but with some errors and take time due to rate limiting
      expect(result.totalPages).toBeGreaterThan(0);
      expect(result.errors.length).toBeGreaterThan(0);
      expect(duration).toBeGreaterThan(500); // Should be throttled
    });
  });

  describe('Output Quality Validation', () => {
    it('should create Obsidian-compatible vault structure', async () => {
      const importer = new NotionToObsidianImporter(config);
      const mockClient = importer['client'] as any;

      mockClient.search = jest.fn().mockResolvedValue([
        {
          id: 'quality-page',
          title: 'Quality Test Page',
          properties: {
            title: {
              type: 'title',
              title: [{ plain_text: 'Quality Test Page' }]
            }
          }
        }
      ]);

      mockClient.getPage = jest.fn().mockResolvedValue({
        id: 'quality-page',
        title: 'Quality Test Page',
        properties: {
          title: {
            type: 'title',
            title: [{ plain_text: 'Quality Test Page' }]
          }
        }
      });

      mockClient.getPageBlocks = jest.fn().mockResolvedValue([
        {
          id: 'link-block',
          type: 'paragraph',
          paragraph: {
            rich_text: [
              { plain_text: 'Check out ', type: 'text' },
              { 
                plain_text: 'this link',
                type: 'text',
                href: 'https://example.com'
              },
              { plain_text: ' for more info.', type: 'text' }
            ]
          }
        }
      ]);

      await importer.importWorkspace({
        outputPath: tempVaultDir,
        includeImages: false,
        includeFiles: false,
        createIndex: true,
        preserveNotionIds: true,
        flattenHierarchy: false
      });

      // Verify Obsidian compatibility
      const vaultContents = await fs.readdir(tempVaultDir);
      const pageFile = vaultContents.find(f => f.includes('Quality') && f.endsWith('.md'));
      expect(pageFile).toBeDefined();

      if (pageFile) {
        const content = await fs.readFile(path.join(tempVaultDir, pageFile), 'utf-8');
        
        // Should have valid frontmatter
        expect(content).toMatch(/^---[\s\S]*?---\n/);
        
        // Should have proper markdown links
        expect(content).toContain('[this link](https://example.com)');
        
        // Should be valid markdown (no syntax errors)
        expect(content).not.toContain('undefined');
        expect(content).not.toContain('null');
        expect(content).not.toContain('[object Object]');
      }
    });

    it('should maintain referential integrity between pages', async () => {
      const importer = new NotionToObsidianImporter(config);
      const mockClient = importer['client'] as any;

      // Create linked pages
      mockClient.search = jest.fn().mockResolvedValue([
        {
          id: 'page-a',
          title: 'Page A',
          properties: {
            title: {
              type: 'title',
              title: [{ plain_text: 'Page A' }]
            }
          }
        },
        {
          id: 'page-b',
          title: 'Page B',
          properties: {
            title: {
              type: 'title',
              title: [{ plain_text: 'Page B' }]
            }
          }
        }
      ]);

      mockClient.getPage = jest.fn()
        .mockImplementation((id: string) => {
          if (id === 'page-a') {
            return Promise.resolve({
              id: 'page-a',
              title: 'Page A',
              properties: {
                title: {
                  type: 'title',
                  title: [{ plain_text: 'Page A' }]
                }
              }
            });
          } else {
            return Promise.resolve({
              id: 'page-b',
              title: 'Page B',
              properties: {
                title: {
                  type: 'title',
                  title: [{ plain_text: 'Page B' }]
                }
              }
            });
          }
        });

      mockClient.getPageBlocks = jest.fn()
        .mockImplementation((id: string) => {
          if (id === 'page-a') {
            return Promise.resolve([
              {
                id: 'link-to-b',
                type: 'paragraph',
                paragraph: {
                  rich_text: [
                    { plain_text: 'See also: ', type: 'text' },
                    {
                      plain_text: 'Page B',
                      type: 'mention',
                      mention: {
                        type: 'page',
                        page: { id: 'page-b' }
                      }
                    }
                  ]
                }
              }
            ]);
          } else {
            return Promise.resolve([
              {
                id: 'content-b',
                type: 'paragraph',
                paragraph: {
                  rich_text: [{ plain_text: 'This is Page B content.' }]
                }
              }
            ]);
          }
        });

      await importer.importWorkspace({
        outputPath: tempVaultDir,
        includeImages: false,
        includeFiles: false,
        createIndex: true,
        preserveNotionIds: false,
        flattenHierarchy: false
      });

      // Check that page links are properly converted
      const vaultContents = await fs.readdir(tempVaultDir);
      const pageAFile = vaultContents.find(f => f.includes('Page A') || f.includes('Page-A'));
      expect(pageAFile).toBeDefined();

      if (pageAFile) {
        const content = await fs.readFile(path.join(tempVaultDir, pageAFile), 'utf-8');
        
        // Should contain a proper Obsidian wikilink to Page B
        expect(content).toMatch(/\[\[.*Page.*B.*\]\]/);
      }
    });
  });

  describe('Performance and Memory', () => {
    it('should handle large imports without memory issues', async () => {
      const importer = new NotionToObsidianImporter(config);
      const mockClient = importer['client'] as any;

      // Simulate memory pressure scenario
      const largeContent = 'X'.repeat(10000); // 10KB per block
      const manyBlocks = Array.from({ length: 100 }, (_, i) => ({
        id: `large-block-${i}`,
        type: 'paragraph',
        paragraph: {
          rich_text: [{ plain_text: largeContent }]
        }
      }));

      mockClient.search = jest.fn().mockResolvedValue([
        {
          id: 'large-page',
          title: 'Large Content Page',
          properties: {
            title: {
              type: 'title',
              title: [{ plain_text: 'Large Content Page' }]
            }
          }
        }
      ]);

      mockClient.getPage = jest.fn().mockResolvedValue({
        id: 'large-page',
        title: 'Large Content Page'
      });

      mockClient.getPageBlocks = jest.fn().mockResolvedValue(manyBlocks);

      const startMemory = process.memoryUsage().heapUsed;
      
      const result = await importer.importWorkspace({
        outputPath: tempVaultDir,
        includeImages: false,
        includeFiles: false,
        createIndex: false,
        preserveNotionIds: false,
        flattenHierarchy: true
      });

      const endMemory = process.memoryUsage().heapUsed;
      const memoryIncrease = endMemory - startMemory;

      expect(result.success).toBe(true);
      
      // Memory increase should be reasonable (less than 100MB for this test)
      expect(memoryIncrease).toBeLessThan(100 * 1024 * 1024);

      // Verify the large content was processed correctly
      const vaultContents = await fs.readdir(tempVaultDir);
      const largeFile = vaultContents.find(f => f.includes('Large'));
      expect(largeFile).toBeDefined();
      
      if (largeFile) {
        const stats = await fs.stat(path.join(tempVaultDir, largeFile));
        expect(stats.size).toBeGreaterThan(500000); // Should be a large file
      }
    });
  });
});