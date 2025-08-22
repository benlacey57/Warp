#!/bin/bash
# Warp Installation Script

set -e

WARP_DIR="$HOME/.warp"
REPO_URL="https://github.com/benlacey57/warp.git"
INSTALL_PREFIX="/usr/local/bin"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}🚀 $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    local missing=()
    
    command -v git >/dev/null || missing+=("git")
    command -v curl >/dev/null || missing+=("curl")
    command -v jq >/dev/null || missing+=("jq")
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing[*]}"
        echo
        echo "Please install the missing tools:"
        for tool in "${missing[@]}"; do
            case "$tool" in
                "git") echo "  Git: https://git-scm.com/downloads" ;;
                "curl") echo "  cURL: Usually pre-installed on most systems" ;;
                "jq") echo "  jq: brew install jq (macOS) or apt-get install jq (Linux)" ;;
            esac
        done
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Install Warp
install_warp() {
    log_info "Installing Warp Development Toolkit..."
    
    # Backup existing installation
    if [[ -d "$WARP_DIR" ]]; then
        log_warning "Existing Warp installation found. Creating backup..."
        mv "$WARP_DIR" "$WARP_DIR.backup.$(date +%s)"
    fi
    
    # Clone repository
    log_info "Cloning Warp repository..."
    git clone --depth 1 "$REPO_URL" "$WARP_DIR"
    
    cd "$WARP_DIR"
    
    # Set up permissions
    log_info "Setting up permissions..."
    find src/ bin/ scripts/ -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
    chmod +x bin/warp
    
    # Create system symlink
    log_info "Creating system symlink..."
    if [[ -w "$INSTALL_PREFIX" ]]; then
        ln -sf "$WARP_DIR/bin/warp" "$INSTALL_PREFIX/warp"
    else
        sudo ln -sf "$WARP_DIR/bin/warp" "$INSTALL_PREFIX/warp"
    fi
    
    # Setup configuration
    setup_configuration
    
    # Setup shell integration
    setup_shell_integration
    
    # Install optional dependencies
    install_optional_dependencies
    
    # Setup WordPress development
    setup_wordpress_development
    
    log_success "Warp installed successfully!"
    echo
    log_info "Next steps:"
    echo "  1. Restart your terminal or run: source ~/.zshrc (or ~/.bashrc)"
    echo "  2. Run 'warp help' to see available commands"
    echo "  3. Run 'warp config edit' to customize settings"
    echo
    log_info "Optional: Install additional tools for full functionality:"
    echo "  • GitHub CLI: brew install gh"
    echo "  • Docker: https://docs.docker.com/get-docker/"
    echo "  • Act: brew install act"
}

setup_configuration() {
    log_info "Setting up configuration..."
    
    # Create config directory
    mkdir -p "$WARP_DIR/config"
    
    # Copy default configurations
    cp "$WARP_DIR/config/warp.conf" "$WARP_DIR/config/warp.conf.default" 2>/dev/null || true
    
    # Create user config if it doesn't exist
    local user_config="$HOME/.warp/config/user.conf"
    if [[ ! -f "$user_config" ]]; then
        mkdir -p "$(dirname "$user_config")"
        cat > "$user_config" << 'EOF'
# User-specific Warp configuration
# Override default settings here

# Personal information
# WARP_USER_NAME="Your Name"
# WARP_USER_EMAIL="your.email@example.com"

# Preferred settings
# WARP_DEBUG=false
# WARP_LOG_LEVEL="info"

# WordPress development
# WP_DEV_PORT=8080
# WP_DEV_AUTO_INSTALL=true

# GitHub integration
# GITHUB_AUTO_CREATE_PR=false
EOF
    fi
    
    log_success "Configuration setup complete"
}

setup_shell_integration() {
    log_info "Setting up shell integration..."
    
    local shell_file=""
    case "$SHELL" in
        */zsh) shell_file="$HOME/.zshrc" ;;
        */bash) shell_file="$HOME/.bashrc" ;;
        */fish) shell_file="$HOME/.config/fish/config.fish" ;;
        *) 
            log_warning "Unsupported shell: $SHELL"
            return 0
            ;;
    esac
    
    # Add Warp to PATH and aliases
    if [[ -n "$shell_file" ]] && ! grep -q "# Warp Development Toolkit" "$shell_file" 2>/dev/null; then
        log_info "Adding Warp integration to $shell_file..."
        
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

# WordPress development
alias wp-plugin="warp wordpress plugin"
alias wp-theme="warp wordpress theme"
alias wp-start="cd ~/.warp/wordpress-dev && find . -name '*-dev.sh' -exec {} start \;"
alias wp-stop="cd ~/.warp/wordpress-dev && find . -name '*-dev.sh' -exec {} stop \;"

# Quality and security
alias check-all="warp quality && warp security"
alias check-quick="warp quality --quick && warp security --quick"

# Documentation
alias docs-gen="warp docs generate --website"
alias docs-serve="warp docs serve"

# Git workflow
alias gfs="warp git status"
alias gfc="warp git commit"
alias gfp="warp git pr"
alias gff="warp git finish"

# Project creation shortcuts
new-python() { warp github new "$1" python "$2"; }
new-node() { warp github new "$1" javascript "$2"; }
new-laravel() { warp github new "$1" laravel-api "$2"; }
new-wp-plugin() { warp github new "$1" wordpress-plugin "$2"; }
new-wp-theme() { warp github new "$1" wordpress-theme "$2"; }

# Full project setup with quality checks
full-setup() {
    warp github new "$1" "$2" "$3" &&
    cd "$1" &&
    warp quality &&
    warp security &&
    warp docs generate --website &&
    echo "✅ Project '$1' fully set up!"
}
EOF
        
        log_success "Shell integration added to $shell_file"
    else
        log_info "Shell integration already exists or unsupported shell"
    fi
}

install_optional_dependencies() {
    log_info "Installing optional dependencies..."
    
    local os_type=$(uname -s | tr '[:upper:]' '[:lower:]')
    
    # GitHub CLI
    if ! command -v gh >/dev/null; then
        log_info "Installing GitHub CLI..."
        case "$os_type" in
            "darwin")
                if command -v brew >/dev/null; then
                    brew install gh 2>/dev/null || log_warning "Failed to install GitHub CLI with brew"
                else
                    log_warning "Homebrew not found. Please install GitHub CLI manually"
                fi
                ;;
            "linux")
                if command -v apt-get >/dev/null; then
                    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
                    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
                    sudo apt update && sudo apt install gh 2>/dev/null || log_warning "Failed to install GitHub CLI with apt"
                else
                    log_warning "Please install GitHub CLI manually: https://cli.github.com/"
                fi
                ;;
            *)
                log_warning "Unsupported OS for automatic GitHub CLI installation"
                ;;
        esac
    fi
    
    # Act (GitHub Actions runner)
    if ! command -v act >/dev/null; then
        log_info "Installing Act..."
        case "$os_type" in
            "darwin")
                if command -v brew >/dev/null; then
                    brew install act 2>/dev/null || log_warning "Failed to install Act with brew"
                fi
                ;;
            "linux")
                curl https://raw.githubusercontent.com/nektos/act/master/install.sh | bash 2>/dev/null || log_warning "Failed to install Act"
                ;;
        esac
    fi
    
    # Development tools
    log_info "Checking development tools..."
    
    local tools_to_check=("docker" "docker-compose" "node" "npm" "python3" "pip3" "php" "composer")
    local missing_tools=()
    
    for tool in "${tools_to_check[@]}"; do
        if ! command -v "$tool" >/dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_warning "Optional tools not found: ${missing_tools[*]}"
        echo "These tools are recommended for full functionality:"
        echo "  • Docker & Docker Compose: https://docs.docker.com/get-docker/"
        echo "  • Node.js & npm: https://nodejs.org/"
        echo "  • Python 3 & pip: https://python.org/"
        echo "  • PHP & Composer: https://php.net/ & https://getcomposer.org/"
    fi
}

setup_wordpress_development() {
    log_info "Setting up WordPress development environment..."
    
    # Create WordPress development directory
    mkdir -p "$HOME/.warp/wordpress-dev"
    
    # Copy WordPress development templates
    if [[ -d "$WARP_DIR/src/wordpress/templates" ]]; then
        cp -r "$WARP_DIR/src/wordpress/templates"/* "$HOME/.warp/wordpress-dev/" 2>/dev/null || true
    fi
    
    # Create WordPress development helper script
    cat > "$HOME/.warp/wordpress-dev/wp-helper.sh" << 'EOF'
#!/bin/bash
# WordPress Development Helper
# 
# List all WordPress development environments
list() {
    echo "🔍 WordPress Development Environments:"
    echo
    find . -maxdepth 2 -name "*-dev.sh" -type f | while read -r script; do
        local dir=$(dirname "$script")
        local name=$(basename "$dir")
        local type="unknown"
        
        if [[ -f "$dir/docker-compose.yml" ]]; then
            if grep -q "wp-content/plugins" "$dir/docker-compose.yml"; then
                type="plugin"
            elif grep -q "wp-content/themes" "$dir/docker-compose.yml"; then
                type="theme"
            fi
        fi
        
        echo "  📂 $name ($type)"
        echo "     Script: $script"
        echo "     Directory: $dir"
        echo
    done
}

# Start all environments
start_all() {
    echo "🚀 Starting all WordPress environments..."
    find . -maxdepth 2 -name "*-dev.sh" -type f -exec {} start \;
}

# Stop all environments
stop_all() {
    echo "🛑 Stopping all WordPress environments..."
    find . -maxdepth 2 -name "*-dev.sh" -type f -exec {} stop \;
}

# Clean all environments
clean_all() {
    echo "🧹 Cleaning all WordPress environments..."
    docker system prune -f
    docker volume prune -f
}

case "$1" in
    "list") list ;;
    "start") start_all ;;
    "stop") stop_all ;;
    "clean") clean_all ;;
    *)
        echo "WordPress Development Helper"
        echo "Usage: $0 {list|start|stop|clean}"
        echo
        echo "Commands:"
        echo "  list   - List all WordPress development environments"
        echo "  start  - Start all WordPress environments"
        echo "  stop   - Stop all WordPress environments"
        echo "  clean  - Clean Docker resources"
        ;;
esac
EOF
    
    chmod +x "$HOME/.warp/wordpress-dev/wp-helper.sh"
    
    log_success "WordPress development environment ready"
}

# Main installation
main() {
    echo
    echo "🚀 Warp Development Toolkit Installer"
    echo "======================================"
    echo
    
    check_prerequisites
    install_warp
    
    echo
    echo "🎉 Installation complete!"
    echo
    echo "Get started with:"
    echo "  warp help              # Show all commands"
    echo "  warp config edit       # Edit configuration"
    echo "  warp github new my-app python  # Create new project"
    echo
}

main "$@"
