# MCP Tools Documentation

## Overview

The Model Context Protocol (MCP) provides a standardized way to expose tools to AI models. This platform implements MCP servers for search, repository, data, and execution operations.

## Architecture

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│   Claude    │────▶│  MCP Client  │────▶│ MCP Servers │
└─────────────┘     └──────────────┘     └─────────────┘
                           │                     │
                           ▼                     ▼
                    ┌──────────────┐     ┌─────────────┐
                    │ Experiments  │     │   Tools     │
                    └──────────────┘     └─────────────┘
```

## Available Servers

### Search Server

**Path**: `.mcp/servers/search`

**Tools**:
- `search_code`: Search code files
- `search_docs`: Search documentation

**Usage**:
```json
{
  "tool": "search_code",
  "params": {
    "query": "function verify",
    "path": "platform/",
    "max_results": 10
  }
}
```

### Repository Server

**Path**: `.mcp/servers/repo`

**Tools**:
- `list_files`: List directory contents
- `read_file`: Read file content
- `write_file`: Write to file

**Usage**:
```json
{
  "tool": "read_file",
  "params": {
    "path": "experiments/test/config.yaml"
  }
}
```

### Data Server

**Path**: `.mcp/servers/data`

**Tools**:
- `process_ndjson`: Process NDJSON streams
- `analyze_metrics`: Analyze experiment metrics

**Usage**:
```json
{
  "tool": "process_ndjson",
  "params": {
    "input": "runs/input.ndjson",
    "output": "runs/output.ndjson",
    "transform": "filter:status=success"
  }
}
```

### Execution Server

**Path**: `.mcp/servers/exec`

**Tools**:
- `run_experiment`: Execute experiment
- `run_pipeline`: Run data pipeline

**Usage**:
```json
{
  "tool": "run_experiment",
  "params": {
    "name": "my-experiment",
    "config": {
      "temperature": 0.7
    }
  }
}
```

## Client Configuration

### Timeouts and Retries

Configure in `.claude/mcp/clients.yaml`:

```yaml
clients:
  default:
    timeout: 30000
    retry:
      attempts: 3
      backoff: exponential
      
  search:
    timeout: 15000
    retry:
      attempts: 2
```

### Connection Settings

```yaml
settings:
  logging:
    level: info
    format: ndjson
  cache:
    enabled: true
    ttl: 3600
```

## Tool Schemas

### Schema Definition

Tools are defined in `.mcp/registry.yaml`:

```yaml
tools:
  - name: search_code
    schema:
      type: object
      required: [query]
      properties:
        query:
          type: string
          description: Search query
        path:
          type: string
          description: Path to search
```

### Schema Validation

All inputs are validated against schemas:

```typescript
const validateInput = (tool: string, params: any) => {
  const schema = getToolSchema(tool);
  const valid = ajv.validate(schema, params);
  if (!valid) {
    throw new ValidationError(ajv.errors);
  }
};
```

## Tool Implementation

### Basic Tool Structure

```typescript
export class SearchTool implements MCPTool {
  name = 'search_code';
  
  async execute(params: any): Promise<any> {
    const { query, path = '.', max_results = 10 } = params;
    
    // Implementation
    const results = await searchFiles(query, path);
    
    return {
      results: results.slice(0, max_results),
      total: results.length
    };
  }
}
```

### Error Handling

```typescript
async execute(params: any): Promise<any> {
  try {
    // Tool logic
    return { success: true, data };
  } catch (error) {
    return {
      success: false,
      error: error.message,
      code: error.code || 'UNKNOWN_ERROR'
    };
  }
}
```

## Advanced Features

### Tool Composition

Chain multiple tools:

```typescript
const pipeline = async (input: any) => {
  const searchResults = await tools.search_code({ query: input });
  const files = await Promise.all(
    searchResults.map(r => tools.read_file({ path: r.path }))
  );
  return tools.analyze_metrics({ data: files });
};
```

### Streaming Tools

For large data processing:

```typescript
export class StreamTool implements MCPTool {
  async *stream(params: any): AsyncGenerator<any> {
    const reader = new NDJSONReader(params.input);
    
    for await (const record of reader.read()) {
      const processed = await this.process(record);
      yield processed;
    }
  }
}
```

### Caching

Implement caching for expensive operations:

```typescript
const cache = new LRUCache({ max: 100, ttl: 3600000 });

async execute(params: any): Promise<any> {
  const key = JSON.stringify(params);
  
  if (cache.has(key)) {
    return cache.get(key);
  }
  
  const result = await this.compute(params);
  cache.set(key, result);
  return result;
}
```

## Security

### Permission Model

Tools check permissions before execution:

```typescript
const checkPermission = (tool: string, action: string) => {
  const allowlist = loadAllowlist();
  
  if (!allowlist.tools[tool]?.includes(action)) {
    throw new PermissionError(`Action ${action} not allowed for ${tool}`);
  }
};
```

### Input Sanitization

```typescript
const sanitizeParams = (params: any) => {
  // Remove dangerous characters
  if (typeof params === 'string') {
    return params.replace(/[;&|`$]/g, '');
  }
  
  // Recursively sanitize objects
  if (typeof params === 'object') {
    return Object.entries(params).reduce((acc, [key, value]) => {
      acc[key] = sanitizeParams(value);
      return acc;
    }, {});
  }
  
  return params;
};
```

## Monitoring

### Tool Metrics

Track tool usage:

```json
{
  "tool": "search_code",
  "timestamp": "2024-01-01T00:00:00Z",
  "duration_ms": 123,
  "success": true,
  "params_size": 45,
  "result_size": 1024
}
```

### Performance Monitoring

```typescript
const withMetrics = async (tool: MCPTool, params: any) => {
  const start = Date.now();
  
  try {
    const result = await tool.execute(params);
    
    metrics.record({
      tool: tool.name,
      duration: Date.now() - start,
      success: true
    });
    
    return result;
  } catch (error) {
    metrics.record({
      tool: tool.name,
      duration: Date.now() - start,
      success: false,
      error: error.message
    });
    
    throw error;
  }
};
```

## Testing

### Unit Tests

```typescript
describe('SearchTool', () => {
  it('should find matches', async () => {
    const tool = new SearchTool();
    const result = await tool.execute({
      query: 'test',
      path: 'tests/'
    });
    
    expect(result.results).toHaveLength(10);
    expect(result.total).toBeGreaterThan(0);
  });
});
```

### Integration Tests

```typescript
describe('MCP Integration', () => {
  it('should handle tool pipeline', async () => {
    const client = new MCPClient(config);
    
    await client.invoke('search_code', { query: 'function' });
    await client.invoke('read_file', { path: 'test.js' });
    
    const metrics = await client.invoke('analyze_metrics', {
      data: ['test.js']
    });
    
    expect(metrics).toBeDefined();
  });
});
```

## Best Practices

1. **Validate inputs**: Always validate against schema
2. **Handle errors**: Graceful failure with clear messages
3. **Cache results**: For expensive operations
4. **Stream data**: For large datasets
5. **Monitor usage**: Track metrics and performance
6. **Secure tools**: Check permissions and sanitize
7. **Test thoroughly**: Unit and integration tests
8. **Document tools**: Clear descriptions and examples
9. **Version schemas**: Track schema changes
10. **Rate limit**: Prevent abuse

## Troubleshooting

### Common Issues

**Tool not found**:
- Check `.mcp/registry.yaml`
- Verify server is running
- Check client configuration

**Timeout errors**:
- Increase timeout in `clients.yaml`
- Optimize tool performance
- Use streaming for large data

**Permission denied**:
- Check `allowlists.yaml`
- Verify tool permissions
- Review security policies

**Schema validation failed**:
- Check input format
- Review schema definition
- Validate before sending