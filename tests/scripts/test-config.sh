#!/bin/bash

# Test configuration for check-push.sh
# This file contains environment variables and settings for testing

# Override default paths for testing
export DIR_REPOS="./work.test/git_repos"
export DIR_COPIES="./work.test/copies"
export CI_LOCK="./work.test/.ci-lock"

# Test settings
export VERB=2                    # Verbose output (0=silent, 1=normal, 2=verbose)
export TIMEOUT=30                # Shorter timeout for testing
export SLEEP_TIME=""             # Run once and exit (empty = no daemon mode)

# Branch whitelist for testing
export BR_WHITELIST="main master dev test alpha"

# Test mode flag
export TEST_MODE=1

echo "Test configuration loaded:"
echo "  DIR_REPOS: $DIR_REPOS"
echo "  DIR_COPIES: $DIR_COPIES"
echo "  CI_LOCK: $CI_LOCK"
echo "  VERB: $VERB"
echo "  TIMEOUT: $TIMEOUT"
echo "  SLEEP_TIME: $SLEEP_TIME"
echo "  BR_WHITELIST: $BR_WHITELIST"
echo "  TEST_MODE: $TEST_MODE"
