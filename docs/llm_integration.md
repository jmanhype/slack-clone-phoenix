# LLM Integration Guide

## Overview

The Experiments Platform supports integration with multiple LLM providers through a unified interface.

## Supported Providers

### Claude (Anthropic)
```typescript
{
  provider: "claude",
  model: "claude-3-opus",
  apiKey: process.env.ANTHROPIC_API_KEY
}
```

### OpenAI
```typescript
{
  provider: "openai",
  model: "gpt-4",
  apiKey: process.env.OPENAI_API_KEY
}
```

### Local Models
```typescript
{
  provider: "local",
  endpoint: "http://localhost:11434",
  model: "llama2"
}
```

## Configuration

### Environment Variables

Create `.env` file:
```bash
ANTHROPIC_API_KEY=sk-ant-...
OPENAI_API_KEY=sk-...
```

### Experiment Config

In `config.yaml`:
```yaml
parameters:
  model:
    provider: "claude"
    version: "3.5"
    temperature: 0.7
    max_tokens: 4096
    top_p: 0.95
    frequency_penalty: 0
    presence_penalty: 0
```

## Prompt Engineering

### Using Prompt Templates

The platform uses three prompt templates:

1. **System Prompt** (`promptkit/system.md`)
   - Core instructions
   - Safety guidelines
   - Output format

2. **Development Prompt** (`promptkit/dev.md`)
   - Debug features
   - Verbose logging
   - Testing tools

3. **Production Prompt** (`promptkit/run.md`)
   - Optimized performance
   - Strict validation
   - NDJSON logging

### Variable Substitution

Templates support variables:
```markdown
# Task: {{TASK_NAME}}
Input: {{INPUT_DATA}}
Expected: {{EXPECTED_OUTPUT}}
```

Substituted at runtime:
```typescript
const prompt = template
  .replace('{{TASK_NAME}}', 'Classification')
  .replace('{{INPUT_DATA}}', data)
  .replace('{{EXPECTED_OUTPUT}}', 'category');
```

## Request/Response Format

### Request Structure
```json
{
  "model": "claude-3.5",
  "messages": [
    {
      "role": "system",
      "content": "System prompt..."
    },
    {
      "role": "user",
      "content": "User input..."
    }
  ],
  "temperature": 0.7,
  "max_tokens": 1000
}
```

### Response Handling
```typescript
interface LLMResponse {
  id: string;
  model: string;
  choices: Array<{
    message: {
      role: string;
      content: string;
    };
    finish_reason: string;
  }>;
  usage: {
    prompt_tokens: number;
    completion_tokens: number;
    total_tokens: number;
  };
}
```

## Streaming Responses

### Enable Streaming
```typescript
{
  stream: true,
  onChunk: (chunk: string) => {
    process.stdout.write(chunk);
  }
}
```

### Process Stream
```typescript
const stream = await llm.stream(prompt);
for await (const chunk of stream) {
  // Process each chunk
  results.push(processChunk(chunk));
}
```

## Error Handling

### Retry Logic
```typescript
const retry = async (fn: Function, retries = 3) => {
  for (let i = 0; i < retries; i++) {
    try {
      return await fn();
    } catch (error) {
      if (i === retries - 1) throw error;
      await sleep(Math.pow(2, i) * 1000);
    }
  }
};
```

### Error Types
- **RateLimitError**: Back off exponentially
- **TokenLimitError**: Reduce max_tokens
- **TimeoutError**: Increase timeout
- **ValidationError**: Fix prompt format

## Performance Optimization

### Batching Requests
```typescript
const batchProcess = async (items: any[], batchSize = 10) => {
  const results = [];
  for (let i = 0; i < items.length; i += batchSize) {
    const batch = items.slice(i, i + batchSize);
    const batchResults = await Promise.all(
      batch.map(item => processItem(item))
    );
    results.push(...batchResults);
  }
  return results;
};
```

### Caching Responses
```typescript
const cache = new Map();

const cachedLLM = async (prompt: string) => {
  const key = hash(prompt);
  if (cache.has(key)) {
    return cache.get(key);
  }
  const result = await llm.complete(prompt);
  cache.set(key, result);
  return result;
};
```

### Token Optimization
- Use shorter prompts when possible
- Remove redundant examples
- Compress context information
- Stream for long outputs

## Monitoring

### Metrics to Track
```typescript
{
  "request_id": "uuid",
  "timestamp": "ISO-8601",
  "provider": "claude",
  "model": "3.5",
  "prompt_tokens": 150,
  "completion_tokens": 350,
  "total_tokens": 500,
  "latency_ms": 1234,
  "status": "success",
  "truth_score": 0.97
}
```

### Logging Best Practices
1. Log all requests/responses
2. Track token usage
3. Monitor latency
4. Record errors
5. Calculate costs

## Testing

### Mock LLM for Testing
```typescript
class MockLLM {
  async complete(prompt: string) {
    return {
      content: "Mock response",
      usage: { total_tokens: 100 }
    };
  }
}
```

### Integration Tests
```typescript
describe('LLM Integration', () => {
  it('should handle completions', async () => {
    const response = await llm.complete('Test prompt');
    expect(response.content).toBeDefined();
    expect(response.usage.total_tokens).toBeGreaterThan(0);
  });
});
```

## Cost Management

### Token Limits
```yaml
limits:
  daily_tokens: 1000000
  request_tokens: 4096
  minute_tokens: 10000
```

### Cost Tracking
```typescript
const trackCost = (usage: Usage) => {
  const rate = 0.00002; // per token
  const cost = usage.total_tokens * rate;
  metrics.recordCost(cost);
  return cost;
};
```

## Security

### API Key Management
- Never commit API keys
- Use environment variables
- Rotate keys regularly
- Monitor usage

### Input Sanitization
```typescript
const sanitize = (input: string) => {
  return input
    .replace(/[<>]/g, '')
    .slice(0, MAX_LENGTH);
};
```

### Output Validation
```typescript
const validate = (output: any) => {
  const schema = getSchema();
  if (!schema.validate(output)) {
    throw new ValidationError('Invalid output format');
  }
  return output;
};
```

## Best Practices

1. **Start simple**: Basic prompts first
2. **Iterate quickly**: Test and refine
3. **Monitor everything**: Track all metrics
4. **Handle failures**: Graceful degradation
5. **Optimize costs**: Minimize token usage
6. **Document prompts**: Version control
7. **Test thoroughly**: Unit and integration
8. **Secure keys**: Environment variables