import generated/oneofs_only
import gleam/option
import gleam/string
import gleeunit

pub fn main() {
  gleeunit.main()
}

pub fn oneof_string_value_test() {
  let msg =
    oneofs_only.SimpleOneof(
      common_field: "shared",
      value: option.Some(oneofs_only.StringValue("hello")),
    )

  assert msg.common_field == "shared"
  case msg.value {
    option.Some(oneofs_only.StringValue(s)) -> {
      assert s == "hello"
    }
    _ -> panic as "Expected string value"
  }
}

pub fn oneof_int_value_test() {
  let msg =
    oneofs_only.SimpleOneof(
      common_field: "shared",
      value: option.Some(oneofs_only.IntValue(42)),
    )

  case msg.value {
    option.Some(oneofs_only.IntValue(i)) -> {
      assert i == 42
    }
    _ -> panic as "Expected int value"
  }
}

pub fn oneof_none_test() {
  let msg = oneofs_only.SimpleOneof(common_field: "shared", value: option.None)

  assert msg.value == option.None
}

pub fn oneof_encode_decode_test() {
  let original =
    oneofs_only.SimpleOneof(
      common_field: "test",
      value: option.Some(oneofs_only.BoolValue(True)),
    )

  let encoded = oneofs_only.encode_simpleoneof(original)
  let decoded = oneofs_only.decode_simpleoneof(encoded)

  case decoded {
    Ok(msg) -> {
      assert msg.common_field == "test"
      case msg.value {
        option.Some(oneofs_only.BoolValue(b)) -> {
          assert b == True
        }
        _ -> panic as "Expected bool value"
      }
    }
    Error(err) -> panic as { "Decode failed: " <> string.inspect(err) }
  }
}

pub fn submessage_test() {
  let sub = oneofs_only.SubMessage(content: "nested")
  assert sub.content == "nested"

  let encoded = oneofs_only.encode_submessage(sub)
  let decoded = oneofs_only.decode_submessage(encoded)

  case decoded {
    Ok(msg) -> {
      assert msg.content == "nested"
    }
    Error(err) -> panic as { "Decode failed: " <> string.inspect(err) }
  }
}
