import generated_app.{
  ACTIVE, AppAppMessage, BaseBaseMessage, decode_app_app_message,
  decode_base_base_message, encode_app_app_message, encode_base_base_message,
}
import generated_service.{
  type TestserviceTestRequest, TestserviceTestRequest, TestserviceTestResponse,
  decode_testservice_test_request, decode_testservice_test_response,
  encode_testservice_test_request, encode_testservice_test_response,
  process_service,
}
import generated_types.{
  TypesAllTypes, TypesRepeatedTypes, decode_types_all_types,
  decode_types_repeated_types, encode_types_all_types, encode_types_repeated_types,
}
import gleeunit

pub fn main() {
  gleeunit.main()
}

// ---- App/Base message tests (tests imports and enums) ----

pub fn base_message_roundtrip_test() {
  let msg = BaseBaseMessage(id: "test-123", status: ACTIVE)
  let encoded = encode_base_base_message(msg)
  let assert Ok(decoded) = decode_base_base_message(encoded)

  let assert "test-123" = decoded.id
  let assert ACTIVE = decoded.status
}

pub fn app_message_with_nested_roundtrip_test() {
  let base = BaseBaseMessage(id: "nested-id", status: ACTIVE)
  let app = AppAppMessage(base: base, status: ACTIVE)

  let encoded = encode_app_app_message(app)
  let assert Ok(decoded) = decode_app_app_message(encoded)

  let assert "nested-id" = decoded.base.id
  let assert ACTIVE = decoded.base.status
  let assert ACTIVE = decoded.status
}

// ---- Service tests ----

pub fn service_request_roundtrip_test() {
  let req = TestserviceTestRequest(data: "hello world")
  let encoded = encode_testservice_test_request(req)
  let assert Ok(decoded) = decode_testservice_test_request(encoded)

  let assert "hello world" = decoded.data
}

pub fn service_response_roundtrip_test() {
  let resp = TestserviceTestResponse(result: "success")
  let encoded = encode_testservice_test_response(resp)
  let assert Ok(decoded) = decode_testservice_test_response(encoded)

  let assert "success" = decoded.result
}

pub fn process_service_test() {
  // Create a handler that echoes the request data
  let handler = fn(req: TestserviceTestRequest) {
    Ok(TestserviceTestResponse(result: "Processed: " <> req.data))
  }

  // Encode a request
  let request = TestserviceTestRequest(data: "test input")
  let request_bytes = encode_testservice_test_request(request)

  // Call the service
  let assert Ok(response_bytes) = process_service(request_bytes, handler)

  // Decode and verify response
  let assert Ok(response) = decode_testservice_test_response(response_bytes)
  let assert "Processed: test input" = response.result
}

// ---- Types tests (all scalar types) ----

pub fn all_types_roundtrip_test() {
  let msg =
    TypesAllTypes(
      double_field: 3.14159,
      float_field: 2.5,
      int32_field: 42,
      int64_field: 9_999_999_999,
      uint32_field: 100,
      uint64_field: 200,
      sint32_field: -50,
      sint64_field: -100,
      fixed32_field: 1000,
      fixed64_field: 2000,
      sfixed32_field: -500,
      sfixed64_field: -1000,
      bool_field: True,
      string_field: "hello",
      bytes_field: <<1, 2, 3, 4>>,
    )

  let encoded = encode_types_all_types(msg)
  let assert Ok(decoded) = decode_types_all_types(encoded)

  // Check all fields
  let assert 42 = decoded.int32_field
  let assert 9_999_999_999 = decoded.int64_field
  let assert 100 = decoded.uint32_field
  let assert 200 = decoded.uint64_field
  let assert -50 = decoded.sint32_field
  let assert -100 = decoded.sint64_field
  let assert 1000 = decoded.fixed32_field
  let assert 2000 = decoded.fixed64_field
  let assert -500 = decoded.sfixed32_field
  let assert -1000 = decoded.sfixed64_field
  let assert True = decoded.bool_field
  let assert "hello" = decoded.string_field
  let assert <<1, 2, 3, 4>> = decoded.bytes_field
}

pub fn repeated_types_roundtrip_test() {
  let msg =
    TypesRepeatedTypes(
      strings: ["a", "b", "c"],
      numbers: [1, 2, 3, 4, 5],
      flags: [True, False, True],
    )

  let encoded = encode_types_repeated_types(msg)
  let assert Ok(decoded) = decode_types_repeated_types(encoded)

  let assert ["a", "b", "c"] = decoded.strings
  let assert [1, 2, 3, 4, 5] = decoded.numbers
  let assert [True, False, True] = decoded.flags
}

pub fn empty_repeated_roundtrip_test() {
  let msg = TypesRepeatedTypes(strings: [], numbers: [], flags: [])

  let encoded = encode_types_repeated_types(msg)
  let assert Ok(decoded) = decode_types_repeated_types(encoded)

  let assert [] = decoded.strings
  let assert [] = decoded.numbers
  let assert [] = decoded.flags
}
