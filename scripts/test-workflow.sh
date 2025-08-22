#!/bin/bash
# Test the complete Warp workflow

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# Test directory
TEST_DIR="warp-test-$(date +%s)"

echo "🧪 Testing Warp Core Workflow"
echo "=============================="
echo

# Create test directory
mkdir "$TEST_DIR"
cd "$TEST_DIR"

log_info "Test directory: $(pwd)"
echo

# Test 1: Python project creation
log_info "Test 1: Creating Python project..."
if warp github new test-python-app python "Test Python application"; then
    log_success "Python project created successfully"
else
    log_error "Failed to create Python project"
    exit 1
fi

cd test-python-app

# Test 2: Quality checks
log_info "Test 2: Running quality checks..."
if warp quality; then
    log_success "Quality checks completed"
else
    log_warning "Quality checks completed with warnings"
fi

# Test 3: Security checks
log_info "Test 3: Running security checks..."
if warp security; then
    log_success "Security checks completed"
else
    log_warning "Security checks completed with warnings"
fi

# Test 4: Docker setup
log_info "Test 4: Setting up Docker environment..."
if warp docker setup python; then
    log_success "Docker environment created"
else
    log_error "Failed to create Docker environment"
    exit 1
fi

# Test 5: Development environment
log_info "Test 5: Testing development environment..."
if [[ -f "docker-dev.sh" ]]; then
    log_success "Development helper script created"
    
    # Test Docker Compose validation
    if docker-compose config >/dev/null 2>&1; then
        log_success "Docker Compose configuration is valid"
    else
        log_warning "Docker Compose configuration has issues"
    fi
else
    log_error "Development helper script not found"
fi

cd ..

# Test 6: WordPress plugin project
log_info "Test 6: Creating WordPress plugin project..."
if warp github new test-wp-plugin wordpress-plugin "Test WordPress plugin"; then
    log_success "WordPress plugin project created"
    
    cd test-wp-plugin
    
    # Check plugin structure
    if [[ -f "test-wp-plugin.php" ]]; then
        log_success "Main plugin file created"
    else
        log_error "Main plugin file not found"
    fi
    
    # Test WordPress Docker setup
    if warp docker setup wordpress-plugin; then
        log_success "WordPress Docker environment created"
    else
        log_error "Failed to create WordPress Docker environment"
    fi
    
    cd ..
else
    log_error "Failed to create WordPress plugin project"
fi

# Test 7: JavaScript project
log_info "Test 7: Creating JavaScript project..."
if warp github new test-js-app javascript "Test JavaScript application"; then
    log_success "JavaScript project created"
    
    cd test-js-app
    
    # Test quality checks on JavaScript
    if warp quality; then
        log_success "JavaScript quality checks completed"
    else
        log_warning "JavaScript quality checks completed with warnings"
    fi
    
    cd ..
else
    log_error "Failed to create JavaScript project"
fi

echo
echo "🎉 Workflow Test Summary"
echo "======================="

# Check what was created
log_info "Created projects:"
for project in test-*; do
    if [[ -d "$project" ]]; then
        echo "  📁 $project"
        
        cd "$project"
        
        # Check for quality report
        if [[ -f "code-quality-report.log" ]]; then
            echo "    ✅ Quality report generated"
        fi
        
        # Check for security report
        if [[ -f "security-report.log" ]]; then
            echo "    ✅ Security report generated"
        fi
        
        # Check for Docker files
        if [[ -f "docker-compose.yml" ]]; then
            echo "    ✅ Docker environment configured"
        fi
        
        cd ..
    fi
done

echo
log_success "Core workflow test completed!"
log_info "Test directory: $(pwd)"

echo
echo "🚀 Next Steps:"
echo "1. Review the generated projects in $(pwd)"
echo "2. Test Docker environments: cd <project> && ./docker-dev.sh start"
echo "3. Run quality/security checks on your own projects"
echo "4. Create your first real project: warp github new my-app python"
