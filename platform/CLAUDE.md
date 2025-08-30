# Platform Directory - Core System Components

## Purpose
Core platform infrastructure - scripts, templates, pipelines, and policies.

## Allowed Operations
- ✅ Read all platform files
- ✅ Execute scripts with proper permissions
- ✅ Update template content
- ✅ Modify pipeline configurations
- ⚠️ Change core scripts only with testing
- ❌ Experiments may NOT edit platform/ (black-box separation)

## Directory Structure
```
platform/
├── scripts/        # Automation scripts
├── templates/      # Experiment templates
├── pipeline/       # Processing pipelines
└── policy/         # Security and verification policies
```

## Primary Agents
- `system-architect` - Platform architecture
- `coder` - Script implementation
- `security-manager` - Policy enforcement
- `base-template-generator` - Template creation

## Black-Box Principle
**CRITICAL**: Experiments must treat platform/ as black-box:
- Experiments use platform tools but cannot modify them
- Platform provides stable APIs through scripts
- Changes to platform require proper testing
- Version platform components for compatibility

## Platform APIs
Scripts provide stable interfaces:
- `create-experiment.ts` - Experiment scaffolding
- `verify.ts` - Validation and verification
- `run-pipeline.ts` - Pipeline execution

## Versioning Strategy
- Semantic versioning for all components
- Backward compatibility guarantees
- Migration guides for breaking changes
- API stability for experiment isolation

## Development Guidelines
1. Test all changes thoroughly
2. Maintain API compatibility
3. Document breaking changes
4. Use TypeScript for type safety
5. Follow security best practices

## Security Boundaries
- Platform components run with elevated permissions
- Experiments run in sandboxed environment
- Policy files define security boundaries
- Verification gates enforce compliance