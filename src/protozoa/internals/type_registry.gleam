import gleam/dict
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import protozoa/parser.{type Enum, type Message, type ProtoFile, type ProtoType}

/// A registry to hold all message and enum types across multiple proto files,
/// allowing for type resolution and lookup.
pub type TypeRegistry {
  TypeRegistry(
    messages: dict.Dict(String, Message),
    enums: dict.Dict(String, Enum),
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

/// Create a new, empty TypeRegistry.
pub fn new() -> TypeRegistry {
  TypeRegistry(
    messages: dict.new(),
    enums: dict.new(),
    type_sources: dict.new(),
    file_packages: dict.new(),
  )
}

/// Add types from a single ProtoFile to the TypeRegistry.
pub fn add_file(
  registry: TypeRegistry,
  file_path: String,
  proto_file: ProtoFile,
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
  message: Message,
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
  nested_messages: List(Message),
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
  enum: Enum,
  package: String,
  file_path: String,
) -> Result(TypeRegistry, Error) {
  let fqn = make_fully_qualified_name(package, enum.name)

  case dict.get(registry.enums, fqn) {
    Ok(_existing) -> {
      Error(DuplicateEnumDefinition(fqn))
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
    ..resolve_nested_type_candidates(type_name, current_package, registry)
  ]

  case
    list.find(candidates, fn(candidate) {
      case lookup_type(registry, candidate) {
        Some(_) -> True
        None -> False
      }
    })
  {
    Ok(resolved) -> Ok(resolved)
    Error(_) ->
      Error(
        "Unknown type: "
        <> type_name
        <> " (searched in package: "
        <> current_package
        <> ")",
      )
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


pub fn lookup_type(
  registry: TypeRegistry,
  fqn: String,
) -> Option(#(String, ProtoType)) {
  case dict.get(registry.messages, fqn) {
    Ok(msg) -> {
      case dict.get(registry.type_sources, fqn) {
        Ok(source) -> Some(#(source, parser.MessageType(msg.name)))
        Error(_) -> None
      }
    }
    Error(_) -> {
      case dict.get(registry.enums, fqn) {
        Ok(enum) -> {
          case dict.get(registry.type_sources, fqn) {
            Ok(source) -> Some(#(source, parser.EnumType(enum.name)))
            Error(_) -> None
          }
        }
        Error(_) -> None
      }
    }
  }
}


pub fn get_types_from_file(
  registry: TypeRegistry,
  file_path: String,
) -> List(#(String, ProtoType)) {
  dict.fold(registry.type_sources, [], fn(acc, fqn, source) {
    case source == file_path {
      False -> acc
      True -> {
        case lookup_type(registry, fqn) {
          Some(#(_source, proto_type)) -> [#(fqn, proto_type), ..acc]
          None -> acc
        }
      }
    }
  })
}


pub fn get_file_package(
  registry: TypeRegistry,
  file_path: String,
) -> Option(String) {
  case dict.get(registry.file_packages, file_path) {
    Ok(package) -> Some(package)
    Error(_) -> None
  }
}


pub fn get_type_source(registry: TypeRegistry, fqn: String) -> Option(String) {
  case dict.get(registry.type_sources, fqn) {
    Ok(source) -> Some(source)
    Error(_) -> None
  }
}
