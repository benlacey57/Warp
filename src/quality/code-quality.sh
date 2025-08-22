#!/bin/bash
# Code Quality Checker - Core Implementation

set -e

# Load core utilities
WARP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$WARP_DIR/src/core/logger.sh"
source "$WARP_DIR/src/core/utils.sh"

PROJECT_ROOT=$(pwd)
LOG_FILE="$PROJECT_ROOT/code-quality-report.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Initialize log
init_log() {
    cat > "$LOG_FILE" << EOF
=====================================
Code Quality Report
Generated: $TIMESTAMP
Project: $(basename "$PROJECT_ROOT")
=====================================

EOF
}

# Log to both console and file
log_both() {
    echo -e "$1" | tee -a "$LOG_FILE"
}

# Detect project type
detect_project_type() {
    local project_types=()
    
    # Python
    if [[ -f "requirements.txt" ]] || [[ -f "setup.py" ]] || [[ -f "pyproject.toml" ]]; then
        project_types+=("python")
    fi
    
    # JavaScript
    if [[ -f "package.json" ]]; then
        project_types+=("javascript")
    fi
    
    # WordPress Plugin
    if find . -maxdepth 1 -name "*.php" -exec grep -l "Plugin Name:" {} \; 2>/dev/null | head -1 | grep -q .; then
        project_types+=("wordpress-plugin")
    fi
    
    # PHP (general)
    if [[ -f "composer.json" ]]; then
        project_types+=("php")
    fi
    
    echo "${project_types[@]}"
}

# Check Python quality
check_python() {
    log_section "Python Code Quality Checks"
    log_both "\n=== PYTHON QUALITY ANALYSIS ==="
    
    local python_score=0
    local total_checks=0
    
    # Check if virtual environment exists
    if [[ -d "venv" ]]; then
        log_info "Virtual environment found"
        # Activate virtual environment for checks
        source venv/bin/activate 2>/dev/null || true
    else
        log_warning "No virtual environment found. Run ./setup-dev.sh first"
    fi
    
    # Black (formatting)
    if command -v black >/dev/null 2>&1; then
        log_info "Running Black formatter check..."
        ((total_checks++))
        if black --check --diff . >/dev/null 2>&1; then
            log_success "Black: Code is properly formatted"
            log_both "✅ Black: All files properly formatted"
            ((python_score++))
        else
            log_warning "Black: Code formatting issues found"
            log_both "⚠️  Black: Formatting issues detected"
            echo "Run 'black .' to fix formatting issues" >> "$LOG_FILE"
        fi
    else
        log_warning "Black not installed. Install with: pip install black"
        log_both "⚠️  Black: Not installed"
    fi
    
    # isort (import sorting)
    if command -v isort >/dev/null 2>&1; then
        log_info "Running isort import check..."
        ((total_checks++))
        if isort --check-only --diff . >/dev/null 2>&1; then
            log_success "isort: Imports are properly sorted"
            log_both "✅ isort: All imports properly sorted"
            ((python_score++))
        else
            log_warning "isort: Import sorting issues found"
            log_both "⚠️  isort: Import sorting issues"
            echo "Run 'isort .' to fix import sorting" >> "$LOG_FILE"
        fi
    else
        log_both "⚠️  isort: Not installed (pip install isort)"
    fi
    
    # Flake8 (linting)
    if command -v flake8 >/dev/null 2>&1; then
        log_info "Running Flake8 linting..."
        ((total_checks++))
        if flake8 --count --select=E9,F63,F7,F82 --show-source --statistics . >/dev/null 2>&1; then
            log_success "Flake8: No critical issues found"
            log_both "✅ Flake8: No critical issues"
            ((python_score++))
        else
            log_warning "Flake8: Issues found"
            log_both "⚠️  Flake8: Issues detected"
            flake8 --count --select=E9,F63,F7,F82 --show-source --statistics . >> "$LOG_FILE" 2>&1 || true
        fi
    else
        log_both "⚠️  Flake8: Not installed (pip install flake8)"
    fi
    
    # pytest (testing)
    if command -v pytest >/dev/null 2>&1; then
        log_info "Running pytest..."
        ((total_checks++))
        if pytest --quiet >/dev/null 2>&1; then
            log_success "pytest: All tests passed"
            log_both "✅ pytest: All tests passed"
            ((python_score++))
        else
            log_warning "pytest: Some tests failed"
            log_both "⚠️  pytest: Some tests failed"
            echo "Run 'pytest -v' for detailed test results" >> "$LOG_FILE"
        fi
    else
        log_both "⚠️  pytest: Not installed (pip install pytest)"
    fi
    
    # Calculate score
    if [[ $total_checks -gt 0 ]]; then
        local percentage=$((python_score * 100 / total_checks))
        log_both "\n📊 Python Quality Score: $python_score/$total_checks ($percentage%)"
        
        if [[ $percentage -ge 80 ]]; then
            log_success "Excellent code quality!"
        elif [[ $percentage -ge 60 ]]; then
            log_warning "Good code quality, some improvements possible"
        else
            log_error "Code quality needs attention"
        fi
    fi
}

# Check JavaScript quality
check_javascript() {
    log_section "JavaScript Code Quality Checks"
    log_both "\n=== JAVASCRIPT QUALITY ANALYSIS ==="
    
    local js_score=0
    local total_checks=0
    
    # Check if node_modules exists
    if [[ ! -d "node_modules" ]]; then
        log_warning "Node modules not installed. Run 'npm install' first"
        log_both "⚠️  Node modules: Not installed"
        return 0
    fi
    
    # ESLint
    if [[ -f "node_modules/.bin/eslint" ]] || command -v eslint >/dev/null 2>&1; then
        log_info "Running ESLint..."
        ((total_checks++))
        local eslint_cmd="npx eslint"
        
        if $eslint_cmd src/ >/dev/null 2>&1; then
            log_success "ESLint: No issues found"
            log_both "✅ ESLint: Clean code"
            ((js_score++))
        else
            log_warning "ESLint: Issues found"
            log_both "⚠️  ESLint: Issues detected"
            echo "Run 'npm run lint' to see detailed issues" >> "$LOG_FILE"
        fi
    else
        log_both "⚠️  ESLint: Not installed"
    fi
    
    # Prettier
    if [[ -f "node_modules/.bin/prettier" ]] || command -v prettier >/dev/null 2>&1; then
        log_info "Running Prettier check..."
        ((total_checks++))
        local prettier_cmd="npx prettier"
        
        if $prettier_cmd --check src/ >/dev/null 2>&1; then
            log_success "Prettier: Code is properly formatted"
            log_both "✅ Prettier: All files properly formatted"
            ((js_score++))
        else
            log_warning "Prettier: Formatting issues found"
            log_both "⚠️  Prettier: Formatting issues"
            echo "Run 'npm run format' to fix formatting" >> "$LOG_FILE"
        fi
    else
        log_both "⚠️  Prettier: Not installed"
    fi
    
    # Jest (testing)
    if [[ -f "node_modules/.bin/jest" ]] || command -v jest >/dev/null 2>&1; then
        log_info "Running Jest tests..."
        ((total_checks++))
        if npm test >/dev/null 2>&1; then
            log_success "Jest: All tests passed"
            log_both "✅ Jest: All tests passed"
            ((js_score++))
        else
            log_warning "Jest: Some tests failed"
            log_both "⚠️  Jest: Some tests failed"
            echo "Run 'npm test' for detailed test results" >> "$LOG_FILE"
        fi
    else
        log_both "⚠️  Jest: Not installed"
    fi
    
    # Calculate score
    if [[ $total_checks -gt 0 ]]; then
        local percentage=$((js_score * 100 / total_checks))
        log_both "\n📊 JavaScript Quality Score: $js_score/$total_checks ($percentage%)"
    fi
}

# Check WordPress plugin quality
check_wordpress_plugin() {
    log_section "WordPress Plugin Quality Checks"
    log_both "\n=== WORDPRESS PLUGIN ANALYSIS ==="
    
    local wp_score=0
    local total_checks=0
    
    # Find main plugin file
    local plugin_file=$(find . -maxdepth 1 -name "*.php" -exec grep -l "Plugin Name:" {} \; | head -1)
    
    if [[ -z "$plugin_file" ]]; then
        log_error "No WordPress plugin file found"
        log_both "❌ WordPress Plugin: No main plugin file found"
        return 1
    fi
    
    log_info "Found plugin file: $plugin_file"
    
    # Check plugin header
    ((total_checks++))
    if grep -q "Plugin Name:" "$plugin_file" && grep -q "Version:" "$plugin_file"; then
        log_success "Plugin header is complete"
        log_both "✅ Plugin Header: Complete"
        ((wp_score++))
    else
        log_warning "Plugin header is incomplete"
        log_both "⚠️  Plugin Header: Missing required fields"
    fi
    
    # Check for security best practices
    ((total_checks++))
    if grep -q "if (!defined('ABSPATH'))" "$plugin_file"; then
        log_success "Direct access protection found"
        log_both "✅ Security: Direct access protection"
        ((wp_score++))
    else
        log_warning "No direct access protection found"
        log_both "⚠️  Security: Add direct access protection"
        echo "Add this to your plugin file: if (!defined('ABSPATH')) { exit; }" >> "$LOG_FILE"
    fi
    
    # Check for text domain
    ((total_checks++))
    if grep -q "load_plugin_textdomain\|Text Domain:" "$plugin_file"; then
        log_success "Text domain configuration found"
        log_both "✅ Internationalization: Text domain configured"
        ((wp_score++))
    else
        log_warning "No text domain configuration found"
        log_both "⚠️  Internationalization: Configure text domain"
    fi
    
    # PHPCS (if available)
    if command -v phpcs >/dev/null 2>&1; then
        log_info "Running PHPCS WordPress standards..."
        ((total_checks++))
        if phpcs --standard=WordPress --extensions=php . >/dev/null 2>&1; then
            log_success "PHPCS: WordPress standards compliant"
            log_both "✅ PHPCS: WordPress standards compliant"
            ((wp_score++))
        else
            log_warning "PHPCS: WordPress standards violations found"
            log_both "⚠️  PHPCS: Standards violations"
            echo "Run 'phpcs --standard=WordPress .' for details" >> "$LOG_FILE"
        fi
    else
        log_both "⚠️  PHPCS: Not installed"
    fi
    
    # Calculate score
    if [[ $total_checks -gt 0 ]]; then
        local percentage=$((wp_score * 100 / total_checks))
        log_both "\n📊 WordPress Plugin Quality Score: $wp_score/$total_checks ($percentage%)"
    fi
}

# Generate summary
generate_summary() {
    log_both "\n=====================================
SUMMARY REPORT
====================================="
    
    local total_files=$(find . -type f \( -name "*.py" -o -name "*.js" -o -name "*.php" \) 2>/dev/null | wc -l)
    log_both "📊 Files analyzed: $total_files"
    log_both "📄 Report saved: $LOG_FILE"
    log_both "🕐 Generated: $TIMESTAMP"
    
    log_both "\n💡 Next steps:"
    log_both "  1. Review the detailed report: $LOG_FILE"
    log_both "  2. Fix any identified issues"
    log_both "  3. Run 'warp security' to check for security issues"
    log_both "  4. Commit your changes"
    
    log_both "\n=====================================
END OF REPORT
====================================="
}

# Main execution
main() {
    log_info "Starting code quality analysis..."
    log_info "Project root: $PROJECT_ROOT"
    
    init_log
    
    local project_types=($(detect_project_type))
    
    if [[ ${#project_types[@]} -eq 0 ]]; then
        log_warning "No supported project types detected"
        log_both "⚠️  No supported project types found"
        echo "Supported types: Python (requirements.txt), JavaScript (package.json), WordPress Plugin (*.php with Plugin Name)"
        exit 1
    fi

    log_info "Detected project types: ${project_types[*]}"
    log_both "🔍 Project types: ${project_types[*]}"
    
    local overall_success=true
    
    for project_type in "${project_types[@]}"; do
        case $project_type in
            "python")
                check_python || overall_success=false
                ;;
            "javascript")
                check_javascript || overall_success=false
                ;;
            "wordpress-plugin")
                check_wordpress_plugin || overall_success=false
                ;;
            "php")
                log_warning "General PHP support coming soon"
                ;;
        esac
    done
    
    generate_summary
    
    if [[ "$overall_success" == "true" ]]; then
        log_success "Code quality analysis complete!"
        exit 0
    else
        log_warning "Code quality analysis completed with issues"
        exit 1
    fi
}

# Help function
show_help() {
    echo "Code Quality Checker"
    echo "Usage: warp quality [options]"
    echo
    echo "Supported project types:"
    echo "  • Python (requirements.txt, setup.py, pyproject.toml)"
    echo "  • JavaScript/Node.js (package.json)"
    echo "  • WordPress Plugin (*.php with Plugin Name header)"
    echo
    echo "Tools used:"
    echo "  Python: black, isort, flake8, pytest"
    echo "  JavaScript: eslint, prettier, jest"
    echo "  WordPress: phpcs (WordPress standards)"
    echo
    echo "Examples:"
    echo "  warp quality          # Run quality checks"
    echo "Install tools:"
    echo "  Python: pip install black isort flake8 pytest"
    echo "  JavaScript: npm install eslint prettier jest"
    echo "  WordPress: composer global require squizlabs/php_codesniffer wp-coding-standards/wpcs"
}

# Parse arguments
case "${1:-}" in
    -h|--help)
        show_help
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac
