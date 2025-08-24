#!/bin/bash
# Main test runner script that handles setup, testing, and cleanup

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== Gloto Test Runner ===${NC}"

# Step 1: Setup test environment
echo -e "${YELLOW}Setting up test environment...${NC}"
./scripts/setup_tests.sh

# Step 2: Run tests
echo -e "${YELLOW}Running tests...${NC}"
gleam test "$@"
TEST_RESULT=$?

# Step 3: Cleanup
echo -e "${YELLOW}Cleaning up test files...${NC}"
rm -rf test/generated

if [ $TEST_RESULT -eq 0 ]; then
  echo -e "${GREEN}✓ All tests passed!${NC}"
else
  echo -e "${RED}✗ Some tests failed${NC}"
fi

exit $TEST_RESULT

