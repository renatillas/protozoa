import gleam/string
import gleeunit
import protozoa/internal/codegen

pub fn main() {
  gleeunit.main()
}

// Test that our new well-known type generator functions work correctly
pub fn generate_type_definition_test() {
  let generated = codegen.generate_well_known_type_definition("Type")

  // Should contain the Type definition
  assert string.contains(generated, "pub type Type {")

  // Should contain the Syntax enum
  assert string.contains(generated, "pub type Syntax {")

  // Should contain encoder
  assert string.contains(generated, "pub fn encode_type(")

  // Should contain decoder  
  assert string.contains(generated, "pub fn type_decoder()")
}

pub fn generate_field_definition_test() {
  let generated = codegen.generate_well_known_type_definition("Field")
  // Should contain the Field definition
  assert string.contains(generated, "pub type Field {")

  // Should contain the FieldKind enum
  assert string.contains(generated, "pub type FieldKind {")

  // Should contain the FieldCardinality enum
  assert string.contains(generated, "pub type FieldCardinality {")

  // Should contain encoder
  assert string.contains(generated, "pub fn encode_field(")

  // Should contain decoder
  assert string.contains(generated, "pub fn field_decoder()")
}

pub fn generate_option_definition_test() {
  let generated = codegen.generate_well_known_type_definition("Option")

  // Should contain the Option definition
  assert string.contains(generated, "pub type Option {")

  // Should contain encoder
  assert string.contains(generated, "pub fn encode_option(")

  // Should contain decoder
  assert string.contains(generated, "pub fn option_decoder()")
}

pub fn generate_sourcecontext_definition_test() {
  let generated = codegen.generate_well_known_type_definition("SourceContext")

  // Should contain the SourceContext definition  
  assert string.contains(generated, "pub type SourceContext {")

  // Should contain encoder
  assert string.contains(generated, "pub fn encode_sourcecontext(")

  // Should contain decoder
  assert string.contains(generated, "pub fn sourcecontext_decoder()")
}

pub fn generate_api_definition_test() {
  let generated = codegen.generate_well_known_type_definition("Api")

  // Should contain the Api definition
  assert string.contains(generated, "pub type Api {")

  // Should contain encoder
  assert string.contains(generated, "pub fn encode_api(")

  // Should contain decoder
  assert string.contains(generated, "pub fn api_decoder()")
}

pub fn generate_enum_definition_test() {
  let generated = codegen.generate_well_known_type_definition("Enum")

  // Should contain the Enum definition
  assert string.contains(generated, "pub type Enum {")

  // Should contain encoder
  assert string.contains(generated, "pub fn encode_enum(")

  // Should contain decoder
  assert string.contains(generated, "pub fn enum_decoder()")
}

pub fn generate_enumvalue_definition_test() {
  let generated = codegen.generate_well_known_type_definition("EnumValue")

  // Should contain the EnumValue definition
  assert string.contains(generated, "pub type EnumValue {")

  // Should contain encoder
  assert string.contains(generated, "pub fn encode_enumvalue(")

  // Should contain decoder
  assert string.contains(generated, "pub fn enumvalue_decoder()")
}

pub fn generate_method_definition_test() {
  let generated = codegen.generate_well_known_type_definition("Method")

  // Should contain the Method definition
  assert string.contains(generated, "pub type Method {")

  // Should contain encoder
  assert string.contains(generated, "pub fn encode_method(")

  // Should contain decoder
  assert string.contains(generated, "pub fn method_decoder()")
}

pub fn generate_mixin_definition_test() {
  let generated = codegen.generate_well_known_type_definition("Mixin")

  // Should contain the Mixin definition
  assert string.contains(generated, "pub type Mixin {")

  // Should contain encoder
  assert string.contains(generated, "pub fn encode_mixin(")

  // Should contain decoder
  assert string.contains(generated, "pub fn mixin_decoder()")
}

pub fn all_new_types_recognized_test() {
  // Test that all our new types are recognized as well-known types
  assert codegen.is_well_known_type("google.protobuf.Type")

  assert codegen.is_well_known_type("google.protobuf.Field")

  assert codegen.is_well_known_type("google.protobuf.Enum")

  assert codegen.is_well_known_type("google.protobuf.EnumValue")

  assert codegen.is_well_known_type("google.protobuf.Option")

  assert codegen.is_well_known_type("google.protobuf.SourceContext")

  assert codegen.is_well_known_type("google.protobuf.Api")

  assert codegen.is_well_known_type("google.protobuf.Method")

  assert codegen.is_well_known_type("google.protobuf.Mixin")

  // Test short names too
  assert codegen.is_well_known_type("Type")

  assert codegen.is_well_known_type("Field")
}
