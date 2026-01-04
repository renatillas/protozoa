import gleam/option.{None, Some}
import nibble
import nibble/lexer
import protozoa/parser/lexer as proto_lexer
import protozoa/parser/proto

pub fn parse_syntax_proto3_test() {
  let input = "syntax = \"proto3\";"

  let assert Ok(tokens) = lexer.run(input, proto_lexer.proto_lexer())
  let assert Ok(version) = nibble.run(tokens, proto.syntax())

  let assert "proto3" = version
}

pub fn parse_syntax_proto2_fails_test() {
  let input = "syntax = \"proto2\";"

  let assert Ok(tokens) = lexer.run(input, proto_lexer.proto_lexer())
  let assert Error(_) = nibble.run(tokens, proto.syntax())
}

pub fn parse_package_test() {
  let input = "package com.example.proto;"

  let assert Ok(tokens) = lexer.run(input, proto_lexer.proto_lexer())
  let assert Ok(pkg) = nibble.run(tokens, proto.package())

  let assert Some("com.example.proto") = pkg
}

pub fn parse_package_simple_test() {
  let input = "package example;"

  let assert Ok(tokens) = lexer.run(input, proto_lexer.proto_lexer())
  let assert Ok(pkg) = nibble.run(tokens, proto.package())

  let assert Some("example") = pkg
}

pub fn parse_no_package_test() {
  let input = ""

  let assert Ok(tokens) = lexer.run(input, proto_lexer.proto_lexer())
  let assert Ok(pkg) = nibble.run(tokens, proto.package())

  let assert None = pkg
}

pub fn parse_import_test() {
  let input = "import \"google/protobuf/timestamp.proto\";"

  let assert Ok(tokens) = lexer.run(input, proto_lexer.proto_lexer())
  let assert Ok([proto.Import("google/protobuf/timestamp.proto", False, False)]) =
    nibble.run(tokens, proto.imports())
}

pub fn parse_import_public_test() {
  let input = "import public \"other.proto\";"

  let assert Ok(tokens) = lexer.run(input, proto_lexer.proto_lexer())
  let assert Ok([proto.Import("other.proto", True, False)]) =
    nibble.run(tokens, proto.imports())
}

pub fn parse_import_weak_test() {
  let input = "import weak \"other.proto\";"

  let assert Ok(tokens) = lexer.run(input, proto_lexer.proto_lexer())
  let assert Ok([proto.Import("other.proto", False, True)]) =
    nibble.run(tokens, proto.imports())
}

pub fn parse_multiple_imports_test() {
  let input =
    "import \"a.proto\";
import public \"b.proto\";
import weak \"c.proto\";"

  let assert Ok(tokens) = lexer.run(input, proto_lexer.proto_lexer())
  let assert Ok([
    proto.Import("a.proto", False, False),
    proto.Import("b.proto", True, False),
    proto.Import("c.proto", False, True),
  ]) = nibble.run(tokens, proto.imports())
}

pub fn parse_enum_test() {
  let input =
    "enum Status {
  UNKNOWN = 0;
  ACTIVE = 1;
  INACTIVE = 2;
}"

  let assert Ok(tokens) = lexer.run(input, proto_lexer.proto_lexer())
  let assert Ok(proto.Enum(
    "Status",
    [
      proto.EnumValue("UNKNOWN", 0),
      proto.EnumValue("ACTIVE", 1),
      proto.EnumValue("INACTIVE", 2),
    ],
  )) = nibble.run(tokens, proto.enum_def())
}

pub fn parse_empty_enum_test() {
  let input = "enum Empty {}"

  let assert Ok(tokens) = lexer.run(input, proto_lexer.proto_lexer())
  let assert Ok(proto.Enum("Empty", [])) = nibble.run(tokens, proto.enum_def())
}

pub fn parse_single_line_enum_test() {
  let input = "enum Status { UNKNOWN = 0; ACTIVE = 1; }"

  let assert Ok(tokens) = lexer.run(input, proto_lexer.proto_lexer())
  let assert Ok(proto.Enum(
    "Status",
    [proto.EnumValue("UNKNOWN", 0), proto.EnumValue("ACTIVE", 1)],
  )) = nibble.run(tokens, proto.enum_def())
}

pub fn parse_empty_message_test() {
  let input = "message Empty {}"

  let assert Ok(tokens) = lexer.run(input, proto_lexer.proto_lexer())
  let assert Ok(proto.Message("Empty", [], [], [], [])) =
    nibble.run(tokens, proto.message())
}

pub fn parse_simple_message_test() {
  let input =
    "message User {
  string name = 1;
  int32 age = 2;
}"

  let assert Ok(tokens) = lexer.run(input, proto_lexer.proto_lexer())
  let assert Ok(proto.Message(
    "User",
    [
      proto.Field("name", proto.String, 1, None, []),
      proto.Field("age", proto.Int32, 2, None, []),
    ],
    [],
    [],
    [],
  )) = nibble.run(tokens, proto.message())
}

pub fn parse_message_with_repeated_test() {
  let input =
    "message User {
  repeated string emails = 1;
}"

  let assert Ok(tokens) = lexer.run(input, proto_lexer.proto_lexer())
  let assert Ok(proto.Message(
    "User",
    [proto.Field("emails", proto.Repeated(proto.String), 1, None, [])],
    [],
    [],
    [],
  )) = nibble.run(tokens, proto.message())
}

pub fn parse_message_with_optional_test() {
  let input =
    "message User {
  optional string nickname = 1;
}"

  let assert Ok(tokens) = lexer.run(input, proto_lexer.proto_lexer())
  let assert Ok(proto.Message(
    "User",
    [proto.Field("nickname", proto.Optional(proto.String), 1, None, [])],
    [],
    [],
    [],
  )) = nibble.run(tokens, proto.message())
}

pub fn parse_message_with_map_test() {
  let input =
    "message User {
  map<string, int32> attributes = 1;
}"

  let assert Ok(tokens) = lexer.run(input, proto_lexer.proto_lexer())
  let assert Ok(proto.Message(
    "User",
    [
      proto.Field(
        "attributes",
        proto.Map(proto.String, proto.Int32),
        1,
        None,
        [],
      ),
    ],
    [],
    [],
    [],
  )) = nibble.run(tokens, proto.message())
}

pub fn parse_message_with_message_type_test() {
  let input =
    "message Post {
  User author = 1;
}"

  let assert Ok(tokens) = lexer.run(input, proto_lexer.proto_lexer())
  let assert Ok(proto.Message(
    "Post",
    [proto.Field("author", proto.MessageType("User"), 1, None, [])],
    [],
    [],
    [],
  )) = nibble.run(tokens, proto.message())
}

pub fn parse_single_line_message_test() {
  let input = "message User { string name = 1; }"

  let assert Ok(tokens) = lexer.run(input, proto_lexer.proto_lexer())
  let assert Ok(proto.Message(
    "User",
    [proto.Field("name", proto.String, 1, None, [])],
    [],
    [],
    [],
  )) = nibble.run(tokens, proto.message())
}

pub fn parse_message_with_nested_message_test() {
  let input =
    "message User {
  string name = 1;
  message Address {
    string street = 1;
  }
}"

  let assert Ok(tokens) = lexer.run(input, proto_lexer.proto_lexer())
  let assert Ok(proto.Message(
    "User",
    [proto.Field("name", proto.String, 1, None, [])],
    [],
    [
      proto.Message(
        "Address",
        [proto.Field("street", proto.String, 1, None, [])],
        [],
        [],
        [],
      ),
    ],
    [],
  )) = nibble.run(tokens, proto.message())
}

pub fn parse_message_with_nested_enum_test() {
  let input =
    "message User {
  string name = 1;
  enum Status {
    UNKNOWN = 0;
    ACTIVE = 1;
  }
}"

  let assert Ok(tokens) = lexer.run(input, proto_lexer.proto_lexer())
  let assert Ok(proto.Message(
    "User",
    [proto.Field("name", proto.String, 1, None, [])],
    [],
    [],
    [
      proto.Enum(
        "Status",
        [proto.EnumValue("UNKNOWN", 0), proto.EnumValue("ACTIVE", 1)],
      ),
    ],
  )) = nibble.run(tokens, proto.message())
}

pub fn parse_message_with_multiple_nested_test() {
  let input =
    "message User {
  string name = 1;
  message Address {
    string street = 1;
  }
  enum Role {
    USER = 0;
    ADMIN = 1;
  }
  message Contact {
    string email = 1;
  }
}"

  let assert Ok(tokens) = lexer.run(input, proto_lexer.proto_lexer())
  let assert Ok(proto.Message(
    "User",
    [proto.Field("name", proto.String, 1, None, [])],
    [],
    [
      proto.Message(
        "Address",
        [proto.Field("street", proto.String, 1, None, [])],
        [],
        [],
        [],
      ),
      proto.Message(
        "Contact",
        [proto.Field("email", proto.String, 1, None, [])],
        [],
        [],
        [],
      ),
    ],
    [
      proto.Enum(
        "Role",
        [proto.EnumValue("USER", 0), proto.EnumValue("ADMIN", 1)],
      ),
    ],
  )) = nibble.run(tokens, proto.message())
}

pub fn parse_oneof_test() {
  let input =
    "message User {
  oneof identifier {
    string email = 1;
    int32 user_id = 2;
  }
}"

  let assert Ok(tokens) = lexer.run(input, proto_lexer.proto_lexer())
  let assert Ok(proto.Message(
    "User",
    [],
    [
      proto.Oneof(
        "identifier",
        [
          proto.Field("email", proto.String, 1, Some("identifier"), []),
          proto.Field("user_id", proto.Int32, 2, Some("identifier"), []),
        ],
      ),
    ],
    [],
    [],
  )) = nibble.run(tokens, proto.message())
}

pub fn parse_message_with_fields_and_oneof_test() {
  let input =
    "message User {
  string name = 1;
  oneof contact {
    string email = 2;
    string phone = 3;
  }
  int32 age = 4;
}"

  let assert Ok(tokens) = lexer.run(input, proto_lexer.proto_lexer())
  let assert Ok(proto.Message(
    "User",
    [
      proto.Field("name", proto.String, 1, None, []),
      proto.Field("age", proto.Int32, 4, None, []),
    ],
    [
      proto.Oneof(
        "contact",
        [
          proto.Field("email", proto.String, 2, Some("contact"), []),
          proto.Field("phone", proto.String, 3, Some("contact"), []),
        ],
      ),
    ],
    [],
    [],
  )) = nibble.run(tokens, proto.message())
}

pub fn parse_field_with_deprecated_option_test() {
  let input =
    "message User {
  string old_name = 1 [deprecated = true];
}"

  let assert Ok(tokens) = lexer.run(input, proto_lexer.proto_lexer())
  let assert Ok(proto.Message(
    "User",
    [proto.Field("old_name", proto.String, 1, None, [proto.Deprecated(True)])],
    [],
    [],
    [],
  )) = nibble.run(tokens, proto.message())
}

pub fn parse_field_with_json_name_option_test() {
  let input =
    "message User {
  string user_name = 1 [json_name = \"userName\"];
}"

  let assert Ok(tokens) = lexer.run(input, proto_lexer.proto_lexer())
  let assert Ok(proto.Message(
    "User",
    [
      proto.Field(
        "user_name",
        proto.String,
        1,
        None,
        [proto.JsonName("userName")],
      ),
    ],
    [],
    [],
    [],
  )) = nibble.run(tokens, proto.message())
}

pub fn parse_field_with_packed_option_test() {
  let input =
    "message Data {
  repeated int32 values = 1 [packed = true];
}"

  let assert Ok(tokens) = lexer.run(input, proto_lexer.proto_lexer())
  let assert Ok(proto.Message(
    "Data",
    [
      proto.Field(
        "values",
        proto.Repeated(proto.Int32),
        1,
        None,
        [proto.Packed(True)],
      ),
    ],
    [],
    [],
    [],
  )) = nibble.run(tokens, proto.message())
}

pub fn parse_field_with_multiple_options_test() {
  let input =
    "message User {
  string old_name = 1 [deprecated = true, json_name = \"oldName\"];
}"

  let assert Ok(tokens) = lexer.run(input, proto_lexer.proto_lexer())
  let assert Ok(proto.Message(
    "User",
    [
      proto.Field(
        "old_name",
        proto.String,
        1,
        None,
        [proto.Deprecated(True), proto.JsonName("oldName")],
      ),
    ],
    [],
    [],
    [],
  )) = nibble.run(tokens, proto.message())
}

pub fn parse_simple_service_test() {
  let input =
    "service Greeter {
  rpc SayHello (HelloRequest) returns (HelloReply);
}"

  let assert Ok(tokens) = lexer.run(input, proto_lexer.proto_lexer())
  let assert Ok([
    proto.Service(
      "Greeter",
      [
        proto.Method(
          "SayHello",
          "HelloRequest",
          "HelloReply",
          False,
          False,
          None,
          None,
        ),
      ],
    ),
  ]) = nibble.run(tokens, proto.services())
}

pub fn parse_service_with_streaming_test() {
  let input =
    "service Chat {
  rpc BidiChat (stream ChatMessage) returns (stream ChatMessage);
  rpc ServerStream (Request) returns (stream Response);
  rpc ClientStream (stream Request) returns (Response);
}"

  let assert Ok(tokens) = lexer.run(input, proto_lexer.proto_lexer())
  let assert Ok([
    proto.Service(
      "Chat",
      [
        proto.Method(
          "BidiChat",
          "ChatMessage",
          "ChatMessage",
          True,
          True,
          None,
          None,
        ),
        proto.Method(
          "ServerStream",
          "Request",
          "Response",
          False,
          True,
          None,
          None,
        ),
        proto.Method(
          "ClientStream",
          "Request",
          "Response",
          True,
          False,
          None,
          None,
        ),
      ],
    ),
  ]) = nibble.run(tokens, proto.services())
}

pub fn parse_service_with_options_block_test() {
  let input =
    "service UserService {
  rpc GetUser (UserId) returns (User) {
    option (google.api.http) = {
      get: \"/v1/users/{id}\"
    };
  }
}"

  let assert Ok(tokens) = lexer.run(input, proto_lexer.proto_lexer())
  let assert Ok([
    proto.Service(
      "UserService",
      [
        proto.Method(
          "GetUser",
          "UserId",
          "User",
          False,
          False,
          Some(proto.Get),
          Some("/v1/users/{id}"),
        ),
      ],
    ),
  ]) = nibble.run(tokens, proto.services())
}
