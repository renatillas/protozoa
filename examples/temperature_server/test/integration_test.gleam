import gleam/bit_array
import gleam/http
import gleam/http/request
import gleam/httpc
import gleam/int
import gleam/io
import gleam/result
import gleam/string
import temperature_server/proto/proto

pub fn main() {
  io.println("🧪 Starting Integration Tests...")
  io.println("")

  // Test 1: GET with path and query parameters
  test_get_temperature()

  // Test 2: POST create with body
  test_create_temperature()

  // Test 3: PUT update with path param and body
  test_update_temperature()

  // Test 4: DELETE with multiple path parameters
  test_delete_temperature()

  // Test 5: GET list with query parameters
  test_list_temperatures()

  // Test 6: PATCH search with body
  test_search_temperatures()

  io.println("")
  io.println("✅ All integration tests completed!")
}

fn test_get_temperature() {
  io.println("📍 Test 1: GET /v1/sensors/{sensor_id}/temperatures")

  let assert Ok(req) =
    request.to(
      "http://localhost:8000/v1/sensors/sensor-999/temperatures?location=office&include_history=true",
    )

  let assert Ok(resp) = httpc.send(req)

  io.println("  Status: " <> int.to_string(resp.status))
  io.println("  Body length: " <> int.to_string(string.byte_size(resp.body)))

  // Decode the response
  let body_bits = bit_array.from_string(resp.body)
  let assert Ok(decoded) =
    proto.decode_temperature_response(body_bits)
    |> result.map_error(fn(_) { "Decode failed" })

  io.println("  Response eval: " <> decoded.eval)
  io.println("  Response degrees: " <> int.to_string(decoded.degrees))
  io.println("  Response sensor_id: " <> decoded.sensor_id)
  io.println("  ✅ GET test passed")
  io.println("")
}

fn test_create_temperature() {
  io.println("📍 Test 2: POST /v1/temperatures")

  // Create request message
  let req_msg =
    proto.CreateTemperatureRequest(
      sensor_id: "sensor-create-123",
      degrees: 30,
      unit: "celsius",
      location: "warehouse",
    )

  // Encode it
  let body = proto.encode_create_temperature_request(req_msg)

  let assert Ok(req) =
    request.to("http://localhost:8000/v1/temperatures")
    |> result.map(request.set_method(_, http.Post))
    |> result.map(request.set_body(_, body))
    |> result.map(request.set_header(
      _,
      "content-type",
      "application/x-protobuf",
    ))

  let assert Ok(resp) = httpc.send_bits(req)

  io.println("  Status: " <> int.to_string(resp.status))

  // Decode the response
  let assert Ok(decoded) =
    proto.decode_temperature_response(resp.body)
    |> result.map_error(fn(_) { "Decode failed" })

  io.println("  Response eval: " <> decoded.eval)
  io.println("  Response degrees: " <> int.to_string(decoded.degrees))
  io.println("  Response sensor_id: " <> decoded.sensor_id)
  io.println("  ✅ POST test passed")
  io.println("")
}

fn test_update_temperature() {
  io.println("📍 Test 3: PUT /v1/sensors/{sensor_id}/temperatures")

  // Create request message
  let req_msg =
    proto.UpdateTemperatureRequest(
      sensor_id: "sensor-update-456",
      degrees: 35,
      unit: "fahrenheit",
      notes: "Updated from test",
    )

  // Encode it
  let body = proto.encode_update_temperature_request(req_msg)

  let assert Ok(req) =
    request.to(
      "http://localhost:8000/v1/sensors/sensor-update-456/temperatures",
    )
    |> result.map(request.set_method(_, http.Put))
    |> result.map(request.set_body(_, body))
    |> result.map(request.set_header(
      _,
      "content-type",
      "application/x-protobuf",
    ))

  let assert Ok(resp) = httpc.send_bits(req)

  io.println("  Status: " <> int.to_string(resp.status))

  // Decode the response
  let assert Ok(decoded) =
    proto.decode_temperature_response(resp.body)
    |> result.map_error(fn(_) { "Decode failed" })

  io.println("  Response eval: " <> decoded.eval)
  io.println("  Response degrees: " <> int.to_string(decoded.degrees))
  io.println("  Response sensor_id: " <> decoded.sensor_id)
  io.println("  ✅ PUT test passed")
  io.println("")
}

fn test_delete_temperature() {
  io.println("📍 Test 4: DELETE /v1/locations/{location}/sensors/{sensor_id}")

  let assert Ok(req) =
    request.to(
      "http://localhost:8000/v1/locations/factory-floor/sensors/sensor-del-789",
    )
    |> result.map(request.set_method(_, http.Delete))

  let assert Ok(resp) = httpc.send(req)

  io.println("  Status: " <> int.to_string(resp.status))

  // Decode the response
  let body_bits = bit_array.from_string(resp.body)
  let assert Ok(decoded) =
    proto.decode_temperature_response(body_bits)
    |> result.map_error(fn(_) { "Decode failed" })

  io.println("  Response eval: " <> decoded.eval)
  io.println("  Response degrees: " <> int.to_string(decoded.degrees))
  io.println("  Response sensor_id: " <> decoded.sensor_id)

  // Verify the path parameters were extracted correctly
  let assert True = string.contains(decoded.eval, "sensor-del-789")
  let assert True = string.contains(decoded.eval, "factory-floor")

  io.println("  ✅ DELETE test passed (both path params extracted)")
  io.println("")
}

fn test_list_temperatures() {
  io.println("📍 Test 5: GET /v1/temperatures")

  let assert Ok(req) =
    request.to(
      "http://localhost:8000/v1/temperatures?location=lab&limit=20&offset=10",
    )

  let assert Ok(resp) = httpc.send(req)

  io.println("  Status: " <> int.to_string(resp.status))

  // Decode the response
  let body_bits = bit_array.from_string(resp.body)
  let assert Ok(decoded) =
    proto.decode_temperature_response(body_bits)
    |> result.map_error(fn(_) { "Decode failed" })

  io.println("  Response eval: " <> decoded.eval)

  // Verify the query parameters were parsed correctly
  let assert True = string.contains(decoded.eval, "lab")
  let assert True = string.contains(decoded.eval, "20")
  let assert True = string.contains(decoded.eval, "10")

  io.println("  ✅ LIST test passed (all query params parsed)")
  io.println("")
}

fn test_search_temperatures() {
  io.println("📍 Test 6: PATCH /v1/temperatures/search")

  // Create request message
  let req_msg =
    proto.SearchTemperaturesRequest(
      min_degrees: 15,
      max_degrees: 30,
      location: "greenhouse",
    )

  // Encode it
  let body = proto.encode_search_temperatures_request(req_msg)

  let assert Ok(req) =
    request.to("http://localhost:8000/v1/temperatures/search")
    |> result.map(request.set_method(_, http.Patch))
    |> result.map(request.set_body(_, body))
    |> result.map(request.set_header(
      _,
      "content-type",
      "application/x-protobuf",
    ))

  let assert Ok(resp) = httpc.send_bits(req)

  io.println("  Status: " <> int.to_string(resp.status))

  // Decode the response
  let assert Ok(decoded) =
    proto.decode_temperature_response(resp.body)
    |> result.map_error(fn(_) { "Decode failed" })

  io.println("  Response eval: " <> decoded.eval)

  // Verify the search parameters were parsed correctly
  let assert True = string.contains(decoded.eval, "15")
  let assert True = string.contains(decoded.eval, "30")
  let assert True = string.contains(decoded.eval, "greenhouse")

  io.println("  ✅ PATCH test passed (all fields parsed)")
  io.println("")
}
