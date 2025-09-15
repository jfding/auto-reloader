#!/bin/bash

# Test script for check-push.sh
# This script runs the check-push.sh script with test configuration

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEV_DIR="$(dirname "$SCRIPT_DIR")/work.test"
CHECK_PUSH_SCRIPT="$DEV_DIR/../../src/check-push.sh"

# Test configuration
export DIR_REPOS="$DEV_DIR/git_repos"
export DIR_COPIES="$DEV_DIR/copies"
export CI_LOCK="$DEV_DIR/.ci-lock"
export VERB=2  # Verbose output
export TIMEOUT=30  # Shorter timeout for testing
export SLEEP_TIME=""  # Run once and exit

echo "=== Testing check-push.sh ==="
echo "Git repos directory: $DIR_REPOS"
echo "Copies directory: $DIR_COPIES"
echo "CI lock file: $CI_LOCK"
echo ""

# Check if check-push.sh exists
if [[ ! -f "$CHECK_PUSH_SCRIPT" ]]; then
    echo "Error: check-push.sh not found at $CHECK_PUSH_SCRIPT"
    exit 1
fi

# Check if test repositories exist
if [[ ! -d "$DIR_REPOS" ]] || [[ -z "$(ls -A "$DIR_REPOS" 2>/dev/null)" ]]; then
    echo "Error: No test repositories found in $DIR_REPOS"
    echo "Please run setup-test-repos.sh first"
    exit 1
fi

# Clean up any existing lock file
rm -f "$CI_LOCK"

# Make check-push.sh executable
chmod +x "$CHECK_PUSH_SCRIPT"

echo "Running check-push.sh..."
echo ""

# Run the script
bash "$CHECK_PUSH_SCRIPT"

echo ""
echo "=== Test completed ==="
echo "Check the copies directory for results:"
ls -la "$DIR_COPIES"
