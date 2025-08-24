#!/bin/bash
# Main test runner script that handles setup, testing, and cleanup

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== Gloto Test Runner ===${NC}"

# Step 1: Prepare test env
echo -e "${YELLOW}Preparing test env...${NC}"
rm -rf test/generated_outputs
mkdir -p test/generated_outputs

# Step 2: Run tests
echo -e "${YELLOW}Running tests...${NC}"
gleam test "$@"
TEST_RESULT=$?

echo -e "${YELLOW}Checking generated files are correct...${NC}"
gleam check

echo -e "${YELLOW}Delete generated files afterwards...${NC}"
rm -rf test/generated_outputs
mkdir -p test/generated_outputs

if [ $TEST_RESULT -eq 0 ]; then
  echo -e "${GREEN}✓ All tests passed!${NC}"
else
  echo -e "${RED}✗ Some tests failed${NC}"
fi

exit $TEST_RESULT
