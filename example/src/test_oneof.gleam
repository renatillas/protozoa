import generated/proto
import gleam/int
import gleam/io
import gleam/option

pub fn main() {
  io.println("Testing oneof decoder fix...")

  // Test text data variant
  let text_message =
    proto.SimpleMessage(
      id: "test1",
      description: "Text test",
      enabled: True,
      data: option.Some(proto.TextData("Hello")),
    )

  let encoded = proto.encode_simplemessage(text_message)
  case proto.decode_simplemessage(encoded) {
    Ok(decoded) -> {
      io.println("✅ Text variant decoded successfully")
      case decoded.data {
        option.Some(proto.TextData(value)) ->
          io.println("   Text value: " <> value)
        _ -> io.println("❌ Wrong data type decoded")
      }
    }
    Error(_) -> {
      io.println("❌ Text variant decode failed")
      io.println("Error details omitted")
    }
  }

  // Test numeric data variant
  let numeric_message =
    proto.SimpleMessage(
      id: "test2",
      description: "Numeric test",
      enabled: False,
      data: option.Some(proto.NumericData(12_345)),
    )

  let encoded2 = proto.encode_simplemessage(numeric_message)
  case proto.decode_simplemessage(encoded2) {
    Ok(decoded) -> {
      io.println("✅ Numeric variant decoded successfully")
      case decoded.data {
        option.Some(proto.NumericData(value)) ->
          io.println("   Numeric value: " <> int.to_string(value))
        _ -> io.println("❌ Wrong data type decoded")
      }
    }
    Error(_) -> {
      io.println("❌ Numeric variant decode failed")
      io.println("Error details omitted")
    }
  }

  io.println("✅ Oneof decoder test completed!")
}
