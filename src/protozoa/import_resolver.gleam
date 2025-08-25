import gleam/dict
import protozoa/parser.{type ProtoFile}

pub type ImportResolver {
  ImportResolver(
    search_paths: List(String),
    // Like protoc's -I flag
    loaded_files: dict.Dict(String, ProtoFile),
    dependency_graph: dict.Dict(String, List(String)),
  )
}

pub fn resolve_imports(
  file_path: String,
  resolver: ImportResolver,
) -> Result(#(ProtoFile, ImportResolver), String) {
  todo
  // 1. Parse the file
  // 2. For each import, recursively load and parse
  // 3. Detect circular dependencies
  // 4. Return merged type environment
}
