#!/usr/bin/env python3
"""
SessionStart hook for uni - Cross-platform Python version

This script:
1. Reads configuration from .uni/config.json
2. Manages skill repositories (clone/fetch/update)
3. Discovers all available skills
4. Creates environment variables for each skill (UNI_SKILL_*)
5. Outputs JSON context for Claude
"""

import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Dict, List, Tuple, Optional

# ============================================================================
# CONFIGURATION
# ============================================================================

SKILL_REPOS = [
    {
        "name": "core",
        "url": "https://github.com/tmoxon/uni-core-skills",
        "branch": None  # Will be read from config
    },
    # Add more repos here as needed
]

DEFAULT_BRANCH = "main"


# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

def get_config_path() -> Path:
    """Get the path to the config file."""
    # Try workspace-relative path first
    workspace_config = Path("/workspace/.uni/config.json")
    if workspace_config.exists():
        return workspace_config
    
    # Fall back to current directory relative path
    current_config = Path.cwd() / ".uni" / "config.json"
    if current_config.exists():
        return current_config
    
    return workspace_config  # Return default even if it doesn't exist


def get_skills_branch() -> str:
    """Read the skills branch from config file."""
    config_path = get_config_path()
    
    try:
        if config_path.exists():
            with open(config_path, 'r', encoding='utf-8') as f:
                config = json.load(f)
                branch = config.get('skillsBranch')
                if branch:
                    return branch
    except (json.JSONDecodeError, IOError) as e:
        print(f"Warning: Could not read config file: {e}", file=sys.stderr)
    
    return DEFAULT_BRANCH


def get_uni_root() -> Path:
    """Get the UNI_ROOT directory path."""
    # Check if we're running in a bash/MSYS/Cygwin environment on Windows
    home = os.environ.get('HOME', '')
    
    # Convert Git Bash style paths (/c/Users/...) to Windows paths (C:/Users/...)
    if home.startswith('/') and len(home) > 2 and home[2] == '/':
        # Looks like /c/Users/... or /d/Program Files/...
        drive_letter = home[1].upper()
        rest_of_path = home[3:]  # Skip /c/
        # Convert to C:/Users/... format
        windows_path = f"{drive_letter}:/{rest_of_path}"
        return Path(windows_path) / ".config" / "uni"
    elif home.startswith('/home/'):
        # Real Unix/WSL path
        return Path(home) / ".config" / "uni"
    
    # Otherwise use standard Python Path.home()
    return Path.home() / ".config" / "uni"


def run_git_command(args: List[str], cwd: Path, check: bool = True) -> Tuple[bool, str]:
    """
    Run a git command and return success status and output.
    
    Args:
        args: Git command arguments
        cwd: Working directory
        check: If True, raise on non-zero exit
    
    Returns:
        Tuple of (success, output)
    """
    try:
        result = subprocess.run(
            ['git'] + args,
            cwd=cwd,
            capture_output=True,
            text=True,
            check=check
        )
        return True, result.stdout.strip()
    except subprocess.CalledProcessError as e:
        return False, e.stderr.strip()
    except FileNotFoundError:
        print("ERROR: git command not found. Please install Git.", file=sys.stderr)
        sys.exit(1)


def initialize_repository(repo: Dict[str, str], uni_root: Path) -> Tuple[bool, bool, List[str]]:
    """
    Initialize or update a skill repository.
    
    Args:
        repo: Repository configuration dict
        uni_root: UNI_ROOT directory path
    
    Returns:
        Tuple of (updated, behind, messages)
    """
    repo_name = repo['name']
    repo_url = repo['url']
    repo_branch = repo['branch']
    repo_dir = uni_root / repo_name
    
    messages = []
    updated = False
    behind = False
    
    # Check if repository exists
    if (repo_dir / ".git").exists():
        # Repository exists - fetch and update
        messages.append(f"Fetching latest changes for {repo_name}...")
        
        # Determine remote name (try upstream first, then origin)
        success, _ = run_git_command(['remote', 'get-url', 'upstream'], repo_dir, check=False)
        remote_name = 'upstream' if success else 'origin'
        
        # Fetch from remote
        run_git_command(['fetch', remote_name], repo_dir, check=False)
        
        # Check current branch
        success, current_branch = run_git_command(
            ['rev-parse', '--abbrev-ref', 'HEAD'], 
            repo_dir, 
            check=False
        )
        
        # Switch branches if needed
        if success and current_branch != repo_branch:
            messages.append(f"Switching {repo_name} from '{current_branch}' to '{repo_branch}'...")
            
            # Check if branch exists locally
            success, _ = run_git_command(
                ['show-ref', '--verify', '--quiet', f'refs/heads/{repo_branch}'],
                repo_dir,
                check=False
            )
            
            if success:
                # Branch exists locally
                run_git_command(['checkout', repo_branch], repo_dir, check=False)
            else:
                # Check if branch exists on remote
                success, _ = run_git_command(
                    ['show-ref', '--verify', '--quiet', f'refs/remotes/{remote_name}/{repo_branch}'],
                    repo_dir,
                    check=False
                )
                
                if success:
                    # Create local branch tracking remote
                    messages.append(f"Creating local branch '{repo_branch}' tracking {remote_name}/{repo_branch}...")
                    run_git_command(
                        ['checkout', '-b', repo_branch, f'{remote_name}/{repo_branch}'],
                        repo_dir,
                        check=False
                    )
                else:
                    messages.append(f"Warning: Branch {repo_branch} not found for {repo_name}")
        
        # Check if we can fast-forward
        success_local, local_sha = run_git_command(['rev-parse', '@'], repo_dir, check=False)
        success_remote, remote_sha = run_git_command(['rev-parse', '@{u}'], repo_dir, check=False)
        success_base, base_sha = run_git_command(['merge-base', '@', '@{u}'], repo_dir, check=False)
        
        if success_local and success_remote and local_sha != remote_sha:
            if success_base and local_sha == base_sha:
                # Can fast-forward
                messages.append(f"Updating {repo_name} repository to latest version...")
                success, output = run_git_command(['merge', '--ff-only', '@{u}'], repo_dir, check=False)
                if success:
                    messages.append(f"✓ {repo_name} repository updated successfully")
                    updated = True
                else:
                    messages.append(f"Failed to update {repo_name} repository")
            else:
                # Can't fast-forward - behind
                behind = True
    else:
        # Repository doesn't exist - clone it
        messages.append(f"Initializing {repo_name} repository...")
        uni_root.mkdir(parents=True, exist_ok=True)
        
        success, output = run_git_command(['clone', repo_url, str(repo_dir)], uni_root, check=False)
        
        if success:
            # Checkout the specified branch if not already on it
            success, current_branch = run_git_command(
                ['rev-parse', '--abbrev-ref', 'HEAD'],
                repo_dir,
                check=False
            )
            
            if success and current_branch != repo_branch:
                run_git_command(['checkout', repo_branch], repo_dir, check=False)
            
            # Set up upstream remote for core repo
            if repo_name == "core":
                run_git_command(['remote', 'add', 'upstream', repo_url], repo_dir, check=False)
            
            messages.append(f"{repo_name} repository initialized at {repo_dir}")
        else:
            messages.append(f"Failed to clone {repo_name}: {output}")
    
    return updated, behind, messages


def discover_skills(uni_root: Path, repos: List[Dict[str, str]]) -> Tuple[str, Dict[str, str], str]:
    """
    Discover all skills across repositories.
    
    Args:
        uni_root: UNI_ROOT directory path
        repos: List of repository configurations
    
    Returns:
        Tuple of (all_skills_text, env_vars_dict, repos_list_text)
    """
    all_skills_parts = []
    env_vars = {}
    repos_list_parts = []
    
    for repo in repos:
        repo_name = repo['name']
        repo_path = uni_root / repo_name / "skills"
        
        if not repo_path.exists():
            continue
        
        repos_list_parts.append(f"- {repo_name}: {repo_path}")
        
        # Try to use find-skills script if available
        find_skills_script = repo_path / "using-skills" / "find-skills"
        repo_skills_text = ""
        
        if find_skills_script.exists():
            try:
                result = subprocess.run(
                    [str(find_skills_script)],
                    capture_output=True,
                    text=True,
                    check=False
                )
                if result.returncode == 0:
                    repo_skills_text = result.stdout.strip()
            except Exception:
                pass
        
        if not repo_skills_text:
            # Fallback: list skill directories
            try:
                skill_dirs = [d.name for d in repo_path.iterdir() if d.is_dir()]
                skill_dirs.sort()
                repo_skills_text = "\n".join(skill_dirs)
            except Exception:
                pass
        
        if repo_skills_text:
            all_skills_parts.append(f"### Skills from repository: {repo_name}\n{repo_skills_text}")
        
        # Create environment variables for each skill
        # These will be available as fallback if path construction doesn't work
        try:
            for skill_category in repo_path.iterdir():
                if not skill_category.is_dir():
                    continue
                
                for skill_dir in skill_category.iterdir():
                    if not skill_dir.is_dir():
                        continue
                    
                    skill_file = skill_dir / "SKILL.md"
                    if skill_file.exists():
                        # Create per-skill environment variable
                        # e.g., UNI_SKILL_BRAINSTORMING -> path/to/skills/collaboration/brainstorming/SKILL.md
                        skill_name = skill_dir.name.upper().replace("-", "_")
                        env_var_name = f"UNI_SKILL_{skill_name}"
                        env_vars[env_var_name] = str(skill_file).replace("\\", "/")
        except Exception as e:
            print(f"Warning: Error discovering skills in {repo_name}: {e}", file=sys.stderr)
    
    all_skills_text = "\n\n".join(all_skills_parts)
    repos_list_text = "\n".join(repos_list_parts)
    
    return all_skills_text, env_vars, repos_list_text


def read_using_skills_content(uni_root: Path) -> str:
    """Read the using-skills SKILL.md content from core repository."""
    using_skills_path = uni_root / "core" / "skills" / "using-skills" / "SKILL.md"
    
    try:
        if using_skills_path.exists():
            with open(using_skills_path, 'r', encoding='utf-8') as f:
                return f.read()
    except Exception as e:
        print(f"Warning: Could not read using-skills content: {e}", file=sys.stderr)
    
    return f"uni is ready. Skills are organized in repositories under {uni_root}/\n\nNote: Expected to find skills/using-skills/SKILL.md in core repository but it was not found."


def escape_for_json(text: str) -> str:
    """Escape text for JSON string inclusion."""
    # JSON escaping is handled by json.dumps, but we need to preserve newlines for readability
    return text


# ============================================================================
# MAIN LOGIC
# ============================================================================

def main():
    """Main entry point."""
    try:
        # Get configuration
        skills_branch = get_skills_branch()
        uni_root = get_uni_root()
        
        # Update repo configurations with the branch from config
        for repo in SKILL_REPOS:
            if repo['branch'] is None:
                repo['branch'] = skills_branch
        
        # Validate that we have a "core" repository
        if not any(repo['name'] == 'core' for repo in SKILL_REPOS):
            error_msg = 'ERROR: uni configuration requires at least one repository named "core". Please check hooks/session-start.py configuration.'
            output = {
                "hookSpecificOutput": {
                    "hookEventName": "SessionStart",
                    "additionalContext": error_msg
                }
            }
            print(json.dumps(output), file=sys.stderr)
            sys.exit(1)
        
        # Set environment variables
        os.environ['UNI_ROOT'] = str(uni_root)
        os.environ['UNI_SKILLS'] = str(uni_root / "core")  # Points to /core, not /core/skills!
        
        # Initialize all repositories
        any_updated = False
        any_behind = False
        all_messages = []
        
        for repo in SKILL_REPOS:
            updated, behind, messages = initialize_repository(repo, uni_root)
            any_updated = any_updated or updated
            any_behind = any_behind or behind
            all_messages.extend(messages)
        
        # Discover skills and create environment variables
        all_skills_text, env_vars, repos_list_text = discover_skills(uni_root, SKILL_REPOS)
        
        # Add base environment variables - note: UNI_SKILLS points to /core, not /core/skills
        # This matches the bash script behavior
        env_vars["UNI_ROOT"] = str(uni_root).replace("\\", "/")
        env_vars["UNI_SKILLS"] = str(uni_root / "core").replace("\\", "/")
        
        # Set ALL environment variables in the process so Claude can use them
        for key, value in env_vars.items():
            os.environ[key] = value
        
        # Read using-skills content
        using_skills_content = read_using_skills_content(uni_root)
        
        # Build initialization messages
        init_message = "\n".join(all_messages)
        if init_message:
            init_message += "\n\n"
        
        # Build status message
        status_message = ""
        if any_behind:
            status_message = "\n\n⚠️ New skills available from upstream. Ask me to use the pulling-updates-from-skills-repository skill."
        
        # Build environment variables section
        env_vars_text = "\n".join(f"- {key}={value}" for key, value in sorted(env_vars.items()))
        
        # Build additional context
        additional_context = f"""<EXTREMELY_IMPORTANT>
You have access to the uni.

{init_message}**The content below is from skills/using-skills/SKILL.md - your introduction to using skills:**

{using_skills_content}

**uni Configuration:**
- Root directory: {uni_root}
- Skills directory: {uni_root / "core"}
- Active repositories:
{repos_list_text}

**Environment Variables for Skills:**
{env_vars_text}

**Available skills across all repositories:**
{all_skills_text}{status_message}
</EXTREMELY_IMPORTANT>"""
        
        # Output JSON
        output = {
            "hookSpecificOutput": {
                "hookEventName": "SessionStart",
                "additionalContext": additional_context
            }
        }
        
        print(json.dumps(output, indent=2))
        sys.exit(0)
        
    except Exception as e:
        error_output = {
            "hookSpecificOutput": {
                "hookEventName": "SessionStart",
                "additionalContext": f"ERROR: Session start failed: {str(e)}"
            }
        }
        print(json.dumps(error_output), file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
