import generated/proto
import gleam/option
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

pub fn simple_message_oneof_test() {
  // Test text data variant
  let text_message =
    proto.SimpleMessage(
      id: "test1",
      description: "Text test",
      enabled: True,
      data: option.Some(proto.TextData("Hello")),
    )

  let encoded = proto.encode_simplemessage(text_message)
  let assert Ok(decoded) = proto.decode_simplemessage(encoded)

  decoded.id |> should.equal("test1")
  decoded.description |> should.equal("Text test")
  decoded.enabled |> should.equal(True)

  case decoded.data {
    option.Some(proto.TextData(value)) -> value |> should.equal("Hello")
    _ -> should.fail()
  }
}

pub fn simple_message_numeric_test() {
  // Test numeric data variant
  let numeric_message =
    proto.SimpleMessage(
      id: "test2",
      description: "Numeric test",
      enabled: False,
      data: option.Some(proto.NumericData(12_345)),
    )

  let encoded = proto.encode_simplemessage(numeric_message)
  let assert Ok(decoded) = proto.decode_simplemessage(encoded)

  decoded.id |> should.equal("test2")
  decoded.description |> should.equal("Numeric test")
  decoded.enabled |> should.equal(False)

  case decoded.data {
    option.Some(proto.NumericData(value)) -> value |> should.equal(12_345)
    _ -> should.fail()
  }
}

pub fn simple_message_binary_test() {
  // Test binary data variant
  let binary_message =
    proto.SimpleMessage(
      id: "test3",
      description: "Binary test",
      enabled: True,
      data: option.Some(proto.BinaryData(<<"hello":utf8>>)),
    )

  let encoded = proto.encode_simplemessage(binary_message)
  let assert Ok(decoded) = proto.decode_simplemessage(encoded)

  decoded.id |> should.equal("test3")
  decoded.description |> should.equal("Binary test")
  decoded.enabled |> should.equal(True)

  case decoded.data {
    option.Some(proto.BinaryData(value)) ->
      value |> should.equal(<<"hello":utf8>>)
    _ -> should.fail()
  }
}

pub fn user_test() {
  let user =
    proto.User(
      id: 1,
      name: "Test User",
      email: "test@example.com",
      created_at: proto.Timestamp(seconds: 1_234_567_890, nanos: 0),
      is_active: True,
      role: proto.USER,
      tags: ["tag1", "tag2"],
      bio: proto.StringValue(value: "Test bio"),
    )

  let encoded = proto.encode_user(user)
  let assert Ok(decoded) = proto.decode_user(encoded)

  decoded.id |> should.equal(1)
  decoded.name |> should.equal("Test User")
  decoded.email |> should.equal("test@example.com")
  decoded.created_at.seconds |> should.equal(1_234_567_890)
  decoded.is_active |> should.equal(True)
  decoded.role |> should.equal(proto.USER)
  decoded.tags |> should.equal(["tag1", "tag2"])
  decoded.bio.value |> should.equal("Test bio")
}
