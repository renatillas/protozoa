import generated/proto
import gleam/result
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

// Test minimal User with just basic fields (no nested messages)
pub fn minimal_user_test() {
  let user =
    proto.User(
      id: 42,
      name: "Test",
      email: "test@example.com",
      created_at: proto.Timestamp(seconds: 1_640_995_200, nanos: 0),
      // This works in debug
      is_active: True,
      role: proto.ADMIN,
      tags: [],
      bio: proto.StringValue(value: "Test bio"),
      // This might be the issue
    )

  let encoded = proto.encode_user(user)
  let decode_result = proto.decode_user(encoded)

  decode_result |> should.be_ok()

  let decoded = result.unwrap(decode_result, user)
  decoded.name |> should.equal("Test")
}

// Test User without StringValue bio to see if that's the issue
pub fn user_without_stringvalue_test() {
  // We can't remove bio as it's required, so let's test if empty bio works
  let user =
    proto.User(
      id: 1,
      name: "Simple",
      email: "simple@test.com",
      created_at: proto.Timestamp(seconds: 0, nanos: 0),
      is_active: False,
      role: proto.UNKNOWN,
      tags: [],
      bio: proto.StringValue(value: ""),
    )

  let encoded = proto.encode_user(user)
  let decode_result = proto.decode_user(encoded)

  decode_result |> should.be_ok()
}
