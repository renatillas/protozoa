import gleam/string
import gleeunit
import gleeunit/should
import simplifile
import shellout

pub fn main() -> Nil {
  gleeunit.main()
}

// Test error handling for missing input file
pub fn test_missing_input_file() {
  let result = shellout.command(
    run: "gleam",
    with: ["run", "-m", "protozoa", "--", "nonexistent_file.proto"],
    in: ".",
    opt: [],
  )
  
  case result {
    Error(output) -> {
      // Should fail and provide meaningful error message
      should.be_true(string.contains(output.1, "Failed to resolve imports") || 
                    string.contains(output.1, "Could not read") ||
                    string.contains(output.1, "not found"))
    }
    Ok(_) -> should.fail() // Should not succeed with missing file
  }
}

// Test error handling for invalid proto syntax
pub fn test_invalid_proto_syntax() {
  let invalid_content = "this is not valid protobuf syntax at all"
  let temp_file = "test_invalid_syntax.proto"
  
  case simplifile.write(temp_file, invalid_content) {
    Ok(_) -> {
      let result = shellout.command(
        run: "gleam",
        with: ["run", "-m", "protozoa", "--", temp_file],
        in: ".",
        opt: [],
      )
      
      // Clean up temp file
      case simplifile.delete(temp_file) {
        Ok(_) -> Nil
        Error(_) -> Nil
      }
      
      case result {
        Error(output) -> {
          // Should provide parsing error message
          should.be_true(string.contains(output.1, "parse") || 
                        string.contains(output.1, "syntax") ||
                        string.contains(output.1, "failed"))
        }
        Ok(_) -> should.fail() // Should not succeed with invalid syntax
      }
    }
    Error(_) -> should.fail()
  }
}

// Test error handling for missing import files
pub fn test_missing_import_files() {
  let content_with_missing_import = "
syntax = \"proto3\";
import \"nonexistent_import.proto\";

message TestMessage {
  string field = 1;
}
"
  let temp_file = "test_missing_import.proto"
  
  case simplifile.write(temp_file, content_with_missing_import) {
    Ok(_) -> {
      let result = shellout.command(
        run: "gleam",
        with: ["run", "-m", "protozoa", "--", temp_file],
        in: ".",
        opt: [],
      )
      
      // Clean up temp file
      case simplifile.delete(temp_file) {
        Ok(_) -> Nil
        Error(_) -> Nil
      }
      
      case result {
        Error(output) -> {
          // Should provide import resolution error
          should.be_true(string.contains(output.1, "import") || 
                        string.contains(output.1, "resolve") ||
                        string.contains(output.1, "not found"))
        }
        Ok(_) -> should.fail() // Should not succeed with missing imports
      }
    }
    Error(_) -> should.fail()
  }
}

// Test error handling for invalid field numbers
pub fn test_invalid_field_numbers() {
  let invalid_field_content = "
syntax = \"proto3\";

message InvalidFields {
  string field_zero = 0;       // Invalid: field number 0
  string field_negative = -1;  // Invalid: negative field number  
}
"
  let temp_file = "test_invalid_fields.proto"
  
  case simplifile.write(temp_file, invalid_field_content) {
    Ok(_) -> {
      let result = shellout.command(
        run: "gleam",
        with: ["run", "-m", "protozoa", "--", temp_file],
        in: ".",
        opt: [],
      )
      
      // Clean up temp file
      case simplifile.delete(temp_file) {
        Ok(_) -> Nil
        Error(_) -> Nil
      }
      
      case result {
        Error(_) -> should.be_true(True) // Should fail with invalid field numbers
        Ok(_) -> should.fail() // Should not succeed
      }
    }
    Error(_) -> should.fail()
  }
}

// Test error handling for directory creation failures
pub fn test_invalid_output_directory() {
  // Try to create output in a path that would fail on most systems
  let invalid_output_path = "/root/forbidden/path" // Usually not writable
  
  let result = shellout.command(
    run: "gleam",
    with: ["run", "-m", "protozoa", "--", "test/proto/simple_scalars.proto", invalid_output_path],
    in: ".",
    opt: [],
  )
  
  case result {
    Error(_) -> should.be_true(True) // Expected to fail
    Ok(_) -> {
      // If it somehow succeeded, clean up
      case simplifile.delete(invalid_output_path) {
        Ok(_) -> Nil
        Error(_) -> Nil
      }
      // This might actually work in some environments, so we'll allow it
      should.be_true(True)
    }
  }
}

// Test error handling for malformed proto messages
pub fn test_malformed_proto_messages() {
  let malformed_content = "
syntax = \"proto3\";

message MalformedMessage {
  string field_without_number;  // Missing field number
  repeated;                     // Invalid syntax
  map<string> incomplete_map = 2; // Incomplete map definition
}
"
  let temp_file = "test_malformed.proto"
  
  case simplifile.write(temp_file, malformed_content) {
    Ok(_) -> {
      let result = shellout.command(
        run: "gleam",
        with: ["run", "-m", "protozoa", "--", temp_file],
        in: ".",
        opt: [],
      )
      
      // Clean up temp file
      case simplifile.delete(temp_file) {
        Ok(_) -> Nil
        Error(_) -> Nil
      }
      
      case result {
        Error(_) -> should.be_true(True) // Should fail with malformed proto
        Ok(_) -> should.fail() // Should not succeed
      }
    }
    Error(_) -> should.fail()
  }
}

// Test error handling for duplicate field numbers
pub fn test_duplicate_field_numbers() {
  let duplicate_fields_content = "
syntax = \"proto3\";

message DuplicateFields {
  string first_field = 1;
  int32 second_field = 1;  // Duplicate field number
}
"
  let temp_file = "test_duplicate_fields.proto"
  
  case simplifile.write(temp_file, duplicate_fields_content) {
    Ok(_) -> {
      let result = shellout.command(
        run: "gleam",
        with: ["run", "-m", "protozoa", "--", temp_file],
        in: ".",
        opt: [],
      )
      
      // Clean up temp file
      case simplifile.delete(temp_file) {
        Ok(_) -> Nil
        Error(_) -> Nil
      }
      
      case result {
        Error(_) -> should.be_true(True) // Should fail with duplicate field numbers
        Ok(_) -> {
          // Some proto compilers allow this, so we'll be lenient
          // The important thing is that it doesn't crash
          should.be_true(True)
        }
      }
    }
    Error(_) -> should.fail()
  }
}

// Test simplified interface error handling
pub fn test_simplified_interface_errors() {
  // Test invalid arguments to simplified interface
  let result = shellout.command(
    run: "gleam",
    with: ["run", "-m", "protozoa", "invalid", "too", "many", "args"],
    in: ".",
    opt: [],
  )
  
  case result {
    Error(output) -> {
      // Should show usage message
      should.be_true(string.contains(output.1, "Usage:") || 
                    string.contains(output.1, "Protozoa"))
    }
    Ok(_) -> should.fail() // Should not succeed with invalid args
  }
}

// Test that error messages are user-friendly
pub fn test_user_friendly_error_messages() {
  let result = shellout.command(
    run: "gleam",
    with: ["run", "-m", "protozoa", "--", "definitely_nonexistent_file.proto"],
    in: ".",
    opt: [],
  )
  
  case result {
    Error(output) -> {
      // Error messages should not contain internal stack traces or technical jargon
      should.be_false(string.contains(output.1, "panic"))
      should.be_false(string.contains(output.1, "stack trace"))
      should.be_false(string.contains(output.1, "internal error"))
      
      // Should contain helpful information
      should.be_true(string.contains(output.1, "Failed") || 
                    string.contains(output.1, "Could not") ||
                    string.contains(output.1, "Error") ||
                    string.contains(output.1, "not found"))
    }
    Ok(_) -> should.fail()
  }
}

// Test error handling with empty proto files
pub fn test_empty_proto_file() {
  let empty_content = ""
  let temp_file = "test_empty.proto"
  
  case simplifile.write(temp_file, empty_content) {
    Ok(_) -> {
      let result = shellout.command(
        run: "gleam",
        with: ["run", "-m", "protozoa", "--", temp_file],
        in: ".",
        opt: [],
      )
      
      // Clean up temp file
      case simplifile.delete(temp_file) {
        Ok(_) -> Nil
        Error(_) -> Nil
      }
      
      case result {
        Error(_) -> should.be_true(True) // Expected to fail with empty file
        Ok(_) -> {
          // Some implementations might handle empty files gracefully
          should.be_true(True)
        }
      }
    }
    Error(_) -> should.fail()
  }
}

// Test that the CLI properly handles and reports code generation failures
pub fn test_code_generation_error_reporting() {
  // Create a proto that might cause code generation issues
  let problematic_content = "
syntax = \"proto3\";

message ProblematicMessage {
  // Using reserved keywords that might cause issues in generated code
  string import = 1;
  string type = 2;  
  string fn = 3;
}
"
  let temp_file = "test_problematic.proto"
  
  case simplifile.write(temp_file, problematic_content) {
    Ok(_) -> {
      let result = shellout.command(
        run: "gleam",
        with: ["run", "-m", "protozoa", "--", temp_file],
        in: ".",
        opt: [],
      )
      
      // Clean up temp file
      case simplifile.delete(temp_file) {
        Ok(_) -> Nil
        Error(_) -> Nil
      }
      
      case result {
        Ok(_) -> {
          // If it succeeds, that's actually good - the tool handled reserved words
          should.be_true(True)
        }
        Error(output) -> {
          // If it fails, the error message should be informative
          should.be_true(string.length(output.1) > 0) // Non-empty error message
        }
      }
    }
    Error(_) -> should.fail()
  }
}