# Claude Commands

Slash commands for Claude that reference skills.

## Available Commands

- `/brainstorm` - Interactive idea refinement using Socratic method (→ `${UNI_SKILL_BRAINSTORMING}`)
- `/create-adr` - Create an Architectural Decision Record (→ `${UNI_SKILL_CREATE_ADR}`)
- `/write-plan` - Create detailed implementation plan (→ `${UNI_SKILL_WRITING_PLANS}`)
- `/execute-plan` - Execute plan in batches with review (→ `${UNI_SKILL_EXECUTING_PLANS}`)

## Format

Each command is a simple markdown file that references a skill using environment variables:

```markdown
---
description: Interactive design refinement using Socratic method
---

Read and follow: ${UNI_SKILL_BRAINSTORMING}
```

The environment variables (like `${UNI_SKILL_BRAINSTORMING}`) provide direct paths to skill files and work reliably across all platforms, including Windows.

When you run the command (e.g., `/brainstorm`), Claude loads and follows that skill.

## Creating Custom Commands

To add your own commands:

1. Create `your-command.md` in this directory
2. Add a reference to a skill using its environment variable:
   ```markdown
   ---
   description: Your command description
   ---
   
   Read and follow: ${UNI_SKILL_YOUR_SKILL_NAME}
   ```
3. The environment variable name follows the convention: `UNI_SKILL_` + uppercase skill directory name with hyphens replaced by underscores
3. The command `/your-command` is now available

## Installation

These commands are automatically symlinked to `~/.claude/commands/` by the clank installer.

See `@skills/meta/installing-skills/SKILL.md` for installation details.
