import birdie
import glance
import gleeunit
import gloto/codegen
import gloto/proto_parser as parser

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn generate_text_message_proto_test() {
  let proto_content =
    "
syntax = \"proto3\";

message TestMessage {
  string name = 1;
  int32 value = 2;
}
"

  let parsed = parser.parse_simple(proto_content)
  let generated = codegen.generate_simple(parsed)
  let assert Ok(_) = glance.module(generated)

  birdie.snap(generated, "Generate text messages")
}

pub fn generate_nested_messages_test() {
  let proto_content =
    "
syntax = \"proto3\";

message Outer {
  string id = 1;
  Inner inner = 2;
}

message Inner {
  int32 value = 1;
}
"

  let parsed = parser.parse_simple(proto_content)
  let generated = codegen.generate_simple(parsed)
  let assert Ok(_) = glance.module(generated)

  birdie.snap(generated, "Generate nested messages")
}

pub fn generate_repeated_fields_test() {
  let proto_content =
    "
syntax = \"proto3\";

message Container {
  repeated string items = 1;
  int32 count = 2;
}
"

  let parsed = parser.parse_simple(proto_content)
  let generated = codegen.generate_simple(parsed)

  let assert Ok(_) = glance.module(generated)

  birdie.snap(generated, "Generate repeated fields")
}

pub fn field_types_test() {
  let proto_content =
    "
syntax = \"proto3\";

message AllTypes {
  double d = 1;
  float f = 2;
  int32 i32 = 3;
  int64 i64 = 4;
  bool b = 5;
  string s = 6;
  bytes by = 7;
}
"

  let parsed = parser.parse_simple(proto_content)
  let generated = codegen.generate_simple(parsed)

  let assert Ok(_) = glance.module(generated)

  birdie.snap(generated, "Generate all field types")
}

pub fn generate_oneof_code_test() {
  let proto_content =
    "
syntax = \"proto3\";

message TestOneof {
  string name = 1;
  
  oneof test_value {
    string string_value = 2;
    int32 int_value = 3;
  }
  
  int32 id = 10;
}
"

  let parsed = parser.parse_simple(proto_content)
  let generated = codegen.generate_simple(parsed)

  let assert Ok(_) = glance.module(generated)

  birdie.snap(generated, "Generate oneof fields")
}

pub fn generate_complex_oneof_test() {
  let proto_content =
    "
syntax = \"proto3\";

message ComplexOneof {
  string id = 1;
  
  oneof data {
    string text = 2;
    int32 number = 3;
    bool flag = 4;
    NestedMessage nested = 5;
  }
  
  repeated string tags = 10;
}

message NestedMessage {
  string value = 1;
}
"

  let parsed = parser.parse_simple(proto_content)
  let generated = codegen.generate_simple(parsed)

  let assert Ok(_) = glance.module(generated)

  birdie.snap(generated, "Generate complex oneof with nested message")
}

pub fn generate_multiple_oneofs_test() {
  let proto_content =
    "
syntax = \"proto3\";

message MultipleOneofs {
  string id = 1;
  
  oneof first_choice {
    string option_a = 2;
    int32 option_b = 3;
  }
  
  oneof second_choice {
    bool enabled = 4;
    float value = 5;
  }
  
  string name = 10;
}
"

  let parsed = parser.parse_simple(proto_content)
  let generated = codegen.generate_simple(parsed)

  let assert Ok(_) = glance.module(generated)

  birdie.snap(generated, "Generate message with multiple oneofs")
}

pub fn generate_optional_fields_test() {
  let proto_content =
    "
syntax = \"proto3\";

message OptionalFields {
  string required_name = 1;
  optional string nickname = 2;
  optional int32 age = 3;
  optional bool active = 4;
  optional NestedOptional nested = 5;
}

message NestedOptional {
  optional string value = 1;
}
"

  let parsed = parser.parse_simple(proto_content)
  let generated = codegen.generate_simple(parsed)

  let assert Ok(_) = glance.module(generated)

  birdie.snap(generated, "Generate optional fields")
}

pub fn generate_enums_test() {
  let proto_content =
    "
syntax = \"proto3\";

enum Status {
  UNKNOWN = 0;
  PENDING = 1;
  ACTIVE = 2;
  COMPLETED = 3;
}

message Task {
  string id = 1;
  Status status = 2;
  repeated Status history = 3;
}
"

  let parsed = parser.parse_simple(proto_content)
  let generated = codegen.generate_simple(parsed)

  let assert Ok(_) = glance.module(generated)

  birdie.snap(generated, "Generate enums and enum fields")
}

pub fn generate_maps_test() {
  let proto_content =
    "
syntax = \"proto3\";

message MapMessage {
  map<string, string> attributes = 1;
  map<int32, bool> flags = 2;
  map<string, NestedValue> objects = 3;
}

message NestedValue {
  string data = 1;
}
"

  let parsed = parser.parse_simple(proto_content)
  let generated = codegen.generate_simple(parsed)

  let assert Ok(_) = glance.module(generated)

  birdie.snap(generated, "Generate map fields")
}

pub fn generate_empty_message_test() {
  let proto_content =
    "
syntax = \"proto3\";

message EmptyMessage {
}
"

  let parsed = parser.parse_simple(proto_content)
  let generated = codegen.generate_simple(parsed)

  let assert Ok(_) = glance.module(generated)

  birdie.snap(generated, "Generate empty message")
}

pub fn generate_reserved_fields_test() {
  let proto_content =
    "
syntax = \"proto3\";

message ReservedFields {
  reserved 2, 15, 9 to 11;
  reserved \"foo\", \"bar\";
  
  string name = 1;
  int32 value = 3;
}
"

  let parsed = parser.parse_simple(proto_content)
  let generated = codegen.generate_simple(parsed)

  let assert Ok(_) = glance.module(generated)

  birdie.snap(generated, "Generate message with reserved fields")
}

pub fn generate_all_scalar_types_test() {
  let proto_content =
    "
syntax = \"proto3\";

message AllScalarTypes {
  double double_field = 1;
  float float_field = 2;
  int32 int32_field = 3;
  int64 int64_field = 4;
  uint32 uint32_field = 5;
  uint64 uint64_field = 6;
  sint32 sint32_field = 7;
  sint64 sint64_field = 8;
  fixed32 fixed32_field = 9;
  fixed64 fixed64_field = 10;
  sfixed32 sfixed32_field = 11;
  sfixed64 sfixed64_field = 12;
  bool bool_field = 13;
  string string_field = 14;
  bytes bytes_field = 15;
}
"

  let parsed = parser.parse_simple(proto_content)
  let generated = codegen.generate_simple(parsed)

  let assert Ok(_) = glance.module(generated)

  birdie.snap(generated, "Generate all scalar types")
}
