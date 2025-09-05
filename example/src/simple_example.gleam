// Simple example demonstrating basic Protozoa functionality
import generated/proto
import gleam/bit_array
import gleam/int
import gleam/io
import gleam/option
import gleam/string

pub fn main() {
  io.println("🚀 Protozoa Simple Example")
  io.println("=========================")

  // Create a user with all non-default values
  let user =
    proto.User(
      id: 42,
      name: "Alice",
      email: "alice@example.com",
      created_at: proto.Timestamp(seconds: 1_640_995_200, nanos: 123_456),
      is_active: True,
      role: proto.ADMIN,
      tags: ["developer", "admin"],
      bio: proto.StringValue(value: "Senior developer"),
    )

  io.println("👤 Created user: " <> user.name <> " (" <> user.email <> ")")

  // First, let's test individual components to isolate the issue
  io.println("🔍 Testing individual components...")

  // Test Timestamp alone
  let timestamp = proto.Timestamp(seconds: 0, nanos: 0)
  let timestamp_encoded = proto.encode_timestamp(timestamp)
  case proto.decode_timestamp(timestamp_encoded) {
    Ok(_) -> io.println("✅ Timestamp works")
    Error(err) -> io.println("❌ Timestamp failed: " <> string.inspect(err))
  }

  // Test StringValue alone
  let stringvalue = proto.StringValue(value: "")
  let stringvalue_encoded = proto.encode_stringvalue(stringvalue)
  case proto.decode_stringvalue(stringvalue_encoded) {
    Ok(_) -> io.println("✅ StringValue works")
    Error(err) -> io.println("❌ StringValue failed: " <> string.inspect(err))
  }

  // Now try the full User
  let encoded = proto.encode_user(user)
  io.println("📦 Encoded user data successfully")
  io.println(
    "   Encoded bytes length: " <> string.inspect(bit_array.byte_size(encoded)),
  )

  // Decode the user back
  case proto.decode_user(encoded) {
    Ok(decoded_user) -> {
      io.println("✅ Successfully decoded user: " <> decoded_user.name)
      io.println(
        "   ID: "
        <> case decoded_user.id {
          id -> int.to_string(id)
        },
      )
      io.println(
        "   Active: "
        <> case decoded_user.is_active {
          True -> "Yes"
          False -> "No"
        },
      )
    }
    Error(error) ->
      io.println("❌ Failed to decode user: " <> string.inspect(error))
  }

  // Test simple message with oneof
  let message =
    proto.SimpleMessage(
      id: "msg_001",
      description: "Test message",
      enabled: True,
      data: option.Some(proto.TextData("Hello, World!")),
    )

  io.println("\n💬 Created simple message: " <> message.id)

  // Encode and decode the message
  let encoded_msg = proto.encode_simplemessage(message)
  case proto.decode_simplemessage(encoded_msg) {
    Ok(decoded_msg) -> {
      io.println("✅ Successfully decoded message: " <> decoded_msg.id)
      case decoded_msg.data {
        option.Some(proto.TextData(text)) ->
          io.println("   Text data: " <> text)
        option.Some(proto.NumericData(num)) ->
          io.println("   Numeric data: " <> int.to_string(num))
        option.Some(proto.BinaryData(_)) -> io.println("   Binary data")
        option.None -> io.println("   No data")
      }
    }
    Error(_) -> io.println("❌ Failed to decode message")
  }

  io.println("\n✅ Simple example completed!")
}
