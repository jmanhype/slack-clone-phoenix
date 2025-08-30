# Platform Scripts Directory

## Purpose
Core automation scripts for experiment lifecycle management.

## Allowed Operations
- ✅ Read and execute all scripts
- ✅ Update script parameters and configurations
- ✅ Add new automation scripts
- ✅ Debug and test script functionality
- ⚠️ Modify core scripts only with testing
- ❌ Delete essential lifecycle scripts

## Core Scripts

### create-experiment.ts
- Experiment scaffolding and initialization
- TypeScript project structure generation
- Registry metadata management
- Validation of experiment names and structure

### verify.ts
- Comprehensive experiment validation
- File structure verification
- Dependency checking
- Test execution validation
- Registry consistency checks

### run-pipeline.ts
- Pipeline orchestration and execution
- Stage management with timeouts
- Environment variable handling
- Multiple pipeline types (build, test, full, experiment)
- Retry logic and error handling

## Primary Agents
- `coder` - Script implementation and updates
- `backend-dev` - Node.js/TypeScript development
- `cicd-engineer` - Pipeline automation
- `tester` - Script testing and validation

## Script Standards
- Use TypeScript for type safety
- Include comprehensive error handling
- Support verbose and dry-run modes
- Log all operations to NDJSON format
- Validate inputs and environment

## Execution Context
All scripts run with:
- Node.js runtime environment
- Access to platform configuration
- Registry read/write permissions
- Environment variable access
- Git context available

## Testing Scripts
```bash
# Test script functionality
npx tsx scripts/create-experiment.ts --help
npx tsx scripts/verify.ts --dry-run
npx tsx scripts/run-pipeline.ts --test
```

## Dependencies
- tsx for TypeScript execution
- Node.js standard libraries
- Platform configuration access
- Registry file system access

## Best Practices
1. Always validate inputs before processing
2. Use proper error codes (0=success, 1=warning, 2=error)
3. Log operations for audit trails
4. Support configuration overrides
5. Test with various experiment types
