import gleam/int
import gleam/io
import gleam/string

pub fn main() {
  io.println("🔍 Testing varint decoding")

  // Test the specific varint that's failing: 1640995200
  // This should be encoded as: 80 B3 BE 8E 06
  let varint_bytes = <<0x80, 0xB3, 0xBE, 0x8E, 0x06>>

  io.println("Testing varint: 80 B3 BE 8E 06 (should be 1640995200)")

  case decode_varint_raw_test(varint_bytes) {
    Ok(#(value, _rest)) -> {
      io.println("Decoded value: " <> int.to_string(value))
      io.println("Expected:      1640995200")
      case value == 1_640_995_200 {
        True -> io.println("✅ Varint decoding works correctly")
        False -> io.println("❌ Varint decoding is broken!")
      }
    }
    Error(err) -> io.println("❌ Varint decode error: " <> string.inspect(err))
  }
}

// Copy the varint decoding logic to test it
fn decode_varint_raw_test(data: BitArray) -> Result(#(Int, BitArray), String) {
  decode_varint_helper_test(data, 0, 0)
}

fn decode_varint_helper_test(
  data: BitArray,
  value: Int,
  shift: Int,
) -> Result(#(Int, BitArray), String) {
  case data {
    <<>> -> Error("unexpected end of data")
    <<byte:int, rest:bits>> -> {
      let new_value =
        value
        |> int.bitwise_or(
          int.bitwise_and(byte, 0x7F)
          |> int.bitwise_shift_left(shift),
        )
      case int.bitwise_and(byte, 0x80) {
        0 -> Ok(#(new_value, rest))
        _ -> decode_varint_helper_test(rest, new_value, shift + 7)
      }
    }
    _ -> Error("invalid varint data")
  }
}
