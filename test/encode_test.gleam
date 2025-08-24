import gleam/bit_array
import gleeunit
import gloto/encode
import gloto/wire

pub fn main() {
  gleeunit.main()
}

pub fn varint_test() {
  assert encode.varint(0) == <<0>>
  assert encode.varint(1) == <<1>>
  assert encode.varint(127) == <<127>>
  assert encode.varint(128) == <<128, 1>>
  assert encode.varint(300) == <<172, 2>>
  assert encode.varint(16_384) == <<128, 128, 1>>
}

pub fn fixed32_test() {
  assert encode.fixed32(0) == <<0, 0, 0, 0>>
  assert encode.fixed32(1) == <<1, 0, 0, 0>>
  assert encode.fixed32(256) == <<0, 1, 0, 0>>
  assert encode.fixed32(16_777_216) == <<0, 0, 0, 1>>
}

pub fn fixed64_test() {
  assert encode.fixed64(0) == <<0, 0, 0, 0, 0, 0, 0, 0>>
  assert encode.fixed64(1) == <<1, 0, 0, 0, 0, 0, 0, 0>>
  assert encode.fixed64(256) == <<0, 1, 0, 0, 0, 0, 0, 0>>
  assert encode.fixed64(65_536) == <<0, 0, 1, 0, 0, 0, 0, 0>>
  assert encode.fixed64(16_777_216) == <<0, 0, 0, 1, 0, 0, 0, 0>>
  assert encode.fixed64(4_294_967_296) == <<0, 0, 0, 0, 1, 0, 0, 0>>
  assert encode.fixed64(1_099_511_627_776) == <<0, 0, 0, 0, 0, 1, 0, 0>>
  assert encode.fixed64(281_474_976_710_656) == <<0, 0, 0, 0, 0, 0, 1, 0>>
  assert encode.fixed64(72_057_594_037_927_936) == <<0, 0, 0, 0, 0, 0, 0, 1>>
}

pub fn length_delimited_test() {
  assert encode.length_delimited(<<>>) == <<0>>
  assert encode.length_delimited(<<1, 2, 3>>) == <<3, 1, 2, 3>>
  assert encode.length_delimited(bit_array.from_string("hello"))
    == <<5, 104, 101, 108, 108, 111>>
}

// Test string encoding
pub fn string_test() {
  assert encode.string("") == <<0>>
  assert encode.string("hello") == <<5, 104, 101, 108, 108, 111>>
  assert encode.string("a") == <<1, 97>>
}

// Test tag encoding
pub fn tag_test() {
  assert encode.tag(1, wire.Varint) == <<8>>
  assert encode.tag(2, wire.LengthDelimited) == <<18>>
  assert encode.tag(15, wire.Fixed32) == <<125>>
}

// Test field encoding
pub fn field_test() {
  assert encode.field(1, wire.Varint, <<150, 1>>) == <<8, 150, 1>>
  assert encode.field(2, wire.LengthDelimited, <<
      5,
      104,
      101,
      108,
      108,
      111,
    >>)
    == <<18, 5, 104, 101, 108, 108, 111>>
}

// Test int32_field encoding
pub fn int32_field_test() {
  assert encode.int32_field(1, 0) == <<8, 0>>
  assert encode.int32_field(1, 150) == <<8, 150, 1>>
  assert encode.int32_field(2, 1) == <<16, 1>>
}

// Test string_field encoding
pub fn string_field_test() {
  assert encode.string_field(1, "") == <<10, 0>>
  assert encode.string_field(1, "hello") == <<10, 5, 104, 101, 108, 108, 111>>
  assert encode.string_field(2, "world") == <<18, 5, 119, 111, 114, 108, 100>>
}

// Test bool_field encoding
pub fn bool_field_test() {
  assert encode.bool_field(1, True) == <<8, 1>>
  assert encode.bool_field(1, False) == <<8, 0>>
  assert encode.bool_field(5, True) == <<40, 1>>
}

// Test float encoding
pub fn float_test() {
  assert encode.float(0.0) == <<0, 0, 0, 0>>
  assert encode.float(1.0) == <<0, 0, 128, 63>>
  assert encode.float(-1.0) == <<0, 0, 128, 191>>
}

// Test double encoding
pub fn double_test() {
  assert encode.double(0.0) == <<0, 0, 0, 0, 0, 0, 0, 0>>
  assert encode.double(1.0) == <<0, 0, 0, 0, 0, 0, 240, 63>>
  assert encode.double(-1.0) == <<0, 0, 0, 0, 0, 0, 240, 191>>
}

// Test zigzag encoding
pub fn zigzag_test() {
  assert encode.zigzag(0) == 0
  assert encode.zigzag(-1) == 1
  assert encode.zigzag(1) == 2
  assert encode.zigzag(-2) == 3
  assert encode.zigzag(2) == 4
  assert encode.zigzag(2_147_483_647) == 4_294_967_294
  assert encode.zigzag(-2_147_483_648) == 4_294_967_295
}

// Test sint32_field encoding
pub fn sint32_field_test() {
  assert encode.sint32_field(1, 0) == <<8, 0>>
  assert encode.sint32_field(1, -1) == <<8, 1>>
  assert encode.sint32_field(1, 1) == <<8, 2>>
  assert encode.sint32_field(1, -2) == <<8, 3>>
}

// Test message encoding
pub fn message_test() {
  assert encode.message([]) == <<>>
  assert encode.message([<<8, 1>>, <<16, 2>>]) == <<8, 1, 16, 2>>
  assert encode.message([<<10, 5, 104, 101, 108, 108, 111>>])
    == <<10, 5, 104, 101, 108, 108, 111>>
}

// Test varint_size function
pub fn varint_size_test() {
  assert encode.varint_size(0) == 1
  assert encode.varint_size(127) == 1
  assert encode.varint_size(128) == 2
  assert encode.varint_size(16_383) == 2
  assert encode.varint_size(16_384) == 3
  assert encode.varint_size(-1) == 10
}

// Test message_size function
pub fn message_size_test() {
  assert encode.message_size([]) == 0
  assert encode.message_size([<<1, 2, 3>>]) == 3
  assert encode.message_size([<<1, 2>>, <<3, 4, 5>>]) == 5
}

// Test bytes encoding
pub fn bytes_test() {
  assert encode.bytes(1, <<>>) == <<10, 0>>
  assert encode.bytes(1, <<1, 2, 3>>) == <<10, 3, 1, 2, 3>>
  assert encode.bytes(2, <<255>>) == <<18, 1, 255>>
}

// Test message_field encoding
pub fn message_field_test() {
  assert encode.message_field(1, <<>>) == <<10, 0>>
  assert encode.message_field(1, <<8, 1>>) == <<10, 2, 8, 1>>
  assert encode.message_field(3, <<8, 1, 16, 2>>) == <<26, 4, 8, 1, 16, 2>>
}

// Test repeated_int32_field encoding
pub fn repeated_int32_field_test() {
  assert encode.repeated_int32_field(1, []) == <<10, 0>>
  assert encode.repeated_int32_field(1, [1, 2, 3]) == <<10, 3, 1, 2, 3>>
  assert encode.repeated_int32_field(2, [150, 300]) == <<18, 4, 150, 1, 172, 2>>
}

// Test tag_size function
pub fn tag_size_test() {
  assert encode.tag_size(1) == 1
  assert encode.tag_size(15) == 1
  assert encode.tag_size(16) == 2
  assert encode.tag_size(2047) == 2
  assert encode.tag_size(2048) == 3
}
