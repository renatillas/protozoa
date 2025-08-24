import gleam/list
import gleeunit
import protozoa/wire as wire_format

pub fn main() {
  gleeunit.main()
}

// Test wire_type_value function
pub fn wire_type_value_test() {
  assert wire_format.wire_type_value(wire_format.Varint) == 0

  assert wire_format.wire_type_value(wire_format.Fixed64) == 1

  assert wire_format.wire_type_value(wire_format.LengthDelimited) == 2

  assert wire_format.wire_type_value(wire_format.StartGroup) == 3

  assert wire_format.wire_type_value(wire_format.EndGroup) == 4

  assert wire_format.wire_type_value(wire_format.Fixed32) == 5
}

// Test wire_type_from_int function
pub fn wire_type_from_int_test() {
  assert wire_format.wire_type_from_int(0) == Ok(wire_format.Varint)

  assert wire_format.wire_type_from_int(1) == Ok(wire_format.Fixed64)

  assert wire_format.wire_type_from_int(2) == Ok(wire_format.LengthDelimited)

  assert wire_format.wire_type_from_int(3) == Ok(wire_format.StartGroup)

  assert wire_format.wire_type_from_int(4) == Ok(wire_format.EndGroup)

  assert wire_format.wire_type_from_int(5) == Ok(wire_format.Fixed32)

  // Test invalid wire type
  assert wire_format.wire_type_from_int(7) == Error("Invalid wire type: 7")

  assert wire_format.wire_type_from_int(-1) == Error("Invalid wire type: -1")
}

// Test make_tag function
pub fn make_tag_test() {
  // Field 1 with Varint (0) = (1 << 3) | 0 = 8
  assert wire_format.make_tag(1, wire_format.Varint) == 8

  // Field 2 with LengthDelimited (2) = (2 << 3) | 2 = 18
  assert wire_format.make_tag(2, wire_format.LengthDelimited) == 18

  // Field 15 with Fixed32 (5) = (15 << 3) | 5 = 125
  assert wire_format.make_tag(15, wire_format.Fixed32) == 125

  // Field 100 with Fixed64 (1) = (100 << 3) | 1 = 801
  assert wire_format.make_tag(100, wire_format.Fixed64) == 801
}

// Test get_field_number function
pub fn get_field_number_test() {
  // Tag 8 = field 1
  assert wire_format.get_field_number(8) == 1

  // Tag 18 = field 2
  assert wire_format.get_field_number(18) == 2

  // Tag 125 = field 15
  assert wire_format.get_field_number(125) == 15

  // Tag 801 = field 100
  assert wire_format.get_field_number(801) == 100

  // Tag 0 = field 0
  assert wire_format.get_field_number(0) == 0
}

// Test get_wire_type function
pub fn get_wire_type_test() {
  // Tag 8 = wire type 0 (Varint)
  assert wire_format.get_wire_type(8) == Ok(wire_format.Varint)

  // Tag 18 = wire type 2 (LengthDelimited)
  assert wire_format.get_wire_type(18) == Ok(wire_format.LengthDelimited)

  // Tag 125 = wire type 5 (Fixed32)
  assert wire_format.get_wire_type(125) == Ok(wire_format.Fixed32)

  // Tag 801 = wire type 1 (Fixed64)
  assert wire_format.get_wire_type(801) == Ok(wire_format.Fixed64)
}

// Test roundtrip: make_tag then extract field number and wire type
pub fn tag_roundtrip_test() {
  let test_cases = [
    #(1, wire_format.Varint),
    #(2, wire_format.LengthDelimited),
    #(15, wire_format.Fixed32),
    #(100, wire_format.Fixed64),
    #(255, wire_format.Varint),
    #(1000, wire_format.LengthDelimited),
  ]

  test_cases
  |> list.each(fn(test_case) {
    let #(field_num, wire_type) = test_case
    let tag = wire_format.make_tag(field_num, wire_type)

    assert wire_format.get_field_number(tag) == field_num

    assert wire_format.get_wire_type(tag) == Ok(wire_type)
  })
}
