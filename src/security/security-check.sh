#!/bin/bash
# Security Checker - Core Implementation

set -e

# Load core utilities
WARP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$WARP_DIR/src/core/logger.sh"
source "$WARP_DIR/src/core/utils.sh"

PROJECT_ROOT=$(pwd)
SECURITY_LOG="$PROJECT_ROOT/security-report.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Initialize security log
init_security_log() {
    cat > "$SECURITY_LOG" << EOF
=====================================
Security Analysis Report
Generated: $TIMESTAMP
Project: $(basename "$PROJECT_ROOT")
=====================================

EOF
}

# Log to both console and file
log_both() {
    echo -e "$1" | tee -a "$SECURITY_LOG"
}

# Detect project type
detect_project_type() {
    local project_types=()
    
    [[ -f "requirements.txt" || -f "setup.py" || -f "pyproject.toml" ]] && project_types+=("python")
    [[ -f "package.json" ]] && project_types+=("javascript")
    if find . -maxdepth 1 -name "*.php" -exec grep -l "Plugin Name:" {} \; 2>/dev/null | head -1 | grep -q .; then
        project_types+=("wordpress-plugin")
    fi
    [[ -f "composer.json" ]] && project_types+=("php")
    
    echo "${project_types[@]}"
}

# Check for exposed secrets
check_secrets() {
    log_info "Scanning for exposed secrets and sensitive files"
    log_both "\n=== SECRETS AND SENSITIVE DATA ANALYSIS ==="
    
    local secret_patterns=(
        "password\s*[=:]\s*['\"][^'\"]*['\"]"
        "api[_-]?key\s*[=:]\s*['\"][^'\"]*['\"]"
        "secret[_-]?key\s*[=:]\s*['\"][^'\"]*['\"]"
        "access[_-]?token\s*[=:]\s*['\"][^'\"]*['\"]"
        "private[_-]?key"
        "-----BEGIN.*PRIVATE KEY-----"
        "ssh-rsa AAAA"
        "ghp_[a-zA-Z0-9]{36}"
        "sk_live_[a-zA-Z0-9]{24}"
        "xox[baprs]-[a-zA-Z0-9-]+"
        "AKIA[0-9A-Z]{16}"
    )
    
    local secrets_found=0
    
    for pattern in "${secret_patterns[@]}"; do
        local matches=$(grep -r -i -E "$pattern" --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=venv --exclude="*.log" . 2>/dev/null | wc -l || echo "0")
        if [[ $matches -gt 0 ]]; then
            log_error "Found $matches potential secrets matching pattern"
            log_both "💀 Secret Pattern: $matches matches for sensitive data"
            secrets_found=$((secrets_found + matches))
            
            # Show files (without revealing actual secrets)
            grep -r -l -i -E "$pattern" --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=venv --exclude="*.log" . 2>/dev/null | head -5 | while read -r file; do
                log_both "   📄 File: $file"
            done >> "$SECURITY_LOG"
        fi
    done
    
    # Check for sensitive files
    local sensitive_files=(
        ".env"
        ".env.local"
        ".env.production"
        "config.json"
        "secrets.yml"
        "private.key"
        "id_rsa"
        ".aws/credentials"
        ".ssh/id_rsa"
    )
    
    log_info "Checking for sensitive files..."
    for file in "${sensitive_files[@]}"; do
        if find . -name "$file" -type f 2>/dev/null | grep -q .; then
            log_warning "Sensitive file found: $file"
            log_both "⚠️  Sensitive File: $file exists"
            
            # Check if it's in git
            if git ls-files --error-unmatch "$file" &>/dev/null; then
                log_error "Sensitive file is tracked by git: $file"
                log_both "💀 Git Tracked: $file is in version control!"
                secrets_found=$((secrets_found + 1))
            fi
        fi
    done
    
    if [[ $secrets_found -eq 0 ]]; then
        log_success "No obvious secrets found in codebase"
        log_both "✅ Secrets Scan: No obvious secrets detected"
    else
        log_error "Total potential secrets found: $secrets_found"
        log_both "💀 Total Secrets: $secrets_found potential secrets found"
    fi
    
    return $secrets_found
}

# Python security checks
check_python_security() {
    log_info "Python Security Analysis"
    log_both "\n=== PYTHON SECURITY ANALYSIS ==="
    
    local critical_issues=0
    local high_issues=0
    
    # Check if virtual environment exists
    if [[ -d "venv" ]]; then
        source venv/bin/activate 2>/dev/null || true
    fi
    
    # Bandit - Python security linter
    if command -v bandit >/dev/null 2>&1; then
        log_info "Running Bandit security analysis..."
        local bandit_output=$(mktemp)
        
        if bandit -r . -f json -o "$bandit_output" 2>/dev/null; then
            local issues=$(jq '.results | length' "$bandit_output" 2>/dev/null || echo "0")
            
            if [[ $issues -eq 0 ]]; then
                log_success "Bandit: No security issues found"
                log_both "✅ Bandit: No security vulnerabilities detected"
            else
                log_warning "Bandit: $issues security issues found"
                log_both "🚨 Bandit: $issues security issues detected"
                
                # Count by severity
                local high=$(jq '[.results[] | select(.issue_severity=="HIGH")] | length' "$bandit_output" 2>/dev/null || echo "0")
                local medium=$(jq '[.results[] | select(.issue_severity=="MEDIUM")] | length' "$bandit_output" 2>/dev/null || echo "0")
                local low=$(jq '[.results[] | select(.issue_severity=="LOW")] | length' "$bandit_output" 2>/dev/null || echo "0")
                
                high_issues=$((high_issues + high))
                critical_issues=$((critical_issues + high))
                
                log_both "   High severity: $high"
                log_both "   Medium severity: $medium"
                log_both "   Low severity: $low"
            fi
        else
            # Fallback: simple bandit without JSON
            if bandit -r . >/dev/null 2>&1; then
                log_success "Bandit: No security issues found"
                log_both "✅ Bandit: Clean security scan"
            else
                log_warning "Bandit: Security issues found"
                log_both "⚠️  Bandit: Run 'bandit -r .' for details"
            fi
        fi
        
        rm -f "$bandit_output"
    else
        log_both "⚠️  Bandit: Not installed (pip install bandit)"
    fi
    
    # Safety - Check dependencies for vulnerabilities
    if command -v safety >/dev/null 2>&1 && [[ -f "requirements.txt" ]]; then
        log_info "Running Safety dependency check..."
        if safety check --json >/dev/null 2>&1; then
            log_success "Safety: No vulnerable dependencies found"
            log_both "✅ Safety: All dependencies are secure"
        else
            log_error "Safety: Vulnerable dependencies found"
            log_both "🚨 Safety: Vulnerable dependencies detected"
            critical_issues=$((critical_issues + 1))
            echo "Run 'safety check' for detailed vulnerability information" >> "$SECURITY_LOG"
        fi
    else
        if [[ ! -f "requirements.txt" ]]; then
            log_both "ℹ️  Safety: No requirements.txt found"
        else
            log_both "⚠️  Safety: Not installed (pip install safety)"
        fi
    fi
    
    # Check for dangerous function usage
    log_info "Checking for dangerous function usage..."
    local dangerous_funcs=$(grep -r -n "eval\|exec\|__import__" --include="*.py" . 2>/dev/null | wc -l || echo "0")
    if [[ $dangerous_funcs -gt 0 ]]; then
        log_warning "Dangerous Python functions detected: $dangerous_funcs"
        log_both "⚠️  Dangerous Functions: $dangerous_funcs occurrences found"
        grep -r -n "eval\|exec\|__import__" --include="*.py" . 2>/dev/null | head -5 >> "$SECURITY_LOG" || true
    else
        log_both "✅ Dangerous Functions: None detected"
    fi
    
    log_both "\n📊 Python Security Summary:"
    log_both "   Critical: $critical_issues"
    log_both "   High: $high_issues"
    
    return $critical_issues
}

# JavaScript security checks
check_javascript_security() {
    log_info "JavaScript Security Analysis"
    log_both "\n=== JAVASCRIPT SECURITY ANALYSIS ==="
    
    local npm_audit_issues=0
    
    # npm audit
    if [[ -f "package.json" ]] && command -v npm >/dev/null 2>&1; then
        log_info "Running npm audit..."
        local audit_output=$(mktemp)
        
        if npm audit --json > "$audit_output" 2>/dev/null; then
            local vulnerabilities=$(jq '.metadata.vulnerabilities // {}' "$audit_output" 2>/dev/null || echo '{}')
            local total=$(echo "$vulnerabilities" | jq '.info + .low + .moderate + .high + .critical' 2>/dev/null || echo "0")
            
            if [[ $total -eq 0 ]]; then
                log_success "npm audit: No vulnerabilities found"
                log_both "✅ npm audit: No known vulnerabilities"
            else
                log_error "npm audit: $total vulnerabilities found"
                log_both "🚨 npm audit: $total vulnerabilities detected"
                
                local critical=$(echo "$vulnerabilities" | jq '.critical // 0' 2>/dev/null || echo "0")
                local high=$(echo "$vulnerabilities" | jq '.high // 0' 2>/dev/null || echo "0")
                local moderate=$(echo "$vulnerabilities" | jq '.moderate // 0' 2>/dev/null || echo "0")
                local low=$(echo "$vulnerabilities" | jq '.low // 0' 2>/dev/null || echo "0")
                
                log_both "   Critical: $critical"
                log_both "   High: $high"
                log_both "   Moderate: $moderate"
                log_both "   Low: $low"
                
                npm_audit_issues=$total
            fi
        else
            # Fallback: simple npm audit
            if npm audit >/dev/null 2>&1; then
                log_success "npm audit: No vulnerabilities found"
                log_both "✅ npm audit: Clean"
            else
                log_warning "npm audit: Vulnerabilities found"
                log_both "⚠️  npm audit: Run 'npm audit' for details"
                npm_audit_issues=1
            fi
        fi
        
        rm -f "$audit_output"
    else
        if [[ ! -f "package.json" ]]; then
            log_both "ℹ️  npm audit: No package.json found"
        else
            log_both "⚠️  npm audit: npm not available"
        fi
    fi
    
    log_both "\n📊 JavaScript Security Summary:"
    log_both "   npm audit vulnerabilities: $npm_audit_issues"
    
    return $npm_audit_issues
}

# WordPress security checks
check_wordpress_security() {
    log_info "WordPress Security Analysis"
    log_both "\n=== WORDPRESS SECURITY ANALYSIS ==="
    
    local wp_issues=0
    
    # Find main plugin file
    local plugin_file=$(find . -maxdepth 1 -name "*.php" -exec grep -l "Plugin Name:" {} \; | head -1)
    
    if [[ -z "$plugin_file" ]]; then
        log_error "No WordPress plugin file found"
        return 1
    fi
    
    # Check for direct access protection
    if grep -q "if (!defined('ABSPATH'))" "$plugin_file"; then
        log_both "✅ Direct Access: Protection found"
    else
        log_warning "No direct access protection found"
        log_both "🚨 Direct Access: Missing protection"
        wp_issues=$((wp_issues + 1))
    fi
    
    # Check for SQL injection patterns
    local sql_injection=$(grep -r -i "mysql_query\|mysqli_query.*\$" --include="*.php" . 2>/dev/null | wc -l || echo "0")
    if [[ $sql_injection -gt 0 ]]; then
        log_error "Potential SQL injection vulnerabilities: $sql_injection"
        log_both "🚨 SQL Injection: $sql_injection potential issues"
        wp_issues=$((wp_issues + sql_injection))
        grep -r -n -i "mysql_query\|mysqli_query.*\$" --include="*.php" . 2>/dev/null | head -3 >> "$SECURITY_LOG" || true
    else
        log_both "✅ SQL Injection: No obvious vulnerabilities"
    fi
    
    # Check for XSS patterns
    local xss_issues=$(grep -r -n "echo.*\$_\|print.*\$_" --include="*.php" . 2>/dev/null | wc -l || echo "0")
    if [[ $xss_issues -gt 0 ]]; then
        log_error "Potential XSS vulnerabilities: $xss_issues"
        log_both "🚨 XSS: $xss_issues potential issues"
        wp_issues=$((wp_issues + xss_issues))
        grep -r -n "echo.*\$_\|print.*\$_" --include="*.php" . 2>/dev/null | head -3 >> "$SECURITY_LOG" || true
    else
        log_both "✅ XSS: No obvious vulnerabilities"
    fi
    
    # Check for file inclusion issues
    local file_inclusion=$(grep -r -n "include.*\$\|require.*\$" --include="*.php" . 2>/dev/null | wc -l || echo "0")
    if [[ $file_inclusion -gt 0 ]]; then
        log_error "Potential file inclusion vulnerabilities: $file_inclusion"
        log_both "🚨 File Inclusion: $file_inclusion potential issues"
        wp_issues=$((wp_issues + file_inclusion))
    else
        log_both "✅ File Inclusion: No obvious vulnerabilities"
    fi
    
    return $wp_issues
}

# Check file permissions
check_file_permissions() {
    log_info "Checking file permissions and security"
    log_both "\n=== FILE PERMISSIONS ANALYSIS ==="
    
    local permission_issues=0
    
    # Check for world-writable files
    local world_writable=$(find . -type f -perm -002 2>/dev/null | wc -l || echo "0")
    if [[ $world_writable -gt 0 ]]; then
        log_error "Found $world_writable world-writable files"
        log_both "🚨 World Writable: $world_writable files"
        find . -type f -perm -002 2>/dev/null | head -5 >> "$SECURITY_LOG"
        permission_issues=$((permission_issues + world_writable))
    else
        log_both "✅ File Permissions: No world-writable files"
    fi
    
    return $permission_issues
}

# Generate security summary
generate_security_summary() {
    log_both "\n=====================================
SECURITY SUMMARY & RECOMMENDATIONS
====================================="
    
    # Count total issues
    local critical_count=$(grep -c "💀\|🚨" "$SECURITY_LOG" 2>/dev/null || echo "0")
    local warning_count=$(grep -c "⚠️" "$SECURITY_LOG" 2>/dev/null || echo "0")
    
    # Risk assessment
    local risk_level="LOW"
    if [[ $critical_count -gt 0 ]]; then
        risk_level="CRITICAL"
    elif [[ $warning_count -gt 5 ]]; then
        risk_level="HIGH"
    elif [[ $warning_count -gt 0 ]]; then
        risk_level="MEDIUM"
    fi
    
    log_both "🎯 Overall Risk Level: $risk_level"
    log_both "📊 Issue Breakdown:"
    log_both "   💀 Critical: $critical_count"
    log_both "   ⚠️  Warnings: $warning_count"
    
    # Immediate actions
    if [[ $critical_count -gt 0 ]]; then
        log_both "\n🚨 IMMEDIATE ACTION REQUIRED:"
        log_both "   1. Review and remove any exposed secrets immediately"
        log_both "   2. Fix security vulnerabilities"
        log_both "   3. Update vulnerable dependencies"
    fi
    
    # Recommendations
    log_both "\n💡 SECURITY RECOMMENDATIONS:"
    log_both "   • Add .env to .gitignore and never commit secrets"
    log_both "   • Use environment variables for sensitive data"
    log_both "   • Regularly update dependencies"
    log_both "   • Use security linting in CI/CD pipeline"
    log_both "   • Implement proper input validation and sanitization"
    
    # Tools to install
    log_both "\n🔧 RECOMMENDED SECURITY TOOLS:"
    ! command -v bandit &>/dev/null && log_both "   • pip install bandit (Python)"
    ! command -v safety &>/dev/null && log_both "   • pip install safety (Python)"
    
    log_both "\n📄 Full report: $SECURITY_LOG"
    log_both "\n=====================================
END OF SECURITY REPORT
====================================="
}

# Main execution
main() {
    log_info "Starting comprehensive security analysis..."
    log_info "Project root: $PROJECT_ROOT"
    
    init_security_log
    
    local project_types=($(detect_project_type))
    
    if [[ ${#project_types[@]} -eq 0 ]]; then
        log_warning "No supported project types detected, running general checks..."
        project_types=("general")
    fi
    
    log_info "Detected project types: ${project_types[*]}"
    log_both "🔍 Security scan for: ${project_types[*]}"
    
    local total_critical=0
    local total_issues=0
    
    # Always check for secrets and file permissions
    check_secrets
    local secrets_result=$?
    total_critical=$((total_critical + secrets_result))
    
    check_file_permissions
    local permissions_result=$?
    total_issues=$((total_issues + permissions_result))
    
    # Run project-specific security checks
    for project_type in "${project_types[@]}"; do
        case $project_type in
            "python")
                check_python_security
                local python_result=$?
                total_critical=$((total_critical + python_result))
                ;;
            "javascript")
                check_javascript_security
                local js_result=$?
                total_issues=$((total_issues + js_result))
                ;;
            "wordpress-plugin")
                check_wordpress_security
                local wp_result=$?
                total_issues=$((total_issues + wp_result))
                ;;
        esac
    done
    
    generate_security_summary
    
    log_success "Security analysis complete!"
    log_success "Report saved to: $SECURITY_LOG"
    
    # Return appropriate exit code
    if [[ $total_critical -gt 0 ]]; then
        log_error "CRITICAL SECURITY ISSUES FOUND - Review immediately!"
        exit 1
    elif [[ $total_issues -gt 0 ]]; then
        log_warning "Security issues found - Review recommended"
        exit 1
    else
        log_success "No critical security issues found"
        exit 0
    fi
}

# Help function
show_help() {
    echo "Security Checker"
    echo "Usage: warp security [options]"
    echo
    echo "Security checks include:"
    echo "  • Secret detection (API keys, passwords, tokens)"
    echo "  • Dependency vulnerability scanning"
    echo "  • File permission analysis"
    echo "  • Language-specific security issues"
    echo
    echo "Supported project types:"
    echo "  • Python (bandit, safety)"
    echo "  • JavaScript/Node.js (npm audit)"
    echo "  • WordPress Plugin (common vulnerabilities)"
    echo
    echo "Examples:"
    echo "  warp security          # Run security analysis"
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
