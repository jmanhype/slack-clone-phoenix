# slack-clone-phoenix

SPARC development environment with Claude Flow orchestration. Despite the repo name, this is not a Slack clone and contains no Phoenix/Elixir application code. It is a configuration scaffold for running Claude Code agents with pre-defined workflows.

## Status

Configuration-only repository. Contains 45,000+ files, almost entirely `.claude/` agent definitions, MCP server configs, automation scripts, and CLAUDE.md instruction files. No application source code.

## What It Contains

| Directory | File Count (approx) | Purpose |
|---|---|---|
| `.claude/agents/` | ~90 agent definitions | Markdown-based agent role specs (coder, reviewer, tester, etc.) |
| `.claude/commands/` | ~40 command definitions | Workflow triggers for Claude Code |
| `.claude/templates/` | ~15 templates | Agent spawning templates |
| `automation/tmux/` | ~20 scripts | tmux-based 24/7 orchestration, guardian scripts, dashboards |
| `chrome-mcp-extension/` | ~30 files | Chrome extension for browser-based MCP interaction |
| `.mcp/` | ~10 configs | MCP server registry and connection configs |
| `config/` | 3 files | Platform config, Claude Code settings, launchd plist |

## Agent Categories

The repo defines 54 agent roles organized into 7 groups:

| Group | Count | Examples |
|---|---|---|
| Core Development | 5 | coder, reviewer, tester, planner, researcher |
| Swarm Coordination | 5 | hierarchical-coordinator, mesh-coordinator, adaptive-coordinator |
| Specialized Development | 10 | backend-dev, mobile-dev, ml-developer, cicd-engineer |
| GitHub Integration | 9 | pr-manager, code-review-swarm, issue-tracker, release-manager |
| SPARC Methodology | 6 | specification, pseudocode, architecture, refinement |
| Consensus/Distributed | 7 | byzantine-coordinator, raft-manager, gossip-coordinator |
| Performance/Optimization | 7 | performance-benchmarker, load-balancer, resource-allocator |

## How It Works

1. Clone into a project directory
2. Install Claude Flow: `npm install -g claude-flow@alpha`
3. Open with Claude Code -- agents and commands are auto-discovered from `.claude/`
4. Run workflows: `npx claude-flow sparc tdd "feature description"`

The tmux automation (`make up`) starts a persistent session with orchestrator and worker panes. A guardian script monitors and restarts crashed workers.

## Limitations

- The repo name is misleading. There is no Slack clone or Phoenix application.
- 45,000+ files for what is essentially a configuration template is excessive. Most are CLAUDE.md marker files in nested directories.
- The "84.8% SWE-Bench solve rate" and "2.8-4.4x speed improvement" claims from the previous README are unsubstantiated -- no benchmarks or methodology are included.
- Depends on `claude-flow@alpha`, an unpublished/alpha npm package.
- The Chrome MCP extension is bundled as pre-built JS with no source or build instructions.
- The 24/7 orchestration scripts assume macOS (launchd plist included).

## Usage

```bash
# Start tmux orchestration
make up

# Stop
make down

# Check status
make status

# View logs
make logs
```

SPARC commands (require claude-flow):

```bash
npx claude-flow sparc tdd "feature description"
npx claude-flow sparc run <mode> "task"
npx claude-flow swarm status
npx claude-flow agent list
```

## License

Not specified.
