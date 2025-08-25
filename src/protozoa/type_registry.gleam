import gleam/dict
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import protozoa/parser.{type Enum, type Message, type ProtoFile, type ProtoType}

pub type TypeRegistry {
  TypeRegistry(
    messages: dict.Dict(String, Message),
    enums: dict.Dict(String, Enum),
    type_sources: dict.Dict(String, String),
    file_packages: dict.Dict(String, String),
  )
}

pub fn new() -> TypeRegistry {
  TypeRegistry(
    messages: dict.new(),
    enums: dict.new(),
    type_sources: dict.new(),
    file_packages: dict.new(),
  )
}

pub fn build_registry(
  files: List(#(String, ProtoFile)),
) -> Result(TypeRegistry, String) {
  list.fold(files, Ok(new()), fn(acc, file_entry) {
    case acc {
      Error(e) -> Error(e)
      Ok(registry) -> {
        let #(file_path, proto_file) = file_entry
        add_file_to_registry(registry, file_path, proto_file)
      }
    }
  })
}

pub fn add_file_to_registry(
  registry: TypeRegistry,
  file_path: String,
  proto_file: ProtoFile,
) -> Result(TypeRegistry, String) {
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
) -> Result(TypeRegistry, String) {
  let fqn = make_fully_qualified_name(package, message.name)

  case dict.get(registry.messages, fqn) {
    Ok(_existing) -> {
      Error("Duplicate message definition: " <> fqn)
    }
    Error(_) -> {
      Ok(
        TypeRegistry(
          ..registry,
          messages: dict.insert(registry.messages, fqn, message),
          type_sources: dict.insert(registry.type_sources, fqn, file_path),
        ),
      )
    }
  }
}

fn add_enum(
  registry: TypeRegistry,
  enum: Enum,
  package: String,
  file_path: String,
) -> Result(TypeRegistry, String) {
  let fqn = make_fully_qualified_name(package, enum.name)

  case dict.get(registry.enums, fqn) {
    Ok(_existing) -> {
      Error("Duplicate enum definition: " <> fqn)
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
  type_name: String,
  current_package: String,
  registry: TypeRegistry,
) -> Result(String, String) {
  case string.contains(type_name, ".") {
    True -> {
      case lookup_type(registry, type_name) {
        Some(_) -> Ok(type_name)
        None -> Error("Unknown type: " <> type_name)
      }
    }
    False -> {
      let with_package = make_fully_qualified_name(current_package, type_name)
      case lookup_type(registry, with_package) {
        Some(_) -> Ok(with_package)
        None -> {
          case lookup_type(registry, type_name) {
            Some(_) -> Ok(type_name)
            None -> Error("Unknown type: " <> type_name)
          }
        }
      }
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
