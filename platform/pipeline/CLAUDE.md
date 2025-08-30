# Platform Pipeline Directory

## Purpose
Pipeline processing components with backpressure support and streaming capabilities.

## Allowed Operations
- ✅ Read and use pipeline components
- ✅ Update pipeline configurations
- ✅ Add new pipeline stages
- ✅ Monitor pipeline performance
- ⚠️ Modify core pipeline logic with testing
- ❌ Break existing pipeline interfaces

## Pipeline Components

### chain.ts
- BackpressurePipeline class implementation
- Stream-chain integration for processing
- Concurrent processing with configurable limits
- Metrics tracking and performance monitoring
- Error handling and recovery

### ndjson.ts
- NDJSON streaming utilities
- Parse and write NDJSON data
- Backpressure-aware processing
- Memory-efficient streaming
- Batch processing support

## Primary Agents
- `backend-dev` - Pipeline implementation
- `system-architect` - Pipeline architecture
- `perf-analyzer` - Performance optimization
- `coder` - Component development

## Pipeline Features
- Backpressure management
- Concurrent processing limits
- Stream-based data handling
- Metrics collection
- Error recovery
- Memory efficiency

## Pipeline Types
- **build** - Code compilation and bundling
- **test** - Test execution and validation
- **full** - Complete CI/CD pipeline
- **experiment** - Experiment-specific processing

## Configuration
Pipeline behavior controlled by:
- `CONCURRENT_LIMIT` - Max concurrent operations
- `BACKPRESSURE_HIGH_WATERMARK` - Memory threshold
- `PIPELINE_TIMEOUT` - Processing timeout
- `RETRY_COUNT` - Error retry attempts

## Usage Examples
```typescript
import { BackpressurePipeline } from "./chain";
import { parseNDJSON, writeNDJSON } from "./ndjson";

// Create pipeline with backpressure
const pipeline = new BackpressurePipeline({
  concurrency: 10,
  highWaterMark: 1024 * 1024
});

// Process NDJSON data
const results = await parseNDJSON(stream)
  .pipe(pipeline)
  .pipe(writeNDJSON());
```

## Performance Monitoring
Pipeline components provide:
- Processing throughput metrics
- Memory usage tracking
- Error rate monitoring
- Backpressure event logging
- Stage timing analysis

## Best Practices
1. Monitor memory usage and backpressure
2. Set appropriate concurrency limits
3. Handle errors gracefully
4. Use streaming for large datasets
5. Test with realistic data volumes
