import gleam/list
import gleam/option.{None, Some}
import protozoa/parser/file
import protozoa/parser/proto

pub fn parse_complete_proto_file_test() {
  let input =
    "syntax = \"proto3\";

package example.v1;

import \"google/protobuf/timestamp.proto\";
import public \"common.proto\";

enum Status {
  UNKNOWN = 0;
  ACTIVE = 1;
  INACTIVE = 2;
}

message User {
  string name = 1;
  int32 age = 2;
  Status status = 3;
  repeated string emails = 4;
  map<string, string> metadata = 5;
}

service UserService {
  rpc GetUser (UserId) returns (User);
  rpc ListUsers (ListRequest) returns (stream User);
}
"

  let assert Ok(proto_file) = file.parse(input)

  // Verify syntax
  let assert "proto3" = proto_file.syntax

  // Verify package
  let assert Some("example.v1") = proto_file.package

  // Verify imports
  let assert [
    proto.Import("google/protobuf/timestamp.proto", False, False),
    proto.Import("common.proto", True, False),
  ] = proto_file.imports

  // Verify enums
  let assert [proto.Enum("Status", _)] = proto_file.enums

  // Verify messages
  let assert [proto.Message("User", fields, [], [], [])] = proto_file.messages
  let assert 5 = list.length(fields)

  // Verify status field has EnumType (not MessageType)
  let assert [_, _, proto.Field("status", field_type, 3, None, []), _, _] =
    fields
  let assert proto.EnumType("Status") = field_type

  // Verify services
  let assert [proto.Service("UserService", methods)] = proto_file.services
  let assert 2 = list.length(methods)
}

pub fn parse_nested_structures_test() {
  let input =
    "syntax = \"proto3\";

message Outer {
  string name = 1;
  
  message Inner {
    int32 value = 1;
    enum InnerEnum {
      DEFAULT = 0;
      SPECIAL = 1;
    }
    InnerEnum type = 2;
  }
  
  Inner inner = 2;
}
"

  let assert Ok(proto_file) = file.parse(input)

  // Verify nested message
  let assert [proto.Message("Outer", outer_fields, [], [inner_msg], [])] =
    proto_file.messages

  let assert proto.Message("Inner", inner_fields, [], [], [_inner_enum]) =
    inner_msg

  // Verify inner enum type is correctly identified
  let assert [_, proto.Field("type", field_type, 2, None, [])] = inner_fields
  let assert proto.EnumType("InnerEnum") = field_type

  // Verify outer references inner message
  let assert [_, proto.Field("inner", outer_inner_type, 2, None, [])] =
    outer_fields
  let assert proto.MessageType("Inner") = outer_inner_type
}

pub fn parse_oneof_with_enum_test() {
  let input =
    "syntax = \"proto3\";

enum ContactType {
  EMAIL = 0;
  PHONE = 1;
}

message User {
  string name = 1;
  oneof contact {
    string email = 2;
    string phone = 3;
  }
  ContactType preferred_contact = 4;
}
"

  let assert Ok(proto_file) = file.parse(input)

  // Verify enum is at top level
  let assert [proto.Enum("ContactType", _)] = proto_file.enums

  // Verify message
  let assert [proto.Message("User", fields, [_oneof], [], [])] =
    proto_file.messages

  // Verify preferred_contact is EnumType
  let assert [_, proto.Field("preferred_contact", field_type, 4, None, [])] =
    fields
  let assert proto.EnumType("ContactType") = field_type
}

pub fn invalid_field_number_zero_test() {
  let input =
    "syntax = \"proto3\";

message User {
  string name = 0;
}
"

  let assert Error(file.InvalidFieldNumber("User", "name", 0)) =
    file.parse(input)
}

pub fn invalid_field_number_negative_test() {
  let input =
    "syntax = \"proto3\";

message User {
  string name = -1;
}
"

  let assert Error(file.InvalidFieldNumber("User", "name", -1)) =
    file.parse(input)
}

pub fn duplicate_field_number_test() {
  let input =
    "syntax = \"proto3\";

message User {
  string name = 1;
  int32 age = 1;
}
"

  let assert Error(file.DuplicateFieldNumber("User", 1)) = file.parse(input)
}

pub fn duplicate_field_number_in_oneof_test() {
  let input =
    "syntax = \"proto3\";

message User {
  oneof contact {
    string email = 1;
    string phone = 1;
  }
}
"

  let assert Error(file.DuplicateFieldNumber("User", 1)) = file.parse(input)
}

pub fn duplicate_field_number_across_fields_and_oneof_test() {
  let input =
    "syntax = \"proto3\";

message User {
  string name = 1;
  oneof contact {
    string email = 2;
    string phone = 2;
  }
}
"

  let assert Error(file.DuplicateFieldNumber("User", 2)) = file.parse(input)
}

pub fn nested_message_invalid_field_number_test() {
  let input =
    "syntax = \"proto3\";

message Outer {
  string name = 1;
  
  message Inner {
    int32 value = 0;
  }
}
"

  let assert Error(file.InvalidFieldNumber("Inner", "value", 0)) =
    file.parse(input)
}

pub fn complex_enum_type_detection_test() {
  let input =
    "syntax = \"proto3\";

enum Color {
  RED = 0;
  GREEN = 1;
  BLUE = 2;
}

message Config {
  repeated Color colors = 1;
  optional Color primary = 2;
  map<string, Color> theme = 3;
}
"

  let assert Ok(proto_file) = file.parse(input)

  let assert [proto.Message("Config", fields, [], [], [])] = proto_file.messages

  // Verify repeated enum
  let assert [
    proto.Field("colors", proto.Repeated(colors_type), 1, None, []),
    proto.Field("primary", proto.Optional(primary_type), 2, None, []),
    proto.Field("theme", proto.Map(_, theme_value_type), 3, None, []),
  ] = fields

  let assert proto.EnumType("Color") = colors_type
  let assert proto.EnumType("Color") = primary_type
  let assert proto.EnumType("Color") = theme_value_type
}

pub fn minimal_proto_file_test() {
  let input = "syntax = \"proto3\";"

  let assert Ok(proto_file) = file.parse(input)

  let assert "proto3" = proto_file.syntax
  let assert None = proto_file.package
  let assert [] = proto_file.imports
  let assert [] = proto_file.messages
  let assert [] = proto_file.enums
  let assert [] = proto_file.services
}

pub fn empty_message_is_valid_test() {
  let input =
    "syntax = \"proto3\";

message Empty {}
"

  let assert Ok(proto_file) = file.parse(input)

  let assert [proto.Message("Empty", [], [], [], [])] = proto_file.messages
}
