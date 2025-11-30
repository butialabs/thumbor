#!/bin/bash
set -e

# Load common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="DOCKER-ENTRYPOINT"

THUMBOR_HOST="${THUMBOR_HOST:-}"
WEBROOT="/var/www/certbot"
RENEWAL_DAYS=1

# Source common utilities
source "${SCRIPT_DIR}/common-utils.sh"

logs() {
    info "Checking and creating log directories..."
    
    # Array of log directories to check/create
    local log_dirs=(
        "/var/log/nginx"
        "/var/log/supervisor"
        "/var/log/system"
    )
    
    # Check each directory
    for dir in "${log_dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            info "Creating log directory: $dir"
            if safe_execute "mkdir -p '$dir'" "Creating directory $dir"; then
                debug "Directory $dir created successfully"
                
                # Set permissions to 755 for directories
                if safe_execute "chmod 755 '$dir'" "Setting permissions for $dir"; then
                    debug "Permissions set to 755 for $dir"
                else
                    warning "Failed to set permissions for $dir"
                fi
                
                # Set proper ownership based on directory type
                if [[ "$dir" == "/var/log/supervisor" || "$dir" == "/var/log/system" ]]; then
                    # Supervisor and system logs should be owned by root
                    if safe_execute "chown root:root '$dir'" "Setting ownership for $dir"; then
                        debug "Ownership set to root:root for $dir"
                    else
                        warning "Failed to set ownership for $dir"
                    fi
                else
                    # Other logs should be owned by www-data
                    if safe_execute "chown www-data:www-data '$dir'" "Setting ownership for $dir"; then
                        debug "Ownership set to www-data:www-data for $dir"
                    else
                        warning "Failed to set ownership for $dir"
                    fi
                fi
            else
                error "Failed to create directory $dir"
            fi
        else
            debug "Log directory already exists: $dir"
        fi
    done
    
    success "Log directories check completed"
}

# Thumbor
configure_thumbor() {
    # To disable warning libdc1394 error: Failed to initialize libdc1394
    ln -s /dev/null /dev/raw1394

    # Generate thumbor configuration from template
    if [ ! -f /app/thumbor.conf ]; then
    envtpl /app/thumbor.conf.tpl --allow-missing --keep-template
    fi

    # Set default environment variables if not provided
    export THUMBOR_LOG_LEVEL=${THUMBOR_LOG_LEVEL:-info}
    export THUMBOR_NUM_PROCESSES=${THUMBOR_NUM_PROCESSES:-4}
}

# Main function
main() {
    # Log script start
    log_script_start "Docker Entrypoint"
        
    # Check required environment variables
    require_env_vars DOMAIN

    logs
    
    # Configure Thumbor
    configure_thumbor
    
    # Log script end
    log_script_end 0 "Docker Entrypoint"
    
    # Execute the original command
    info "Executing command: $*"
    exec "$@"
}

# Execute main function
main "$@"