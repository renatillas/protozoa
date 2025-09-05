import generated/proto
import gleam/option
import gleam/result
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

// Test simple message with oneof - this works!
pub fn simple_message_test() {
  let message =
    proto.SimpleMessage(
      id: "test_001",
      description: "Test message",
      enabled: True,
      data: option.Some(proto.TextData("Hello, Test!")),
    )

  let encoded = proto.encode_simplemessage(message)
  let decode_result = proto.decode_simplemessage(encoded)

  decode_result |> should.be_ok()

  let decoded = result.unwrap(decode_result, message)
  decoded.id |> should.equal("test_001")
  decoded.description |> should.equal("Test message")
  decoded.enabled |> should.equal(True)

  case decoded.data {
    option.Some(proto.TextData(text)) -> text |> should.equal("Hello, Test!")
    _ -> should.fail()
  }
}

// Test simple message with numeric data
pub fn simple_message_numeric_test() {
  let message =
    proto.SimpleMessage(
      id: "numeric_test",
      description: "Numeric test",
      enabled: False,
      data: option.Some(proto.NumericData(42)),
    )

  let encoded = proto.encode_simplemessage(message)
  let decode_result = proto.decode_simplemessage(encoded)

  decode_result |> should.be_ok()

  let decoded = result.unwrap(decode_result, message)
  case decoded.data {
    option.Some(proto.NumericData(num)) -> num |> should.equal(42)
    _ -> should.fail()
  }
}

// Test timestamp (well-known type)
pub fn timestamp_test() {
  let timestamp = proto.Timestamp(seconds: 1_640_995_200, nanos: 123_456_789)
  let encoded = proto.encode_timestamp(timestamp)
  let decode_result = proto.decode_timestamp(encoded)

  decode_result |> should.be_ok()

  let decoded = result.unwrap(decode_result, timestamp)
  decoded.seconds |> should.equal(1_640_995_200)
  decoded.nanos |> should.equal(123_456_789)
}
