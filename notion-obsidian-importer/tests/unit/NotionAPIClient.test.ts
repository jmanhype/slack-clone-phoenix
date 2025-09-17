import { NotionAPIClient } from '../../src/client/NotionAPIClient';
import { RateLimiter } from '../../src/client/RateLimiter';
import { NotionConfig, NotionPage, NotionDatabase, NotionBlock } from '../../src/types';
import { Client } from '@notionhq/client';

// Mock dependencies
jest.mock('@notionhq/client');
jest.mock('../../src/client/RateLimiter');
jest.mock('../../src/utils/logger');

describe('NotionAPIClient', () => {
  let client: NotionAPIClient;
  let mockNotionClient: jest.Mocked<Client>;
  let mockRateLimiter: jest.Mocked<RateLimiter>;
  let config: NotionConfig;

  const mockPage = {
    id: 'page-123',
    object: 'page',
    properties: {
      title: {
        type: 'title',
        title: [{ plain_text: 'Test Page' }]
      }
    },
    parent: { type: 'workspace', workspace: true },
    created_time: '2023-01-01T00:00:00.000Z',
    last_edited_time: '2023-01-02T00:00:00.000Z',
    url: 'https://notion.so/test-page'
  };

  const mockDatabase = {
    id: 'db-123',
    object: 'database',
    title: [{ plain_text: 'Test Database' }],
    properties: {
      Name: { type: 'title' },
      Status: { type: 'select' }
    },
    parent: { type: 'workspace', workspace: true },
    created_time: '2023-01-01T00:00:00.000Z',
    last_edited_time: '2023-01-02T00:00:00.000Z',
    url: 'https://notion.so/test-db'
  };

  const mockBlock = {
    id: 'block-123',
    object: 'block',
    type: 'paragraph',
    created_time: '2023-01-01T00:00:00.000Z',
    last_edited_time: '2023-01-02T00:00:00.000Z',
    has_children: false,
    archived: false,
    paragraph: {
      rich_text: [{ plain_text: 'Test content' }]
    }
  };

  beforeEach(() => {
    config = {
      token: 'test-token',
      version: '2022-06-28',
      rateLimitRequests: 3,
      rateLimitWindow: 1000
    };

    // Setup mocks
    mockNotionClient = {
      search: jest.fn(),
      pages: { retrieve: jest.fn() },
      blocks: { children: { list: jest.fn() } },
      databases: { 
        retrieve: jest.fn(),
        query: jest.fn()
      },
      users: { me: jest.fn() }
    } as any;

    mockRateLimiter = {
      execute: jest.fn(),
      getRateLimitInfo: jest.fn(),
      reset: jest.fn()
    } as any;

    (Client as jest.MockedClass<typeof Client>).mockImplementation(() => mockNotionClient);
    (RateLimiter as jest.MockedClass<typeof RateLimiter>).mockImplementation(() => mockRateLimiter);

    // Setup rate limiter to execute functions directly
    mockRateLimiter.execute.mockImplementation((fn: any) => fn());

    client = new NotionAPIClient(config);
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('constructor', () => {
    it('should initialize with correct configuration', () => {
      expect(Client).toHaveBeenCalledWith({
        auth: 'test-token',
        notionVersion: '2022-06-28'
      });

      expect(RateLimiter).toHaveBeenCalledWith(3, 1000);
    });

    it('should use default values when not provided', () => {
      const minimalConfig = { token: 'test-token' };
      new NotionAPIClient(minimalConfig);

      expect(Client).toHaveBeenCalledWith({
        auth: 'test-token',
        notionVersion: '2022-06-28'
      });
    });
  });

  describe('search', () => {
    it('should search workspace and return mapped results', async () => {
      const mockResponse = {
        results: [mockPage, mockDatabase],
        next_cursor: null
      };

      mockNotionClient.search.mockResolvedValue(mockResponse as any);

      const results = await client.search('test query');

      expect(mockNotionClient.search).toHaveBeenCalledWith({
        query: 'test query',
        filter: undefined,
        start_cursor: undefined,
        page_size: 100
      });

      expect(results).toHaveLength(2);
      expect(results[0]).toMatchObject({
        id: 'page-123',
        title: 'Test Page'
      });
      expect(results[1]).toMatchObject({
        id: 'db-123',
        title: 'Test Database'
      });
    });

    it('should handle pagination', async () => {
      const page1 = {
        results: [mockPage],
        next_cursor: 'cursor-123'
      };
      
      const page2 = {
        results: [mockDatabase],
        next_cursor: null
      };

      mockNotionClient.search
        .mockResolvedValueOnce(page1 as any)
        .mockResolvedValueOnce(page2 as any);

      const results = await client.search();

      expect(mockNotionClient.search).toHaveBeenCalledTimes(2);
      expect(mockNotionClient.search).toHaveBeenNthCalledWith(2, {
        query: undefined,
        filter: undefined,
        start_cursor: 'cursor-123',
        page_size: 100
      });

      expect(results).toHaveLength(2);
    });

    it('should handle search with filter', async () => {
      const filter = { property: 'object', value: 'page' };
      mockNotionClient.search.mockResolvedValue({ results: [], next_cursor: null } as any);

      await client.search('query', filter);

      expect(mockNotionClient.search).toHaveBeenCalledWith({
        query: 'query',
        filter,
        start_cursor: undefined,
        page_size: 100
      });
    });

    it('should handle rate limiting', async () => {
      mockNotionClient.search.mockResolvedValue({ results: [], next_cursor: null } as any);

      await client.search();

      expect(mockRateLimiter.execute).toHaveBeenCalledWith(expect.any(Function), 'search workspace');
    });
  });

  describe('getPage', () => {
    it('should retrieve and map a page', async () => {
      mockNotionClient.pages.retrieve.mockResolvedValue(mockPage as any);

      const result = await client.getPage('page-123');

      expect(mockNotionClient.pages.retrieve).toHaveBeenCalledWith({ page_id: 'page-123' });
      expect(result).toMatchObject({
        id: 'page-123',
        title: 'Test Page',
        createdTime: '2023-01-01T00:00:00.000Z',
        lastEditedTime: '2023-01-02T00:00:00.000Z'
      });
    });

    it('should handle rate limiting', async () => {
      mockNotionClient.pages.retrieve.mockResolvedValue(mockPage as any);

      await client.getPage('page-123');

      expect(mockRateLimiter.execute).toHaveBeenCalledWith(
        expect.any(Function), 
        'get page page-123'
      );
    });
  });

  describe('getPageBlocks', () => {
    it('should retrieve page blocks', async () => {
      const mockResponse = {
        results: [mockBlock],
        next_cursor: null
      };

      mockNotionClient.blocks.children.list.mockResolvedValue(mockResponse as any);

      const result = await client.getPageBlocks('page-123');

      expect(mockNotionClient.blocks.children.list).toHaveBeenCalledWith({
        block_id: 'page-123',
        start_cursor: undefined,
        page_size: 100
      });

      expect(result).toHaveLength(1);
      expect(result[0]).toMatchObject({
        id: 'block-123',
        type: 'paragraph',
        has_children: false
      });
    });

    it('should handle pagination for blocks', async () => {
      const page1 = {
        results: [mockBlock],
        next_cursor: 'cursor-456'
      };
      
      const page2 = {
        results: [{ ...mockBlock, id: 'block-456' }],
        next_cursor: null
      };

      mockNotionClient.blocks.children.list
        .mockResolvedValueOnce(page1 as any)
        .mockResolvedValueOnce(page2 as any);

      const result = await client.getPageBlocks('page-123');

      expect(mockNotionClient.blocks.children.list).toHaveBeenCalledTimes(2);
      expect(result).toHaveLength(2);
    });

    it('should recursively fetch child blocks', async () => {
      const blockWithChildren = {
        ...mockBlock,
        id: 'parent-block',
        has_children: true
      };

      const childBlock = {
        ...mockBlock,
        id: 'child-block'
      };

      mockNotionClient.blocks.children.list
        .mockResolvedValueOnce({ results: [blockWithChildren], next_cursor: null } as any)
        .mockResolvedValueOnce({ results: [childBlock], next_cursor: null } as any);

      const result = await client.getPageBlocks('page-123');

      expect(mockNotionClient.blocks.children.list).toHaveBeenCalledTimes(2);
      expect(result[0].children).toHaveLength(1);
      expect(result[0].children[0].id).toBe('child-block');
    });
  });

  describe('getDatabase', () => {
    it('should retrieve and map a database', async () => {
      mockNotionClient.databases.retrieve.mockResolvedValue(mockDatabase as any);

      const result = await client.getDatabase('db-123');

      expect(mockNotionClient.databases.retrieve).toHaveBeenCalledWith({ database_id: 'db-123' });
      expect(result).toMatchObject({
        id: 'db-123',
        title: 'Test Database',
        properties: {
          Name: { type: 'title' },
          Status: { type: 'select' }
        }
      });
    });
  });

  describe('queryDatabase', () => {
    it('should query database and return pages', async () => {
      const mockResponse = {
        results: [mockPage],
        next_cursor: null
      };

      mockNotionClient.databases.query.mockResolvedValue(mockResponse as any);

      const result = await client.queryDatabase('db-123');

      expect(mockNotionClient.databases.query).toHaveBeenCalledWith({
        database_id: 'db-123',
        filter: undefined,
        sorts: undefined,
        start_cursor: undefined,
        page_size: 100
      });

      expect(result).toHaveLength(1);
      expect(result[0].id).toBe('page-123');
    });

    it('should handle filter and sorts', async () => {
      const filter = { property: 'Status', select: { equals: 'Done' } };
      const sorts = [{ property: 'Name', direction: 'ascending' }];

      mockNotionClient.databases.query.mockResolvedValue({ results: [], next_cursor: null } as any);

      await client.queryDatabase('db-123', filter, sorts);

      expect(mockNotionClient.databases.query).toHaveBeenCalledWith({
        database_id: 'db-123',
        filter,
        sorts,
        start_cursor: undefined,
        page_size: 100
      });
    });
  });

  describe('downloadFile', () => {
    beforeEach(() => {
      // Mock fetch globally
      global.fetch = jest.fn();
    });

    it('should download file and return buffer', async () => {
      const mockBuffer = Buffer.from('test file content');
      const mockResponse = {
        ok: true,
        arrayBuffer: jest.fn().mockResolvedValue(mockBuffer.buffer)
      };

      (global.fetch as jest.Mock).mockResolvedValue(mockResponse);

      const result = await client.downloadFile('https://example.com/file.pdf');

      expect(global.fetch).toHaveBeenCalledWith('https://example.com/file.pdf');
      expect(Buffer.compare(result, mockBuffer)).toBe(0);
    });

    it('should throw error on failed download', async () => {
      const mockResponse = {
        ok: false,
        statusText: 'Not Found'
      };

      (global.fetch as jest.Mock).mockResolvedValue(mockResponse);

      await expect(client.downloadFile('https://example.com/missing.pdf'))
        .rejects.toThrow('Failed to download file: Not Found');
    });
  });

  describe('testConnection', () => {
    it('should return true on successful connection', async () => {
      mockNotionClient.users.me.mockResolvedValue({ id: 'user-123' } as any);

      const result = await client.testConnection();

      expect(result).toBe(true);
      expect(mockNotionClient.users.me).toHaveBeenCalled();
    });

    it('should return false on failed connection', async () => {
      mockNotionClient.users.me.mockRejectedValue(new Error('Unauthorized'));

      const result = await client.testConnection();

      expect(result).toBe(false);
    });
  });

  describe('title extraction', () => {
    it('should extract title from page properties', async () => {
      const pageWithTitle = {
        ...mockPage,
        properties: {
          title: {
            type: 'title',
            title: [{ plain_text: 'Custom Title' }]
          }
        }
      };

      mockNotionClient.pages.retrieve.mockResolvedValue(pageWithTitle as any);
      
      const result = await client.getPage('page-123');
      expect(result.title).toBe('Custom Title');
    });

    it('should extract title from Name property', async () => {
      const pageWithName = {
        ...mockPage,
        properties: {
          Name: {
            type: 'title',
            title: [{ plain_text: 'Name Title' }]
          }
        }
      };

      mockNotionClient.pages.retrieve.mockResolvedValue(pageWithName as any);
      
      const result = await client.getPage('page-123');
      expect(result.title).toBe('Name Title');
    });

    it('should fallback to Untitled for pages without title', async () => {
      const pageWithoutTitle = {
        ...mockPage,
        properties: {}
      };

      mockNotionClient.pages.retrieve.mockResolvedValue(pageWithoutTitle as any);
      
      const result = await client.getPage('page-123');
      expect(result.title).toBe('Untitled');
    });
  });

  describe('rate limiting utilities', () => {
    it('should get rate limit info', () => {
      const mockInfo = { requests: 2, windowStart: Date.now(), resetTime: Date.now() + 1000 };
      mockRateLimiter.getRateLimitInfo.mockReturnValue(mockInfo);

      const info = client.getRateLimitInfo();

      expect(info).toBe(mockInfo);
      expect(mockRateLimiter.getRateLimitInfo).toHaveBeenCalled();
    });

    it('should reset rate limit', () => {
      client.resetRateLimit();

      expect(mockRateLimiter.reset).toHaveBeenCalled();
    });
  });

  describe('error handling', () => {
    it('should handle API errors gracefully', async () => {
      const apiError = new Error('API Error');
      mockNotionClient.search.mockRejectedValue(apiError);

      // The error should bubble up from the rate limiter
      mockRateLimiter.execute.mockRejectedValue(apiError);

      await expect(client.search()).rejects.toThrow('API Error');
    });

    it('should handle malformed responses', async () => {
      const malformedResponse = { results: null, next_cursor: undefined };
      mockNotionClient.search.mockResolvedValue(malformedResponse as any);

      const results = await client.search();

      expect(results).toEqual([]);
    });
  });
});