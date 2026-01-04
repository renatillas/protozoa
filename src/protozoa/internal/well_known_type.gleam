import gleam/dict
import gleam/option
import protozoa/parser/file
import protozoa/parser/proto

/// Provides definitions for Google's well-known protobuf types
/// These are commonly used types that are part of the protobuf standard library
pub fn get_well_known_proto_files() -> dict.Dict(String, file.ProtoFile) {
  dict.new()
  |> dict.insert("google/protobuf/timestamp.proto", timestamp_proto())
  |> dict.insert("google/protobuf/duration.proto", duration_proto())
  |> dict.insert("google/protobuf/any.proto", any_proto())
  |> dict.insert("google/protobuf/empty.proto", empty_proto())
  |> dict.insert("google/protobuf/wrappers.proto", wrappers_proto())
  |> dict.insert("google/protobuf/struct.proto", struct_proto())
  |> dict.insert("google/protobuf/field_mask.proto", field_mask_proto())
  |> dict.insert("google/api/annotations.proto", annotations_proto())
  |> dict.insert("google/api/http.proto", http_proto())
  |> dict.insert("google/protobuf/source_context.proto", source_context_proto())
  |> dict.insert("google/protobuf/type.proto", type_proto())
  |> dict.insert("google/protobuf/api.proto", api_proto())
}

fn timestamp_proto() -> file.ProtoFile {
  file.ProtoFile(
    syntax: "proto3",
    package: option.Some("google.protobuf"),
    imports: [],
    messages: [
      proto.Message(
        name: "Timestamp",
        fields: [
          proto.Field(
            name: "seconds",
            field_type: proto.Int64,
            number: 1,
            oneof_name: option.None,
            options: [],
          ),
          proto.Field(
            name: "nanos",
            field_type: proto.Int32,
            number: 2,
            oneof_name: option.None,
            options: [],
          ),
        ],
        oneofs: [],
        nested_messages: [],
        nested_enums: [],
      ),
    ],
    enums: [],
    services: [],
  )
}

fn duration_proto() -> file.ProtoFile {
  file.ProtoFile(
    syntax: "proto3",
    package: option.Some("google.protobuf"),
    imports: [],
    messages: [
      proto.Message(
        name: "Duration",
        fields: [
          proto.Field(
            name: "seconds",
            field_type: proto.Int64,
            number: 1,
            oneof_name: option.None,
            options: [],
          ),
          proto.Field(
            name: "nanos",
            field_type: proto.Int32,
            number: 2,
            oneof_name: option.None,
            options: [],
          ),
        ],
        oneofs: [],
        nested_messages: [],
        nested_enums: [],
      ),
    ],
    enums: [],
    services: [],
  )
}

fn any_proto() -> file.ProtoFile {
  file.ProtoFile(
    syntax: "proto3",
    package: option.Some("google.protobuf"),
    imports: [],
    messages: [
      proto.Message(
        name: "Any",
        fields: [
          proto.Field(
            name: "type_url",
            field_type: proto.String,
            number: 1,
            oneof_name: option.None,
            options: [],
          ),
          proto.Field(
            name: "value",
            field_type: proto.Bytes,
            number: 2,
            oneof_name: option.None,
            options: [],
          ),
        ],
        oneofs: [],
        nested_messages: [],
        nested_enums: [],
      ),
    ],
    enums: [],
    services: [],
  )
}

fn empty_proto() -> file.ProtoFile {
  file.ProtoFile(
    syntax: "proto3",
    package: option.Some("google.protobuf"),
    imports: [],
    messages: [
      proto.Message(
        name: "Empty",
        fields: [],
        oneofs: [],
        nested_messages: [],
        nested_enums: [],
      ),
    ],
    enums: [],
    services: [],
  )
}

fn wrappers_proto() -> file.ProtoFile {
  file.ProtoFile(
    syntax: "proto3",
    package: option.Some("google.protobuf"),
    imports: [],
    messages: [
      proto.Message(
        name: "DoubleValue",
        fields: [
          proto.Field(
            name: "value",
            field_type: proto.Double,
            number: 1,
            oneof_name: option.None,
            options: [],
          ),
        ],
        oneofs: [],
        nested_messages: [],
        nested_enums: [],
      ),
      proto.Message(
        name: "FloatValue",
        fields: [
          proto.Field(
            name: "value",
            field_type: proto.Float,
            number: 1,
            oneof_name: option.None,
            options: [],
          ),
        ],
        oneofs: [],
        nested_messages: [],
        nested_enums: [],
      ),
      proto.Message(
        name: "Int64Value",
        fields: [
          proto.Field(
            name: "value",
            field_type: proto.Int64,
            number: 1,
            oneof_name: option.None,
            options: [],
          ),
        ],
        oneofs: [],
        nested_messages: [],
        nested_enums: [],
      ),
      proto.Message(
        name: "UInt64Value",
        fields: [
          proto.Field(
            name: "value",
            field_type: proto.UInt64,
            number: 1,
            oneof_name: option.None,
            options: [],
          ),
        ],
        oneofs: [],
        nested_messages: [],
        nested_enums: [],
      ),
      proto.Message(
        name: "Int32Value",
        fields: [
          proto.Field(
            name: "value",
            field_type: proto.Int32,
            number: 1,
            oneof_name: option.None,
            options: [],
          ),
        ],
        oneofs: [],
        nested_messages: [],
        nested_enums: [],
      ),
      proto.Message(
        name: "UInt32Value",
        fields: [
          proto.Field(
            name: "value",
            field_type: proto.UInt32,
            number: 1,
            oneof_name: option.None,
            options: [],
          ),
        ],
        oneofs: [],
        nested_messages: [],
        nested_enums: [],
      ),
      proto.Message(
        name: "BoolValue",
        fields: [
          proto.Field(
            name: "value",
            field_type: proto.Bool,
            number: 1,
            oneof_name: option.None,
            options: [],
          ),
        ],
        oneofs: [],
        nested_messages: [],
        nested_enums: [],
      ),
      proto.Message(
        name: "StringValue",
        fields: [
          proto.Field(
            name: "value",
            field_type: proto.String,
            number: 1,
            oneof_name: option.None,
            options: [],
          ),
        ],
        oneofs: [],
        nested_messages: [],
        nested_enums: [],
      ),
      proto.Message(
        name: "BytesValue",
        fields: [
          proto.Field(
            name: "value",
            field_type: proto.Bytes,
            number: 1,
            oneof_name: option.None,
            options: [],
          ),
        ],
        oneofs: [],
        nested_messages: [],
        nested_enums: [],
      ),
    ],
    enums: [],
    services: [],
  )
}

fn struct_proto() -> file.ProtoFile {
  file.ProtoFile(
    syntax: "proto3",
    package: option.Some("google.protobuf"),
    imports: [],
    messages: [
      proto.Message(
        name: "Struct",
        fields: [
          proto.Field(
            name: "fields",
            field_type: proto.Map(proto.String, proto.MessageType("Value")),
            number: 1,
            oneof_name: option.None,
            options: [],
          ),
        ],
        oneofs: [],
        nested_messages: [],
        nested_enums: [],
      ),
      proto.Message(
        name: "Value",
        fields: [],
        oneofs: [
          proto.Oneof(name: "kind", fields: [
            proto.Field(
              name: "null_value",
              field_type: proto.EnumType("NullValue"),
              number: 1,
              oneof_name: option.Some("kind"),
              options: [],
            ),
            proto.Field(
              name: "number_value",
              field_type: proto.Double,
              number: 2,
              oneof_name: option.Some("kind"),
              options: [],
            ),
            proto.Field(
              name: "string_value",
              field_type: proto.String,
              number: 3,
              oneof_name: option.Some("kind"),
              options: [],
            ),
            proto.Field(
              name: "bool_value",
              field_type: proto.Bool,
              number: 4,
              oneof_name: option.Some("kind"),
              options: [],
            ),
            proto.Field(
              name: "struct_value",
              field_type: proto.MessageType("Struct"),
              number: 5,
              oneof_name: option.Some("kind"),
              options: [],
            ),
            proto.Field(
              name: "list_value",
              field_type: proto.MessageType("ListValue"),
              number: 6,
              oneof_name: option.Some("kind"),
              options: [],
            ),
          ]),
        ],
        nested_messages: [],
        nested_enums: [],
      ),
      proto.Message(
        name: "ListValue",
        fields: [
          proto.Field(
            name: "values",
            field_type: proto.Repeated(proto.MessageType("Value")),
            number: 1,
            oneof_name: option.None,
            options: [],
          ),
        ],
        oneofs: [],
        nested_messages: [],
        nested_enums: [],
      ),
    ],
    enums: [
      proto.Enum(name: "NullValue", values: [
        proto.EnumValue(name: "NULL_VALUE", number: 0),
      ]),
    ],
    services: [],
  )
}

fn field_mask_proto() -> file.ProtoFile {
  file.ProtoFile(
    syntax: "proto3",
    package: option.Some("google.protobuf"),
    imports: [],
    messages: [
      proto.Message(
        name: "FieldMask",
        fields: [
          proto.Field(
            name: "paths",
            field_type: proto.Repeated(proto.String),
            number: 1,
            oneof_name: option.None,
            options: [],
          ),
        ],
        oneofs: [],
        nested_messages: [],
        nested_enums: [],
      ),
    ],
    enums: [],
    services: [],
  )
}

fn annotations_proto() -> file.ProtoFile {
  file.ProtoFile(
    syntax: "proto3",
    package: option.Some("google.api"),
    imports: [
      proto.Import(path: "google/api/http.proto", public: False, weak: False),
    ],
    messages: [],
    enums: [],
    services: [],
  )
}

fn http_proto() -> file.ProtoFile {
  file.ProtoFile(
    syntax: "proto3",
    package: option.Some("google.api"),
    imports: [],
    messages: [],
    enums: [],
    services: [],
  )
}

fn source_context_proto() -> file.ProtoFile {
  file.ProtoFile(
    syntax: "proto3",
    package: option.Some("google.protobuf"),
    imports: [],
    messages: [
      proto.Message(
        name: "SourceContext",
        fields: [
          proto.Field(
            name: "file_name",
            field_type: proto.String,
            number: 1,
            oneof_name: option.None,
            options: [],
          ),
        ],
        oneofs: [],
        nested_messages: [],
        nested_enums: [],
      ),
    ],
    enums: [],
    services: [],
  )
}

fn type_proto() -> file.ProtoFile {
  file.ProtoFile(
    syntax: "proto3",
    package: option.Some("google.protobuf"),
    imports: [
      proto.Import(path: "google/protobuf/any.proto", public: False, weak: False),
      proto.Import(
        path: "google/protobuf/source_context.proto",
        public: False,
        weak: False,
      ),
    ],
    messages: [
      // Type message
      proto.Message(
        name: "Type",
        fields: [
          proto.Field(
            name: "name",
            field_type: proto.String,
            number: 1,
            oneof_name: option.None,
            options: [],
          ),
          proto.Field(
            name: "fields",
            field_type: proto.Repeated(proto.MessageType("Field")),
            number: 2,
            oneof_name: option.None,
            options: [],
          ),
          proto.Field(
            name: "oneofs",
            field_type: proto.Repeated(proto.String),
            number: 3,
            oneof_name: option.None,
            options: [],
          ),
          proto.Field(
            name: "options",
            field_type: proto.Repeated(proto.MessageType("Option")),
            number: 4,
            oneof_name: option.None,
            options: [],
          ),
          proto.Field(
            name: "source_context",
            field_type: proto.MessageType("SourceContext"),
            number: 5,
            oneof_name: option.None,
            options: [],
          ),
          proto.Field(
            name: "syntax",
            field_type: proto.EnumType("Syntax"),
            number: 6,
            oneof_name: option.None,
            options: [],
          ),
          proto.Field(
            name: "edition",
            field_type: proto.String,
            number: 7,
            oneof_name: option.None,
            options: [],
          ),
        ],
        oneofs: [],
        nested_messages: [],
        nested_enums: [],
      ),
      // Field message
      proto.Message(
        name: "Field",
        fields: [
          proto.Field(
            name: "kind",
            field_type: proto.EnumType("FieldKind"),
            number: 1,
            oneof_name: option.None,
            options: [],
          ),
          proto.Field(
            name: "cardinality",
            field_type: proto.EnumType("FieldCardinality"),
            number: 2,
            oneof_name: option.None,
            options: [],
          ),
          proto.Field(
            name: "number",
            field_type: proto.Int32,
            number: 3,
            oneof_name: option.None,
            options: [],
          ),
          proto.Field(
            name: "name",
            field_type: proto.String,
            number: 4,
            oneof_name: option.None,
            options: [],
          ),
          proto.Field(
            name: "type_url",
            field_type: proto.String,
            number: 6,
            oneof_name: option.None,
            options: [],
          ),
          proto.Field(
            name: "oneof_index",
            field_type: proto.Int32,
            number: 7,
            oneof_name: option.None,
            options: [],
          ),
          proto.Field(
            name: "packed",
            field_type: proto.Bool,
            number: 8,
            oneof_name: option.None,
            options: [],
          ),
          proto.Field(
            name: "options",
            field_type: proto.Repeated(proto.MessageType("Option")),
            number: 9,
            oneof_name: option.None,
            options: [],
          ),
          proto.Field(
            name: "json_name",
            field_type: proto.String,
            number: 10,
            oneof_name: option.None,
            options: [],
          ),
          proto.Field(
            name: "default_value",
            field_type: proto.String,
            number: 11,
            oneof_name: option.None,
            options: [],
          ),
        ],
        oneofs: [],
        nested_messages: [],
        nested_enums: [],
      ),
      // Enum message (describes a protobuf enum type, not to be confused with Gleam enum)
      proto.Message(
        name: "Enum",
        fields: [
          proto.Field(
            name: "name",
            field_type: proto.String,
            number: 1,
            oneof_name: option.None,
            options: [],
          ),
          proto.Field(
            name: "enumvalue",
            field_type: proto.Repeated(proto.MessageType("EnumValue")),
            number: 2,
            oneof_name: option.None,
            options: [],
          ),
          proto.Field(
            name: "options",
            field_type: proto.Repeated(proto.MessageType("Option")),
            number: 3,
            oneof_name: option.None,
            options: [],
          ),
          proto.Field(
            name: "source_context",
            field_type: proto.MessageType("SourceContext"),
            number: 4,
            oneof_name: option.None,
            options: [],
          ),
          proto.Field(
            name: "syntax",
            field_type: proto.EnumType("Syntax"),
            number: 5,
            oneof_name: option.None,
            options: [],
          ),
          proto.Field(
            name: "edition",
            field_type: proto.String,
            number: 6,
            oneof_name: option.None,
            options: [],
          ),
        ],
        oneofs: [],
        nested_messages: [],
        nested_enums: [],
      ),
      // EnumValue message
      proto.Message(
        name: "EnumValue",
        fields: [
          proto.Field(
            name: "name",
            field_type: proto.String,
            number: 1,
            oneof_name: option.None,
            options: [],
          ),
          proto.Field(
            name: "number",
            field_type: proto.Int32,
            number: 2,
            oneof_name: option.None,
            options: [],
          ),
          proto.Field(
            name: "options",
            field_type: proto.Repeated(proto.MessageType("Option")),
            number: 3,
            oneof_name: option.None,
            options: [],
          ),
        ],
        oneofs: [],
        nested_messages: [],
        nested_enums: [],
      ),
      // Option message
      proto.Message(
        name: "Option",
        fields: [
          proto.Field(
            name: "name",
            field_type: proto.String,
            number: 1,
            oneof_name: option.None,
            options: [],
          ),
          proto.Field(
            name: "value",
            field_type: proto.MessageType("Any"),
            number: 2,
            oneof_name: option.None,
            options: [],
          ),
        ],
        oneofs: [],
        nested_messages: [],
        nested_enums: [],
      ),
    ],
    enums: [
      // Syntax enum
      proto.Enum(name: "Syntax", values: [
        proto.EnumValue(name: "SYNTAX_PROTO2", number: 0),
        proto.EnumValue(name: "SYNTAX_PROTO3", number: 1),
        proto.EnumValue(name: "SYNTAX_EDITIONS", number: 2),
      ]),
      // Field.Kind enum (flattened as FieldKind)
      proto.Enum(name: "FieldKind", values: [
        proto.EnumValue(name: "TYPE_UNKNOWN", number: 0),
        proto.EnumValue(name: "TYPE_DOUBLE", number: 1),
        proto.EnumValue(name: "TYPE_FLOAT", number: 2),
        proto.EnumValue(name: "TYPE_INT64", number: 3),
        proto.EnumValue(name: "TYPE_UINT64", number: 4),
        proto.EnumValue(name: "TYPE_INT32", number: 5),
        proto.EnumValue(name: "TYPE_FIXED64", number: 6),
        proto.EnumValue(name: "TYPE_FIXED32", number: 7),
        proto.EnumValue(name: "TYPE_BOOL", number: 8),
        proto.EnumValue(name: "TYPE_STRING", number: 9),
        proto.EnumValue(name: "TYPE_GROUP", number: 10),
        proto.EnumValue(name: "TYPE_MESSAGE", number: 11),
        proto.EnumValue(name: "TYPE_BYTES", number: 12),
        proto.EnumValue(name: "TYPE_UINT32", number: 13),
        proto.EnumValue(name: "TYPE_ENUM", number: 14),
        proto.EnumValue(name: "TYPE_SFIXED32", number: 15),
        proto.EnumValue(name: "TYPE_SFIXED64", number: 16),
        proto.EnumValue(name: "TYPE_SINT32", number: 17),
        proto.EnumValue(name: "TYPE_SINT64", number: 18),
      ]),
      // Field.Cardinality enum (flattened as FieldCardinality)
      proto.Enum(name: "FieldCardinality", values: [
        proto.EnumValue(name: "CARDINALITY_UNKNOWN", number: 0),
        proto.EnumValue(name: "CARDINALITY_OPTIONAL", number: 1),
        proto.EnumValue(name: "CARDINALITY_REQUIRED", number: 2),
        proto.EnumValue(name: "CARDINALITY_REPEATED", number: 3),
      ]),
    ],
    services: [],
  )
}

fn api_proto() -> file.ProtoFile {
  file.ProtoFile(
    syntax: "proto3",
    package: option.Some("google.protobuf"),
    imports: [
      proto.Import(
        path: "google/protobuf/source_context.proto",
        public: False,
        weak: False,
      ),
      proto.Import(path: "google/protobuf/type.proto", public: False, weak: False),
    ],
    messages: [
      // Api message
      proto.Message(
        name: "Api",
        fields: [
          proto.Field(
            name: "name",
            field_type: proto.String,
            number: 1,
            oneof_name: option.None,
            options: [],
          ),
          proto.Field(
            name: "methods",
            field_type: proto.Repeated(proto.MessageType("Method")),
            number: 2,
            oneof_name: option.None,
            options: [],
          ),
          proto.Field(
            name: "options",
            field_type: proto.Repeated(proto.MessageType("Option")),
            number: 3,
            oneof_name: option.None,
            options: [],
          ),
          proto.Field(
            name: "version",
            field_type: proto.String,
            number: 4,
            oneof_name: option.None,
            options: [],
          ),
          proto.Field(
            name: "source_context",
            field_type: proto.MessageType("SourceContext"),
            number: 5,
            oneof_name: option.None,
            options: [],
          ),
          proto.Field(
            name: "mixins",
            field_type: proto.Repeated(proto.MessageType("Mixin")),
            number: 6,
            oneof_name: option.None,
            options: [],
          ),
          proto.Field(
            name: "syntax",
            field_type: proto.EnumType("Syntax"),
            number: 7,
            oneof_name: option.None,
            options: [],
          ),
        ],
        oneofs: [],
        nested_messages: [],
        nested_enums: [],
      ),
      // Method message
      proto.Message(
        name: "Method",
        fields: [
          proto.Field(
            name: "name",
            field_type: proto.String,
            number: 1,
            oneof_name: option.None,
            options: [],
          ),
          proto.Field(
            name: "request_type_url",
            field_type: proto.String,
            number: 2,
            oneof_name: option.None,
            options: [],
          ),
          proto.Field(
            name: "request_streaming",
            field_type: proto.Bool,
            number: 3,
            oneof_name: option.None,
            options: [],
          ),
          proto.Field(
            name: "response_type_url",
            field_type: proto.String,
            number: 4,
            oneof_name: option.None,
            options: [],
          ),
          proto.Field(
            name: "response_streaming",
            field_type: proto.Bool,
            number: 5,
            oneof_name: option.None,
            options: [],
          ),
          proto.Field(
            name: "options",
            field_type: proto.Repeated(proto.MessageType("Option")),
            number: 6,
            oneof_name: option.None,
            options: [],
          ),
          proto.Field(
            name: "syntax",
            field_type: proto.EnumType("Syntax"),
            number: 7,
            oneof_name: option.None,
            options: [],
          ),
        ],
        oneofs: [],
        nested_messages: [],
        nested_enums: [],
      ),
      // Mixin message
      proto.Message(
        name: "Mixin",
        fields: [
          proto.Field(
            name: "name",
            field_type: proto.String,
            number: 1,
            oneof_name: option.None,
            options: [],
          ),
          proto.Field(
            name: "root",
            field_type: proto.String,
            number: 2,
            oneof_name: option.None,
            options: [],
          ),
        ],
        oneofs: [],
        nested_messages: [],
        nested_enums: [],
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
    | "google/protobuf/field_mask.proto"
    | "google/protobuf/source_context.proto"
    | "google/protobuf/type.proto"
    | "google/protobuf/api.proto"
    | "google/api/annotations.proto"
    | "google/api/http.proto" -> True
    _ -> False
  }
}

pub fn is_well_known_type(type_name: String) -> Bool {
  case type_name {
    // Fully qualified names
    "google.protobuf.Timestamp"
    | "google.protobuf.Duration"
    | "google.protobuf.FieldMask"
    | "google.protobuf.Empty"
    | "google.protobuf.Any"
    | "google.protobuf.Struct"
    | "google.protobuf.StringValue"
    | "google.protobuf.Type"
    | "google.protobuf.Field"
    | "google.protobuf.Enum"
    | "google.protobuf.EnumValue"
    | "google.protobuf.Option"
    | "google.protobuf.SourceContext"
    | "google.protobuf.Api"
    | "google.protobuf.Method"
    | "google.protobuf.Mixin"
    | "google.protobuf.Syntax"
    | "google.protobuf.FieldKind"
    | "google.protobuf.FieldCardinality"
    | // Flattened names (what the parser might use after resolution)
      "Timestamp"
    | "Duration"
    | "FieldMask"
    | "Empty"
    | "Any"
    | "Struct"
    | "StringValue"
    | "Type"
    | "Field"
    | "Enum"
    | "EnumValue"
    | "Option"
    | "SourceContext"
    | "Api"
    | "Method"
    | "Mixin"
    | "Syntax"
    | "FieldKind"
    | "FieldCardinality" -> True
    _ -> False
  }
}
