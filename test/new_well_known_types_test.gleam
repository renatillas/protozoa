import birdie
import gleeunit
import protozoa/internal/codegen

pub fn main() {
  gleeunit.main()
}

// Test that our new well-known type generator functions work correctly
pub fn generate_type_definition_test() {
  codegen.generate_well_known_type_definition("Type")
  |> birdie.snap("Well known type definition: Type")
}

pub fn generate_field_definition_test() {
  codegen.generate_well_known_type_definition("Field")
  |> birdie.snap("Well known type definition: Field")
}

pub fn generate_option_definition_test() {
  codegen.generate_well_known_type_definition("Option")
  |> birdie.snap("Well known type definiton: Option")
}

pub fn generate_sourcecontext_definition_test() {
  codegen.generate_well_known_type_definition("SourceContext")
  |> birdie.snap("Well known type definiton: SourceContext")
}

pub fn generate_api_definition_test() {
  codegen.generate_well_known_type_definition("Api")
  |> birdie.snap("Well known type definiton: Api")
}

pub fn generate_enum_definition_test() {
  codegen.generate_well_known_type_definition("Enum")
  |> birdie.snap("Well known type definiton: Enum")
}

pub fn generate_enumvalue_definition_test() {
  codegen.generate_well_known_type_definition("EnumValue")
  |> birdie.snap("Well known type definiton: EnumValue")
}

pub fn generate_method_definition_test() {
  codegen.generate_well_known_type_definition("Method")
  |> birdie.snap("Well known type definiton: Method")
}

pub fn generate_mixin_definition_test() {
  codegen.generate_well_known_type_definition("Mixin")
  |> birdie.snap("Well known type definiton: Mixin")
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
