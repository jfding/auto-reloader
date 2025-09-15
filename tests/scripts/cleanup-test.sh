#!/bin/bash

# Cleanup script for test environment
# This script removes all test data and resets the environment

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEV_DIR="$(dirname "$SCRIPT_DIR")/work.test"

echo "Cleaning up test environment..."

# Remove test directories
if [[ -d "$DEV_DIR" ]]; then
    echo "Removing git_repos directory..."
    rm -rf "$DEV_DIR"
fi

echo "Test environment cleaned up successfully!"
echo "You can now run setup-test-repos.sh to recreate the test environment."
