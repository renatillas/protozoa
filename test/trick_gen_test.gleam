import birdie
import gleam/option
import protozoa/internal/codegen/trick_gen
import protozoa/internal/codegen/types
import protozoa/internal/type_registry
import protozoa/parser/proto
import trick

fn make_test_ctx() -> types.Context {
  let registry = type_registry.new()
  types.new_ctx(registry, "test.proto")
}

pub fn generate_simple_message_type_test() {
  let ctx = make_test_ctx()

  let message =
    proto.Message(
      name: "Person",
      fields: [
        proto.Field(
          name: "name",
          field_type: proto.String,
          number: 1,
          oneof_name: option.None,
          options: [],
        ),
        proto.Field(
          name: "age",
          field_type: proto.Int32,
          number: 2,
          oneof_name: option.None,
          options: [],
        ),
      ],
      oneofs: [],
      nested_messages: [],
      nested_enums: [],
    )

  let definition = trick_gen.generate_message_type(message, ctx)

  let assert Ok(code) = trick.to_string(definition)

  birdie.snap(code, "trick_gen_simple_message_type")
}

pub fn generate_enum_type_test() {
  let ctx = make_test_ctx()

  let enum =
    proto.Enum(name: "Status", values: [
      proto.EnumValue(name: "UNKNOWN", number: 0),
      proto.EnumValue(name: "ACTIVE", number: 1),
      proto.EnumValue(name: "INACTIVE", number: 2),
    ])

  let definition = trick_gen.generate_enum_type(enum, ctx)

  let assert Ok(code) = trick.to_string(definition)

  birdie.snap(code, "trick_gen_enum_type")
}

pub fn generate_message_with_repeated_field_test() {
  let ctx = make_test_ctx()

  let message =
    proto.Message(
      name: "Team",
      fields: [
        proto.Field(
          name: "name",
          field_type: proto.String,
          number: 1,
          oneof_name: option.None,
          options: [],
        ),
        proto.Field(
          name: "members",
          field_type: proto.Repeated(proto.String),
          number: 2,
          oneof_name: option.None,
          options: [],
        ),
      ],
      oneofs: [],
      nested_messages: [],
      nested_enums: [],
    )

  let definition = trick_gen.generate_message_type(message, ctx)

  let assert Ok(code) = trick.to_string(definition)

  birdie.snap(code, "trick_gen_message_with_repeated")
}

pub fn generate_message_with_optional_field_test() {
  let ctx = make_test_ctx()

  let message =
    proto.Message(
      name: "User",
      fields: [
        proto.Field(
          name: "id",
          field_type: proto.Int64,
          number: 1,
          oneof_name: option.None,
          options: [],
        ),
        proto.Field(
          name: "nickname",
          field_type: proto.Optional(proto.String),
          number: 2,
          oneof_name: option.None,
          options: [],
        ),
      ],
      oneofs: [],
      nested_messages: [],
      nested_enums: [],
    )

  let definition = trick_gen.generate_message_type(message, ctx)

  let assert Ok(code) = trick.to_string(definition)

  birdie.snap(code, "trick_gen_message_with_optional")
}

pub fn generate_oneof_type_test() {
  let ctx = make_test_ctx()

  let message =
    proto.Message(
      name: "Response",
      fields: [],
      oneofs: [
        proto.Oneof(
          name: "result",
          fields: [
            proto.Field(
              name: "success",
              field_type: proto.String,
              number: 1,
              oneof_name: option.Some("result"),
              options: [],
            ),
            proto.Field(
              name: "error",
              field_type: proto.String,
              number: 2,
              oneof_name: option.Some("result"),
              options: [],
            ),
          ],
        ),
      ],
      nested_messages: [],
      nested_enums: [],
    )

  let oneof = case message.oneofs {
    [first, ..] -> first
    [] -> panic as "No oneofs in message"
  }

  let definition = trick_gen.generate_oneof_type(message, oneof, ctx)

  let assert Ok(code) = trick.to_string(definition)

  birdie.snap(code, "trick_gen_oneof_type")
}

pub fn generate_import_statements_test() {
  let imports = trick_gen.standard_imports()

  let code = trick.imports_to_string(imports)

  birdie.snap(code, "trick_gen_imports")
}

// =============================================================================
// Encoder Generation Tests
// =============================================================================

pub fn generate_simple_encoder_test() {
  let ctx = make_test_ctx()

  let message =
    proto.Message(
      name: "Person",
      fields: [
        proto.Field(
          name: "name",
          field_type: proto.String,
          number: 1,
          oneof_name: option.None,
          options: [],
        ),
        proto.Field(
          name: "age",
          field_type: proto.Int32,
          number: 2,
          oneof_name: option.None,
          options: [],
        ),
      ],
      oneofs: [],
      nested_messages: [],
      nested_enums: [],
    )

  let definition = trick_gen.generate_encoder(message, ctx)

  let assert Ok(code) = trick.to_string(definition)

  birdie.snap(code, "trick_gen_simple_encoder")
}

pub fn generate_encoder_with_optional_field_test() {
  let ctx = make_test_ctx()

  let message =
    proto.Message(
      name: "User",
      fields: [
        proto.Field(
          name: "id",
          field_type: proto.Int64,
          number: 1,
          oneof_name: option.None,
          options: [],
        ),
        proto.Field(
          name: "nickname",
          field_type: proto.Optional(proto.String),
          number: 2,
          oneof_name: option.None,
          options: [],
        ),
      ],
      oneofs: [],
      nested_messages: [],
      nested_enums: [],
    )

  let definition = trick_gen.generate_encoder(message, ctx)

  let assert Ok(code) = trick.to_string(definition)

  birdie.snap(code, "trick_gen_encoder_with_optional")
}

pub fn generate_encoder_with_oneof_test() {
  let ctx = make_test_ctx()

  let message =
    proto.Message(
      name: "Response",
      fields: [],
      oneofs: [
        proto.Oneof(
          name: "result",
          fields: [
            proto.Field(
              name: "success",
              field_type: proto.String,
              number: 1,
              oneof_name: option.Some("result"),
              options: [],
            ),
            proto.Field(
              name: "error",
              field_type: proto.String,
              number: 2,
              oneof_name: option.Some("result"),
              options: [],
            ),
          ],
        ),
      ],
      nested_messages: [],
      nested_enums: [],
    )

  let definition = trick_gen.generate_encoder(message, ctx)

  let assert Ok(code) = trick.to_string(definition)

  birdie.snap(code, "trick_gen_encoder_with_oneof")
}

pub fn generate_encoder_with_repeated_field_test() {
  let ctx = make_test_ctx()

  let message =
    proto.Message(
      name: "Team",
      fields: [
        proto.Field(
          name: "name",
          field_type: proto.String,
          number: 1,
          oneof_name: option.None,
          options: [],
        ),
        proto.Field(
          name: "members",
          field_type: proto.Repeated(proto.String),
          number: 2,
          oneof_name: option.None,
          options: [],
        ),
      ],
      oneofs: [],
      nested_messages: [],
      nested_enums: [],
    )

  let definition = trick_gen.generate_encoder(message, ctx)

  let assert Ok(code) = trick.to_string(definition)

  birdie.snap(code, "trick_gen_encoder_with_repeated")
}

pub fn generate_encoder_with_map_field_test() {
  let ctx = make_test_ctx()

  let message =
    proto.Message(
      name: "Config",
      fields: [
        proto.Field(
          name: "settings",
          field_type: proto.Map(proto.String, proto.String),
          number: 1,
          oneof_name: option.None,
          options: [],
        ),
      ],
      oneofs: [],
      nested_messages: [],
      nested_enums: [],
    )

  let definition = trick_gen.generate_encoder(message, ctx)

  let assert Ok(code) = trick.to_string(definition)

  birdie.snap(code, "trick_gen_encoder_with_map")
}

// =============================================================================
// Decoder Generation Tests
// =============================================================================

pub fn generate_simple_decoder_test() {
  let ctx = make_test_ctx()

  let message =
    proto.Message(
      name: "Person",
      fields: [
        proto.Field(
          name: "name",
          field_type: proto.String,
          number: 1,
          oneof_name: option.None,
          options: [],
        ),
        proto.Field(
          name: "age",
          field_type: proto.Int32,
          number: 2,
          oneof_name: option.None,
          options: [],
        ),
      ],
      oneofs: [],
      nested_messages: [],
      nested_enums: [],
    )

  let definition = trick_gen.generate_decoder(message, ctx)

  let assert Ok(code) = trick.to_string(definition)

  birdie.snap(code, "trick_gen_simple_decoder")
}

pub fn generate_decoder_with_optional_field_test() {
  let ctx = make_test_ctx()

  let message =
    proto.Message(
      name: "User",
      fields: [
        proto.Field(
          name: "id",
          field_type: proto.Int64,
          number: 1,
          oneof_name: option.None,
          options: [],
        ),
        proto.Field(
          name: "nickname",
          field_type: proto.Optional(proto.String),
          number: 2,
          oneof_name: option.None,
          options: [],
        ),
      ],
      oneofs: [],
      nested_messages: [],
      nested_enums: [],
    )

  let definition = trick_gen.generate_decoder(message, ctx)

  let assert Ok(code) = trick.to_string(definition)

  birdie.snap(code, "trick_gen_decoder_with_optional")
}

pub fn generate_decoder_with_repeated_field_test() {
  let ctx = make_test_ctx()

  let message =
    proto.Message(
      name: "Team",
      fields: [
        proto.Field(
          name: "name",
          field_type: proto.String,
          number: 1,
          oneof_name: option.None,
          options: [],
        ),
        proto.Field(
          name: "members",
          field_type: proto.Repeated(proto.String),
          number: 2,
          oneof_name: option.None,
          options: [],
        ),
      ],
      oneofs: [],
      nested_messages: [],
      nested_enums: [],
    )

  let definition = trick_gen.generate_decoder(message, ctx)

  let assert Ok(code) = trick.to_string(definition)

  birdie.snap(code, "trick_gen_decoder_with_repeated")
}

pub fn generate_decoder_with_oneof_test() {
  let ctx = make_test_ctx()

  let message =
    proto.Message(
      name: "Response",
      fields: [],
      oneofs: [
        proto.Oneof(
          name: "result",
          fields: [
            proto.Field(
              name: "success",
              field_type: proto.String,
              number: 1,
              oneof_name: option.Some("result"),
              options: [],
            ),
            proto.Field(
              name: "error",
              field_type: proto.String,
              number: 2,
              oneof_name: option.Some("result"),
              options: [],
            ),
          ],
        ),
      ],
      nested_messages: [],
      nested_enums: [],
    )

  let definition = trick_gen.generate_decoder(message, ctx)

  let assert Ok(code) = trick.to_string(definition)

  birdie.snap(code, "trick_gen_decoder_with_oneof")
}

pub fn generate_decoder_with_map_field_test() {
  let ctx = make_test_ctx()

  let message =
    proto.Message(
      name: "Config",
      fields: [
        proto.Field(
          name: "settings",
          field_type: proto.Map(proto.String, proto.String),
          number: 1,
          oneof_name: option.None,
          options: [],
        ),
      ],
      oneofs: [],
      nested_messages: [],
      nested_enums: [],
    )

  let definition = trick_gen.generate_decoder(message, ctx)

  let assert Ok(code) = trick.to_string(definition)

  birdie.snap(code, "trick_gen_decoder_with_map")
}

// =============================================================================
// Complete Code Generation Tests
// =============================================================================

pub fn generate_complete_message_code_test() {
  let ctx = make_test_ctx()

  let message =
    proto.Message(
      name: "Person",
      fields: [
        proto.Field(
          name: "name",
          field_type: proto.String,
          number: 1,
          oneof_name: option.None,
          options: [],
        ),
        proto.Field(
          name: "age",
          field_type: proto.Int32,
          number: 2,
          oneof_name: option.None,
          options: [],
        ),
      ],
      oneofs: [],
      nested_messages: [],
      nested_enums: [],
    )

  let assert Ok(code) = trick_gen.generate_message_code(message, ctx)

  birdie.snap(code, "trick_gen_complete_message_code")
}

pub fn generate_complete_message_with_oneof_test() {
  let ctx = make_test_ctx()

  let message =
    proto.Message(
      name: "Response",
      fields: [],
      oneofs: [
        proto.Oneof(
          name: "result",
          fields: [
            proto.Field(
              name: "success",
              field_type: proto.String,
              number: 1,
              oneof_name: option.Some("result"),
              options: [],
            ),
            proto.Field(
              name: "error",
              field_type: proto.String,
              number: 2,
              oneof_name: option.Some("result"),
              options: [],
            ),
          ],
        ),
      ],
      nested_messages: [],
      nested_enums: [],
    )

  let assert Ok(code) = trick_gen.generate_message_code(message, ctx)

  birdie.snap(code, "trick_gen_complete_message_with_oneof")
}
