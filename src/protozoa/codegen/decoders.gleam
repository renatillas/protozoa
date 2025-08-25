//// Decoder Generation Module
////
//// This module handles generating Gleam decoding functions for Protocol Buffer messages.
//// It creates functions that parse binary Protocol Buffer data into Gleam values.

import gleam/int
import gleam/list
import gleam/string
import protozoa/internals/type_registry.{type TypeRegistry}
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
  
  "pub fn " <> decoder_fn_name <> "() -> decode.Decoder(" <> message.name <> ") {\n" <>
  decoder_body <> "\n}\n\n" <>
  "pub fn " <> decode_fn_name <> "(data: BitArray) -> Result(" <> message.name <> ", decode.DecodeError) {\n" <>
  wrapper_body <> "\n}"
}

// Helper functions

fn generate_decoder_function_body(message: Message) -> String {
  let field_decoders = 
    message.fields
    |> list.map(generate_field_decoder)
    |> string.join("\n")
  
  // For now, oneof fields are not implemented - they should be option.None
  let oneof_decoders = 
    message.oneofs
    |> list.map(fn(oneof) {
      "  let " <> oneof.name <> " = option.None"
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
  
  "  use " <> field.name <> " <- decode.subrecord(" <> decoder_call <> ")"
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
    parser.MessageType(name) -> "decode.nested_message(" <> field_num <> ", " <> string.lowercase(flatten_name(name)) <> "_decoder())"
    parser.EnumType(name) -> "decode_" <> string.lowercase(flatten_name(name)) <> "_field(" <> field_num <> ")"
    _ -> "decode.fail(\"Unsupported type\")"
  }
}

fn generate_optional_type_decoder(inner_type: ProtoType, field_num: String) -> String {
  case inner_type {
    parser.MessageType(name) -> "decode.optional_nested_message(" <> field_num <> ", " <> string.lowercase(flatten_name(name)) <> "_decoder())"
    _ -> "decode.optional_field(" <> field_num <> ", fn(field) { " <> generate_simple_type_decoder(inner_type) <> " })"
  }
}

fn generate_repeated_type_decoder(inner_type: ProtoType, field_num: String) -> String {
  case inner_type {
    parser.String -> "decode.repeated_string(" <> field_num <> ")"
    parser.Int32 -> "decode.repeated_int32(" <> field_num <> ")"
    _ -> "decode.repeated_field(" <> field_num <> ", fn(field) { " <> generate_simple_type_decoder(inner_type) <> " })"
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
    _ -> "Error(decode.DecodeError(\"Unsupported field type\"))"
  }
}

fn generate_constructor_call(message: Message) -> String {
  let field_names = 
    message.fields
    |> list.map(fn(field) { field.name <> ": " <> field.name })
  
  let oneof_names =
    message.oneofs
    |> list.map(fn(oneof) { oneof.name <> ": " <> oneof.name })
  
  let all_names = list.append(field_names, oneof_names)
  
  case all_names {
    [] -> "  decode.success(" <> message.name <> ")"
    _ -> {
      let names_str = string.join(all_names, ", ")
      "  decode.success(" <> message.name <> "(" <> names_str <> "))"
    }
  }
}

fn generate_wrapper_function_body(_message: Message, decoder_fn_name: String) -> String {
  "  decode.decode(data, " <> decoder_fn_name <> "())"
}

// Utility functions

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

fn flatten_name(name: String) -> String {
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

