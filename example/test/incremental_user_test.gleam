import generated/proto
import gleam/bit_array
import gleam/io
import gleam/string
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

// Test building User incrementally to find the breaking point
pub fn minimal_user_test() {
  let user =
    proto.User(
      id: 1,
      name: "",
      email: "",
      created_at: proto.Timestamp(seconds: 0, nanos: 0),
      is_active: False,
      role: proto.UNKNOWN,
      tags: [],
      bio: proto.StringValue(value: ""),
    )

  let encoded = proto.encode_user(user)
  io.println(
    "Minimal user encoded length: "
    <> string.inspect(bit_array.byte_size(encoded)),
  )

  let decode_result = proto.decode_user(encoded)
  case decode_result {
    Ok(_) -> io.println("✅ Minimal user works!")
    Error(err) -> io.println("❌ Minimal user failed: " <> string.inspect(err))
  }

  decode_result |> should.be_ok()
}
