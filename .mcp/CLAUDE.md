# MCP Servers Directory

## Purpose
MCP server configurations and schemas for tool coordination.

## Allowed Operations
- ✅ Read server configurations
- ✅ Update server schemas and settings
- ✅ Add new server directories
- ✅ Modify registry.yaml for new tools
- ⚠️ Remove servers only with dependency check
- ❌ Break existing tool schemas

## Directory Structure
```
.mcp/
├── registry.yaml       # Master server registry
├── servers/
│   ├── search/         # Search functionality
│   ├── repo/           # Repository management  
│   ├── data/           # Data processing
│   └── exec/           # Execution environment
```

## Primary Agents
- `api-docs` - Schema documentation
- `system-architect` - Server architecture
- `coder` - Configuration implementation

## Registry Schema
Each server entry includes:
- Tool definitions with input/output schemas
- Resource limits and permissions
- Health check endpoints
- Version compatibility

## Server Categories
- **search** - Web search, document retrieval
- **repo** - Git operations, issue management
- **data** - Data loading, transformation, streaming
- **exec** - Command execution, process management

## Schema Versioning
- Use `x-version` field for schema versions
- Maintain backward compatibility
- Document breaking changes
- Test with multiple client versions

## Security Considerations
- Validate all tool inputs
- Limit resource access per server
- Monitor execution permissions
- Audit tool usage patterns

## Adding New Servers
1. Create server directory
2. Define tool schemas
3. Update registry.yaml
4. Add health checks
5. Document usage patterns