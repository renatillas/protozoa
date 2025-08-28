//// Decoder Generation Module
////
//// This module handles generating Gleam decoding functions for Protocol Buffer messages.
//// It creates functions that parse binary Protocol Buffer data into Gleam values.

import gleam/int
import gleam/list
import gleam/string
import protozoa/internal/codegen/types.{capitalize_first, flatten_type_name}
import protozoa/internal/type_registry.{type TypeRegistry}
import protozoa/parser.{type Field, type Message, type ProtoType}

/// Generate all decoders for a list of messages
pub fn generate_decoders_with_registry(
  messages: List(Message),
  registry: TypeRegistry,
  file_path: String,
) -> String {
  let all_messages = collect_all_messages_flattened(messages)

  all_messages
  |> list.map(fn(message) {
    generate_message_decoder_with_registry(message, registry, file_path)
  })
  |> string.join("\n\n")
}

/// Generate decoder for a single message
pub fn generate_message_decoder_with_registry(
  message: Message,
  _registry: TypeRegistry,
  _file_path: String,
) -> String {
  let decoder_fn_name = string.lowercase(message.name) <> "_decoder"
  let decode_fn_name = "decode_" <> string.lowercase(message.name)

  let decoder_body = generate_decoder_function_body(message)
  let wrapper_body = generate_wrapper_function_body(message, decoder_fn_name)
  let oneof_helpers = generate_oneof_helper_functions(message)
  let map_helpers = generate_map_helper_functions(message)

  let main_decoder =
    "pub fn "
    <> decoder_fn_name
    <> "() -> decode.Decoder("
    <> message.name
    <> ") {\n"
    <> decoder_body
    <> "\n}\n\n"
    <> "pub fn "
    <> decode_fn_name
    <> "(data: BitArray) -> Result("
    <> message.name
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

fn generate_oneof_helper_functions(message: Message) -> String {
  message.oneofs
  |> list.map(fn(oneof) { generate_single_oneof_decoder(message.name, oneof) })
  |> string.join("\n\n")
}

fn generate_map_helper_functions(message: Message) -> String {
  let map_fields =
    list.filter(message.fields, fn(field) {
      case field.field_type {
        parser.Map(_, _) -> True
        _ -> False
      }
    })

  list.map(map_fields, fn(field) {
    case field.field_type {
      parser.Map(key_type, value_type) -> {
        let field_num = int.to_string(field.number)
        generate_map_entry_decoder(field_num, key_type, value_type)
      }
      _ -> ""
      // This shouldn't happen due to filtering
    }
  })
  |> string.join("\n\n")
}

fn generate_map_entry_decoder(
  field_num: String,
  key_type: ProtoType,
  value_type: ProtoType,
) -> String {
  let function_name = "map_entry_" <> field_num <> "_decoder"
  let key_decoder = generate_map_field_decoder(key_type, "1")
  let value_decoder = generate_map_field_decoder(value_type, "2")

  "fn "
  <> function_name
  <> "() -> fn(wire.Field) -> Result(#("
  <> get_gleam_type(key_type)
  <> ", "
  <> get_gleam_type(value_type)
  <> "), decode.DecodeError) {\n"
  <> "  fn(field) {\n"
  <> "    case decode.message_field(field, fn(data) {\n"
  <> "      use key <- decode.then("
  <> key_decoder
  <> ")\n"
  <> "      use value <- decode.then("
  <> value_decoder
  <> ")\n"
  <> "      decode.success(#(key, value))\n"
  <> "    }) {\n"
  <> "      Ok(entry) -> Ok(entry)\n"
  <> "      Error(err) -> Error(err)\n"
  <> "    }\n"
  <> "  }\n"
  <> "}"
}

fn generate_map_field_decoder(
  proto_type: ProtoType,
  field_num: String,
) -> String {
  case proto_type {
    parser.String -> "decode.string_with_default(" <> field_num <> ", \"\")"
    parser.Int32 -> "decode.int32_with_default(" <> field_num <> ", 0)"
    parser.Bool -> "decode.bool_with_default(" <> field_num <> ", False)"
    _ -> "decode.string_with_default(" <> field_num <> ", \"\")"
    // fallback
  }
}

fn get_gleam_type(proto_type: ProtoType) -> String {
  case proto_type {
    parser.String -> "String"
    parser.Int32 -> "Int"
    parser.Bool -> "Bool"
    _ -> "String"
    // fallback
  }
}

fn generate_single_oneof_decoder(
  message_name: String,
  oneof: parser.Oneof,
) -> String {
  let function_name = "oneof_" <> string.lowercase(oneof.name) <> "_decoder"
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

fn generate_oneof_field_checks(fields: List(parser.Field)) -> String {
  case fields {
    [] -> "    Ok(option.None)\n"
    [field] -> {
      let field_num = int.to_string(field.number)
      let base_variant_name = capitalize_first(field.name)
      let variant_name = case base_variant_name, field.field_type {
        "Empty", parser.MessageType("google.protobuf.Empty") -> "EmptyData"
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
        "Empty", parser.MessageType("google.protobuf.Empty") -> "EmptyData"
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

fn get_field_decoder_for_type(field_type: parser.ProtoType) -> String {
  case field_type {
    parser.String -> "decode.string_field"
    parser.Int32 -> "decode.int32_field"
    parser.Bool -> "decode.bool_field"
    parser.Bytes -> "decode.bytes_field"
    parser.Float -> "decode.float_field"
    parser.Double -> "decode.double_field"
    parser.MessageType(name) -> {
      let decoder_name = string.lowercase(flatten_type_name(name)) <> "_decoder"
      "decode.message_field(_, " <> decoder_name <> "())"
    }
    parser.EnumType(name) -> {
      let decoder_name =
        "decode_" <> string.lowercase(flatten_type_name(name)) <> "_field"
      decoder_name
    }
    _ -> "decode.string_field"
    // fallback
  }
}



fn generate_decoder_function_body(message: Message) -> String {
  let field_decoders =
    message.fields
    |> list.map(generate_field_decoder)
    |> string.join("\n")

  // Generate oneof decoders using helper functions
  let oneof_decoders =
    message.oneofs
    |> list.map(fn(oneof) {
      let escaped_oneof_name = types.escape_keyword(oneof.name)
      let function_name = "oneof_" <> string.lowercase(oneof.name) <> "_decoder"
      "  use "
      <> escaped_oneof_name
      <> " <- decode.then("
      <> function_name
      <> "())"
    })
    |> string.join("\n")

  let constructor_call = generate_constructor_call(message)

  case field_decoders, oneof_decoders {
    "", "" -> constructor_call
    fields, "" -> fields <> "\n" <> constructor_call
    "", oneofs -> oneofs <> "\n" <> constructor_call
    fields, oneofs -> fields <> "\n" <> oneofs <> "\n" <> constructor_call
  }
}

fn generate_field_decoder(field: Field) -> String {
  let _field_num = int.to_string(field.number)
  let decoder_call = generate_field_decoder_call(field)

  let escaped_field_name = types.escape_keyword(field.name)
  "  use " <> escaped_field_name <> " <- decode.then(" <> decoder_call <> ")"
}

fn generate_field_decoder_call(field: Field) -> String {
  let field_num = int.to_string(field.number)

  case field.field_type {
    parser.Optional(inner) -> generate_optional_type_decoder(inner, field_num)
    parser.Repeated(inner) -> generate_repeated_type_decoder(inner, field_num)
    _ -> generate_type_decoder(field.field_type, field_num)
  }
}

fn generate_type_decoder(proto_type: ProtoType, field_num: String) -> String {
  case proto_type {
    parser.String -> "decode.string_with_default(" <> field_num <> ", \"\")"
    parser.Int32 -> "decode.int32_with_default(" <> field_num <> ", 0)"
    parser.Int64 -> "decode.int64_with_default(" <> field_num <> ", 0)"
    parser.UInt32 -> "decode.uint32_with_default(" <> field_num <> ", 0)"
    parser.UInt64 -> "decode.uint64_with_default(" <> field_num <> ", 0)"
    parser.SInt32 -> "decode.sint32(" <> field_num <> ")"
    parser.SInt64 -> "decode.sint64(" <> field_num <> ")"
    parser.Fixed32 -> "decode.fixed32(" <> field_num <> ")"
    parser.Fixed64 -> "decode.fixed64(" <> field_num <> ")"
    parser.SFixed32 -> "decode.sfixed32(" <> field_num <> ")"
    parser.SFixed64 -> "decode.sfixed64(" <> field_num <> ")"
    parser.Bool -> "decode.bool_with_default(" <> field_num <> ", False)"
    parser.Bytes -> "decode.bytes(" <> field_num <> ")"
    parser.Float -> "decode.float(" <> field_num <> ")"
    parser.Double -> "decode.double(" <> field_num <> ")"
    parser.MessageType(name) ->
      "decode.nested_message("
      <> field_num
      <> ", "
      <> string.lowercase(flatten_type_name(name))
      <> "_decoder())"
    parser.EnumType(name) ->
      "decode_"
      <> string.lowercase(flatten_type_name(name))
      <> "_field("
      <> field_num
      <> ")"
    parser.Map(_key_type, _value_type) ->
      "decode.repeated_field("
      <> field_num
      <> ", fn(field) { map_entry_"
      <> field_num
      <> "_decoder()(field) })"
    _ -> "decode.fail(\"Unsupported type\")"
  }
}

fn generate_optional_type_decoder(
  inner_type: ProtoType,
  field_num: String,
) -> String {
  case inner_type {
    parser.MessageType(name) ->
      "decode.optional_nested_message("
      <> field_num
      <> ", "
      <> string.lowercase(flatten_type_name(name))
      <> "_decoder())"
    _ ->
      "decode.optional_field("
      <> field_num
      <> ", "
      <> generate_simple_field_decoder_name(inner_type)
      <> ")"
  }
}

fn generate_repeated_type_decoder(
  inner_type: ProtoType,
  field_num: String,
) -> String {
  case inner_type {
    parser.String -> "decode.repeated_string(" <> field_num <> ")"
    parser.Int32 -> "decode.repeated_int32(" <> field_num <> ")"
    parser.EnumType(name) ->
      "decode_repeated_"
      <> string.lowercase(flatten_type_name(name))
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

fn generate_simple_type_decoder(proto_type: ProtoType) -> String {
  case proto_type {
    parser.String -> "decode.string_field(field)"
    parser.Int32 -> "decode.int32_field(field)"
    parser.Int64 -> "decode.int64_field(field)"
    parser.UInt32 -> "decode.uint32_field(field)"
    parser.UInt64 -> "decode.uint64_field(field)"
    parser.Bool -> "decode.bool_field(field)"
    parser.Bytes -> "decode.bytes_field(field)"
    parser.Float -> "decode.float_field(field)"
    parser.Double -> "decode.double_field(field)"
    _ ->
      "Error(decode.DecodeError(expected: \"supported field type\", found: \"unsupported field type\", path: []))"
  }
}

fn generate_simple_field_decoder_name(proto_type: ProtoType) -> String {
  case proto_type {
    parser.String -> "decode.string_field"
    parser.Int32 -> "decode.int32_field"
    parser.Int64 -> "decode.int64_field"
    parser.UInt32 -> "decode.uint32_field"
    parser.UInt64 -> "decode.uint64_field"
    parser.Bool -> "decode.bool_field"
    parser.Bytes -> "decode.bytes_field"
    parser.Float -> "decode.float_field"
    parser.Double -> "decode.double_field"
    _ ->
      "fn(_) { Error(decode.DecodeError(expected: \"supported field type\", found: \"unsupported field type\", path: [])) }"
  }
}

fn generate_constructor_call(message: Message) -> String {
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
    [] -> "  decode.success(" <> message.name <> ")"
    [single] -> "  decode.success(" <> message.name <> "(" <> single <> "))"
    _ -> {
      case list.length(all_names) > 4 {
        True -> {
          let names_str = string.join(all_names, ",\n    ")
          "  decode.success("
          <> message.name
          <> "(\n    "
          <> names_str
          <> ",\n  ))"
        }
        False -> {
          let names_str = string.join(all_names, ", ")
          "  decode.success(" <> message.name <> "(" <> names_str <> "))"
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
    let nested =
      collect_nested_messages_flattened(msg.nested_messages, msg.name)
    [msg, ..list.append(nested, acc)]
  })
}

fn collect_nested_messages_flattened(
  nested_messages: List(Message),
  parent_name: String,
) -> List(Message) {
  list.fold(nested_messages, [], fn(acc, nested_msg) {
    let flattened_name = parent_name <> nested_msg.name
    let flattened_msg = parser.Message(..nested_msg, name: flattened_name)
    let deeper_nested =
      collect_nested_messages_flattened(
        nested_msg.nested_messages,
        flattened_name,
      )
    [flattened_msg, ..list.append(deeper_nested, acc)]
  })
}

