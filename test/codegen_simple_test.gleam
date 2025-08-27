import generated/simple_scalars
import gleam/string
import gleeunit

pub fn main() {
  gleeunit.main()
}

pub fn simple_message_creation_test() {
  let msg: simple_scalars.SimpleMessage =
    simple_scalars.SimpleMessage(
      double_field: 3.14159,
      float_field: 2.718,
      int32_field: 42,
      int64_field: 1_234_567_890,
      uint32_field: 100,
      uint64_field: 999_999_999,
      sint32_field: -42,
      sint64_field: -1_234_567_890,
      bool_field: True,
      string_field: "Hello, World!",
      bytes_field: <<"binary data">>,
    )

  assert msg.double_field == 3.14159
  assert msg.string_field == "Hello, World!"
  assert msg.bool_field == True
}

pub fn simple_encode_decode_roundtrip_test() {
  let original =
    simple_scalars.SimpleMessage(
      double_field: 1.5,
      float_field: 2.5,
      int32_field: 100,
      int64_field: 200,
      uint32_field: 300,
      uint64_field: 400,
      sint32_field: -100,
      sint64_field: -200,
      bool_field: False,
      string_field: "test",
      bytes_field: <<"test bytes">>,
    )

  let encoded = simple_scalars.encode_simplemessage(original)
  let decoded = simple_scalars.decode_simplemessage(encoded)

  case decoded {
    Ok(msg) -> {
      let typed_msg: simple_scalars.SimpleMessage = msg
      assert typed_msg.double_field == 1.5
      assert typed_msg.string_field == "test"
      assert typed_msg.bool_field == False
      assert typed_msg.int32_field == 100
    }
    Error(err) -> panic as { "Decode failed: " <> string.inspect(err) }
  }
}

pub fn status_enum_test() {
  let msg: simple_scalars.StatusMessage =
    simple_scalars.StatusMessage(status: simple_scalars.ACTIVE)
  assert msg.status == simple_scalars.ACTIVE

  let encoded = simple_scalars.encode_statusmessage(msg)
  let decoded = simple_scalars.decode_statusmessage(encoded)

  case decoded {
    Ok(decoded_msg) -> {
      let typed_msg: simple_scalars.StatusMessage = decoded_msg
      assert typed_msg.status == simple_scalars.ACTIVE
    }
    Error(err) -> panic as { "Decode failed: " <> string.inspect(err) }
  }
}
