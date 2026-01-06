//// Type Helper Module
////
//// This module provides helper functions for code generation, including type
//// name resolution, keyword escaping, and name formatting.

import gleam/list
import gleam/option
import gleam/string
import justin
import protozoa/internal/type_registry.{type TypeRegistry}
import protozoa/parser/proto.{type Type}

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
  "case", "const", "fn", "if", "import", "let", "opaque", "pub", "todo", "type",
  "use", "assert", "try", "panic", "auto", "delegate", "derive", "echo", "else",
  "external", "macro", "module", "test", "as", "when",
]

/// Escape reserved Gleam keywords by appending underscore
pub fn escape_keyword(name: String) -> String {
  case list.contains(gleam_keywords, name) {
    True -> name <> "_"
    False -> name
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

/// Resolve a proto type to its Gleam string representation
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

/// Flatten a fully qualified type name to a single identifier
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
    "google.protobuf.SourceContext" -> "SourceContext"
    "google.protobuf.Type" -> "Type"
    "google.protobuf.Field" -> "Field"
    "google.protobuf.Enum" -> "Enum"
    "google.protobuf.EnumValue" -> "EnumValue"
    "google.protobuf.Option" -> "Option"
    "google.protobuf.Syntax" -> "Syntax"
    "google.protobuf.FieldKind" -> "FieldKind"
    "google.protobuf.FieldCardinality" -> "FieldCardinality"
    "google.protobuf.Api" -> "Api"
    "google.protobuf.Method" -> "Method"
    "google.protobuf.Mixin" -> "Mixin"
    _ -> {
      // Convert dotted names like "base.BaseMessage" to "BaseBaseMessage"
      name
      |> string.split(".")
      |> list.map(capitalize_first)
      |> string.join("")
    }
  }
}

/// Capitalize first letter of each word (snake_case to PascalCase)
pub fn capitalize_first(str: String) -> String {
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
