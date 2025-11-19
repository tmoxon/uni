# Uni Development Guide

This guide covers development workflows, architecture details, and contribution processes for Uni.

## Development Environment

### Prerequisites

- **Python 3.11+** - Required for cross-platform session-start hook
- **Git** - For version control and skills repository management
- **Docker** (optional) - For containerized development environment

### Platform Support

Uni now works across all platforms:
- **Windows** - Native support using Python
- **macOS** - Native support using Python
- **Linux** - Native support using Python
- **WSL** - Works in Windows Subsystem for Linux
- **Docker** - Containerized environment available

### Local Development (All Platforms)

Once you've installed uni via the Claude plugin system, the session-start hook will automatically:

1. Clone the skills repository to `~/.config/uni/core` (or `%USERPROFILE%\.config\uni\core` on Windows)
2. Checkout the configured branch from `.uni/config.json`
3. Create environment variables for all skills
4. Inject skill context into Claude

**Testing the hook manually:**

```bash
# Windows
python hooks/session-start.py

# Mac/Linux
python3 hooks/session-start.py
```

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

The plugin is a Python-based shim that:
- Reads configuration from `.uni/config.json`
- Clones/updates configured skill repositories to `~/.config/uni/`
- Discovers all available skills across repositories
- Creates environment variables for each skill (e.g., `UNI_SKILL_BRAINSTORMING`)
- Registers hooks that inject skill context into Claude sessions
- Works cross-platform (Windows, macOS, Linux)

### Session Start Hook

The `hooks/session-start.py` script runs at the start of each Claude session and:

1. **Reads branch configuration** from `.uni/config.json`
2. **Initializes repositories**:
   - Clones if needed
   - Fetches latest changes
   - Switches branches if configured
   - Fast-forwards when possible
3. **Discovers skills**:
   - Scans all skill directories
   - Creates `UNI_SKILL_*` environment variables
   - Builds skill lists for Claude
4. **Outputs JSON context** with:
   - Skill documentation
   - Environment variables
   - Repository status
   - Available skills list

### Environment Variables

The session-start hook creates environment variables for skills and base paths.

**Per-Skill File Path:**
```
UNI_SKILL_{SKILL_NAME} = path/to/skill/SKILL.md
```

**Base Paths:**
```
UNI_ROOT = ~/.config/uni
UNI_SKILLS = ~/.config/uni/core/skills
```

**Examples:**
- `UNI_SKILL_BRAINSTORMING` → `.../collaboration/brainstorming/SKILL.md`
- `UNI_SKILL_TEST_DRIVEN_DEVELOPMENT` → `.../testing/test-driven-development/SKILL.md`
- `UNI_SKILL_SYSTEMATIC_DEBUGGING` → `.../debugging/systematic-debugging/SKILL.md`

**Total:** 34 environment variables (2 base paths + 32 skill paths)

**Path Construction vs Direct Variables:**

**Recommended approach:** Use direct skill environment variables:
```bash
${UNI_SKILL_BRAINSTORMING}  # Full path to SKILL.md file
```

**Legacy approach:** Path construction with `${UNI_SKILLS}`:
```bash
${UNI_SKILLS}/skills/collaboration/brainstorming/SKILL.md
```

Direct skill variables are more reliable across platforms (especially Windows) since they provide absolute paths without requiring path concatenation. Commands have been updated to use this approach.

These variables are available in:
- Command files (`commands/*.md`)
- Claude's context during sessions
- Any skill that references another skill

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
