//// Trick-based Code Generation Module
////
//// This module uses the trick library for type-safe Gleam code generation
//// instead of string concatenation.

import gleam/list
import gleam/option
import gleam/result
import gleam/string
import justin
import protozoa/internal/codegen/types.{type Context}
import protozoa/internal/type_registry
import protozoa/parser/proto.{type Enum, type Field, type Message, type Type}
import trick

// =============================================================================
// Type Mappings
// =============================================================================

/// Convert a protobuf type to a trick Type
pub fn proto_to_trick_type(proto_type: Type, ctx: Context) -> trick.Type {
  case proto_type {
    proto.Double | proto.Float -> trick.Custom("gleam", "Float", [])
    proto.Int32
    | proto.Int64
    | proto.UInt32
    | proto.UInt64
    | proto.SInt32
    | proto.SInt64
    | proto.Fixed32
    | proto.Fixed64
    | proto.SFixed32
    | proto.SFixed64 -> trick.Custom("gleam", "Int", [])
    proto.Bool -> trick.Custom("gleam", "Bool", [])
    proto.String | proto.Bytes -> trick.Custom("gleam", "String", [])
    proto.MessageType(name) -> {
      let resolved = resolve_message_type(name, ctx)
      trick.Custom("", resolved, [])
    }
    proto.EnumType(name) -> {
      let resolved = resolve_enum_type(name, ctx)
      trick.Custom("", resolved, [])
    }
    proto.Map(key_type, value_type) -> {
      let key = proto_to_trick_type(key_type, ctx)
      let value = proto_to_trick_type(value_type, ctx)
      trick.Custom("gleam/dict", "Dict", [key, value])
    }
    proto.Repeated(inner_type) -> {
      let inner = proto_to_trick_type(inner_type, ctx)
      trick.Custom("gleam", "List", [inner])
    }
    proto.Optional(inner_type) -> {
      let inner = proto_to_trick_type(inner_type, ctx)
      trick.Custom("gleam/option", "Option", [inner])
    }
  }
}

/// Resolve a message type name to its Gleam equivalent
fn resolve_message_type(name: String, ctx: Context) -> String {
  // Check if it's a well-known type
  case name {
    "google.protobuf.Empty" -> "Empty"
    "google.protobuf.Timestamp" -> "Timestamp"
    "google.protobuf.Duration" -> "Duration"
    "google.protobuf.Any" -> "Any"
    "google.protobuf.StringValue" -> "String"
    "google.protobuf.BoolValue" -> "Bool"
    "google.protobuf.Int32Value" | "google.protobuf.Int64Value" -> "Int"
    "google.protobuf.FloatValue" | "google.protobuf.DoubleValue" -> "Float"
    "google.protobuf.BytesValue" -> "String"
    "google.protobuf.ListValue" -> "ListValue"
    "google.protobuf.Value" -> "Value"
    "google.protobuf.Struct" -> "Struct"
    _ -> {
      // Check if it's in the registry
      case type_registry.resolve_type_reference(ctx.registry, name, ctx.package) {
        Ok(resolved) -> types.flatten_type_name(resolved)
        Error(_) -> {
          // Local type - qualify with package
          case ctx.package {
            "" -> types.flatten_type_name(name)
            pkg -> types.flatten_type_name(pkg <> "." <> name)
          }
        }
      }
    }
  }
}

/// Resolve an enum type name
fn resolve_enum_type(name: String, ctx: Context) -> String {
  case type_registry.resolve_type_reference(ctx.registry, name, ctx.package) {
    Ok(resolved) -> types.flatten_type_name(resolved)
    Error(_) -> {
      case ctx.package {
        "" -> types.flatten_type_name(name)
        pkg -> types.flatten_type_name(pkg <> "." <> name)
      }
    }
  }
}

// =============================================================================
// Type Generation
// =============================================================================

/// Generate a message type definition using trick
pub fn generate_message_type(message: Message, ctx: Context) -> trick.Definition {
  let type_name = types.qualified_type(message.name, ctx)

  // Convert fields to trick TypeFields
  let fields =
    list.map(message.fields, fn(field) {
      let gleam_type = field_to_trick_type(field, message, ctx)
      let escaped_name = types.escape_keyword(field.name)
      trick.TypeField(escaped_name, gleam_type)
    })

  // Add oneof fields as Option types
  let oneof_fields =
    list.map(message.oneofs, fn(oneof) {
      let oneof_type_name = type_name <> types.capitalize_first(oneof.name)
      let escaped_name = types.escape_keyword(oneof.name)
      let option_type =
        trick.Custom("gleam/option", "Option", [
          trick.Custom("", oneof_type_name, []),
        ])
      trick.TypeField(escaped_name, option_type)
    })

  let all_fields = list.append(fields, oneof_fields)

  // Create the variant (single constructor with same name as type)
  let variant = trick.Variant(type_name, all_fields)

  trick.custom_type(trick.Public, type_name, [], [variant], fn() {
    trick.empty()
  })
}

/// Generate an enum type definition using trick
pub fn generate_enum_type(enum: Enum, ctx: Context) -> trick.Definition {
  let type_name = types.qualified_type(enum.name, ctx)

  // Create variants for each enum value (no fields)
  let variants =
    list.map(enum.values, fn(value) {
      trick.Variant(types.capitalize_first(value.name), [])
    })

  trick.custom_type(trick.Public, type_name, [], variants, fn() {
    trick.empty()
  })
}

/// Generate a oneof type definition using trick
pub fn generate_oneof_type(
  parent_message: Message,
  oneof: proto.Oneof,
  ctx: Context,
) -> trick.Definition {
  let parent_type_name = types.qualified_type(parent_message.name, ctx)
  let type_name = parent_type_name <> types.capitalize_first(oneof.name)

  // Create variants for each oneof field
  let variants =
    list.map(oneof.fields, fn(field) {
      let base_variant_name = types.capitalize_first(field.name)
      let gleam_type = oneof_field_to_trick_type(field, ctx)

      // Avoid naming conflicts with well-known types
      let variant_name = normalize_variant_name(base_variant_name, gleam_type)

      trick.Variant(variant_name, [trick.TypeField("value", gleam_type)])
    })

  trick.custom_type(trick.Public, type_name, [], variants, fn() {
    trick.empty()
  })
}

// =============================================================================
// Import Generation
// =============================================================================

/// Generate standard imports for generated proto files
pub fn standard_imports() -> List(trick.Import) {
  [
    trick.QualifiedImport("gleam/option"),
    trick.QualifiedImport("gleam/list"),
    trick.QualifiedImport("gleam/dict"),
    trick.QualifiedImport("gleam/result"),
    trick.UnqualifiedImport("protozoa/encode", ["encode"]),
    trick.UnqualifiedImport("protozoa/decode", ["decode"]),
  ]
}

// =============================================================================
// Helper Functions
// =============================================================================

/// Convert a field to its trick Type
fn field_to_trick_type(
  field: Field,
  _parent_message: Message,
  ctx: Context,
) -> trick.Type {
  // The field_type already includes Repeated/Optional wrappers
  proto_to_trick_type(field.field_type, ctx)
}

/// Convert a oneof field to its Gleam type
fn oneof_field_to_trick_type(field: Field, ctx: Context) -> trick.Type {
  // Oneof fields don't have Repeated/Optional wrappers in the type
  proto_to_trick_type(field.field_type, ctx)
}

/// Normalize variant names to avoid conflicts with well-known types
fn normalize_variant_name(base_name: String, gleam_type: trick.Type) -> String {
  let type_name = case gleam_type {
    trick.Custom(_, name, _) -> name
    _ -> ""
  }

  case base_name, type_name {
    "Empty", "Empty" -> "EmptyData"
    "StringValue", "String" -> "StringValueVariant"
    "BoolValue", "Bool" -> "BoolValueVariant"
    "ListValue", "ListValue" -> "ListValueVariant"
    name, _ -> name
  }
}

/// Convert a Gleam type string to trick.Type (for string-based types)
pub fn string_to_trick_type(type_str: String) -> trick.Type {
  case type_str {
    "Int" -> trick.Custom("gleam", "Int", [])
    "Float" -> trick.Custom("gleam", "Float", [])
    "String" -> trick.Custom("gleam", "String", [])
    "Bool" -> trick.Custom("gleam", "Bool", [])
    "Nil" -> trick.Custom("gleam", "Nil", [])
    _ -> trick.Custom("", type_str, [])
  }
}

// =============================================================================
// Encoder Generation
// =============================================================================

/// Generate an encoder function for a message using trick
pub fn generate_encoder(message: Message, ctx: Context) -> trick.Definition {
  let qualified_fn_name = types.qualified_fn(message.name, ctx)
  let qualified_type_name = types.qualified_type(message.name, ctx)
  let function_name = "encode_" <> qualified_fn_name

  let is_empty = list.is_empty(message.fields) && list.is_empty(message.oneofs)

  let param_name = case is_empty {
    True -> "_" <> qualified_fn_name
    False -> types.escape_keyword(qualified_fn_name)
  }

  let param_type = trick.Custom("", qualified_type_name, [])

  trick.pub_function(
    function_name,
    {
      use msg <- trick.parameter(param_name, param_type)
      generate_encoder_body(message, msg, ctx)
      |> trick.expression
      |> trick.function_body
    },
    fn(_) { trick.empty() },
  )
}

/// Generate the encoder function body
fn generate_encoder_body(
  message: Message,
  msg: trick.Expression(trick.Variable),
  ctx: Context,
) -> trick.Expression(trick.Variable) {
  // Separate different field types
  let #(repeated_and_map_fields, regular_fields) =
    list.partition(message.fields, fn(field) {
      case field.field_type {
        proto.Repeated(_) -> True
        proto.Map(_, _) -> True
        _ -> False
      }
    })

  let #(map_fields, repeated_fields) =
    list.partition(repeated_and_map_fields, fn(field) {
      case field.field_type {
        proto.Map(_, _) -> True
        _ -> False
      }
    })

  // Generate field encoders
  let regular_encoders =
    list.map(regular_fields, fn(field) {
      generate_field_encoder_expr(field, msg, ctx)
    })

  let oneof_encoders =
    list.map(message.oneofs, fn(oneof) {
      generate_oneof_encoder_expr(message.name, oneof, msg, ctx)
    })

  let all_encoders = list.append(regular_encoders, oneof_encoders)

  // Handle different cases
  case repeated_fields, map_fields {
    [], [] ->
      // Simple case: no repeated/map fields
      trick.ext_call("encode.message", [trick.list(all_encoders)])

    _, _ ->
      // Complex case with repeated/map fields - need let bindings
      generate_encoder_body_with_collections(
        repeated_fields,
        map_fields,
        all_encoders,
        msg,
        ctx,
      )
  }
}

/// Generate encoder body when there are repeated/map fields
fn generate_encoder_body_with_collections(
  repeated_fields: List(Field),
  map_fields: List(Field),
  regular_encoders: List(trick.Expression(trick.Variable)),
  msg: trick.Expression(trick.Variable),
  ctx: Context,
) -> trick.Expression(trick.Variable) {
  // Build the statement block with let bindings
  let statement = build_collection_bindings(
    repeated_fields,
    map_fields,
    regular_encoders,
    msg,
    ctx,
    [],
  )

  trick.block(statement)
}

/// Build let bindings for repeated/map fields and final encode.message call
fn build_collection_bindings(
  repeated_fields: List(Field),
  map_fields: List(Field),
  regular_encoders: List(trick.Expression(trick.Variable)),
  msg: trick.Expression(trick.Variable),
  ctx: Context,
  bound_vars: List(#(String, trick.Expression(trick.Variable))),
) -> trick.Statement {
  case repeated_fields {
    [field, ..rest] -> {
      let var_name = types.escape_keyword(field.name) <> "_fields"
      let mapper_expr = generate_repeated_mapper(field, msg, ctx)

      trick.variable(var_name, mapper_expr, fn(var) {
        build_collection_bindings(
          rest,
          map_fields,
          regular_encoders,
          msg,
          ctx,
          [#(var_name, var), ..bound_vars],
        )
      })
    }
    [] ->
      case map_fields {
        [field, ..rest] -> {
          let var_name = types.escape_keyword(field.name) <> "_fields"
          let mapper_expr = generate_map_mapper(field, msg, ctx)

          trick.variable(var_name, mapper_expr, fn(var) {
            build_collection_bindings(
              [],
              rest,
              regular_encoders,
              msg,
              ctx,
              [#(var_name, var), ..bound_vars],
            )
          })
        }
        [] ->
          // All bindings done, now generate the final encode.message call
          generate_final_encoder_call(regular_encoders, bound_vars)
      }
  }
}

/// Generate the final encode.message call with list.flatten if needed
fn generate_final_encoder_call(
  regular_encoders: List(trick.Expression(trick.Variable)),
  bound_vars: List(#(String, trick.Expression(trick.Variable))),
) -> trick.Statement {
  case bound_vars, regular_encoders {
    [], [] ->
      trick.expression(trick.ext_call("encode.message", [trick.list([])]))

    vars, [] -> {
      // Only collection fields
      let var_exprs = list.map(list.reverse(vars), fn(v) { v.1 })
      let flattened = trick.ext_call("list.flatten", [trick.list(var_exprs)])
      trick.expression(trick.ext_call("encode.message", [flattened]))
    }

    [], encoders ->
      // Only regular encoders
      trick.expression(trick.ext_call("encode.message", [trick.list(encoders)]))

    vars, encoders -> {
      // Mix of collection fields and regular encoders
      let var_exprs = list.map(list.reverse(vars), fn(v) { v.1 })
      // Wrap each regular encoder in a single-item list
      let encoder_lists =
        list.map(encoders, fn(enc) { trick.list([enc]) })
      let all_lists = list.append(var_exprs, encoder_lists)
      let flattened = trick.ext_call("list.flatten", [trick.list(all_lists)])
      trick.expression(trick.ext_call("encode.message", [flattened]))
    }
  }
}

/// Generate list.map expression for repeated field
fn generate_repeated_mapper(
  field: Field,
  msg: trick.Expression(trick.Variable),
  ctx: Context,
) -> trick.Expression(trick.Variable) {
  let escaped_field_name = types.escape_keyword(field.name)
  let field_access = trick.field_access(msg, escaped_field_name)

  case field.field_type {
    proto.Repeated(inner_type) -> {
      let mapper = trick.anonymous({
        use v <- trick.parameter("v", proto_to_trick_type(inner_type, ctx))
        generate_required_encoder_expr(inner_type, v, field.number, ctx)
        |> trick.expression
        |> trick.function_body
      })
      trick.ext_call("list.map", [field_access, mapper])
    }
    _ -> field_access
  }
}

/// Generate list.map expression for map field
fn generate_map_mapper(
  field: Field,
  msg: trick.Expression(trick.Variable),
  ctx: Context,
) -> trick.Expression(trick.Variable) {
  let escaped_field_name = types.escape_keyword(field.name)
  let field_access = trick.field_access(msg, escaped_field_name)

  case field.field_type {
    proto.Map(key_type, value_type) -> {
      let key_trick_type = proto_to_trick_type(key_type, ctx)
      let value_trick_type = proto_to_trick_type(value_type, ctx)
      let pair_type = trick.Tuple([key_trick_type, value_trick_type])

      let mapper = trick.anonymous({
        use pair <- trick.parameter("pair", pair_type)
        // Generate: let #(key, value) = pair
        // For now, use tuple access
        let key_access = trick.tuple_index(pair, 0)
        let value_access = trick.tuple_index(pair, 1)
        let key_encoder = generate_map_key_encoder_expr(key_type, key_access)
        let value_encoder =
          generate_map_value_encoder_expr(value_type, value_access, ctx)

        trick.ext_call("encode.field", [
          trick.int(field.number),
          trick.ident("wire.LengthDelimited", trick.Custom("", "WireType", [])),
          trick.ext_call("encode.length_delimited", [
            trick.ext_call("encode.message", [
              trick.list([key_encoder, value_encoder]),
            ]),
          ]),
        ])
        |> trick.expression
        |> trick.function_body
      })
      trick.ext_call("list.map", [field_access, mapper])
    }
    _ -> field_access
  }
}

/// Generate encoder for a map key (field number 1)
fn generate_map_key_encoder_expr(
  proto_type: Type,
  access: trick.Expression(trick.Variable),
) -> trick.Expression(trick.Variable) {
  let num = trick.int(1)
  case proto_type {
    proto.String -> trick.ext_call("encode.string_field", [num, access])
    proto.Int32 -> trick.ext_call("encode.int32_field", [num, access])
    proto.Int64 -> trick.ext_call("encode.int64_field", [num, access])
    proto.UInt32 -> trick.ext_call("encode.uint32_field", [num, access])
    proto.UInt64 -> trick.ext_call("encode.uint64_field", [num, access])
    proto.SInt32 -> trick.ext_call("encode.sint32_field", [num, access])
    proto.SInt64 -> trick.ext_call("encode.sint64_field", [num, access])
    proto.Fixed32 -> trick.ext_call("encode.fixed32_field", [num, access])
    proto.Fixed64 -> trick.ext_call("encode.fixed64_field", [num, access])
    proto.SFixed32 -> trick.ext_call("encode.sfixed32_field", [num, access])
    proto.SFixed64 -> trick.ext_call("encode.sfixed64_field", [num, access])
    proto.Bool -> trick.ext_call("encode.bool_field", [num, access])
    _ -> trick.ext_call("encode.string_field", [num, access])
  }
}

/// Generate encoder for a map value (field number 2)
fn generate_map_value_encoder_expr(
  proto_type: Type,
  access: trick.Expression(trick.Variable),
  _ctx: Context,
) -> trick.Expression(trick.Variable) {
  let num = trick.int(2)
  case proto_type {
    proto.String -> trick.ext_call("encode.string_field", [num, access])
    proto.Int32 -> trick.ext_call("encode.int32_field", [num, access])
    proto.Int64 -> trick.ext_call("encode.int64_field", [num, access])
    proto.UInt32 -> trick.ext_call("encode.uint32_field", [num, access])
    proto.UInt64 -> trick.ext_call("encode.uint64_field", [num, access])
    proto.SInt32 -> trick.ext_call("encode.sint32_field", [num, access])
    proto.SInt64 -> trick.ext_call("encode.sint64_field", [num, access])
    proto.Fixed32 -> trick.ext_call("encode.fixed32_field", [num, access])
    proto.Fixed64 -> trick.ext_call("encode.fixed64_field", [num, access])
    proto.SFixed32 -> trick.ext_call("encode.sfixed32_field", [num, access])
    proto.SFixed64 -> trick.ext_call("encode.sfixed64_field", [num, access])
    proto.Bool -> trick.ext_call("encode.bool_field", [num, access])
    proto.Float -> trick.ext_call("encode.float_field", [num, access])
    proto.Double -> trick.ext_call("encode.double_field", [num, access])
    proto.Bytes ->
      trick.ext_call("encode.field", [
        num,
        trick.ident("wire.LengthDelimited", trick.Custom("", "WireType", [])),
        trick.ext_call("encode.length_delimited", [access]),
      ])
    proto.MessageType(name) -> {
      let encoder_name =
        "encode_" <> justin.snake_case(types.flatten_type_name(name))
      trick.ext_call("encode.field", [
        num,
        trick.ident("wire.LengthDelimited", trick.Custom("", "WireType", [])),
        trick.ext_call("encode.length_delimited", [
          trick.ext_call(encoder_name, [access]),
        ]),
      ])
    }
    proto.EnumType(name) -> {
      let encoder_name =
        "encode_" <> justin.snake_case(types.flatten_type_name(name)) <> "_value"
      trick.ext_call("encode.int32_field", [
        num,
        trick.ext_call(encoder_name, [access]),
      ])
    }
    _ -> trick.ext_call("encode.string_field", [num, access])
  }
}

// =============================================================================
// Decoder Generation
// =============================================================================

/// Generate a decoder function for a message using trick
pub fn generate_decoder(message: Message, ctx: Context) -> trick.Definition {
  let qualified_fn_name = types.qualified_fn(message.name, ctx)
  let qualified_type_name = types.qualified_type(message.name, ctx)
  let function_name = qualified_fn_name <> "_decoder"

  let _return_type =
    trick.Custom("protozoa/decode", "Decoder", [
      trick.Custom("", qualified_type_name, []),
    ])

  trick.pub_function(
    function_name,
    trick.function_body(generate_decoder_body_statement(message, ctx)),
    fn(_) { trick.empty() },
  )
}

/// Generate the decoder body as a Statement with chained use expressions
fn generate_decoder_body_statement(message: Message, ctx: Context) -> trick.Statement {
  let qualified_type_name = types.qualified_type(message.name, ctx)

  // Build the chain of use expressions for fields
  // Pass oneofs twice: once for processing, once for building constructor
  build_decoder_chain(
    message.fields,
    message.fields,
    message.oneofs,
    message.oneofs,
    qualified_type_name,
    ctx,
  )
}

/// Build chained use expressions for field decoders
fn build_decoder_chain(
  fields: List(Field),
  all_fields: List(Field),
  oneofs: List(proto.Oneof),
  original_oneofs: List(proto.Oneof),
  type_name: String,
  ctx: Context,
) -> trick.Statement {
  case fields {
    [field, ..rest] -> {
      let escaped_name = types.escape_keyword(field.name)
      let decoder_expr = generate_field_decoder_expr(field, ctx)
      // Wrap in decode.then
      let then_expr = trick.ext_call("decode.then", [decoder_expr])

      trick.use_binding(escaped_name, then_expr, fn(_var) {
        build_decoder_chain(rest, all_fields, oneofs, original_oneofs, type_name, ctx)
      })
    }
    [] -> build_oneof_decoder_chain(oneofs, all_fields, original_oneofs, type_name, ctx)
  }
}

/// Build chained use expressions for oneof decoders
fn build_oneof_decoder_chain(
  oneofs: List(proto.Oneof),
  all_fields: List(Field),
  original_oneofs: List(proto.Oneof),
  type_name: String,
  ctx: Context,
) -> trick.Statement {
  case oneofs {
    [oneof, ..rest] -> {
      let escaped_name = types.escape_keyword(oneof.name)
      let function_name = "oneof_" <> justin.snake_case(oneof.name) <> "_decoder"
      let decoder_expr = trick.ext_call("decode.then", [
        trick.ext_call(function_name, []),
      ])

      trick.use_binding(escaped_name, decoder_expr, fn(_var) {
        build_oneof_decoder_chain(rest, all_fields, original_oneofs, type_name, ctx)
      })
    }
    [] -> generate_decoder_success_statement(type_name, all_fields, original_oneofs, ctx)
  }
}

/// Generate the final decode.success(...) statement
fn generate_decoder_success_statement(
  type_name: String,
  all_fields: List(Field),
  oneofs: List(proto.Oneof),
  ctx: Context,
) -> trick.Statement {
  // Build constructor fields from regular fields
  let regular_fields =
    list.map(all_fields, fn(field) {
      let escaped_name = types.escape_keyword(field.name)
      let field_type = proto_to_trick_type(field.field_type, ctx)
      #(escaped_name, trick.ident(escaped_name, field_type))
    })

  // Build constructor fields from oneofs
  let oneof_fields =
    list.map(oneofs, fn(oneof) {
      let escaped_name = types.escape_keyword(oneof.name)
      let oneof_type_name = type_name <> types.capitalize_first(oneof.name)
      let option_type =
        trick.Custom("gleam/option", "Option", [
          trick.Custom("", oneof_type_name, []),
        ])
      #(escaped_name, trick.ident(escaped_name, option_type))
    })

  let all_constructor_fields = list.append(regular_fields, oneof_fields)

  let constructor_type = trick.Custom("", type_name, [])
  let constructor_expr =
    trick.constructor(type_name, constructor_type, all_constructor_fields)

  trick.expression(trick.ext_call("decode.success", [constructor_expr]))
}

/// Generate the decoder expression for a field
fn generate_field_decoder_expr(
  field: Field,
  ctx: Context,
) -> trick.Expression(trick.Variable) {
  let field_num = trick.int(field.number)

  case field.field_type {
    proto.Optional(inner) -> generate_optional_decoder_expr(inner, field_num)
    proto.Repeated(inner) -> generate_repeated_decoder_expr(inner, field_num)
    proto.Map(key_type, value_type) -> generate_map_decoder_expr(key_type, value_type, field_num, ctx)
    _ -> generate_type_decoder_expr(field.field_type, field_num, ctx)
  }
}

/// Generate decoder for optional field
fn generate_optional_decoder_expr(
  inner_type: Type,
  field_num: trick.Expression(trick.Variable),
) -> trick.Expression(trick.Variable) {
  case inner_type {
    proto.MessageType(name) -> {
      let decoder_name =
        justin.snake_case(types.flatten_type_name(name)) <> "_decoder"
      trick.ext_call("decode.map", [
        trick.ext_call("decode.optional_nested_message", [
          field_num,
          trick.ext_call(decoder_name, []),
        ]),
        trick.ident(
          "option.from_result",
          trick.Custom("gleam/option", "Option", []),
        ),
      ])
    }
    _ -> {
      let field_decoder = get_field_decoder_name(inner_type)
      trick.ext_call("decode.map", [
        trick.ext_call("decode.optional_field", [
          field_num,
          trick.ident(field_decoder, trick.Custom("", "Decoder", [])),
        ]),
        trick.ident(
          "option.from_result",
          trick.Custom("gleam/option", "Option", []),
        ),
      ])
    }
  }
}

/// Generate decoder for repeated field
fn generate_repeated_decoder_expr(
  inner_type: Type,
  field_num: trick.Expression(trick.Variable),
) -> trick.Expression(trick.Variable) {
  case inner_type {
    proto.String -> trick.ext_call("decode.repeated_string", [field_num])
    proto.Int32 -> trick.ext_call("decode.repeated_int32", [field_num])
    proto.EnumType(name) -> {
      let decoder_name =
        "decode_repeated_" <> justin.snake_case(types.flatten_type_name(name))
      trick.ext_call(decoder_name, [field_num])
    }
    _ -> {
      // For other types, use repeated_field with a lambda
      let field_decoder = get_simple_decoder(inner_type)
      trick.ext_call("decode.repeated_field", [
        field_num,
        trick.anonymous({
          use field <- trick.parameter(
            "field",
            trick.Custom("protozoa/decode", "Field", []),
          )
          trick.ext_call(field_decoder, [field])
          |> trick.expression
          |> trick.function_body
        }),
      ])
    }
  }
}

/// Generate decoder for map field
/// This generates a call to decode.map with dict.from_list wrapper
fn generate_map_decoder_expr(
  _key_type: Type,
  _value_type: Type,
  field_num: trick.Expression(trick.Variable),
  _ctx: Context,
) -> trick.Expression(trick.Variable) {
  // Map decoding is complex - for now generate a placeholder that references
  // the map entry decoder helper that would be generated separately
  // Pattern: decode.map(decode.repeated_field(field_num, map_entry_decoder()), dict.from_list)
  trick.ext_call("decode.map", [
    trick.ext_call("decode.repeated_field", [
      field_num,
      trick.ident("map_entry_decoder", trick.Custom("", "Decoder", [])),
    ]),
    trick.ident("dict.from_list", trick.Custom("gleam/dict", "Dict", [])),
  ])
}


/// Generate decoder for a primitive/message type
fn generate_type_decoder_expr(
  proto_type: Type,
  field_num: trick.Expression(trick.Variable),
  _ctx: Context,
) -> trick.Expression(trick.Variable) {
  case proto_type {
    proto.String ->
      trick.ext_call("decode.string_with_default", [field_num, trick.string("")])
    proto.Int32 ->
      trick.ext_call("decode.int32_with_default", [field_num, trick.int(0)])
    proto.Int64 ->
      trick.ext_call("decode.int64_with_default", [field_num, trick.int(0)])
    proto.UInt32 ->
      trick.ext_call("decode.uint32_with_default", [field_num, trick.int(0)])
    proto.UInt64 ->
      trick.ext_call("decode.uint64_with_default", [field_num, trick.int(0)])
    proto.SInt32 ->
      trick.ext_call("decode.sint32", [field_num])
    proto.SInt64 ->
      trick.ext_call("decode.sint64", [field_num])
    proto.Fixed32 ->
      trick.ext_call("decode.fixed32", [field_num])
    proto.Fixed64 ->
      trick.ext_call("decode.fixed64", [field_num])
    proto.SFixed32 ->
      trick.ext_call("decode.sfixed32", [field_num])
    proto.SFixed64 ->
      trick.ext_call("decode.sfixed64", [field_num])
    proto.Bool ->
      trick.ext_call("decode.bool_with_default", [field_num, trick.bool(False)])
    proto.Bytes ->
      trick.ext_call("decode.bytes", [field_num])
    proto.Float ->
      trick.ext_call("decode.float", [field_num])
    proto.Double ->
      trick.ext_call("decode.double", [field_num])
    proto.MessageType(name) -> {
      let decoder_name =
        justin.snake_case(types.flatten_type_name(name)) <> "_decoder"
      trick.ext_call("decode.nested_message", [
        field_num,
        trick.ext_call(decoder_name, []),
      ])
    }
    proto.EnumType(name) -> {
      let decoder_name =
        "decode_" <> justin.snake_case(types.flatten_type_name(name)) <> "_field"
      trick.ext_call(decoder_name, [field_num])
    }
    _ ->
      trick.ext_call("decode.string_with_default", [field_num, trick.string("")])
  }
}

/// Get the field decoder function name for a type
fn get_field_decoder_name(proto_type: Type) -> String {
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
    _ -> "decode.string_field"
  }
}

/// Get simple decoder expression for a type (used in repeated_field)
fn get_simple_decoder(proto_type: Type) -> String {
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
    proto.MessageType(name) ->
      "decode.message_field(_, "
      <> justin.snake_case(types.flatten_type_name(name))
      <> "_decoder())"
    _ -> "decode.string_field"
  }
}

/// Generate encoder expression for a single field
fn generate_field_encoder_expr(
  field: Field,
  msg: trick.Expression(trick.Variable),
  ctx: Context,
) -> trick.Expression(trick.Variable) {
  let escaped_field_name = types.escape_keyword(field.name)
  let field_access = trick.field_access(msg, escaped_field_name)

  case field.field_type {
    proto.Optional(inner) ->
      generate_optional_encoder_expr(inner, field_access, field.number, ctx)
    proto.Repeated(_) ->
      // Handled separately
      trick.empty_bit_array()
    _ -> generate_required_encoder_expr(field.field_type, field_access, field.number, ctx)
  }
}

/// Generate encoder for a required (non-optional) field
fn generate_required_encoder_expr(
  proto_type: Type,
  access: trick.Expression(trick.Variable),
  field_num: Int,
  _ctx: Context,
) -> trick.Expression(trick.Variable) {
  let num = trick.int(field_num)
  case proto_type {
    proto.String ->
      trick.ext_call("encode.string_field", [num, access])
    proto.Int32 ->
      trick.ext_call("encode.int32_field", [num, access])
    proto.Int64 ->
      trick.ext_call("encode.int64_field", [num, access])
    proto.UInt32 ->
      trick.ext_call("encode.uint32_field", [num, access])
    proto.UInt64 ->
      trick.ext_call("encode.uint64_field", [num, access])
    proto.SInt32 ->
      trick.ext_call("encode.sint32_field", [num, access])
    proto.SInt64 ->
      trick.ext_call("encode.sint64_field", [num, access])
    proto.Fixed32 ->
      trick.ext_call("encode.fixed32_field", [num, access])
    proto.Fixed64 ->
      trick.ext_call("encode.fixed64_field", [num, access])
    proto.SFixed32 ->
      trick.ext_call("encode.sfixed32_field", [num, access])
    proto.SFixed64 ->
      trick.ext_call("encode.sfixed64_field", [num, access])
    proto.Bool ->
      trick.ext_call("encode.bool_field", [num, access])
    proto.Float ->
      trick.ext_call("encode.float_field", [num, access])
    proto.Double ->
      trick.ext_call("encode.double_field", [num, access])
    proto.Bytes ->
      trick.ext_call("encode.field", [
        num,
        trick.ident("wire.LengthDelimited", trick.Custom("", "WireType", [])),
        trick.ext_call("encode.length_delimited", [access]),
      ])
    proto.MessageType(name) -> {
      let encoder_name =
        "encode_" <> justin.snake_case(types.flatten_type_name(name))
      trick.ext_call("encode.field", [
        num,
        trick.ident("wire.LengthDelimited", trick.Custom("", "WireType", [])),
        trick.ext_call("encode.length_delimited", [
          trick.ext_call(encoder_name, [access]),
        ]),
      ])
    }
    proto.EnumType(name) -> {
      let encoder_name =
        "encode_" <> justin.snake_case(types.flatten_type_name(name)) <> "_value"
      trick.ext_call("encode.int32_field", [
        num,
        trick.ext_call(encoder_name, [access]),
      ])
    }
    _ -> trick.empty_bit_array()
  }
}

/// Generate encoder for an optional field (case expression)
fn generate_optional_encoder_expr(
  inner_type: Type,
  access: trick.Expression(trick.Variable),
  field_num: Int,
  ctx: Context,
) -> trick.Expression(trick.Variable) {
  trick.case_(access, [
    trick.CaseBranch(
      trick.ConstructorPattern("Some", [
        trick.PositionalPatternField(trick.VariablePattern("value")),
      ]),
      option.None,
      trick.expression(
        generate_required_encoder_expr(
          inner_type,
          trick.ident("value", proto_to_trick_type(inner_type, ctx)),
          field_num,
          ctx,
        ),
      ),
    ),
    trick.CaseBranch(
      trick.ConstructorPattern("None", []),
      option.None,
      trick.expression(trick.empty_bit_array()),
    ),
  ])
}

/// Generate encoder for a oneof field
fn generate_oneof_encoder_expr(
  message_name: String,
  oneof: proto.Oneof,
  msg: trick.Expression(trick.Variable),
  ctx: Context,
) -> trick.Expression(trick.Variable) {
  let escaped_oneof_name = types.escape_keyword(oneof.name)
  let oneof_access = trick.field_access(msg, escaped_oneof_name)

  // Generate case branches for each oneof variant
  let inner_branches =
    list.map(oneof.fields, fn(field) {
      let base_variant_name = types.capitalize_first(field.name)

      // Avoid naming conflicts with well-known types
      let variant_name = case base_variant_name, field.field_type {
        "Empty", proto.MessageType("google.protobuf.Empty") -> "EmptyData"
        "StringValue", proto.String -> "StringValueVariant"
        "BoolValue", proto.Bool -> "BoolValueVariant"
        "ListValue", proto.MessageType("ListValue") -> "ListValueVariant"
        name, _ -> name
      }

      let value_type = proto_to_trick_type(field.field_type, ctx)

      trick.CaseBranch(
        trick.ConstructorPattern(variant_name, [
          trick.PositionalPatternField(trick.VariablePattern("value")),
        ]),
        option.None,
        trick.expression(
          generate_required_encoder_expr(
            field.field_type,
            trick.ident("value", value_type),
            field.number,
            ctx,
          ),
        ),
      )
    })

  // Wrap in Some/None check
  trick.case_(oneof_access, [
    trick.CaseBranch(
      trick.ConstructorPattern("Some", [
        trick.PositionalPatternField(trick.VariablePattern("oneof_value")),
      ]),
      option.None,
      {
        let oneof_type_name =
          types.qualified_type(message_name, ctx)
          <> types.capitalize_first(oneof.name)
        let oneof_type = trick.Custom("", oneof_type_name, [])
        trick.case_(trick.ident("oneof_value", oneof_type), inner_branches)
        |> trick.expression
      },
    ),
    trick.CaseBranch(
      trick.ConstructorPattern("None", []),
      option.None,
      trick.expression(trick.empty_bit_array()),
    ),
  ])
}

/// Generate the decode_X convenience wrapper function
fn generate_decode_wrapper(message: Message, ctx: Context) -> trick.Definition {
  let qualified_fn_name = types.qualified_fn(message.name, ctx)
  let function_name = "decode_" <> qualified_fn_name

  let data_type = trick.Custom("gleam", "BitArray", [])

  trick.pub_function(
    function_name,
    {
      use data <- trick.parameter("data", data_type)
      trick.ext_call("decode.run", [
        data,
        trick.ext_call(qualified_fn_name <> "_decoder", []),
      ])
      |> trick.expression
      |> trick.function_body
    },
    fn(_) { trick.empty() },
  )
}

// =============================================================================
// Complete Code Generation (Type + Encoder + Decoder)
// =============================================================================

/// Generate complete code for a message as a string (type definition, encoder, decoder)
/// This is the main integration point for using trick-based code generation
pub fn generate_message_code(
  message: Message,
  ctx: Context,
) -> Result(String, trick.Error) {
  let type_def = generate_message_type(message, ctx)
  let encoder_def = generate_encoder(message, ctx)
  let decoder_def = generate_decoder(message, ctx)
  let decode_wrapper_def = generate_decode_wrapper(message, ctx)

  // Also generate oneof types if present
  let oneof_defs =
    list.map(message.oneofs, fn(oneof) {
      generate_oneof_type(message, oneof, ctx)
    })

  // Convert all definitions to strings
  use type_code <- result.try(trick.to_string(type_def))
  use encoder_code <- result.try(trick.to_string(encoder_def))
  use decoder_code <- result.try(trick.to_string(decoder_def))
  use decode_wrapper_code <- result.try(trick.to_string(decode_wrapper_def))

  // Convert oneof definitions
  use oneof_codes <- result.try(
    list.try_map(oneof_defs, trick.to_string),
  )

  let oneof_section = case oneof_codes {
    [] -> ""
    codes -> "\n\n" <> string.join(codes, "\n\n")
  }

  Ok(
    type_code
    <> oneof_section
    <> "\n\n"
    <> encoder_code
    <> "\n\n"
    <> decoder_code
    <> "\n\n"
    <> decode_wrapper_code,
  )
}

/// Generate complete code for an enum as a string (type definition only for now)
pub fn generate_enum_code(
  enum: Enum,
  ctx: Context,
) -> Result(String, trick.Error) {
  let type_def = generate_enum_type(enum, ctx)
  trick.to_string(type_def)
}

/// Generate code for multiple messages
pub fn generate_messages_code(
  messages: List(Message),
  ctx: Context,
) -> Result(String, trick.Error) {
  use codes <- result.try(
    list.try_map(messages, fn(message) {
      generate_message_code(message, ctx)
    }),
  )
  Ok(string.join(codes, "\n\n"))
}

/// Generate code for multiple enums
pub fn generate_enums_code(
  enums: List(Enum),
  ctx: Context,
) -> Result(String, trick.Error) {
  use codes <- result.try(
    list.try_map(enums, fn(enum) {
      generate_enum_code(enum, ctx)
    }),
  )
  Ok(string.join(codes, "\n\n"))
}
