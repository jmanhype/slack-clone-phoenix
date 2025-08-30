# Development Prompt Template

## Development Context

**Project**: {PROJECT_NAME}
**Phase**: {DEVELOPMENT_PHASE} (Planning | Development | Testing | Deployment | Maintenance)
**Sprint**: {SPRINT_NUMBER}
**Environment**: {ENVIRONMENT} (Development | Staging | Production)

### Development Objectives
1. {OBJECTIVE_1}
2. {OBJECTIVE_2}
3. {OBJECTIVE_3}

### Success Criteria
- {SUCCESS_CRITERION_1}
- {SUCCESS_CRITERION_2}
- {SUCCESS_CRITERION_3}

---

## Technical Specifications

### Technology Stack
**Frontend**: {FRONTEND_TECH}
**Backend**: {BACKEND_TECH}
**Database**: {DATABASE_TECH}
**Infrastructure**: {INFRASTRUCTURE_TECH}
**DevOps**: {DEVOPS_TOOLS}

### Architecture Pattern
**Pattern**: {ARCHITECTURE_PATTERN} (MVC, Microservices, Serverless, Monolithic)
**Design Principles**: {DESIGN_PRINCIPLES}
**Integration Style**: {INTEGRATION_STYLE}

### Development Standards
**Code Style**: {CODE_STYLE_GUIDE}
**Testing Strategy**: {TESTING_STRATEGY}
**Documentation**: {DOCUMENTATION_STANDARD}
**Version Control**: {VERSION_CONTROL_STRATEGY}

---

## Development Guidelines

### Coding Standards
```{PROGRAMMING_LANGUAGE}
// Example code structure following project conventions
{CODE_EXAMPLE_1}

// Error handling pattern
{ERROR_HANDLING_EXAMPLE}

// Documentation format
{DOCUMENTATION_EXAMPLE}
```

### Best Practices
**Code Quality**:
- {QUALITY_PRACTICE_1}
- {QUALITY_PRACTICE_2}
- {QUALITY_PRACTICE_3}

**Security**:
- {SECURITY_PRACTICE_1}
- {SECURITY_PRACTICE_2}
- {SECURITY_PRACTICE_3}

**Performance**:
- {PERFORMANCE_PRACTICE_1}
- {PERFORMANCE_PRACTICE_2}
- {PERFORMANCE_PRACTICE_3}

### Design Patterns
**Recommended Patterns**:
- {PATTERN_1}: {PATTERN_1_USE_CASE}
- {PATTERN_2}: {PATTERN_2_USE_CASE}
- {PATTERN_3}: {PATTERN_3_USE_CASE}

**Anti-Patterns to Avoid**:
- {ANTI_PATTERN_1}: {ANTI_PATTERN_1_REASON}
- {ANTI_PATTERN_2}: {ANTI_PATTERN_2_REASON}

---

## Feature Development Process

### User Story Analysis
When implementing a feature, analyze:
1. **User Need**: {USER_NEED_ANALYSIS}
2. **Acceptance Criteria**: {ACCEPTANCE_CRITERIA_FORMAT}
3. **Edge Cases**: {EDGE_CASE_CONSIDERATIONS}
4. **Integration Points**: {INTEGRATION_ANALYSIS}

### Development Workflow
```
Story Analysis → Design → Implementation → Testing → Code Review → Deployment
```

**Implementation Steps**:
1. **Plan**: {PLANNING_APPROACH}
2. **Design**: {DESIGN_APPROACH}
3. **Code**: {CODING_APPROACH}
4. **Test**: {TESTING_APPROACH}
5. **Document**: {DOCUMENTATION_APPROACH}

### Code Structure Template
```{PROGRAMMING_LANGUAGE}
{FILE_HEADER_TEMPLATE}

{IMPORT_SECTION}

{CONSTANTS_SECTION}

{CLASS_OR_MODULE_STRUCTURE}

{MAIN_IMPLEMENTATION}

{HELPER_FUNCTIONS}

{EXPORT_SECTION}
```

---

## Testing Strategy

### Testing Pyramid
```
    /\
   /  \    E2E Tests (10%)
  /____\   Integration Tests (20%)
 /______\  Unit Tests (70%)
```

### Test Types and Coverage
**Unit Tests**:
- **Target Coverage**: {UNIT_TEST_COVERAGE}%
- **Framework**: {UNIT_TEST_FRAMEWORK}
- **Patterns**: {UNIT_TEST_PATTERNS}

**Integration Tests**:
- **Scope**: {INTEGRATION_TEST_SCOPE}
- **Framework**: {INTEGRATION_TEST_FRAMEWORK}
- **Data Strategy**: {TEST_DATA_STRATEGY}

**End-to-End Tests**:
- **Critical Paths**: {E2E_CRITICAL_PATHS}
- **Framework**: {E2E_TEST_FRAMEWORK}
- **Environment**: {E2E_TEST_ENVIRONMENT}

### Test-Driven Development
**TDD Process**:
```
Red (Write failing test) → Green (Make it pass) → Refactor (Improve code)
```

**Test Structure**:
```{PROGRAMMING_LANGUAGE}
{TEST_TEMPLATE_STRUCTURE}
```

---

## API Development

### API Design Principles
- **RESTful Design**: {REST_PRINCIPLES}
- **Consistency**: {API_CONSISTENCY_RULES}
- **Versioning**: {API_VERSIONING_STRATEGY}
- **Documentation**: {API_DOCUMENTATION_STANDARD}

### Request/Response Format
**Standard Request**:
```json
{
  "data": {
    "{REQUEST_FIELD_1}": "{REQUEST_VALUE_1}",
    "{REQUEST_FIELD_2}": "{REQUEST_VALUE_2}"
  },
  "metadata": {
    "requestId": "{REQUEST_ID}",
    "timestamp": "{TIMESTAMP}",
    "version": "{API_VERSION}"
  }
}
```

**Standard Response**:
```json
{
  "success": true,
  "data": {
    "{RESPONSE_FIELD_1}": "{RESPONSE_VALUE_1}",
    "{RESPONSE_FIELD_2}": "{RESPONSE_VALUE_2}"
  },
  "metadata": {
    "responseId": "{RESPONSE_ID}",
    "timestamp": "{TIMESTAMP}",
    "executionTime": "{EXECUTION_TIME}"
  },
  "errors": []
}
```

### Error Handling
**Error Response Format**:
```json
{
  "success": false,
  "errors": [
    {
      "code": "{ERROR_CODE}",
      "message": "{ERROR_MESSAGE}",
      "field": "{ERROR_FIELD}",
      "details": "{ERROR_DETAILS}"
    }
  ]
}
```

---

## Database Development

### Schema Design
**Design Principles**:
- {DB_DESIGN_PRINCIPLE_1}
- {DB_DESIGN_PRINCIPLE_2}
- {DB_DESIGN_PRINCIPLE_3}

**Naming Conventions**:
- Tables: {TABLE_NAMING_CONVENTION}
- Columns: {COLUMN_NAMING_CONVENTION}
- Indexes: {INDEX_NAMING_CONVENTION}
- Constraints: {CONSTRAINT_NAMING_CONVENTION}

### Migration Strategy
**Migration Process**:
1. {MIGRATION_STEP_1}
2. {MIGRATION_STEP_2}
3. {MIGRATION_STEP_3}

**Migration Template**:
```sql
{MIGRATION_TEMPLATE}
```

### Query Optimization
**Performance Guidelines**:
- {QUERY_OPTIMIZATION_1}
- {QUERY_OPTIMIZATION_2}
- {QUERY_OPTIMIZATION_3}

---

## Frontend Development

### Component Architecture
**Component Structure**:
```{FRONTEND_FRAMEWORK}
{COMPONENT_TEMPLATE}
```

**State Management**:
- **Pattern**: {STATE_MANAGEMENT_PATTERN}
- **Tools**: {STATE_MANAGEMENT_TOOLS}
- **Organization**: {STATE_ORGANIZATION}

### UI/UX Guidelines
**Design System**:
- **Colors**: {COLOR_PALETTE}
- **Typography**: {TYPOGRAPHY_SYSTEM}
- **Spacing**: {SPACING_SYSTEM}
- **Components**: {COMPONENT_LIBRARY}

**Accessibility**:
- {ACCESSIBILITY_REQUIREMENT_1}
- {ACCESSIBILITY_REQUIREMENT_2}
- {ACCESSIBILITY_REQUIREMENT_3}

### Performance Optimization
**Frontend Performance**:
- {FRONTEND_PERF_1}
- {FRONTEND_PERF_2}
- {FRONTEND_PERF_3}

---

## DevOps and Deployment

### CI/CD Pipeline
**Pipeline Stages**:
1. **Build**: {BUILD_PROCESS}
2. **Test**: {TEST_AUTOMATION}
3. **Security Scan**: {SECURITY_SCANNING}
4. **Deploy**: {DEPLOYMENT_PROCESS}
5. **Monitor**: {MONITORING_SETUP}

### Infrastructure as Code
**IaC Tools**: {IAC_TOOLS}
**Configuration Management**: {CONFIG_MANAGEMENT}
**Environment Parity**: {ENVIRONMENT_CONSISTENCY}

### Monitoring and Logging
**Logging Strategy**:
```{PROGRAMMING_LANGUAGE}
{LOGGING_EXAMPLE}
```

**Metrics Collection**:
- {METRIC_1}: {METRIC_1_DESCRIPTION}
- {METRIC_2}: {METRIC_2_DESCRIPTION}
- {METRIC_3}: {METRIC_3_DESCRIPTION}

---

## Code Review Guidelines

### Review Checklist
**Functionality**:
- [ ] {FUNCTIONALITY_CHECK_1}
- [ ] {FUNCTIONALITY_CHECK_2}
- [ ] {FUNCTIONALITY_CHECK_3}

**Code Quality**:
- [ ] {QUALITY_CHECK_1}
- [ ] {QUALITY_CHECK_2}
- [ ] {QUALITY_CHECK_3}

**Security**:
- [ ] {SECURITY_CHECK_1}
- [ ] {SECURITY_CHECK_2}
- [ ] {SECURITY_CHECK_3}

### Review Process
**Review Steps**:
1. **Understand**: {REVIEW_UNDERSTANDING}
2. **Analyze**: {REVIEW_ANALYSIS}
3. **Test**: {REVIEW_TESTING}
4. **Suggest**: {REVIEW_SUGGESTIONS}
5. **Approve**: {REVIEW_APPROVAL_CRITERIA}

### Feedback Guidelines
**Constructive Feedback**:
- {FEEDBACK_GUIDELINE_1}
- {FEEDBACK_GUIDELINE_2}
- {FEEDBACK_GUIDELINE_3}

---

## Documentation Standards

### Code Documentation
**Inline Documentation**:
```{PROGRAMMING_LANGUAGE}
{INLINE_DOC_EXAMPLE}
```

**API Documentation**:
- **Format**: {API_DOC_FORMAT}
- **Tools**: {API_DOC_TOOLS}
- **Coverage**: {API_DOC_COVERAGE}

### Project Documentation
**README Structure**:
```markdown
{README_TEMPLATE}
```

**Architecture Documentation**:
- {ARCHITECTURE_DOC_1}
- {ARCHITECTURE_DOC_2}
- {ARCHITECTURE_DOC_3}

---

## Troubleshooting Guide

### Common Issues and Solutions
**Issue 1: {COMMON_ISSUE_1}**
- **Symptoms**: {ISSUE_1_SYMPTOMS}
- **Cause**: {ISSUE_1_CAUSE}
- **Solution**: {ISSUE_1_SOLUTION}

**Issue 2: {COMMON_ISSUE_2}**
- **Symptoms**: {ISSUE_2_SYMPTOMS}
- **Cause**: {ISSUE_2_CAUSE}
- **Solution**: {ISSUE_2_SOLUTION}

### Debugging Process
1. **Reproduce**: {REPRODUCTION_APPROACH}
2. **Isolate**: {ISOLATION_METHOD}
3. **Investigate**: {INVESTIGATION_TOOLS}
4. **Fix**: {FIX_STRATEGY}
5. **Verify**: {VERIFICATION_PROCESS}

### Debug Tools and Techniques
**Development Tools**:
- {DEBUG_TOOL_1}: {TOOL_1_USAGE}
- {DEBUG_TOOL_2}: {TOOL_2_USAGE}
- {DEBUG_TOOL_3}: {TOOL_3_USAGE}

---

## Performance Optimization

### Performance Metrics
**Key Metrics**:
- {PERF_METRIC_1}: Target {PERF_TARGET_1}
- {PERF_METRIC_2}: Target {PERF_TARGET_2}
- {PERF_METRIC_3}: Target {PERF_TARGET_3}

### Optimization Strategies
**Code Optimization**:
- {CODE_OPT_1}
- {CODE_OPT_2}
- {CODE_OPT_3}

**Database Optimization**:
- {DB_OPT_1}
- {DB_OPT_2}
- {DB_OPT_3}

**Infrastructure Optimization**:
- {INFRA_OPT_1}
- {INFRA_OPT_2}
- {INFRA_OPT_3}

---

## Security Considerations

### Security Checklist
**Authentication & Authorization**:
- [ ] {AUTH_SECURITY_1}
- [ ] {AUTH_SECURITY_2}
- [ ] {AUTH_SECURITY_3}

**Data Protection**:
- [ ] {DATA_SECURITY_1}
- [ ] {DATA_SECURITY_2}
- [ ] {DATA_SECURITY_3}

**Input Validation**:
- [ ] {INPUT_VALIDATION_1}
- [ ] {INPUT_VALIDATION_2}
- [ ] {INPUT_VALIDATION_3}

### Security Patterns
**Secure Coding Patterns**:
```{PROGRAMMING_LANGUAGE}
{SECURE_CODING_EXAMPLE}
```

---

## Development Tools and Environment

### Required Tools
**Development Environment**:
- IDE: {IDE_RECOMMENDATION}
- Version Control: {VERSION_CONTROL_TOOL}
- Package Manager: {PACKAGE_MANAGER}
- Build Tool: {BUILD_TOOL}

**Development Setup**:
```bash
{SETUP_COMMANDS}
```

### Environment Configuration
**Environment Variables**:
```bash
{ENVIRONMENT_VARIABLES}
```

**Configuration Files**:
- {CONFIG_FILE_1}: {CONFIG_PURPOSE_1}
- {CONFIG_FILE_2}: {CONFIG_PURPOSE_2}
- {CONFIG_FILE_3}: {CONFIG_PURPOSE_3}

---

## Collaboration Workflow

### Git Workflow
**Branching Strategy**: {BRANCHING_STRATEGY}
**Commit Message Format**: {COMMIT_MESSAGE_FORMAT}
**Pull Request Process**: {PR_PROCESS}

### Communication Protocols
**Daily Standups**: {STANDUP_FORMAT}
**Code Reviews**: {CODE_REVIEW_PROCESS}
**Technical Discussions**: {TECH_DISCUSSION_FORMAT}

---

**Development Prompt Version**: {DEV_PROMPT_VERSION}
**Last Updated**: {LAST_UPDATE_DATE}
**Team Contact**: {TEAM_CONTACT}

---

*This development prompt provides comprehensive guidance for the entire development lifecycle. Customize the placeholders with project-specific values and standards.*