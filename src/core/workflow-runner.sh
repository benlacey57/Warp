#!/bin/bash
# Workflow Runner for Warp

# Load core utilities
source "$WARP_DIR/src/core/logger.sh"
source "$WARP_DIR/src/core/utils.sh"

# Parse YAML workflow file
parse_workflow() {
    local workflow_file="$1"
    
    if [[ ! -f "$workflow_file" ]]; then
        log_error "Workflow file not found: $workflow_file"
        return 1
    fi
    
    # Extract workflow metadata
    local name=$(grep "^name:" "$workflow_file" | cut -d':' -f2- | sed 's/^[[:space:]]*//' | tr -d '"')
    local description=$(grep "^description:" "$workflow_file" | cut -d':' -f2- | sed 's/^[[:space:]]*//' | tr -d '"')
    
    export WORKFLOW_NAME="$name"
    export WORKFLOW_DESCRIPTION="$description"
    
    log_info "Running workflow: $name"
    if [[ -n "$description" ]]; then
        log_info "Description: $description"
    fi
}

# Execute workflow command
execute_workflow() {
    local workflow_file="$1"
    shift
    local args=("$@")
    
    # Parse workflow metadata
    parse_workflow "$workflow_file"
    
    # Extract command section (everything after 'command: |')
    local command_section=$(awk '/^command: \|/{flag=1; next} /^[^ ]/{flag=0} flag && /^  /{print substr($0, 3)}' "$workflow_file")
    
    if [[ -z "$command_section" ]]; then
        log_error "No command section found in workflow"
        return 1
    fi
    
    # Create temporary script
    local temp_script=$(mktemp)
    echo '#!/bin/bash' > "$temp_script"
    echo 'set -e' >> "$temp_script"
    echo '' >> "$temp_script"
    echo "# Workflow: $WORKFLOW_NAME" >> "$temp_script"
    echo "# Arguments: ${args[*]}" >> "$temp_script"
    echo '' >> "$temp_script"
    echo "$command_section" >> "$temp_script"
    
    # Make executable
    chmod +x "$temp_script"
    
    # Execute with arguments
    log_debug "Executing workflow script: $temp_script"
    
    # Export workflow arguments
    for i in "${!args[@]}"; do
        export "WORKFLOW_ARG_$((i+1))"="${args[$i]}"
    done
    export WORKFLOW_ARGS="${args[*]}"
    
    # Execute the script
    if "$temp_script"; then
        log_success "Workflow completed successfully"
        local exit_code=0
    else
        local exit_code=$?
        log_error "Workflow failed with exit code: $exit_code"
    fi
    
    # Cleanup
    rm -f "$temp_script"
    
    return $exit_code
}

# List available workflows with details
list_workflows_detailed() {
    echo "Available Warp workflows:"
    echo
    
    local workflows_dir="$WARP_DIR/src/workflows"
    
    if [[ ! -d "$workflows_dir" ]]; then
        log_warning "Workflows directory not found: $workflows_dir"
        return 1
    fi
    
    for workflow in "$workflows_dir"/*.yaml; do
        if [[ -f "$workflow" ]]; then
            local name=$(basename "$workflow" .yaml)
            local title=$(grep "^name:" "$workflow" | cut -d':' -f2- | sed 's/^[[:space:]]*//' | tr -d '"')
            local description=$(grep "^description:" "$workflow" | cut -d':' -f2- | sed 's/^[[:space:]]*//' | tr -d '"')
            
            printf "  %-20s %s\n" "$name" "$title"
            if [[ -n "$description" ]]; then
                printf "  %-20s %s\n" "" "$description"
            fi
            echo
        fi
    done
    
    echo "Usage: warp workflow <workflow-name> [args...]"
}

# Validate workflow file
validate_workflow() {
    local workflow_file="$1"
    
    log_info "Validating workflow: $(basename "$workflow_file")"
    
    # Check required fields
    local required_fields=("name" "command")
    local validation_errors=()
    
    for field in "${required_fields[@]}"; do
        if ! grep -q "^$field:" "$workflow_file"; then
            validation_errors+=("Missing required field: $field")
        fi
    done
    
    # Check command section
    if ! grep -q "^command: |" "$workflow_file"; then
        validation_errors+=("Command section must use literal block scalar (|)")
    fi
    
    # Check YAML syntax (if yq is available)
    if command -v yq >/dev/null; then
        if ! yq eval '.' "$workflow_file" >/dev/null 2>&1; then
            validation_errors+=("Invalid YAML syntax")
        fi
    fi
    
    # Report validation results
    if [[ ${#validation_errors[@]} -eq 0 ]]; then
        log_success "Workflow validation passed"
        return 0
    else
        log_error "Workflow validation failed:"
        for error in "${validation_errors[@]}"; do
            echo "  - $error"
        done
        return 1
    fi
}

# Create new workflow from template
create_workflow() {
    local workflow_name="$1"
    local workflow_title="$2"
    local workflow_description="$3"
    
    if [[ -z "$workflow_name" ]]; then
        log_error "Workflow name is required"
        return 1
    fi
    
    local workflow_file="$WARP_DIR/src/workflows/$workflow_name.yaml"
    
    if [[ -f "$workflow_file" ]]; then
        log_error "Workflow already exists: $workflow_name"
        return 1
    fi
    
    # Create workflow from template
    cat > "$workflow_file" << EOF
name: "${workflow_title:-$workflow_name}"
description: "${workflow_description:-Custom workflow}"
command: |
  #!/bin/bash
  
  # Load Warp utilities
  source "\$WARP_DIR/src/core/logger.sh"
  source "\$WARP_DIR/src/core/utils.sh"
  
  echo "🚀 Running workflow: ${workflow_title:-$workflow_name}"
  echo "=================================="
  echo
  
  # Workflow arguments available as:
  # \$WORKFLOW_ARG_1, \$WORKFLOW_ARG_2, etc.
  # or \$WORKFLOW_ARGS for all arguments
  
  # Add your workflow commands here
  log_info "Workflow started"
  
  # Example: Run quality checks
  # warp quality
  
  # Example: Deploy application
  # echo "Deploying application..."
  
  log_success "Workflow completed successfully"
EOF
    
    log_success "Workflow created: $workflow_file"
    log_info "Edit the workflow file to customize it for your needs"
    
    # Validate the created workflow
    validate_workflow "$workflow_file"
}

# Interactive workflow selector
select_workflow() {
    local workflows_dir="$WARP_DIR/src/workflows"
    local workflows=()
    
    # Collect available workflows
    for workflow in "$workflows_dir"/*.yaml; do
        if [[ -f "$workflow" ]]; then
            workflows+=($(basename "$workflow" .yaml))
        fi
    done
    
    if [[ ${#workflows[@]} -eq 0 ]]; then
        log_warning "No workflows available"
        return 1
    fi
    
    echo "Available workflows:"
    for i in "${!workflows[@]}"; do
        local workflow_file="$workflows_dir/${workflows[$i]}.yaml"
        local title=$(grep "^name:" "$workflow_file" | cut -d':' -f2- | sed 's/^[[:space:]]*//' | tr -d '"')
        echo "$((i + 1)). ${workflows[$i]} - $title"
    done
    echo
    
    read -p "Select workflow (1-${#workflows[@]}): " selection
    
    if [[ "$selection" =~ ^[0-9]+$ ]] && [[ "$selection" -ge 1 ]] && [[ "$selection" -le ${#workflows[@]} ]]; then
        local selected_workflow="${workflows[$((selection - 1))]}"
        echo
        log_info "Selected workflow: $selected_workflow"
        
        # Ask for arguments
        read -p "Enter workflow arguments (optional): " workflow_args
        
        # Execute workflow
        execute_workflow "$workflows_dir/$selected_workflow.yaml" $workflow_args
    else
        log_error "Invalid selection"
        return 1
    fi
}

# Main workflow command handler
handle_workflow_command() {
    local subcommand="$1"
    shift
    
    case "$subcommand" in
        "list"|"ls")
            list_workflows_detailed
            ;;
        "run")
            local workflow_name="$1"
            shift
            local workflow_file="$WARP_DIR/src/workflows/$workflow_name.yaml"
            execute_workflow "$workflow_file" "$@"
            ;;
        "validate")
            local workflow_name="$1"
            local workflow_file="$WARP_DIR/src/workflows/$workflow_name.yaml"
            validate_workflow "$workflow_file"
            ;;
        "create")
            create_workflow "$1" "$2" "$3"
            ;;
        "select")
            select_workflow
            ;;
        "edit")
            local workflow_name="$1"
            local workflow_file="$WARP_DIR/src/workflows/$workflow_name.yaml"
            if [[ -f "$workflow_file" ]]; then
                ${EDITOR:-nano} "$workflow_file"
            else
                log_error "Workflow not found: $workflow_name"
            fi
            ;;
        *)
            # Default: try to run workflow
            if [[ -n "$subcommand" ]]; then
                local workflow_file="$WARP_DIR/src/workflows/$subcommand.yaml"
                execute_workflow "$workflow_file" "$@"
            else
                list_workflows_detailed
            fi
            ;;
    esac
}
