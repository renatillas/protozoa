//// Encoder Generation Module
////
//// This module handles generating Gleam encoding functions for Protocol Buffer messages.
//// It creates functions that convert Gleam values to binary Protocol Buffer format.

import gleam/int
import gleam/list
import gleam/string
import protozoa/internals/type_registry.{type TypeRegistry}
import protozoa/parser.{type Field, type Message, type ProtoType}

/// Generate all encoders for a list of messages
pub fn generate_encoders_with_registry(
  messages: List(Message),
  registry: TypeRegistry,
  file_path: String,
) -> String {
  let all_messages = collect_all_messages_flattened(messages)

  all_messages
  |> list.map(fn(message) {
    generate_message_encoder_with_registry(message, registry, file_path)
  })
  |> string.join("\n\n")
}

/// Generate encoder for a single message
pub fn generate_message_encoder_with_registry(
  message: Message,
  registry: TypeRegistry,
  file_path: String,
) -> String {
  let function_name = "encode_" <> string.lowercase(message.name)
  let is_empty = list.is_empty(message.fields) && list.is_empty(message.oneofs)
  
  let param_name = case is_empty {
    True -> "_" <> string.lowercase(message.name)
    False -> string.lowercase(message.name)
  }

  // Separate different field types
  let #(repeated_and_map_fields, regular_fields) =
    list.partition(message.fields, fn(field) {
      case field.field_type {
        parser.Repeated(_) -> True
        parser.Map(_, _) -> True
        _ -> False
      }
    })
  
  let #(map_fields, repeated_fields) =
    list.partition(repeated_and_map_fields, fn(field) {
      case field.field_type {
        parser.Map(_, _) -> True
        _ -> False
      }
    })

  // Generate different types of encoders
  let regular_encoders = generate_regular_field_encoders(regular_fields, message, param_name, registry, file_path)
  let oneof_encoders = generate_oneof_encoders(message.oneofs, message, param_name)
  let repeated_code = generate_repeated_fields_code(repeated_fields, param_name)
  let map_code = generate_map_fields_code(map_fields, param_name)

  // Build the function body
  let body = build_encoder_function_body(
    repeated_fields,
    map_fields,
    regular_encoders,
    oneof_encoders,
    repeated_code,
    map_code,
  )

  "pub fn " <> function_name <> "(" <> param_name <> ": " <> message.name <> ") -> BitArray {\n" <> body <> "\n}"
}

/// Generate enum helper encoders
pub fn generate_enum_helpers_with_nested(
  top_level_enums: List(parser.Enum),
  messages: List(Message),
) -> String {
  let all_enums = collect_all_enums_flattened(top_level_enums, messages)
  
  all_enums
  |> list.map(generate_enum_helper)
  |> string.join("\n\n")
}

// Helper functions

fn generate_regular_field_encoders(
  fields: List(Field),
  message: Message,
  param_name: String,
  registry: TypeRegistry,
  file_path: String,
) -> List(String) {
  fields
  |> list.map(fn(field) {
    let qualified_field_type = qualify_nested_field_type(field.field_type, message.name, message)
    let resolved_field_type = resolve_field_type_with_registry(qualified_field_type, registry, file_path)
    let qualified_field = parser.Field(..field, field_type: resolved_field_type)
    generate_field_encoder(qualified_field, param_name)
  })
}

fn generate_oneof_encoders(
  oneofs: List(parser.Oneof),
  message: Message,
  param_name: String,
) -> List(String) {
  oneofs
  |> list.map(fn(oneof) {
    generate_oneof_encoder(message.name, oneof, param_name, message)
  })
}

fn generate_repeated_fields_code(fields: List(Field), param_name: String) -> String {
  case fields {
    [] -> ""
    _ -> {
      fields
      |> list.map(fn(field) { generate_repeated_field_code(field, param_name) })
      |> string.join("\n  ")
    }
  }
}

fn generate_map_fields_code(fields: List(Field), param_name: String) -> String {
  case fields {
    [] -> ""
    _ -> {
      fields
      |> list.map(fn(field) { generate_map_field_code(field, param_name) })
      |> string.join("\n  ")
    }
  }
}

fn build_encoder_function_body(
  repeated_fields: List(Field),
  map_fields: List(Field),
  regular_encoders: List(String),
  oneof_encoders: List(String),
  repeated_code: String,
  map_code: String,
) -> String {
  let repeated_field_vars = 
    repeated_fields
    |> list.map(fn(field) { string.lowercase(field.name) <> "_fields" })
  
  let map_field_vars = 
    map_fields
    |> list.map(fn(field) { string.lowercase(field.name) <> "_fields" })

  let all_vars = list.flatten([repeated_field_vars, map_field_vars])
  let all_regular = list.append(regular_encoders, oneof_encoders)

  case all_vars, all_regular, repeated_code, map_code {
    [], [], "", "" -> "  encode.message([])"
    [], encoders, "", "" -> "  encode.message([\n    " <> string.join(encoders, ",\n    ") <> ",\n  ])"
    vars, [], code1, code2 -> {
      let code = case code1, code2 {
        "", c2 -> "  " <> c2
        c1, "" -> "  " <> c1
        c1, c2 -> "  " <> c1 <> "\n  " <> c2
      }
      code <> "\n  encode.message(" <> build_list_flattening(vars) <> ")"
    }
    vars, encoders, code1, code2 -> {
      let code = case code1, code2 {
        "", c2 -> "  " <> c2
        c1, "" -> "  " <> c1
        c1, c2 -> "  " <> c1 <> "\n  " <> c2
      }
      let individual_encoders = list.map(encoders, fn(enc) { "[" <> enc <> "]" })
      let concat_expr = build_list_flattening(list.append(vars, individual_encoders))
      code <> "\n  encode.message(" <> concat_expr <> ")"
    }
  }
}


fn build_list_flattening(vars: List(String)) -> String {
  case vars {
    [] -> "[]"
    [single] -> single
    _ -> "list.flatten([" <> string.join(vars, ", ") <> "])"
  }
}

fn generate_field_encoder(field: Field, param_name: String) -> String {
  let field_access = param_name <> "." <> field.name
  let field_num = int.to_string(field.number)

  case field.field_type {
    parser.Optional(inner) -> generate_optional_field_encoder_typed(inner, field_access, field_num)
    parser.Repeated(_) -> "// Repeated fields handled separately"
    _ -> generate_required_field_encoder(field.field_type, field_access, field_num)
  }
}

fn generate_required_field_encoder(proto_type: ProtoType, access: String, field_num: String) -> String {
  case proto_type {
    parser.String -> "encode.string_field(" <> field_num <> ", " <> access <> ")"
    parser.Int32 -> "encode.int32_field(" <> field_num <> ", " <> access <> ")"
    parser.Int64 -> "encode.int64_field(" <> field_num <> ", " <> access <> ")"
    parser.UInt32 -> "encode.uint32_field(" <> field_num <> ", " <> access <> ")"
    parser.UInt64 -> "encode.uint64_field(" <> field_num <> ", " <> access <> ")"
    parser.SInt32 -> "encode.sint32_field(" <> field_num <> ", " <> access <> ")"
    parser.SInt64 -> "encode.sint64_field(" <> field_num <> ", " <> access <> ")"
    parser.Fixed32 -> "encode.fixed32_field(" <> field_num <> ", " <> access <> ")"
    parser.Fixed64 -> "encode.fixed64_field(" <> field_num <> ", " <> access <> ")"
    parser.SFixed32 -> "encode.sfixed32_field(" <> field_num <> ", " <> access <> ")"
    parser.SFixed64 -> "encode.sfixed64_field(" <> field_num <> ", " <> access <> ")"
    parser.Bool -> "encode.bool_field(" <> field_num <> ", " <> access <> ")"
    parser.Bytes -> "encode.field(" <> field_num <> ", wire.LengthDelimited, encode.length_delimited(" <> access <> "))"
    parser.Float -> "encode.float_field(" <> field_num <> ", " <> access <> ")"
    parser.Double -> "encode.double_field(" <> field_num <> ", " <> access <> ")"
    parser.MessageType(_) -> "encode.message_field(" <> field_num <> ", encode_" <> string.lowercase(flatten_type_name(get_type_name(proto_type))) <> "(" <> access <> "))"
    parser.EnumType(_) -> "encode.int32_field(" <> field_num <> ", encode_" <> string.lowercase(flatten_type_name(get_type_name(proto_type))) <> "_value(" <> access <> "))"
    _ -> "// Unsupported type: " <> string.inspect(proto_type)
  }
}

fn generate_optional_field_encoder_typed(inner_type: ProtoType, access: String, field_num: String) -> String {
  "case " <> access <> " {\n      option.Some(val) -> " <> 
  generate_required_field_encoder(inner_type, "val", field_num) <> 
  "\n      option.None -> encode.empty_field()\n    }"
}

fn generate_oneof_encoder(
  message_name: String,
  oneof: parser.Oneof,
  param_name: String,
  _parent_message: Message,
) -> String {
  let oneof_access = param_name <> "." <> oneof.name
  let _type_name = capitalize_first(message_name) <> capitalize_first(oneof.name)
  
  let cases = 
    oneof.fields
    |> list.map(fn(field) {
      let base_variant_name = capitalize_first(field.name)
      let field_num = int.to_string(field.number)
      let gleam_type = get_type_name(field.field_type)
      // Avoid naming conflicts with well-known types
      let variant_name = case base_variant_name, gleam_type {
        "Empty", "google.protobuf.Empty" -> "EmptyData"
        name, _ -> name
      }
      let encoder = generate_required_field_encoder(field.field_type, "val", field_num)
      "      " <> variant_name <> "(val) -> " <> encoder
    })
    |> string.join("\n")

  "case " <> oneof_access <> " {\n      option.Some(oneof_val) -> {\n        case oneof_val {\n" <> 
  cases <> "\n        }\n      }\n      option.None -> <<>>\n    }"
}

fn generate_repeated_field_code(field: Field, param_name: String) -> String {
  let field_name = string.lowercase(field.name)
  let var_name = field_name <> "_fields"
  let field_access = param_name <> "." <> field.name
  let field_num = int.to_string(field.number)

  case field.field_type {
    parser.Repeated(inner_type) -> {
      let encoder = generate_repeated_item_encoder(inner_type, field_num)
      "let " <> var_name <> " = list.map(" <> field_access <> ", fn(v) { " <> encoder <> " })"
    }
    _ -> "// Not a repeated field"
  }
}

fn generate_repeated_item_encoder(proto_type: ProtoType, field_num: String) -> String {
  case proto_type {
    parser.String -> "encode.string_field(" <> field_num <> ", v)"
    parser.Int32 -> "encode.int32_field(" <> field_num <> ", v)"
    parser.Bool -> "encode.bool_field(" <> field_num <> ", v)"
    parser.Bytes -> "encode.field(" <> field_num <> ", wire.LengthDelimited, encode.length_delimited(v))"
    parser.MessageType(_) -> "encode.message_field(" <> field_num <> ", encode_" <> string.lowercase(flatten_type_name(get_type_name(proto_type))) <> "(v))"
    parser.EnumType(_) -> "encode.int32_field(" <> field_num <> ", encode_" <> string.lowercase(flatten_type_name(get_type_name(proto_type))) <> "_value(v))"
    _ -> "encode.string_field(" <> field_num <> ", \"unsupported\")"
  }
}

fn generate_map_field_code(field: Field, _param_name: String) -> String {
  let field_name = string.lowercase(field.name)
  let var_name = field_name <> "_fields"
  "let " <> var_name <> " = [] // Map fields not yet implemented"
}

fn generate_enum_helper(enum: parser.Enum) -> String {
  let encoder_function = generate_enum_encoder(enum)
  let decoder_function = generate_enum_decoder(enum)
  encoder_function <> "\n\n" <> decoder_function
}

fn generate_enum_encoder(enum: parser.Enum) -> String {
  let function_name = "encode_" <> string.lowercase(enum.name) <> "_value"
  let cases = 
    enum.values
    |> list.map(fn(variant) {
      let variant_name = capitalize_first(variant.name)
      "    " <> variant_name <> " -> " <> int.to_string(variant.number)
    })
    |> string.join("\n")

  "pub fn " <> function_name <> "(value: " <> enum.name <> ") -> Int {\n  case value {\n" <> 
  cases <> "\n  }\n}"
}

fn generate_enum_decoder(enum: parser.Enum) -> String {
  let function_name = "decode_" <> string.lowercase(enum.name) <> "_field"
  let decode_cases = 
    enum.values
    |> list.map(fn(variant) {
      let variant_name = capitalize_first(variant.name)
      "          " <> int.to_string(variant.number) <> " -> Ok(" <> variant_name <> ")"
    })
    |> string.join("\n")

  "pub fn " <> function_name <> "(field_number: Int) -> decode.Decoder(" <> enum.name <> ") {\n" <>
  "  decode.field(field_number, fn(field) {\n" <>
  "    use value <- result.try(decode.int32_field(field))\n" <>
  "    case value {\n" <>
  decode_cases <> "\n" <>
  "      _ -> Error(decode.DecodeError(\"Unknown " <> string.lowercase(enum.name) <> " value: \" <> string.inspect(value)))\n" <>
  "    }\n" <>
  "  })\n" <>
  "}"
}

// Utility functions that should be extracted from the main module

fn collect_all_messages_flattened(messages: List(Message)) -> List(Message) {
  list.fold(messages, [], fn(acc, msg) {
    let nested = collect_nested_messages_flattened(msg.nested_messages, msg.name)
    [msg, ..list.append(nested, acc)]
  })
}

fn collect_nested_messages_flattened(nested_messages: List(Message), parent_name: String) -> List(Message) {
  list.fold(nested_messages, [], fn(acc, nested_msg) {
    let flattened_name = parent_name <> nested_msg.name
    let flattened_msg = parser.Message(..nested_msg, name: flattened_name)
    let deeper_nested = collect_nested_messages_flattened(nested_msg.nested_messages, flattened_name)
    [flattened_msg, ..list.append(deeper_nested, acc)]
  })
}

fn collect_all_enums_flattened(top_level_enums: List(parser.Enum), messages: List(Message)) -> List(parser.Enum) {
  let nested_enums = 
    messages
    |> list.fold([], fn(acc, msg) {
      list.append(acc, collect_nested_enums_flattened(msg.enums, msg.nested_messages, msg.name))
    })
  
  list.append(top_level_enums, nested_enums)
}

fn collect_nested_enums_flattened(
  enums: List(parser.Enum),
  nested_messages: List(Message),
  parent_name: String,
) -> List(parser.Enum) {
  let current_enums = 
    enums
    |> list.map(fn(enum) {
      parser.Enum(..enum, name: parent_name <> enum.name)
    })

  let deeper_enums = 
    nested_messages
    |> list.fold([], fn(acc, nested_msg) {
      let nested_name = parent_name <> nested_msg.name
      list.append(acc, collect_nested_enums_flattened(nested_msg.enums, nested_msg.nested_messages, nested_name))
    })

  list.append(current_enums, deeper_enums)
}

fn qualify_nested_field_type(proto_type: ProtoType, parent_name: String, parent_message: Message) -> ProtoType {
  case proto_type {
    parser.MessageType(name) -> {
      case is_nested_type_in_message(name, parent_message) {
        True -> parser.MessageType(parent_name <> name)
        False -> proto_type
      }
    }
    parser.EnumType(name) -> {
      case is_nested_enum_in_message(name, parent_message) {
        True -> parser.EnumType(parent_name <> name)
        False -> proto_type
      }
    }
    _ -> proto_type
  }
}

fn resolve_field_type_with_registry(
  proto_type: ProtoType,
  _registry: TypeRegistry,
  _file_path: String,
) -> ProtoType {
  // For now, just return the type as-is
  proto_type
}

fn is_nested_type_in_message(type_name: String, parent_message: Message) -> Bool {
  parent_message.nested_messages
  |> list.any(fn(nested) { nested.name == type_name })
}

fn is_nested_enum_in_message(enum_name: String, parent_message: Message) -> Bool {
  parent_message.enums
  |> list.any(fn(nested_enum) { nested_enum.name == enum_name })
}

fn flatten_type_name(name: String) -> String {
  // Handle well-known types
  case name {
    "google.protobuf.Timestamp" -> "Timestamp"
    "google.protobuf.Duration" -> "Duration"
    "google.protobuf.FieldMask" -> "FieldMask"
    "google.protobuf.Empty" -> "Empty"
    "google.protobuf.Any" -> "Any"
    _ -> {
      // Convert dotted names like "OuterMessage.NestedMessage" to "OuterMessageNestedMessage"
      name
      |> string.replace(".", "")
    }
  }
}

fn get_type_name(proto_type: ProtoType) -> String {
  case proto_type {
    parser.MessageType(name) -> name
    parser.EnumType(name) -> name
    _ -> "UnknownType"
  }
}

fn capitalize_first(str: String) -> String {
  // Convert snake_case to PascalCase
  str
  |> string.split("_")
  |> list.map(fn(part) {
    case string.pop_grapheme(part) {
      Ok(#(first, rest)) -> string.uppercase(first) <> rest
      Error(_) -> part
    }
  })
  |> string.join("")
}