#!/bin/bash
# Configuration management

# Default configuration
WARP_VERSION="1.0.0"
WARP_DEBUG=${WARP_DEBUG:-false}
WARP_LOG_LEVEL=${WARP_LOG_LEVEL:-"info"}

# Paths
WARP_HOME="${WARP_HOME:-$HOME/.warp}"
WARP_CACHE_DIR="$WARP_HOME/cache"
WARP_LOG_DIR="$WARP_HOME/logs"
WARP_CONFIG_DIR="$WARP_HOME/config"

# Create directories
mkdir -p "$WARP_CACHE_DIR" "$WARP_LOG_DIR" "$WARP_CONFIG_DIR"

# Load user configuration if exists
USER_CONFIG="$WARP_CONFIG_DIR/user.conf"
if [[ -f "$USER_CONFIG" ]]; then
    source "$USER_CONFIG"
fi

# Load project-specific configuration
if [[ -f ".warp.conf" ]]; then
    source ".warp.conf"
fi

# Export configuration
export WARP_VERSION WARP_DEBUG WARP_LOG_LEVEL
export WARP_HOME WARP_CACHE_DIR WARP_LOG_DIR WARP_CONFIG_DIR
