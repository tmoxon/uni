# Uni Development Guide

This guide covers development workflows, architecture details, and contribution processes for Uni.

## Development Environment

Currently, Uni does not work in Claude Code in Windows due to problems with how file paths are handled. Supported approaches are:

### WSL
Developing with VS Code connected to WSL is a good way to benefit from a Linux-based developer experience. Follow the guide here: https://code.visualstudio.com/docs/remote/wsl
Once you have set up your WSL environment then you can follow the details in README.md.

### Mac
On a Mac you follow the installation guidance in README.md.

### Docker
This repo provides a Docker-based development environment with pre-installed tools and dependencies.

### Prerequisites

- **Docker Desktop** or **Docker Compose** installed
- Windows: Docker Desktop for Windows

### Starting the Environment

```bash
# Start the container
docker-compose up -d

# Access the shell
docker-compose exec dev bash
```

### What's Included

The development container comes with:

- **Languages**: Node.js 20
- **CLIs**: GitHub CLI (`gh`), Azure CLI (`az`), Claude CLI
- **Tools**: Git, curl, jq, vim, build tools
- **Base**: Ubuntu 22.04

### Volume Mounts

- `.` → `/workspace` - Your Uni working directory
- `./.uni` → `/workspace/.uni` - Configuration and skills
- `target_workspace` → `/target` - Loaded project (persistent volume)
- `${UNI_TARGET_SOURCE}` → `/host_target` - Read-only access to host projects
- `${UNI_HOST_ROOT}` → `/host_root` - Read-only access to host root (for project loading)

### Stopping the Environment

```bash
docker-compose down
```

## Architecture

The plugin is a shim that:
- Clones/updates configured repos 
- Registers hooks that load skills from the local repository clones
- Offers users the option to fork the skills repos for contributions

## Target Directory - Project Loading

The uni dev container includes a `/target` directory where you can load external projects for analysis and development

### Loading 

```bash
# Load projects from outside container
# Windows
./load-project.ps1 "C:\dev\my-project"

# Manage target directory
./load-project.ps1 -Clear     # Clear (Windows)
./load-project.ps1 -List      # List (Windows)
```

### Project Analysis Features

When you load a project, uni automatically detects:

- **Project Type**: Node.js, Python, Rust, Go, Java, etc.
- **Package Files**: package.json, requirements.txt, Cargo.toml, etc.
- **Git Information**: Repository status and remotes
- **Documentation**: README files and project structure
- **Claude.MD file**: Which should expose AI readable information about the project

### Git Workflow on Target Projects

When working on a loaded project, Claude will:

1. **Create a feature branch** - New branch for your changes
2. **Commit changes** - Regular commits as work progresses

Claude does **not** automatically push or create pull requests. You maintain control over:
- When to push the branch
- Whether to create a PR
- Review before sharing changes

This allows you to review Claude's work locally before publishing.

## Updating Skills

The plugin fetches and fast-forwards your local skills repository on each session start. If your local branch has diverged, Claude notifies you to use the pulling-updates-from-skills-repository skill.

## Testing Skills Branches

You can test different branches of the skills repository by updating the configuration. Changes take effect on the **next Claude session start** (no Docker restart required).

### Set Branch Using Script
```bash
./set-skills-branch.sh feature/new-instructions
```

### Set Branch Manually
Edit `.uni/config.json`:
```json
{
  "skillsBranch": "your-branch-name"
}
```

### Check Current Branch
```bash
./set-skills-branch.sh
# Shows current configured branch
```

**Note:** The `SessionStart` hook reads `.uni/config.json` when Claude starts, so branch changes apply immediately on the next session without restarting Docker

## Contributing Skills

If you forked the skills repository during setup, you can contribute improvements:

1. Edit skills in `~/.config/uni/skills/`
2. Commit your changes
3. Push to your fork
4. Open a PR to `tmoxon/uni-core-skills`

## How It Works

1. **SessionStart Hook** - Clone/update skills repo, inject skills context
2. **Skills Discovery** - `find-skills` shows all available skills with descriptions
3. **Mandatory Workflow** - Skills become required when they exist for your task
4. **Gap Tracking** - Failed searches logged for skill development

## Architectural Decision Records (ADRs)

### What are ADRs?
ADRs document significant architectural decisions and their context. They capture the "why" behind choices, especially when deviating from best practices or making trade-offs.

### When Claude Raises ADRs
During the brainstorming phase, after design approval, Claude evaluates if the design meets ADR criteria:
- Public API contracts changed or added
- Database schemas changed affecting other consumers
- New caches (local/in-memory) affecting system state
- New infrastructure or services required
- PII stored in a new way
- Significant project structure changes
- Breaking changes to public APIs
- Deliberate deviations from best practices or use of anti-patterns

If **any** answer is YES, Claude stops and announces: "I'm going to create an ADR to cover the key decisions made as part of this plan"

### How Claude Creates ADRs
1. **Automatic Detection:** During brainstorming, Claude identifies architectural decisions that need documentation
2. **Skill Invocation:** Switches to `@collaboration/create-adr` skill
3. **ADR Generation:** Creates structured ADR files in `docs/adr/XXXX-<title>.md` with:
   - Context (why the decision was needed)
   - Decision (what was chosen)
   - Consequences (positive and negative impacts)
   - Alternatives (rejected options)
   - Notes (who should review)
4. **Git Commit:** Commits ADRs before planning begins
5. **Verification:** Writing-plans skill checks for ADRs and stops if needed but missing

### ADR Structure
Each ADR includes:
- **Title & Date:** What and when
- **Status:** Proposed, accepted, rejected, deprecated, or superseded
- **Context:** Problem background and circumstances
- **Decision:** The actual choice made
- **Consequences:** Impact on the system
- **Alternatives:** Other options considered
- **Notes:** Stakeholder review recommendations (InfoSec, AppSec, Privacy, Infrastructure teams)

## Philosophy

### Test-Driven Development

- Write tests first, always
- Forcing Red-Green-Refactor cycles at the agent level produces better, testable code and catches issues early.

### Hierarchical Plan Structure and Agent Isolation
- Hierarchical structure with isolated contexts keeps agents focused on single responsibilities and enables parallel execution.
- Plans use main tasks (1, 2, 3) and subtasks (1.1, 1.2, etc.)
- Agents cannot see full plan or other task details
- Each task number receives a dedicated agent with isolated context
- Individual task files provide cleaner agent isolation and easier maintenance rather than a large single file.

### Parallel Task Execution
- Dependency-aware parallel dispatch for independent tasks.
- Independent tasks (different domains, no shared files) execute concurrently

### Plan Commitment Requirement
- Plans must be committed to git before execution begins
- Plans become versioned documentation alongside implementation

### Other 
- **Systematic over ad-hoc** - Process over guessing
- **Complexity reduction** - Simplicity as primary goal
- **Evidence over claims** - Verify before declaring success
- **Domain over implementation** - Work at problem level, not solution level

## License

MIT License - see LICENSE file for details
