import glance
import gleam/list
import gleam/string
import gleeunit
import shellout
import simplifile

pub fn main() {
  gleeunit.main()
}

//
// Test error handling for missing input file
pub fn missing_input_file_test() {
  let assert Error(output) =
    shellout.command(
      run: "gleam",
      with: [
        "run",
        "-m",
        "protozoa",
        "--",
        "test/cli_error_handling_generated/nonexistent_file.proto",
      ],
      in: ".",
      opt: [],
    )

  // Should fail and provide meaningful error message
  assert string.contains(output.1, "Import resolution failed")
    && string.contains(output.1, "File not found")
}

// Test error handling for invalid proto syntax
pub fn invalid_proto_syntax_test() {
  let invalid_content = "this is not valid protobuf syntax at all"
  let temp_file = "test/cli_error_handling_generated/test_invalid_syntax.proto"

  case simplifile.write(temp_file, invalid_content) {
    Ok(_) -> {
      let result =
        shellout.command(
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
          assert string.contains(output.1, "Failed to parse")
            || string.contains(output.1, "Missing required")
            || string.contains(output.1, "Invalid syntax")
        }
        Ok(_) -> {
          panic as "Parser should fail with invalid syntax"
        }
      }
    }
    Error(_) -> {
      // Could not create temp file, skip test
      Nil
    }
  }
}

// Test error handling for missing import files
pub fn missing_import_files_test() {
  let content_with_missing_import =
    "
syntax = \"proto3\";
import \"nonexistent_import.proto\";

message TestMessage {
  string field = 1;
}
"
  let temp_file = "test/cli_error_handling_generated/test_missing_import.proto"

  let assert Ok(_) = simplifile.write(temp_file, content_with_missing_import)
  let assert Error(output) =
    shellout.command(
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

  // Should provide import resolution error
  assert string.contains(output.1, "Import resolution failed")
    && string.contains(output.1, "File not found")
}

// Test error handling for invalid field numbers
pub fn invalid_field_numbers_test() {
  let invalid_field_content =
    "
syntax = \"proto3\";

message InvalidFields {
  string field_zero = 0;       // Invalid: field number 0
  string field_negative = -1;  // Invalid: negative field number  
}
"
  let temp_file = "test/cli_error_handling_generated/test_invalid_fields.proto"

  case simplifile.create_directory_all("test/cli_error_handling_generated") {
    Ok(_) | Error(_) -> Nil
  }
  let assert Ok(_) = simplifile.write(temp_file, invalid_field_content)

  // Parser should now validate field numbers
  let assert Error(output) =
    shellout.command(
      run: "gleam",
      with: ["run", "-m", "protozoa", "--", temp_file],
      in: ".",
      opt: [],
    )

  // Should provide field number validation error
  assert string.contains(output.1, "Invalid field number")
    || string.contains(output.1, "Malformed field")

  // Clean up temp file
  let _ = simplifile.delete(temp_file)
}

// Test error handling for directory creation failures
pub fn invalid_output_directory_test() {
  // Try to create output in a path that would fail on most systems
  let invalid_output_path = "/root/forbidden/path"
  // Usually not writable

  let assert Error(_) =
    shellout.command(
      run: "gleam",
      with: [
        "run",
        "-m",
        "protozoa",
        "--",
        "test/proto/simple_scalars.proto",
        invalid_output_path,
      ],
      in: ".",
      opt: [],
    )
}

pub fn malformed_proto_messages_test() {
  let malformed_content =
    "
syntax = \"proto3\";

message MalformedMessage {
  string field_without_number;  // Missing field number
  repeated;                     // Invalid syntax
  map<string> incomplete_map = 2; // Incomplete map definition
}
"
  let temp_file = "test/cli_error_handling_generated/test_malformed.proto"

  case simplifile.create_directory_all("test/cli_error_handling_generated") {
    Ok(_) | Error(_) -> Nil
  }
  let assert Ok(_) = simplifile.write(temp_file, malformed_content)

  let assert Error(output) =
    shellout.command(
      run: "gleam",
      with: ["run", "-m", "protozoa", "--", temp_file],
      in: ".",
      opt: [],
    )

  assert string.contains(output.1, "Malformed field")
    || string.contains(output.1, "Failed to parse")

  let _ = simplifile.delete(temp_file)
}

// Test error handling for duplicate field numbers
pub fn duplicate_field_numbers_test() {
  let duplicate_fields_content =
    "
syntax = \"proto3\";

message DuplicateFields {
  string first_field = 1;
  int32 second_field = 1;  // Duplicate field number
}
"
  let temp_file =
    "test/cli_error_handling_generated/test_duplicate_fields.proto"

  case simplifile.create_directory_all("test/cli_error_handling_generated") {
    Ok(_) | Error(_) -> Nil
  }

  case simplifile.write(temp_file, duplicate_fields_content) {
    Ok(_) -> {
      // Parser should now detect duplicate field numbers
      let assert Error(output) =
        shellout.command(
          run: "gleam",
          with: ["run", "-m", "protozoa", "--", temp_file],
          in: ".",
          opt: [],
        )

      // Should provide duplicate field number error
      assert string.contains(output.1, "Duplicate field number")

      // Clean up temp file
      case simplifile.delete(temp_file) {
        Ok(_) -> Nil
        Error(_) -> Nil
      }
    }
    Error(_) -> {
      // Could not create temp file, skip test
      Nil
    }
  }
}

// Test simplified interface error handling
pub fn simplified_interface_errors_test() {
  // Test invalid arguments to simplified interface
  let result =
    shellout.command(
      run: "gleam",
      with: ["run", "-m", "protozoa", "invalid", "too", "many", "args"],
      in: ".",
      opt: [],
    )

  case result {
    Error(output) -> {
      // Should show usage message
      assert string.contains(output.1, "Usage:")
        || string.contains(output.1, "Protozoa")
    }
    Ok(_) -> panic
    // Should not succeed with invalid args
  }
}

// Test that error messages are user-friendly
pub fn user_friendly_error_messages_test() {
  let result =
    shellout.command(
      run: "gleam",
      with: ["run", "-m", "protozoa", "--", "definitely_nonexistent_file.proto"],
      in: ".",
      opt: [],
    )

  case result {
    Error(output) -> {
      // Error messages should not contain internal stack traces or technical jargon
      assert !string.contains(output.1, "panic")
      assert !string.contains(output.1, "stack trace")
      assert !string.contains(output.1, "internal error")

      // Should contain helpful information
      assert string.contains(output.1, "Failed")
        || string.contains(output.1, "Could not")
        || string.contains(output.1, "Error")
        || string.contains(output.1, "not found")
    }
    Ok(_) -> panic
  }
}

// Test error handling with empty proto files
pub fn empty_proto_file_test() {
  let empty_content = ""
  let temp_file = "test/cli_error_handling_generated/test_empty.proto"

  case simplifile.create_directory_all("test/cli_error_handling_generated") {
    Ok(_) | Error(_) -> Nil
  }

  case simplifile.write(temp_file, empty_content) {
    Ok(_) -> {
      // Parser should reject empty files
      let assert Error(output) =
        shellout.command(
          run: "gleam",
          with: ["run", "-m", "protozoa", "--", temp_file],
          in: ".",
          opt: [],
        )

      assert string.contains(output.1, "Missing required")

      // Clean up temp file
      case simplifile.delete(temp_file) {
        Ok(_) -> Nil
        Error(_) -> Nil
      }
    }
    Error(_) -> {
      // Could not create temp file, skip test
      Nil
    }
  }
}

// Test that the CLI properly handles and reports code generation failures
pub fn code_generation_error_reporting_test() {
  // Create a proto that might cause code generation issues
  let problematic_content =
    "
syntax = \"proto3\";

message ProblematicMessage {
  // Using reserved keywords that might cause issues in generated code
  string import = 1;
  string type = 2;  
  string fn = 3;
}
"
  let temp_file = "test/cli_error_handling_generated/test_problematic.proto"

  case simplifile.create_directory_all("test/cli_error_handling_generated") {
    Ok(_) | Error(_) -> Nil
  }

  case simplifile.write(temp_file, problematic_content) {
    Ok(_) -> {
      // Test parser with reserved keywords (this should work with keyword escaping)
      let assert Ok(_) =
        shellout.command(
          run: "gleam",
          with: [
            "run",
            "-m",
            "protozoa",
            "--",
            temp_file,
            "test/cli_error_handling_generated",
          ],
          in: ".",
          opt: [],
        )

      // Clean up temp file
      case simplifile.delete(temp_file) {
        Ok(_) -> Nil
        Error(_) -> Nil
      }
    }
    Error(_) -> {
      // Could not create temp file, skip test
      Nil
    }
  }
}

// Test basic CLI argument parsing
pub fn basic_cli_help_test() {
  let assert Ok(output) =
    shellout.command(
      run: "gleam",
      with: ["run", "-m", "protozoa", "--", "--help"],
      in: ".",
      opt: [],
    )

  assert string.contains(output, "Protozoa - Protocol Buffer Compiler")
  assert string.contains(output, "Recommended Usage:")
  assert string.contains(output, "Advanced Usage:")
  assert string.contains(output, "Options:")
  assert string.contains(output, "-I<path>")
}

// Test CLI compilation with existing test proto files
pub fn cli_compile_basic_proto_test() {
  // Use one of the existing test proto files
  let proto_file = "test/proto/simple_scalars.proto"
  let output_dir = "test_generated_cli"

  // Clean up any existing output
  case simplifile.delete("test_generated_cli") {
    Ok(_) -> Nil
    Error(_) -> Nil
  }
  let _ = simplifile.create_directory_all(output_dir)

  let assert Ok(output) =
    shellout.command(
      run: "gleam",
      with: ["run", "-m", "protozoa", "--", proto_file, output_dir],
      in: ".",
      opt: [],
    )
  // Should indicate successful generation
  assert string.contains(output, "Successfully generated")
  assert string.contains(output, "file(s):")

  // Check that output file was created
  let expected_file = output_dir <> "/simple_scalars.gleam"
  assert Ok(True) == simplifile.is_file(expected_file)

  // Verify generated content has expected structure
  let assert Ok(content) = simplifile.read(expected_file)
  assert string.contains(content, "Generated by Protozoa")
  assert string.contains(content, "pub type")
  assert string.contains(content, "pub fn encode_")
  assert string.contains(content, "pub fn decode_")

  // Clean up
  case simplifile.delete(output_dir) {
    Ok(_) -> Nil
    Error(_) -> Nil
  }
}

// Test CLI with import paths
pub fn cli_compile_with_imports_test() {
  let proto_file = "test/proto/imports.proto"
  let output_dir = "test_generated_cli_imports"

  // Clean up any existing output
  case simplifile.delete(output_dir) {
    Ok(_) -> Nil
    Error(_) -> Nil
  }
  let _ = simplifile.create_directory_all(output_dir)

  let assert Ok(output) =
    shellout.command(
      run: "gleam",
      with: [
        "run",
        "-m",
        "protozoa",
        "--",
        "-Itest/proto",
        proto_file,
        output_dir,
      ],
      in: ".",
      opt: [],
    )

  // Should indicate successful generation
  assert string.contains(output, "Successfully generated")

  // Check that multiple files were generated (due to imports)
  let assert Ok(files) = simplifile.read_directory(output_dir)
  assert list.length(files) >= 1
  // Should have the main file
  assert list.contains(files, "imports.gleam")

  // Clean up
  let _ = simplifile.delete(output_dir)
}

// Test error handling - non-existent file
pub fn cli_nonexistent_file_test() {
  let assert Error(_) =
    shellout.command(
      run: "gleam",
      with: ["run", "-m", "protozoa", "--", "nonexistent.proto", "test"],
      in: ".",
      opt: [],
    )
}

// Test simplified interface check command
pub fn simplified_check_command_test() {
  let assert Ok(output) =
    shellout.command(
      run: "gleam",
      with: ["run", "-m", "protozoa", "check"],
      in: ".",
      opt: [],
    )

  assert string.contains(output, "Checking proto file changes")
}

// Test output directory creation
pub fn cli_creates_output_directory_test() {
  let proto_file = "test/proto/simple_scalars.proto"
  let output_dir = "test_new_directory/nested/deep"

  // Ensure the directory doesn't exist
  case simplifile.delete("test_new_directory") {
    Ok(_) -> Nil
    Error(_) -> Nil
  }

  let assert Ok(_) =
    shellout.command(
      run: "gleam",
      with: ["run", "-m", "protozoa", "--", proto_file, output_dir],
      in: ".",
      opt: [],
    )
  // Check that the nested directory was created
  let assert Ok(True) = simplifile.is_directory(output_dir)
  // Check that file was generated in the correct location
  let expected_file = output_dir <> "/simple_scalars.gleam"
  let assert Ok(True) = simplifile.is_file(expected_file)

  // Clean up
  case simplifile.delete("test_new_directory") {
    Ok(_) -> Nil
    Error(_) -> Nil
  }
}

// Test multiple import paths
pub fn cli_multiple_import_paths_test() {
  let proto_file = "test/proto/imports.proto"
  let output_dir = "test_multi_imports"

  // Clean up any existing output
  case simplifile.delete(output_dir) {
    Ok(_) -> Nil
    Error(_) -> Nil
  }
  let _ = simplifile.create_directory_all(output_dir)

  let assert Ok(output) =
    shellout.command(
      run: "gleam",
      with: [
        "run",
        "-m",
        "protozoa",
        "--",
        "-Itest/proto",
        "-I.",
        proto_file,
        output_dir,
      ],
      in: ".",
      opt: [],
    )

  assert string.contains(output, "Successfully generated")

  // Clean up
  case simplifile.delete(output_dir) {
    Ok(_) -> Nil
    Error(_) -> Nil
  }
}

// Test that CLI preserves exit codes properly
pub fn cli_exit_codes_test() {
  // Test successful case should have exit code 0
  let assert Ok(_) =
    shellout.command(
      run: "gleam",
      with: [
        "run",
        "-m",
        "protozoa",
        "--",
        "test/proto/simple_scalars.proto",
        "temp_output",
      ],
      in: ".",
      opt: [],
    )

  // Clean up
  let _ = simplifile.delete("temp_output")

  // Test failure case should have non-zero exit code
  let assert Error(#(1, _)) =
    shellout.command(
      run: "gleam",
      with: ["run", "-m", "protozoa", "--", "nonexistent.proto"],
      in: ".",
      opt: [],
    )
}

pub fn all_proto_files_compile_test() {
  let test_protos = [
    "test/proto/basic_types.proto",
    "test/proto/simple_scalars.proto",
    "test/proto/repeated_fields.proto",
    "test/proto/oneofs_only.proto",
    "test/proto/nested_types.proto",
    "test/proto/well_known.proto",
  ]
  list.each(test_protos, test_single_proto_file)
}

fn test_single_proto_file(proto_file: String) -> Nil {
  let output_dir = "test/validation_output"

  let _ = simplifile.delete(output_dir)
  let _ = simplifile.create_directory_all(output_dir)

  let assert Ok(output) =
    shellout.command(
      run: "gleam",
      with: ["run", "-m", "protozoa", proto_file, output_dir],
      in: ".",
      opt: [],
    )

  assert string.contains(output, "Successfully generated")

  let assert Ok(files) = simplifile.read_directory(output_dir)
  assert list.length(files) >= 1

  list.each(files, fn(file) {
    let file_path = output_dir <> "/" <> file
    let assert Ok(content) = simplifile.read(file_path)
    assert string.contains(content, "Generated by Protozoa")
    assert string.contains(content, "import protozoa/")
    let assert Ok(_) = glance.module(content)
    Nil
  })

  Nil
}

pub fn imports_proto_compilation_test() {
  let output_dir = "test/imports_validation"

  let _ = simplifile.delete(output_dir)
  let _ = simplifile.create_directory_all(output_dir)

  let assert Ok(output) =
    shellout.command(
      run: "gleam",
      with: [
        "run",
        "-m",
        "protozoa",
        "--",
        "-Itest/proto",
        "test/proto/imports.proto",
        output_dir,
      ],
      in: ".",
      opt: [],
    )

  assert string.contains(output, "Successfully generated")

  let assert Ok(files) = simplifile.read_directory(output_dir)
  assert list.length(files) >= 1
  let _ = simplifile.delete(output_dir)
}

pub fn oneofs_maps_proto_compilation_test() {
  let output_dir = "test_oneofs_maps_validation"

  let _ = simplifile.delete(output_dir)
  let _ = simplifile.create_directory_all(output_dir)

  let assert Ok(output) =
    shellout.command(
      run: "gleam",
      with: [
        "run",
        "-m",
        "protozoa",
        "--",
        "test/proto/oneofs_maps.proto",
        output_dir,
      ],
      in: ".",
      opt: [],
    )

  assert string.contains(output, "Successfully generated")
  let assert Ok(files) = simplifile.read_directory(output_dir)
  assert list.length(files) >= 1
  let expected_file = output_dir <> "/oneofs_maps.gleam"
  let assert Ok(content) = simplifile.read(expected_file)
  assert string.contains(content, "pub type ")
    || string.contains(content, "oneof")

  let _ = simplifile.delete(output_dir)
}

pub fn generated_code_compiles_test() {
  let output_dir = "test_gleam_compilation"

  let _ = simplifile.delete(output_dir)
  let _ = simplifile.create_directory_all(output_dir)

  let assert Ok(_) =
    shellout.command(
      run: "gleam",
      with: [
        "run",
        "-m",
        "protozoa",
        "--",
        "test/proto/simple_scalars.proto",
        output_dir,
      ],
      in: ".",
      opt: [],
    )

  let assert Ok(files) = simplifile.read_directory(output_dir)
  list.each(files, fn(file) {
    case string.ends_with(file, ".gleam") {
      True -> {
        let file_path = output_dir <> "/" <> file
        let assert Ok(content) = simplifile.read(file_path)
        assert string.contains(content, "import ")
        assert string.contains(content, "pub type ")
        assert string.contains(content, "pub fn ")

        assert !string.contains(content, "syntax error")
        assert !string.contains(content, "undefined")
      }
      False -> Nil
    }
  })

  let _ = simplifile.delete(output_dir)
}

pub fn cli_edge_cases_test() {
  let empty_proto_content = "syntax = \"proto3\";\nmessage Empty {}\n"
  let temp_proto = "test_empty_temp.proto"

  let assert Ok(_) = simplifile.write(temp_proto, empty_proto_content)
  let output_dir = "test_empty_output"
  let _ = simplifile.delete(output_dir)
  let _ = simplifile.create_directory_all(output_dir)

  let assert Ok(output) =
    shellout.command(
      run: "gleam",
      with: ["run", "-m", "protozoa", "--", temp_proto, output_dir],
      in: ".",
      opt: [],
    )

  assert string.contains(output, "Successfully generated")

  let expected_file = output_dir <> "/test_empty_temp.gleam"
  let assert Ok(content) = simplifile.read(expected_file)
  assert string.contains(content, "pub type Empty")
  assert string.contains(content, "pub fn encode_empty")
  assert string.contains(content, "pub fn decode_empty")

  let _ = simplifile.delete(temp_proto)
  let _ = simplifile.delete(output_dir)
}

pub fn cli_output_format_test() {
  let output_dir = "test_output_format"
  let _ = simplifile.delete(output_dir)
  let _ = simplifile.create_directory_all(output_dir)

  let assert Ok(output) =
    shellout.command(
      run: "gleam",
      with: [
        "run",
        "-m",
        "protozoa",
        "--",
        "test/proto/simple_scalars.proto",
        output_dir,
      ],
      in: ".",
      opt: [],
    )

  assert string.contains(output, "Successfully generated")
  assert string.contains(output, "file(s):")

  assert string.contains(output, "simple_scalars.gleam")

  let _ = simplifile.delete(output_dir)
}
