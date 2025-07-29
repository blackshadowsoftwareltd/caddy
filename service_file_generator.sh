#!/bin/bash

# Systemd Service Generator Script
# This script generates systemd service files for any repository
# Usage: Run this script in your project directory

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_color() {
    color=$1
    message=$2
    echo -e "${color}${message}${NC}"
}

print_success() {
    print_color $GREEN "✅ $1"
}

print_error() {
    print_color $RED "❌ $1"
}

print_warning() {
    print_color $YELLOW "⚠️  $1"
}

print_info() {
    print_color $BLUE "ℹ️  $1"
}

# Function to detect project type
detect_project_type() {
    local project_dir="$1"
    
    if [[ -f "$project_dir/Cargo.toml" ]]; then
        echo "rust"
    elif [[ -f "$project_dir/package.json" ]]; then
        if grep -q "\"build\":" "$project_dir/package.json"; then
            echo "nodejs-build"
        else
            echo "nodejs"
        fi
    elif [[ -f "$project_dir/index.html" ]] || [[ -f "$project_dir/index.php" ]]; then
        echo "static"
    elif [[ -f "$project_dir/requirements.txt" ]] || [[ -f "$project_dir/setup.py" ]]; then
        echo "python"
    elif [[ -f "$project_dir/go.mod" ]]; then
        echo "go"
    else
        echo "unknown"
    fi
}

# Function to find executable
find_executable() {
    local project_type="$1"
    local project_dir="$2"
    local service_name="$3"
    
    case $project_type in
        "rust")
            # Look for binary in target/release/
            if [[ -f "$project_dir/target/release/$service_name" ]]; then
                echo "$project_dir/target/release/$service_name"
            elif [[ -d "$project_dir/target/release" ]]; then
                # Find the first executable in release directory
                local executable=$(find "$project_dir/target/release" -maxdepth 1 -type f -executable | head -n 1)
                if [[ -n "$executable" ]]; then
                    echo "$executable"
                fi
            fi
            ;;
        "nodejs"|"nodejs-build")
            echo "npm start"
            ;;
        "python")
            if [[ -f "$project_dir/main.py" ]]; then
                echo "python3 main.py"
            elif [[ -f "$project_dir/app.py" ]]; then
                echo "python3 app.py"
            elif [[ -f "$project_dir/server.py" ]]; then
                echo "python3 server.py"
            else
                echo "python3 main.py"
            fi
            ;;
        "go")
            if [[ -f "$project_dir/$service_name" ]]; then
                echo "$project_dir/$service_name"
            else
                echo "go run ."
            fi
            ;;
        *)
            echo ""
            ;;
    esac
}

# Function to get user input with validation
get_service_name() {
    while true; do
        echo
        print_info "Enter the service name (letters, numbers, hyphens only):"
        read -p "Service name: " service_name
        
        # Validate service name
        if [[ -z "$service_name" ]]; then
            print_error "Service name cannot be empty!"
            continue
        fi
        
        if [[ ! "$service_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
            print_error "Service name can only contain letters, numbers, underscores, and hyphens!"
            continue
        fi
        
        # Convert to lowercase and replace underscores with hyphens for consistency
        service_name=$(echo "$service_name" | tr '[:upper:]' '[:lower:]' | tr '_' '-')
        
        echo
        print_info "Service name will be: $service_name"
        read -p "Is this correct? (y/n): " confirm
        
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            echo "$service_name"
            return
        fi
    done
}

# Function to get optional configuration
get_service_config() {
    local project_type="$1"
    
    echo
    print_info "Optional configuration (press Enter for defaults):"
    
    # Description
    read -p "Service description [Auto-detected]: " description
    if [[ -z "$description" ]]; then
        case $project_type in
            "rust") description="Rust Application Server" ;;
            "nodejs"|"nodejs-build") description="Node.js Application Server" ;;
            "python") description="Python Application Server" ;;
            "go") description="Go Application Server" ;;
            "static") description="Static Website Server" ;;
            *) description="Application Server" ;;
        esac
    fi
    
    # User
    read -p "Run as user [root]: " run_user
    if [[ -z "$run_user" ]]; then
        run_user="root"
    fi
    
    # Port (for information only)
    read -p "Port number (for reference only) [8080]: " port
    if [[ -z "$port" ]]; then
        port="8080"
    fi
    
    # Environment variables
    read -p "Environment variables (e.g., RUST_LOG=info NODE_ENV=production) []: " env_vars
    
    echo "$description|$run_user|$port|$env_vars"
}

# Function to generate systemd service file content
generate_service_content() {
    local service_name="$1"
    local project_dir="$2"
    local project_type="$3"
    local executable="$4"
    local description="$5"
    local run_user="$6"
    local port="$7"
    local env_vars="$8"
    
    # Generate environment variables section
    local env_section=""
    if [[ -n "$env_vars" ]]; then
        # Split environment variables and format them
        IFS=' ' read -ra ENV_ARRAY <<< "$env_vars"
        for env in "${ENV_ARRAY[@]}"; do
            env_section+="\nEnvironment=$env"
        done
    fi
    
    # Determine if we need to change working directory
    local working_dir="$project_dir"
    if [[ "$project_type" == "static" ]]; then
        working_dir=""
    fi
    
    # Generate the service file content
    cat << EOF
[Unit]
Description=$description
After=network.target
Wants=network.target

[Service]
Type=simple
User=$run_user
Group=$run_user$(if [[ -n "$working_dir" ]]; then echo "
WorkingDirectory=$working_dir"; fi)
ExecStart=$executable
Restart=on-failure
RestartSec=5$(if [[ -n "$env_section" ]]; then echo -e "$env_section"; fi)

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectHome=true
ProtectSystem=strict$(if [[ -n "$working_dir" ]]; then echo "
ReadWritePaths=$working_dir"; fi)

# Limits
LimitNOFILE=65536
LimitNPROC=65536

[Install]
WantedBy=multi-user.target
EOF
}

# Main script execution
main() {
    print_info "Systemd Service Generator"
    print_info "========================="
    
    # Get current directory
    project_dir=$(pwd)
    print_info "Current directory: $project_dir"
    
    # Detect project type
    project_type=$(detect_project_type "$project_dir")
    print_info "Detected project type: $project_type"
    
    # Get service name
    service_name=$(get_service_name)
    
    # Find executable
    executable=$(find_executable "$project_type" "$project_dir" "$service_name")
    
    # If no executable found, ask user
    if [[ -z "$executable" ]] || [[ "$project_type" == "unknown" ]]; then
        echo
        print_warning "Could not auto-detect executable command."
        read -p "Enter the command to start your application: " executable
        if [[ -z "$executable" ]]; then
            print_error "Executable command is required!"
            exit 1
        fi
    fi
    
    print_success "Executable command: $executable"
    
    # Get additional configuration
    config=$(get_service_config "$project_type")
    IFS='|' read -r description run_user port env_vars <<< "$config"
    
    # Generate service file path
    service_file="/etc/systemd/system/${service_name}.service"
    
    # Show summary
    echo
    print_info "Service Configuration Summary:"
    echo "  Service name: $service_name"
    echo "  Description: $description"
    echo "  Project type: $project_type"
    echo "  Working directory: $project_dir"
    echo "  Executable: $executable"
    echo "  Run as user: $run_user"
    echo "  Port: $port"
    if [[ -n "$env_vars" ]]; then
        echo "  Environment: $env_vars"
    fi
    echo "  Service file: $service_file"
    
    echo
    read -p "Generate service file? (y/n): " confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_info "Service file generation cancelled."
        exit 0
    fi
    
    # Generate service file content
    service_content=$(generate_service_content "$service_name" "$project_dir" "$project_type" "$executable" "$description" "$run_user" "$port" "$env_vars")
    
    # Create service file
    echo
    print_info "Creating service file..."
    
    if ! echo "$service_content" | sudo tee "$service_file" > /dev/null; then
        print_error "Failed to create service file!"
        exit 1
    fi
    
    print_success "Service file created: $service_file"
    
    # Set proper permissions
    sudo chmod 644 "$service_file"
    
    # Reload systemd
    print_info "Reloading systemd daemon..."
    sudo systemctl daemon-reload
    
    print_success "Systemd daemon reloaded!"
    
    # Show next steps
    echo
    print_info "Next steps:"
    echo "  1. Enable service: sudo systemctl enable $service_name"
    echo "  2. Start service:  sudo systemctl start $service_name"
    echo "  3. Check status:   sudo systemctl status $service_name"
    echo "  4. View logs:      sudo journalctl -u $service_name -f"
    
    # Ask if user wants to enable and start the service
    echo
    read -p "Enable and start the service now? (y/n): " start_now
    
    if [[ "$start_now" =~ ^[Yy]$ ]]; then
        print_info "Enabling service..."
        sudo systemctl enable "$service_name"
        
        print_info "Starting service..."
        if sudo systemctl start "$service_name"; then
            print_success "Service started successfully!"
            
            # Show status
            echo
            print_info "Service status:"
            sudo systemctl status "$service_name" --no-pager -l
        else
            print_error "Failed to start service!"
            print_info "Check logs with: sudo journalctl -u $service_name"
        fi
    fi
    
    echo
    print_success "Service generator completed!"
}

# Check if running as root for systemd operations
if [[ $EUID -eq 0 ]]; then
    print_warning "Running as root. This is normal for systemd service creation."
fi

# Check if sudo is available
if ! command -v sudo &> /dev/null; then
    print_error "sudo is required but not available!"
    exit 1
fi

# Run main function
main "$@"
