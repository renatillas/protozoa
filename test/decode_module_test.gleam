import gleam/bit_array
import gleam/float
import gleam/order
import gleeunit
import gloto/decode
import gloto/encode

pub fn main() {
  gleeunit.main()
}

pub fn success_decoder_test() {
  let decoder_int = decode.success(42)
  let decoder_string = decode.success("hello")

  assert decode.decode(<<>>, with: decoder_int) == Ok(42)
  assert decode.decode(<<>>, with: decoder_string) == Ok("hello")
}

pub fn fail_decoder_test() {
  let decoder = decode.fail("Test error")

  assert Error(decode.DecodeError("Test error"))
    == decode.decode(<<>>, with: decoder)
}

pub fn int32_decoder_test() {
  let encoded = encode.int32_field(1, 42)
  let good_decoder = decode.int32(1)
  let bad_decoder = decode.int32(2)

  assert decode.decode(encoded, good_decoder) == Ok(42)
  assert Error(decode.FieldNotFound(2)) == decode.decode(encoded, bad_decoder)
}

pub fn int32_with_default_decoder_test() {
  let encoded = encode.int32_field(1, 42)
  let decoder_correct = decode.int32_with_default(1, 0)
  let decoder_default = decode.int32_with_default(2, 99)
  let decoder_empty = decode.int32_with_default(1, 77)

  assert decode.decode(encoded, decoder_correct) == Ok(42)
  assert decode.decode(encoded, decoder_default) == Ok(99)
  assert decode.decode(<<>>, decoder_empty) == Ok(77)
}

pub fn string_decoder_test() {
  let encoded = encode.string_field(1, "hello")
  let encoded_empty = encode.string_field(2, "")
  let decoder_correct = decode.string(1)
  let decoder_default = decode.string(2)

  assert decode.decode(encoded, decoder_correct) == Ok("hello")
  assert decode.decode(encoded_empty, decoder_default) == Ok("")
}

pub fn string_with_default_decoder_test() {
  let encoded = encode.string_field(1, "hello")
  let decoder_correct = decode.string_with_default(1, "default")
  let decoder_default = decode.string_with_default(2, "default")

  assert decode.decode(encoded, decoder_correct) == Ok("hello")
  assert decode.decode(encoded, decoder_default) == Ok("default")
}

pub fn bool_decoder_test() {
  let encoded_true = encode.bool_field(1, True)
  let encoded_false = encode.bool_field(1, False)

  let decoder = decode.bool(1)

  assert decode.decode(encoded_true, decoder) == Ok(True)
  assert decode.decode(encoded_false, decoder) == Ok(False)
}

pub fn bool_with_default_decoder_test() {
  let encoded = encode.bool_field(1, True)
  let decoder_correct = decode.bool_with_default(1, False)
  let decoder_default = decode.bool_with_default(2, True)

  assert decode.decode(encoded, decoder_correct) == Ok(True)

  assert decode.decode(encoded, decoder_default) == Ok(True)
}

pub fn bytes_decoder_test() {
  let encoded = encode.bytes(1, <<1, 2, 3, 4, 5>>)
  let encoded_empty = encode.bytes(2, <<>>)
  let decoder = decode.bytes(1)
  let decoder_empty = decode.bytes(2)

  assert decode.decode(encoded, decoder) == Ok(<<1, 2, 3, 4, 5>>)
  assert decode.decode(encoded_empty, decoder_empty) == Ok(<<>>)
}

pub fn float_decoder_test() {
  let encoded = encode.float_field(1, 3.14)
  let decoder = decode.float(1)

  let assert Ok(value) = decode.decode(encoded, decoder)
  assert float.loosely_compare(value, 3.14, 0.01) == order.Eq
}

pub fn double_decoder_test() {
  let encoded = encode.double_field(1, 3.14159)
  let decoder = decode.double(1)

  let assert Ok(value) = decode.decode(encoded, decoder)
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

  assert decode.decode(encoded, decoder) == Ok([10, 20, 30])
  assert decode.decode(encoded, decoder_no_fields) == Ok([])
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

  assert decode.decode(encoded, decoder) == Ok(["hello", "world", "!"])
  assert decode.decode(encoded, decoder_no_fields) == Ok([])
}

pub fn sint32_decoder_test() {
  let encoded1 = encode.sint32_field(1, 0)
  let encoded2 = encode.sint32_field(1, -1)
  let encoded3 = encode.sint32_field(1, 1)
  let encoded4 = encode.sint32_field(1, -2)
  let decoder = decode.sint32(1)

  assert decode.decode(encoded1, decoder) == Ok(0)
  assert decode.decode(encoded2, decoder) == Ok(-1)
  assert decode.decode(encoded3, decoder) == Ok(1)
  assert decode.decode(encoded4, decoder) == Ok(-2)
}

pub fn sint64_decoder_test() {
  let encoded1 = encode.sint64_field(1, 0)
  let encoded2 = encode.sint64_field(1, -1)
  let encoded3 = encode.sint64_field(1, 1)
  let encoded4 = encode.sint64_field(1, -100)
  let decoder = decode.sint64(1)

  assert decode.decode(encoded1, decoder) == Ok(0)
  assert decode.decode(encoded2, decoder) == Ok(-1)
  assert decode.decode(encoded3, decoder) == Ok(1)
  assert decode.decode(encoded4, decoder) == Ok(-100)
}

pub fn subrecord_decoder_test() {
  let encoded =
    bit_array.concat([
      encode.string_field(1, "Alice"),
      encode.int32_field(2, 30),
      encode.bool_field(3, True),
    ])

  let decoder = {
    use name <- decode.subrecord(decode.string(1))
    use age <- decode.subrecord(decode.int32(2))
    use active <- decode.subrecord(decode.bool(3))
    decode.success(#(name, age, active))
  }

  assert decode.decode(encoded, decoder) == Ok(#("Alice", 30, True))
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
