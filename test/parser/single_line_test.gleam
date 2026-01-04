import protozoa/parser/file
import protozoa/parser/proto

pub fn empty_single_line_message_test() {
  let proto_content =
    "syntax = \"proto3\";

package test;

message HelloRequest {}
"

  let assert Ok(proto_file) = file.parse(proto_content)
  assert proto_file.messages != []

  let assert [message] = proto_file.messages
  assert message.name == "HelloRequest"
  assert message.fields == []
}

pub fn single_line_message_with_field_test() {
  let proto_content =
    "syntax = \"proto3\";

package test;

message HelloRequest { string name = 1; }
"

  let assert Ok(proto_file) = file.parse(proto_content)
  assert proto_file.messages != []

  let assert [message] = proto_file.messages
  assert message.name == "HelloRequest"
  assert message.fields != []

  let assert [field] = message.fields
  assert field.name == "name"
  assert field.number == 1
  let assert proto.String = field.field_type
}

pub fn single_line_message_with_multiple_fields_test() {
  let proto_content =
    "syntax = \"proto3\";

package test;

message User { string name = 1; int32 age = 2; }
"

  let assert Ok(proto_file) = file.parse(proto_content)
  let assert [message] = proto_file.messages

  assert message.name == "User"
  assert message.fields != []
}

pub fn empty_single_line_enum_test() {
  let proto_content =
    "syntax = \"proto3\";

package test;

enum Status {}
"

  let assert Ok(proto_file) = file.parse(proto_content)
  assert proto_file.enums != []

  let assert [enum] = proto_file.enums
  assert enum.name == "Status"
  assert enum.values == []
}

pub fn single_line_enum_with_values_test() {
  let proto_content =
    "syntax = \"proto3\";

package test;

enum Status { UNKNOWN = 0; ACTIVE = 1; }
"

  let assert Ok(proto_file) = file.parse(proto_content)
  let assert [enum] = proto_file.enums

  assert enum.name == "Status"
  assert enum.values != []
}

pub fn mixed_single_and_multi_line_messages_test() {
  let proto_content =
    "syntax = \"proto3\";

package test;

message EmptyRequest {}

message DetailedRequest {
  string name = 1;
  int32 id = 2;
}

message SingleLineRequest { bool flag = 1; }
"

  let assert Ok(proto_file) = file.parse(proto_content)
  assert proto_file.messages != []
}

pub fn issue_3_regression_test() {
  // This test verifies that Issue #3 is fixed:
  // Single-line messages like "message Empty {}" should parse correctly
  let proto_content =
    "syntax = \"proto3\";

package test;

message Empty {}
message Request { int32 id = 1; }
enum State { UNKNOWN = 0; }
"

  let assert Ok(proto_file) = file.parse(proto_content)
  assert proto_file.messages != []
  assert proto_file.enums != []

  // Should have 2 messages
  let assert [empty, request] = proto_file.messages
  assert empty.name == "Empty"
  assert empty.fields == []
  assert request.name == "Request"
  assert request.fields != []

  // Should have 1 enum
  let assert [state] = proto_file.enums
  assert state.name == "State"
}
