import { DatabaseConverter } from '../../src/converters/DatabaseConverter';
import { ContentConverter } from '../../src/converters/ContentConverter';
import { NotionDatabase, NotionPage, NotionBlock } from '../../src/types';

jest.mock('../../src/converters/ContentConverter');
jest.mock('../../src/utils/logger');

describe('DatabaseConverter', () => {
  let converter: DatabaseConverter;
  let mockContentConverter: jest.Mocked<ContentConverter>;
  let mockDatabase: NotionDatabase;
  let mockPages: NotionPage[];

  beforeEach(() => {
    // Setup mock content converter
    mockContentConverter = {
      convertBlocks: jest.fn()
    } as any;

    (ContentConverter as jest.MockedClass<typeof ContentConverter>).mockImplementation(() => mockContentConverter);

    converter = new DatabaseConverter();

    // Setup mock database
    mockDatabase = {
      id: 'db-123',
      title: 'Test Database',
      properties: {
        Name: {
          type: 'title',
          title: {}
        },
        Status: {
          type: 'select',
          select: {
            options: [
              { name: 'Not Started', color: 'red' },
              { name: 'In Progress', color: 'yellow' },
              { name: 'Done', color: 'green' }
            ]
          }
        },
        Priority: {
          type: 'multi_select',
          multi_select: {
            options: [
              { name: 'High', color: 'red' },
              { name: 'Medium', color: 'yellow' },
              { name: 'Low', color: 'blue' }
            ]
          }
        },
        Due: {
          type: 'date',
          date: {}
        },
        Completed: {
          type: 'checkbox',
          checkbox: {}
        },
        Score: {
          type: 'number',
          number: { format: 'number' }
        },
        Formula: {
          type: 'formula',
          formula: { expression: 'prop("Score") * 2' }
        }
      },
      parent: { type: 'workspace', workspace: true },
      createdTime: '2023-01-01T00:00:00.000Z',
      lastEditedTime: '2023-01-02T00:00:00.000Z',
      url: 'https://notion.so/test-db'
    };

    // Setup mock pages
    mockPages = [
      {
        id: 'page-1',
        title: 'Task 1',
        parent: { type: 'database_id', database_id: 'db-123' },
        properties: {
          Name: {
            type: 'title',
            title: [{ plain_text: 'Task 1' }]
          },
          Status: {
            type: 'select',
            select: { name: 'In Progress' }
          },
          Priority: {
            type: 'multi_select',
            multi_select: [{ name: 'High' }, { name: 'Medium' }]
          },
          Due: {
            type: 'date',
            date: { start: '2023-12-31' }
          },
          Completed: {
            type: 'checkbox',
            checkbox: false
          },
          Score: {
            type: 'number',
            number: 85
          }
        },
        children: [],
        createdTime: '2023-01-01T00:00:00.000Z',
        lastEditedTime: '2023-01-01T12:00:00.000Z',
        url: 'https://notion.so/task-1'
      },
      {
        id: 'page-2',
        title: 'Task 2',
        parent: { type: 'database_id', database_id: 'db-123' },
        properties: {
          Name: {
            type: 'title',
            title: [{ plain_text: 'Task 2' }]
          },
          Status: {
            type: 'select',
            select: { name: 'Done' }
          },
          Completed: {
            type: 'checkbox',
            checkbox: true
          },
          Score: {
            type: 'number',
            number: 92
          }
        },
        children: [],
        createdTime: '2023-01-02T00:00:00.000Z',
        lastEditedTime: '2023-01-02T12:00:00.000Z',
        url: 'https://notion.so/task-2'
      }
    ];
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('convertDatabase', () => {
    beforeEach(() => {
      // Mock the content converter to return successful results
      mockContentConverter.convertBlocks.mockResolvedValue({
        markdown: 'Page content here',
        attachments: [],
        metadata: {
          title: 'Test Page',
          tags: [],
          createdTime: '2023-01-01T00:00:00.000Z',
          lastEditedTime: '2023-01-01T00:00:00.000Z',
          notionId: 'page-123'
        },
        errors: []
      });
    });

    it('should convert database with pages successfully', async () => {
      const result = await converter.convertDatabase(mockDatabase, mockPages);

      expect(result.errors).toHaveLength(0);
      expect(result.pageFiles).toHaveLength(2);
      expect(result.indexFile).toBeDefined();
      
      // Verify content converter was called for each page
      expect(mockContentConverter.convertBlocks).toHaveBeenCalledTimes(2);
    });

    it('should generate correct index file metadata', async () => {
      const result = await converter.convertDatabase(mockDatabase, mockPages);

      expect(result.indexFile.metadata).toMatchObject({
        title: 'Test Database',
        tags: ['database', 'index'],
        createdTime: '2023-01-01T00:00:00.000Z',
        lastEditedTime: '2023-01-02T00:00:00.000Z',
        notionId: 'db-123',
        url: 'https://notion.so/test-db'
      });
    });

    it('should include frontmatter in index file', async () => {
      const result = await converter.convertDatabase(mockDatabase, mockPages);

      const markdown = result.indexFile.markdown;
      expect(markdown).toMatch(/^---\n/);
      expect(markdown).toContain('title: "Test Database"');
      expect(markdown).toContain('type: database');
      expect(markdown).toContain('notion_id: db-123');
      expect(markdown).toContain('notion_url: "https://notion.so/test-db"');
    });

    it('should include properties schema in index file', async () => {
      const result = await converter.convertDatabase(mockDatabase, mockPages);

      const markdown = result.indexFile.markdown;
      expect(markdown).toContain('## Properties');
      expect(markdown).toContain('- **Name**: title');
      expect(markdown).toContain('- **Status**: select');
      expect(markdown).toContain('- Options: Not Started, In Progress, Done');
      expect(markdown).toContain('- **Priority**: multi_select');
      expect(markdown).toContain('- Options: High, Medium, Low');
    });

    it('should include formula expression in properties', async () => {
      const result = await converter.convertDatabase(mockDatabase, mockPages);

      const markdown = result.indexFile.markdown;
      expect(markdown).toContain('- **Formula**: formula');
      expect(markdown).toContain('- Formula: `prop("Score") * 2`');
    });

    it('should generate pages table with correct headers', async () => {
      const result = await converter.convertDatabase(mockDatabase, mockPages);

      const markdown = result.indexFile.markdown;
      expect(markdown).toContain('## Pages');
      expect(markdown).toContain('| Title | Status | Priority | Due | Completed | Score | Created | Updated |');
      expect(markdown).toContain('| --- | --- | --- | --- | --- | --- | --- | --- |');
    });

    it('should populate table rows with page data', async () => {
      const result = await converter.convertDatabase(mockDatabase, mockPages);

      const markdown = result.indexFile.markdown;
      expect(markdown).toContain('| [[Task 1|Task 1]] | In Progress | High, Medium | | | 85 |');
      expect(markdown).toContain('| [[Task 2|Task 2]] | Done | | | ✓ | 92 |');
    });

    it('should include statistics section', async () => {
      const result = await converter.convertDatabase(mockDatabase, mockPages);

      const markdown = result.indexFile.markdown;
      expect(markdown).toContain('## Statistics');
      expect(markdown).toContain('- Total pages: 2');
      expect(markdown).toContain('- Properties: 7');
      expect(markdown).toContain('- Last updated: 2023-01-02T00:00:00.000Z');
    });

    it('should include page links section', async () => {
      const result = await converter.convertDatabase(mockDatabase, mockPages);

      const markdown = result.indexFile.markdown;
      expect(markdown).toContain('## All Pages');
      expect(markdown).toContain('- [[Task 1]]');
      expect(markdown).toContain('- [[Task 2]]');
    });

    it('should handle empty database', async () => {
      const result = await converter.convertDatabase(mockDatabase, []);

      expect(result.pageFiles).toHaveLength(0);
      expect(result.indexFile.markdown).toContain('- Total pages: 0');
      expect(result.indexFile.markdown).not.toContain('## Pages');
      expect(result.indexFile.markdown).not.toContain('## All Pages');
    });
  });

  describe('page metadata creation', () => {
    it('should extract tags from multi_select properties', async () => {
      const result = await converter.convertDatabase(mockDatabase, [mockPages[0]]);

      // Should include multi_select values and database name as tags
      const pageMetadata = result.pageFiles[0].metadata;
      expect(pageMetadata.tags).toContain('High');
      expect(pageMetadata.tags).toContain('Medium');
      expect(pageMetadata.tags).toContain('database:Test Database');
    });

    it('should extract tags from select properties', async () => {
      const result = await converter.convertDatabase(mockDatabase, [mockPages[0]]);

      const pageMetadata = result.pageFiles[0].metadata;
      expect(pageMetadata.tags).toContain('In Progress');
    });

    it('should process page properties correctly', async () => {
      const result = await converter.convertDatabase(mockDatabase, [mockPages[0]]);

      const pageMetadata = result.pageFiles[0].metadata;
      expect(pageMetadata.properties).toMatchObject({
        Name: 'Task 1',
        Status: 'In Progress',
        Priority: ['High', 'Medium'],
        Due: '2023-12-31',
        Completed: false,
        Score: 85
      });
    });

    it('should handle pages without properties', async () => {
      const minimalPage = {
        ...mockPages[0],
        properties: {}
      };

      const result = await converter.convertDatabase(mockDatabase, [minimalPage]);

      const pageMetadata = result.pageFiles[0].metadata;
      expect(pageMetadata.tags).toEqual(['database:Test Database']);
      expect(pageMetadata.properties).toEqual({});
    });
  });

  describe('property processing', () => {
    it('should handle all property types', () => {
      const testProperties = {
        title_prop: {
          type: 'title',
          title: [{ plain_text: 'Title Text' }]
        },
        rich_text_prop: {
          type: 'rich_text',
          rich_text: [{ plain_text: 'Rich ' }, { plain_text: 'Text' }]
        },
        number_prop: {
          type: 'number',
          number: 42
        },
        select_prop: {
          type: 'select',
          select: { name: 'Option A' }
        },
        multi_select_prop: {
          type: 'multi_select',
          multi_select: [{ name: 'Tag1' }, { name: 'Tag2' }]
        },
        date_prop: {
          type: 'date',
          date: { start: '2023-01-01', end: '2023-01-02' }
        },
        checkbox_prop: {
          type: 'checkbox',
          checkbox: true
        },
        url_prop: {
          type: 'url',
          url: 'https://example.com'
        },
        email_prop: {
          type: 'email',
          email: 'test@example.com'
        },
        phone_prop: {
          type: 'phone_number',
          phone_number: '+1234567890'
        },
        formula_string: {
          type: 'formula',
          formula: { string: 'Formula Result' }
        },
        formula_number: {
          type: 'formula',
          formula: { number: 100 }
        },
        formula_boolean: {
          type: 'formula',
          formula: { boolean: true }
        },
        relation_prop: {
          type: 'relation',
          relation: [{ id: 'rel-1' }, { id: 'rel-2' }]
        },
        people_prop: {
          type: 'people',
          people: [{ name: 'John Doe' }, { id: 'user-2' }]
        },
        files_prop: {
          type: 'files',
          files: [
            { name: 'file1.pdf' },
            { external: { url: 'https://example.com/file2.pdf' } }
          ]
        }
      };

      const testPage = {
        ...mockPages[0],
        properties: testProperties
      };

      // Call the private method through reflection
      const result = (converter as any).processPageProperties(testProperties, mockDatabase.properties);

      expect(result).toMatchObject({
        title_prop: 'Title Text',
        rich_text_prop: 'Rich Text',
        number_prop: 42,
        select_prop: 'Option A',
        multi_select_prop: ['Tag1', 'Tag2'],
        date_prop: '2023-01-01',
        date_prop_end: '2023-01-02',
        checkbox_prop: true,
        url_prop: 'https://example.com',
        email_prop: 'test@example.com',
        phone_prop: '+1234567890',
        formula_string: 'Formula Result',
        formula_number: 100,
        formula_boolean: true,
        relation_prop: ['rel-1', 'rel-2'],
        people_prop: ['John Doe', 'user-2'],
        files_prop: ['file1.pdf', 'https://example.com/file2.pdf']
      });
    });

    it('should handle null and empty values', () => {
      const testProperties = {
        empty_number: {
          type: 'number',
          number: null
        },
        empty_select: {
          type: 'select',
          select: null
        },
        empty_multi_select: {
          type: 'multi_select',
          multi_select: []
        },
        empty_date: {
          type: 'date',
          date: null
        }
      };

      const result = (converter as any).processPageProperties(testProperties, mockDatabase.properties);

      expect(result).toEqual({});
    });
  });

  describe('table formatting', () => {
    it('should format property values for table display', () => {
      const selectValue = { type: 'select', select: { name: 'Done' } };
      const multiSelectValue = { type: 'multi_select', multi_select: [{ name: 'Tag1' }, { name: 'Tag2' }] };
      const dateValue = { type: 'date', date: { start: '2023-01-01' } };
      const checkboxTrue = { type: 'checkbox', checkbox: true };
      const checkboxFalse = { type: 'checkbox', checkbox: false };
      const numberValue = { type: 'number', number: 42 };

      expect((converter as any).formatPropertyForTable(selectValue)).toBe('Done');
      expect((converter as any).formatPropertyForTable(multiSelectValue)).toBe('Tag1, Tag2');
      expect((converter as any).formatPropertyForTable(dateValue)).toBe('2023-01-01');
      expect((converter as any).formatPropertyForTable(checkboxTrue)).toBe('✓');
      expect((converter as any).formatPropertyForTable(checkboxFalse)).toBe('');
      expect((converter as any).formatPropertyForTable(numberValue)).toBe('42');
      expect((converter as any).formatPropertyForTable(null)).toBe('');
    });

    it('should limit properties displayed in table', () => {
      const manyProperties = {};
      for (let i = 0; i < 10; i++) {
        manyProperties[`prop${i}`] = { type: 'select' };
      }

      const relevant = (converter as any).getRelevantProperties(manyProperties);
      expect(relevant).toHaveLength(5);
    });
  });

  describe('filename generation', () => {
    it('should generate valid filenames', () => {
      const testCases = [
        { title: 'Normal Title', expected: 'Normal Title' },
        { title: 'Title/With\\Invalid:Characters', expected: 'TitleWithInvalidCharacters' },
        { title: 'Title  with   spaces', expected: 'Title with spaces' },
        { title: '', expected: 'Untitled-page-1' }
      ];

      testCases.forEach(({ title, expected }) => {
        const page = { ...mockPages[0], title, id: 'page-1' };
        const filename = (converter as any).generatePageFilename(page);
        
        if (title === '') {
          expect(filename).toMatch(/^Untitled-page-1/);
        } else {
          expect(filename).toBe(expected);
        }
      });
    });
  });

  describe('error handling', () => {
    it('should handle individual page conversion errors', async () => {
      mockContentConverter.convertBlocks
        .mockResolvedValueOnce({
          markdown: 'Success',
          attachments: [],
          metadata: { title: 'Good', tags: [], createdTime: '', lastEditedTime: '', notionId: '' },
          errors: []
        })
        .mockRejectedValueOnce(new Error('Conversion failed'));

      const result = await converter.convertDatabase(mockDatabase, mockPages);

      expect(result.pageFiles).toHaveLength(1); // Only successful conversion
      expect(result.errors).toHaveLength(1);
      expect(result.errors[0]).toMatchObject({
        type: 'CONVERSION',
        message: 'Failed to convert database page: Conversion failed',
        pageId: 'page-2'
      });
    });

    it('should handle complete database conversion failure', async () => {
      // Mock a critical error that happens before page processing
      const originalConvert = mockContentConverter.convertBlocks;
      mockContentConverter.convertBlocks = jest.fn().mockImplementation(() => {
        throw new Error('Critical error');
      });

      const result = await converter.convertDatabase(mockDatabase, mockPages);

      expect(result.pageFiles).toHaveLength(0);
      expect(result.errors).toHaveLength(1);
      expect(result.errors[0].message).toContain('Critical error');
    });

    it('should return partial results on error', async () => {
      mockContentConverter.convertBlocks.mockRejectedValue(new Error('All conversions failed'));

      const result = await converter.convertDatabase(mockDatabase, mockPages);

      // Should still return index file structure
      expect(result.indexFile).toBeDefined();
      expect(result.indexFile.markdown).toContain('Test Database');
      expect(result.pageFiles).toHaveLength(0);
      expect(result.errors.length).toBeGreaterThan(0);
    });
  });

  describe('date formatting', () => {
    it('should format dates correctly', () => {
      const validDate = '2023-01-01T00:00:00.000Z';
      const invalidDate = 'invalid-date';

      expect((converter as any).formatDate(validDate)).toBe('1/1/2023');
      expect((converter as any).formatDate(invalidDate)).toBe('invalid-date');
    });
  });
});