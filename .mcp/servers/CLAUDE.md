# MCP Servers Configuration Directory

## Purpose
Individual MCP server configurations and tool definitions.

## Allowed Operations
- ✅ Create new server configurations
- ✅ Update existing server settings
- ✅ Add tool schemas and definitions
- ✅ Configure server-specific permissions
- ⚠️ Modify core tool schemas carefully
- ❌ Break compatibility with existing tools

## Server Types

### search/
- Web search tools
- Document retrieval
- Content indexing
- Query processing

### repo/
- Git operations
- Issue management
- PR handling
- Repository analysis

### data/
- Data loading and streaming
- Format conversion
- Batch processing
- Pipeline operations

### exec/
- Command execution
- Process management
- Environment setup
- Resource monitoring

## Primary Agents
- `api-docs` - Schema documentation
- `backend-dev` - Server implementation
- `system-architect` - Architecture design

## Configuration Format
Each server directory contains:
- `config.yaml` - Server configuration
- `tools.yaml` - Tool definitions
- `schema.json` - Input/output schemas
- `permissions.yaml` - Security settings

## Tool Schema Pattern
```yaml
tool_name:
  description: "Tool description"
  input:
    type: object
    properties:
      param1: {type: string}
      param2: {type: number}
  output:
    type: object
    properties:
      result: {type: string}
```

## Best Practices
1. Keep schemas simple and versioned
2. Validate all inputs and outputs
3. Document tool usage patterns
4. Test with different client versions
5. Monitor performance and errors