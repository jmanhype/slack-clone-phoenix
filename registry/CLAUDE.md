# Registry Directory

## Purpose
Experiment registry and metadata tracking for platform coordination.

## Allowed Operations
- ✅ Read registry entries and metadata
- ✅ Add new experiment entries
- ✅ Update experiment status and metadata
- ✅ Query and search registry data
- ⚠️ Modify registry structure with validation
- ❌ Delete registry entries without proper archival

## Registry Structure
```
registry/
├── index.ndjson      # Main experiment registry
├── archived/         # Archived experiments
├── schemas/          # Registry schemas
└── backups/          # Registry backups
```

## Registry Format
Each registry entry is NDJSON format:
```json
{
  "name": "experiment-name",
  "description": "Experiment description", 
  "author": "Author Name",
  "created": "2024-01-01T00:00:00Z",
  "updated": "2024-01-01T00:00:00Z",
  "status": "active",
  "version": "1.0.0",
  "tags": ["ml", "research"],
  "truthScore": 0.95,
  "metadata": {}
}
```

## Primary Agents
- `researcher` - Registry analysis and queries
- `coder` - Registry management scripts
- `system-architect` - Registry schema design
- `api-docs` - Registry API documentation

## Registry Operations
- **Create** - Add new experiment entry
- **Update** - Modify existing entry metadata
- **Archive** - Move completed experiments
- **Search** - Query experiments by criteria
- **Validate** - Ensure registry consistency

## Status Values
- `active` - Currently being developed
- `testing` - In testing phase
- `completed` - Development finished
- `archived` - Moved to long-term storage
- `deprecated` - No longer maintained

## Registry Maintenance
- Daily backup of registry data
- Periodic validation of entry integrity
- Cleanup of orphaned entries
- Schema version management
- Performance monitoring

## Query Examples
```bash
# Find experiments by author
cat registry/index.ndjson | jq "select(.author == \"Author Name\")"

# Get active experiments
cat registry/index.ndjson | jq "select(.status == \"active\")"

# Find high-truth score experiments  
cat registry/index.ndjson | jq "select(.truthScore >= 0.95)"
```

## Best Practices
1. Always validate entries before adding
2. Include comprehensive metadata
3. Use consistent naming conventions
4. Regular registry cleanup and maintenance
5. Monitor registry performance and size
