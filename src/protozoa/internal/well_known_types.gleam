import gleam/dict
import gleam/option
import protozoa/parser

/// Provides definitions for Google's well-known protobuf types
/// These are commonly used types that are part of the protobuf standard library
pub fn get_well_known_proto_files() -> dict.Dict(String, parser.ProtoFile) {
  dict.new()
  |> dict.insert("google/protobuf/timestamp.proto", timestamp_proto())
  |> dict.insert("google/protobuf/duration.proto", duration_proto())
  |> dict.insert("google/protobuf/any.proto", any_proto())
  |> dict.insert("google/protobuf/empty.proto", empty_proto())
  |> dict.insert("google/protobuf/wrappers.proto", wrappers_proto())
  |> dict.insert("google/protobuf/struct.proto", struct_proto())
  |> dict.insert("google/protobuf/field_mask.proto", field_mask_proto())
}

fn timestamp_proto() -> parser.ProtoFile {
  parser.ProtoFile(
    syntax: "proto3",
    package: option.Some("google.protobuf"),
    imports: [],
    messages: [
      parser.Message(
        name: "Timestamp",
        fields: [
          parser.Field(
            name: "seconds",
            field_type: parser.Int64,
            number: 1,
            oneof_name: option.None,
            options: [],
          ),
          parser.Field(
            name: "nanos",
            field_type: parser.Int32,
            number: 2,
            oneof_name: option.None,
            options: [],
          ),
        ],
        oneofs: [],
        nested_messages: [],
        enums: [],
      ),
    ],
    enums: [],
    services: [],
  )
}

fn duration_proto() -> parser.ProtoFile {
  parser.ProtoFile(
    syntax: "proto3",
    package: option.Some("google.protobuf"),
    imports: [],
    messages: [
      parser.Message(
        name: "Duration",
        fields: [
          parser.Field(
            name: "seconds",
            field_type: parser.Int64,
            number: 1,
            oneof_name: option.None,
            options: [],
          ),
          parser.Field(
            name: "nanos",
            field_type: parser.Int32,
            number: 2,
            oneof_name: option.None,
            options: [],
          ),
        ],
        oneofs: [],
        nested_messages: [],
        enums: [],
      ),
    ],
    enums: [],
    services: [],
  )
}

fn any_proto() -> parser.ProtoFile {
  parser.ProtoFile(
    syntax: "proto3",
    package: option.Some("google.protobuf"),
    imports: [],
    messages: [
      parser.Message(
        name: "Any",
        fields: [
          parser.Field(
            name: "type_url",
            field_type: parser.String,
            number: 1,
            oneof_name: option.None,
            options: [],
          ),
          parser.Field(
            name: "value",
            field_type: parser.Bytes,
            number: 2,
            oneof_name: option.None,
            options: [],
          ),
        ],
        oneofs: [],
        nested_messages: [],
        enums: [],
      ),
    ],
    enums: [],
    services: [],
  )
}

fn empty_proto() -> parser.ProtoFile {
  parser.ProtoFile(
    syntax: "proto3",
    package: option.Some("google.protobuf"),
    imports: [],
    messages: [
      parser.Message(
        name: "Empty",
        fields: [],
        oneofs: [],
        nested_messages: [],
        enums: [],
      ),
    ],
    enums: [],
    services: [],
  )
}

fn wrappers_proto() -> parser.ProtoFile {
  parser.ProtoFile(
    syntax: "proto3",
    package: option.Some("google.protobuf"),
    imports: [],
    messages: [
      parser.Message(
        name: "DoubleValue",
        fields: [
          parser.Field(
            name: "value",
            field_type: parser.Double,
            number: 1,
            oneof_name: option.None,
            options: [],
          ),
        ],
        oneofs: [],
        nested_messages: [],
        enums: [],
      ),
      parser.Message(
        name: "FloatValue",
        fields: [
          parser.Field(
            name: "value",
            field_type: parser.Float,
            number: 1,
            oneof_name: option.None,
            options: [],
          ),
        ],
        oneofs: [],
        nested_messages: [],
        enums: [],
      ),
      parser.Message(
        name: "Int64Value",
        fields: [
          parser.Field(
            name: "value",
            field_type: parser.Int64,
            number: 1,
            oneof_name: option.None,
            options: [],
          ),
        ],
        oneofs: [],
        nested_messages: [],
        enums: [],
      ),
      parser.Message(
        name: "UInt64Value",
        fields: [
          parser.Field(
            name: "value",
            field_type: parser.UInt64,
            number: 1,
            oneof_name: option.None,
            options: [],
          ),
        ],
        oneofs: [],
        nested_messages: [],
        enums: [],
      ),
      parser.Message(
        name: "Int32Value",
        fields: [
          parser.Field(
            name: "value",
            field_type: parser.Int32,
            number: 1,
            oneof_name: option.None,
            options: [],
          ),
        ],
        oneofs: [],
        nested_messages: [],
        enums: [],
      ),
      parser.Message(
        name: "UInt32Value",
        fields: [
          parser.Field(
            name: "value",
            field_type: parser.UInt32,
            number: 1,
            oneof_name: option.None,
            options: [],
          ),
        ],
        oneofs: [],
        nested_messages: [],
        enums: [],
      ),
      parser.Message(
        name: "BoolValue",
        fields: [
          parser.Field(
            name: "value",
            field_type: parser.Bool,
            number: 1,
            oneof_name: option.None,
            options: [],
          ),
        ],
        oneofs: [],
        nested_messages: [],
        enums: [],
      ),
      parser.Message(
        name: "StringValue",
        fields: [
          parser.Field(
            name: "value",
            field_type: parser.String,
            number: 1,
            oneof_name: option.None,
            options: [],
          ),
        ],
        oneofs: [],
        nested_messages: [],
        enums: [],
      ),
      parser.Message(
        name: "BytesValue",
        fields: [
          parser.Field(
            name: "value",
            field_type: parser.Bytes,
            number: 1,
            oneof_name: option.None,
            options: [],
          ),
        ],
        oneofs: [],
        nested_messages: [],
        enums: [],
      ),
    ],
    enums: [],
    services: [],
  )
}

fn struct_proto() -> parser.ProtoFile {
  parser.ProtoFile(
    syntax: "proto3",
    package: option.Some("google.protobuf"),
    imports: [],
    messages: [
      parser.Message(
        name: "Struct",
        fields: [
          parser.Field(
            name: "fields",
            field_type: parser.Map(parser.String, parser.MessageType("Value")),
            number: 1,
            oneof_name: option.None,
            options: [],
          ),
        ],
        oneofs: [],
        nested_messages: [],
        enums: [],
      ),
      parser.Message(
        name: "Value",
        fields: [],
        oneofs: [
          parser.Oneof(name: "kind", fields: [
            parser.Field(
              name: "null_value",
              field_type: parser.EnumType("NullValue"),
              number: 1,
              oneof_name: option.Some("kind"),
              options: [],
            ),
            parser.Field(
              name: "number_value",
              field_type: parser.Double,
              number: 2,
              oneof_name: option.Some("kind"),
              options: [],
            ),
            parser.Field(
              name: "string_value",
              field_type: parser.String,
              number: 3,
              oneof_name: option.Some("kind"),
              options: [],
            ),
            parser.Field(
              name: "bool_value",
              field_type: parser.Bool,
              number: 4,
              oneof_name: option.Some("kind"),
              options: [],
            ),
            parser.Field(
              name: "struct_value",
              field_type: parser.MessageType("Struct"),
              number: 5,
              oneof_name: option.Some("kind"),
              options: [],
            ),
            parser.Field(
              name: "list_value",
              field_type: parser.MessageType("ListValue"),
              number: 6,
              oneof_name: option.Some("kind"),
              options: [],
            ),
          ]),
        ],
        nested_messages: [],
        enums: [],
      ),
      parser.Message(
        name: "ListValue",
        fields: [
          parser.Field(
            name: "values",
            field_type: parser.Repeated(parser.MessageType("Value")),
            number: 1,
            oneof_name: option.None,
            options: [],
          ),
        ],
        oneofs: [],
        nested_messages: [],
        enums: [],
      ),
    ],
    enums: [
      parser.Enum(name: "NullValue", values: [
        parser.EnumValue(name: "NULL_VALUE", number: 0),
      ]),
    ],
    services: [],
  )
}

fn field_mask_proto() -> parser.ProtoFile {
  parser.ProtoFile(
    syntax: "proto3",
    package: option.Some("google.protobuf"),
    imports: [],
    messages: [
      parser.Message(
        name: "FieldMask",
        fields: [
          parser.Field(
            name: "paths",
            field_type: parser.Repeated(parser.String),
            number: 1,
            oneof_name: option.None,
            options: [],
          ),
        ],
        oneofs: [],
        nested_messages: [],
        enums: [],
      ),
    ],
    enums: [],
    services: [],
  )
}

pub fn is_well_known_import(path: String) -> Bool {
  case path {
    "google/protobuf/timestamp.proto"
    | "google/protobuf/duration.proto"
    | "google/protobuf/any.proto"
    | "google/protobuf/empty.proto"
    | "google/protobuf/wrappers.proto"
    | "google/protobuf/struct.proto"
    | "google/protobuf/field_mask.proto" -> True
    _ -> False
  }
}
