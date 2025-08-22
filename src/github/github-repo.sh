#!/bin/bash
# GitHub Repository Manager - Core Implementation

set -e

# Load core utilities
WARP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$WARP_DIR/src/core/logger.sh"
source "$WARP_DIR/src/core/utils.sh"

# Check credentials
check_credentials() {
    if ! command -v gh >/dev/null 2>&1; then
        log_error "GitHub CLI not found. Install with: brew install gh"
        log_info "Or use direct GitHub token setup"
        return 1
    fi
    
    if ! gh auth status >/dev/null 2>&1; then
        log_warning "GitHub CLI not authenticated"
        log_info "Run: gh auth login"
        return 1
    fi
    
    log_success "GitHub credentials verified"
    return 0
}

# Create basic project structure
create_project_structure() {
    local project_name="$1"
    local project_type="$2"
    
    log_info "Creating $project_type project structure for: $project_name"
    
    case "$project_type" in
        "python")
            create_python_project "$project_name"
            ;;
        "javascript"|"node")
            create_javascript_project "$project_name"
            ;;
        "wordpress-plugin")
            create_wordpress_plugin_project "$project_name"
            ;;
        *)
            log_error "Unsupported project type: $project_type"
            return 1
            ;;
    esac
}

# Create Python project
create_python_project() {
    local project_name="$1"
    
    log_info "Setting up Python project structure..."
    
    # Basic directory structure
    mkdir -p {src,tests,docs}
    
    # requirements.txt
    cat > requirements.txt << 'EOF'
# Production dependencies
requests>=2.31.0
python-dotenv>=1.0.0
EOF
    
    # requirements-dev.txt
    cat > requirements-dev.txt << 'EOF'
-r requirements.txt

# Development dependencies
pytest>=7.4.0
pytest-cov>=4.0.0
black>=23.0.0
isort>=5.12.0
flake8>=6.0.0
mypy>=1.5.0
bandit>=1.7.5
safety>=2.3.0
EOF
    
    # src/__init__.py
    mkdir -p "src/$project_name"
    cat > "src/$project_name/__init__.py" << EOF
"""$project_name package."""

__version__ = "0.1.0"
EOF
    
    # src/main.py
    cat > "src/$project_name/main.py" << 'EOF'
"""Main module."""

def main():
    """Main function."""
    print("Hello from Python project!")

if __name__ == "__main__":
    main()
EOF
    
    # tests/test_main.py
    cat > "tests/test_main.py" << EOF
"""Tests for main module."""

import pytest
from src.$project_name.main import main

def test_main():
    """Test main function."""
    # This test will pass
    assert True

def test_main_output(capsys):
    """Test main function output."""
    main()
    captured = capsys.readouterr()
    assert "Hello from Python project!" in captured.out
EOF
    
    # .env.example
    cat > .env.example << 'EOF'
# Environment variables template
# Copy to .env and fill in your values

DEBUG=True
API_KEY=your_api_key_here
DATABASE_URL=sqlite:///app.db
EOF
    
    # Basic .gitignore
    cat > .gitignore << 'EOF'
# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
wheels/
*.egg-info/
.installed.cfg
*.egg

# Virtual environments
.env
.venv
env/
venv/
ENV/
env.bak/
venv.bak/

# Testing
.tox/
.coverage
.pytest_cache/
htmlcov/

# IDEs
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# Warp
.warp/
code-quality-report.log
security-report.log
EOF
    
    # setup.py (basic)
    cat > setup.py << EOF
"""Setup script for $project_name."""

from setuptools import setup, find_packages

setup(
    name="$project_name",
    version="0.1.0",
    packages=find_packages(where="src"),
    package_dir={"": "src"},
    python_requires=">=3.8",
    install_requires=[
        "requests>=2.31.0",
        "python-dotenv>=1.0.0",
    ],
    extras_require={
        "dev": [
            "pytest>=7.4.0",
            "pytest-cov>=4.0.0",
            "black>=23.0.0",
            "isort>=5.12.0",
            "flake8>=6.0.0",
            "mypy>=1.5.0",
        ],
    },
)
EOF

    # Create virtual environment setup script
    cat > setup-dev.sh << 'EOF'
#!/bin/bash
# Development environment setup

echo "🐍 Setting up Python development environment..."

# Create virtual environment
python3 -m venv venv

# Activate virtual environment
source venv/bin/activate

# Upgrade pip
pip install --upgrade pip

# Install dependencies
pip install -r requirements-dev.txt

# Install package in development mode
pip install -e .

echo "✅ Development environment ready!"
echo "💡 Activate with: source venv/bin/activate"
EOF
    
    chmod +x setup-dev.sh
    
    log_success "Python project structure created"
}

# Create JavaScript project  
create_javascript_project() {
    local project_name="$1"
    
    log_info "Setting up JavaScript project structure..."
    
    # Basic directories
    mkdir -p {src,tests,docs}
    
    # package.json
    cat > package.json << EOF
{
  "name": "$project_name",
  "version": "1.0.0",
  "description": "JavaScript project created with Warp",
  "main": "src/index.js",
  "scripts": {
    "start": "node src/index.js",
    "dev": "nodemon src/index.js",
    "test": "jest",
    "test:watch": "jest --watch",
    "test:coverage": "jest --coverage",
    "lint": "eslint src/",
    "lint:fix": "eslint src/ --fix",
    "format": "prettier --write src/"
  },
  "keywords": [],
  "author": "",
  "license": "MIT",
  "devDependencies": {
    "eslint": "^8.49.0",
    "prettier": "^3.0.0",
    "nodemon": "^3.0.0",
    "jest": "^29.7.0"
  },
  "dependencies": {
    "express": "^4.18.2",
    "dotenv": "^16.3.1"
  }
}
EOF
    
    # src/index.js
    cat > src/index.js << 'EOF'
const express = require('express');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

app.use(express.json());

app.get('/', (req, res) => {
  res.json({ message: 'Hello from JavaScript project!' });
});

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});

module.exports = app;
EOF
    
    # tests/index.test.js
    cat > tests/index.test.js << 'EOF'
const request = require('supertest');
const app = require('../src/index');

describe('GET /', () => {
  it('should return hello message', async () => {
    const res = await request(app).get('/');
    expect(res.statusCode).toBe(200);
    expect(res.body.message).toBe('Hello from JavaScript project!');
  });
});
EOF
    
    # .env.example
    cat > .env.example << 'EOF'
PORT=3000
NODE_ENV=development
API_KEY=your_api_key_here
EOF
    
    # .gitignore
    cat > .gitignore << 'EOF'
# Dependencies
node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# Runtime data
pids
*.pid
*.seed
*.pid.lock

# Coverage directory used by tools like istanbul
coverage/

# Environment variables
.env
.env.local
.env.development.local
.env.test.local
.env.production.local

# IDEs
.vscode/
.idea/

# OS
.DS_Store
Thumbs.db

# Warp
.warp/
code-quality-report.log
security-report.log
EOF
    
    log_success "JavaScript project structure created"
}

# Create WordPress plugin project
create_wordpress_plugin_project() {
    local project_name="$1"
    
    log_info "Setting up WordPress plugin structure..."
    
    # Plugin directories
    mkdir -p {includes,assets/{css,js,images},languages,templates,tests}
    
    # Main plugin file
    local class_name=$(echo "$project_name" | sed 's/-/_/g' | sed 's/\b\w/\U&/g')
    local constant_prefix=$(echo "$project_name" | tr '[:lower:]' '[:upper:]' | tr '-' '_')
    
    cat > "$project_name.php" << EOF
<?php
/**
 * Plugin Name: $project_name
 * Description: WordPress plugin created with Warp
 * Version: 1.0.0
 * Author: Developer
 * Text Domain: $project_name
 * Domain Path: /languages
 */

// Prevent direct access
if (!defined('ABSPATH')) {
    exit;
}

// Define constants
define('${constant_prefix}_VERSION', '1.0.0');
define('${constant_prefix}_PLUGIN_DIR', plugin_dir_path(__FILE__));
define('${constant_prefix}_PLUGIN_URL', plugin_dir_url(__FILE__));

/**
 * Main plugin class
 */
class $class_name {
    
    public function __construct() {
        add_action('init', array(\$this, 'init'));
        register_activation_hook(__FILE__, array(\$this, 'activate'));
        register_deactivation_hook(__FILE__, array(\$this, 'deactivate'));
    }
    
    public function init() {
        load_plugin_textdomain('$project_name', false, dirname(plugin_basename(__FILE__)) . '/languages');
    }
    
    public function activate() {
        flush_rewrite_rules();
    }
    
    public function deactivate() {
        flush_rewrite_rules();
    }
}

// Initialize plugin
new $class_name();
EOF
    
    # Basic .gitignore
    cat > .gitignore << 'EOF'
# WordPress
wp-config.php
wp-content/uploads/
wp-content/cache/

# Dependencies
node_modules/
vendor/

# Build files
assets/dist/
*.min.css
*.min.js

# Environment
.env

# IDEs
.vscode/
.idea/

# OS
.DS_Store
Thumbs.db

# Warp
.warp/
code-quality-report.log
security-report.log
EOF
    
    log_success "WordPress plugin structure created"
}

# Create GitHub repository
create_github_repo() {
    local repo_name="$1"
    local description="$2"
    local private="${3:-false}"
    
    log_info "Creating GitHub repository: $repo_name"
    
    local visibility_flag="--public"
    if [[ "$private" == "true" ]]; then
        visibility_flag="--private"
    fi
    
    if gh repo create "$repo_name" $visibility_flag --description "$description" --clone; then
        log_success "Repository created and cloned: $repo_name"
        return 0
    else
        log_error "Failed to create repository"
        return 1
    fi
}

# Main function
main() {
    case "$1" in
        "new")
            local repo_name="$2"
            local project_type="$3"
            local description="${4:-Project created with Warp}"
            local private="${5:-false}"
            
            if [[ -z "$repo_name" ]] || [[ -z "$project_type" ]]; then
                log_error "Usage: warp github new <name> <type> [description] [private]"
                echo "Types: python, javascript, wordpress-plugin"
                exit 1
            fi
            
            # Validate project name
            if [[ ! "$repo_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
                log_error "Invalid project name. Use only letters, numbers, hyphens, and underscores."
                exit 1
            fi
            
            # Check credentials
            check_credentials || exit 1
            
            # Create GitHub repository
            create_github_repo "$repo_name" "$description" "$private" || exit 1
            
            # Enter project directory
            cd "$repo_name"
            
            # Create project structure
            create_project_structure "$repo_name" "$project_type" || exit 1
            
            # Initial commit
            git add .
            git commit -m "feat: initial project setup"
            git push -u origin main
            
            log_success "Project '$repo_name' created successfully!"
            echo
            echo "📁 Project location: $(pwd)"
            echo "🔗 Repository: $(gh repo view --web --json url -q .url 2>/dev/null || echo 'GitHub repository')"
            echo
            echo "🚀 Next steps:"
            case "$project_type" in
                "python")
                    echo "  1. Set up development environment: ./setup-dev.sh"
                    echo "  2. Activate virtual environment: source venv/bin/activate"
                    echo "  3. Run tests: pytest"
                    ;;
                "javascript")
                    echo "  1. Install dependencies: npm install"
                    echo "  2. Start development server: npm run dev"
                    echo "  3. Run tests: npm test"
                    ;;
                "wordpress-plugin")
                    echo "  1. Set up WordPress environment: warp wordpress plugin"
                    echo "  2. Start development server: docker-compose up -d"
                    echo "  3. Access WordPress: http://localhost:8080"
                    ;;
            esac
            echo "  4. Run quality checks: warp quality"
            echo "  5. Run security checks: warp security"
            ;;
        *)
            echo "GitHub Repository Manager"
            echo "Usage: warp github new <name> <type> [description] [private]"
            echo
            echo "Project types:"
            echo "  python           - Python application"
            echo "  javascript       - JavaScript/Node.js application"  
            echo "  wordpress-plugin - WordPress plugin"
            echo
            echo "Examples:"
            echo "  warp github new my-python-app python"
            echo "  warp github new my-api javascript 'REST API application'"
            echo "  warp github new my-plugin wordpress-plugin 'WordPress plugin' true"
            ;;
    esac
}

main "$@"
