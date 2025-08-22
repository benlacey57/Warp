#!/bin/bash
# Warp Update Script

set -e

WARP_DIR="$HOME/.warp"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}🔄 $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

update_warp() {
    if [[ ! -d "$WARP_DIR" ]]; then
        log_error "Warp is not installed. Run the install script first."
        exit 1
    fi
    
    log_info "Updating Warp Development Toolkit..."
    
    cd "$WARP_DIR"
    
    # Backup current configuration
    log_info "Backing up configuration..."
    cp -r config config.backup.$(date +%s) 2>/dev/null || true
    
    # Get current version
    local current_version=""
    if [[ -f "VERSION" ]]; then
        current_version=$(cat VERSION)
        log_info "Current version: $current_version"
    fi
    
    # Update from repository
    log_info "Pulling latest changes..."
    git fetch origin
    git reset --hard origin/main
    
    # Get new version
    local new_version=""
    if [[ -f "VERSION" ]]; then
        new_version=$(cat VERSION)
        log_info "New version: $new_version"
    fi
    
    # Set permissions
    log_info "Updating permissions..."
    find src/ bin/ scripts/ -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
    chmod +x bin/warp
    
    # Restore configuration
    log_info "Restoring configuration..."
    if [[ -d "config.backup."* ]]; then
        local backup_dir=$(ls -1d config.backup.* | tail -1)
        cp -r "$backup_dir"/* config/ 2>/dev/null || true
    fi
    
    # Run any update migrations
    if [[ -f "scripts/migrate.sh" ]]; then
        log_info "Running migrations..."
        bash scripts/migrate.sh
    fi
    
    log_success "Warp updated successfully!"
    
    if [[ -n "$current_version" ]] && [[ -n "$new_version" ]] && [[ "$current_version" != "$new_version" ]]; then
        log_info "Updated from $current_version to $new_version"
        
        # Show changelog if available
        if [[ -f "CHANGELOG.md" ]]; then
            echo
            log_info "Recent changes:"
            awk "/## \[$new_version\]/,/## \[/{if(/## \[/ && !/## \[$new_version\]/) exit; print}" CHANGELOG.md | head -20
        fi
    fi
}

update_warp
