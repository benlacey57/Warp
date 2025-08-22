#!/bin/bash
# Warp Uninstall Script

WARP_DIR="$HOME/.warp"
INSTALL_PREFIX="/usr/local/bin"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}🗑️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

confirm() {
    read -p "$1 [y/N]: " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]]
}

uninstall_warp() {
    echo
    echo "🗑️  Warp Uninstaller"
    echo "==================="
    echo
    
    if [[ ! -d "$WARP_DIR" ]]; then
        log_error "Warp is not installed."
        exit 1
    fi
    
    log_warning "This will completely remove Warp from your system."
    echo
    echo "The following will be removed:"
    echo "  • Warp directory: $WARP_DIR"
    echo "  • System symlink: $INSTALL_PREFIX/warp"
    echo "  • Shell aliases (manual removal required)"
    echo "  • All WordPress development environments"
    echo
    
    if ! confirm "Are you sure you want to uninstall Warp?"; then
        echo "Uninstall cancelled."
        exit 0
    fi
    
    # Stop all WordPress environments
    log_info "Stopping WordPress development environments..."
    if [[ -f "$HOME/.warp/wordpress-dev/wp-helper.sh" ]]; then
        bash "$HOME/.warp/wordpress-dev/wp-helper.sh" stop 2>/dev/null || true
    fi
    
    # Remove system symlink
    log_info "Removing system symlink..."
    if [[ -L "$INSTALL_PREFIX/warp" ]]; then
        if [[ -w "$INSTALL_PREFIX" ]]; then
            rm -f "$INSTALL_PREFIX/warp"
        else
            sudo rm -f "$INSTALL_PREFIX/warp"
        fi
    fi
    
    # Remove Warp directory
    log_info "Removing Warp directory..."
    rm -rf "$WARP_DIR"
    
    # Clean up Docker resources
    log_info "Cleaning up Docker resources..."
    docker system prune -f 2>/dev/null || true
    
    log_success "Warp has been uninstalled successfully!"
    echo
    log_warning "Manual cleanup required:"
    echo "  • Remove Warp aliases from your shell configuration file"
    echo "  • Remove any project-specific .warp.conf files"
    echo
}

uninstall_warp
