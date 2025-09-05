import generated/proto
import gleam/result
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

// Test StringValue (well-known type) in isolation
pub fn stringvalue_test() {
  let string_value = proto.StringValue(value: "test string")
  let encoded = proto.encode_stringvalue(string_value)
  let decode_result = proto.decode_stringvalue(encoded)

  decode_result |> should.be_ok()

  let decoded = result.unwrap(decode_result, string_value)
  decoded.value |> should.equal("test string")
}

// Test User without well-known types - create a minimal user
pub fn minimal_user_test() {
  // Test with just basic types first
  let timestamp = proto.Timestamp(seconds: 1_640_995_200, nanos: 0)
  let timestamp_encoded = proto.encode_timestamp(timestamp)
  let timestamp_decode_result = proto.decode_timestamp(timestamp_encoded)

  timestamp_decode_result |> should.be_ok()

  let decoded_timestamp = result.unwrap(timestamp_decode_result, timestamp)
  decoded_timestamp.seconds |> should.equal(1_640_995_200)
}

// Test each User component individually to isolate the problem
pub fn user_components_test() {
  // Test the enum encoding/decoding
  let role_encoded = proto.encode_userrole_value(proto.ADMIN)
  role_encoded |> should.equal(1)

  let role_decode_result = proto.decode_userrole_value(1)
  role_decode_result |> should.be_ok()

  let decoded_role = result.unwrap(role_decode_result, proto.ADMIN)
  decoded_role |> should.equal(proto.ADMIN)
}
