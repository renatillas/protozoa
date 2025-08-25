//// Code generator module that produces Gleam code from Protocol Buffer definitions.
//// Uses the composable decode module for type-safe decoding.

import gleam/int
import gleam/list
import gleam/option
import gleam/result
import gleam/set
import gleam/string
import protozoa/parser.{
  type Enum, type Field, type Message, type Path, type ProtoFile, type ProtoType,
}
import protozoa/type_registry.{type TypeRegistry}
import simplifile

pub fn generate_with_imports(
  files files: List(Path),
  registry registry: TypeRegistry,
  output_dir output_dir: String,
) -> Result(List(#(String, String)), String) {
  // Generate code for each proto file
  list.try_map(files, fn(file_entry) {
    // Get the base name for the output file
    let base_name = get_base_name(file_entry.path)
    let output_path = output_dir <> "/" <> base_name <> ".gleam"

    // Generate code with cross-file imports
    use code <- result.try(generate_file_with_imports(
      file_entry.content,
      file_entry.path,
      registry,
    ))

    // Write the generated file
    use _ <- result.try(
      simplifile.write(output_path, code)
      |> result.map_error(fn(_) { "Failed to write file: " <> output_path }),
    )

    Ok(#(output_path, code))
  })
}

fn generate_file_with_imports(
  proto_file: ProtoFile,
  file_path: String,
  registry: TypeRegistry,
) -> Result(String, String) {
  // Get all external types referenced in this file
  let external_refs = find_external_references(proto_file, file_path, registry)

  // Generate import statements for external types
  let extra_imports =
    generate_cross_file_imports(external_refs, file_path, registry)

  // Generate the code with awareness of external types
  let imports = generate_smart_imports_with_externals(proto_file, extra_imports)
  let enum_types = generate_enum_types(proto_file.enums)
  let types =
    generate_types_with_registry(proto_file.messages, registry, file_path)
  let encoders =
    generate_encoders_with_registry(proto_file.messages, registry, file_path)
  let decoders =
    generate_decoders_with_registry(proto_file.messages, registry, file_path)
  let enum_helpers = generate_enum_helpers(proto_file.enums)

  Ok(string.join(
    [
      imports,
      "",
      enum_types,
      "",
      types,
      "",
      encoders,
      "",
      decoders,
      "",
      enum_helpers,
    ],
    "\n",
  ))
}

fn get_base_name(file_path: String) -> String {
  file_path
  |> string.split("/")
  |> list.last()
  |> result.unwrap("")
  |> string.split(".")
  |> list.first()
  |> result.unwrap("generated")
}

fn find_external_references(
  proto_file: ProtoFile,
  file_path: String,
  registry: TypeRegistry,
) -> List(#(String, String)) {
  // Find all type references in messages
  let refs =
    list.flat_map(proto_file.messages, fn(msg) {
      list.flat_map(msg.fields, fn(field) {
        extract_type_references(field.field_type)
      })
    })

  // Filter to only external types
  list.filter_map(refs, fn(type_name) {
    case
      type_registry.resolve_type_reference(
        registry,
        type_name,
        option.unwrap(proto_file.package, ""),
      )
    {
      Ok(fqn) -> {
        case type_registry.get_type_source(registry, fqn) {
          option.Some(source) if source != file_path -> {
            Ok(#(fqn, source))
          }
          _ -> Error(Nil)
        }
      }
      Error(_) -> Error(Nil)
    }
  })
  |> list.unique()
}

fn extract_type_references(proto_type: ProtoType) -> List(String) {
  case proto_type {
    parser.MessageType(name) -> [name]
    parser.EnumType(name) -> [name]
    parser.Repeated(inner) -> extract_type_references(inner)
    parser.Optional(inner) -> extract_type_references(inner)
    parser.Map(_, value_type) -> extract_type_references(value_type)
    _ -> []
  }
}

fn generate_cross_file_imports(
  external_refs: List(#(String, String)),
  _current_file: String,
  _registry: TypeRegistry,
) -> List(String) {
  external_refs
  |> list.map(fn(ref) {
    let #(_fqn, source_file) = ref
    let module_name = get_base_name(source_file)
    "import generated/" <> module_name
  })
  |> list.unique()
}

fn generate_smart_imports_with_externals(
  proto_file: ProtoFile,
  extra_imports: List(String),
) -> String {
  let base_imports = generate_smart_imports(proto_file)
  case extra_imports {
    [] -> base_imports
    imports -> {
      base_imports <> "\n" <> string.join(imports, "\n")
    }
  }
}

fn generate_types_with_registry(
  messages: List(Message),
  registry: TypeRegistry,
  file_path: String,
) -> String {
  messages
  |> list.map(fn(msg) { generate_type_with_registry(msg, registry, file_path) })
  |> string.join("\n\n")
}

fn generate_type_with_registry(
  message: Message,
  registry: TypeRegistry,
  file_path: String,
) -> String {
  let fields =
    message.fields
    |> list.map(fn(field) {
      let field_type = resolve_field_type(field.field_type, registry, file_path)
      "  " <> field.name <> ": " <> field_type
    })
    |> string.join(",\n")

  let oneofs =
    message.oneofs
    |> list.map(fn(oneof) {
      "  "
      <> oneof.name
      <> ": option.Option("
      <> message.name
      <> capitalize_first(oneof.name)
      <> ")"
    })
    |> string.join(",\n")

  let all_fields = case message.oneofs {
    [] -> fields
    _ -> fields <> ",\n" <> oneofs
  }

  let type_def =
    "pub type "
    <> message.name
    <> " {\n  "
    <> message.name
    <> "(\n"
    <> all_fields
    <> "\n  )\n}"

  let oneof_types =
    message.oneofs
    |> list.map(fn(oneof) {
      generate_oneof_type_with_registry(
        message.name,
        oneof,
        registry,
        file_path,
      )
    })
    |> string.join("\n\n")

  case oneof_types {
    "" -> type_def
    _ -> type_def <> "\n\n" <> oneof_types
  }
}

fn resolve_field_type(
  proto_type: ProtoType,
  registry: TypeRegistry,
  file_path: String,
) -> String {
  case proto_type {
    parser.MessageType(name) -> {
      // Try to resolve the type to check if it's external
      case type_registry.resolve_type_reference(registry, name, "") {
        Ok(fqn) -> {
          case type_registry.get_type_source(registry, fqn) {
            option.Some(source) if source != file_path -> {
              // External type - use module prefix
              let module_name = get_base_name(source)
              "generated/" <> module_name <> "." <> get_type_name(fqn)
            }
            _ -> name
            // Local type
          }
        }
        Error(_) -> name
        // Fallback to original name
      }
    }
    parser.EnumType(name) -> {
      // Similar logic for enums
      case type_registry.resolve_type_reference(registry, name, "") {
        Ok(fqn) -> {
          case type_registry.get_type_source(registry, fqn) {
            option.Some(source) if source != file_path -> {
              let module_name = get_base_name(source)
              "generated/" <> module_name <> "." <> get_type_name(fqn)
            }
            _ -> name
          }
        }
        Error(_) -> name
      }
    }
    parser.Repeated(inner) ->
      "List(" <> resolve_field_type(inner, registry, file_path) <> ")"
    parser.Optional(inner) ->
      "option.Option(" <> resolve_field_type(inner, registry, file_path) <> ")"
    parser.Map(key_type, value_type) -> {
      "dict.Dict("
      <> gleam_type_for_proto(key_type)
      <> ", "
      <> resolve_field_type(value_type, registry, file_path)
      <> ")"
    }
    _ -> gleam_type_for_proto(proto_type)
  }
}

fn get_type_name(fqn: String) -> String {
  fqn
  |> string.split(".")
  |> list.last()
  |> result.unwrap(fqn)
}

fn generate_oneof_type_with_registry(
  message_name: String,
  oneof: parser.Oneof,
  registry: TypeRegistry,
  file_path: String,
) -> String {
  let variants =
    oneof.fields
    |> list.map(fn(field) {
      let field_type = resolve_field_type(field.field_type, registry, file_path)
      "  " <> capitalize_first(field.name) <> "(" <> field_type <> ")"
    })
    |> string.join("\n")

  "pub type "
  <> message_name
  <> capitalize_first(oneof.name)
  <> " {\n"
  <> variants
  <> "\n}"
}

fn generate_encoders_with_registry(
  messages: List(Message),
  _registry: TypeRegistry,
  _file_path: String,
) -> String {
  // For now, use existing encoders as they don't need type resolution
  generate_encoders(messages)
}

fn generate_decoders_with_registry(
  messages: List(Message),
  _registry: TypeRegistry,
  _file_path: String,
) -> String {
  // For now, use existing decoders as they don't need type resolution
  generate_decoders(messages)
}

/// Generates Gleam code from a parsed Protocol Buffer file.
/// Produces type definitions, encoders, and decoders for all messages and enums.
/// 
/// ## Examples
/// 
/// ```gleam
/// let proto_file = parser.parse(proto_content)
/// let gleam_code = generate_simple(proto_file)
/// ```
pub fn generate_simple(proto_file: ProtoFile) -> String {
  let imports = generate_smart_imports(proto_file)
  let enum_types = generate_enum_types(proto_file.enums)
  let types = generate_types(proto_file.messages)
  let encoders = generate_encoders(proto_file.messages)
  let decoders = generate_decoders(proto_file.messages)
  let enum_helpers = generate_enum_helpers(proto_file.enums)

  string.join(
    [
      imports,
      "",
      enum_types,
      "",
      types,
      "",
      encoders,
      "",
      decoders,
      "",
      enum_helpers,
    ],
    "\n",
  )
}

fn generate_smart_imports(proto_file: ProtoFile) -> String {
  // Check what features are actually used
  let has_repeated =
    list.any(proto_file.messages, fn(msg) {
      list.any(msg.fields, fn(field) {
        case field.field_type {
          parser.Repeated(_) -> True
          _ -> False
        }
      })
    })

  let has_optional =
    list.any(proto_file.messages, fn(msg) {
      list.any(msg.fields, fn(field) {
        case field.field_type {
          parser.Optional(_) -> True
          _ -> False
        }
      })
    })

  let has_oneof =
    list.any(proto_file.messages, fn(msg) { !list.is_empty(msg.oneofs) })
  let has_enums = !list.is_empty(proto_file.enums)

  let has_map =
    list.any(proto_file.messages, fn(msg) {
      list.any(msg.fields, fn(field) {
        case field.field_type {
          parser.Map(_, _) -> True
          _ -> False
        }
      })
    })

  let needs_wire =
    list.any(proto_file.messages, fn(msg) {
      // Check regular fields
      let has_special_fields =
        list.any(msg.fields, fn(field) {
          case field.field_type {
            parser.Bytes -> True
            parser.MessageType(_) -> True
            parser.Optional(parser.MessageType(_)) -> True
            parser.Map(_, _) -> True
            _ -> False
          }
        })

      // Check oneof fields for message types
      let has_oneof_messages =
        list.any(msg.oneofs, fn(oneof) {
          list.any(oneof.fields, fn(field) {
            case field.field_type {
              parser.MessageType(_) -> True
              _ -> False
            }
          })
        })
      has_special_fields || has_oneof_messages
    })

  // Build imports based on what's needed
  let base_imports = [
    "import protozoa/decode",
    "import protozoa/encode",
  ]

  let conditional_imports =
    set.new()
    |> add_to_set_if_used(has_enums, "import gleam/int")
    |> add_to_set_if_used(has_enums, "import gleam/result")
    |> add_to_set_if_used(has_oneof, "import gleam/dict")
    |> add_to_set_if_used(has_oneof, "import gleam/option")
    |> add_to_set_if_used(has_repeated, "import gleam/list")
    |> add_to_set_if_used(needs_wire, "import protozoa/wire")
    |> add_to_set_if_used(has_map, "import gleam/list")
    |> add_to_set_if_used(
      has_optional,
      "import gleam/option.{type Option, None, Some}",
    )

  string.join(
    set.to_list(set.union(conditional_imports, set.from_list(base_imports))),
    "\n",
  )
}

fn add_to_set_if_used(
  imports: set.Set(String),
  condition: Bool,
  import_: String,
) -> set.Set(String) {
  case condition {
    True -> set.insert(imports, import_)
    False -> imports
  }
}

fn generate_types(messages: List(Message)) -> String {
  messages
  |> list.map(generate_message_type)
  |> list.flatten
  |> string.join("\n\n")
}

fn generate_message_type(message: Message) -> List(String) {
  // Generate oneof types first
  let oneof_types =
    message.oneofs
    |> list.map(fn(oneof) { generate_oneof_type(message.name, oneof) })

  // Generate regular fields
  let regular_fields =
    message.fields
    |> list.map(fn(field) {
      let field_type = gleam_type_for_proto(field.field_type)
      "  " <> field.name <> ": " <> field_type
    })

  // Generate oneof fields (as Result types)
  let oneof_fields =
    message.oneofs
    |> list.map(fn(oneof) {
      let oneof_type = message.name <> capitalize_first(oneof.name)
      "  " <> oneof.name <> ": option.Option(" <> oneof_type <> ")"
    })

  let all_fields = list.append(regular_fields, oneof_fields)
  let fields_str = string.join(all_fields, ",\n")

  let message_type =
    "pub type "
    <> message.name
    <> " {\n  "
    <> message.name
    <> "(\n"
    <> fields_str
    <> "\n  )\n}"

  list.append(oneof_types, [message_type])
}

fn generate_oneof_type(message_name: String, oneof: parser.Oneof) -> String {
  let type_name = message_name <> capitalize_first(oneof.name)

  let variants =
    oneof.fields
    |> list.map(fn(field) {
      let field_type = gleam_type_for_proto(field.field_type)
      "  " <> capitalize_first(field.name) <> "(" <> field_type <> ")"
    })
    |> string.join("\n")

  "pub type " <> type_name <> " {\n" <> variants <> "\n}"
}

fn capitalize_first(str: String) -> String {
  // Split by underscore and capitalize each part for PascalCase
  str
  |> string.split("_")
  |> list.map(fn(part) {
    case string.to_graphemes(part) {
      [first, ..rest] -> string.uppercase(first) <> string.join(rest, "")
      [] -> part
    }
  })
  |> string.join("")
}

fn gleam_type_for_proto(proto_type: ProtoType) -> String {
  case proto_type {
    parser.Double | parser.Float -> "Float"
    parser.Int32
    | parser.Int64
    | parser.UInt32
    | parser.UInt64
    | parser.SInt32
    | parser.SInt64
    | parser.Fixed32
    | parser.Fixed64
    | parser.SFixed32
    | parser.SFixed64 -> "Int"
    parser.Bool -> "Bool"
    parser.String -> "String"
    parser.Bytes -> "BitArray"
    parser.MessageType(name) -> name
    parser.EnumType(name) -> name
    parser.Repeated(inner) -> "List(" <> gleam_type_for_proto(inner) <> ")"
    parser.Optional(inner) -> "Option(" <> gleam_type_for_proto(inner) <> ")"
    parser.Map(key, value) ->
      "List(#("
      <> gleam_type_for_proto(key)
      <> ", "
      <> gleam_type_for_proto(value)
      <> "))"
  }
}

fn generate_encoders(messages: List(Message)) -> String {
  messages
  |> list.map(generate_message_encoder)
  |> string.join("\n\n")
}

fn generate_message_encoder(message: Message) -> String {
  let function_name = "encode_" <> string.lowercase(message.name)

  // Check if message is empty (no fields and no oneofs)
  let is_empty = list.is_empty(message.fields) && list.is_empty(message.oneofs)

  // Use underscore prefix for unused parameters in empty messages
  let param_name = case is_empty {
    True -> "_" <> string.lowercase(message.name)
    False -> string.lowercase(message.name)
  }

  // Separate repeated, map, and regular fields
  let #(repeated_fields, non_repeated) =
    list.partition(message.fields, fn(field) {
      case field.field_type {
        parser.Repeated(_) -> True
        _ -> False
      }
    })

  let #(map_fields, regular_fields) =
    list.partition(non_repeated, fn(field) {
      case field.field_type {
        parser.Map(_, _) -> True
        _ -> False
      }
    })

  let regular_encoders =
    regular_fields
    |> list.map(fn(field) { generate_field_encoder(field, param_name) })

  // Generate oneof encoders
  let oneof_encoders =
    message.oneofs
    |> list.map(fn(oneof) {
      generate_oneof_encoder(message.name, oneof, param_name)
    })

  let repeated_code = case repeated_fields {
    [] -> ""
    fields -> {
      fields
      |> list.map(fn(field) { generate_repeated_field_code(field, param_name) })
      |> string.join("\n  ")
    }
  }

  let map_code = case map_fields {
    [] -> ""
    fields -> {
      fields
      |> list.map(fn(field) { generate_map_field_code(field, param_name) })
      |> string.join("\n  ")
    }
  }

  // Combine all encoders
  let all_regular_encoders = list.append(regular_encoders, oneof_encoders)

  case repeated_fields, map_fields {
    [], [] -> {
      // No repeated or map fields, simple case
      let field_encoders = string.join(all_regular_encoders, ",\n    ")
      "pub fn "
      <> function_name
      <> "("
      <> param_name
      <> ": "
      <> message.name
      <> ") -> BitArray {
  encode.message([
    "
      <> field_encoders
      <> "
  ])
}"
    }
    _, _ -> {
      // Has repeated fields, need to handle them separately
      let regular_list = case all_regular_encoders {
        [] -> "[]"
        encoders -> "[\n    " <> string.join(encoders, ",\n    ") <> "\n  ]"
      }

      "pub fn "
      <> function_name
      <> "("
      <> param_name
      <> ": "
      <> message.name
      <> ") -> BitArray {
  "
      <> repeated_code
      <> case map_code {
        "" -> ""
        code -> "\n  " <> code
      }
      <> "
  let other_fields = "
      <> regular_list
      <> "
  "
      <> case repeated_fields, map_fields {
        [], [] -> "encode.message(other_fields)"
        [], maps -> {
          "encode.message(list.append(other_fields, list.flatten(["
          <> string.join(
            list.map(maps, fn(f) { string.lowercase(f.name) <> "_fields" }),
            ", ",
          )
          <> "])))"
        }
        reps, [] -> {
          "encode.message(list.append(other_fields, list.flatten(["
          <> string.join(
            list.map(reps, fn(f) { string.lowercase(f.name) <> "_fields" }),
            ", ",
          )
          <> "])))"
        }
        reps, maps -> {
          "encode.message(list.append(other_fields, list.flatten(["
          <> string.join(
            list.append(
              list.map(reps, fn(f) { string.lowercase(f.name) <> "_fields" }),
              list.map(maps, fn(f) { string.lowercase(f.name) <> "_fields" }),
            ),
            ", ",
          )
          <> "])))"
        }
      }
      <> "
}"
    }
  }
}

fn generate_field_encoder(field: Field, param_name: String) -> String {
  let field_access = param_name <> "." <> field.name
  let field_num = int.to_string(field.number)

  case field.field_type {
    parser.Int32 ->
      "encode.int32_field(" <> field_num <> ", " <> field_access <> ")"

    parser.Int64 ->
      "encode.int64_field(" <> field_num <> ", " <> field_access <> ")"

    parser.UInt32 ->
      "encode.uint32_field(" <> field_num <> ", " <> field_access <> ")"

    parser.UInt64 ->
      "encode.uint64_field(" <> field_num <> ", " <> field_access <> ")"

    parser.SInt32 ->
      "encode.sint32_field(" <> field_num <> ", " <> field_access <> ")"

    parser.SInt64 ->
      "encode.sint64_field(" <> field_num <> ", " <> field_access <> ")"

    parser.Float ->
      "encode.float_field(" <> field_num <> ", " <> field_access <> ")"

    parser.Double ->
      "encode.double_field(" <> field_num <> ", " <> field_access <> ")"

    parser.Bool ->
      "encode.bool_field(" <> field_num <> ", " <> field_access <> ")"

    parser.String ->
      "encode.string_field(" <> field_num <> ", " <> field_access <> ")"

    parser.Bytes ->
      "encode.field("
      <> field_num
      <> ", wire.LengthDelimited, encode.length_delimited("
      <> field_access
      <> "))"

    parser.MessageType(type_name) -> {
      let encoder_name = "encode_" <> string.lowercase(type_name)
      "encode.field("
      <> field_num
      <> ", wire.LengthDelimited, encode.length_delimited("
      <> encoder_name
      <> "("
      <> field_access
      <> ")))"
    }

    parser.EnumType(enum_name) -> {
      let encoder_name = "encode_" <> string.lowercase(enum_name) <> "_value"
      "encode.int32_field("
      <> field_num
      <> ", "
      <> encoder_name
      <> "("
      <> field_access
      <> "))"
    }

    parser.Repeated(_) -> {
      // Handled separately
      "// Repeated field handled separately"
    }

    parser.Optional(inner) -> {
      // Generate encoder for optional field
      "case " <> field_access <> " {
        Some(value) -> " <> generate_optional_field_encoder(
        inner,
        field.number,
        "value",
      ) <> "
        None -> <<>>
      }"
    }

    parser.Map(key_type, value_type) -> {
      // Maps are encoded as repeated message fields with key and value
      generate_map_field_encoder(field, key_type, value_type, param_name)
    }

    _ -> "// TODO: Unsupported type"
  }
}

fn generate_map_field_code(field: Field, param_name: String) -> String {
  case field.field_type {
    parser.Map(key_type, value_type) -> {
      let field_access = param_name <> "." <> field.name
      let field_var = string.lowercase(field.name) <> "_fields"
      let field_num = int.to_string(field.number)

      "let " <> field_var <> " = list.map(" <> field_access <> ", fn(entry) {
    let #(key, value) = entry
    encode.field(" <> field_num <> ", wire.LengthDelimited, encode.length_delimited(
      encode.message([
        " <> generate_map_key_encoder(key_type, "key") <> ",
        " <> generate_map_value_encoder(value_type, "value") <> "
      ])
    ))
  })"
    }
    _ -> "// Not a map field"
  }
}

fn generate_map_field_encoder(
  field: Field,
  key_type: ProtoType,
  value_type: ProtoType,
  param_name: String,
) -> String {
  let field_access = param_name <> "." <> field.name
  let field_num = int.to_string(field.number)

  // Maps are encoded as repeated message fields, each with key=1 and value=2
  "list.map(" <> field_access <> ", fn(entry) {
    let #(key, value) = entry
    encode.field(" <> field_num <> ", wire.LengthDelimited, encode.length_delimited(
      encode.message([
        " <> generate_map_key_encoder(key_type, "key") <> ",
        " <> generate_map_value_encoder(value_type, "value") <> "
      ])
    ))
  })
  |> list.flatten"
}

fn generate_map_key_encoder(key_type: ProtoType, access: String) -> String {
  case key_type {
    parser.String -> "encode.string_field(1, " <> access <> ")"
    parser.Int32
    | parser.Int64
    | parser.UInt32
    | parser.UInt64
    | parser.SInt32
    | parser.SInt64 -> "encode.int32_field(1, " <> access <> ")"
    parser.Bool -> "encode.bool_field(1, " <> access <> ")"
    _ -> "// TODO: Unsupported map key type"
  }
}

fn generate_map_value_encoder(value_type: ProtoType, access: String) -> String {
  case value_type {
    parser.String -> "encode.string_field(2, " <> access <> ")"
    parser.Int32
    | parser.Int64
    | parser.UInt32
    | parser.UInt64
    | parser.SInt32
    | parser.SInt64 -> "encode.int32_field(2, " <> access <> ")"
    parser.Bool -> "encode.bool_field(2, " <> access <> ")"
    parser.MessageType(type_name) -> {
      let encoder_name = "encode_" <> string.lowercase(type_name)
      "encode.field(2, wire.LengthDelimited, encode.length_delimited("
      <> encoder_name
      <> "("
      <> access
      <> ")))"
    }
    _ -> "// TODO: Unsupported map value type"
  }
}

fn generate_optional_field_encoder(
  field_type: ProtoType,
  field_num: Int,
  value_access: String,
) -> String {
  generate_field_encoder_for_type(field_type, field_num, value_access)
}

fn generate_oneof_encoder(
  _message_name: String,
  oneof: parser.Oneof,
  param_name: String,
) -> String {
  let oneof_access = param_name <> "." <> oneof.name

  // Generate case expression for the oneof
  let cases =
    oneof.fields
    |> list.map(fn(field) {
      let variant_name = capitalize_first(field.name)
      let encoder =
        generate_field_encoder_for_type(field.field_type, field.number, "value")
      "      " <> variant_name <> "(value) -> " <> encoder
    })
    |> string.join("\n")

  "case " <> oneof_access <> " {
    option.Some(oneof_value) -> {
      case oneof_value {
" <> cases <> "
      }
    }
    option.None -> <<>>
  }"
}

fn generate_field_encoder_for_type(
  field_type: ProtoType,
  field_num: Int,
  value_access: String,
) -> String {
  let num_str = int.to_string(field_num)

  case field_type {
    parser.Int32 ->
      "encode.int32_field(" <> num_str <> ", " <> value_access <> ")"

    parser.Int64 ->
      "encode.int64_field(" <> num_str <> ", " <> value_access <> ")"

    parser.UInt32 ->
      "encode.uint32_field(" <> num_str <> ", " <> value_access <> ")"

    parser.UInt64 ->
      "encode.uint64_field(" <> num_str <> ", " <> value_access <> ")"

    parser.SInt32 ->
      "encode.sint32_field(" <> num_str <> ", " <> value_access <> ")"

    parser.SInt64 ->
      "encode.sint64_field(" <> num_str <> ", " <> value_access <> ")"

    parser.Float ->
      "encode.float_field(" <> num_str <> ", " <> value_access <> ")"

    parser.Double ->
      "encode.double_field(" <> num_str <> ", " <> value_access <> ")"

    parser.Bool ->
      "encode.bool_field(" <> num_str <> ", " <> value_access <> ")"

    parser.String ->
      "encode.string_field(" <> num_str <> ", " <> value_access <> ")"

    parser.Bytes ->
      "encode.field("
      <> num_str
      <> ", wire.LengthDelimited, encode.length_delimited("
      <> value_access
      <> "))"

    parser.MessageType(type_name) -> {
      let encoder_name = "encode_" <> string.lowercase(type_name)
      "encode.field("
      <> num_str
      <> ", wire.LengthDelimited, encode.length_delimited("
      <> encoder_name
      <> "("
      <> value_access
      <> ")))"
    }

    parser.EnumType(enum_name) -> {
      let encoder_name = "encode_" <> string.lowercase(enum_name) <> "_value"
      "encode.int32_field("
      <> num_str
      <> ", "
      <> encoder_name
      <> "("
      <> value_access
      <> "))"
    }

    _ -> "<<>>"
  }
}

fn generate_repeated_field_code(field: Field, param_name: String) -> String {
  let field_access = param_name <> "." <> field.name
  let field_var = string.lowercase(field.name) <> "_fields"
  let num_str = int.to_string(field.number)

  case field.field_type {
    parser.Repeated(parser.String) ->
      "let "
      <> field_var
      <> " = list.map("
      <> field_access
      <> ", fn(v) { encode.string_field("
      <> num_str
      <> ", v) })"
    parser.Repeated(parser.Int32) ->
      "let "
      <> field_var
      <> " = list.map("
      <> field_access
      <> ", fn(v) { encode.int32_field("
      <> num_str
      <> ", v) })"
    parser.Repeated(parser.Int64) ->
      "let "
      <> field_var
      <> " = list.map("
      <> field_access
      <> ", fn(v) { encode.int64_field("
      <> num_str
      <> ", v) })"
    parser.Repeated(parser.EnumType(enum_name)) ->
      "let "
      <> field_var
      <> " = list.map("
      <> field_access
      <> ", fn(v) { encode.int32_field("
      <> num_str
      <> ", encode_"
      <> string.lowercase(enum_name)
      <> "_value(v)) })"
    _ -> "let " <> field_var <> " = [] // TODO: Repeated encoder for this type"
  }
}

fn generate_decoders(messages: List(Message)) -> String {
  messages
  |> list.map(generate_message_decoder_composable)
  |> string.join("\n\n")
}

fn generate_message_decoder_composable(message: Message) -> String {
  let decoder_name = "decode_" <> string.lowercase(message.name)
  let message_decoder_name = string.lowercase(message.name) <> "_decoder"

  // Generate the decoder function
  let decoder_body = generate_decoder_body(message)

  // Generate oneof helper decoder functions
  let oneof_decoders =
    message.oneofs
    |> list.map(fn(oneof) { generate_oneof_helper_decoder(message.name, oneof) })
    |> string.join("\n\n")

  // Generate map entry decoder functions
  let map_decoders =
    message.fields
    |> list.filter_map(fn(field) {
      case field.field_type {
        parser.Map(key_type, value_type) ->
          Ok(generate_map_entry_decoder(field.number, key_type, value_type))
        _ -> Error(Nil)
      }
    })
    |> string.join("\n\n")

  let helper_decoders = case oneof_decoders, map_decoders {
    "", "" -> ""
    o, "" -> "\n\n" <> o
    "", m -> "\n\n" <> m
    o, m -> "\n\n" <> o <> "\n\n" <> m
  }

  "pub fn "
  <> message_decoder_name
  <> "() -> decode.Decoder("
  <> message.name
  <> ") {
"
  <> decoder_body
  <> "
}

pub fn "
  <> decoder_name
  <> "(data: BitArray) -> Result("
  <> message.name
  <> ", decode.DecodeError) {
  decode.decode(data, "
  <> message_decoder_name
  <> "())
}"
  <> helper_decoders
}

fn generate_decoder_body(message: Message) -> String {
  // Generate decoders using the subrecord pattern
  let field_bindings =
    message.fields
    |> list.map(fn(field) {
      let decoder = generate_field_decoder_composable(field)
      "  use " <> field.name <> " <- decode.subrecord(" <> decoder <> ")"
    })

  let oneof_bindings =
    message.oneofs
    |> list.map(fn(oneof) {
      let decoder = generate_oneof_decoder(message.name, oneof)
      "  use " <> oneof.name <> " <- decode.subrecord(" <> decoder <> ")"
    })

  let all_bindings = list.append(field_bindings, oneof_bindings)

  // Build the constructor call
  let field_names = list.map(message.fields, fn(f) { f.name <> ": " <> f.name })
  let oneof_names = list.map(message.oneofs, fn(o) { o.name <> ": " <> o.name })
  let all_field_names = list.append(field_names, oneof_names)

  case all_bindings {
    [] -> "  decode.success(" <> message.name <> ")"
    _ -> {
      let bindings_str = string.join(all_bindings, "\n")
      let fields_str = string.join(all_field_names, ", ")

      bindings_str
      <> "\n  decode.success("
      <> message.name
      <> "("
      <> fields_str
      <> "))"
    }
  }
}

fn generate_oneof_decoder(_message_name: String, oneof: parser.Oneof) -> String {
  // Generate a call to a helper decoder function
  let decoder_name = "oneof_" <> string.lowercase(oneof.name) <> "_decoder()"
  decoder_name
}

fn generate_oneof_helper_decoder(
  message_name: String,
  oneof: parser.Oneof,
) -> String {
  // Generate the oneof type name
  let oneof_type = message_name <> capitalize_first(oneof.name)
  let decoder_name = "oneof_" <> string.lowercase(oneof.name) <> "_decoder"

  // Generate field checks for the oneof
  let field_checks =
    oneof.fields
    |> list.map(fn(field) {
      let variant_name = capitalize_first(field.name)
      let field_decoder = generate_oneof_field_decoder(field)
      let field_num = int.to_string(field.number)

      #(field_num, field_decoder, variant_name)
    })

  case field_checks {
    [] ->
      "fn "
      <> decoder_name
      <> "() -> decode.Decoder(option.Option("
      <> oneof_type
      <> ")) {
  decode.success(Error(Nil))
}"
    _ -> {
      // Build the nested case expressions that try each field
      let decoder_body =
        build_oneof_decoder_body(field_checks, oneof_type, "    ")

      "fn "
      <> decoder_name
      <> "() -> decode.Decoder(option.Option("
      <> oneof_type
      <> ")) {
  decode.from_field_dict(fn(fields) {
"
      <> decoder_body
      <> "
  })
}"
    }
  }
}

fn build_oneof_decoder_body(
  fields: List(#(String, String, String)),
  oneof_type: String,
  indent: String,
) -> String {
  case fields {
    [] -> indent <> "Ok(option.None)"
    [#(field_num, decoder, variant)] -> {
      indent <> "case dict.get(fields, " <> field_num <> ") {
" <> indent <> "  Ok([field, ..]) -> {
" <> indent <> "    case " <> decoder <> "(field) {
" <> indent <> "      Ok(value) -> Ok(option.Some(" <> variant <> "(value)))
" <> indent <> "      Error(_) -> Ok(option.None)
" <> indent <> "    }
" <> indent <> "  }
" <> indent <> "  Ok([]) -> Ok(option.None)
" <> indent <> "  Error(_) -> Ok(option.None)
" <> indent <> "}"
    }
    [#(field_num, decoder, variant), ..rest] -> {
      indent <> "case dict.get(fields, " <> field_num <> ") {
" <> indent <> "  Ok([field, ..]) -> {
" <> indent <> "    case " <> decoder <> "(field) {
" <> indent <> "      Ok(value) -> Ok(option.Some(" <> variant <> "(value)))
" <> indent <> "      Error(_) -> {
" <> build_oneof_decoder_body(rest, oneof_type, indent <> "        ") <> "
" <> indent <> "      }
" <> indent <> "    }
" <> indent <> "  }
" <> indent <> "  _ -> {
" <> build_oneof_decoder_body(rest, oneof_type, indent <> "    ") <> "
" <> indent <> "  }
" <> indent <> "}"
    }
  }
}

fn generate_oneof_field_decoder(field: Field) -> String {
  case field.field_type {
    parser.Int32 -> "decode.int32_field"
    parser.Int64 -> "decode.int64_field"
    parser.String -> "decode.string_field"
    parser.Bool -> "decode.bool_field"
    parser.Bytes -> "decode.bytes_field"
    parser.Float -> "decode.float_field"
    parser.Double -> "decode.double_field"
    parser.MessageType(type_name) ->
      "fn(f) { decode.message_field(f, "
      <> string.lowercase(type_name)
      <> "_decoder()) }"
    _ ->
      "fn(_) { Error(decode.InvalidField(\"Unsupported oneof field type\")) }"
  }
}

fn generate_field_decoder_composable(field: Field) -> String {
  let field_num = int.to_string(field.number)

  case field.field_type {
    parser.Int32 -> "decode.int32_with_default(" <> field_num <> ", 0)"

    parser.Int64 -> "decode.int64_with_default(" <> field_num <> ", 0)"

    parser.UInt32 -> "decode.uint32_with_default(" <> field_num <> ", 0)"

    parser.UInt64 -> "decode.uint64_with_default(" <> field_num <> ", 0)"

    parser.SInt32 -> "decode.sint32(" <> field_num <> ")"

    parser.SInt64 -> "decode.sint64(" <> field_num <> ")"

    parser.Float -> "decode.float(" <> field_num <> ")"

    parser.Double -> "decode.double(" <> field_num <> ")"

    parser.Bool -> "decode.bool_with_default(" <> field_num <> ", False)"

    parser.String -> "decode.string_with_default(" <> field_num <> ", \"\")"

    parser.Bytes -> "decode.bytes(" <> field_num <> ")"

    parser.MessageType(type_name) ->
      "decode.nested_message("
      <> field_num
      <> ", "
      <> string.lowercase(type_name)
      <> "_decoder())"

    parser.EnumType(enum_name) -> {
      let decoder_name = "decode_" <> string.lowercase(enum_name) <> "_field"
      decoder_name <> "(" <> field_num <> ")"
    }

    parser.Repeated(parser.String) ->
      "decode.repeated_string(" <> field_num <> ")"

    parser.Repeated(parser.Int32) ->
      "decode.repeated_int32(" <> field_num <> ")"

    parser.Repeated(parser.Int64) ->
      "decode.repeated_int64(" <> field_num <> ")"

    parser.Repeated(parser.EnumType(enum_name)) -> {
      let decoder_name = "decode_repeated_" <> string.lowercase(enum_name)
      decoder_name <> "(" <> field_num <> ")"
    }

    parser.Optional(inner) -> {
      generate_optional_field_decoder(inner, field.number)
    }

    parser.Map(key_type, value_type) ->
      generate_map_field_decoder(field.number, key_type, value_type)

    _ -> "decode.fail(\"Unsupported field type\")"
  }
}

fn generate_map_field_decoder(
  field_num: Int,
  _key_type: ProtoType,
  _value_type: ProtoType,
) -> String {
  let num_str = int.to_string(field_num)

  // Maps are decoded as repeated message fields with key=1 and value=2
  "decode.repeated_field(" <> num_str <> ", fn(field) {
    decode.message_field(field, map_entry_" <> num_str <> "_decoder())
  })"
}

fn generate_map_entry_decoder(
  field_num: Int,
  key_type: ProtoType,
  value_type: ProtoType,
) -> String {
  let num_str = int.to_string(field_num)

  "fn map_entry_"
  <> num_str
  <> "_decoder() -> decode.Decoder(#("
  <> gleam_type_for_proto(key_type)
  <> ", "
  <> gleam_type_for_proto(value_type)
  <> ")) {
  use key <- decode.subrecord("
  <> generate_map_key_decoder(key_type)
  <> ")
  use value <- decode.subrecord("
  <> generate_map_value_decoder(value_type)
  <> ")
  decode.success(#(key, value))
}"
}

fn generate_map_key_decoder(key_type: ProtoType) -> String {
  case key_type {
    parser.String -> "decode.string_with_default(1, \"\")"
    parser.Int32 -> "decode.int32_with_default(1, 0)"
    parser.Int64 -> "decode.int64_with_default(1, 0)"
    parser.UInt32 -> "decode.uint32_with_default(1, 0)"
    parser.UInt64 -> "decode.uint64_with_default(1, 0)"
    parser.SInt32 -> "decode.sint32(1)"
    parser.SInt64 -> "decode.sint64(1)"
    parser.Bool -> "decode.bool_with_default(1, False)"
    _ -> "decode.fail(\"Unsupported map key type\")"
  }
}

fn generate_map_value_decoder(value_type: ProtoType) -> String {
  case value_type {
    parser.String -> "decode.string_with_default(2, \"\")"
    parser.Int32 -> "decode.int32_with_default(2, 0)"
    parser.Int64 -> "decode.int64_with_default(2, 0)"
    parser.UInt32 -> "decode.uint32_with_default(2, 0)"
    parser.UInt64 -> "decode.uint64_with_default(2, 0)"
    parser.SInt32 -> "decode.sint32(2)"
    parser.SInt64 -> "decode.sint64(2)"
    parser.Bool -> "decode.bool_with_default(2, False)"
    parser.MessageType(type_name) ->
      "decode.nested_message(2, "
      <> string.lowercase(type_name)
      <> "_decoder())"
    _ -> "decode.fail(\"Unsupported map value type\")"
  }
}

fn generate_optional_field_decoder(
  field_type: ProtoType,
  field_num: Int,
) -> String {
  let num_str = int.to_string(field_num)

  // For optional fields, we'll use field_with_default and wrap in Option
  case field_type {
    parser.Int32 ->
      "decode.optional_field(" <> num_str <> ", decode.int32_field)
      |> decode.map(fn(opt) {
        case opt {
          Ok(value) -> Some(value)
          Error(Nil) -> None
        }
      })"

    parser.Int64 ->
      "decode.optional_field(" <> num_str <> ", decode.int64_field)
      |> decode.map(fn(opt) {
        case opt {
          Ok(value) -> Some(value)
          Error(Nil) -> None
        }
      })"

    parser.UInt32 ->
      "decode.optional_field(" <> num_str <> ", decode.uint32_field)
      |> decode.map(fn(opt) {
        case opt {
          Ok(value) -> Some(value)
          Error(Nil) -> None
        }
      })"

    parser.UInt64 ->
      "decode.optional_field(" <> num_str <> ", decode.uint64_field)
      |> decode.map(fn(opt) {
        case opt {
          Ok(value) -> Some(value)
          Error(Nil) -> None
        }
      })"

    parser.SInt32 ->
      "decode.optional_field(" <> num_str <> ", decode.sint32_field)
      |> decode.map(fn(opt) {
        case opt {
          Ok(value) -> Some(value)
          Error(Nil) -> None
        }
      })"

    parser.SInt64 ->
      "decode.optional_field(" <> num_str <> ", decode.sint64_field)
      |> decode.map(fn(opt) {
        case opt {
          Ok(value) -> Some(value)
          Error(Nil) -> None
        }
      })"

    parser.Float ->
      "decode.optional_field(" <> num_str <> ", decode.float_field)
      |> decode.map(fn(opt) {
        case opt {
          Ok(value) -> Some(value)
          Error(Nil) -> None
        }
      })"

    parser.Double ->
      "decode.optional_field(" <> num_str <> ", decode.double_field)
      |> decode.map(fn(opt) {
        case opt {
          Ok(value) -> Some(value)
          Error(Nil) -> None
        }
      })"

    parser.Bool -> "decode.optional_field(" <> num_str <> ", decode.bool_field)
      |> decode.map(fn(opt) {
        case opt {
          Ok(value) -> Some(value)
          Error(Nil) -> None
        }
      })"

    parser.String ->
      "decode.optional_field(" <> num_str <> ", decode.string_field)
      |> decode.map(fn(opt) {
        case opt {
          Ok(value) -> Some(value)
          Error(Nil) -> None
        }
      })"

    parser.Bytes ->
      "decode.optional_field(" <> num_str <> ", decode.bytes_field)
      |> decode.map(fn(opt) {
        case opt {
          Ok(value) -> Some(value)
          Error(Nil) -> None
        }
      })"

    parser.MessageType(type_name) ->
      "decode.optional_nested_message("
      <> num_str
      <> ", "
      <> string.lowercase(type_name)
      <> "_decoder())
      |> decode.map(fn(opt) {
        case opt {
          Ok(value) -> Some(value)
          Error(Nil) -> None
        }
      })"

    parser.EnumType(enum_name) -> {
      let decoder_name = "decode_" <> string.lowercase(enum_name) <> "_value"
      "decode.optional_field(" <> num_str <> ", fn(f) {
        use value <- result.try(decode.varint_field(f))
        " <> decoder_name <> "(value)
        |> result.map_error(fn(e) { decode.DecodeError(e) })
      })
      |> decode.map(fn(opt) {
        case opt {
          Ok(value) -> Some(value)
          Error(Nil) -> None
        }
      })"
    }

    _ -> "decode.fail(\"Unsupported optional field type\")"
  }
}

fn generate_enum_types(enums: List(Enum)) -> String {
  enums
  |> list.map(generate_enum_type)
  |> string.join("\n\n")
}

fn generate_enum_type(enum: Enum) -> String {
  let variants =
    enum.values
    |> list.map(fn(v) { "  " <> v.name })
    |> string.join("\n")

  "pub type " <> enum.name <> " {\n" <> variants <> "\n}"
}

fn generate_enum_helpers(enums: List(Enum)) -> String {
  enums
  |> list.map(generate_enum_helper)
  |> string.join("\n\n")
}

fn generate_enum_helper(enum: Enum) -> String {
  let encode_cases =
    enum.values
    |> list.map(fn(v) { "    " <> v.name <> " -> " <> int.to_string(v.number) })
    |> string.join("\n")

  let decode_cases =
    enum.values
    |> list.map(fn(v) {
      "    " <> int.to_string(v.number) <> " -> Ok(" <> v.name <> ")"
    })
    |> string.join("\n")

  let encoder_name = "encode_" <> string.lowercase(enum.name) <> "_value"
  let decoder_name = "decode_" <> string.lowercase(enum.name) <> "_value"
  let field_decoder_name = "decode_" <> string.lowercase(enum.name) <> "_field"
  let repeated_decoder_name = "decode_repeated_" <> string.lowercase(enum.name)

  "pub fn " <> encoder_name <> "(value: " <> enum.name <> ") -> Int {
  case value {
" <> encode_cases <> "
  }
}

pub fn " <> decoder_name <> "(value: Int) -> Result(" <> enum.name <> ", String) {
  case value {
" <> decode_cases <> "
    _ -> Error(\"Unknown enum value: \" <> int.to_string(value))
  }
}

pub fn " <> field_decoder_name <> "(field_num: Int) -> decode.Decoder(" <> enum.name <> ") {
  decode.field(field_num, fn(f) {
    use value <- result.try(decode.varint_field(f))
    " <> decoder_name <> "(value)
    |> result.map_error(fn(e) { decode.DecodeError(e) })
  })
}

pub fn " <> repeated_decoder_name <> "(field_num: Int) -> decode.Decoder(List(" <> enum.name <> ")) {
  decode.repeated_field(field_num, fn(f) {
    use value <- result.try(decode.varint_field(f))
    " <> decoder_name <> "(value)
    |> result.map_error(fn(e) { decode.DecodeError(e) })
  })
}"
}
