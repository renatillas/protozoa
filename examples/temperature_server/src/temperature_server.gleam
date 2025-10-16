import gleam/bytes_tree
import gleam/erlang/process
import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/int
import gleam/io
import gleam/string
import mist
import temperature_server/proto/proto.{
  type CreateTemperatureRequest, type DeleteTemperatureRequest,
  type GetTemperatureRequest, type ListTemperaturesRequest,
  type SearchTemperaturesRequest, type ServiceError, type TemperatureResponse,
  type TemperatureServiceError, type UpdateTemperatureRequest,
  TemperatureResponse,
}

pub fn main() -> Nil {
  io.println("🌡️  Starting Temperature Service...")
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

  let assert Ok(_) =
    mist.new(service)
    |> mist.port(8000)
    |> mist.start

  // Keep the server running
  process.sleep_forever()
}

// Middleware pattern: Handle service results with logging/telemetry
// This demonstrates how HTTP adapters return Result for flexible error handling
fn handle_service_result(
  result: Result(response.Response(BitArray), ServiceError),
) -> response.Response(mist.ResponseData) {
  case result {
    Ok(http_response) ->
      // Success - convert to Mist format
      response.Response(
        status: http_response.status,
        headers: http_response.headers,
        body: mist.Bytes(bytes_tree.from_bit_array(http_response.body)),
      )
    Error(service_error) -> {
      // Error - log it (or emit metrics, track telemetry, etc.)
      case service_error {
        proto.DecodeError(msg) -> {
          io.println("[ERROR] Failed to decode request: " <> msg)
        }
        proto.HandlerError(handler_error) -> {
          io.println("[ERROR] Handler error: " <> string.inspect(handler_error))
        }
      }
      // Convert error to HTTP response
      let error_response = service_error_to_response(service_error)
      response.Response(
        status: error_response.status,
        headers: error_response.headers,
        body: mist.Bytes(bytes_tree.from_bit_array(error_response.body)),
      )
    }
  }
}

// Convert ServiceError to HTTP response
fn service_error_to_response(error: ServiceError) -> response.Response(BitArray) {
  case error {
    proto.DecodeError(msg) ->
      response.Response(
        status: 400,
        headers: [#("content-type", "text/plain")],
        body: <<"Bad Request: ", msg:utf8>>,
      )
    proto.HandlerError(handler_error) ->
      handler_error_to_response(handler_error)
  }
}

// Convert handler-specific errors to HTTP responses
fn handler_error_to_response(
  error: TemperatureServiceError,
) -> response.Response(BitArray) {
  case error {
    proto.NotFound ->
      response.Response(
        status: 404,
        headers: [#("content-type", "text/plain")],
        body: <<"Not Found":utf8>>,
      )
    proto.Unauthorized ->
      response.Response(
        status: 401,
        headers: [
          #("content-type", "text/plain"),
          #("www-authenticate", "Bearer"),
        ],
        body: <<"Unauthorized":utf8>>,
      )
    proto.BadRequest(msg) ->
      response.Response(
        status: 400,
        headers: [#("content-type", "text/plain")],
        body: <<"Bad Request: ", msg:utf8>>,
      )
    proto.InvalidRequest(msg) ->
      response.Response(
        status: 400,
        headers: [#("content-type", "text/plain")],
        body: <<"Invalid Request: ", msg:utf8>>,
      )
    proto.InternalError(msg) ->
      response.Response(
        status: 500,
        headers: [#("content-type", "text/plain")],
        body: <<"Internal Error: ", msg:utf8>>,
      )
    proto.Unavailable(msg) ->
      response.Response(
        status: 503,
        headers: [#("content-type", "text/plain"), #("retry-after", "60")],
        body: <<"Service Unavailable: ", msg:utf8>>,
      )
  }
}

// Business logic handlers

fn handle_get_temperature(
  req: GetTemperatureRequest,
) -> Result(TemperatureResponse, TemperatureServiceError) {
  Ok(TemperatureResponse(
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
  req: CreateTemperatureRequest,
) -> Result(TemperatureResponse, TemperatureServiceError) {
  Ok(TemperatureResponse(
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
  req: UpdateTemperatureRequest,
) -> Result(TemperatureResponse, TemperatureServiceError) {
  Ok(TemperatureResponse(
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
  req: DeleteTemperatureRequest,
) -> Result(TemperatureResponse, TemperatureServiceError) {
  Ok(TemperatureResponse(
    eval: "Deleted sensor "
      <> req.sensor_id
      <> " from location "
      <> req.location,
    degrees: 0,
    sensor_id: req.sensor_id,
  ))
}

fn handle_list_temperatures(
  req: ListTemperaturesRequest,
) -> Result(TemperatureResponse, TemperatureServiceError) {
  Ok(TemperatureResponse(
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
  req: SearchTemperaturesRequest,
) -> Result(TemperatureResponse, TemperatureServiceError) {
  Ok(TemperatureResponse(
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

// HTTP service handler that routes requests to the generated HTTP handlers
// This demonstrates the middleware pattern:
// 1. Read body from Mist connection
// 2. Call generated HTTP adapters (returns Result for middleware)
// 3. Handle Result with custom middleware (logging, metrics, error conversion)
fn service(
  req: request.Request(mist.Connection),
) -> response.Response(mist.ResponseData) {
  // Read the body from the connection (with 10MB limit)
  let bit_req = case mist.read_body(req, 10_000_000) {
    Ok(req_with_body) -> req_with_body
    Error(_) -> request.set_body(req, <<>>)
  }

  case request.path_segments(req) {
    // GET /v1/sensors/{sensor_id}/temperatures
    // PUT /v1/sensors/{sensor_id}/temperatures
    ["v1", "sensors", _sensor_id, "temperatures"] -> {
      case req.method {
        http.Get ->
          proto.http_get_temperature(bit_req, handle_get_temperature)
          |> handle_service_result
        http.Put ->
          proto.http_update_temperature(bit_req, handle_update_temperature)
          |> handle_service_result
        _ ->
          response.new(404)
          |> response.set_body(mist.Bytes(bytes_tree.from_string("Not Found")))
      }
    }
    // DELETE /v1/locations/{location}/sensors/{sensor_id}
    ["v1", "locations", _location, "sensors", _sensor_id] -> {
      case req.method {
        http.Delete ->
          proto.http_delete_temperature(bit_req, handle_delete_temperature)
          |> handle_service_result
        _ ->
          response.new(404)
          |> response.set_body(mist.Bytes(bytes_tree.from_string("Not Found")))
      }
    }
    // GET /v1/temperatures (list)
    // POST /v1/temperatures (create)
    ["v1", "temperatures"] -> {
      case req.method {
        http.Post ->
          proto.http_create_temperature(bit_req, handle_create_temperature)
          |> handle_service_result
        http.Get ->
          proto.http_list_temperatures(bit_req, handle_list_temperatures)
          |> handle_service_result
        _ ->
          response.new(404)
          |> response.set_body(mist.Bytes(bytes_tree.from_string("Not Found")))
      }
    }
    // PATCH /v1/temperatures/search
    ["v1", "temperatures", "search"] -> {
      case req.method {
        http.Patch ->
          proto.http_search_temperatures(bit_req, handle_search_temperatures)
          |> handle_service_result
        _ ->
          response.new(404)
          |> response.set_body(mist.Bytes(bytes_tree.from_string("Not Found")))
      }
    }
    _ ->
      response.new(404)
      |> response.set_body(mist.Bytes(bytes_tree.from_string("Not Found")))
  }
}
