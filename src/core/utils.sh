#!/bin/bash
# Utility functions

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if we're in a git repository
is_git_repo() {
    git rev-parse --git-dir >/dev/null 2>&1
}

# Get current git branch
current_git_branch() {
    git branch --show-current 2>/dev/null || echo "main"
}

# Check if working directory is clean
is_git_clean() {
    git diff-index --quiet HEAD -- 2>/dev/null
}

# Get project root directory
get_project_root() {
    if is_git_repo; then
        git rev-parse --show-toplevel
    else
        pwd
    fi
}

# Detect project type
detect_project_type() {
    local project_types=()
    
    # WordPress Plugin
    if find . -maxdepth 1 -name "*.php" -exec grep -l "Plugin Name:" {} \; 2>/dev/null | head -1 | grep -q .; then
        project_types+=("wordpress-plugin")
    fi
    
    # WordPress Theme
    if [[ -f "style.css" ]] && grep -q "Theme Name:" style.css 2>/dev/null; then
        project_types+=("wordpress-theme")
    fi
    
    # Laravel
    if [[ -f "artisan" ]] && [[ -f "composer.json" ]] && grep -q "laravel/framework" composer.json 2>/dev/null; then
        project_types+=("laravel")
    fi
    
    # Python
    if [[ -f "requirements.txt" ]] || [[ -f "pyproject.toml" ]] || [[ -f "setup.py" ]]; then
        project_types+=("python")
    fi
    
    # Node.js/JavaScript
    if [[ -f "package.json" ]]; then
        project_types+=("javascript")
    fi
    
    # PHP (general)
    if [[ -f "composer.json" ]] && ! grep -q "laravel/framework" composer.json 2>/dev/null; then
        project_types+=("php")
    fi
    
    # Docker
    if [[ -f "Dockerfile" ]] || [[ -f "docker-compose.yml" ]]; then
        project_types+=("docker")
    fi
    
    # Go
    if [[ -f "go.mod" ]]; then
        project_types+=("go")
    fi
    
    # Rust
    if [[ -f "Cargo.toml" ]]; then
        project_types+=("rust")
    fi
    
    echo "${project_types[@]}"
}

# Validate input
validate_not_empty() {
    local value="$1"
    local name="$2"
    
    if [[ -z "$value" ]]; then
        log_error "$name is required"
        return 1
    fi
}

# Validate project name
validate_project_name() {
    local name="$1"
    
    if [[ ! "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        log_error "Project name can only contain letters, numbers, hyphens, and underscores"
        return 1
    fi
}

# Get file extension
get_file_extension() {
    echo "${1##*.}"
}

# Get file name without extension
get_file_basename() {
    local filename=$(basename "$1")
    echo "${filename%.*}"
}

# Check if port is available
is_port_available() {
    local port="$1"
    ! nc -z localhost "$port" >/dev/null 2>&1
}

# Find available port
find_available_port() {
    local start_port="${1:-8000}"
    local port=$start_port
    
    while ! is_port_available "$port"; do
        ((port++))
        if [[ $port -gt $((start_port + 100)) ]]; then
            log_error "No available ports found in range $start_port-$((start_port + 100))"
            return 1
        fi
    done
    
    echo "$port"
}

# Generate random string
generate_random_string() {
    local length="${1:-32}"
    LC_ALL=C tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c "$length"
}

# Check if running in CI
is_ci() {
    [[ -n "$CI" ]] || [[ -n "$GITHUB_ACTIONS" ]] || [[ -n "$GITLAB_CI" ]]
}

# Get OS type
get_os_type() {
    case "$OSTYPE" in
        darwin*) echo "macos" ;;
        linux*) echo "linux" ;;
        msys*|cygwin*) echo "windows" ;;
        *) echo "unknown" ;;
    esac
}

# Check if running in Docker
is_docker() {
    [[ -f /.dockerenv ]] || grep -q docker /proc/1/cgroup 2>/dev/null
}

# Spinner for long operations
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    
    while kill -0 "$pid" 2>/dev/null; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Progress bar
progress_bar() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))
    
    printf "\r["
    printf "%${filled}s" | tr ' ' '='
    printf "%${empty}s" | tr ' ' '-'
    printf "] %d%% (%d/%d)" "$percentage" "$current" "$total"
}

# Confirm prompt
confirm() {
    local message="$1"
    local default="${2:-n}"
    
    if [[ "$default" == "y" ]]; then
        read -p "$message [Y/n]: " -n 1 -r
        echo
        [[ $REPLY =~ ^[Nn]$ ]] && return 1 || return 0
    else
        read -p "$message [y/N]: " -n 1 -r
        echo
        [[ $REPLY =~ ^[Yy]$ ]] && return 0 || return 1
    fi
}

# Select from options
select_option() {
    local prompt="$1"
    shift
    local options=("$@")
    
    echo "$prompt"
    for i in "${!options[@]}"; do
        echo "$((i + 1)). ${options[$i]}"
    done
    
    while true; do
        read -p "Select option (1-${#options[@]}): " choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le ${#options[@]} ]]; then
            echo "${options[$((choice - 1))]}"
            return 0
        else
            echo "Invalid selection. Please choose 1-${#options[@]}."
        fi
    done
}

# Cleanup function
cleanup() {
    local exit_code=$?
    
    # Clean up temporary files
    [[ -n "$TEMP_DIR" ]] && rm -rf "$TEMP_DIR"
    
    # Log cleanup
    log_debug "Cleanup completed with exit code: $exit_code"
    
    exit $exit_code
}

# Set up trap for cleanup
trap cleanup EXIT INT TERM

# Create temporary directory
create_temp_dir() {
    TEMP_DIR=$(mktemp -d)
    export TEMP_DIR
    log_debug "Created temporary directory: $TEMP_DIR"
}
