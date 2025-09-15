#!/bin/bash

# Script to create various test scenarios for check-push.sh
# This creates different configurations and test cases

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEV_DIR="$(dirname "$SCRIPT_DIR")/work.test"
COPIES_DIR="$DEV_DIR/copies"

echo "Creating test scenarios..."

# Create post-deployment scripts for testing
create_post_script() {
    local repo_name=$1
    local branch=$2
    local script_path="$COPIES_DIR/${repo_name}.${branch}.post"
    
    cat > "$script_path" << EOF
#!/bin/bash
echo "Post-deployment script for $repo_name branch $branch"
echo "Timestamp: \$(date)"
echo "Working directory: \$(pwd)"
echo "Files in directory:"
ls -la
echo "Post-deployment completed for $repo_name.$branch"
EOF
    chmod +x "$script_path"
    echo "Created post script: $script_path"
}

# Create Docker restart files for testing
create_docker_script() {
    local repo_name=$1
    local branch=$2
    local docker_name="${repo_name}-${branch}"
    local docker_path="$COPIES_DIR/${repo_name}.${branch}.docker"
    
    echo "$docker_name" > "$docker_path"
    echo "Created docker file: $docker_path (container: $docker_name)"
}

# Create various test scenarios
echo "Creating post-deployment scripts..."
create_post_script "webapp" "main"
create_post_script "webapp" "dev"
create_post_script "api-service" "main"
create_post_script "api-service" "test"

echo "Creating Docker restart files..."
create_docker_script "webapp" "main"
create_docker_script "api-service" "main"

# Create special test files
echo "Creating special test files..."

# Create a .skipping file for a branch
mkdir -p "$COPIES_DIR/webapp.test"
touch "$COPIES_DIR/webapp.test/.skipping"
echo "Created .skipping file for webapp.test"

# Create a .debugging file for a branch
mkdir -p "$COPIES_DIR/api-service.dev"
touch "$COPIES_DIR/api-service.dev/.debugging"
echo "Created .debugging file for api-service.dev"

# Create a .no-cleanup file for a branch
mkdir -p "$COPIES_DIR/mobile-app.main"
touch "$COPIES_DIR/mobile-app.main/.no-cleanup"
echo "Created .no-cleanup file for mobile-app.main"

# Create a .trigger file for testing debug mode
mkdir -p "$COPIES_DIR/webapp.dev"
touch "$COPIES_DIR/webapp.dev/.trigger"
echo "Created .trigger file for webapp.dev"

echo ""
echo "Test scenarios created successfully!"
echo "Available test configurations:"
echo "- Post-deployment scripts for webapp and api-service"
echo "- Docker restart configurations"
echo "- .skipping file (webapp.test)"
echo "- .debugging file (api-service.dev)"
echo "- .no-cleanup file (mobile-app.main)"
echo "- .trigger file (webapp.dev)"
