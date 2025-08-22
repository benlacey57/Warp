#!/bin/bash
# Logging utilities

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Log levels
LOG_LEVEL_DEBUG=0
LOG_LEVEL_INFO=1
LOG_LEVEL_WARNING=2
LOG_LEVEL_ERROR=3

# Current log level
case "${WARP_LOG_LEVEL:-info}" in
    "debug") CURRENT_LOG_LEVEL=$LOG_LEVEL_DEBUG ;;
    "info") CURRENT_LOG_LEVEL=$LOG_LEVEL_INFO ;;
    "warning") CURRENT_LOG_LEVEL=$LOG_LEVEL_WARNING ;;
    "error") CURRENT_LOG_LEVEL=$LOG_LEVEL_ERROR ;;
    *) CURRENT_LOG_LEVEL=$LOG_LEVEL_INFO ;;
esac

# Logging functions
log_debug() {
    [[ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_DEBUG ]] && echo -e "${CYAN}🔍 DEBUG: $1${NC}" >&2
    [[ "$WARP_DEBUG" == "true" ]] && echo "$(date '+%Y-%m-%d %H:%M:%S') DEBUG: $1" >> "$WARP_LOG_DIR/debug.log"
}

log_info() {
    [[ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_INFO ]] && echo -e "${BLUE}ℹ️  $1${NC}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') INFO: $1" >> "$WARP_LOG_DIR/warp.log"
}

log_success() {
    [[ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_INFO ]] && echo -e "${GREEN}✅ $1${NC}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') SUCCESS: $1" >> "$WARP_LOG_DIR/warp.log"
}

log_warning() {
    [[ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_WARNING ]] && echo -e "${YELLOW}⚠️  $1${NC}" >&2
    echo "$(date '+%Y-%m-%d %H:%M:%S') WARNING: $1" >> "$WARP_LOG_DIR/warp.log"
}

log_error() {
    [[ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_ERROR ]] && echo -e "${RED}❌ $1${NC}" >&2
    echo "$(date '+%Y-%m-%d %H:%M:%S') ERROR: $1" >> "$WARP_LOG_DIR/warp.log"
}

log_section() {
    [[ $CURRENT_LOG_LEVEL -le $LOG_LEVEL_INFO ]] && echo -e "${PURPLE}📋 $1${NC}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') SECTION: $1" >> "$WARP_LOG_DIR/warp.log"
}

# Log to file only
log_file() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$WARP_LOG_DIR/warp.log"
}
