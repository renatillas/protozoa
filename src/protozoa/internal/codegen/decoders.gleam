//// Decoder Generation Module
////
//// This module handles generating Gleam decoding functions for Protocol Buffer messages.
//// It creates functions that parse binary Protocol Buffer data into Gleam values.

import gleam/int
import gleam/list
import gleam/option
import gleam/string
import justin
import protozoa/internal/codegen/types.{capitalize_first, flatten_type_name}
import protozoa/internal/type_registry.{type TypeRegistry}
import protozoa/parser/proto.{type Field, type Message, type Type}

/// Generate all decoders for a list of messages
pub fn generate_decoders(
  messages: List(Message),
  registry: TypeRegistry,
  file_path: String,
) -> String {
  // Get the package for type resolution
  let current_package = case type_registry.get_file_package(registry, file_path)
  {
    option.Some(pkg) -> pkg
    option.None -> ""
  }

  let all_messages = collect_all_messages_flattened(messages)

  // Resolve enum types in all messages
  let resolved_messages =
    list.map(all_messages, fn(msg) {
      resolve_message_types(msg, registry, current_package)
    })

  resolved_messages
  |> list.map(fn(message) {
    generate_message_decoder(message, registry, file_path)
  })
  |> string.join("\n\n")
}

/// Resolve field types in a message (convert MessageType to EnumType if needed)
fn resolve_message_types(
  msg: Message,
  registry: TypeRegistry,
  current_package: String,
) -> Message {
  let resolved_fields =
    list.map(msg.fields, fn(field) {
      proto.Field(
        ..field,
        field_type: type_registry.resolve_field_type(
          registry,
          field.field_type,
          current_package,
        ),
      )
    })

  let resolved_oneofs =
    list.map(msg.oneofs, fn(oneof) {
      let resolved_oneof_fields =
        list.map(oneof.fields, fn(field) {
          proto.Field(
            ..field,
            field_type: type_registry.resolve_field_type(
              registry,
              field.field_type,
              current_package,
            ),
          )
        })
      proto.Oneof(..oneof, fields: resolved_oneof_fields)
    })

  proto.Message(..msg, fields: resolved_fields, oneofs: resolved_oneofs)
}

/// Generate decoder for a single message
pub fn generate_message_decoder(
  message: Message,
  registry: TypeRegistry,
  file_path: String,
) -> String {
  // Get qualified names for function and type
  let qualified_fn_name =
    types.get_qualified_function_name(message.name, registry, file_path)
  let qualified_type_name =
    types.get_qualified_type_name(message.name, registry, file_path)
  let decoder_fn_name = qualified_fn_name <> "_decoder"
  let decode_fn_name = "decode_" <> qualified_fn_name

  let decoder_body =
    generate_decoder_function_body(message, registry, file_path)
  let wrapper_body = generate_wrapper_function_body(message, decoder_fn_name)
  let oneof_helpers =
    generate_oneof_helper_functions(message, registry, file_path)
  let map_helpers = generate_map_helper_functions(message, registry, file_path)

  let main_decoder =
    "pub fn "
    <> decoder_fn_name
    <> "() -> decode.Decoder("
    <> qualified_type_name
    <> ") {\n"
    <> decoder_body
    <> "\n}\n\n"
    <> "pub fn "
    <> decode_fn_name
    <> "(data: BitArray) -> Result("
    <> qualified_type_name
    <> ", List(decode.DecodeError)) {\n"
    <> wrapper_body
    <> "\n}"

  let all_helpers = case oneof_helpers, map_helpers {
    "", "" -> ""
    helpers, "" -> helpers <> "\n\n"
    "", helpers -> helpers <> "\n\n"
    oneof, map -> oneof <> "\n\n" <> map <> "\n\n"
  }

  case all_helpers {
    "" -> main_decoder
    helpers -> helpers <> main_decoder
  }
}

// Helper functions

fn generate_oneof_helper_functions(
  message: Message,
  registry: TypeRegistry,
  file_path: String,
) -> String {
  let qualified_fn_name =
    types.get_qualified_function_name(message.name, registry, file_path)
  message.oneofs
  |> list.map(fn(oneof) {
    generate_single_oneof_decoder(qualified_fn_name, oneof)
  })
  |> string.join("\n\n")
}

fn generate_map_helper_functions(
  message: Message,
  registry: TypeRegistry,
  file_path: String,
) -> String {
  let map_fields =
    list.filter(message.fields, fn(field) {
      case field.field_type {
        proto.Map(_, _) -> True
        _ -> False
      }
    })

  let msg_prefix =
    types.get_qualified_function_name(message.name, registry, file_path)

  list.map(map_fields, fn(field) {
    case field.field_type {
      proto.Map(key_type, value_type) -> {
        let field_num = int.to_string(field.number)
        generate_map_entry_decoder(msg_prefix, field_num, key_type, value_type)
      }
      _ -> ""
      // This shouldn't happen due to filtering
    }
  })
  |> string.join("\n\n")
}

fn generate_map_entry_decoder(
  msg_prefix: String,
  field_num: String,
  key_type: Type,
  value_type: Type,
) -> String {
  let function_name =
    msg_prefix <> "_map_entry_" <> field_num <> "_decoder"
  let key_decoder = generate_map_field_decoder(key_type, "1")
  let value_decoder = generate_map_field_decoder(value_type, "2")

  "fn "
  <> function_name
  <> "() -> fn(decode.Field) -> Result(#("
  <> get_gleam_type(key_type)
  <> ", "
  <> get_gleam_type(value_type)
  <> "), decode.DecodeError) {\n"
  <> "  fn(field) {\n"
  <> "    let entry_decoder = {\n"
  <> "      use key <- decode.then("
  <> key_decoder
  <> ")\n"
  <> "      use value <- decode.then("
  <> value_decoder
  <> ")\n"
  <> "      decode.success(#(key, value))\n"
  <> "    }\n"
  <> "    case decode.message_field(_, entry_decoder)(field) {\n"
  <> "      Ok(entry) -> Ok(entry)\n"
  <> "      Error(err) -> Error(err)\n"
  <> "    }\n"
  <> "  }\n"
  <> "}"
}

fn generate_map_field_decoder(proto_type: Type, field_num: String) -> String {
  case proto_type {
    proto.String -> "decode.string_with_default(" <> field_num <> ", \"\")"
    proto.Int32 -> "decode.int32_with_default(" <> field_num <> ", 0)"
    proto.Int64 -> "decode.int64_with_default(" <> field_num <> ", 0)"
    proto.UInt32 -> "decode.uint32_with_default(" <> field_num <> ", 0)"
    proto.UInt64 -> "decode.uint64_with_default(" <> field_num <> ", 0)"
    proto.SInt32 -> "decode.sint32(" <> field_num <> ")"
    proto.SInt64 -> "decode.sint64(" <> field_num <> ")"
    proto.Fixed32 -> "decode.fixed32(" <> field_num <> ")"
    proto.Fixed64 -> "decode.fixed64(" <> field_num <> ")"
    proto.SFixed32 -> "decode.sfixed32(" <> field_num <> ")"
    proto.SFixed64 -> "decode.sfixed64(" <> field_num <> ")"
    proto.Bool -> "decode.bool_with_default(" <> field_num <> ", False)"
    proto.Bytes -> "decode.bytes(" <> field_num <> ")"
    proto.Float -> "decode.float(" <> field_num <> ")"
    proto.Double -> "decode.double(" <> field_num <> ")"
    proto.MessageType("Value") ->
      "decode.nested_message(" <> field_num <> ", value_decoder())"
    proto.MessageType(name) -> {
      let decoder_name =
        justin.snake_case(flatten_type_name(name)) <> "_decoder"
      "decode.nested_message(" <> field_num <> ", " <> decoder_name <> "())"
    }
    proto.EnumType(name) ->
      "decode_" <> justin.snake_case(flatten_type_name(name)) <> "_field(" <> field_num <> ")"
    _ -> "decode.string_with_default(" <> field_num <> ", \"\")"
    // fallback for unsupported types
  }
}

fn get_gleam_type(proto_type: Type) -> String {
  case proto_type {
    proto.String -> "String"
    proto.Int32 -> "Int"
    proto.Int64 -> "Int"
    proto.UInt32 -> "Int"
    proto.UInt64 -> "Int"
    proto.SInt32 -> "Int"
    proto.SInt64 -> "Int"
    proto.Fixed32 -> "Int"
    proto.Fixed64 -> "Int"
    proto.SFixed32 -> "Int"
    proto.SFixed64 -> "Int"
    proto.Bool -> "Bool"
    proto.Bytes -> "BitArray"
    proto.Float -> "Float"
    proto.Double -> "Float"
    proto.MessageType("Value") -> "Value"
    proto.MessageType(name) -> flatten_type_name(name)
    proto.EnumType(name) -> flatten_type_name(name)
    _ -> "String"
    // fallback
  }
}

fn generate_single_oneof_decoder(
  message_name: String,
  oneof: proto.Oneof,
) -> String {
  let function_name = "oneof_" <> justin.snake_case(oneof.name) <> "_decoder"
  let oneof_type_name =
    capitalize_first(message_name) <> capitalize_first(oneof.name)

  let field_checks = generate_oneof_field_checks(oneof.fields)

  "fn "
  <> function_name
  <> "() -> decode.Decoder(option.Option("
  <> oneof_type_name
  <> ")) {\n"
  <> "  decode.from_field_dict(fn(fields) {\n"
  <> field_checks
  <> "  })\n"
  <> "}"
}

fn generate_oneof_field_checks(fields: List(proto.Field)) -> String {
  case fields {
    [] -> "    Ok(option.None)\n"
    [field] -> {
      let field_num = int.to_string(field.number)
      let base_variant_name = capitalize_first(field.name)
      let variant_name = case base_variant_name, field.field_type {
        "Empty", proto.MessageType("google.protobuf.Empty") -> "EmptyData"
        "StringValue", proto.String -> "StringValueVariant"
        "BoolValue", proto.Bool -> "BoolValueVariant"
        "ListValue", proto.MessageType("ListValue") -> "ListValueVariant"
        name, _ -> name
      }
      let field_decoder = get_field_decoder_for_type(field.field_type)
      "    case dict.get(fields, "
      <> field_num
      <> ") {\n"
      <> "      Ok([field, ..]) -> {\n"
      <> "        case "
      <> field_decoder
      <> "(field) {\n"
      <> "          Ok(value) -> Ok(option.Some("
      <> variant_name
      <> "(value)))\n"
      <> "          Error(_) -> Ok(option.None)\n"
      <> "        }\n"
      <> "      }\n"
      <> "      _ -> Ok(option.None)\n"
      <> "    }\n"
    }
    [field, ..rest] -> {
      let field_num = int.to_string(field.number)
      let base_variant_name = capitalize_first(field.name)
      let variant_name = case base_variant_name, field.field_type {
        "Empty", proto.MessageType("google.protobuf.Empty") -> "EmptyData"
        "StringValue", proto.String -> "StringValueVariant"
        "BoolValue", proto.Bool -> "BoolValueVariant"
        "ListValue", proto.MessageType("ListValue") -> "ListValueVariant"
        name, _ -> name
      }
      let field_decoder = get_field_decoder_for_type(field.field_type)

      "    case dict.get(fields, "
      <> field_num
      <> ") {\n"
      <> "      Ok([field, ..]) -> {\n"
      <> "        case "
      <> field_decoder
      <> "(field) {\n"
      <> "          Ok(value) -> Ok(option.Some("
      <> variant_name
      <> "(value)))\n"
      <> "          Error(_) -> {\n"
      <> generate_oneof_field_checks(rest)
      <> "          }\n"
      <> "        }\n"
      <> "      }\n"
      <> "      _ -> {\n"
      <> generate_oneof_field_checks(rest)
      <> "      }\n"
      <> "    }\n"
    }
  }
}

fn get_field_decoder_for_type(field_type: proto.Type) -> String {
  case field_type {
    proto.String -> "decode.string_field"
    proto.Int32 -> "decode.int32_field"
    proto.Bool -> "decode.bool_field"
    proto.Bytes -> "decode.bytes_field"
    proto.Float -> "decode.float_field"
    proto.Double -> "decode.double_field"
    proto.MessageType(name) -> {
      let decoder_name =
        justin.snake_case(flatten_type_name(name)) <> "_decoder"
      "decode.message_field(_, " <> decoder_name <> "())"
    }
    proto.EnumType(name) -> {
      let decoder_name =
        "decode_" <> justin.snake_case(flatten_type_name(name)) <> "_from_field"
      decoder_name
    }
    _ -> "decode.string_field"
    // fallback
  }
}

fn generate_decoder_function_body(
  message: Message,
  registry: TypeRegistry,
  file_path: String,
) -> String {
  let qualified_type_name =
    types.get_qualified_type_name(message.name, registry, file_path)
  let field_decoders =
    message.fields
    |> list.map(fn(field) { generate_field_decoder(message, field, registry, file_path) })
    |> string.join("\n")

  // Generate oneof decoders using helper functions
  let oneof_decoders =
    message.oneofs
    |> list.map(fn(oneof) {
      let escaped_oneof_name = types.escape_keyword(oneof.name)
      let function_name =
        "oneof_" <> justin.snake_case(oneof.name) <> "_decoder"
      "  use "
      <> escaped_oneof_name
      <> " <- decode.then("
      <> function_name
      <> "())"
    })
    |> string.join("\n")

  let constructor_call = generate_constructor_call(message, qualified_type_name)

  case field_decoders, oneof_decoders {
    "", "" -> constructor_call
    fields, "" -> fields <> "\n" <> constructor_call
    "", oneofs -> oneofs <> "\n" <> constructor_call
    fields, oneofs -> fields <> "\n" <> oneofs <> "\n" <> constructor_call
  }
}

fn generate_field_decoder(
  message: Message,
  field: Field,
  registry: TypeRegistry,
  file_path: String,
) -> String {
  let _field_num = int.to_string(field.number)
  let decoder_call = generate_field_decoder_call(message, field, registry, file_path)

  let escaped_field_name = types.escape_keyword(field.name)
  "  use " <> escaped_field_name <> " <- decode.then(" <> decoder_call <> ")"
}

fn generate_field_decoder_call(
  message: Message,
  field: Field,
  registry: TypeRegistry,
  file_path: String,
) -> String {
  let field_num = int.to_string(field.number)

  case field.field_type {
    proto.Optional(inner) -> generate_optional_type_decoder(inner, field_num)
    proto.Repeated(inner) -> generate_repeated_type_decoder(inner, field_num)
    _ -> generate_type_decoder(message, field.field_type, field_num, registry, file_path)
  }
}

fn generate_type_decoder(
  message: Message,
  proto_type: Type,
  field_num: String,
  registry: TypeRegistry,
  file_path: String,
) -> String {
  let msg_prefix =
    types.get_qualified_function_name(message.name, registry, file_path)

  case proto_type {
    proto.String -> "decode.string_with_default(" <> field_num <> ", \"\")"
    proto.Int32 -> "decode.int32_with_default(" <> field_num <> ", 0)"
    proto.Int64 -> "decode.int64_with_default(" <> field_num <> ", 0)"
    proto.UInt32 -> "decode.uint32_with_default(" <> field_num <> ", 0)"
    proto.UInt64 -> "decode.uint64_with_default(" <> field_num <> ", 0)"
    proto.SInt32 -> "decode.sint32(" <> field_num <> ")"
    proto.SInt64 -> "decode.sint64(" <> field_num <> ")"
    proto.Fixed32 -> "decode.fixed32(" <> field_num <> ")"
    proto.Fixed64 -> "decode.fixed64(" <> field_num <> ")"
    proto.SFixed32 -> "decode.sfixed32(" <> field_num <> ")"
    proto.SFixed64 -> "decode.sfixed64(" <> field_num <> ")"
    proto.Bool -> "decode.bool_with_default(" <> field_num <> ", False)"
    proto.Bytes -> "decode.bytes(" <> field_num <> ")"
    proto.Float -> "decode.float(" <> field_num <> ")"
    proto.Double -> "decode.double(" <> field_num <> ")"
    proto.MessageType(name) ->
      "decode.nested_message("
      <> field_num
      <> ", "
      <> justin.snake_case(flatten_type_name(name))
      <> "_decoder())"
    proto.EnumType(name) ->
      "decode_"
      <> justin.snake_case(flatten_type_name(name))
      <> "_field("
      <> field_num
      <> ")"
    proto.Map(_key_type, _value_type) ->
      "decode.repeated_field("
      <> field_num
      <> ", fn(field) { "
      <> msg_prefix
      <> "_map_entry_"
      <> field_num
      <> "_decoder()(field) })"
    _ -> "decode.fail(\"Unsupported type\")"
  }
}

fn generate_optional_type_decoder(inner_type: Type, field_num: String) -> String {
  // decode.optional_field and decode.optional_nested_message return Result(a, Nil)
  // but we need option.Option(a), so we wrap with decode.map and option.from_result
  case inner_type {
    proto.MessageType(name) ->
      "decode.map(decode.optional_nested_message("
      <> field_num
      <> ", "
      <> justin.snake_case(flatten_type_name(name))
      <> "_decoder()), option.from_result)"
    _ ->
      "decode.map(decode.optional_field("
      <> field_num
      <> ", "
      <> generate_simple_field_decoder_name(inner_type)
      <> "), option.from_result)"
  }
}

fn generate_repeated_type_decoder(inner_type: Type, field_num: String) -> String {
  case inner_type {
    proto.String -> "decode.repeated_string(" <> field_num <> ")"
    proto.Int32 -> "decode.repeated_int32(" <> field_num <> ")"
    proto.EnumType(name) ->
      "decode_repeated_"
      <> justin.snake_case(flatten_type_name(name))
      <> "("
      <> field_num
      <> ")"
    _ ->
      "decode.repeated_field("
      <> field_num
      <> ", fn(field) { "
      <> generate_simple_type_decoder(inner_type)
      <> " })"
  }
}

fn generate_simple_type_decoder(proto_type: Type) -> String {
  case proto_type {
    proto.String -> "decode.string_field(field)"
    proto.Int32 -> "decode.int32_field(field)"
    proto.Int64 -> "decode.int64_field(field)"
    proto.UInt32 -> "decode.uint32_field(field)"
    proto.UInt64 -> "decode.uint64_field(field)"
    proto.Bool -> "decode.bool_field(field)"
    proto.Bytes -> "decode.bytes_field(field)"
    proto.Float -> "decode.float_field(field)"
    proto.Double -> "decode.double_field(field)"
    proto.MessageType(name) ->
      "decode.message_field(_, "
      <> justin.snake_case(flatten_type_name(name))
      <> "_decoder())(field)"
    _ ->
      "Error(decode.DecodeError(expected: \"supported field type\", found: \"unsupported field type\", path: []))"
  }
}

fn generate_simple_field_decoder_name(proto_type: Type) -> String {
  case proto_type {
    proto.String -> "decode.string_field"
    proto.Int32 -> "decode.int32_field"
    proto.Int64 -> "decode.int64_field"
    proto.UInt32 -> "decode.uint32_field"
    proto.UInt64 -> "decode.uint64_field"
    proto.Bool -> "decode.bool_field"
    proto.Bytes -> "decode.bytes_field"
    proto.Float -> "decode.float_field"
    proto.Double -> "decode.double_field"
    _ ->
      "fn(_field) { Error(decode.DecodeError(expected: \"supported field type\", found: \"unsupported field type\", path: [])) }"
  }
}

fn generate_constructor_call(
  message: Message,
  qualified_type_name: String,
) -> String {
  let field_names =
    message.fields
    |> list.map(fn(field) {
      let escaped_name = types.escape_keyword(field.name)
      escaped_name <> ": " <> escaped_name
    })

  let oneof_names =
    message.oneofs
    |> list.map(fn(oneof) {
      let escaped_name = types.escape_keyword(oneof.name)
      escaped_name <> ": " <> escaped_name
    })

  let all_names = list.append(field_names, oneof_names)

  case all_names {
    [] -> "  decode.success(" <> qualified_type_name <> ")"
    [single] ->
      "  decode.success(" <> qualified_type_name <> "(" <> single <> "))"
    _ -> {
      case list.length(all_names) > 4 {
        True -> {
          let names_str = string.join(all_names, ",\n    ")
          "  decode.success("
          <> qualified_type_name
          <> "(\n    "
          <> names_str
          <> ",\n  ))"
        }
        False -> {
          let names_str = string.join(all_names, ", ")
          "  decode.success(" <> qualified_type_name <> "(" <> names_str <> "))"
        }
      }
    }
  }
}

fn generate_wrapper_function_body(
  _message: Message,
  decoder_fn_name: String,
) -> String {
  "  decode.run(data, " <> decoder_fn_name <> "())"
}

// Utility functions

fn collect_all_messages_flattened(messages: List(Message)) -> List(Message) {
  list.fold(messages, [], fn(acc, msg) {
    // Recursively flatten nested messages (updating message names only, not field types)
    // Field type resolution is handled separately by resolve_message_types using the registry
    let flattened_nested =
      flatten_nested_messages_simple(msg.nested_messages, msg.name)

    [msg, ..list.append(flattened_nested, acc)]
  })
}

/// Flatten nested messages by prepending parent name to message name
/// Does NOT modify field types - that's handled by resolve_message_types
fn flatten_nested_messages_simple(
  nested_messages: List(Message),
  parent_name: String,
) -> List(Message) {
  list.fold(nested_messages, [], fn(acc, nested_msg) {
    let flattened_name = parent_name <> nested_msg.name

    // Create the flattened message
    let flattened_msg = proto.Message(..nested_msg, name: flattened_name)

    // Recursively handle deeper nesting
    let deeper_nested =
      flatten_nested_messages_simple(nested_msg.nested_messages, flattened_name)

    [flattened_msg, ..list.append(deeper_nested, acc)]
  })
}

