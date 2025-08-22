#!/bin/bash
# Warp Installation Script

set -e

WARP_DIR="$HOME/.warp"
REPO_URL="https://github.com/user/warp.git"

log_info() { echo -e "\033[0;34m🚀 $1\033[0m"; }
log_success() { echo -e "\033[0;32m✅ $1\033[0m"; }
log_warning() { echo -e "\033[1;33m⚠️  $1\033[0m"; }
log_error() { echo -e "\033[0;31m❌ $1\033[0m"; }

# Install Warp
install_warp() {
    log_info "Installing Warp Development Toolkit..."
    
    # Clone repository
    if [[ -d "$WARP_DIR" ]]; then
        log_warning "Warp directory already exists. Updating..."
        cd "$WARP_DIR"
        git pull origin main
    else
        log_info "Cloning Warp repository..."
        git clone "$REPO_URL" "$WARP_DIR"
    fi
    
    cd "$WARP_DIR"
    
    # Make scripts executable
    log_info "Setting up permissions..."
    find src/ bin/ scripts/ -name "*.sh" -exec chmod +x {} \;
    chmod +x bin/warp
    
    # Create symlink
    log_info "Creating system symlink..."
    sudo ln -sf "$WARP_DIR/bin/warp" /usr/local/bin/warp
    
    # Setup shell integration
    setup_shell_integration
    
    # Install dependencies
    install_dependencies
    
    # Setup WordPress development
    setup_wordpress_development
    
    log_success "Warp installed successfully!"
    log_info "Run 'warp help' to get started"
}

setup_shell_integration() {
    log_info "Setting up shell integration..."
    
    local shell_file=""
    case "$SHELL" in
        */zsh) shell_file="$HOME/.zshrc" ;;
        */bash) shell_file="$HOME/.bashrc" ;;
        *) log_warning "Unsupported shell: $SHELL" ;;
    esac
    
    if [[ -n "$shell_file" ]]; then
        # Add Warp to PATH
        if ! grep -q "# Warp Development Toolkit" "$shell_file"; then
            cat >> "$shell_file" << 'EOF'

# Warp Development Toolkit
export PATH="$PATH:$HOME/.warp/bin"

# Warp aliases
alias cq="warp quality"
alias sec="warp security"
alias docs="warp docs"
alias gf="warp git"
alias gh-new="warp github new"
alias wp-dev="warp wordpress"

# WordPress development aliases
alias wp-plugin="warp wordpress plugin"
alias wp-theme="warp wordpress theme"

# Quality checks
alias check-all="warp quality && warp security"
alias docs-gen="warp docs generate --website"

# Git workflow
alias gfs="warp git status"
alias gfc="warp git commit"
alias gfp="warp git pr"
EOF
        fi
        
        log_success "Shell integration added to $shell_file"
        log_info "Restart your terminal or run: source $shell_file"
    fi
}

install_dependencies() {
    log_info "Installing dependencies..."
    
    # Check for required tools
    local missing_tools=()
    
    command -v git >/dev/null || missing_tools+=("git")
    command -v docker >/dev/null || missing_tools+=("docker")
    command -v jq >/dev/null || missing_tools+=("jq")
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_warning "Missing required tools: ${missing_tools[*]}"
        log_info "Please install them manually:"
        
        for tool in "${missing_tools[@]}"; do
            case "$tool" in
                "git") echo "  - Git: https://git-scm.com/downloads" ;;
                "docker") echo "  - Docker: https://docs.docker.com/get-docker/" ;;
                "jq") echo "  - jq: brew install jq (macOS) or apt-get install jq (Linux)" ;;
            esac
        done
    fi
    
    # Install optional tools
    log_info "Installing optional development tools..."
    
    # GitHub CLI
    if ! command -v gh >/dev/null; then
        log_info "Installing GitHub CLI..."
        if [[ "$OSTYPE" == "darwin"* ]]; then
            brew install gh 2>/dev/null || log_warning "Failed to install GitHub CLI. Install manually: brew install gh"
        else
            log_warning "Please install GitHub CLI manually: https://cli.github.com/"
        fi
    fi
    
    # Act (GitHub Actions runner)
    if ! command -v act >/dev/null; then
        log_info "Installing Act..."
        if [[ "$OSTYPE" == "darwin"* ]]; then
            brew install act 2>/dev/null || log_warning "Failed to install Act. Install manually: brew install act"
        else
            log_warning "Please install Act manually: https://github.com/nektos/act"
        fi
    fi
}

setup_wordpress_development() {
    log_info "Setting up WordPress development environment..."
    
    # Create WordPress development directory
    mkdir -p "$HOME/.warp/wordpress-dev"
    
    # Setup WordPress development templates
    cp -r "$WARP_DIR/src/wordpress/templates"/* "$HOME/.warp/wordpress-dev/" 2>/dev/null || true
    
    log_success "WordPress development environment ready"
}

# Run installation
install_warp
