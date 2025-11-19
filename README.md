# Uni!

Equip Claude with a comprehensive skills library of proven techniques, patterns, and tools.

This builds on the great work provided at [superpowers](https://github.com/obra/superpowers), extending with support for multiple skills sources

> 💡 **For developers and contributors**, see [DEVELOPMENT.md](DEVELOPMENT.md) for architecture details, testing workflows, and contribution guidelines.
> 
> 📚 **For project insights and design decisions**, see [LEARNINGS.md](LEARNINGS.md) for lessons learned and implementation notes.

## What You Get

- **Testing Skills** - TDD, async testing, anti-patterns
- **Debugging Skills** - Systematic debugging, root cause tracing, verification
- **Collaboration Skills** - Brainstorming, planning, code review, parallel agents
- **Meta Skills** - Creating, testing, and contributing skills

Plus:
- **Slash Commands** - `/brainstorm`, `/create-adr`, `/write-plan`, `/execute-plan`
- **Skills Search** - Grep-powered discovery of relevant skills
- **Gap Tracking** - Failed searches logged for skill creation

## Learn More

Read the introduction: [Superpowers for Claude Code](https://blog.fsck.com/2025/10/09/superpowers/)

## Prerequisites

- **Python 3.11+** - Required for cross-platform compatibility
- **Git** - For skills repository management
- **Claude Code (VS Code Extension)** - Latest version

## Installation

### Install the plugin

**Option 1: Via GitHub (Recommended)**

Clone the repository directly to your Claude plugins directory:

**Windows:**
```powershell
# Create plugins directory if it doesn't exist
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.claude\plugins"

# Clone the repository
cd "$env:USERPROFILE\.claude\plugins"
git clone https://github.com/tmoxon/uni.git
```

**Mac/Linux:**
```bash
# Create plugins directory if it doesn't exist
mkdir -p ~/.claude/plugins

# Clone the repository
cd ~/.claude/plugins
git clone https://github.com/tmoxon/uni.git
```

**Option 2: Via Marketplace (if you have a marketplace set up)**

If you have a uni marketplace configured:
```bash
/plugin marketplace add tmoxon/uni-marketplace
/plugin install uni@uni-marketplace
```

After installation, restart Claude Code / VS Code.

### Verify Installation

```bash
# Check that commands appear
/help

# Should see:
# /brainstorm - Interactive design refinement
# /write-plan - Create implementation plan
# /execute-plan - Execute plan in batches
```

## Quick Start

### Finding Skills

Find skills before starting any task:

```bash
${UNI_SKILLS}/skills/using-skills/find-skills              # All skills with descriptions
${UNI_SKILLS}/skills/using-skills/find-skills test         # Filter by pattern
${UNI_SKILLS}/skills/using-skills/find-skills 'TDD|debug'  # Regex pattern
```

### Environment Variables

Uni creates environment variables for easy skill access. These use forward slashes for cross-platform compatibility.

**Base Paths:**
```bash
${UNI_ROOT}    # Root directory (~/.config/uni)
${UNI_SKILLS}  # Skills directory (~/.config/uni/core/skills)
```

**Skill File Paths (32 skills):**
```bash
${UNI_SKILL_BRAINSTORMING}           # → .../brainstorming/SKILL.md
${UNI_SKILL_TEST_DRIVEN_DEVELOPMENT} # → .../test-driven-development/SKILL.md
${UNI_SKILL_SYSTEMATIC_DEBUGGING}    # → .../systematic-debugging/SKILL.md
# ... and 29 more
```

**Using Paths in Commands:**

**Recommended:** Use direct skill environment variables for maximum compatibility:
```bash
${UNI_SKILL_BRAINSTORMING}           # Direct path to SKILL.md
${UNI_SKILL_TEST_DRIVEN_DEVELOPMENT} # Works reliably on all platforms
```

**Alternative:** Path construction (may have issues on Windows):
```bash
${UNI_SKILLS}/skills/collaboration/brainstorming/SKILL.md
```

All 34 environment variables are listed at session start.

### Using Slash Commands

**Brainstorm a design:**
```
/brainstorm
```

**Create an implementation plan:**
```
/write-plan
```

**Execute the plan:**
```
/execute-plan
```

## Working with GitHub Issues

Claude Code can work directly with GitHub issues during brainstorming sessions. Simply provide the repository URL and issue number:

**Example:**
```
/brainstorm
I want to work on https://github.com/tmoxon/uni issue #45
```

Claude will fetch the issue details and use them as context for:
- Understanding feature requests with full discussion
- Addressing bug reports with reproduction steps
- Planning work that's already documented

This works with any public GitHub repository. For private repositories, use the GitHub CLI to authenticate:

```bash
gh auth login
```

The GitHub CLI (`gh`) is included in the Uni Docker container.

## About claude.md Files

The `claude.md` file helps Claude understand your project conventions and setup.

**Location**: Place in your project root

**Purpose**: Documents project-specific context:
- Framework and language choices (React, Next.js, TypeScript, etc.)
- Coding conventions and patterns
- Build and test procedures
- Project structure and file organization

**Format**: Human-readable Markdown documentation with optional executable actions (JSON) for patches and dependencies.

Skills automatically read `claude.md` before generating code, ensuring consistency with your project's existing patterns and conventions.

## What's Inside

### Skills Library

**Testing** (`skills/testing/`)
- test-driven-development - RED-GREEN-REFACTOR cycle
- condition-based-waiting - Async test patterns
- testing-anti-patterns - Common pitfalls to avoid

**Debugging** (`skills/debugging/`)
- systematic-debugging - 4-phase root cause process
- root-cause-tracing - Find the real problem
- verification-before-completion - Ensure it's actually fixed
- defense-in-depth - Multiple validation layers

**Collaboration** (`skills/collaboration/`)
- brainstorming - Socratic design refinement
- writing-plans - Detailed implementation plans
- executing-plans - Batch execution with checkpoints
- dispatching-parallel-agents - Concurrent subagent workflows
- remembering-conversations - Search past work
- using-git-worktrees - Parallel development branches
- requesting-code-review - Pre-review checklist
- receiving-code-review - Responding to feedback

**Meta** (`skills/meta/`)
- writing-skills - TDD for documentation, create new skills
- sharing-skills - Contribute skills back via branch and PR
- testing-skills-with-subagents - Validate skill quality
- pulling-updates-from-skills-repository - Sync with upstream
- gardening-skills-wiki - Maintain and improve skills

### Commands

- **brainstorm.md** - Interactive design refinement using Socratic method
- **write-plan.md** - Create detailed implementation plans
- **execute-plan.md** - Execute plans in batches with review checkpoints

### Tools

- **find-skills** - Unified skill discovery with descriptions
- **skill-run** - Generic runner for any skill script
- **search-conversations** - Semantic search of past Claude sessions (in remembering-conversations skill)

**Using tools:**
```bash
${UNI_SKILLS}/skills/using-skills/find-skills              # Show all skills
${UNI_SKILLS}/skills/using-skills/find-skills pattern      # Search skills
${UNI_SKILLS}/skills/using-skills/skill-run <path> [args]  # Run any skill script
```

## Installation Troubleshooting

### Python Not Found

If you get "python command not found", ensure Python 3.11+ is installed and in your PATH:

**Windows:**
```powershell
python --version  # Should show 3.11 or higher
```

**Mac/Linux:**
```bash
python3 --version  # Should show 3.11 or higher
```

### Testing the Hook Manually

You can test the session-start hook directly:

```bash
# Windows
python hooks/session-start.py

# Mac/Linux
python3 hooks/session-start.py
```

This should output JSON with skill information.

### Uninstalling / Reinstalling

There appear to be bugs in handling plugins through the marketplace connections. If you run into problems and can't uninstall it, then:

1. Delete the folder ~/.config/uni
1. Delete the folder ~/.claude/plugins/cache/uni
1. Update the file ~/.claude/settings.json to remove uni
1. Restart vs code / claude

### JSON error when adding a marketplace

If you see an error similar to 'Unexpected token '', "{..." is not valid JSON'

1. Reinstall your Claude Code extension

## License

MIT License - see LICENSE file for details
