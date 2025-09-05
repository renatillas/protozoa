import generated/proto
import gleam/bit_array
import gleam/int
import gleam/io
import gleam/string

pub fn main() {
  io.println("🔍 Debug: Analyzing encoded User message")

  let user =
    proto.User(
      id: 42,
      name: "Test",
      email: "test@example.com",
      created_at: proto.Timestamp(seconds: 1_640_995_200, nanos: 0),
      is_active: True,
      role: proto.ADMIN,
      tags: [],
      bio: proto.StringValue(value: "Bio"),
    )

  let encoded = proto.encode_user(user)

  io.println("Encoded length: " <> int.to_string(bit_array.byte_size(encoded)))

  // Convert to list of bytes for inspection
  case bit_array.to_string(encoded) {
    Ok(_) -> io.println("Contains valid UTF-8")
    Error(_) -> io.println("Contains binary data (expected)")
  }

  // Let's examine all the bytes
  io.println("All bytes as hex:")
  hex_dump(encoded)

  // Test individual field encodings
  io.println("\nTesting individual field encodings:")

  // Let's analyze what the User encoder creates
  io.println("User encoding contains these field numbers: 1,2,3,4,5,6,8")
  io.println(
    "Expected wire types: Varint,String,String,LengthDelimited,Bool,Varint,LengthDelimited",
  )
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
