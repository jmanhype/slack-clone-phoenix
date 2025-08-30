# Platform Templates Directory

## Purpose
Experiment templates and scaffolding structures for rapid development.

## Allowed Operations
- ✅ Create new experiment templates
- ✅ Update existing template structures
- ✅ Add template variables and configurations
- ✅ Test template generation
- ⚠️ Modify core template structure with validation
- ❌ Remove essential template files

## Template Structure
```
templates/
├── experiment/
│   ├── src/
│   ├── tests/
│   ├── docs/
│   ├── package.json
│   ├── tsconfig.json
│   └── README.md
```

## Template Features
- TypeScript project structure
- Jest testing framework
- ESLint and Prettier configuration
- Package.json with standard scripts
- README with experiment documentation
- Source and test directory structure

## Primary Agents
- `base-template-generator` - Template creation and maintenance
- `coder` - Template structure implementation
- `system-architect` - Template architecture design
- `tester` - Template validation

## Template Variables
Templates support variable substitution:
- `{{experiment-name}}` - Experiment identifier
- `{{experiment-description}}` - Human-readable description
- `{{author}}` - Experiment author
- `{{date}}` - Creation timestamp
- `{{platform-version}}` - Platform version

## Template Validation
All templates must include:
- Valid package.json with required fields
- TypeScript configuration
- Test structure with examples
- Documentation template
- Build and test scripts

## Creating New Templates
1. Create template directory structure
2. Add variable placeholders
3. Include all essential files
4. Test template generation
5. Document template usage

## Template Testing
```bash
# Test template generation
npx tsx scripts/create-experiment.ts test-template --template experiment
npx tsx scripts/verify.ts experiments/test-template
```

## Best Practices
1. Keep templates minimal but complete
2. Use consistent naming conventions
3. Include comprehensive documentation
4. Test templates with various names
5. Maintain backward compatibility
