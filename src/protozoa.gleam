import argv
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/string
import protozoa/codegen
import protozoa/import_resolver
import protozoa/parser
import simplifile
import snag.{type Result}

pub fn main() {
  let args = argv.load().arguments

  case parse_arguments(args) {
    Ok(#(input_file, output_dir, import_paths)) -> {
      case generate_with_imports(input_file, output_dir, import_paths) {
        Ok(files) -> {
          io.println(
            "Successfully generated "
            <> int.to_string(list.length(files))
            <> " file(s):",
          )
          list.each(files, fn(file) { io.println("  - " <> file) })
        }
        Error(err) -> {
          io.println_error(snag.pretty_print(err))
        }
      }
    }
    Error(usage) -> {
      io.println(snag.pretty_print(usage))
    }
  }
}

fn parse_arguments(
  args: List(String),
) -> Result(#(String, String, List(String))) {
  case args {
    [] -> usage_message()
    ["-h"] | ["--help"] -> usage_message()
    _ -> {
      let #(import_paths, remaining) = extract_import_paths(args, [])
      case remaining {
        [input_file, output_dir] -> Ok(#(input_file, output_dir, import_paths))
        [input_file] -> {
          // Default output directory is current directory
          Ok(#(input_file, ".", import_paths))
        }
        _ -> usage_message()
      }
    }
  }
}

fn extract_import_paths(
  args: List(String),
  acc: List(String),
) -> #(List(String), List(String)) {
  case args {
    ["-I", path, ..rest] -> extract_import_paths(rest, [path, ..acc])
    ["--proto_path", path, ..rest] -> extract_import_paths(rest, [path, ..acc])
    [arg, ..rest] -> {
      case string.starts_with(arg, "-I") {
        True -> {
          let path = string.drop_start(arg, 2)
          extract_import_paths(rest, [path, ..acc])
        }
        False -> {
          case string.starts_with(arg, "--proto_path=") {
            True -> {
              let path = string.drop_start(arg, 13)
              extract_import_paths(rest, [path, ..acc])
            }
            False -> #(list.reverse(acc), args)
          }
        }
      }
    }
    [] -> #(list.reverse(acc), [])
  }
}

fn usage_message() -> Result(a) {
  "Usage: protozoa [options] <input.proto> [output_dir]

Options:
  -I<path>, --proto_path=<path>  Add a directory to the import search path
  -h, --help                      Show this help message

Arguments:
  input.proto   The Protocol Buffer file to compile
  output_dir    Directory for generated files (default: current directory)

Examples:
  protozoa message.proto
  protozoa -I./protos message.proto ./generated
  protozoa --proto_path=/usr/include --proto_path=. api.proto"
  |> snag.new()
  |> Error
}

pub fn generate_with_imports(
  input_path: String,
  output_dir: String,
  import_paths: List(String),
) -> Result(List(String)) {
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

pub fn generate_from_proto(
  input_path: String,
  output_path: String,
) -> Result(Nil) {
  use proto_content <- result.try(
    simplifile.read(input_path)
    |> result.map_error(fn(_) {
      snag.new("Failed to read proto file: " <> input_path)
    }),
  )

  let proto_file = parser.parse(proto_content)

  let generated_code = codegen.generate_simple(proto_file)

  simplifile.write(output_path, generated_code)
  |> result.map_error(fn(_) {
    snag.new("Failed to write output file: " <> output_path)
  })
}
