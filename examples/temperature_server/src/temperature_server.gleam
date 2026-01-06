import gleam/bit_array
import gleam/bytes_tree
import gleam/erlang/process
import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/int
import gleam/io
import gleam/string
import mist
import temperature_server/proto
import wisp
import wisp/wisp_mist

pub fn main() -> Nil {
  io.println("🌡️  Starting Temperature Service with Wisp...")
  io.println("📍 Server running on http://localhost:8000")
  io.println("")
  io.println("Available endpoints:")
  io.println("  GET    /v1/sensors/{sensor_id}/temperatures")
  io.println("  POST   /v1/temperatures")
  io.println("  PUT    /v1/sensors/{sensor_id}/temperatures")
  io.println("  DELETE /v1/locations/{location}/sensors/{sensor_id}")
  io.println("  GET    /v1/temperatures")
  io.println("  PATCH  /v1/temperatures/search")
  io.println("")

  wisp.configure_logger()

  // Wisp secret key for sessions (not used here, but required)
  let secret_key_base = wisp.random_string(64)

  let assert Ok(_) =
    wisp_mist.handler(handle_request, secret_key_base)
    |> mist.new()
    |> mist.port(8000)
    |> mist.start()

  process.sleep_forever()
}

// Main Wisp request handler
// This demonstrates the middleware pattern with Wisp
fn handle_request(req: wisp.Request) -> wisp.Response {
  use <- wisp.log_request(req)
  // Wisp automatically handles body reading
  // Convert Wisp request to gleam/http request with BitArray body
  use body_bitarray <- wisp.require_bit_array_body(req)
  let http_req = request.map(req, fn(_) { body_bitarray })
  use <- handle_service_result

  case wisp.path_segments(req), req.method {
    // GET /v1/sensors/{sensor_id}/temperatures
    ["v1", "sensors", sensor_id, "temperatures"], http.Get ->
      proto.http_get_temperature(http_req, sensor_id, handle_get_temperature)
    // PUT /v1/sensors/{sensor_id}/temperatures
    ["v1", "sensors", sensor_id, "temperatures"], http.Put ->
      proto.http_update_temperature(
        http_req,
        sensor_id,
        handle_update_temperature,
      )
    // DELETE /v1/locations/{location}/sensors/{sensor_id}
    ["v1", "locations", location, "sensors", sensor_id], http.Delete ->
      proto.http_delete_temperature(
        http_req,
        location,
        sensor_id,
        handle_delete_temperature,
      )
    // POST /v1/temperatures (create)
    ["v1", "temperatures"], http.Post ->
      proto.http_create_temperature(http_req, handle_create_temperature)
    // GET /v1/temperatures (list)
    ["v1", "temperatures"], http.Get ->
      proto.http_list_temperatures(http_req, handle_list_temperatures)
    // PATCH /v1/temperatures/search
    ["v1", "temperatures", "search"], http.Patch ->
      proto.http_search_temperatures(http_req, handle_search_temperatures)
    _, _ ->
      response.new(404)
      |> response.set_body(bit_array.from_string("Not Found"))
      |> Ok
  }
}

// Middleware pattern: Handle service results with logging/telemetry
// Converts Result(Response(BitArray), TemperatureServiceRequestError) to wisp.Response
fn handle_service_result(
  result: fn() ->
    Result(response.Response(BitArray), proto.TemperatureServiceRequestError),
) -> wisp.Response {
  case result() {
    Ok(http_response) -> {
      // Success - convert to Wisp response
      wisp.response(http_response.status)
      |> wisp.set_header("content-type", "application/x-protobuf")
      |> wisp.set_body(
        wisp.Bytes(bytes_tree.from_bit_array(http_response.body)),
      )
    }
    Error(service_error) -> {
      // Error - log it (or emit metrics, track telemetry, etc.)
      case service_error {
        proto.TemperatureServiceDecodeError(msg) -> {
          wisp.log_error("Failed to decode request: " <> msg)
        }
        proto.TemperatureServiceHandlerError(handler_error) -> {
          wisp.log_error("Handler error: " <> string.inspect(handler_error))
        }
      }
      // Convert error to HTTP response
      service_error_to_wisp_response(service_error)
    }
  }
}

// Convert TemperatureServiceRequestError to Wisp response
fn service_error_to_wisp_response(
  error: proto.TemperatureServiceRequestError,
) -> wisp.Response {
  case error {
    proto.TemperatureServiceDecodeError(msg) ->
      wisp.response(400)
      |> wisp.string_body("Bad Request: " <> msg)
    proto.TemperatureServiceHandlerError(handler_error) ->
      handler_error_to_wisp_response(handler_error)
  }
}

// Convert handler-specific errors to Wisp responses
fn handler_error_to_wisp_response(
  error: proto.TemperatureServiceError,
) -> wisp.Response {
  case error {
    proto.TemperatureServiceNotFound ->
      wisp.response(404)
      |> wisp.string_body("Not Found")
    proto.TemperatureServiceUnauthorized ->
      wisp.response(401)
      |> wisp.set_header("www-authenticate", "Bearer")
      |> wisp.string_body("Unauthorized")
    proto.TemperatureServiceBadRequest(msg) ->
      wisp.response(400)
      |> wisp.string_body("Bad Request: " <> msg)
    proto.TemperatureServiceInvalidRequest(msg) ->
      wisp.response(400)
      |> wisp.string_body("Invalid Request: " <> msg)
    proto.TemperatureServiceInternalError(msg) ->
      wisp.response(500)
      |> wisp.string_body("Internal Error: " <> msg)
    proto.TemperatureServiceUnavailable(msg) ->
      wisp.response(503)
      |> wisp.set_header("retry-after", "60")
      |> wisp.string_body("Service Unavailable: " <> msg)
  }
}

// Business logic handlers

fn handle_get_temperature(
  req: proto.TemperatureGetTemperatureRequest,
) -> Result(proto.TemperatureTemperatureResponse, proto.TemperatureServiceError) {
  Ok(proto.TemperatureTemperatureResponse(
    eval: "Sensor "
      <> req.sensor_id
      <> " at "
      <> req.location
      <> " reading: 25°C",
    degrees: 25,
    sensor_id: req.sensor_id,
  ))
}

fn handle_create_temperature(
  req: proto.TemperatureCreateTemperatureRequest,
) -> Result(proto.TemperatureTemperatureResponse, proto.TemperatureServiceError) {
  Ok(proto.TemperatureTemperatureResponse(
    eval: "Created temperature: "
      <> int.to_string(req.degrees)
      <> "°"
      <> req.unit
      <> " at "
      <> req.location
      <> " for sensor "
      <> req.sensor_id,
    degrees: req.degrees,
    sensor_id: req.sensor_id,
  ))
}

fn handle_update_temperature(
  req: proto.TemperatureUpdateTemperatureRequest,
) -> Result(proto.TemperatureTemperatureResponse, proto.TemperatureServiceError) {
  Ok(proto.TemperatureTemperatureResponse(
    eval: "Updated sensor "
      <> req.sensor_id
      <> " to "
      <> int.to_string(req.degrees)
      <> "°"
      <> req.unit
      <> ". Notes: "
      <> req.notes,
    degrees: req.degrees,
    sensor_id: req.sensor_id,
  ))
}

fn handle_delete_temperature(
  req: proto.TemperatureDeleteTemperatureRequest,
) -> Result(proto.TemperatureTemperatureResponse, proto.TemperatureServiceError) {
  Ok(proto.TemperatureTemperatureResponse(
    eval: "Deleted sensor "
      <> req.sensor_id
      <> " from location "
      <> req.location,
    degrees: 0,
    sensor_id: req.sensor_id,
  ))
}

fn handle_list_temperatures(
  req: proto.TemperatureListTemperaturesRequest,
) -> Result(proto.TemperatureTemperatureResponse, proto.TemperatureServiceError) {
  Ok(proto.TemperatureTemperatureResponse(
    eval: "Listing temperatures for "
      <> req.location
      <> " (limit: "
      <> int.to_string(req.limit)
      <> ", offset: "
      <> int.to_string(req.offset)
      <> ")",
    degrees: 0,
    sensor_id: "",
  ))
}

fn handle_search_temperatures(
  req: proto.TemperatureSearchTemperaturesRequest,
) -> Result(proto.TemperatureTemperatureResponse, proto.TemperatureServiceError) {
  Ok(proto.TemperatureTemperatureResponse(
    eval: "Searching temperatures between "
      <> int.to_string(req.min_degrees)
      <> "°C and "
      <> int.to_string(req.max_degrees)
      <> "°C in "
      <> req.location,
    degrees: req.min_degrees,
    sensor_id: "",
  ))
}
