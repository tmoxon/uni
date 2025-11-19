#!/usr/bin/env bash
# SessionStart hook for uni

set -euo pipefail

# ============================================================================
# CONFIGURATION: Define your skill repositories here
# ============================================================================
# Each repo should have: name, url, and optional branch
# Function to get skills branch from config
get_skills_branch() {
    local config_file="/workspace/.uni/config.json"
    local default_branch="main"
    
    # Check if config file exists and read skillsBranch with jq
    if [ -f "$config_file" ]; then
        local branch=$(jq -r '.skillsBranch // empty' "$config_file" 2>/dev/null)
        if [ -n "$branch" ] && [ "$branch" != "null" ]; then
            echo "$branch"
            return
        fi
    fi
    
    echo "$default_branch"
}

# Get branch from config file
SKILLS_BRANCH=$(get_skills_branch)

# Format: "name|url|branch" (branch read from .uni/config.json)
SKILL_REPOS=(
    "core|https://github.com/tmoxon/uni-core-skills|${SKILLS_BRANCH}"
    # Add more repos here, e.g.:
    # "custom|https://github.com/youruser/custom-skills.git|main"
)

# Set UNI_ROOT environment variable
export UNI_ROOT="${HOME}/.config/uni"

# Set UNI_SKILLS to point to the core skills repository
export UNI_SKILLS="${UNI_ROOT}/core"

# Validate that at least one repository is named "core"
has_core=false
for repo_config in "${SKILL_REPOS[@]}"; do
    IFS='|' read -r repo_name repo_url repo_branch <<< "$repo_config"
    if [ "$repo_name" = "core" ]; then
        has_core=true
        break
    fi
done

if [ "$has_core" = false ]; then
    echo '{"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": "ERROR: uni configuration requires at least one repository named \"core\". Please check hooks/session-start.sh configuration."}}' >&2
    exit 1
fi

# Run skills initialization script (handles clone/fetch/auto-update)
# Use CLAUDE_PLUGIN_ROOT if available (set by Claude Code), otherwise fallback to BASH_SOURCE
if [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then
    PLUGIN_ROOT="$CLAUDE_PLUGIN_ROOT"
else
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
fi

# Pass repo configuration to initialization script
init_output=$("${PLUGIN_ROOT}/lib/initialize-skills.sh" "${SKILL_REPOS[@]}" 2>&1 || echo "")

# Extract status flags
skills_updated=$(echo "$init_output" | grep "SKILLS_UPDATED=true" || echo "")
skills_behind=$(echo "$init_output" | grep "SKILLS_BEHIND=true" || echo "")
# Remove status flags from display output
init_output=$(echo "$init_output" | grep -v "SKILLS_UPDATED=true" | grep -v "SKILLS_BEHIND=true")

# Collect skills from all repositories
all_skills=""
all_repos_list=""

for repo_config in "${SKILL_REPOS[@]}"; do
    IFS='|' read -r repo_name repo_url repo_branch <<< "$repo_config"
    repo_path="${UNI_ROOT}/${repo_name}"

    if [ -d "$repo_path/skills" ]; then
        all_repos_list="${all_repos_list}\n- ${repo_name}: ${repo_path}/skills"

        # Try to find and run find-skills if it exists
        if [ -f "$repo_path/skills/using-skills/find-skills" ]; then
            repo_skills=$("$repo_path/skills/using-skills/find-skills" 2>&1 || echo "")
            if [ -n "$repo_skills" ]; then
                all_skills="${all_skills}\n\n### Skills from repository: ${repo_name}\n${repo_skills}"
            fi
        else
            # Fallback: list skill directories
            repo_skills=$(find "$repo_path/skills" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; 2>/dev/null | sort || echo "")
            if [ -n "$repo_skills" ]; then
                all_skills="${all_skills}\n\n### Skills from repository: ${repo_name}\n${repo_skills}"
            fi
        fi
    fi
done

# Read using-skills content from the core repository
core_repo_path="${UNI_ROOT}/core"
using_skills_content=""

if [ -f "$core_repo_path/skills/using-skills/SKILL.md" ]; then
    using_skills_content=$(cat "$core_repo_path/skills/using-skills/SKILL.md" 2>&1 || echo "")
fi

if [ -z "$using_skills_content" ]; then
    using_skills_content="uni is ready. Skills are organized in repositories under ${UNI_ROOT}/\n\nNote: Expected to find skills/using-skills/SKILL.md in core repository but it was not found."
fi

# Escape outputs for JSON
init_escaped=$(echo "$init_output" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | awk '{printf "%s\\n", $0}')
skills_escaped=$(echo -e "$all_skills" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | awk '{printf "%s\\n", $0}')
using_skills_escaped=$(echo "$using_skills_content" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | awk '{printf "%s\\n", $0}')
repos_list_escaped=$(echo -e "$all_repos_list" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | awk '{printf "%s\\n", $0}')

# Build initialization output message if present
init_message=""
if [ -n "$init_escaped" ]; then
    init_message="${init_escaped}\n\n"
fi

# Build status messages that go at the end
status_message=""
if [ -n "$skills_behind" ]; then
    status_message="\n\n⚠️ New skills available from upstream. Ask me to use the pulling-updates-from-skills-repository skill."
fi

# Output context injection as JSON
cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "<EXTREMELY_IMPORTANT>\nYou have access to the uni.\n\n${init_message}**The content below is from skills/using-skills/SKILL.md - your introduction to using skills:**\n\n${using_skills_escaped}\n\n**uni Configuration:**\n- Root directory: ${UNI_ROOT}\n- Skills directory: ${UNI_SKILLS}\n- Active repositories:${repos_list_escaped}\n\n**Available skills across all repositories:**\n${skills_escaped}${status_message}\n</EXTREMELY_IMPORTANT>"
  }
}
EOF

exit 0
