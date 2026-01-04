import gleam/dict
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import protozoa/internal/well_known_type
import protozoa/parser/file
import protozoa/parser/proto

/// A registry to hold all message and enum types across multiple proto files,
/// allowing for type resolution and lookup.
pub type TypeRegistry {
  TypeRegistry(
    messages: dict.Dict(String, proto.Message),
    enums: dict.Dict(String, proto.Enum),
    type_sources: dict.Dict(String, String),
    file_packages: dict.Dict(String, String),
  )
}

/// Errors that can occur when adding types to the TypeRegistry.
pub type Error {
  DuplicateMessageDefinition(fqn: String)
  DuplicateEnumDefinition(fqn: String)
}

pub fn describe_error(error: Error) -> String {
  case error {
    DuplicateMessageDefinition(fqn) ->
      "Duplicate message definition for type: " <> fqn
    DuplicateEnumDefinition(fqn) ->
      "Duplicate enum definition for type: " <> fqn
  }
}

/// Create a new TypeRegistry with well-known types pre-loaded.
pub fn new() -> TypeRegistry {
  let registry =
    TypeRegistry(
      messages: dict.new(),
      enums: dict.new(),
      type_sources: dict.new(),
      file_packages: dict.new(),
    )

  // Pre-populate with well-known types
  load_well_known_types(registry)
}

/// Load well-known types into the registry
fn load_well_known_types(registry: TypeRegistry) -> TypeRegistry {
  let well_known_files = well_known_type.get_well_known_proto_files()

  dict.fold(well_known_files, registry, fn(acc, file_path, proto_file) {
    case add_file(acc, file_path, proto_file) {
      Ok(updated_registry) -> updated_registry
      Error(_) -> acc
      // Ignore errors when loading well-known types
    }
  })
}

/// Add types from a single ProtoFile to the TypeRegistry.
pub fn add_file(
  registry: TypeRegistry,
  file_path: String,
  proto_file: file.ProtoFile,
) -> Result(TypeRegistry, Error) {
  let package = option.unwrap(proto_file.package, "")

  let registry =
    TypeRegistry(
      ..registry,
      file_packages: dict.insert(registry.file_packages, file_path, package),
    )

  use registry <- result.try(
    list.fold(proto_file.messages, Ok(registry), fn(acc, message) {
      case acc {
        Error(e) -> Error(e)
        Ok(reg) -> add_message(reg, message, package, file_path)
      }
    }),
  )

  list.fold(proto_file.enums, Ok(registry), fn(acc, enum) {
    case acc {
      Error(e) -> Error(e)
      Ok(reg) -> add_enum(reg, enum, package, file_path)
    }
  })
}

fn add_message(
  registry: TypeRegistry,
  message: proto.Message,
  package: String,
  file_path: String,
) -> Result(TypeRegistry, Error) {
  let fqn = make_fully_qualified_name(package, message.name)

  case dict.get(registry.messages, fqn) {
    Ok(_existing) -> {
      case dict.get(registry.type_sources, fqn) {
        Ok(source) if source == file_path -> {
          // Same file redefining - this is ok during reprocessing
          Ok(
            TypeRegistry(
              ..registry,
              messages: dict.insert(registry.messages, fqn, message),
              type_sources: dict.insert(registry.type_sources, fqn, file_path),
            ),
          )
        }
        _ -> Error(DuplicateMessageDefinition(fqn))
      }
    }
    Error(_) -> {
      // Also add nested messages to registry
      let registry_with_main =
        TypeRegistry(
          ..registry,
          messages: dict.insert(registry.messages, fqn, message),
          type_sources: dict.insert(registry.type_sources, fqn, file_path),
        )

      // Add nested messages recursively
      add_nested_messages(
        registry_with_main,
        message.nested_messages,
        fqn,
        file_path,
      )
    }
  }
}

fn add_nested_messages(
  registry: TypeRegistry,
  nested_messages: List(proto.Message),
  parent_fqn: String,
  file_path: String,
) -> Result(TypeRegistry, Error) {
  list.fold(nested_messages, Ok(registry), fn(acc, nested_msg) {
    case acc {
      Error(e) -> Error(e)
      Ok(reg) -> {
        let nested_fqn = parent_fqn <> "." <> nested_msg.name
        case dict.get(reg.messages, nested_fqn) {
          Ok(_) -> Error(DuplicateMessageDefinition(nested_fqn))
          Error(_) -> {
            let updated_reg =
              TypeRegistry(
                ..reg,
                messages: dict.insert(reg.messages, nested_fqn, nested_msg),
                type_sources: dict.insert(
                  reg.type_sources,
                  nested_fqn,
                  file_path,
                ),
              )
            // Recursively add nested messages of nested messages
            add_nested_messages(
              updated_reg,
              nested_msg.nested_messages,
              nested_fqn,
              file_path,
            )
          }
        }
      }
    }
  })
}

fn add_enum(
  registry: TypeRegistry,
  enum: proto.Enum,
  package: String,
  file_path: String,
) -> Result(TypeRegistry, Error) {
  let fqn = make_fully_qualified_name(package, enum.name)

  case dict.get(registry.enums, fqn) {
    Ok(_existing) -> {
      case dict.get(registry.type_sources, fqn) {
        Ok(source) if source == file_path -> {
          // Same file redefining - this is ok during reprocessing
          Ok(
            TypeRegistry(
              ..registry,
              enums: dict.insert(registry.enums, fqn, enum),
              type_sources: dict.insert(registry.type_sources, fqn, file_path),
            ),
          )
        }
        _ -> Error(DuplicateEnumDefinition(fqn))
      }
    }
    Error(_) -> {
      Ok(
        TypeRegistry(
          ..registry,
          enums: dict.insert(registry.enums, fqn, enum),
          type_sources: dict.insert(registry.type_sources, fqn, file_path),
        ),
      )
    }
  }
}

pub fn make_fully_qualified_name(package: String, type_name: String) -> String {
  case package {
    "" -> type_name
    _ -> package <> "." <> type_name
  }
}

pub fn resolve_type_reference(
  registry: TypeRegistry,
  type_name: String,
  current_package: String,
) -> Result(String, String) {
  // Try various resolution strategies
  let candidates = [
    // 1. Exact match (already fully qualified)
    type_name,
    // 2. In current package
    make_fully_qualified_name(current_package, type_name),
    // 3. Nested type in current package (e.g., Message.NestedMessage)
    ..resolve_nested_type_candidates(type_name, current_package, registry),
  ]

  case
    list.find(candidates, fn(candidate) {
      case lookup_type(registry, candidate) {
        option.Some(_) -> True
        option.None -> False
      }
    })
  {
    Ok(resolved) -> Ok(resolved)
    Error(_) -> {
      // 4. Try searching for nested types in the registry
      // This handles cases like "Inner" when the full name is "package.Outer.Inner"
      case find_nested_type_in_registry(registry, type_name, current_package) {
        option.Some(fqn) -> Ok(fqn)
        option.None ->
          Error(
            "Unknown type: "
            <> type_name
            <> " (searched in package: "
            <> current_package
            <> ")",
          )
      }
    }
  }
}

fn resolve_nested_type_candidates(
  type_name: String,
  current_package: String,
  _registry: TypeRegistry,
) -> List(String) {
  case string.contains(type_name, ".") {
    False -> []
    True -> {
      // For nested types like "OuterMessage.InnerMessage"
      // Try with current package prefix
      [make_fully_qualified_name(current_package, type_name)]
    }
  }
}

/// Search the registry for a nested type by its simple name
/// This handles cases where we have type name "Inner" but the registry has "package.Outer.Inner"
fn find_nested_type_in_registry(
  registry: TypeRegistry,
  type_name: String,
  current_package: String,
) -> option.Option(String) {
  // Search for a FQN that ends with ".{type_name}" in the current package
  let suffix = "." <> type_name
  let package_prefix = case current_package {
    "" -> ""
    pkg -> pkg <> "."
  }

  // Search messages first
  let message_match =
    dict.keys(registry.messages)
    |> list.find(fn(fqn) {
      string.ends_with(fqn, suffix) && string.starts_with(fqn, package_prefix)
    })

  case message_match {
    Ok(fqn) -> option.Some(fqn)
    Error(_) -> {
      // Search enums
      dict.keys(registry.enums)
      |> list.find(fn(fqn) {
        string.ends_with(fqn, suffix) && string.starts_with(fqn, package_prefix)
      })
      |> option.from_result()
    }
  }
}

pub fn lookup_type(
  registry: TypeRegistry,
  fqn: String,
) -> option.Option(#(String, proto.Type)) {
  case dict.get(registry.messages, fqn) {
    Ok(msg) -> {
      case dict.get(registry.type_sources, fqn) {
        Ok(source) -> option.Some(#(source, proto.MessageType(msg.name)))
        Error(_) -> option.None
      }
    }
    Error(_) -> {
      case dict.get(registry.enums, fqn) {
        Ok(enum) -> {
          case dict.get(registry.type_sources, fqn) {
            Ok(source) -> option.Some(#(source, proto.EnumType(enum.name)))
            Error(_) -> option.None
          }
        }
        Error(_) -> option.None
      }
    }
  }
}

pub fn get_types_from_file(
  registry: TypeRegistry,
  file_path: String,
) -> List(#(String, proto.Type)) {
  dict.fold(registry.type_sources, [], fn(acc, fqn, source) {
    case source == file_path {
      False -> acc
      True -> {
        case lookup_type(registry, fqn) {
          option.Some(#(_source, proto_type)) -> [#(fqn, proto_type), ..acc]
          option.None -> acc
        }
      }
    }
  })
}

pub fn get_file_package(
  registry: TypeRegistry,
  file_path: String,
) -> option.Option(String) {
  case dict.get(registry.file_packages, file_path) {
    Ok(package) -> option.Some(package)
    Error(_) -> option.None
  }
}

pub fn get_type_source(
  registry: TypeRegistry,
  fqn: String,
) -> option.Option(String) {
  case dict.get(registry.type_sources, fqn) {
    Ok(source) -> option.Some(source)
    Error(_) -> option.None
  }
}

/// Get all message FQNs in the registry (for debugging)
pub fn get_all_messages(registry: TypeRegistry) -> List(String) {
  dict.keys(registry.messages)
}

/// Check if a type name refers to an enum (resolves the type first)
pub fn is_enum_type(
  registry: TypeRegistry,
  type_name: String,
  current_package: String,
) -> Bool {
  case resolve_type_reference(registry, type_name, current_package) {
    Ok(fqn) -> {
      case dict.get(registry.enums, fqn) {
        Ok(_) -> True
        Error(_) -> False
      }
    }
    Error(_) -> False
  }
}

/// Resolve a field type: if it's a MessageType that's actually an enum, convert it to EnumType
/// Also resolves the type name to its fully qualified name
pub fn resolve_field_type(
  registry: TypeRegistry,
  field_type: proto.Type,
  current_package: String,
) -> proto.Type {
  case field_type {
    proto.MessageType(name) -> {
      case resolve_type_reference(registry, name, current_package) {
        Ok(fqn) -> {
          case dict.get(registry.enums, fqn) {
            Ok(_) -> proto.EnumType(fqn)
            Error(_) -> proto.MessageType(fqn)
          }
        }
        Error(_) -> field_type
      }
    }
    proto.EnumType(name) -> {
      case resolve_type_reference(registry, name, current_package) {
        Ok(fqn) -> proto.EnumType(fqn)
        Error(_) -> field_type
      }
    }
    proto.Repeated(inner) ->
      proto.Repeated(resolve_field_type(registry, inner, current_package))
    proto.Optional(inner) ->
      proto.Optional(resolve_field_type(registry, inner, current_package))
    proto.Map(key, value) ->
      proto.Map(
        resolve_field_type(registry, key, current_package),
        resolve_field_type(registry, value, current_package),
      )
    _ -> field_type
  }
}
