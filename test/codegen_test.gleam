import glance
import gleam/string
import gleeunit
import protozoa/codegen
import protozoa/parser
import simplifile

pub fn main() -> Nil {
  gleeunit.main()
}

fn compile_test_and_save(
  proto_content: String,
  test_name: String,
  test_fn: fn(String) -> Nil,
) -> Nil {
  let parsed = parser.parse(proto_content)
  let generated = codegen.generate_simple(parsed)

  // Save the generated code to a file
  let output_path = "test/generated_outputs/" <> test_name <> ".gleam"
  let _ = simplifile.write(output_path, generated)

  // First verify it's valid Gleam code
  let assert Ok(_) = glance.module(generated)

  // Then run the specific test
  test_fn(generated)
}


// Helper function to assert string contains substring
fn assert_contains(haystack: String, needle: String) -> Nil {
  assert string.contains(haystack, needle)
}

pub fn simple_message_roundtrip_test() {
  let proto_content =
    "
syntax = \"proto3\";

message Person {
  string name = 1;
  int32 age = 2;
}
"

  compile_test_and_save(proto_content, "simple_message", fn(generated) {
    // Verify the structure is present
    assert_contains(generated, "pub type Person")
    assert_contains(generated, "pub fn encode_person")
    assert_contains(generated, "pub fn decode_person")
    assert_contains(generated, "pub fn person_decoder")

    // Check the type has correct fields
    assert_contains(generated, "name: String")
    assert_contains(generated, "age: Int")

    // Check encoder uses correct field numbers
    assert_contains(generated, "encode.string_field(1, person.name)")
    assert_contains(generated, "encode.int32_field(2, person.age)")

    // Check decoder uses correct field numbers
    assert_contains(generated, "decode.string_with_default(1, \"\")")
    assert_contains(generated, "decode.int32_with_default(2, 0)")
  })
}

pub fn nested_message_roundtrip_test() {
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

  compile_test_and_save(proto_content, "nested_message", fn(generated) {
    // Verify both types are generated
    assert_contains(generated, "pub type Outer")
    assert_contains(generated, "pub type Inner")

    // Check nested field type
    assert_contains(generated, "inner: Inner")

    // Check nested encoding
    assert_contains(generated, "encode_inner(outer.inner)")

    // Check nested decoding
    assert_contains(generated, "inner_decoder()")
  })
}

pub fn repeated_fields_roundtrip_test() {
  let proto_content =
    "
syntax = \"proto3\";

message Container {
  repeated string items = 1;
  repeated int32 values = 2;
}
"

  compile_test_and_save(proto_content, "repeated_fields", fn(generated) {
    // Check imports
    assert_contains(generated, "import gleam/list")

    // Check type definition
    assert_contains(generated, "items: List(String)")
    assert_contains(generated, "values: List(Int)")

    // Check repeated field encoding
    assert_contains(generated, "let items_fields = list.map(container.items")
    assert_contains(generated, "encode.string_field(1, v)")
    assert_contains(generated, "let values_fields = list.map(container.values")
    assert_contains(generated, "encode.int32_field(2, v)")

    // Check repeated field decoding
    assert_contains(generated, "decode.repeated_string(1)")
    assert_contains(generated, "decode.repeated_int32(2)")
  })
}

pub fn optional_fields_roundtrip_test() {
  let proto_content =
    "
syntax = \"proto3\";

message OptionalTest {
  string required_field = 1;
  optional string optional_string = 2;
  optional int32 optional_int = 3;
  optional bool optional_bool = 4;
}
"

  compile_test_and_save(proto_content, "optional_fields", fn(generated) {
    // Check imports
    assert_contains(generated, "import gleam/option.{type Option, None, Some}")

    // Check type definition
    assert_contains(generated, "required_field: String")
    assert_contains(generated, "optional_string: Option(String)")
    assert_contains(generated, "optional_int: Option(Int)")
    assert_contains(generated, "optional_bool: Option(Bool)")

    // Check optional field encoding
    assert_contains(generated, "case optionaltest.optional_string {")
    assert_contains(generated, "Some(value) -> encode.string_field(2, value)")
    assert_contains(generated, "None -> <<>>")

    // Check optional field decoding
    assert_contains(generated, "decode.optional_field(2, decode.string_field)")
    assert_contains(generated, "decode.optional_field(3, decode.int32_field)")
    assert_contains(generated, "decode.optional_field(4, decode.bool_field)")
  })
}

pub fn oneof_fields_roundtrip_test() {
  let proto_content =
    "
syntax = \"proto3\";

message OneofTest {
  string id = 1;
  
  oneof data {
    string text = 2;
    int32 number = 3;
    bool flag = 4;
  }
  
  int32 count = 10;
}
"

  compile_test_and_save(proto_content, "oneof_fields", fn(generated) {
    // Check imports

    // Check oneof type definition
    assert_contains(generated, "pub type OneofTestData")
    assert_contains(generated, "Text(String)")
    assert_contains(generated, "Number(Int)")
    assert_contains(generated, "Flag(Bool)")

    // Check main type has Result field
    assert_contains(generated, "data: option.Option(OneofTestData)")

    // Check oneof encoding
    assert_contains(generated, "case oneoftest.data {")
    assert_contains(generated, "Some(oneof_value) -> {")
    assert_contains(generated, "Text(value) -> encode.string_field(2, value)")
    assert_contains(generated, "Number(value) -> encode.int32_field(3, value)")
    assert_contains(generated, "Flag(value) -> encode.bool_field(4, value)")

    // Check oneof decoder helper
    assert_contains(generated, "fn oneof_data_decoder()")
    assert_contains(generated, "decode.from_field_dict(fn(fields)")
  })
}

pub fn enum_fields_roundtrip_test() {
  let proto_content =
    "
syntax = \"proto3\";

enum Status {
  UNKNOWN = 0;
  ACTIVE = 1;
  INACTIVE = 2;
}

message Task {
  string id = 1;
  Status status = 2;
  repeated Status history = 3;
}
"

  compile_test_and_save(proto_content, "enum_fields", fn(generated) {
    // Check imports (should include int for error messages)
    assert_contains(generated, "import gleam/int")

    // Check enum type definition
    assert_contains(generated, "pub type Status")
    assert_contains(generated, "UNKNOWN")
    assert_contains(generated, "ACTIVE")
    assert_contains(generated, "INACTIVE")

    // Check enum helpers
    assert_contains(
      generated,
      "pub fn encode_status_value(value: Status) -> Int",
    )
    assert_contains(
      generated,
      "pub fn decode_status_value(value: Int) -> Result(Status, String)",
    )
    assert_contains(generated, "pub fn decode_status_field(field_num: Int)")
    assert_contains(generated, "pub fn decode_repeated_status(field_num: Int)")

    // Check enum encoding in messages
    assert_contains(generated, "encode_status_value(task.status)")

    // Check enum decoding in messages
    assert_contains(generated, "decode_status_field(2)")
    assert_contains(generated, "decode_repeated_status(3)")
  })
}

pub fn map_fields_roundtrip_test() {
  let proto_content =
    "
syntax = \"proto3\";

message MapTest {
  map<string, string> attributes = 1;
  map<int32, bool> flags = 2;
}
"

  compile_test_and_save(proto_content, "map_fields", fn(generated) {
    // Check type definition
    assert_contains(generated, "attributes: List(#(String, String))")
    assert_contains(generated, "flags: List(#(Int, Bool))")

    // Check map encoding
    assert_contains(
      generated,
      "let attributes_fields = list.map(maptest.attributes",
    )
    assert_contains(generated, "encode.string_field(1, key)")
    assert_contains(generated, "encode.string_field(2, value)")

    assert_contains(generated, "let flags_fields = list.map(maptest.flags")
    assert_contains(generated, "encode.int32_field(1, key)")
    assert_contains(generated, "encode.bool_field(2, value)")

    // Check map decoder helpers
    assert_contains(generated, "fn map_entry_1_decoder()")
    assert_contains(generated, "fn map_entry_2_decoder()")

    // Check map decoding
    assert_contains(generated, "decode.repeated_field(1, fn(field)")
    assert_contains(generated, "decode.repeated_field(2, fn(field)")
  })
}

pub fn all_scalar_types_test() {
  let proto_content =
    "
syntax = \"proto3\";

message AllTypes {
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

  compile_test_and_save(proto_content, "all_scalar_types", fn(generated) {
    // Check type mappings
    assert_contains(generated, "double_field: Float")
    assert_contains(generated, "float_field: Float")
    assert_contains(generated, "int32_field: Int")
    assert_contains(generated, "bytes_field: BitArray")

    // Check encoders
    assert_contains(generated, "encode.double_field(1, alltypes.double_field)")
    assert_contains(generated, "encode.float_field(2, alltypes.float_field)")
    assert_contains(generated, "encode.int32_field(3, alltypes.int32_field)")
    assert_contains(generated, "encode.int64_field(4, alltypes.int64_field)")
    assert_contains(generated, "encode.uint32_field(5, alltypes.uint32_field)")
    assert_contains(generated, "encode.uint64_field(6, alltypes.uint64_field)")
    assert_contains(generated, "encode.sint32_field(7, alltypes.sint32_field)")
    assert_contains(generated, "encode.sint64_field(8, alltypes.sint64_field)")

    // Check decoders
    assert_contains(generated, "decode.double(1)")
    assert_contains(generated, "decode.float(2)")
    assert_contains(generated, "decode.int32_with_default(3, 0)")
    assert_contains(generated, "decode.int64_with_default(4, 0)")
    assert_contains(generated, "decode.uint32_with_default(5, 0)")
    assert_contains(generated, "decode.uint64_with_default(6, 0)")
    assert_contains(generated, "decode.sint32(7)")
    assert_contains(generated, "decode.sint64(8)")
  })
}

pub fn empty_message_test() {
  let proto_content =
    "
syntax = \"proto3\";

message Empty {
}
"

  compile_test_and_save(proto_content, "empty_message", fn(generated) {
    // Check type definition
    assert_contains(generated, "pub type Empty")

    // Check encoder handles empty message
    assert_contains(generated, "pub fn encode_empty(_empty: Empty)")
    assert_contains(generated, "encode.message([")

    // Check decoder handles empty message  
    assert_contains(generated, "decode.success(Empty")
  })
}

pub fn complex_nested_oneof_test() {
  let proto_content =
    "
syntax = \"proto3\";

message Complex {
  string id = 1;
  
  oneof first {
    string option_a = 2;
    NestedMessage option_b = 3;
  }
  
  oneof second {
    int32 number = 4;
    bool flag = 5;
  }
}

message NestedMessage {
  string value = 1;
}
"

  compile_test_and_save(proto_content, "complex_nested_oneof", fn(generated) {
    // Check multiple oneof types
    assert_contains(generated, "pub type ComplexFirst")
    assert_contains(generated, "OptionA(String)")
    assert_contains(generated, "OptionB(NestedMessage)")

    assert_contains(generated, "pub type ComplexSecond")
    assert_contains(generated, "Number(Int)")
    assert_contains(generated, "Flag(Bool)")

    // Check that nested message encoding is handled in oneof
    assert_contains(
      generated,
      "OptionB(value) -> encode.field(3, wire.LengthDelimited",
    )
    assert_contains(generated, "encode_nestedmessage(value)")
  })
}

pub fn with_imports_test() {
  let proto_content =
    "
syntax = \"proto3\";
import \"other.proto\";
message WithImport {
  string name = 1;
  OtherMessage other = 2;
}
"
  let other_proto_content =
    "
syntax = \"proto3\";
message OtherMessage {
  int32 id = 1;
}
"
  // First compile the imported proto to ensure OtherMessage is generated
  compile_test_and_save(other_proto_content, "other", fn(_generated) {
    Nil
    // No specific checks needed here
  })

  // Now compile the main proto that imports it
  compile_test_and_save(proto_content, "with_imports", fn(generated) {
    // Check that the imported type is referenced correctly
    assert_contains(generated, "other: other.OtherMessage")
    assert_contains(generated, "encode_othermessage(other)")
    assert_contains(generated, "othermessage_decoder()")
  })
}
