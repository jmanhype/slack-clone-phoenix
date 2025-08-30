# 🚀 SPARC Development Environment with Claude Flow

A fully configured, production-ready development environment powered by SPARC methodology and Claude Flow orchestration. Features 54 specialized AI agents, automated workflows, persistent memory, and comprehensive MCP integration for systematic Test-Driven Development.

## ✨ Key Features

- **54 Specialized AI Agents**: From core development to distributed consensus
- **SPARC Methodology**: Specification → Pseudocode → Architecture → Refinement → Completion
- **Claude Flow Orchestration**: Swarm topology with concurrent execution
- **Persistent Memory**: SQLite-backed cross-session state management
- **Automated Hooks**: Pre/post operation triggers for workflow automation
- **MCP Integration**: 24+ configured services including Apollo, Playwright, Rube, Zen
- **TDD Workflows**: Automated Red-Green-Refactor cycles
- **Performance**: 84.8% SWE-Bench solve rate, 2.8-4.4x speed improvement

## 📋 Table of Contents
- [Quick Start](#quick-start)
- [Architecture Overview](#architecture-overview)
- [Available Agents (54)](#available-agents)
- [Core Commands](#core-commands)
- [Workflows](#workflows)
- [Hooks System](#hooks-system)
- [Memory & Persistence](#memory--persistence)
- [Project Structure](#project-structure)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)

## 🎯 Quick Start

### 1. Initial Setup (One-time)
```bash
# Clone the repository
git clone <repository-url>
cd experiments

# Install Claude Flow globally
npm install -g claude-flow@alpha

# Verify installation
npx claude-flow --version
```

### 2. Start Development
When you open Claude Code in this directory, everything is pre-configured:

```bash
# Test the environment
npx claude-flow sparc tdd "user authentication with JWT"

# Check swarm status
npx claude-flow swarm status

# View available agents
npx claude-flow agent list
```

## 🏗️ Architecture Overview

### Core Technologies
- **SPARC Methodology**: Specification → Pseudocode → Architecture → Refinement → Completion
- **Claude Flow**: Orchestration engine with swarm topology
- **MCP (Model Context Protocol)**: Tool coordination
- **SQLite Memory**: Persistent state management
- **Concurrent Execution**: All operations run in parallel

### Key Principles
1. **Single Message, Multiple Operations**: Batch everything
2. **Task Tool for Execution**: Claude Code's Task tool spawns agents
3. **MCP for Coordination**: High-level orchestration only
4. **Automatic Hooks**: Trigger on every operation
5. **Persistent Memory**: Survives between sessions

## 👥 Available Agents

### Core Development (5)
- `coder` - Implementation specialist
- `reviewer` - Code review and quality
- `tester` - Test creation and validation
- `planner` - Strategic planning
- `researcher` - Deep research and analysis

### Swarm Coordination (5)
- `hierarchical-coordinator` - Tree-based coordination
- `mesh-coordinator` - Peer-to-peer coordination
- `adaptive-coordinator` - Dynamic topology
- `collective-intelligence-coordinator` - Swarm intelligence
- `swarm-memory-manager` - Distributed memory

### Specialized Development (10)
- `backend-dev` - Backend API development
- `mobile-dev` - React Native mobile apps
- `ml-developer` - Machine learning models
- `cicd-engineer` - CI/CD pipelines
- `api-docs` - API documentation
- `system-architect` - System design
- `code-analyzer` - Code quality analysis
- `base-template-generator` - Template creation
- `tdd-london-swarm` - Mock-driven TDD
- `production-validator` - Production readiness

### GitHub Integration (9)
- `github-modes` - GitHub workflow orchestration
- `pr-manager` - Pull request management
- `code-review-swarm` - Automated reviews
- `issue-tracker` - Issue management
- `release-manager` - Release coordination
- `workflow-automation` - GitHub Actions
- `project-board-sync` - Project board sync
- `repo-architect` - Repository structure
- `multi-repo-swarm` - Cross-repo coordination

### SPARC Methodology (6)
- `sparc-coord` - SPARC orchestrator
- `sparc-coder` - SPARC implementation
- `specification` - Requirements analysis
- `pseudocode` - Algorithm design
- `architecture` - System architecture
- `refinement` - Iterative improvement

### Consensus & Distributed (7)
- `byzantine-coordinator` - Byzantine fault tolerance
- `raft-manager` - Raft consensus
- `gossip-coordinator` - Gossip protocols
- `consensus-builder` - Consensus mechanisms
- `crdt-synchronizer` - CRDT synchronization
- `quorum-manager` - Quorum management
- `security-manager` - Security protocols

### Performance & Optimization (7)
- `perf-analyzer` - Performance analysis
- `performance-benchmarker` - Benchmarking
- `task-orchestrator` - Task coordination
- `memory-coordinator` - Memory management
- `smart-agent` - Intelligent coordination
- `migration-planner` - Migration planning
- `swarm-init` - Swarm initialization

## 🛠️ Core Commands

### SPARC Commands
```bash
# Run specific SPARC mode
npx claude-flow sparc run <mode> "<task>"

# Complete TDD workflow
npx claude-flow sparc tdd "<feature>"

# Run full pipeline
npx claude-flow sparc pipeline "<task>"

# Batch execution
npx claude-flow sparc batch "spec,architect,code" "<task>"

# Get mode information
npx claude-flow sparc info <mode>
```

### Swarm Management
```bash
# Initialize swarm with topology
npx claude-flow swarm init mesh|star|ring|hierarchical

# Check swarm status
npx claude-flow swarm status

# List active agents
npx claude-flow agent list

# View agent metrics
npx claude-flow agent metrics
```

### Memory Operations
```bash
# Store data
npx claude-flow memory store <key> "<value>"

# Retrieve data
npx claude-flow memory get <key>

# List all keys
npx claude-flow memory list

# Search memory
npx claude-flow memory search "<pattern>"
```

### 🧠 Neural Training & Pattern Learning
```bash
# Train neural patterns from recent operations
npx claude-flow training neural-train --data recent --model task-predictor

# Learn from specific operation outcomes
npx claude-flow training pattern-learn --operation "file-creation" --outcome "success"

# Update agent models with insights
npx claude-flow training model-update --agent-type coordinator --operation-result "efficient"

# Train from swarm-specific data
npx claude-flow training neural-train --data "swarm-123" --epochs 100 --model "coordinator-predictor"
```

#### Training Data Sources
- `recent` - Last 24 hours of operations
- `historical` - All available historical data
- `custom` - User-specified dataset
- `swarm-<id>` - Specific swarm session data

#### Available Models
- `general-predictor` - General task prediction
- `task-predictor` - Task selection optimization
- `agent-selector` - Agent assignment optimization
- `performance-optimizer` - Performance prediction
- `coordinator-predictor` - Coordination patterns

#### Training Benefits
- **Task selection accuracy**: Better prediction of task outcomes
- **Agent performance**: Optimized agent assignment
- **Coordination efficiency**: Improved swarm topology selection
- **Error prevention**: Learn from past failures

### Hooks Management
```bash
# Trigger hooks manually
npx claude-flow hooks pre-task --description "<task>"
npx claude-flow hooks post-edit --file "<file>" --memory-key "<key>"
npx claude-flow hooks post-task --task-id "<id>"

# Session management
npx claude-flow hooks session-restore --session-id "<id>"
npx claude-flow hooks session-end --export-metrics true
```

## 🐝 Hive Mind System

### Initialize and Manage Hive Mind
```bash
# Initialize hive mind system
npx claude-flow hive-mind init

# Spawn hive mind swarm with interactive wizard
npx claude-flow hive-mind spawn

# Quick spawn with objective
npx claude-flow hive-mind spawn "Build microservices architecture"

# View current status
npx claude-flow hive-mind status

# Interactive wizard for complex setups
npx claude-flow hive-mind wizard

# Spawn with Claude Code coordination
npx claude-flow hive-mind spawn "Build REST API" --claude

# Auto-spawn coordinated Claude Code instances
npx claude-flow hive-mind spawn "Research AI trends" --auto-spawn --verbose

# List all sessions
npx claude-flow hive-mind sessions

# Resume a paused session
npx claude-flow hive-mind resume session-1234567890-abc123
```

### Hive Mind Key Features
- 🐝 **Queen-led coordination** with worker specialization
- 🧠 **Collective memory** and knowledge sharing
- 🤝 **Consensus building** for critical decisions
- ⚡ **Parallel task execution** with auto-scaling
- 🔄 **Work stealing** and load balancing
- 📊 **Real-time metrics** and performance tracking
- 🛡️ **Fault tolerance** and self-healing
- 🔒 **Secure communication** between agents

### Hive Mind Options
```bash
--queen-type <type>    # Queen coordinator type (strategic, tactical, adaptive)
--max-workers <n>      # Maximum worker agents (default: 8)
--consensus <type>     # Consensus algorithm (majority, weighted, byzantine)
--memory-size <mb>     # Collective memory size in MB (default: 100)
--auto-scale           # Enable auto-scaling based on workload
--encryption           # Enable encrypted communication
--monitor              # Real-time monitoring dashboard
--verbose              # Detailed logging
--claude               # Generate Claude Code spawn commands
--auto-spawn           # Automatically spawn Claude Code instances
--execute              # Execute Claude Code spawn commands immediately
```

## 📊 Workflows

### 1. TDD Authentication System
```bash
# Automatic TDD with all phases
npx claude-flow sparc tdd "JWT authentication with refresh tokens"

# This will:
# 1. Write failing tests (Red phase)
# 2. Implement minimal code (Green phase)
# 3. Refactor and optimize (Refactor phase)
# 4. Generate documentation
```

### 2. Full-Stack Application
```javascript
// In Claude Code, request:
"Build a task management app with React frontend and Node backend"

// Automatically spawns:
Task("Frontend", "React UI with hooks", "coder")
Task("Backend", "Express REST API", "backend-dev")
Task("Database", "PostgreSQL schema", "code-analyzer")
Task("Tests", "Jest test suite", "tester")
Task("DevOps", "Docker setup", "cicd-engineer")
```

### 3. Microservices Architecture
```bash
# Design microservices system
npx claude-flow sparc run architect "e-commerce platform with microservices"

# Spawns architecture agents
Task("Service Design", "Define service boundaries", "system-architect")
Task("API Gateway", "Design API gateway", "api-docs")
Task("Data Flow", "Design data flow", "code-analyzer")
```

### 4. Code Migration
```bash
# Migrate Python to TypeScript
npx claude-flow sparc pipeline "migrate Python ML service to TypeScript"

# Coordinates:
# - Analysis phase (Python code understanding)
# - Architecture phase (TypeScript structure)
# - Implementation phase (Parallel conversion)
# - Testing phase (Validation)
```

### 5. Performance Optimization
```javascript
// Request optimization
"Optimize React app performance"

// Spawns specialized agents:
Task("Analyzer", "Identify bottlenecks", "perf-analyzer")
Task("Benchmarker", "Create benchmarks", "performance-benchmarker")
Task("Optimizer", "Implement optimizations", "coder")
Task("Validator", "Verify improvements", "tester")
```

### 6. API Documentation
```bash
# Generate OpenAPI documentation
npx claude-flow sparc run api-docs "document REST API with OpenAPI"

# Creates:
# - OpenAPI specification
# - Interactive documentation
# - Client SDK generation
# - Test examples
```

### 7. Security Audit
```javascript
// Security review request
"Perform security audit on authentication system"

// Coordinated agents:
Task("Security Scan", "OWASP Top 10 check", "security-manager")
Task("Code Review", "Security patterns", "reviewer")
Task("Penetration Test", "Test scenarios", "tester")
```

### 8. Database Schema Design
```bash
# Design scalable database
npx claude-flow sparc run architect "multi-tenant SaaS database"

# Generates:
# - ER diagrams
# - Migration scripts
# - Indexing strategy
# - Sharding plan
```

### 9. CI/CD Pipeline
```javascript
// DevOps setup
"Setup GitHub Actions CI/CD with staging and production"

// Automated creation:
Task("Pipeline", "GitHub Actions workflow", "cicd-engineer")
Task("Testing", "Test automation", "tester")
Task("Deployment", "Deploy scripts", "workflow-automation")
```

### 10. Mobile App Development
```bash
# React Native app
npx claude-flow sparc tdd "cross-platform mobile app with offline sync"

# Coordinates:
# - UI/UX implementation
# - Native module integration
# - Offline data sync
# - Platform-specific features
```

## 🪝 Hooks System

### Automatic Triggers

#### Pre-Operation Hooks
Trigger **before** operations:
```javascript
// Automatically triggered on:
- Bash commands
- File writes
- File edits
- Task starts

// Actions:
- Validate operations
- Prepare resources
- Check permissions
- Optimize topology
```

#### Post-Operation Hooks
Trigger **after** operations:
```javascript
// Automatically triggered on:
- File saves
- Command completion
- Task completion

// Actions:
- Format code
- Update memory
- Train patterns
- Log metrics
```

### Hook Configuration (.claude/settings.json)
```json
{
  "hooks": {
    "preToolUse": [
      {
        "tools": ["Bash", "Write", "Edit"],
        "command": "npx claude-flow@alpha hooks pre-edit",
        "async": true
      }
    ],
    "postToolUse": [
      {
        "tools": ["Write", "Edit"],
        "command": "npx claude-flow@alpha hooks post-edit --file \"{file}\"",
        "async": true
      }
    ]
  }
}
```

### Manual Hook Usage
```bash
# Before starting work
npx claude-flow hooks pre-task --description "Building authentication"

# After file changes
npx claude-flow hooks post-edit --file "src/auth.js" --memory-key "auth/implementation"

# After completing work
npx claude-flow hooks post-task --task-id "task-123"

# Session management
npx claude-flow hooks session-end --export-metrics true
```

## 💾 Memory & Persistence

### Memory Store Location
```
.swarm/
├── memory.db        # SQLite database
├── memory.db-shm    # Shared memory
└── memory.db-wal    # Write-ahead log
```

### Memory Operations

#### Store Data
```bash
# Store with default namespace
npx claude-flow memory store "project/config" '{"name": "MyApp", "version": "1.0.0"}'

# Store with custom namespace
npx claude-flow memory store "api/endpoints" "['/users', '/posts']" --namespace api
```

#### Retrieve Data
```bash
# Get specific key
npx claude-flow memory get "project/config"

# List all keys
npx claude-flow memory list

# Search patterns
npx claude-flow memory search "api/*"
```

#### Memory Patterns
```javascript
// Hierarchical keys for organization
"project/config"          // Project configuration
"tdd/tests/auth"         // Test files
"tdd/implementation/auth" // Implementation files
"swarm/agent/status"     // Agent status
"workflow/complete"      // Workflow completion
```

### Cross-Session Persistence
Memory survives between Claude sessions:
```bash
# Session 1: Store data
npx claude-flow memory store "session/data" "Important information"

# Session 2: Retrieve data (even after restart)
npx claude-flow memory get "session/data"
# Output: "Important information"
```

## 📁 Project Structure

```
experiments/
├── .claude/                    # Claude configuration
│   ├── settings.json          # Hook configurations
│   ├── settings.local.json    # Local overrides
│   ├── mcp/                   # MCP configurations
│   │   ├── servers.json       # Server definitions
│   │   ├── clients.yaml       # Client configs
│   │   └── integration.json   # Cross-integration
│   ├── tests/                 # Test suites
│   │   └── mcp-test-suite.sh  # MCP tests
│   ├── workflows/             # Example workflows
│   │   └── example-workflows.md
│   └── docs/                  # Documentation
│       └── MCP_COMMANDS_REFERENCE.md
├── .swarm/                    # Swarm state
│   ├── memory.db             # Persistent memory
│   └── logs/                 # Operation logs
├── src/                      # Source code
│   └── auth.js              # Example: Auth implementation
├── tests/                    # Test files
│   └── auth.test.js         # Example: Auth tests
├── docs/                     # Project documentation
├── config/                   # Configuration files
├── scripts/                  # Utility scripts
├── examples/                 # Example code
├── CLAUDE.md                # Main instructions
├── README.md                # This file
└── package.json            # Project dependencies
```

### Directory-Specific CLAUDE.md Files
Each directory has its own `CLAUDE.md` with:
- Directory purpose
- Allowed operations
- File conventions
- Agent assignments

## ✅ Best Practices

### 1. Concurrent Execution
```javascript
// ✅ CORRECT: Single message, multiple operations
[One Message]:
  Task("Agent 1", "Task 1", "coder")
  Task("Agent 2", "Task 2", "tester")
  Task("Agent 3", "Task 3", "reviewer")
  TodoWrite([...all todos...])
  Write("file1.js")
  Write("file2.js")

// ❌ WRONG: Multiple messages
Message 1: Task("Agent 1")
Message 2: Task("Agent 2")
Message 3: Write("file.js")
```

### 2. File Organization
```bash
# ✅ CORRECT: Use subdirectories
src/auth.js
tests/auth.test.js
docs/API.md

# ❌ WRONG: Root directory
auth.js
test.js
README.md
```

### 3. Agent Spawning
```javascript
// ✅ CORRECT: Use Task tool for execution
Task("Build API", "Create REST endpoints", "backend-dev")

// ❌ WRONG: MCP tools don't execute
mcp__claude-flow__agent_spawn({ type: "coder" })
```

### 4. Memory Keys
```bash
# ✅ CORRECT: Hierarchical organization
"project/config/database"
"tdd/tests/authentication"
"workflow/status/current"

# ❌ WRONG: Flat structure
"config"
"test"
"status"
```

### 5. Hook Integration
```bash
# Hooks trigger automatically, but you can also trigger manually:

# Before work
npx claude-flow hooks pre-task --description "Feature: User login"

# After file edit
npx claude-flow hooks post-edit --file "src/login.js"

# After completion
npx claude-flow hooks post-task --task-id "task-123"
```

## 🔧 Troubleshooting

### Common Issues

#### 1. Command Not Found
```bash
# Problem: npx claude-flow: command not found
# Solution:
npm install -g claude-flow@alpha
```

#### 2. Memory Not Persisting
```bash
# Problem: Memory lost between sessions
# Solution: Check .swarm directory exists
mkdir -p .swarm
npx claude-flow memory store test "data"
```

#### 3. Hooks Not Triggering
```bash
# Problem: Hooks don't run automatically
# Solution: Check .claude/settings.json
cat .claude/settings.json | grep hooks
```

#### 4. Agent Timeout
```bash
# Problem: Agent operations timeout
# Solution: Increase timeout or use simpler topology
export CLAUDE_FLOW_TIMEOUT=300000  # 5 minutes
```

#### 5. MCP Tools Not Available
```bash
# Problem: MCP tools not recognized
# Solution: Restart Claude Code after configuration changes
# The .claude/settings.json must include enabledMcpjsonServers
```

### Debug Commands
```bash
# Check environment
npx claude-flow debug env

# Verify installation
npx claude-flow --version

# Test swarm
npx claude-flow swarm status

# Check memory
sqlite3 .swarm/memory.db "SELECT COUNT(*) FROM memory_store;"

# View logs
tail -f .swarm/logs/claude-flow.log
```

## 📈 Performance Metrics

### Benchmarks
- **84.8% SWE-Bench solve rate** (vs 49% baseline)
- **32.3% token reduction** through caching
- **2.8-4.4x speed improvement** with parallel execution
- **27+ neural models** for pattern recognition
- **Truth score ≥ 0.95** verification threshold

### Optimization Tips
1. Use `mesh` topology for parallel tasks
2. Enable memory caching for repeated operations
3. Batch file operations in single messages
4. Use specialized agents for domain tasks
5. Configure hooks for automation
6. Train neural patterns from successful operations
7. Enable hive mind for complex multi-agent tasks

## 🔬 Experiment Verification

### Verification Gates
All experiments must pass verification with truth score ≥ 0.95:

```bash
# Verify an experiment
npx ts-node platform/scripts/verify.ts experiments/my-experiment

# Run verification gate hook
.claude/hooks/verify_gate.sh
```

### Verification Checks
- **Directory structure** completeness
- **Configuration file** presence
- **Truth score threshold** (≥ 0.95)
- **Performance metrics** validation
- **Code quality** (linting, testing)
- **Security scanning** for secrets

### Hook Features
**Pre-run Hook** (`.claude/hooks/pre_run.sh`):
- Auto-detects project type (Python, Node.js, Rust, Elixir)
- Runs appropriate linters (ruff, eslint, clippy, credo)
- Executes unit tests (pytest, jest, cargo test, mix test)
- Checks for large files and potential secrets

**Post-run Hook** (`.claude/hooks/post_run.sh`):
- Generates git diff statistics
- Creates detailed REVIEW.md with file analysis
- Counts lines of code and TODOs
- Auto-opens review in available editor

**Verification Gate** (`.claude/hooks/verify_gate.sh`):
- Validates truth scores from registry/index.ndjson
- Supports fallback to policy verification
- Provides actionable failure recommendations
- Blocks commits if score < 0.95

## 🔗 Integration with Other Tools

### MCP Servers Configured (24+)
The environment comes pre-configured with these MCP servers:

#### Core Development & Testing
- **claude-flow** - Main orchestration engine
- **ruv-swarm** - Swarm coordination
- **flow-nexus** - Flow management
- **playwright** - Browser automation
- **browsermcp** - Browser control
- **task-master-ai** - Task management

#### AI & Knowledge
- **zen** - AI reasoning and analysis
- **rube** - Cross-app automation (500+ apps)
- **context7** - Documentation retrieval
- **exa** - Web search

#### Data & Integration
- **apollo-dgraph** - Graph database
- **apollo-dagger** - Pipeline orchestration
- **notion-api** - Notion integration
- **obsidian** - Obsidian notes
- **discord** - Discord automation

#### Creative & Media
- **AbletonMCP** - Music production
- **blender** - 3D modeling
- **flux** - Image generation
- **dart** - Flutter development

### GitHub Integration
```bash
# Create PR with swarm review
npx claude-flow github pr create --swarm-review

# Analyze repository
npx claude-flow github repo analyze

# Issue management
npx claude-flow github issue track

# Release coordination
npx claude-flow github release coord
```

### VSCode Integration
```json
// .vscode/settings.json
{
  "claude-flow.enabled": true,
  "claude-flow.autoHooks": true,
  "claude-flow.topology": "mesh",
  "claude-flow.memory": true,
  "claude-flow.neural-training": true
}
```

### CI/CD Integration
```yaml
# .github/workflows/claude-flow.yml
name: Claude Flow CI
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - run: npm install -g claude-flow@alpha
      - run: npx claude-flow sparc test
      - run: npx claude-flow training neural-train --data recent
  
  swarm-review:
    if: github.event_name == 'pull_request'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - run: npm install -g claude-flow@alpha
      - run: npx claude-flow github pr review --swarm
```

## 📚 Additional Resources

### Documentation
- [Claude Flow GitHub](https://github.com/ruvnet/claude-flow)
- [SPARC Methodology](https://github.com/ruvnet/sparc)
- [MCP Protocol Spec](https://modelcontextprotocol.org)

### Examples
- `/examples` - Code examples
- `/.claude/workflows` - Workflow templates
- `/tests` - Test examples

### Support
- Issues: [GitHub Issues](https://github.com/ruvnet/claude-flow/issues)
- Discussions: [GitHub Discussions](https://github.com/ruvnet/claude-flow/discussions)

## 🚀 Quick Reference Card

```bash
# Most Common Commands
npx claude-flow sparc tdd "feature"     # TDD workflow
npx claude-flow swarm status            # Check status
npx claude-flow agent list              # List agents
npx claude-flow memory list             # List memory
npx claude-flow hooks pre-task          # Start work
npx claude-flow hooks post-task         # End work

# In Claude Code
Task("Description", "Instructions", "agent-type")
TodoWrite([{content: "task", status: "pending"}])
```

## 🎯 What New Users Get Immediately

When a new user starts Claude Code in this repo:

### Auto-loaded Configuration
- **CLAUDE.md** in root and every directory providing context
- **54 specialized agents** ready for concurrent execution
- **MCP tools** pre-configured for orchestration
- **Hooks system** for automated workflows

### Available Commands (work instantly)
```bash
# SPARC methodology
npx claude-flow sparc tdd "feature description"
npx claude-flow sparc run architect "system design"
npx claude-flow sparc pipeline "complete task"

# Swarm orchestration
npx claude-flow swarm init mesh
npx claude-flow swarm status

# Memory & persistence
npx claude-flow memory store key "value"
npx claude-flow memory list
```

### Pre-configured Agents via Task Tool
They can immediately use Claude Code's Task tool to spawn agents:
```javascript
Task("Backend API", "Build REST endpoints", "backend-dev")
Task("React UI", "Create frontend", "coder")
Task("Testing", "Write comprehensive tests", "tester")
```

### Automatic Behaviors
- Hooks trigger on file edits
- Memory persists in `.swarm/memory.db`
- Concurrent execution by default
- TodoWrite for task tracking

## 📝 License

This project is configured for use with Claude Code and Claude Flow.

## 🤝 Contributing

1. Follow SPARC methodology
2. Write tests first (TDD)
3. Use appropriate agents
4. Document in memory
5. Submit PR with swarm review

---

**Remember**: Claude Flow coordinates, Claude Code creates! 🚀