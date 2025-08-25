import generated/oneofs_only
import gleam/option
import gleam/string
import gleeunit/should

pub fn oneof_string_value_test() {
  let msg =
    oneofs_only.SimpleOneof(
      common_field: "shared",
      value: option.Some(oneofs_only.StringValue("hello")),
    )

  msg.common_field |> should.equal("shared")
  case msg.value {
    option.Some(oneofs_only.StringValue(s)) -> s |> should.equal("hello")
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
    option.Some(oneofs_only.IntValue(i)) -> i |> should.equal(42)
    _ -> panic as "Expected int value"
  }
}

pub fn oneof_none_test() {
  let msg = oneofs_only.SimpleOneof(common_field: "shared", value: option.None)

  msg.value |> should.equal(option.None)
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
      msg.common_field |> should.equal("test")
      case msg.value {
        option.Some(oneofs_only.BoolValue(b)) -> b |> should.equal(True)
        _ -> panic as "Expected bool value"
      }
    }
    Error(err) -> panic as { "Decode failed: " <> string.inspect(err) }
  }
}

pub fn submessage_test() {
  let sub = oneofs_only.SubMessage(content: "nested")
  sub.content |> should.equal("nested")

  let encoded = oneofs_only.encode_submessage(sub)
  let decoded = oneofs_only.decode_submessage(encoded)

  case decoded {
    Ok(msg) -> msg.content |> should.equal("nested")
    Error(err) -> panic as { "Decode failed: " <> string.inspect(err) }
  }
}
