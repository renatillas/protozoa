import generated/proto
import gleam/bit_array
import gleam/int
import gleam/io
import gleam/string

pub fn main() {
  io.println("🔍 Testing timestamp encoding/decoding")

  let timestamp = proto.Timestamp(seconds: 1_640_995_200, nanos: 0)
  io.println(
    "Original: seconds="
    <> int.to_string(timestamp.seconds)
    <> ", nanos="
    <> int.to_string(timestamp.nanos),
  )

  let encoded = proto.encode_timestamp(timestamp)
  io.println(
    "Encoded length: "
    <> int.to_string(bit_array.byte_size(encoded))
    <> " bytes",
  )

  // Show hex
  io.println("Encoded as hex:")
  hex_dump(encoded)

  case proto.decode_timestamp(encoded) {
    Ok(decoded) -> {
      io.println(
        "Decoded: seconds="
        <> int.to_string(decoded.seconds)
        <> ", nanos="
        <> int.to_string(decoded.nanos),
      )
      case
        decoded.seconds == timestamp.seconds && decoded.nanos == timestamp.nanos
      {
        True -> io.println("✅ Timestamp round-trip works")
        False -> io.println("❌ Timestamp round-trip failed!")
      }
    }
    Error(err) ->
      io.println("❌ Timestamp decode error: " <> string.inspect(err))
  }
}

fn hex_dump(data: BitArray) -> Nil {
  hex_dump_helper(data, 0)
}

fn hex_dump_helper(data: BitArray, offset: Int) -> Nil {
  case data {
    <<byte:int, rest:bits>> -> {
      let hex = int.to_base16(byte)
      let padded = case string.length(hex) {
        1 -> "0" <> hex
        _ -> hex
      }
      io.print(padded <> " ")
      case int.remainder(offset + 1, 16) {
        Ok(0) -> io.println("")
        _ -> Nil
      }
      hex_dump_helper(rest, offset + 1)
    }
    <<>> -> io.println("")
    _ -> io.println("(invalid pattern)")
  }
}
