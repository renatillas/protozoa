//// Type Generation Module
////
//// This module handles generating Gleam type definitions from Protocol Buffer messages.
//// It creates record types, enum types, and oneof types with proper nesting support.

import gleam/list
import gleam/option
import gleam/set
import gleam/string
import justin
import protozoa/internal/type_registry.{type TypeRegistry}
import protozoa/parser/proto.{
  type Enum, type Field, type FieldOption, type Message, type Type,
}

/// Codegen context - bundles registry, file path, and pre-computed package
pub type Context {
  Context(registry: TypeRegistry, file_path: String, package: String)
}

/// Create a new codegen context
pub fn new_ctx(registry: TypeRegistry, file_path: String) -> Context {
  let package = case type_registry.get_file_package(registry, file_path) {
    option.Some(pkg) -> pkg
    option.None -> ""
  }
  Context(registry: registry, file_path: file_path, package: package)
}

// Reserved Gleam keywords that need to be escaped when used as field names
const gleam_keywords = [
  "case",
  "const",
  "fn",
  "if",
  "import",
  "let",
  "opaque",
  "pub",
  "todo",
  "type",
  "use",
  "assert",
  "try",
  "panic",
  "auto",
  "delegate",
  "derive",
  "echo",
  "else",
  "external",
  "macro",
  "module",
  "test",
  "as",
  "when",
]

/// Escape reserved Gleam keywords by appending underscore
pub fn escape_keyword(name: String) -> String {
  case list.contains(gleam_keywords, name) {
    True -> name <> "_"
    False -> name
  }
}

/// Generate all type definitions for a list of messages
pub fn generate_types(messages: List(Message), ctx: Context) -> String {
  let generated_enum_names = set.new()
  let #(all_types, _) =
    messages
    |> list.fold(#([], generated_enum_names), fn(acc, msg) {
      let #(existing_types, seen_enums) = acc
      let #(new_types, updated_enums) = generate_msg_types(msg, ctx, seen_enums)
      #(list.append(existing_types, new_types), updated_enums)
    })

  all_types
  |> string.join("\n\n")
}

/// Generate a single message type and its nested types
pub fn generate_msg_types(
  message: Message,
  ctx: Context,
  seen_enums: set.Set(String),
) -> #(List(String), set.Set(String)) {
  // Generate nested messages first
  let #(nested_types, enums_after_nested) =
    message.nested_messages
    |> list.fold(#([], seen_enums), fn(acc, nested_msg) {
      let #(existing_nested, current_enums) = acc
      let flattened_msg = flatten_nested_message(nested_msg, message)
      let #(new_nested_types, updated_enums) =
        generate_msg_types(flattened_msg, ctx, current_enums)
      #(list.append(existing_nested, new_nested_types), updated_enums)
    })

  // Generate nested enums
  let #(nested_enum_types, enums_after_enum_gen) =
    generate_nested_enum_types(message, ctx, enums_after_nested)

  // Generate oneof types
  let oneof_types =
    message.oneofs
    |> list.map(fn(oneof) { generate_oneof_type(message, oneof, ctx) })

  // Generate the main message type
  let main_type = generate_message_type(message, ctx)

  // Combine all types
  let all_types =
    list.flatten([nested_types, nested_enum_types, oneof_types, [main_type]])

  #(all_types, enums_after_enum_gen)
}

/// Generate enum types for all enums in a list
pub fn generate_enum_types(enums: List(Enum), ctx: Context) -> String {
  enums
  |> list.map(fn(enum) { generate_enum_type(enum, ctx) })
  |> string.join("\n\n")
}

/// Generate a single enum type
pub fn generate_enum_type(enum: Enum, ctx: Context) -> String {
  let type_name = qualified_type(enum.name, ctx)
  let variants =
    enum.values
    |> list.map(fn(variant) { "  " <> capitalize_first(variant.name) })
    |> string.join("\n")

  "pub type " <> type_name <> " {\n" <> variants <> "\n}"
}

/// Generate a single message type
fn generate_message_type(message: Message, ctx: Context) -> String {
  // Get the fully qualified type name for this message
  let type_name = qualified_type(message.name, ctx)

  let fields =
    message.fields
    |> list.map(fn(field) {
      let gleam_type = resolve_field_type(field, ctx, message)
      let escaped_name = escape_keyword(field.name)
      let deprecation_comment = case has_deprecated_option(field.options) {
        True -> " // @deprecated"
        False -> ""
      }
      "    " <> escaped_name <> ": " <> gleam_type <> deprecation_comment
    })

  let oneofs =
    message.oneofs
    |> list.map(fn(oneof) {
      let oneof_type_name = type_name <> capitalize_first(oneof.name)
      let escaped_name = escape_keyword(oneof.name)
      "    " <> escaped_name <> ": option.Option(" <> oneof_type_name <> ")"
    })

  let all_fields = list.append(fields, oneofs)

  case all_fields {
    [] -> "pub type " <> type_name <> " {\n  " <> type_name <> "\n}"
    _ -> {
      let fields_str = string.join(all_fields, ",\n")
      "pub type "
      <> type_name
      <> " {\n  "
      <> type_name
      <> "(\n"
      <> fields_str
      <> ",\n  )\n}"
    }
  }
}

/// Get the fully qualified and flattened type name for a message
pub fn qualified_type(name: String, ctx: Context) -> String {
  // Build fully qualified name and flatten it
  let fqn = case ctx.package {
    "" -> name
    pkg -> pkg <> "." <> name
  }
  flatten_type_name(fqn)
}

/// Get the qualified snake_case function name suffix for a message
/// e.g., "base" package + "BaseMessage" -> "base_base_message"
pub fn qualified_fn(name: String, ctx: Context) -> String {
  // Get the qualified type name first
  let type_name = qualified_type(name, ctx)
  // Convert to snake_case
  justin.snake_case(type_name)
}

/// Generate oneof type
fn generate_oneof_type(
  parent_message: Message,
  oneof: proto.Oneof,
  ctx: Context,
) -> String {
  // Get qualified parent type name and append oneof name
  let parent_type_name = qualified_type(parent_message.name, ctx)
  let type_name = parent_type_name <> capitalize_first(oneof.name)
  let variants =
    oneof.fields
    |> list.map(fn(field) {
      let base_variant_name = capitalize_first(field.name)
      // Qualify the field type if it's a nested type
      let qualified =
        qualify_nested_field_type(
          field.field_type,
          parent_message.name,
          parent_message,
        )
      let gleam_type = resolve_type(qualified, ctx)
      // Avoid naming conflicts with well-known types
      let variant_name = case base_variant_name, gleam_type {
        "Empty", "Empty" -> "EmptyData"
        "StringValue", "String" -> "StringValueVariant"
        "BoolValue", "Bool" -> "BoolValueVariant"
        "ListValue", "ListValue" -> "ListValueVariant"
        name, _ -> name
      }
      "  " <> variant_name <> "(" <> gleam_type <> ")"
    })
    |> string.join("\n")

  "pub type " <> type_name <> " {\n" <> variants <> "\n}"
}

// Helper functions

/// Check if field has deprecated option set to true
fn has_deprecated_option(options: List(FieldOption)) -> Bool {
  list.any(options, fn(option) {
    case option {
      proto.Deprecated(True) -> True
      _ -> False
    }
  })
}

fn flatten_nested_message(nested_msg: Message, parent: Message) -> Message {
  // The prefix for nested types should include both parent and current message names
  let full_prefix = parent.name <> nested_msg.name

  let fixed_fields =
    nested_msg.fields
    |> list.map(fn(field) {
      let updated_field_type =
        qualify_nested_field_type(field.field_type, full_prefix, nested_msg)
      proto.Field(..field, field_type: updated_field_type)
    })

  // Also fix oneofs to use qualified nested type names
  let fixed_oneofs =
    nested_msg.oneofs
    |> list.map(fn(oneof) {
      let fixed_oneof_fields =
        oneof.fields
        |> list.map(fn(field) {
          let updated_field_type =
            qualify_nested_field_type(field.field_type, full_prefix, nested_msg)
          proto.Field(..field, field_type: updated_field_type)
        })
      proto.Oneof(..oneof, fields: fixed_oneof_fields)
    })

  proto.Message(
    name: parent.name <> nested_msg.name,
    fields: fixed_fields,
    oneofs: fixed_oneofs,
    nested_messages: nested_msg.nested_messages,
    nested_enums: nested_msg.nested_enums,
  )
}

fn generate_nested_enum_types(
  message: Message,
  ctx: Context,
  seen_enums: set.Set(String),
) -> #(List(String), set.Set(String)) {
  message.nested_enums
  |> list.fold(#([], seen_enums), fn(acc, nested_enum) {
    let #(existing_enum_types, current_enums) = acc
    let flattened_name = message.name <> nested_enum.name

    case set.contains(current_enums, flattened_name) {
      True -> acc
      False -> {
        let flattened_enum =
          proto.Enum(name: flattened_name, values: nested_enum.values)
        let enum_code = generate_enum_type(flattened_enum, ctx)
        let updated_enums = set.insert(current_enums, flattened_name)
        #(list.append(existing_enum_types, [enum_code]), updated_enums)
      }
    }
  })
}

fn resolve_field_type(
  field: Field,
  ctx: Context,
  parent_message: Message,
) -> String {
  // Get the qualified parent name (including package prefix)
  let qualified_parent_name = qualified_type(parent_message.name, ctx)

  // First, qualify the field type if it references a nested type
  let qualified =
    qualify_nested_type(field.field_type, qualified_parent_name, parent_message)

  case qualified {
    proto.Repeated(inner) -> {
      let qualified_inner =
        qualify_nested_type(inner, qualified_parent_name, parent_message)
      "List(" <> resolve_type(qualified_inner, ctx) <> ")"
    }
    proto.Optional(inner) -> {
      let qualified_inner =
        qualify_nested_type(inner, qualified_parent_name, parent_message)
      "option.Option(" <> resolve_type(qualified_inner, ctx) <> ")"
    }
    _ -> resolve_type(qualified, ctx)
  }
}

pub fn resolve_type(proto_type: Type, ctx: Context) -> String {
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
    proto.Double -> "Float"
    proto.Float -> "Float"
    proto.MessageType(name) -> resolve_external_type(name, ctx)
    proto.EnumType(name) -> resolve_external_type(name, ctx)
    proto.Repeated(inner) -> "List(" <> resolve_type(inner, ctx) <> ")"
    proto.Optional(inner) -> "option.Option(" <> resolve_type(inner, ctx) <> ")"
    proto.Map(key, value) ->
      "List(#("
      <> resolve_type(key, ctx)
      <> ", "
      <> resolve_type(value, ctx)
      <> "))"
  }
}

fn qualify_nested_field_type(
  proto_type: Type,
  parent_name: String,
  parent_message: Message,
) -> Type {
  case proto_type {
    proto.MessageType(name) -> {
      case is_nested_type_in_message(name, parent_message) {
        True -> proto.MessageType(parent_name <> name)
        False -> proto_type
      }
    }
    proto.EnumType(name) -> {
      case is_nested_enum_in_message(name, parent_message) {
        True -> proto.EnumType(parent_name <> name)
        False -> proto_type
      }
    }
    _ -> proto_type
  }
}

/// Qualify nested field type with already-qualified parent name
/// Used when we need the full package-prefixed name for the nested type
fn qualify_nested_type(
  proto_type: Type,
  qualified_parent_name: String,
  parent_message: Message,
) -> Type {
  case proto_type {
    proto.MessageType(name) -> {
      case is_nested_type_in_message(name, parent_message) {
        // Use the already-qualified parent name directly
        True -> proto.MessageType(qualified_parent_name <> name)
        False -> proto_type
      }
    }
    proto.EnumType(name) -> {
      case is_nested_enum_in_message(name, parent_message) {
        True -> proto.EnumType(qualified_parent_name <> name)
        False -> proto_type
      }
    }
    _ -> proto_type
  }
}

fn is_nested_type_in_message(type_name: String, parent_message: Message) -> Bool {
  parent_message.nested_messages
  |> list.any(fn(nested) { nested.name == type_name })
}

fn is_nested_enum_in_message(enum_name: String, parent_message: Message) -> Bool {
  parent_message.nested_enums
  |> list.any(fn(nested_enum) { nested_enum.name == enum_name })
}

fn resolve_external_type(name: String, ctx: Context) -> String {
  // Try to resolve the type through the registry
  case type_registry.resolve_type_reference(ctx.registry, name, ctx.package) {
    Ok(resolved_fqn) -> {
      // All types are merged into a single Gleam module, so just flatten the name
      flatten_type_name(resolved_fqn)
    }
    Error(_) -> {
      // Fallback for types not in registry
      flatten_type_name(name)
    }
  }
}

pub fn flatten_type_name(name: String) -> String {
  // Handle well-known types
  case name {
    "google.protobuf.Timestamp" -> "Timestamp"
    "google.protobuf.Duration" -> "Duration"
    "google.protobuf.FieldMask" -> "FieldMask"
    "google.protobuf.Empty" -> "Empty"
    "google.protobuf.Any" -> "Any"
    "google.protobuf.Struct" -> "Struct"
    "google.protobuf.Value" -> "Value"
    "google.protobuf.ListValue" -> "ListValue"
    "google.protobuf.NullValue" -> "NullValue"
    "google.protobuf.DoubleValue" -> "DoubleValue"
    "google.protobuf.FloatValue" -> "FloatValue"
    "google.protobuf.Int64Value" -> "Int64Value"
    "google.protobuf.UInt64Value" -> "UInt64Value"
    "google.protobuf.Int32Value" -> "Int32Value"
    "google.protobuf.UInt32Value" -> "UInt32Value"
    "google.protobuf.BoolValue" -> "BoolValue"
    "google.protobuf.StringValue" -> "StringValue"
    "google.protobuf.BytesValue" -> "BytesValue"
    // Types from source_context.proto
    "google.protobuf.SourceContext" -> "SourceContext"
    // Types from type.proto
    "google.protobuf.Type" -> "Type"
    "google.protobuf.Field" -> "Field"
    "google.protobuf.Enum" -> "Enum"
    "google.protobuf.EnumValue" -> "EnumValue"
    "google.protobuf.Option" -> "Option"
    "google.protobuf.Syntax" -> "Syntax"
    "google.protobuf.FieldKind" -> "FieldKind"
    "google.protobuf.FieldCardinality" -> "FieldCardinality"
    // Types from api.proto
    "google.protobuf.Api" -> "Api"
    "google.protobuf.Method" -> "Method"
    "google.protobuf.Mixin" -> "Mixin"
    _ -> {
      // Convert dotted names like "base.BaseMessage" to "BaseBaseMessage"
      // Each part needs to be capitalized when joined
      name
      |> string.split(".")
      |> list.map(capitalize_first)
      |> string.join("")
    }
  }
}

pub fn capitalize_first(str: String) -> String {
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
