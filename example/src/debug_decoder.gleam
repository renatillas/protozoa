import generated/proto
import gleam/bit_array
import gleam/int
import gleam/io
import gleam/list
import gleam/string
import protozoa/decode

pub fn main() {
  io.println("🔍 Debug: Step-by-step decoding")

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
  io.println(
    "Encoded " <> int.to_string(bit_array.byte_size(encoded)) <> " bytes",
  )

  // Try to manually decode using the lower-level decode functions
  io.println("\nTrying to decode with raw decode functions...")

  case decode.run(encoded, test_decoder()) {
    Ok(_) -> io.println("✅ Manual decode succeeded!")
    Error(errors) -> {
      io.println("❌ Manual decode failed:")
      list.each(errors, fn(err) { io.println("  - " <> string.inspect(err)) })
    }
  }
}

fn test_decoder() -> decode.Decoder(String) {
  // Try to decode just the first field (id)
  use id <- decode.then(decode.int32_with_default(1, 0))
  io.println("Decoded field 1 (id): " <> int.to_string(id))

  // Try to decode the second field (name) 
  use name <- decode.then(decode.string_with_default(2, ""))
  io.println("Decoded field 2 (name): " <> name)

  // Try to decode the third field (email)
  use email <- decode.then(decode.string_with_default(3, ""))
  io.println("Decoded field 3 (email): " <> email)

  // Skip field 4 (timestamp) for now
  io.println("Skipping field 4 (timestamp)")

  // Try to decode boolean
  use is_active <- decode.then(decode.bool_with_default(5, False))
  io.println(
    "Decoded field 5 (is_active): "
    <> case is_active {
      True -> "true"
      False -> "false"
    },
  )

  // Try to decode the enum
  use role <- decode.then(proto.decode_userrole_field(6))
  io.println("Decoded field 6 (role): " <> string.inspect(role))

  // Try to decode tags (repeated strings)
  use tags <- decode.then(decode.repeated_string(7))
  io.println("Decoded field 7 (tags): " <> string.inspect(tags))

  // Try to decode the StringValue 
  use bio <- decode.then(decode.nested_message(8, proto.stringvalue_decoder()))
  io.println("Decoded field 8 (bio): " <> bio.value)

  decode.success("All fields decoded!")
}
