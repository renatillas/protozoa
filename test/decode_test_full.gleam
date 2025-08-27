import gleam/bit_array
import gleam/dict
import gleam/float
import gleam/list
import gleam/order
import gleam/result
import gleeunit
import protozoa/decode
import protozoa/encode

pub fn main() {
  gleeunit.main()
}

pub fn success_decoder_test() {
  let decoder_int = decode.success(42)
  let decoder_string = decode.success("hello")

  assert decode.run(<<>>, with: decoder_int) == Ok(42)
  assert decode.run(<<>>, with: decoder_string) == Ok("hello")
}

pub fn fail_decoder_test() {
  let decoder = decode.fail("expected", "found", [])

  assert Error([decode.DecodeError("expected", "found", [])])
    == decode.run(<<>>, with: decoder)
}

pub fn int32_decoder_test() {
  let encoded = encode.int32_field(1, 42)
  let good_decoder = decode.int32(1)
  let bad_decoder = decode.int32(2)

  assert decode.run(encoded, with: good_decoder) == Ok(42)
  assert Error([decode.FieldNotFound(2)])
    == decode.run(encoded, with: bad_decoder)
}

pub fn int32_with_default_decoder_test() {
  let encoded = encode.int32_field(1, 42)
  let decoder_correct = decode.int32_with_default(1, 0)
  let decoder_default = decode.int32_with_default(2, 99)
  let decoder_empty = decode.int32_with_default(1, 77)

  assert decode.run(encoded, with: decoder_correct) == Ok(42)
  assert decode.run(encoded, with: decoder_default) == Ok(99)
  assert decode.run(<<>>, with: decoder_empty) == Ok(77)
}

pub fn string_decoder_test() {
  let encoded = encode.string_field(1, "hello")
  let encoded_empty = encode.string_field(2, "")
  let decoder_correct = decode.string(1)
  let decoder_default = decode.string(2)

  assert decode.run(encoded, with: decoder_correct) == Ok("hello")
  assert decode.run(encoded_empty, with: decoder_default) == Ok("")
}

pub fn string_with_default_decoder_test() {
  let encoded = encode.string_field(1, "hello")
  let decoder_correct = decode.string_with_default(1, "default")
  let decoder_default = decode.string_with_default(2, "default")

  assert decode.run(encoded, with: decoder_correct) == Ok("hello")
  assert decode.run(encoded, with: decoder_default) == Ok("default")
}

pub fn bool_decoder_test() {
  let encoded_true = encode.bool_field(1, True)
  let encoded_false = encode.bool_field(1, False)

  let decoder = decode.bool(1)

  assert decode.run(encoded_true, with: decoder) == Ok(True)
  assert decode.run(encoded_false, with: decoder) == Ok(False)
}

pub fn bool_with_default_decoder_test() {
  let encoded = encode.bool_field(1, True)
  let decoder_correct = decode.bool_with_default(1, False)
  let decoder_default = decode.bool_with_default(2, True)

  assert decode.run(encoded, with: decoder_correct) == Ok(True)

  assert decode.run(encoded, with: decoder_default) == Ok(True)
}

pub fn bytes_decoder_test() {
  let encoded = encode.bytes(1, <<1, 2, 3, 4, 5>>)
  let encoded_empty = encode.bytes(2, <<>>)
  let decoder = decode.bytes(1)
  let decoder_empty = decode.bytes(2)

  assert decode.run(encoded, with: decoder) == Ok(<<1, 2, 3, 4, 5>>)
  assert decode.run(encoded_empty, with: decoder_empty) == Ok(<<>>)
}

pub fn float_decoder_test() {
  let encoded = encode.float_field(1, 3.14)
  let decoder = decode.float(1)

  let assert Ok(value) = decode.run(encoded, with: decoder)
  assert float.loosely_compare(value, 3.14, 0.01) == order.Eq
}

pub fn double_decoder_test() {
  let encoded = encode.double_field(1, 3.14159)
  let decoder = decode.double(1)

  let assert Ok(value) = decode.run(encoded, with: decoder)
  assert float.loosely_compare(value, 3.14159, 0.00001) == order.Eq
}

pub fn repeated_int32_decoder_test() {
  let encoded =
    bit_array.concat([
      encode.int32_field(1, 10),
      encode.int32_field(1, 20),
      encode.int32_field(1, 30),
    ])
  let decoder = decode.repeated_int32(1)
  let decoder_no_fields = decode.repeated_int32(2)

  assert decode.run(encoded, with: decoder) == Ok([10, 20, 30])
  assert decode.run(encoded, decoder_no_fields) == Ok([])
}

pub fn repeated_string_decoder_test() {
  let encoded =
    bit_array.concat([
      encode.string_field(1, "hello"),
      encode.string_field(1, "world"),
      encode.string_field(1, "!"),
    ])
  let decoder = decode.repeated_string(1)
  let decoder_no_fields = decode.repeated_string(2)

  assert decode.run(encoded, with: decoder) == Ok(["hello", "world", "!"])
  assert decode.run(encoded, decoder_no_fields) == Ok([])
}

pub fn sint32_decoder_test() {
  let encoded1 = encode.sint32_field(1, 0)
  let encoded2 = encode.sint32_field(1, -1)
  let encoded3 = encode.sint32_field(1, 1)
  let encoded4 = encode.sint32_field(1, -2)
  let decoder = decode.sint32(1)

  assert decode.run(encoded1, decoder) == Ok(0)
  assert decode.run(encoded2, decoder) == Ok(-1)
  assert decode.run(encoded3, decoder) == Ok(1)
  assert decode.run(encoded4, decoder) == Ok(-2)
}

pub fn sint64_decoder_test() {
  let encoded1 = encode.sint64_field(1, 0)
  let encoded2 = encode.sint64_field(1, -1)
  let encoded3 = encode.sint64_field(1, 1)
  let encoded4 = encode.sint64_field(1, -100)
  let decoder = decode.sint64(1)

  assert decode.run(encoded1, decoder) == Ok(0)
  assert decode.run(encoded2, decoder) == Ok(-1)
  assert decode.run(encoded3, decoder) == Ok(1)
  assert decode.run(encoded4, decoder) == Ok(-100)
}

pub fn subrecord_decoder_test() {
  let encoded =
    bit_array.concat([
      encode.string_field(1, "Alice"),
      encode.int32_field(2, 30),
      encode.bool_field(3, True),
    ])

  let decoder = {
    use name <- decode.then(decode.string(1))
    use age <- decode.then(decode.int32(2))
    use active <- decode.then(decode.bool(3))
    decode.success(#(name, age, active))
  }

  assert decode.run(encoded, with: decoder) == Ok(#("Alice", 30, True))
}

pub fn decode_zigzag_test() {
  assert decode.decode_zigzag(0) == 0
  assert decode.decode_zigzag(1) == -1
  assert decode.decode_zigzag(2) == 1
  assert decode.decode_zigzag(3) == -2
  assert decode.decode_zigzag(4) == 2
  assert decode.decode_zigzag(4_294_967_294) == 2_147_483_647
  assert decode.decode_zigzag(4_294_967_295) == -2_147_483_648
}

// Decoder failure tests - testing all error conditions

pub fn invalid_wire_type_test() {
  // Create data with string in field 1, try to decode as int32 (varint)
  let string_encoded = encode.string_field(1, "hello")
  let int_decoder = decode.int32(1)

  let assert Error([
    decode.DecodeError("varint wire type", "non-varint wire type", []),
  ]) = decode.run(string_encoded, with: int_decoder)
}

pub fn invalid_wire_type_for_string_test() {
  // Create data with int32 in field 1, try to decode as string (length-delimited)
  let int_encoded = encode.int32_field(1, 42)
  let string_decoder = decode.string(1)

  let assert Error([
    decode.DecodeError(
      "length-delimited wire type",
      "non-length-delimited wire type",
      [],
    ),
  ]) = decode.run(int_encoded, with: string_decoder)
}

pub fn invalid_wire_type_for_bytes_test() {
  // Create data with int32 in field 1, try to decode as bytes (length-delimited)
  let int_encoded = encode.int32_field(1, 42)
  let bytes_decoder = decode.bytes(1)

  let assert Error([
    decode.DecodeError(
      "length-delimited wire type",
      "non-length-delimited wire type",
      [],
    ),
  ]) = decode.run(int_encoded, with: bytes_decoder)
}

pub fn invalid_wire_type_for_float_test() {
  // Create data with int32 in field 1, try to decode as float (fixed32)
  let int_encoded = encode.int32_field(1, 42)
  let float_decoder = decode.float(1)

  let assert Error([
    decode.DecodeError("fixed32 wire type", "non-fixed32 wire type", []),
  ]) = decode.run(int_encoded, with: float_decoder)
}

pub fn invalid_wire_type_for_double_test() {
  // Create data with int32 in field 1, try to decode as double (fixed64)
  let int_encoded = encode.int32_field(1, 42)
  let double_decoder = decode.double(1)

  let assert Error([
    decode.DecodeError("fixed64 wire type", "non-fixed64 wire type", []),
  ]) = decode.run(int_encoded, with: double_decoder)
}

pub fn invalid_utf8_string_test() {
  // Create invalid UTF-8 bytes manually and try to decode as string
  // Invalid UTF-8: 0xFF is not valid UTF-8
  let invalid_utf8_data = <<
    10:int,
    // Tag: field 1, wire type 2 (0x08 | 0x02 = 10)
    0x01:int,
    // Length: 1 byte
    0xFF:int,
    // Invalid UTF-8 byte
  >>
  let string_decoder = decode.string(1)

  let assert Error([
    decode.DecodeError("valid UTF-8 string", "invalid UTF-8 bytes", []),
  ]) = decode.run(invalid_utf8_data, with: string_decoder)
}

pub fn insufficient_data_for_fixed32_test() {
  // Create data with not enough bytes for fixed32
  let insufficient_data = <<
    // Field 1, wire type 5 (fixed32)
    13:int,
    // Tag: field 1, wire type 5 (0x08 | 0x05 = 13)
    0x01:int,
    // Only 1 byte instead of 4
    0x42:int,
  >>
  let fixed32_decoder = decode.fixed32(1)

  let assert Error([
    decode.DecodeError("4 bytes for fixed32", "insufficient data", []),
  ]) = decode.run(insufficient_data, with: fixed32_decoder)
}

pub fn insufficient_data_for_fixed64_test() {
  // Create data with not enough bytes for fixed64
  let insufficient_data = <<
    // Field 1, wire type 1 (fixed64)
    9:int,
    // Tag: field 1, wire type 1 (0x08 | 0x01 = 9)
    0x01:int,
    0x02:int,
    0x03:int,
    0x04:int,
    // Only 4 bytes instead of 8
  >>
  let fixed64_decoder = decode.fixed64(1)

  let assert Error([
    decode.DecodeError("8 bytes for fixed64", "insufficient data", []),
  ]) = decode.run(insufficient_data, with: fixed64_decoder)
}

pub fn insufficient_data_for_length_delimited_test() {
  // Create length-delimited data that claims more bytes than available
  let insufficient_data = <<
    // Field 1, wire type 2 (length-delimited)
    10:int,
    // Tag: field 1, wire type 2 (0x08 | 0x02 = 10)
    0x05:int,
    // Claims 5 bytes
    0x01:int,
    0x02:int,
    // But only has 2 bytes
  >>
  let string_decoder = decode.string(1)

  let assert Error([
    decode.DecodeError(
      "sufficient bytes for length-delimited field",
      "insufficient data",
      [],
    ),
  ]) = decode.run(insufficient_data, with: string_decoder)
}

pub fn malformed_varint_test() {
  // Create a varint that never terminates (all bytes have continuation bit set)
  let malformed_varint = <<
    0x08:int,
    // Field 1, wire type 0 (varint)
    0xFF:int,
    0xFF:int,
    0xFF:int,
    0xFF:int,
    0xFF:int,
    0xFF:int,
    0xFF:int,
    0xFF:int,
    0xFF:int,
    0xFF:int,
    // 10 bytes, all with continuation bit
  >>
  let int_decoder = decode.int32(1)

  // This should eventually fail due to unexpected end of data or hitting limits
  let assert Error([_]) = decode.run(malformed_varint, with: int_decoder)
}

pub fn empty_data_varint_test() {
  // Try to decode from completely empty data
  let empty_data = <<>>
  let int_decoder = decode.int32(1)

  let assert Error([decode.FieldNotFound(1)]) =
    decode.run(empty_data, with: int_decoder)
}

pub fn invalid_float_data_test() {
  // Create fixed32 data with insufficient bytes for float
  let invalid_float_data = <<
    // Field 1, wire type 5 (fixed32)
    13:int,
    // Tag: field 1, wire type 5 (0x08 | 0x05 = 13)
    0x01:int,
    0x02:int,
    // Only 2 bytes instead of 4
  >>
  let float_decoder = decode.float(1)

  let assert Error([
    decode.DecodeError("4 bytes for fixed32", "insufficient data", []),
  ]) = decode.run(invalid_float_data, with: float_decoder)
}

pub fn invalid_double_data_test() {
  // Create fixed64 data with insufficient bytes for double
  let invalid_double_data = <<
    // Field 1, wire type 1 (fixed64)
    9:int,
    // Tag: field 1, wire type 1 (0x08 | 0x01 = 9)
    0x01:int,
    0x02:int,
    0x03:int,
    0x04:int,
    // Only 4 bytes instead of 8
  >>
  let double_decoder = decode.double(1)

  let assert Error([
    decode.DecodeError("8 bytes for fixed64", "insufficient data", []),
  ]) = decode.run(invalid_double_data, with: double_decoder)
}

pub fn missing_required_field_test() {
  // Try to decode field 1 when data only has field 2
  let encoded = encode.int32_field(2, 42)
  let decoder = decode.int32(1)

  let assert Error([decode.FieldNotFound(1)]) = decode.run(encoded, decoder)
}

pub fn repeated_field_with_errors_test() {
  // Create repeated field data where some fields have wrong wire types
  let mixed_data =
    bit_array.concat([
      encode.int32_field(1, 42),
      // Valid int32
      encode.string_field(1, "hello"),
      // Invalid wire type for int32 decoder
      encode.int32_field(1, 24),
      // Valid int32 again
    ])
  let repeated_decoder = decode.repeated_field(1, decode.varint_field)

  // Should return errors for the invalid wire types
  let assert Error(errors) = decode.run(mixed_data, with: repeated_decoder)

  // Should have at least one error for the string field
  assert list.length(errors) >= 1
}

pub fn subrecord_error_propagation_test() {
  // Test that errors in subrecord decoders are properly propagated
  let encoded = encode.string_field(1, "hello")
  // Only has field 1

  let decoder = {
    use name <- decode.then(decode.string(1))
    // This will succeed
    use age <- decode.then(decode.int32(2))
    // This will fail (field not found)
    decode.success(#(name, age))
  }

  let assert Error([decode.FieldNotFound(2)]) = decode.run(encoded, decoder)
}

pub fn invalid_wire_type_in_tag_test() {
  // Create data with invalid wire type in tag
  let invalid_tag_data = <<
    14:int,
    // Tag with invalid wire type 6 (0x08 | 0x06 = 14) (only 0-5 are valid)
    0x42:int,
  >>
  let decoder = decode.int32(1)

  let assert Error([
    decode.DecodeError("valid wire type", "invalid wire type", []),
  ]) = decode.run(invalid_tag_data, with: decoder)
}

pub fn nested_message_decode_error_test() {
  // Create a nested message with invalid inner content
  let invalid_inner_message = <<0xFF:int>>
  // Invalid varint (no terminating byte)

  let nested_data =
    bit_array.concat([
      <<10:int>>,
      // Field 1, wire type 2 (0x08 | 0x02 = 10)
      <<bit_array.byte_size(invalid_inner_message):int>>,
      invalid_inner_message,
    ])

  let inner_decoder = decode.int32(1)
  // Expect field 1 in inner message
  let outer_decoder = decode.nested_message(1, inner_decoder)

  let assert Error([_]) = decode.run(nested_data, with: outer_decoder)
}

pub fn sfixed32_invalid_wire_type_test() {
  let int_encoded = encode.int32_field(1, 42)
  // Wrong wire type
  let sfixed32_decoder = decode.sfixed32(1)

  let assert Error([
    decode.DecodeError("fixed32 wire type", "non-fixed32 wire type", []),
  ]) = decode.run(int_encoded, with: sfixed32_decoder)
}

pub fn sfixed64_invalid_wire_type_test() {
  let int_encoded = encode.int32_field(1, 42)
  // Wrong wire type  
  let sfixed64_decoder = decode.sfixed64(1)

  let assert Error([
    decode.DecodeError("fixed64 wire type", "non-fixed64 wire type", []),
  ]) = decode.run(int_encoded, with: sfixed64_decoder)
}

pub fn invalid_sfixed32_data_test() {
  // Create sfixed32 data with insufficient bytes
  let insufficient_data = <<
    13:int,
    // Tag: field 1, wire type 5 (fixed32)
    0x01:int,
    0x02:int,
    // Only 2 bytes instead of 4
  >>
  let sfixed32_decoder = decode.sfixed32(1)

  let assert Error([
    decode.DecodeError("4 bytes for fixed32", "insufficient data", []),
  ]) = decode.run(insufficient_data, with: sfixed32_decoder)
}

pub fn invalid_sfixed64_data_test() {
  // Create sfixed64 data with insufficient bytes
  let insufficient_data = <<
    9:int,
    // Tag: field 1, wire type 1 (fixed64)
    0x01:int,
    0x02:int,
    0x03:int,
    0x04:int,
    // Only 4 bytes instead of 8
  >>
  let sfixed64_decoder = decode.sfixed64(1)

  let assert Error([
    decode.DecodeError("8 bytes for fixed64", "insufficient data", []),
  ]) = decode.run(insufficient_data, with: sfixed64_decoder)
}

pub fn optional_field_with_invalid_data_test() {
  // Test optional field decoder with invalid data (wrong wire type)
  let string_encoded = encode.string_field(1, "hello")
  let optional_int_decoder = decode.optional_field(1, decode.varint_field)

  // Should return Ok(Error(Nil)) for invalid data in optional field
  let assert Ok(Error(Nil)) =
    decode.run(string_encoded, with: optional_int_decoder)
}

pub fn field_with_default_invalid_data_test() {
  // Test field_with_default decoder with invalid data (wrong wire type)
  let string_encoded = encode.string_field(1, "hello")
  let int_with_default_decoder =
    decode.field_with_default(1, decode.varint_field, 42)

  // Should return default value when field has invalid data
  let assert Ok(42) = decode.run(string_encoded, with: int_with_default_decoder)
}

pub fn map_decoder_transforms_result_test() {
  // Test that map decoder properly transforms successful results
  let encoded = encode.int32_field(1, 21)
  let double_decoder = decode.int32(1) |> decode.map(fn(x) { x * 2 })

  let assert Ok(42) = decode.run(encoded, double_decoder)
}

pub fn map_decoder_preserves_errors_test() {
  // Test that map decoder preserves errors from the underlying decoder
  let string_encoded = encode.string_field(1, "hello")
  let mapped_decoder = decode.int32(1) |> decode.map(fn(x) { x * 2 })

  let assert Error([
    decode.DecodeError("varint wire type", "non-varint wire type", []),
  ]) = decode.run(string_encoded, with: mapped_decoder)
}

pub fn from_field_dict_custom_decoder_test() {
  // Test custom decoder using from_field_dict
  let encoded =
    bit_array.concat([encode.int32_field(1, 10), encode.int32_field(2, 20)])

  let sum_decoder =
    decode.from_field_dict(fn(fields) {
      use field1 <- result.try(
        dict.get(fields, 1)
        |> result.replace_error([decode.FieldNotFound(1)])
        |> result.try(fn(field_list) {
          case field_list {
            [field, ..] ->
              decode.varint_field(field) |> result.map_error(fn(err) { [err] })
            [] -> Error([decode.FieldNotFound(1)])
          }
        }),
      )
      use field2 <- result.try(
        dict.get(fields, 2)
        |> result.replace_error([decode.FieldNotFound(2)])
        |> result.try(fn(field_list) {
          case field_list {
            [field, ..] ->
              decode.varint_field(field) |> result.map_error(fn(err) { [err] })
            [] -> Error([decode.FieldNotFound(2)])
          }
        }),
      )
      Ok(field1 + field2)
    })

  let assert Ok(30) = decode.run(encoded, sum_decoder)
}

pub fn unsupported_wire_type_in_decode_field_test() {
  // This tests the case where wire.get_wire_type returns an unsupported wire type
  // Wire type 3 and 4 are not supported in proto3
  let unsupported_wire_type_data = <<
    11:int,
    // Tag: field 1, wire type 3 (start group - unsupported)
    0x42:int,
  >>
  let decoder = decode.int32(1)

  let assert Error([
    decode.DecodeError("supported wire type", "unsupported wire type", []),
  ]) = decode.run(unsupported_wire_type_data, with: decoder)
}
