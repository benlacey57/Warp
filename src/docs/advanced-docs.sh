```bash
SCRIPT_HANDLE=$(echo "$project_name" | tr '_' '-')
STYLE_HANDLE=$(echo "$project_name" | tr '_' '-')
NONCE_ACTION=${project_name}_nonce
AJAX_ACTION=${project_name}_ajax
SHORTCODE=$(echo "$project_name" | tr '_' '-')
TABLE_NAME=$(echo "$project_name" | tr '-' '_')
CRON_HOOK=${project_name}_cron
OPTION_GROUP=${project_name}_options
SECTION_ID=${project_name}_section
LOCALIZE_OBJECT=$(echo "$project_name" | sed 's/[-_]./\U&/g' | sed 's/[-_]//g')Object
PLUGIN_URI=https://github.com/$GITHUB_USERNAME/$project_name

# Node.js/JavaScript specific
NPM_NAME=$(echo "$project_name" | tr '[:upper:]' '[:lower:]')
MODULE_NAME=$(echo "$project_name" | sed 's/[-_]./\U&/g' | sed 's/[-_]//g')
COMPONENT_NAME=$(echo "$project_name" | sed 's/[-_]./\U&/g' | sed 's/[-_]//g' | sed 's/^./\U&/')

# Python specific
PYTHON_PACKAGE=$(echo "$project_name" | tr '-' '_' | tr '[:upper:]' '[:lower:]')
PYTHON_MODULE=$(echo "$project_name" | tr '-' '_' | tr '[:upper:]' '[:lower:]')
PYTHON_CLASS=$(echo "$project_name" | sed 's/[-_]./\U&/g' | sed 's/[-_]//g' | sed 's/^./\U&/')

# Feature flags
USE_DOCKER=$use_docker
INCLUDE_TESTING=$include_testing
INCLUDE_CI=$include_ci
INCLUDE_DOCS=$include_docs

# Version and dates
PROJECT_VERSION=1.0.0
CURRENT_YEAR=$(date +%Y)
CURRENT_DATE=$(date +%Y-%m-%d)
CURRENT_DATETIME=$(date '+%Y-%m-%d %H:%M:%S')

# License
LICENSE=${LICENSE:-MIT}

# GitHub specific
GITHUB_USERNAME=${GITHUB_USERNAME:-$USER}
GITHUB_REPO_URL=https://github.com/$GITHUB_USERNAME/$project_name
GITHUB_ISSUES_URL=https://github.com/$GITHUB_USERNAME/$project_name/issues
GITHUB_CLONE_URL=git@github.com:$GITHUB_USERNAME/$project_name.git

# Docker specific
DOCKER_IMAGE_NAME=$(echo "$project_name" | tr '[:upper:]' '[:lower:]')
DOCKER_CONTAINER_NAME=$(echo "$project_name" | tr '[:upper:]' '[:lower:]')_app

# Database
DB_NAME=$(echo "$project_name" | tr '-' '_')
DB_TABLE_PREFIX=$(echo "$project_name" | tr '-' '_')_

# API specific
API_VERSION=v1
API_NAMESPACE=$project_name/v1
REST_ROUTE_PREFIX=$project_name

# File extensions based on project type
$(get_file_extensions_for_type "$project_type")

EOF

    log_success "Comprehensive variables generated: $output_file"
}

# Get file extensions for project type
get_file_extensions_for_type() {
    local project_type="$1"
    
    case "$project_type" in
        "python")
            echo "MAIN_FILE_EXT=.py"
            echo "TEST_FILE_EXT=.py"
            echo "CONFIG_FILE=setup.py"
            ;;
        "javascript"|"node")
            echo "MAIN_FILE_EXT=.js"
            echo "TEST_FILE_EXT=.test.js"
            echo "CONFIG_FILE=package.json"
            ;;
        "wordpress-plugin"|"wordpress-theme")
            echo "MAIN_FILE_EXT=.php"
            echo "TEST_FILE_EXT=.php"
            echo "CONFIG_FILE=composer.json"
            ;;
        "php")
            echo "MAIN_FILE_EXT=.php"
            echo "TEST_FILE_EXT=.php"
            echo "CONFIG_FILE=composer.json"
            ;;
    esac
}

# Create project from advanced template
create_project_from_template() {
    local project_name="$1"
    local template_name="$2"
    local options="$3"
    local target_dir="${4:-.}"
    
    local template_dir="$WARP_DIR/src/templates/projects/$template_name"
    
    if [[ ! -d "$template_dir" ]]; then
        log_error "Template not found: $template_name"
        return 1
    fi
    
    log_info "Creating project from template: $template_name"
    
    # Generate variables
    local vars_file=$(mktemp)
    generate_comprehensive_variables "$project_name" "$template_name" "$options" "$vars_file"
    
    # Create target directory
    local project_dir="$target_dir/$project_name"
    mkdir -p "$project_dir"
    
    # Process all template files
    find "$template_dir" -type f | while read -r template_file; do
        # Calculate relative path
        local rel_path="${template_file#$template_dir/}"
        
        # Process template filename (variables can be in filenames too)
        local output_filename=$(process_template_filename "$rel_path" "$vars_file")
        local output_file="$project_dir/$output_filename"
        
        # Create output directory
        mkdir -p "$(dirname "$output_file")"
        
        # Process template content
        if [[ "$template_file" == *.template ]]; then
            # Remove .template extension
            output_file="${output_file%.template}"
            process_advanced_template "$template_file" "$output_file" "$vars_file"
        else
            # Copy binary files as-is
            cp "$template_file" "$output_file"
        fi
    done
    
    # Set executable permissions for scripts
    find "$project_dir" -name "*.sh" -type f -exec chmod +x {} \;
    find "$project_dir" -name "*-dev.sh" -type f -exec chmod +x {} \;
    
    # Cleanup
    rm -f "$vars_file"
    
    log_success "Project created from template: $project_dir"
}

# Process template filenames (variables in filenames)
process_template_filename() {
    local filename="$1"
    local vars_file="$2"
    
    local processed="$filename"
    
    # Load variables
    while IFS='=' read -r key value; do
        [[ $key =~ ^[[:space:]]*# ]] && continue
        [[ -z "$key" ]] && continue
        processed=$(echo "$processed" | sed "s/{{$key}}/$value/g")
    done < "$vars_file"
    
    echo "$processed"
}

# Interactive template selection and customization
interactive_template_wizard() {
    echo "🧙 Warp Project Template Wizard"
    echo "==============================="
    echo
    
    # Project name
    read -p "📝 Project name: " project_name
    if [[ -z "$project_name" ]]; then
        log_error "Project name is required"
        exit 1
    fi
    
    # Validate project name
    if [[ ! "$project_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        log_error "Invalid project name. Use only letters, numbers, hyphens, and underscores."
        exit 1
    fi
    
    echo
    echo "📋 Available project templates:"
    echo
    
    # List available templates
    local templates=()
    local template_descriptions=()
    
    for template_dir in "$WARP_DIR/src/templates/projects"/*; do
        if [[ -d "$template_dir" ]]; then
            local template_name=$(basename "$template_dir")
            local description=""
            
            if [[ -f "$template_dir/template.json" ]]; then
                description=$(grep -o '"description":"[^"]*"' "$template_dir/template.json" | cut -d'"' -f4)
            fi
            
            templates+=("$template_name")
            template_descriptions+=("${description:-No description available}")
        fi
    done
    
    # Display templates
    for i in "${!templates[@]}"; do
        printf "  %2d. %-20s %s\n" $((i+1)) "${templates[$i]}" "${template_descriptions[$i]}"
    done
    
    echo
    read -p "🎯 Select template (1-${#templates[@]}): " template_selection
    
    if [[ ! "$template_selection" =~ ^[0-9]+$ ]] || [[ "$template_selection" -lt 1 ]] || [[ "$template_selection" -gt ${#templates[@]} ]]; then
        log_error "Invalid template selection"
        exit 1
    fi
    
    local selected_template="${templates[$((template_selection-1))]}"
    
    # Get template options
    local template_config="$WARP_DIR/src/templates/projects/$selected_template/template.json"
    local options="{}"
    
    if [[ -f "$template_config" ]]; then
        echo
        echo "⚙️  Template Options for $selected_template"
        echo "==========================================="
        
        # Parse and display options (simplified - would use jq in production)
        options=$(get_template_options "$template_config")
    fi
    
    echo
    read -p "📄 Project description: " project_description
    read -p "👤 Author name [$USER]: " author_name
    author_name=${author_name:-$USER}
    
    echo
    read -p "🔧 Include Docker environment? [Y/n]: " use_docker
    use_docker=${use_docker:-y}
    
    read -p "🧪 Include testing setup? [Y/n]: " include_testing
    include_testing=${include_testing:-y}
    
    read -p "🚀 Include CI/CD pipeline? [Y/n]: " include_ci
    include_ci=${include_ci:-y}
    
    read -p "📖 Include documentation? [Y/n]: " include_docs
    include_docs=${include_docs:-y}
    
    read -p "🔒 Make repository private? [y/N]: " private_repo
    private_repo=${private_repo:-n}
    
    # Compile options
    local compiled_options="{
        \"description\": \"$project_description\",
        \"author\": \"$author_name\",
        \"docker\": \"$(bool_to_string "$use_docker")\",
        \"testing\": \"$(bool_to_string "$include_testing")\",
        \"ci\": \"$(bool_to_string "$include_ci")\",
        \"docs\": \"$(bool_to_string "$include_docs")\",
        \"private\": \"$(bool_to_string "$private_repo")\"
    }"
    
    echo
    echo "🎯 Project Summary:"
    echo "  Name: $project_name"
    echo "  Template: $selected_template"
    echo "  Description: $project_description"
    echo "  Author: $author_name"
    echo "  Docker: $(bool_to_string "$use_docker")"
    echo "  Testing: $(bool_to_string "$include_testing")"
    echo "  CI/CD: $(bool_to_string "$include_ci")"
    echo "  Documentation: $(bool_to_string "$include_docs")"
    echo "  Private: $(bool_to_string "$private_repo")"
    echo
    
    if ! confirm "Create project with these settings?"; then
        echo "Project creation cancelled."
        exit 0
    fi
    
    echo
    echo "🚀 Creating project..."
    
    # Create GitHub repository if not exists locally
    if [[ ! -d ".git" ]]; then
        local visibility_flag="--public"
        if [[ "$(bool_to_string "$private_repo")" == "true" ]]; then
            visibility_flag="--private"
        fi
        
        gh repo create "$project_name" $visibility_flag --description "$project_description" --clone || {
            log_warning "GitHub repository creation failed. Creating local project only."
        }
        
        if [[ -d "$project_name" ]]; then
            cd "$project_name"
        fi
    fi
    
    # Create project from template
    create_project_from_template "$project_name" "$selected_template" "$compiled_options" "."
    
    # If we're in the project directory, move files up
    if [[ -d "$project_name" ]]; then
        mv "$project_name"/* . 2>/dev/null || true
        mv "$project_name"/.* . 2>/dev/null || true
        rmdir "$project_name"
    fi
    
    # Initial commit
    if [[ -d ".git" ]]; then
        git add .
        git commit -m "feat: initial project setup from $selected_template template"
        git push -u origin main 2>/dev/null || git push -u origin master 2>/dev/null || true
    fi
    
    echo
    echo "🎉 Project '$project_name' created successfully!"
    echo
    echo "📁 Project location: $(pwd)"
    echo
    
    # Show next steps based on template
    show_next_steps "$selected_template" "$compiled_options"
}

# Convert y/n to true/false
bool_to_string() {
    local input="$1"
    if [[ "$input" =~ ^[Yy]$ ]]; then
        echo "true"
    else
        echo "false"
    fi
}

# Get template options (simplified - would use jq for real JSON parsing)
get_template_options() {
    local config_file="$1"
    echo "{}"  # Simplified - return empty options for now
}

# Show next steps based on project template
show_next_steps() {
    local template_name="$1"
    local options="$2"
    
    echo "🚀 Next steps:"
    
    case "$template_name" in
        "python")
            echo "  1. Set up development environment:"
            echo "     chmod +x setup-dev.sh && ./setup-dev.sh"
            echo "  2. Activate virtual environment:"
            echo "     source venv/bin/activate"
            echo "  3. Run tests:"
            echo "     pytest"
            if [[ "$options" == *"\"docker\":\"true\""* ]]; then
                echo "  4. Start Docker environment:"
                echo "     ./docker-dev.sh start"
            fi
            ;;
        "javascript"|"node")
            echo "  1. Install dependencies:"
            echo "     npm install"
            echo "  2. Start development server:"
            echo "     npm run dev"
            echo "  3. Run tests:"
            echo "     npm test"
            if [[ "$options" == *"\"docker\":\"true\""* ]]; then
                echo "  4. Start Docker environment:"
                echo "     ./docker-dev.sh start"
            fi
            ;;
        "wordpress-plugin")
            echo "  1. Install dependencies:"
            echo "     npm install && composer install"
            echo "  2. Start WordPress environment:"
            echo "     ./wp-dev.sh start"
            echo "  3. Start asset watcher:"
            echo "     ./wp-dev.sh dev watch"
            echo "  4. Access WordPress:"
            echo "     http://localhost:8080 (admin/admin)"
            ;;
        "laravel-api"|"laravel-admin")
            echo "  1. Install dependencies:"
            echo "     composer install"
            echo "  2. Set up environment:"
            echo "     cp .env.example .env"
            echo "  3. Start Docker environment:"
            echo "     ./docker-dev.sh start"
            echo "  4. Run migrations:"
            echo "     ./docker-dev.sh artisan migrate"
            ;;
    esac
    
    echo
    echo "💡 Common commands:"
    echo "  warp quality     # Run code quality checks"
    echo "  warp security    # Run security analysis"
    echo "  warp docs serve  # Serve documentation locally"
    
    if [[ "$options" == *"\"ci\":\"true\""* ]]; then
        echo
        echo "🔄 CI/CD Pipeline:"
        echo "  Your project includes GitHub Actions for:"
        echo "  • Automated testing on push/PR"
        echo "  • Code quality checks"
        echo "  • Security scanning"
        echo "  • Automated deployment (on main branch)"
    fi
    
    if [[ "$options" == *"\"docs\":\"true\""* ]]; then
        echo
        echo "📖 Documentation:"
        echo "  Generate docs: warp docs generate"
        echo "  Serve docs locally: warp docs serve"
    fi
}

# Main function
main() {
    case "$1" in
        "wizard"|"interactive")
            interactive_template_wizard
            ;;
        "create")
            local project_name="$2"
            local template_name="$3"
            local options="${4:-{}}"
            
            if [[ -z "$project_name" ]] || [[ -z "$template_name" ]]; then
                log_error "Usage: warp templates create <project-name> <template-name> [options-json]"
                exit 1
            fi
            
            create_project_from_template "$project_name" "$template_name" "$options"
            ;;
        "list")
            echo "Available project templates:"
            echo
            for template_dir in "$WARP_DIR/src/templates/projects"/*; do
                if [[ -d "$template_dir" ]]; then
                    local template_name=$(basename "$template_dir")
                    local description=""
                    
                    if [[ -f "$template_dir/template.json" ]]; then
                        description=$(grep -o '"description":"[^"]*"' "$template_dir/template.json" | cut -d'"' -f4 2>/dev/null || echo "")
                    fi
                    
                    printf "  %-20s %s\n" "$template_name" "${description:-No description}"
                fi
            done
            ;;
        "validate")
            local template_name="$2"
            if [[ -z "$template_name" ]]; then
                log_error "Usage: warp templates validate <template-name>"
                exit 1
            fi
            validate_template "$WARP_DIR/src/templates/projects/$template_name"
            ;;
        *)
            echo "Advanced Template Engine"
            echo "Usage: warp templates <command> [options]"
            echo
            echo "Commands:"
            echo "  wizard              - Interactive project creation wizard"
            echo "  create <name> <tpl> - Create project from template"
            echo "  list                - List available templates"
            echo "  validate <tpl>      - Validate template"
            echo
            echo "Examples:"
            echo "  warp templates wizard"
            echo "  warp templates create my-app python '{\"docker\":true}'"
            echo "  warp templates list"
            ;;
    esac
}

main "$@"
```

### 3. Enhanced Documentation Generator

Let's create a comprehensive documentation system:

**File**: `src/docs/advanced-docs.sh`

```bash
#!/bin/bash
# Advanced Documentation Generator

set -e

WARP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$WARP_DIR/src/core/logger.sh"
source "$WARP_DIR/src/core/utils.sh"

PROJECT_ROOT=$(pwd)
DOCS_DIR="$PROJECT_ROOT/docs"
BUILD_DIR="$PROJECT_ROOT/.warp/docs-build"

# Generate comprehensive documentation
generate_comprehensive_docs() {
    local project_type="$1"
    local output_format="${2:-html}"
    
    log_info "Generating comprehensive documentation..."
    
    # Create documentation structure
    create_docs_structure "$project_type"
    
    # Generate different types of documentation
    generate_api_docs "$project_type"
    generate_user_guide "$project_type"
    generate_developer_guide "$project_type"
    generate_deployment_guide "$project_type"
    
    # Build documentation website
    if [[ "$output_format" == "website" ]] || [[ "$output_format" == "html" ]]; then
        build_docs_website
    fi
    
    # Generate PDF if requested
    if [[ "$output_format" == "pdf" ]]; then
        generate_pdf_docs
    fi
    
    log_success "Documentation generated successfully!"
}

# Create documentation structure
create_docs_structure() {
    local project_type="$1"
    
    mkdir -p "$DOCS_DIR"/{api,guides,tutorials,examples,assets/{css,js,images}}
    
    # Create main index
    cat > "$DOCS_DIR/index.md" << EOF
# $(basename "$PROJECT_ROOT" | sed 's/[-_]/ /g' | sed 's/\b\w/\U&/g') Documentation

Welcome to the documentation for $(basename "$PROJECT_ROOT").

## Quick Start

$(generate_quick_start_section "$project_type")

## Documentation Sections

- [📚 User Guide](guides/user-guide.md) - How to use this project
- [🔧 Developer Guide](guides/developer-guide.md) - How to contribute and develop
- [🚀 Deployment Guide](guides/deployment.md) - How to deploy to production
- [📖 API Reference](api/README.md) - Complete API documentation
- [💡 Examples](examples/README.md) - Code examples and tutorials

## Support

- [Issues](https://github.com/$GITHUB_USERNAME/$(basename "$PROJECT_ROOT")/issues)
- [Discussions](https://github.com/$GITHUB_USERNAME/$(basename "$PROJECT_ROOT")/discussions)

---

*Documentation generated with [Warp](https://github.com/user/warp) on $(date)*
EOF
}

# Generate quick start section based on project type
generate_quick_start_section() {
    local project_type="$1"
    
    case "$project_type" in
        "python")
            cat << 'EOF'
```bash
# Clone the repository
git clone https://github.com/{{GITHUB_USERNAME}}/{{PROJECT_NAME}}.git
cd {{PROJECT_NAME}}

# Set up development environment
./setup-dev.sh

# Activate virtual environment
source venv/bin/activate

# Run tests
pytest

# Start the application
python -m src.main
```
EOF
            ;;
        "javascript"|"node")
            cat << 'EOF'
```bash
# Clone the repository
git clone https://github.com/{{GITHUB_USERNAME}}/{{PROJECT_NAME}}.git
cd {{PROJECT_NAME}}

# Install dependencies
npm install

# Start development server
npm run dev

# Run tests
npm test

# Build for production
npm run build
```
EOF
            ;;
        "wordpress-plugin")
            cat << 'EOF'
```bash
# Clone the repository
git clone https://github.com/{{GITHUB_USERNAME}}/{{PROJECT_NAME}}.git
cd {{PROJECT_NAME}}

# Install dependencies
npm install && composer install

# Start WordPress development environment
./wp-dev.sh start

# Start asset watcher
./wp-dev.sh dev watch

# Access WordPress at http://localhost:8080
# Admin login: admin/admin
```
EOF;
