#!/bin/bash
# Warp Installation Script - Core Implementation

set -e

WARP_DIR="$HOME/.warp"
REPO_URL="https://github.com/user/warp.git"  # Update with actual repo
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
    command -v docker >/dev/null || missing+=("docker")
    
    # Optional but recommended
    if ! command -v gh >/dev/null; then
        log_warning "GitHub CLI not found (recommended for repository management)"
        log_info "Install with: brew install gh"
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing[*]}"
        echo
        echo "Please install the missing tools:"
        for tool in "${missing[@]}"; do
            case "$tool" in
                "git") echo "  Git: https://git-scm.com/downloads" ;;
                "docker") echo "  Docker: https://docs.docker.com/get-docker/" ;;
            esac
        done
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Install Warp
install_warp() {
    log_info "Installing Warp Development Toolkit..."
    
    # For now, copy the scripts we've created
    # In a real scenario, this would clone from GitHub
    
    # Create Warp directory structure
    mkdir -p "$WARP_DIR"/{src/{core,quality,security,docs,git-flow,github,docker},config,scripts}
    
    # Copy core files (you'll need to have these files available)
    log_info "Setting up Warp structure..."
    
    # Create a minimal working version
    cat > "$WARP_DIR/bin/warp" << 'EOF'
#!/bin/bash
# Warp CLI - Core Implementation

WARP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

case "$1" in
    "github")
        shift
        "$WARP_DIR/src/github/github-repo.sh" "$@"
        ;;
    "quality")
        shift
        "$WARP_DIR/src/quality/code-quality.sh" "$@"
        ;;
    "security")
        shift
        "$WARP_DIR/src/security/security-check.sh" "$@"
        ;;
    "docker")
        shift
        "$WARP_DIR/src/docker/docker-dev.sh" "$@"
        ;;
    "version")
        echo "Warp v1.0.0"
        ;;
    *)
        echo "Warp Development Toolkit"
        echo "Usage: warp <command> [options]"
        echo
        echo "Commands:"
        echo "  github    - Repository management"
        echo "  quality   - Code quality checks"
        echo "  security  - Security analysis"
        echo "  docker    - Development environments"
        echo "  version   - Show version"
        echo
        echo "Examples:"
        echo "  warp github new my-app python"
        echo "  warp quality"
        echo "  warp security"
        echo "  warp docker setup"
        ;;
esac
EOF
    
    chmod +x "$WARP_DIR/bin/warp"
    
    # Create system symlink
    log_info "Creating system symlink..."
    if [[ -w "$INSTALL_PREFIX" ]]; then
        ln -sf "$WARP_DIR/bin/warp" "$INSTALL_PREFIX/warp"
    else
        sudo ln -sf "$WARP_DIR/bin/warp" "$INSTALL_PREFIX/warp"
    fi
    
    # You'll need to copy the actual script files here
    log_warning "Please copy the Warp scripts to $WARP_DIR/src/"
    log_info "The scripts should be organized as shown in the documentation"
    
    log_success "Warp installed successfully!"
}

# Setup shell integration
setup_shell_integration() {
    log_info "Setting up shell integration..."
    
    local shell_file=""
    case "$SHELL" in
        */zsh) shell_file="$HOME/.zshrc" ;;
        */bash) shell_file="$HOME/.bashrc" ;;
        *) 
            log_warning "Unsupported shell: $SHELL"
            return 0
            ;;
    esac
    
    if [[ -n "$shell_file" ]] && ! grep -q "# Warp Development Toolkit" "$shell_file" 2>/dev/null; then
        log_info "Adding Warp aliases to $shell_file..."
        
        cat >> "$shell_file" << 'EOF'

# Warp Development Toolkit
export PATH="$PATH:$HOME/.warp/bin"

# Warp aliases
alias cq="warp quality"
alias sec="warp security"
alias gh-new="warp github new"

# Quick project creation
new-python() { warp github new "$1" python "$2"; }
new-js() { warp github new "$1" javascript "$2"; }
new-wp-plugin() { warp github new "$1" wordpress-plugin "$2"; }

# Full development setup
dev-setup() {
    warp github new "$1" "$2" "$3" &&
    cd "$1" &&
    warp docker setup &&
    warp quality &&
    warp security &&
    echo "🎉 Project '$1' ready for development!"
}
EOF
        
        log_success "Shell integration added to $shell_file"
        log_info "Restart your terminal or run: source $shell_file"
    fi
}

# Test installation
test_installation() {
    log_info "Testing Warp installation..."
    
    if command -v warp >/dev/null; then
        log_success "Warp command available"
        
        # Test version
        if warp version >/dev/null 2>&1; then
            log_success "Warp version command works"
        else
            log_warning "Warp version command failed"
        fi
    else
        log_error "Warp command not found in PATH"
        exit 1
    fi
}

# Main installation
main() {
    echo
    echo "🚀 Warp Development Toolkit Installer"
    echo "======================================"
    echo
    
    check_prerequisites
    install_warp
    setup_shell_integration
    test_installation
    
    echo
    echo "🎉 Installation complete!"
    echo
    echo "📋 Next steps:"
    echo "1. Copy the Warp scripts to $WARP_DIR/src/"
    echo "2. Restart your terminal or run: source ~/.zshrc"
    echo "3. Test with: warp version"
    echo "4. Create your first project: warp github new my-app python"
    echo
    echo "🔧 Recommended setup:"
    echo "• Install GitHub CLI: brew install gh && gh auth login"
    echo "• Install development tools: pip install black flake8 pytest bandit"
    echo "• Install Node.js tools: npm install -g eslint prettier"
    echo
}

main "$@"
