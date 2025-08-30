# Runtime Prompt Template

## Runtime Context

**System**: {SYSTEM_NAME}
**Version**: {SYSTEM_VERSION}
**Environment**: {RUNTIME_ENVIRONMENT} (Production | Staging | Development)
**Session ID**: {SESSION_ID}
**Timestamp**: {RUNTIME_TIMESTAMP}

### Runtime Objectives
- **Primary Goal**: {PRIMARY_GOAL}
- **Performance Target**: {PERFORMANCE_TARGET}
- **Quality Threshold**: {QUALITY_THRESHOLD}
- **Resource Limits**: {RESOURCE_LIMITS}

---

## Operational Parameters

### System Configuration
**Resource Allocation**:
- CPU: {CPU_ALLOCATION}
- Memory: {MEMORY_ALLOCATION}
- Storage: {STORAGE_ALLOCATION}
- Network: {NETWORK_BANDWIDTH}

**Performance Settings**:
- Max Concurrent Users: {MAX_CONCURRENT_USERS}
- Request Timeout: {REQUEST_TIMEOUT}
- Retry Policy: {RETRY_POLICY}
- Rate Limiting: {RATE_LIMITING}

### Service Level Agreements
**Availability**: {AVAILABILITY_TARGET}%
**Response Time**: {RESPONSE_TIME_TARGET}ms
**Throughput**: {THROUGHPUT_TARGET} requests/second
**Error Rate**: < {ERROR_RATE_TARGET}%

---

## Runtime Behavior

### Processing Pipeline
```
Input Validation → Authentication → Authorization → Processing → 
Response Generation → Logging → Monitoring
```

### Request Handling
**Standard Request Flow**:
1. **Receive**: {REQUEST_RECEPTION}
2. **Validate**: {INPUT_VALIDATION}
3. **Process**: {CORE_PROCESSING}
4. **Respond**: {RESPONSE_GENERATION}
5. **Log**: {LOGGING_ACTIONS}

### Response Patterns
**Success Response**:
```json
{
  "status": "success",
  "data": {
    "{DATA_FIELD_1}": "{DATA_VALUE_1}",
    "{DATA_FIELD_2}": "{DATA_VALUE_2}"
  },
  "metadata": {
    "requestId": "{REQUEST_ID}",
    "processingTime": "{PROCESSING_TIME_MS}ms",
    "timestamp": "{RESPONSE_TIMESTAMP}",
    "version": "{API_VERSION}"
  }
}
```

**Error Response**:
```json
{
  "status": "error",
  "error": {
    "code": "{ERROR_CODE}",
    "message": "{ERROR_MESSAGE}",
    "type": "{ERROR_TYPE}",
    "details": "{ERROR_DETAILS}"
  },
  "metadata": {
    "requestId": "{REQUEST_ID}",
    "timestamp": "{ERROR_TIMESTAMP}",
    "retryable": "{RETRYABLE_FLAG}"
  }
}
```

---

## Input Processing

### Input Validation
**Validation Rules**:
- {VALIDATION_RULE_1}
- {VALIDATION_RULE_2}
- {VALIDATION_RULE_3}

**Data Sanitization**:
- {SANITIZATION_RULE_1}
- {SANITIZATION_RULE_2}
- {SANITIZATION_RULE_3}

### Input Types and Handling
**Supported Input Types**:
- **Text**: {TEXT_INPUT_HANDLING}
- **JSON**: {JSON_INPUT_HANDLING}
- **Files**: {FILE_INPUT_HANDLING}
- **Streaming**: {STREAMING_INPUT_HANDLING}

**Content Filtering**:
- {CONTENT_FILTER_1}
- {CONTENT_FILTER_2}
- {CONTENT_FILTER_3}

### Rate Limiting and Throttling
**Rate Limit Policy**:
- Per User: {PER_USER_RATE_LIMIT}
- Per IP: {PER_IP_RATE_LIMIT}
- Global: {GLOBAL_RATE_LIMIT}

**Throttling Response**:
```json
{
  "status": "throttled",
  "error": {
    "code": "RATE_LIMIT_EXCEEDED",
    "message": "Rate limit exceeded. Please try again later.",
    "retryAfter": "{RETRY_AFTER_SECONDS}"
  }
}
```

---

## Core Processing Logic

### Processing Modes
**Mode 1: {PROCESSING_MODE_1}**
- **Use Case**: {MODE_1_USE_CASE}
- **Algorithm**: {MODE_1_ALGORITHM}
- **Performance**: {MODE_1_PERFORMANCE}

**Mode 2: {PROCESSING_MODE_2}**
- **Use Case**: {MODE_2_USE_CASE}
- **Algorithm**: {MODE_2_ALGORITHM}
- **Performance**: {MODE_2_PERFORMANCE}

### Decision Trees
```
Input Type Check → Processing Mode Selection → Resource Allocation → 
Algorithm Execution → Quality Check → Output Generation
```

### Optimization Strategies
**Performance Optimizations**:
- {OPTIMIZATION_1}
- {OPTIMIZATION_2}
- {OPTIMIZATION_3}

**Resource Management**:
- {RESOURCE_MGMT_1}
- {RESOURCE_MGMT_2}
- {RESOURCE_MGMT_3}

---

## Error Handling and Recovery

### Error Classification
**Error Categories**:
- **User Errors** (400-499): {USER_ERROR_HANDLING}
- **System Errors** (500-599): {SYSTEM_ERROR_HANDLING}
- **Network Errors**: {NETWORK_ERROR_HANDLING}
- **Timeout Errors**: {TIMEOUT_ERROR_HANDLING}

### Recovery Strategies
**Automatic Recovery**:
- **Retry Logic**: {RETRY_LOGIC}
- **Fallback Mechanisms**: {FALLBACK_MECHANISMS}
- **Circuit Breaker**: {CIRCUIT_BREAKER_LOGIC}

**Manual Recovery**:
- **Alert Triggers**: {ALERT_TRIGGERS}
- **Escalation Path**: {ESCALATION_PATH}
- **Recovery Procedures**: {RECOVERY_PROCEDURES}

### Graceful Degradation
**Service Levels**:
1. **Full Service**: {FULL_SERVICE_DESCRIPTION}
2. **Reduced Service**: {REDUCED_SERVICE_DESCRIPTION}
3. **Minimal Service**: {MINIMAL_SERVICE_DESCRIPTION}
4. **Maintenance Mode**: {MAINTENANCE_MODE_DESCRIPTION}

---

## Monitoring and Observability

### Metrics Collection
**Performance Metrics**:
- Response Time: {RESPONSE_TIME_COLLECTION}
- Throughput: {THROUGHPUT_COLLECTION}
- Error Rate: {ERROR_RATE_COLLECTION}
- Resource Usage: {RESOURCE_USAGE_COLLECTION}

**Business Metrics**:
- {BUSINESS_METRIC_1}: {METRIC_1_COLLECTION}
- {BUSINESS_METRIC_2}: {METRIC_2_COLLECTION}
- {BUSINESS_METRIC_3}: {METRIC_3_COLLECTION}

### Logging Strategy
**Log Levels**:
- **DEBUG**: {DEBUG_LOGGING}
- **INFO**: {INFO_LOGGING}
- **WARN**: {WARN_LOGGING}
- **ERROR**: {ERROR_LOGGING}
- **FATAL**: {FATAL_LOGGING}

**Log Format**:
```json
{
  "timestamp": "{TIMESTAMP}",
  "level": "{LOG_LEVEL}",
  "service": "{SERVICE_NAME}",
  "requestId": "{REQUEST_ID}",
  "message": "{LOG_MESSAGE}",
  "metadata": {
    "{METADATA_FIELD_1}": "{METADATA_VALUE_1}",
    "{METADATA_FIELD_2}": "{METADATA_VALUE_2}"
  }
}
```

### Health Checks
**Health Check Endpoints**:
- **Liveness**: {LIVENESS_CHECK}
- **Readiness**: {READINESS_CHECK}
- **Startup**: {STARTUP_CHECK}

**Health Check Response**:
```json
{
  "status": "healthy",
  "checks": {
    "database": "healthy",
    "cache": "healthy",
    "external_api": "degraded"
  },
  "uptime": "{UPTIME_SECONDS}",
  "timestamp": "{CHECK_TIMESTAMP}"
}
```

---

## Security Runtime Policies

### Authentication and Authorization
**Authentication Methods**:
- {AUTH_METHOD_1}: {AUTH_1_IMPLEMENTATION}
- {AUTH_METHOD_2}: {AUTH_2_IMPLEMENTATION}
- {AUTH_METHOD_3}: {AUTH_3_IMPLEMENTATION}

**Authorization Policies**:
```json
{
  "policies": [
    {
      "resource": "{RESOURCE_1}",
      "actions": ["{ACTION_1}", "{ACTION_2}"],
      "conditions": "{CONDITIONS_1}"
    }
  ]
}
```

### Security Headers
**Required Headers**:
```http
{SECURITY_HEADERS}
```

### Data Protection
**Encryption Standards**:
- Data in Transit: {ENCRYPTION_IN_TRANSIT}
- Data at Rest: {ENCRYPTION_AT_REST}
- Key Management: {KEY_MANAGEMENT}

**Privacy Controls**:
- {PRIVACY_CONTROL_1}
- {PRIVACY_CONTROL_2}
- {PRIVACY_CONTROL_3}

---

## Caching Strategy

### Cache Configuration
**Cache Levels**:
- **L1 (Application)**: {L1_CACHE_CONFIG}
- **L2 (Distributed)**: {L2_CACHE_CONFIG}
- **L3 (CDN)**: {L3_CACHE_CONFIG}

**Cache Policies**:
- **TTL**: {CACHE_TTL}
- **Eviction**: {CACHE_EVICTION_POLICY}
- **Invalidation**: {CACHE_INVALIDATION}

### Cache Keys and Strategies
**Key Patterns**:
- {CACHE_KEY_PATTERN_1}
- {CACHE_KEY_PATTERN_2}
- {CACHE_KEY_PATTERN_3}

**Caching Strategies**:
- **Cache-Aside**: {CACHE_ASIDE_USAGE}
- **Write-Through**: {WRITE_THROUGH_USAGE}
- **Write-Behind**: {WRITE_BEHIND_USAGE}

---

## Database Interactions

### Connection Management
**Connection Pool Configuration**:
- Pool Size: {DB_POOL_SIZE}
- Max Connections: {DB_MAX_CONNECTIONS}
- Timeout: {DB_CONNECTION_TIMEOUT}
- Retry Policy: {DB_RETRY_POLICY}

### Query Optimization
**Query Performance Guidelines**:
- {DB_QUERY_GUIDELINE_1}
- {DB_QUERY_GUIDELINE_2}
- {DB_QUERY_GUIDELINE_3}

### Transaction Management
**Transaction Policies**:
- **Isolation Level**: {TRANSACTION_ISOLATION}
- **Timeout**: {TRANSACTION_TIMEOUT}
- **Rollback Strategy**: {ROLLBACK_STRATEGY}

---

## External Service Integration

### API Integrations
**External Services**:
- **{SERVICE_1}**: {SERVICE_1_INTEGRATION}
- **{SERVICE_2}**: {SERVICE_2_INTEGRATION}
- **{SERVICE_3}**: {SERVICE_3_INTEGRATION}

### Circuit Breaker Configuration
**Circuit Breaker Settings**:
```json
{
  "failureThreshold": {FAILURE_THRESHOLD},
  "recoveryTimeout": "{RECOVERY_TIMEOUT}ms",
  "monitoringPeriod": "{MONITORING_PERIOD}ms",
  "expectedRecoveryTime": "{EXPECTED_RECOVERY_TIME}ms"
}
```

### Timeout and Retry Policies
**Service-Specific Timeouts**:
- {SERVICE_1}: {SERVICE_1_TIMEOUT}ms
- {SERVICE_2}: {SERVICE_2_TIMEOUT}ms
- {SERVICE_3}: {SERVICE_3_TIMEOUT}ms

---

## Resource Management

### Memory Management
**Memory Allocation**:
- Heap Size: {HEAP_SIZE}
- Garbage Collection: {GC_STRATEGY}
- Memory Monitoring: {MEMORY_MONITORING}

### CPU Management
**CPU Optimization**:
- Thread Pool Size: {THREAD_POOL_SIZE}
- CPU Throttling: {CPU_THROTTLING}
- Load Balancing: {LOAD_BALANCING}

### Storage Management
**Storage Policies**:
- {STORAGE_POLICY_1}
- {STORAGE_POLICY_2}
- {STORAGE_POLICY_3}

---

## Scaling and Load Management

### Auto-scaling Configuration
**Scaling Triggers**:
- CPU Usage > {CPU_SCALE_THRESHOLD}%
- Memory Usage > {MEMORY_SCALE_THRESHOLD}%
- Request Queue > {QUEUE_SCALE_THRESHOLD}

**Scaling Policies**:
- Scale Up: {SCALE_UP_POLICY}
- Scale Down: {SCALE_DOWN_POLICY}
- Cooldown: {SCALING_COOLDOWN}

### Load Balancing
**Load Balancing Algorithm**: {LOAD_BALANCING_ALGORITHM}
**Health Check Interval**: {HEALTH_CHECK_INTERVAL}
**Session Affinity**: {SESSION_AFFINITY}

---

## Disaster Recovery

### Backup Procedures
**Backup Schedule**: {BACKUP_SCHEDULE}
**Backup Retention**: {BACKUP_RETENTION}
**Backup Verification**: {BACKUP_VERIFICATION}

### Recovery Procedures
**RTO (Recovery Time Objective)**: {RTO}
**RPO (Recovery Point Objective)**: {RPO}
**Recovery Steps**: {RECOVERY_STEPS}

### Business Continuity
**Failover Strategy**: {FAILOVER_STRATEGY}
**Geographic Distribution**: {GEO_DISTRIBUTION}
**Data Replication**: {DATA_REPLICATION}

---

## Configuration Management

### Runtime Configuration
**Configuration Sources**:
- Environment Variables: {ENV_VAR_CONFIG}
- Configuration Files: {CONFIG_FILE_SOURCES}
- Remote Configuration: {REMOTE_CONFIG_SOURCES}

**Configuration Hot Reload**: {HOT_RELOAD_CAPABILITY}

### Feature Flags
**Feature Flag System**: {FEATURE_FLAG_SYSTEM}
**Flag Categories**:
- {FLAG_CATEGORY_1}: {FLAG_1_DESCRIPTION}
- {FLAG_CATEGORY_2}: {FLAG_2_DESCRIPTION}
- {FLAG_CATEGORY_3}: {FLAG_3_DESCRIPTION}

---

## Compliance and Audit

### Audit Logging
**Audit Events**:
- {AUDIT_EVENT_1}
- {AUDIT_EVENT_2}
- {AUDIT_EVENT_3}

**Audit Log Format**:
```json
{
  "eventType": "{AUDIT_EVENT_TYPE}",
  "timestamp": "{AUDIT_TIMESTAMP}",
  "actor": "{AUDIT_ACTOR}",
  "resource": "{AUDIT_RESOURCE}",
  "action": "{AUDIT_ACTION}",
  "outcome": "{AUDIT_OUTCOME}",
  "metadata": "{AUDIT_METADATA}"
}
```

### Compliance Frameworks
**Applicable Standards**:
- {COMPLIANCE_STANDARD_1}
- {COMPLIANCE_STANDARD_2}
- {COMPLIANCE_STANDARD_3}

---

## Performance Tuning

### Runtime Optimization
**JIT Compilation**: {JIT_OPTIMIZATION}
**Memory Optimization**: {MEMORY_OPTIMIZATION}
**I/O Optimization**: {IO_OPTIMIZATION}

### Profiling and Analysis
**Profiling Tools**: {PROFILING_TOOLS}
**Performance Baselines**: {PERFORMANCE_BASELINES}
**Optimization Targets**: {OPTIMIZATION_TARGETS}

---

## Troubleshooting Guide

### Common Runtime Issues
**Issue 1: High Latency**
- Symptoms: {HIGH_LATENCY_SYMPTOMS}
- Diagnosis: {HIGH_LATENCY_DIAGNOSIS}
- Resolution: {HIGH_LATENCY_RESOLUTION}

**Issue 2: Memory Leaks**
- Symptoms: {MEMORY_LEAK_SYMPTOMS}
- Diagnosis: {MEMORY_LEAK_DIAGNOSIS}
- Resolution: {MEMORY_LEAK_RESOLUTION}

**Issue 3: Connection Pool Exhaustion**
- Symptoms: {CONNECTION_POOL_SYMPTOMS}
- Diagnosis: {CONNECTION_POOL_DIAGNOSIS}
- Resolution: {CONNECTION_POOL_RESOLUTION}

### Diagnostic Commands
**System Diagnostics**:
```bash
{DIAGNOSTIC_COMMANDS}
```

---

**Runtime Prompt Version**: {RUNTIME_PROMPT_VERSION}
**Last Updated**: {LAST_UPDATE_DATE}
**Operations Contact**: {OPS_CONTACT}
**Emergency Contact**: {EMERGENCY_CONTACT}

---

*This runtime prompt provides comprehensive operational guidance for production systems. All parameters should be configured according to your specific deployment requirements and SLA commitments.*