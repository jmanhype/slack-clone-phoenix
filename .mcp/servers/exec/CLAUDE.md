# MCP exec Server Configuration

## Purpose
MCP server configuration for exec-related operations.

## Allowed Operations
- ✅ Update server configuration
- ✅ Modify tool schemas
- ✅ Add new tools and endpoints
- ✅ Configure permissions and limits
- ⚠️ Change core tool definitions with testing
- ❌ Break compatibility with existing clients

## Configuration Files
- `config.yaml` - Server configuration
- `tools.yaml` - Tool definitions  
- `schema.json` - Input/output schemas
- `permissions.yaml` - Security settings

## Primary Agents
- `api-docs` - Schema documentation
- `backend-dev` - Server implementation
- `system-architect` - Architecture design

## Server Functionality
exec-specific operations and tool implementations.

## Best Practices
1. Validate all schema changes
2. Test with multiple clients
3. Document tool usage patterns
4. Monitor performance metrics
5. Maintain backward compatibility
