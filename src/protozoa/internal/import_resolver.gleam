import gleam/dict
import gleam/list
import gleam/result
import gleam/set
import protozoa/internal/type_registry.{type TypeRegistry}
import protozoa/internal/well_known_types
import protozoa/parser.{type ProtoFile}
import simplifile

pub type ImportResolver {
  ImportResolver(
    search_paths: List(String),
    loaded_files: dict.Dict(String, ProtoFile),
    dependency_graph: dict.Dict(String, List(String)),
    type_registry: TypeRegistry,
    public_imports: dict.Dict(String, List(String)),
  )
}

pub type Error {
  FileNotFound(path: String)
  CircularDependency(path: String)
  ReadError(path: String, reason: String)
  ParseError(path: String, reason: String)
  WellKnownTypeNotFound(path: String)
}

pub fn describe_error(error: Error) -> String {
  case error {
    FileNotFound(path) -> "File not found: " <> path
    CircularDependency(path) -> "Circular dependency detected at: " <> path
    ReadError(path, reason) -> "Failed to read file " <> path <> ": " <> reason
    ParseError(path, reason) ->
      "Failed to parse file " <> path <> ": " <> reason
    WellKnownTypeNotFound(path) -> "Well-known type not found: " <> path
  }
}

pub fn new() -> ImportResolver {
  ImportResolver(
    search_paths: ["."],
    loaded_files: dict.new(),
    dependency_graph: dict.new(),
    type_registry: type_registry.new(),
    public_imports: dict.new(),
  )
}

pub fn with_search_paths(
  resolver: ImportResolver,
  paths: List(String),
) -> ImportResolver {
  ImportResolver(..resolver, search_paths: paths)
}

fn find_file(path: String, search_paths: List(String)) -> Result(String, Error) {
  case search_paths {
    [] -> Error(FileNotFound(path))
    [search_path, ..rest] -> {
      let full_path = case search_path {
        "." -> path
        _ -> search_path <> "/" <> path
      }
      case simplifile.is_file(full_path) {
        Ok(True) -> Ok(full_path)
        _ -> find_file(path, rest)
      }
    }
  }
}

fn detect_circular_dependency(
  path: String,
  visiting: set.Set(String),
  graph: dict.Dict(String, List(String)),
) -> Result(Nil, Error) {
  case set.contains(visiting, path) {
    True -> Error(CircularDependency(path))
    False -> {
      let new_visiting = set.insert(visiting, path)
      case dict.get(graph, path) {
        Ok(deps) -> {
          list.try_each(deps, fn(dep) {
            detect_circular_dependency(dep, new_visiting, graph)
          })
        }
        Error(_) -> Ok(Nil)
      }
    }
  }
}

pub fn resolve_imports(
  resolver: ImportResolver,
  file_path: String,
) -> Result(#(ProtoFile, ImportResolver), Error) {
  case dict.get(resolver.loaded_files, file_path) {
    Ok(proto_file) -> Ok(#(proto_file, resolver))
    Error(_) -> {
      // Check if it's a well-known type
      let proto_file = case well_known_types.is_well_known_import(file_path) {
        True -> {
          case
            dict.get(well_known_types.get_well_known_proto_files(), file_path)
          {
            Ok(wkt) -> Ok(wkt)
            Error(_) -> Error(WellKnownTypeNotFound(file_path))
          }
        }
        False -> {
          use full_path <- result.try(find_file(
            file_path,
            resolver.search_paths,
          ))
          use content <- result.try(
            simplifile.read(full_path)
            |> result.map_error(fn(reason) {
              ReadError(file_path, reason: simplifile.describe_error(reason))
            }),
          )
          parser.parse(content)
          |> result.map_error(fn(parse_error) {
            ParseError(
              file_path,
              reason: parser.describe_parse_error(parse_error),
            )
          })
        }
      }

      use proto_file <- result.try(proto_file)

      let import_paths = list.map(proto_file.imports, fn(imp) { imp.path })

      // Track public imports
      let public_import_paths =
        proto_file.imports
        |> list.filter(fn(imp) { imp.public })
        |> list.map(fn(imp) { imp.path })

      let new_graph =
        dict.insert(resolver.dependency_graph, file_path, import_paths)
      use _ <- result.try(detect_circular_dependency(
        file_path,
        set.new(),
        new_graph,
      ))

      let resolver_with_imports =
        ImportResolver(
          ..resolver,
          loaded_files: dict.insert(
            resolver.loaded_files,
            file_path,
            proto_file,
          ),
          dependency_graph: new_graph,
          public_imports: dict.insert(
            resolver.public_imports,
            file_path,
            public_import_paths,
          ),
        )

      use resolver_after_imports <- result.try(
        list.try_fold(proto_file.imports, resolver_with_imports, fn(res, imp) {
          use #(_, updated_res) <- result.try(resolve_imports(res, imp.path))
          Ok(updated_res)
        }),
      )

      use updated_registry <- result.try(
        type_registry.add_file(
          resolver_after_imports.type_registry,
          file_path,
          proto_file,
        )
        |> result.map_error(fn(error) {
          ReadError(
            path: file_path,
            reason: type_registry.describe_error(error),
          )
        }),
      )

      let final_resolver =
        ImportResolver(
          ..resolver_after_imports,
          type_registry: updated_registry,
        )

      Ok(#(proto_file, final_resolver))
    }
  }
}

pub fn get_type_registry(resolver: ImportResolver) -> TypeRegistry {
  resolver.type_registry
}

pub fn get_all_loaded_files(
  resolver: ImportResolver,
) -> List(#(String, ProtoFile)) {
  dict.to_list(resolver.loaded_files)
}

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
