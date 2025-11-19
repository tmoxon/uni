#!/usr/bin/env bash
set -euo pipefail

# Accept repository configurations as arguments
# Format: "name|url|branch"
REPO_CONFIGS=("$@")

# Base directory for all skill repositories
UNI_ROOT="${HOME}/.config/uni"

# Ensure the uni root directory exists
mkdir -p "$UNI_ROOT" 2>/dev/null || true

# Track overall status
ANY_UPDATED=false
ANY_BEHIND=false

# Process each repository
for repo_config in "${REPO_CONFIGS[@]}"; do
    IFS='|' read -r repo_name repo_url repo_branch <<< "$repo_config"

    # Default to main if no branch specified
    if [ -z "$repo_branch" ]; then
        repo_branch="main"
    fi

    REPO_DIR="$UNI_ROOT/$repo_name"

    # Check if repository directory exists and is a valid git repo
    if [ -d "$REPO_DIR/.git" ]; then
        cd "$REPO_DIR"

        # Get the remote name (try upstream first, then origin)
        REMOTE_NAME=""
        if git remote get-url upstream >/dev/null 2>&1; then
            REMOTE_NAME="upstream"
        elif git remote get-url origin >/dev/null 2>&1; then
            REMOTE_NAME="origin"
        fi

        # Fetch from the remote to get latest branch information
        if [ -n "$REMOTE_NAME" ]; then
            echo "Fetching latest changes from $REMOTE_NAME..."
            git fetch "$REMOTE_NAME" 2>/dev/null || true
        fi

        # Check if we need to switch branches
        CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
        if [ -n "$CURRENT_BRANCH" ] && [ "$CURRENT_BRANCH" != "$repo_branch" ]; then
            echo "Switching $repo_name from branch '$CURRENT_BRANCH' to '$repo_branch'..."
            
            # Check if the branch exists locally
            if git show-ref --verify --quiet "refs/heads/$repo_branch"; then
                # Branch exists locally, just checkout
                git checkout "$repo_branch" 2>/dev/null || echo "Warning: Could not checkout local branch $repo_branch for $repo_name"
            elif [ -n "$REMOTE_NAME" ] && git show-ref --verify --quiet "refs/remotes/$REMOTE_NAME/$repo_branch"; then
                # Branch exists on remote but not locally, create local branch tracking remote
                echo "Creating local branch '$repo_branch' tracking $REMOTE_NAME/$repo_branch..."
                git checkout -b "$repo_branch" "$REMOTE_NAME/$repo_branch" 2>/dev/null || echo "Warning: Could not create and checkout branch $repo_branch from $REMOTE_NAME/$repo_branch for $repo_name"
            else
                echo "Warning: Branch $repo_branch not found locally or on remote $REMOTE_NAME for $repo_name"
            fi
        fi

        # Check if we can fast-forward
        LOCAL=$(git rev-parse @ 2>/dev/null || echo "")
        REMOTE=$(git rev-parse @{u} 2>/dev/null || echo "")
        BASE=$(git merge-base @ @{u} 2>/dev/null || echo "")

        # Try to fast-forward merge first
        if [ -n "$LOCAL" ] && [ -n "$REMOTE" ] && [ "$LOCAL" != "$REMOTE" ]; then
            # Check if we can fast-forward (local is ancestor of remote)
            if [ "$LOCAL" = "$BASE" ]; then
                # Fast-forward merge is possible
                echo "Updating $repo_name repository to latest version..."
                if git merge --ff-only @{u} 2>&1; then
                    echo "✓ $repo_name repository updated successfully"
                    ANY_UPDATED=true
                else
                    echo "Failed to update $repo_name repository"
                fi
            else
                # Can't fast-forward - will be reported at the end
                ANY_BEHIND=true
            fi
        fi
    else
        # Repository doesn't exist or isn't a git repo - initialize it
        echo "Initializing $repo_name repository..."

        # Clone the repository
        git clone "$repo_url" "$REPO_DIR"

        cd "$REPO_DIR"

        # Checkout the specified branch if not already on it
        CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
        if [ "$CURRENT_BRANCH" != "$repo_branch" ]; then
            git checkout "$repo_branch" 2>/dev/null || echo "Warning: Could not checkout branch $repo_branch for $repo_name"
        fi

        # Offer to fork if gh is installed (only for the first/core repo)
        if [ "$repo_name" = "core" ] && command -v gh &> /dev/null; then
            echo ""
            echo "GitHub CLI detected. Would you like to fork the $repo_name skills repository?"
            echo "Forking allows you to share skill improvements with the community."
            echo ""
            read -p "Fork repository? (y/N): " -n 1 -r
            echo

            if [[ $REPLY =~ ^[Yy]$ ]]; then
                # Extract owner/repo from URL
                repo_slug=$(echo "$repo_url" | sed -E 's#.*/([^/]+/[^/]+)(\.git)?$#\1#' | sed 's/\.git$//')
                gh repo fork "$repo_slug" --remote=true
                echo "Forked! You can now contribute skills back to the community."
            else
                git remote add upstream "$repo_url" 2>/dev/null || true
            fi
        else
            # No gh, just set up upstream remote
            git remote add upstream "$repo_url" 2>/dev/null || true
        fi

        echo "$repo_name repository initialized at $REPO_DIR"
    fi
done

# Output status flags
if [ "$ANY_UPDATED" = true ]; then
    echo "SKILLS_UPDATED=true"
fi

if [ "$ANY_BEHIND" = true ]; then
    echo "SKILLS_BEHIND=true"
fi

exit 0
