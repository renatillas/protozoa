import generated/basic_types
import gleam/string
import gleeunit/should

pub fn scalar_message_creation_test() {
  // Test creating a scalar message with all field types
  let msg: basic_types.ScalarMessage =
    basic_types.ScalarMessage(
      double_field: 3.14159,
      float_field: 2.718,
      int32_field: 42,
      int64_field: 1_234_567_890,
      uint32_field: 100,
      uint64_field: 999_999_999,
      sint32_field: -42,
      sint64_field: -1_234_567_890,
      fixed32_field: 123_456,
      fixed64_field: 987_654_321,
      sfixed32_field: -123_456,
      sfixed64_field: -987_654_321,
      bool_field: True,
      string_field: "Hello, World!",
      bytes_field: <<"binary data">>,
    )

  // Verify fields are accessible
  msg.double_field |> should.equal(3.14159)
  msg.string_field |> should.equal("Hello, World!")
  msg.bool_field |> should.equal(True)
}

pub fn enum_creation_test() {
  let msg: basic_types.EnumMessage =
    basic_types.EnumMessage(color: basic_types.RED)
  msg.color |> should.equal(basic_types.RED)
}

pub fn encode_decode_roundtrip_test() {
  let original =
    basic_types.ScalarMessage(
      double_field: 1.5,
      float_field: 2.5,
      int32_field: 100,
      int64_field: 200,
      uint32_field: 300,
      uint64_field: 400,
      sint32_field: -100,
      sint64_field: -200,
      fixed32_field: 500,
      fixed64_field: 600,
      sfixed32_field: -500,
      sfixed64_field: -600,
      bool_field: False,
      string_field: "test",
      bytes_field: <<"test bytes">>,
    )

  // Encode the message
  let encoded = basic_types.encode_scalarmessage(original)

  // Decode it back
  let decoded = basic_types.decode_scalarmessage(encoded)

  // Should succeed and match original
  case decoded {
    Ok(msg) -> {
      let typed_msg: basic_types.ScalarMessage = msg
      typed_msg.double_field |> should.equal(1.5)
      typed_msg.string_field |> should.equal("test")
      typed_msg.bool_field |> should.equal(False)
      typed_msg.int32_field |> should.equal(100)
    }
    Error(err) -> panic as { "Decode failed: " <> string.inspect(err) }
  }
}

pub fn enum_encode_decode_test() {
  let original = basic_types.EnumMessage(color: basic_types.BLUE)

  let encoded = basic_types.encode_enummessage(original)
  let decoded = basic_types.decode_enummessage(encoded)

  case decoded {
    Ok(msg) -> {
      let typed_msg: basic_types.EnumMessage = msg
      typed_msg.color |> should.equal(basic_types.BLUE)
    }
    Error(err) -> panic as { "Decode failed: " <> string.inspect(err) }
  }
}
