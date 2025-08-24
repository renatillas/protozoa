#!/bin/bash
# Script to generate test proto files before running tests
# This ensures all required modules exist at compile time

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Setting up test environment...${NC}"

# Create test generation directory
TEST_GEN_DIR="test/generated"
mkdir -p "$TEST_GEN_DIR"

# Function to generate a proto file
generate_proto() {
  local name=$1
  local content=$2
  local proto_file="$TEST_GEN_DIR/${name}.proto"
  local gleam_file="$TEST_GEN_DIR/${name}_pb.gleam"

  echo -e "${GREEN}Generating ${name}...${NC}"

  # Write proto content
  echo "$content" >"$proto_file"

  # Remove existing generated file if it exists
  rm -f "$gleam_file"

  # Generate Gleam code
  gleam run -m gloto -- generate "$proto_file" "$gleam_file" 2>/dev/null || {
    echo -e "${RED}Failed to generate ${name}_pb.gleam${NC}"
    return 1
  }
}

# Generate test proto files
# These are used by various tests but kept separate from src/

# 1. Simple test message
generate_proto "test_simple" '
syntax = "proto3";

message SimpleTest {
  string name = 1;
  int32 value = 2;
}
'

# 2. Complex nested message
generate_proto "test_nested" '
syntax = "proto3";

message OuterTest {
  string id = 1;
  InnerTest inner = 2;
  repeated InnerTest items = 3;
}

message InnerTest {
  int32 num = 1;
  string text = 2;
}
'

# 3. Test with all field types
generate_proto "test_types" '
syntax = "proto3";

message TypesTest {
  double double_val = 1;
  float float_val = 2;
  int32 int32_val = 3;
  int64 int64_val = 4;
  uint32 uint32_val = 5;
  uint64 uint64_val = 6;
  sint32 sint32_val = 7;
  sint64 sint64_val = 8;
  fixed32 fixed32_val = 9;
  fixed64 fixed64_val = 10;
  sfixed32 sfixed32_val = 11;
  sfixed64 sfixed64_val = 12;
  bool bool_val = 13;
  string string_val = 14;
  bytes bytes_val = 15;
}
'

# 4. Test with oneof
generate_proto "test_oneof" '
syntax = "proto3";

message OneofTest {
  string id = 1;
  
  oneof test_oneof {
    string name = 2;
    int32 number = 3;
    SubMessage sub = 4;
  }
}

message SubMessage {
  string value = 1;
}
'

echo -e "${GREEN}Test setup complete!${NC}"
echo -e "${YELLOW}Generated test files are in: $TEST_GEN_DIR${NC}"
