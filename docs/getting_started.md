# Getting Started with Experiments Platform

## Overview

The Experiments Platform is a black-box research platform designed for running controlled AI experiments with full auditability and verification.

## Quick Start

### 1. Installation

```bash
# Clone the repository
git clone <repository-url>
cd experiments-platform

# Install dependencies
npm install

# Make scripts executable
chmod +x platform/scripts/*.ts
chmod +x .claude/hooks/*.sh
```

### 2. Create Your First Experiment

```bash
# Create a new experiment
npx ts-node platform/scripts/create-experiment.ts \
  "My First Experiment" \
  "Testing the platform capabilities" \
  "Your Name"
```

This creates:
- `experiments/my-first-experiment/` directory
- All required configuration files
- Entry in `registry/index.ndjson`

### 3. Configure the Experiment

Edit `experiments/my-first-experiment/config.yaml`:

```yaml
parameters:
  model:
    temperature: 0.7
    max_tokens: 1000
  validation:
    threshold: 0.95
```

### 4. Run the Experiment

```bash
# Run with verification
.claude/hooks/pre_run.sh && \
npx ts-node platform/scripts/run-pipeline.ts \
  experiments/my-first-experiment/data/input.ndjson \
  experiments/my-first-experiment/runs/run-001.ndjson
```

### 5. Verify Results

```bash
npx ts-node platform/scripts/verify.ts experiments/my-first-experiment
```

## Core Concepts

### Directory Structure

```
.
├── .claude/           # Claude-specific configuration
│   ├── hooks/        # Execution hooks
│   └── mcp/          # MCP client config
├── .mcp/             # MCP server definitions
│   ├── registry.yaml # Tool registry
│   └── servers/      # Server implementations
├── platform/         # Core platform code
│   ├── templates/    # Experiment templates
│   ├── scripts/      # Utility scripts
│   └── pipeline/     # Stream processing
├── experiments/      # Your experiments
├── registry/         # Experiment registry
└── docs/            # Documentation
```

### Experiment Lifecycle

1. **Creation**: Generate from templates
2. **Configuration**: Set parameters
3. **Execution**: Run with pipeline
4. **Verification**: Check truth scores
5. **Analysis**: Review results

### NDJSON Logging

All runs produce NDJSON logs:

```json
{"timestamp":"2024-01-01T00:00:00Z","status":"success","metrics":{"truth_score":0.98}}
{"timestamp":"2024-01-01T00:00:01Z","status":"success","metrics":{"truth_score":0.96}}
```

### Verification Gates

The platform enforces quality through verification:
- Truth score must be ≥ 0.95
- All required fields must be present
- Performance must meet thresholds

## Best Practices

1. **Always verify** before committing results
2. **Use templates** for consistency
3. **Log everything** in NDJSON format
4. **Monitor metrics** continuously
5. **Document experiments** thoroughly

## Common Tasks

### Running Multiple Experiments

```bash
for exp in experiments/*/; do
  npx ts-node platform/scripts/verify.ts "$exp"
done
```

### Processing Results

```bash
# Merge all run logs
cat experiments/*/runs/*.ndjson > all-runs.ndjson

# Filter by status
jq -c 'select(.status == "success")' all-runs.ndjson
```

### Cleaning Up

```bash
# Remove failed runs
find experiments -name "*.ndjson" -exec \
  jq -c 'select(.status != "failure")' {} \; > cleaned.ndjson
```

## Troubleshooting

### Verification Failures

If verification fails:
1. Check `registry/index.ndjson` for truth scores
2. Review run logs in `experiments/*/runs/`
3. Ensure all required files exist

### Pipeline Errors

Common issues:
- **Backpressure**: Reduce `maxConcurrency`
- **Memory**: Process in smaller batches
- **Timeouts**: Increase timeout values

## Next Steps

- Read [LLM Integration Guide](llm_integration.md)
- Explore [MCP Tools Documentation](mcp_tools.md)
- Review example experiments in `experiments/`