#!/bin/bash
# Template Manager for Warp

# Template processing functions
process_template() {
    local template_file="$1"
    local output_file="$2"
    local variables_file="$3"
    
    if [[ ! -f "$template_file" ]]; then
        log_error "Template file not found: $template_file"
        return 1
    fi
    
    # Load variables
    local variables=()
    if [[ -f "$variables_file" ]]; then
        while IFS='=' read -r key value; do
            variables+=("s/{{$key}}/$value/g")
        done < "$variables_file"
    fi
    
    # Process template
    local content=$(cat "$template_file")
    
    for substitution in "${variables[@]}"; do
        content=$(echo "$content" | sed "$substitution")
    done
    
    # Write output
    echo "$content" > "$output_file"
    
    log_success "Template processed: $template_file -> $output_file"
}

# Copy template directory
copy_template_dir() {
    local template_dir="$1"
    local target_dir="$2"
    local variables_file="$3"
    
    if [[ ! -d "$template_dir" ]]; then
        log_error "Template directory not found: $template_dir"
        return 1
    fi
    
    # Create target directory
    mkdir -p "$target_dir"
    
    # Copy and process templates
    find "$template_dir" -type f | while read -r file; do
        local relative_path="${file#$template_dir/}"
        local target_file="$target_dir/$relative_path"
        local target_subdir=$(dirname "$target_file")
        
        # Create subdirectory if needed
        mkdir -p "$target_subdir"
        
        # Process template file
        if [[ "$file" == *.template ]]; then
            # Remove .template extension from target
            target_file="${target_file%.template}"
            process_template "$file" "$target_file" "$variables_file"
        else
            # Copy file as-is
            cp "$file" "$target_file"
        fi
    done
    
    log_success "Template directory copied: $template_dir -> $target_dir"
}

# Generate variables file for project
generate_project_variables() {
    local project_name="$1"
    local project_type="$2"
    local author_name="${3:-$USER}"
    local variables_file="$4"
    
    # Convert project name to different formats
    local class_name=$(echo "$project_name" | sed 's/-/_/g' | sed 's/\b\w/\U&/g')
    local constant_prefix=$(echo "$project_name" | tr '[:lower:]' '[:upper:]' | tr '-' '_')
    local function_prefix=$(echo "$project_name" | tr '-' '_' | tr '[:upper:]' '[:lower:]')
    
    cat > "$variables_file" << EOF
PROJECT_NAME=$project_name
PROJECT_TYPE=$project_type
AUTHOR_NAME=$author_name
CLASS_NAME=$class_name
CONSTANT_PREFIX=$constant_prefix
FUNCTION_PREFIX=$function_prefix
PACKAGE_NAME=$(echo "$project_name" | sed 's/-//g')
TEXT_DOMAIN=$project_name
MENU_SLUG=$(echo "$project_name" | tr '_' '-')
OPTION_PREFIX=$(echo "$project_name" | tr '-' '_')
SCRIPT_HANDLE=$(echo "$project_name" | tr '_' '-')
STYLE_HANDLE=$(echo "$project_name" | tr '_' '-')
NONCE_ACTION=${project_name}_nonce
AJAX_ACTION=${project_name}_ajax
SHORTCODE=$(echo "$project_name" | tr '_' '-')
TABLE_NAME=$(echo "$project_name" | tr '-' '_')
CRON_HOOK=${project_name}_cron
OPTION_GROUP=${project_name}_options
SECTION_ID=${project_name}_section
LOCALIZE_OBJECT=$(echo "$project_name" | sed 's/-/_/g')Object
PLUGIN_VERSION=1.0.0
PLUGIN_DESCRIPTION=A WordPress plugin created with Warp
PLUGIN_URI=https://github.com/$GITHUB_USERNAME/$project_name
AUTHOR_URI=https://github.com/$GITHUB_USERNAME
CURRENT_YEAR=$(date +%Y)
CURRENT_DATE=$(date '+%Y-%m-%d')
EOF
    
    log_success "Variables file generated: $variables_file"
}

# Get template path
get_template_path() {
    local template_type="$1"
    local template_name="$2"
    
    case "$template_type" in
        "project")
            echo "$WARP_DIR/src/github/templates/$template_name"
            ;;
        "workflow")
            echo "$WARP_DIR/src/workflows/$template_name.yaml"
            ;;
        "docs")
            echo "$WARP_DIR/src/docs/templates/$template_name"
            ;;
        "gitignore")
            echo "$WARP_DIR/src/templates/gitignore/$template_name.gitignore"
            ;;
        "github-actions")
            echo "$WARP_DIR/src/templates/github-actions/$template_name.yml"
            ;;
        "docker")
            echo "$WARP_DIR/src/templates/docker/$template_name"
            ;;
        *)
            echo "$WARP_DIR/src/templates/$template_type/$template_name"
            ;;
    esac
}

# List available templates
list_templates() {
    local template_type="$1"
    
    case "$template_type" in
        "project")
            echo "Available project templates:"
            ls -1 "$WARP_DIR/src/github/templates/" | grep -v '\.template$'
            ;;
        "workflow")
            echo "Available workflow templates:"
            ls -1 "$WARP_DIR/src/workflows/" | sed 's/\.yaml$//'
            ;;
        "docs")
            echo "Available documentation templates:"
            ls -1 "$WARP_DIR/src/docs/templates/" | grep '\.md$'
            ;;
        *)
            echo "Template types: project, workflow, docs, gitignore, github-actions, docker"
            ;;
    esac
}

# Validate template
validate_template() {
    local template_file="$1"
    
    if [[ ! -f "$template_file" ]]; then
        log_error "Template file not found: $template_file"
        return 1
    fi
    
    # Check for required variables
    local required_vars=$(grep -o '{{[A-Z_]*}}' "$template_file" | sort -u)
    
    if [[ -n "$required_vars" ]]; then
        log_info "Template requires these variables:"
        echo "$required_vars" | sed 's/[{}]//g' | sed 's/^/  - /'
    fi
    
    return 0
}
