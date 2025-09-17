import { ContentConverter } from '../../src/converters/ContentConverter';
import { NotionBlock, PageMetadata, AttachmentInfo } from '../../src/types';

jest.mock('../../src/utils/logger');

describe('ContentConverter', () => {
  let converter: ContentConverter;
  let mockMetadata: PageMetadata;

  beforeEach(() => {
    converter = new ContentConverter();
    mockMetadata = {
      title: 'Test Page',
      tags: ['tag1', 'tag2'],
      createdTime: '2023-01-01T00:00:00.000Z',
      lastEditedTime: '2023-01-02T00:00:00.000Z',
      notionId: 'page-123',
      url: 'https://notion.so/test-page'
    };
  });

  describe('convertBlocks', () => {
    it('should convert empty blocks array', async () => {
      const result = await converter.convertBlocks([], mockMetadata);

      expect(result.markdown).toContain('---');
      expect(result.markdown).toContain('title: "Test Page"');
      expect(result.markdown).toContain('notion_id: page-123');
      expect(result.attachments).toEqual([]);
      expect(result.errors).toEqual([]);
    });

    it('should include frontmatter with metadata', async () => {
      const result = await converter.convertBlocks([], mockMetadata);

      expect(result.markdown).toMatch(/^---\n/);
      expect(result.markdown).toContain('title: "Test Page"');
      expect(result.markdown).toContain('created: 2023-01-01T00:00:00.000Z');
      expect(result.markdown).toContain('updated: 2023-01-02T00:00:00.000Z');
      expect(result.markdown).toContain('notion_id: page-123');
      expect(result.markdown).toContain('tags: ["tag1", "tag2"]');
      expect(result.markdown).toContain('notion_url: "https://notion.so/test-page"');
      expect(result.markdown).toMatch(/---\n\n$/);
    });

    it('should handle metadata without optional fields', async () => {
      const minimalMetadata = {
        title: 'Simple Page',
        tags: [],
        createdTime: '2023-01-01T00:00:00.000Z',
        lastEditedTime: '2023-01-02T00:00:00.000Z',
        notionId: 'page-456'
      };

      const result = await converter.convertBlocks([], minimalMetadata);

      expect(result.markdown).toContain('title: "Simple Page"');
      expect(result.markdown).not.toContain('tags:');
      expect(result.markdown).not.toContain('notion_url:');
    });

    it('should escape quotes in title', async () => {
      const metadataWithQuotes = {
        ...mockMetadata,
        title: 'Title with "quotes" inside'
      };

      const result = await converter.convertBlocks([], metadataWithQuotes);

      expect(result.markdown).toContain('title: "Title with \\"quotes\\" inside"');
    });
  });

  describe('paragraph conversion', () => {
    it('should convert simple paragraph', async () => {
      const block: NotionBlock = {
        id: 'block-1',
        type: 'paragraph',
        object: 'block',
        created_time: '2023-01-01T00:00:00.000Z',
        last_edited_time: '2023-01-01T00:00:00.000Z',
        has_children: false,
        archived: false,
        paragraph: {
          rich_text: [{ plain_text: 'This is a paragraph.' }]
        }
      };

      const result = await converter.convertBlocks([block], mockMetadata);

      expect(result.markdown).toContain('This is a paragraph.\n\n');
    });

    it('should convert paragraph with rich text formatting', async () => {
      const block: NotionBlock = {
        id: 'block-1',
        type: 'paragraph',
        object: 'block',
        created_time: '2023-01-01T00:00:00.000Z',
        last_edited_time: '2023-01-01T00:00:00.000Z',
        has_children: false,
        archived: false,
        paragraph: {
          rich_text: [
            { 
              plain_text: 'Bold text', 
              annotations: { bold: true, italic: false, strikethrough: false, underline: false, code: false }
            },
            { plain_text: ' and ' },
            { 
              plain_text: 'italic text', 
              annotations: { bold: false, italic: true, strikethrough: false, underline: false, code: false }
            }
          ]
        }
      };

      const result = await converter.convertBlocks([block], mockMetadata);

      expect(result.markdown).toContain('**Bold text** and *italic text*');
    });

    it('should convert paragraph with links', async () => {
      const block: NotionBlock = {
        id: 'block-1',
        type: 'paragraph',
        object: 'block',
        created_time: '2023-01-01T00:00:00.000Z',
        last_edited_time: '2023-01-01T00:00:00.000Z',
        has_children: false,
        archived: false,
        paragraph: {
          rich_text: [
            { 
              plain_text: 'Visit our website',
              href: 'https://example.com'
            }
          ]
        }
      };

      const result = await converter.convertBlocks([block], mockMetadata);

      expect(result.markdown).toContain('[Visit our website](https://example.com)');
    });

    it('should skip empty paragraphs', async () => {
      const block: NotionBlock = {
        id: 'block-1',
        type: 'paragraph',
        object: 'block',
        created_time: '2023-01-01T00:00:00.000Z',
        last_edited_time: '2023-01-01T00:00:00.000Z',
        has_children: false,
        archived: false,
        paragraph: {
          rich_text: []
        }
      };

      const result = await converter.convertBlocks([block], mockMetadata);

      // Should only contain frontmatter, no paragraph content
      const lines = result.markdown.split('\n');
      const contentLines = lines.slice(lines.indexOf('---', 1) + 1).filter(line => line.trim());
      expect(contentLines).toHaveLength(0);
    });
  });

  describe('heading conversion', () => {
    const createHeadingBlock = (level: number, text: string): NotionBlock => ({
      id: `heading-${level}`,
      type: `heading_${level}`,
      object: 'block',
      created_time: '2023-01-01T00:00:00.000Z',
      last_edited_time: '2023-01-01T00:00:00.000Z',
      has_children: false,
      archived: false,
      [`heading_${level}`]: {
        rich_text: [{ plain_text: text }]
      }
    });

    it('should convert heading 1', async () => {
      const block = createHeadingBlock(1, 'Main Title');
      const result = await converter.convertBlocks([block], mockMetadata);
      expect(result.markdown).toContain('# Main Title');
    });

    it('should convert heading 2', async () => {
      const block = createHeadingBlock(2, 'Subtitle');
      const result = await converter.convertBlocks([block], mockMetadata);
      expect(result.markdown).toContain('## Subtitle');
    });

    it('should convert heading 3', async () => {
      const block = createHeadingBlock(3, 'Sub-subtitle');
      const result = await converter.convertBlocks([block], mockMetadata);
      expect(result.markdown).toContain('### Sub-subtitle');
    });
  });

  describe('list conversion', () => {
    it('should convert bulleted list items', async () => {
      const block: NotionBlock = {
        id: 'list-1',
        type: 'bulleted_list_item',
        object: 'block',
        created_time: '2023-01-01T00:00:00.000Z',
        last_edited_time: '2023-01-01T00:00:00.000Z',
        has_children: false,
        archived: false,
        bulleted_list_item: {
          rich_text: [{ plain_text: 'First item' }]
        }
      };

      const result = await converter.convertBlocks([block], mockMetadata);
      expect(result.markdown).toContain('- First item');
    });

    it('should convert numbered list items', async () => {
      const block: NotionBlock = {
        id: 'list-1',
        type: 'numbered_list_item',
        object: 'block',
        created_time: '2023-01-01T00:00:00.000Z',
        last_edited_time: '2023-01-01T00:00:00.000Z',
        has_children: false,
        archived: false,
        numbered_list_item: {
          rich_text: [{ plain_text: 'First numbered item' }]
        }
      };

      const result = await converter.convertBlocks([block], mockMetadata);
      expect(result.markdown).toContain('1. First numbered item');
    });

    it('should convert to-do items', async () => {
      const checkedBlock: NotionBlock = {
        id: 'todo-1',
        type: 'to_do',
        object: 'block',
        created_time: '2023-01-01T00:00:00.000Z',
        last_edited_time: '2023-01-01T00:00:00.000Z',
        has_children: false,
        archived: false,
        to_do: {
          rich_text: [{ plain_text: 'Completed task' }],
          checked: true
        }
      };

      const uncheckedBlock: NotionBlock = {
        id: 'todo-2',
        type: 'to_do',
        object: 'block',
        created_time: '2023-01-01T00:00:00.000Z',
        last_edited_time: '2023-01-01T00:00:00.000Z',
        has_children: false,
        archived: false,
        to_do: {
          rich_text: [{ plain_text: 'Pending task' }],
          checked: false
        }
      };

      const result = await converter.convertBlocks([checkedBlock, uncheckedBlock], mockMetadata);
      expect(result.markdown).toContain('- [x] Completed task');
      expect(result.markdown).toContain('- [ ] Pending task');
    });
  });

  describe('code conversion', () => {
    it('should convert code blocks', async () => {
      const block: NotionBlock = {
        id: 'code-1',
        type: 'code',
        object: 'block',
        created_time: '2023-01-01T00:00:00.000Z',
        last_edited_time: '2023-01-01T00:00:00.000Z',
        has_children: false,
        archived: false,
        code: {
          rich_text: [{ plain_text: 'console.log("Hello, World!");' }],
          language: 'javascript'
        }
      };

      const result = await converter.convertBlocks([block], mockMetadata);
      expect(result.markdown).toContain('```javascript\nconsole.log("Hello, World!");\n```');
    });

    it('should handle code blocks without language', async () => {
      const block: NotionBlock = {
        id: 'code-1',
        type: 'code',
        object: 'block',
        created_time: '2023-01-01T00:00:00.000Z',
        last_edited_time: '2023-01-01T00:00:00.000Z',
        has_children: false,
        archived: false,
        code: {
          rich_text: [{ plain_text: 'some code' }],
          language: ''
        }
      };

      const result = await converter.convertBlocks([block], mockMetadata);
      expect(result.markdown).toContain('```\nsome code\n```');
    });
  });

  describe('quote and callout conversion', () => {
    it('should convert quotes', async () => {
      const block: NotionBlock = {
        id: 'quote-1',
        type: 'quote',
        object: 'block',
        created_time: '2023-01-01T00:00:00.000Z',
        last_edited_time: '2023-01-01T00:00:00.000Z',
        has_children: false,
        archived: false,
        quote: {
          rich_text: [{ plain_text: 'This is a quote.' }]
        }
      };

      const result = await converter.convertBlocks([block], mockMetadata);
      expect(result.markdown).toContain('> This is a quote.');
    });

    it('should convert callouts', async () => {
      const block: NotionBlock = {
        id: 'callout-1',
        type: 'callout',
        object: 'block',
        created_time: '2023-01-01T00:00:00.000Z',
        last_edited_time: '2023-01-01T00:00:00.000Z',
        has_children: false,
        archived: false,
        callout: {
          rich_text: [{ plain_text: 'This is important!' }],
          icon: { emoji: '⚠️' }
        }
      };

      const result = await converter.convertBlocks([block], mockMetadata);
      expect(result.markdown).toContain('> ⚠️ This is important!');
    });

    it('should use default icon for callouts without icon', async () => {
      const block: NotionBlock = {
        id: 'callout-1',
        type: 'callout',
        object: 'block',
        created_time: '2023-01-01T00:00:00.000Z',
        last_edited_time: '2023-01-01T00:00:00.000Z',
        has_children: false,
        archived: false,
        callout: {
          rich_text: [{ plain_text: 'No icon callout' }]
        }
      };

      const result = await converter.convertBlocks([block], mockMetadata);
      expect(result.markdown).toContain('> 💡 No icon callout');
    });
  });

  describe('media conversion', () => {
    it('should convert image blocks with external URL', async () => {
      const block: NotionBlock = {
        id: 'image-1',
        type: 'image',
        object: 'block',
        created_time: '2023-01-01T00:00:00.000Z',
        last_edited_time: '2023-01-01T00:00:00.000Z',
        has_children: false,
        archived: false,
        image: {
          external: { url: 'https://example.com/image.png' },
          caption: [{ plain_text: 'Sample image' }]
        }
      };

      const result = await converter.convertBlocks([block], mockMetadata);
      
      expect(result.markdown).toContain('![Sample image](attachments/image.png)');
      expect(result.attachments).toHaveLength(1);
      expect(result.attachments[0]).toMatchObject({
        originalUrl: 'https://example.com/image.png',
        localPath: 'attachments/image.png',
        type: 'image',
        downloaded: false
      });
    });

    it('should convert file blocks', async () => {
      const block: NotionBlock = {
        id: 'file-1',
        type: 'file',
        object: 'block',
        created_time: '2023-01-01T00:00:00.000Z',
        last_edited_time: '2023-01-01T00:00:00.000Z',
        has_children: false,
        archived: false,
        file: {
          file: { url: 'https://example.com/document.pdf' },
          caption: [{ plain_text: 'Important document' }]
        }
      };

      const result = await converter.convertBlocks([block], mockMetadata);
      
      expect(result.markdown).toContain('[Important document](attachments/document.pdf)');
      expect(result.attachments).toHaveLength(1);
      expect(result.attachments[0].type).toBe('file');
    });

    it('should handle media blocks without URL', async () => {
      const block: NotionBlock = {
        id: 'image-1',
        type: 'image',
        object: 'block',
        created_time: '2023-01-01T00:00:00.000Z',
        last_edited_time: '2023-01-01T00:00:00.000Z',
        has_children: false,
        archived: false,
        image: {}
      };

      const result = await converter.convertBlocks([block], mockMetadata);
      
      expect(result.markdown).toContain('<!-- Missing image URL -->');
      expect(result.attachments).toHaveLength(0);
    });
  });

  describe('other block types', () => {
    it('should convert dividers', async () => {
      const block: NotionBlock = {
        id: 'divider-1',
        type: 'divider',
        object: 'block',
        created_time: '2023-01-01T00:00:00.000Z',
        last_edited_time: '2023-01-01T00:00:00.000Z',
        has_children: false,
        archived: false
      };

      const result = await converter.convertBlocks([block], mockMetadata);
      expect(result.markdown).toContain('---');
    });

    it('should convert equations', async () => {
      const block: NotionBlock = {
        id: 'equation-1',
        type: 'equation',
        object: 'block',
        created_time: '2023-01-01T00:00:00.000Z',
        last_edited_time: '2023-01-01T00:00:00.000Z',
        has_children: false,
        archived: false,
        equation: {
          expression: 'E = mc^2'
        }
      };

      const result = await converter.convertBlocks([block], mockMetadata);
      expect(result.markdown).toContain('$$E = mc^2$$');
    });

    it('should convert bookmarks', async () => {
      const block: NotionBlock = {
        id: 'bookmark-1',
        type: 'bookmark',
        object: 'block',
        created_time: '2023-01-01T00:00:00.000Z',
        last_edited_time: '2023-01-01T00:00:00.000Z',
        has_children: false,
        archived: false,
        bookmark: {
          url: 'https://example.com',
          caption: [{ plain_text: 'Example website' }]
        }
      };

      const result = await converter.convertBlocks([block], mockMetadata);
      expect(result.markdown).toContain('[Example website](https://example.com)');
    });

    it('should convert toggles', async () => {
      const block: NotionBlock = {
        id: 'toggle-1',
        type: 'toggle',
        object: 'block',
        created_time: '2023-01-01T00:00:00.000Z',
        last_edited_time: '2023-01-01T00:00:00.000Z',
        has_children: false,
        archived: false,
        toggle: {
          rich_text: [{ plain_text: 'Click to expand' }]
        }
      };

      const result = await converter.convertBlocks([block], mockMetadata);
      expect(result.markdown).toContain('<details><summary>Click to expand</summary>');
    });
  });

  describe('nested blocks', () => {
    it('should handle nested blocks with proper indentation', async () => {
      const childBlock: NotionBlock = {
        id: 'child-1',
        type: 'paragraph',
        object: 'block',
        created_time: '2023-01-01T00:00:00.000Z',
        last_edited_time: '2023-01-01T00:00:00.000Z',
        has_children: false,
        archived: false,
        paragraph: {
          rich_text: [{ plain_text: 'Nested content' }]
        }
      };

      const parentBlock: NotionBlock = {
        id: 'parent-1',
        type: 'bulleted_list_item',
        object: 'block',
        created_time: '2023-01-01T00:00:00.000Z',
        last_edited_time: '2023-01-01T00:00:00.000Z',
        has_children: true,
        archived: false,
        bulleted_list_item: {
          rich_text: [{ plain_text: 'Parent item' }]
        },
        children: [childBlock]
      };

      const result = await converter.convertBlocks([parentBlock], mockMetadata);
      
      expect(result.markdown).toContain('- Parent item');
      expect(result.markdown).toContain('  Nested content');
    });
  });

  describe('unsupported blocks', () => {
    it('should handle unsupported block types gracefully', async () => {
      const block: NotionBlock = {
        id: 'unsupported-1',
        type: 'unsupported_type',
        object: 'block',
        created_time: '2023-01-01T00:00:00.000Z',
        last_edited_time: '2023-01-01T00:00:00.000Z',
        has_children: false,
        archived: false
      };

      const result = await converter.convertBlocks([block], mockMetadata);
      
      expect(result.markdown).toContain('<!-- Unsupported block type: unsupported_type -->');
      expect(result.errors).toHaveLength(1);
      expect(result.errors[0]).toMatchObject({
        type: 'CONVERSION',
        message: 'Unsupported block type: unsupported_type',
        blockId: 'unsupported-1',
        retryable: false
      });
    });
  });

  describe('error handling', () => {
    it('should handle conversion errors gracefully', async () => {
      // Create a block that will cause an error during conversion
      const problematicBlock: NotionBlock = {
        id: 'error-block',
        type: 'paragraph',
        object: 'block',
        created_time: '2023-01-01T00:00:00.000Z',
        last_edited_time: '2023-01-01T00:00:00.000Z',
        has_children: false,
        archived: false,
        paragraph: null as any // This will cause an error
      };

      const result = await converter.convertBlocks([problematicBlock], mockMetadata);
      
      expect(result.errors).toHaveLength(1);
      expect(result.errors[0].type).toBe('CONVERSION');
      expect(result.errors[0].blockId).toBe('error-block');
    });

    it('should continue processing after individual block errors', async () => {
      const goodBlock: NotionBlock = {
        id: 'good-block',
        type: 'paragraph',
        object: 'block',
        created_time: '2023-01-01T00:00:00.000Z',
        last_edited_time: '2023-01-01T00:00:00.000Z',
        has_children: false,
        archived: false,
        paragraph: {
          rich_text: [{ plain_text: 'Good content' }]
        }
      };

      const badBlock: NotionBlock = {
        id: 'bad-block',
        type: 'paragraph',
        object: 'block',
        created_time: '2023-01-01T00:00:00.000Z',
        last_edited_time: '2023-01-01T00:00:00.000Z',
        has_children: false,
        archived: false,
        paragraph: null as any
      };

      const result = await converter.convertBlocks([goodBlock, badBlock], mockMetadata);
      
      expect(result.markdown).toContain('Good content');
      expect(result.errors).toHaveLength(1);
    });
  });

  describe('rich text formatting combinations', () => {
    it('should handle multiple formatting annotations', async () => {
      const block: NotionBlock = {
        id: 'rich-1',
        type: 'paragraph',
        object: 'block',
        created_time: '2023-01-01T00:00:00.000Z',
        last_edited_time: '2023-01-01T00:00:00.000Z',
        has_children: false,
        archived: false,
        paragraph: {
          rich_text: [
            { 
              plain_text: 'bold and italic',
              annotations: { 
                bold: true, 
                italic: true, 
                strikethrough: false, 
                underline: false, 
                code: false 
              }
            }
          ]
        }
      };

      const result = await converter.convertBlocks([block], mockMetadata);
      expect(result.markdown).toContain('***bold and italic***');
    });

    it('should handle strikethrough', async () => {
      const block: NotionBlock = {
        id: 'strike-1',
        type: 'paragraph',
        object: 'block',
        created_time: '2023-01-01T00:00:00.000Z',
        last_edited_time: '2023-01-01T00:00:00.000Z',
        has_children: false,
        archived: false,
        paragraph: {
          rich_text: [
            { 
              plain_text: 'struck through',
              annotations: { 
                bold: false, 
                italic: false, 
                strikethrough: true, 
                underline: false, 
                code: false 
              }
            }
          ]
        }
      };

      const result = await converter.convertBlocks([block], mockMetadata);
      expect(result.markdown).toContain('~~struck through~~');
    });

    it('should handle underline', async () => {
      const block: NotionBlock = {
        id: 'underline-1',
        type: 'paragraph',
        object: 'block',
        created_time: '2023-01-01T00:00:00.000Z',
        last_edited_time: '2023-01-01T00:00:00.000Z',
        has_children: false,
        archived: false,
        paragraph: {
          rich_text: [
            { 
              plain_text: 'underlined',
              annotations: { 
                bold: false, 
                italic: false, 
                strikethrough: false, 
                underline: true, 
                code: false 
              }
            }
          ]
        }
      };

      const result = await converter.convertBlocks([block], mockMetadata);
      expect(result.markdown).toContain('<u>underlined</u>');
    });

    it('should handle inline code', async () => {
      const block: NotionBlock = {
        id: 'code-1',
        type: 'paragraph',
        object: 'block',
        created_time: '2023-01-01T00:00:00.000Z',
        last_edited_time: '2023-01-01T00:00:00.000Z',
        has_children: false,
        archived: false,
        paragraph: {
          rich_text: [
            { 
              plain_text: 'console.log()',
              annotations: { 
                bold: false, 
                italic: false, 
                strikethrough: false, 
                underline: false, 
                code: true 
              }
            }
          ]
        }
      };

      const result = await converter.convertBlocks([block], mockMetadata);
      expect(result.markdown).toContain('`console.log()`');
    });
  });
});