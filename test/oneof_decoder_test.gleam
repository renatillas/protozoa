import gleam/string
import gleeunit
import protozoa/codegen
import protozoa/parser

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn test_oneof_decoder_works() {
  // Create a simple proto with oneof
  let proto_content =
    "
syntax = \"proto3\";

message TestOneof {
  string id = 1;
  
  oneof value {
    string text = 2;
    int32 number = 3;
    bool flag = 4;
  }
}
"

  let parsed = parser.parse(proto_content)
  let generated = codegen.generate_simple_for_testing(parsed)

  // Check that the decoder properly tries all fields
  assert string.contains(
    generated,
    "case list.find(fields, fn(f) { f.number == 2 })",
  )
  assert string.contains(
    generated,
    "case list.find(fields, fn(f) { f.number == 3 })",
  )
  assert string.contains(
    generated,
    "case list.find(fields, fn(f) { f.number == 4 })",
  )

  // Check that variants are properly created
  assert string.contains(generated, "TestOneofValue.Text(value)")
  assert string.contains(generated, "TestOneofValue.Number(value)")
  assert string.contains(generated, "TestOneofValue.Flag(value)")

  // Check that failed matches continue to next field
  assert string.contains(generated, "Error(_) -> {")
}
