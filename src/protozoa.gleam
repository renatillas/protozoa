//// Protozoa - Protocol Buffer Compiler for Gleam
////
//// Protozoa is a complete Protocol Buffer (protobuf) compiler that generates Gleam code from .proto files.
//// It provides a production-ready toolchain for working with Protocol Buffers in Gleam applications,
//// supporting the full proto3 syntax including imports, nested messages, enums, oneofs, and maps.
////
//// ## Main Features
////
//// - **Complete proto3 support**: Messages, enums, nested types, oneofs, maps, and repeated fields
//// - **Import resolution**: Handles import statements with configurable search paths
//// - **All field types**: Full support including Fixed32, Fixed64, SFixed32, SFixed64
//// - **Type-safe codegen**: Generates idiomatic Gleam code with proper type safety
//// - **Project integration**: Automatic project structure detection and CLI tools
//// - **Generated file safety**: Headers for safe deletion and regeneration
////
//// ## Recommended Usage
////
//// The recommended way to use Protozoa is with the integrated CLI:
////
//// ```bash
//// # Generate all proto files in your project (recommended)
//// gleam run -m protozoa
////
//// # Check if proto files need regeneration (useful for CI)
//// gleam run -m protozoa check
//// ```
////
//// This automatically detects your project structure from `gleam.toml`, finds proto files
//// in `src/[appname]/proto/` directories, and generates output files with safety headers.
////
//// ## Manual CLI Usage
////
//// For advanced usage or custom project structures:
////
//// ```bash
//// # Auto-detect proto files in project
//// gleam run
////
//// # Compile specific proto files
//// gleam run -m protozoa message.proto ./output
////
//// # Use import search paths for dependencies
//// gleam run -m protozoa -I./protos -I./vendor message.proto ./src
////
//// # Check if files need regeneration
//// gleam run -m protozoa check
//// ```
////

import argv
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string
import protozoa/codegen
import protozoa/internals/import_resolver
import protozoa/parser
import simplifile
import snag

/// Main entry point for the Protozoa CLI tool.
/// 
/// Parses command line arguments and compiles Protocol Buffer files to Gleam code.
/// Supports import resolution with configurable search paths and handles all proto3 features.
/// 
/// ## Command Line Arguments
/// 
/// - `input.proto` (required): The Protocol Buffer file to compile
/// - `output_dir` (optional): Directory for generated files (defaults to current directory)
/// - `-I<path>` or `--proto_path=<path>`: Add directories to the import search path
/// - `-h` or `--help`: Show help message
/// 
/// ## Examples
/// 
/// ```bash
/// # Basic compilation
/// gleam run -m protozoa user.proto
/// 
/// # With output directory
/// gleam run -m protozoa user.proto ./generated
/// 
/// # With import paths
/// gleam run -m protozoa -I./common -I./vendor user.proto ./src
/// ```
/// 
/// ## Exit Behavior
/// 
/// - Exits successfully (0) when compilation completes without errors
/// - Prints error messages to stderr and exits with non-zero code on failure
/// - Prints usage information for invalid arguments or --help
pub fn main() -> Nil {
  let args = argv.load().arguments

  // Check if this is the simplified interface (gleam run -m protozoa)
  case is_simplified_interface(args) {
    True -> run_simplified_interface(args)
    False -> run_full_cli(args)
  }
}

fn is_simplified_interface(args: List(String)) -> Bool {
  case args {
    [] -> True
    ["check"] -> True
    _ -> {
      // If args start with proto file path or import flags, use full CLI
      case args {
        [arg, ..] ->
          !string.ends_with(arg, ".proto")
          && !string.starts_with(arg, "-I")
          && !string.starts_with(arg, "--proto_path")
          && arg != "-h"
          && arg != "--help"
        [] -> False
      }
    }
  }
}

fn run_simplified_interface(args: List(String)) -> Nil {
  case args {
    [] -> {
      // Generate mode with user-friendly output
      io.println("🔄 Running proto code generation...")
      case run_default_generation() {
        Ok(files) -> print_generation_success(files)
        Error(err) -> print_error_and_exit("Generation failed", err)
      }
    }
    ["check"] -> {
      // Check mode with user-friendly output
      io.println("🔍 Checking proto file changes...")
      case run_check_mode() {
        Ok(ProtoUnchanged) -> io.println("✅ Proto files are up to date.")
        Ok(ProtoChanged(changes)) -> {
          print_proto_changes(changes)
          exit(1)
        }
        Error(err) -> print_error_and_exit("Check failed", err)
      }
    }
    _ -> {
      show_simplified_usage()
      exit(1)
    }
  }
}

fn run_full_cli(args: List(String)) -> Nil {
  execute_full_cli_command(args)
  |> handle_cli_result
}

fn run_default_generation() -> Result(List(String), snag.Snag) {
  use #(_command, input_path, output_dir, import_paths) <- result.try(
    parse_default_command(),
  )
  generate_with_imports(input_path, output_dir, import_paths)
}

fn run_check_mode() -> Result(ProtoChangeResult, snag.Snag) {
  use #(_command, input_path, output_dir, import_paths) <- result.try(
    parse_check_command(),
  )
  check_proto_changes(input_path, output_dir, import_paths)
}

fn show_simplified_usage() -> Nil {
  io.println("Protozoa - Protocol Buffer Compiler for Gleam")
  io.println("")
  io.println("Usage:")
  io.println("  gleam run -m protozoa        Generate all proto files")
  io.println("  gleam run -m protozoa check  Check if files need regeneration")
  io.println("")
  io.println(
    "The tool automatically detects proto files in src/[appname]/proto/",
  )
  io.println("and generates Gleam code in the same directories.")
  io.println("")
  io.println("For advanced usage with custom paths, use:")
  io.println("  gleam run -m protozoa -- [options] [input.proto] [output_dir]")
  io.println("  gleam run -m protozoa -- --help")
}

fn parse_arguments(
  args: List(String),
) -> Result(#(ProtoCommand, String, String, List(String)), snag.Snag) {
  case args {
    [] -> parse_default_command()
    ["-h"] | ["--help"] -> usage_message()
    ["check"] -> parse_check_command()
    _ -> {
      let #(import_paths, remaining) = extract_import_paths(args, [])
      case remaining {
        [input_file, output_dir] ->
          Ok(#(Generate, input_file, output_dir, import_paths))
        [input_file] -> {
          // Default output directory is current directory
          Ok(#(Generate, input_file, ".", import_paths))
        }
        _ -> usage_message()
      }
    }
  }
}

type ProtoCommand {
  Generate
  Check
}

fn parse_default_command() -> Result(
  #(ProtoCommand, String, String, List(String)),
  snag.Snag,
) {
  resolve_proto_directory(Generate)
}

fn parse_check_command() -> Result(
  #(ProtoCommand, String, String, List(String)),
  snag.Snag,
) {
  resolve_proto_directory(Check)
}

fn extract_import_paths(
  args: List(String),
  acc: List(String),
) -> #(List(String), List(String)) {
  case args {
    ["-I", path, ..rest] | ["--proto_path", path, ..rest] ->
      extract_import_paths(rest, [path, ..acc])
    [arg, ..rest] -> {
      case extract_path_from_arg(arg) {
        Some(path) -> extract_import_paths(rest, [path, ..acc])
        None -> #(list.reverse(acc), args)
      }
    }
    [] -> #(list.reverse(acc), [])
  }
}

fn extract_path_from_arg(arg: String) -> option.Option(String) {
  case string.starts_with(arg, "-I") {
    True -> Some(string.drop_start(arg, 2))
    False ->
      case string.starts_with(arg, "--proto_path=") {
        True -> Some(string.drop_start(arg, 13))
        False -> None
      }
  }
}

// Project structure helpers

// Get app name from gleam.toml
fn get_app_name() -> Result(String, snag.Snag) {
  use content <- result.try(
    simplifile.read("gleam.toml")
    |> result.map_error(fn(_) { snag.new("Could not read gleam.toml") }),
  )

  // Look for name = "appname" in gleam.toml
  let app_name_option =
    content
    |> string.split("\n")
    |> list.fold(None, fn(acc, line) {
      case acc {
        Some(_) -> acc
        // Already found it
        None -> {
          let trimmed = string.trim(line)
          case string.starts_with(trimmed, "name = ") {
            True -> {
              trimmed
              |> string.drop_start(7)
              // Remove "name = "
              |> string.trim()
              |> string.drop_start(1)
              // Remove opening quote
              |> string.drop_end(1)
              // Remove closing quote
              |> Some
            }
            False -> None
          }
        }
      }
    })

  case app_name_option {
    Some(app_name) -> Ok(app_name)
    None -> Error(snag.new("Could not find app name in gleam.toml"))
  }
}

// Find existing proto directories in src/*/proto/ structure
fn resolve_proto_directory(
  command: ProtoCommand,
) -> Result(#(ProtoCommand, String, String, List(String)), snag.Snag) {
  case simplifile.is_directory("src") {
    Ok(True) -> {
      case find_proto_directories() {
        Ok([proto_dir, ..]) -> {
          Ok(#(command, proto_dir, proto_dir, [proto_dir]))
        }
        Ok([]) -> get_default_proto_dir(command)
        Error(_) -> get_default_proto_dir(command)
      }
    }
    _ -> usage_message()
  }
}

fn execute_full_cli_command(args: List(String)) -> Result(Nil, snag.Snag) {
  use #(command, input_path, output_dir, import_paths) <- result.try(
    parse_arguments(args),
  )

  case command {
    Generate -> {
      use files <- result.map(generate_with_imports(
        input_path,
        output_dir,
        import_paths,
      ))
      print_cli_generation_success(files)
    }
    Check -> {
      use result <- result.try(check_proto_changes(
        input_path,
        output_dir,
        import_paths,
      ))
      case result {
        ProtoUnchanged -> {
          io.println("Proto files are up to date.")
          Ok(Nil)
        }
        ProtoChanged(changes) -> {
          print_cli_proto_changes(changes)
          exit(1)
          Ok(Nil)
        }
      }
    }
  }
}

fn handle_cli_result(result: Result(Nil, snag.Snag)) -> Nil {
  case result {
    Ok(_) -> exit(0)
    Error(err) -> {
      io.println_error(snag.pretty_print(err))
      exit(1)
    }
  }
}

fn get_default_proto_dir(
  command: ProtoCommand,
) -> Result(#(ProtoCommand, String, String, List(String)), snag.Snag) {
  case get_app_name() {
    Ok(app_name) -> {
      let proto_dir = "src/" <> app_name <> "/proto"
      Ok(#(command, proto_dir, proto_dir, [proto_dir]))
    }
    Error(_) -> {
      let proto_dir = "src/proto"
      Ok(#(command, proto_dir, proto_dir, [proto_dir]))
    }
  }
}

fn find_proto_directories() -> Result(List(String), snag.Snag) {
  use entries <- result.try(
    simplifile.read_directory("src")
    |> result.map_error(fn(_) { snag.new("Could not read src directory") }),
  )

  let proto_dirs =
    entries
    |> list.fold([], fn(acc, entry) {
      let proto_path = "src/" <> entry <> "/proto"
      case simplifile.is_directory(proto_path) {
        Ok(True) -> [proto_path, ..acc]
        _ -> acc
      }
    })

  Ok(proto_dirs)
}

// Check if proto files have changed compared to generated files
type ProtoChangeResult {
  ProtoUnchanged
  ProtoChanged(changes: List(String))
}

fn check_proto_changes(
  proto_dir: String,
  _output_dir: String,
  _import_paths: List(String),
) -> Result(ProtoChangeResult, snag.Snag) {
  // For now, always indicate changes need to be generated
  // This could be enhanced to check file timestamps, hashes, etc.
  use proto_files <- result.try(find_proto_files(proto_dir))

  case proto_files {
    [] -> Ok(ProtoUnchanged)
    _ -> Ok(ProtoChanged(proto_files))
  }
}

fn find_proto_files(directory: String) -> Result(List(String), snag.Snag) {
  case simplifile.is_directory(directory) {
    Ok(True) -> {
      use entries <- result.try(
        simplifile.read_directory(directory)
        |> result.map_error(fn(_) {
          snag.new("Could not read directory: " <> directory)
        }),
      )

      let proto_files =
        entries
        |> list.filter(string.ends_with(_, ".proto"))
        |> list.map(fn(file) { directory <> "/" <> file })

      Ok(proto_files)
    }
    _ -> Ok([])
  }
}

fn usage_message() -> Result(a, snag.Snag) {
  "Protozoa - Protocol Buffer Compiler for Gleam

Recommended Usage:
  gleam run -m protozoa           # Generate all proto files
  gleam run -m protozoa check     # Check if files need regeneration

Advanced Usage:
  gleam run -m protozoa -- [options] [<input.proto> [output_dir]]

Options:
  -I<path>, --proto_path=<path>  Add a directory to the import search path
  -h, --help                      Show this help message

Arguments:
  input.proto   The Protocol Buffer file to compile (optional)
  output_dir    Directory for generated files (optional)

Examples:
  gleam run -m protozoa                              # Auto-detect and process proto files
  gleam run -m protozoa check                       # Check if proto files need regeneration
  gleam run -m protozoa -- message.proto           # Process specific file
  gleam run -m protozoa -- -I./protos message.proto ./generated

The tool automatically detects proto files in src/[appname]/proto/ directories
and generates Gleam code with safety headers for regeneration."
  |> snag.new()
  |> Error
}

fn generate_with_imports(
  input_path: String,
  output_dir: String,
  import_paths: List(String),
) -> Result(List(String), snag.Snag) {
  // Check if input_path is a directory or a single file
  case simplifile.is_directory(input_path) {
    Ok(True) -> generate_directory(input_path, output_dir, import_paths)
    _ -> generate_single_file(input_path, output_dir, import_paths)
  }
}

fn generate_directory(
  proto_dir: String,
  output_dir: String,
  import_paths: List(String),
) -> Result(List(String), snag.Snag) {
  // Find all .proto files in the directory
  use proto_files <- result.try(find_proto_files(proto_dir))

  // Process each proto file
  proto_files
  |> list.try_map(fn(proto_file) {
    generate_single_file(proto_file, output_dir, import_paths)
  })
  |> result.map(list.flatten)
}

fn generate_single_file(
  input_path: String,
  output_dir: String,
  import_paths: List(String),
) -> Result(List(String), snag.Snag) {
  // Create output directory if it doesn't exist
  let _ = simplifile.create_directory_all(output_dir)

  // Initialize resolver with import paths
  let resolver =
    import_resolver.new()
    |> import_resolver.with_search_paths([".", ..import_paths])

  // Resolve all imports
  use #(_proto_file, final_resolver) <- result.try(
    import_resolver.resolve_imports(resolver, input_path)
    |> result.map_error(fn(err) {
      snag.new(
        "Failed to resolve imports: " <> import_resolver.describe_error(err),
      )
    }),
  )

  // Get all loaded files
  let files = import_resolver.get_all_loaded_files(final_resolver)
  let registry = import_resolver.get_type_registry(final_resolver)

  // Convert to Path type for codegen
  let paths =
    list.map(files, fn(entry) {
      let #(path, content) = entry
      parser.Path(path, content)
    })

  // Generate code for all files
  use generated_files <- result.try(
    codegen.generate_with_imports(paths, registry, output_dir)
    |> result.map_error(fn(err) { snag.new("Code generation failed: " <> err) }),
  )

  // Return just the file paths
  Ok(list.map(generated_files, fn(entry) { entry.0 }))
}

fn print_generation_success(files: List(String)) -> Nil {
  io.println(
    "✅ Successfully generated "
    <> int.to_string(list.length(files))
    <> " file(s):",
  )
  list.each(files, fn(file) { io.println("  - " <> file) })
}

fn print_cli_generation_success(files: List(String)) -> Nil {
  io.println(
    "Successfully generated "
    <> int.to_string(list.length(files))
    <> " file(s):",
  )
  list.each(files, fn(file) { io.println("  - " <> file) })
}

fn print_proto_changes(changes: List(String)) -> Nil {
  io.println("⚠️  Proto files have changed:")
  list.each(changes, fn(change) { io.println("  - " <> change) })
  io.println("💡 Run 'gleam run -m protozoa' to regenerate.")
}

fn print_cli_proto_changes(changes: List(String)) -> Nil {
  io.println("Proto files have changed:")
  list.each(changes, fn(change) { io.println("  - " <> change) })
}

fn print_error_and_exit(message: String, err: snag.Snag) -> Nil {
  io.println_error("❌ " <> message <> ": " <> snag.pretty_print(err))
  exit(1)
}

@external(erlang, "erlang", "halt")
fn exit(n: Int) -> Nil
