import gleam/dict
import gleam/list
import gleam/result
import gleam/set
import protozoa/internal/type_registry
import protozoa/internal/well_known_type
import protozoa/parser/file

pub type ImportResolver {
  ImportResolver(
    loaded_files: dict.Dict(String, file.ProtoFile),
    dependency_graph: dict.Dict(String, List(String)),
    type_registry: type_registry.TypeRegistry,
    public_imports: dict.Dict(String, List(String)),
  )
}

pub type Error {
  FileNotFound(path: String)
  CircularDependency(path: String)
  ParseError(path: String, reason: String)
  TypeError(path: String, reason: String)
}

pub fn describe_error(error: Error) -> String {
  case error {
    FileNotFound(path) -> "File not found: " <> path
    CircularDependency(path) -> "Circular dependency detected at: " <> path
    ParseError(path, reason) ->
      "Failed to parse file " <> path <> ": " <> reason
    TypeError(path, reason) -> "Type error in " <> path <> ": " <> reason
  }
}

pub fn new() -> ImportResolver {
  ImportResolver(
    loaded_files: dict.new(),
    dependency_graph: dict.new(),
    type_registry: type_registry.new(),
    public_imports: dict.new(),
  )
}

/// A proto file source that can be either pre-parsed content or raw string
pub type ProtoSource {
  /// Pre-parsed ProtoFile
  Parsed(file.ProtoFile)
  /// Raw proto content string to be parsed
  Raw(String)
}

/// Resolve imports from a collection of in-memory proto sources.
///
/// The `sources` dict maps file paths to their content (either parsed or raw).
/// The `entry_point` is the main file to resolve from.
///
/// Well-known types (google/protobuf/*) are automatically available and don't
/// need to be included in sources.
pub fn resolve(
  sources: dict.Dict(String, ProtoSource),
  entry_point: String,
) -> Result(ImportResolver, Error) {
  // First, parse any raw sources
  use parsed_sources <- result.try(parse_raw_sources(sources))

  // Start with an empty resolver
  let resolver = new()

  // Resolve from the entry point
  resolve_file(resolver, entry_point, parsed_sources, set.new())
}

/// Parse all raw sources into ProtoFiles
fn parse_raw_sources(
  sources: dict.Dict(String, ProtoSource),
) -> Result(dict.Dict(String, file.ProtoFile), Error) {
  dict.to_list(sources)
  |> list.try_fold(dict.new(), fn(acc, entry) {
    let #(path, source) = entry
    case source {
      Parsed(proto_file) -> Ok(dict.insert(acc, path, proto_file))
      Raw(content) -> {
        case file.parse(content) {
          Ok(proto_file) -> Ok(dict.insert(acc, path, proto_file))
          Error(parse_error) ->
            Error(ParseError(path, file.describe_error(parse_error)))
        }
      }
    }
  })
}

/// Resolve a file and its imports from in-memory sources
fn resolve_file(
  resolver: ImportResolver,
  file_path: String,
  sources: dict.Dict(String, file.ProtoFile),
  visiting: set.Set(String),
) -> Result(ImportResolver, Error) {
  // Check for circular dependency
  case set.contains(visiting, file_path) {
    True -> Error(CircularDependency(file_path))
    False -> {
      // Check if already loaded
      case dict.get(resolver.loaded_files, file_path) {
        Ok(_) -> Ok(resolver)
        Error(_) -> {
          // Try to find the file
          use proto_file <- result.try(lookup_file(file_path, sources))

          let new_visiting = set.insert(visiting, file_path)

          // Get import paths
          let import_paths = list.map(proto_file.imports, fn(imp) { imp.path })

          // Track public imports
          let public_import_paths =
            proto_file.imports
            |> list.filter(fn(imp) { imp.public })
            |> list.map(fn(imp) { imp.path })

          // Update the resolver with this file
          let resolver_with_file =
            ImportResolver(
              ..resolver,
              loaded_files: dict.insert(
                resolver.loaded_files,
                file_path,
                proto_file,
              ),
              dependency_graph: dict.insert(
                resolver.dependency_graph,
                file_path,
                import_paths,
              ),
              public_imports: dict.insert(
                resolver.public_imports,
                file_path,
                public_import_paths,
              ),
            )

          // Recursively resolve imports
          use resolver_after_imports <- result.try(
            list.try_fold(proto_file.imports, resolver_with_file, fn(res, imp) {
              resolve_file(res, imp.path, sources, new_visiting)
            }),
          )

          // Add to type registry
          use updated_registry <- result.try(
            type_registry.add_file(
              resolver_after_imports.type_registry,
              file_path,
              proto_file,
            )
            |> result.map_error(fn(error) {
              TypeError(file_path, type_registry.describe_error(error))
            }),
          )

          Ok(
            ImportResolver(
              ..resolver_after_imports,
              type_registry: updated_registry,
            ),
          )
        }
      }
    }
  }
}

/// Look up a file from sources or well-known types
fn lookup_file(
  file_path: String,
  sources: dict.Dict(String, file.ProtoFile),
) -> Result(file.ProtoFile, Error) {
  // First check user-provided sources
  case dict.get(sources, file_path) {
    Ok(proto_file) -> Ok(proto_file)
    Error(_) -> {
      // Check if it's a well-known type
      case well_known_type.is_well_known_import(file_path) {
        True -> {
          case
            dict.get(well_known_type.get_well_known_proto_files(), file_path)
          {
            Ok(wkt) -> Ok(wkt)
            Error(_) -> Error(FileNotFound(file_path))
          }
        }
        False -> Error(FileNotFound(file_path))
      }
    }
  }
}

/// Get the type registry from the resolver
pub fn get_type_registry(resolver: ImportResolver) -> type_registry.TypeRegistry {
  resolver.type_registry
}

/// Get all loaded files as a list of (path, ProtoFile) tuples
pub fn get_all_loaded_files(
  resolver: ImportResolver,
) -> List(#(String, file.ProtoFile)) {
  dict.to_list(resolver.loaded_files)
}

/// Get transitive public imports for a file
pub fn get_public_imports(
  resolver: ImportResolver,
  file_path: String,
) -> List(String) {
  get_transitive_public_imports(file_path, resolver.public_imports, set.new())
  |> set.to_list()
}

fn get_transitive_public_imports(
  file_path: String,
  public_imports: dict.Dict(String, List(String)),
  visited: set.Set(String),
) -> set.Set(String) {
  case set.contains(visited, file_path) {
    True -> visited
    False -> {
      let visited_with_current = set.insert(visited, file_path)
      case dict.get(public_imports, file_path) {
        Ok(imports) -> {
          list.fold(imports, visited_with_current, fn(acc, import_path) {
            let with_import = set.insert(acc, import_path)
            get_transitive_public_imports(
              import_path,
              public_imports,
              with_import,
            )
          })
        }
        Error(_) -> visited_with_current
      }
    }
  }
}
