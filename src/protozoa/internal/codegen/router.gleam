//// HTTP Router Code Generation Module
////
//// This module generates Mist HTTP router code from Protocol Buffer service definitions.
//// It creates:
//// - Service router functions that map HTTP routes to handler functions
//// - HTTP request/response wrapper functions
//// - Error response formatting
//// - Request parameter extraction from paths, queries, and bodies
////
//// Generates code compatible with Mist 5.x

import gleam/list
import gleam/option.{None, Some}
import gleam/regexp
import gleam/string
import justin
import protozoa/parser.{type Message, type Method, type Service}

/// Extract path parameter names from a URL pattern
/// Example: "/v1/temperatures/{id}" -> ["id"]
fn extract_path_params(path: String) -> List(String) {
  let assert Ok(param_regex) = regexp.from_string("\\{([^}]+)\\}")

  regexp.scan(param_regex, path)
  |> list.map(fn(match: regexp.Match) {
    case match.submatches {
      [Some(param_name)] -> param_name
      _ -> ""
    }
  })
  |> list.filter(fn(s) { s != "" })
}

/// Generate a Mist service function setup for a service
pub fn generate_service_router(
  service: Service,
  messages: List(Message),
) -> String {
  case service.methods {
    [] -> ""
    methods -> {
      let method_handlers =
        list.map(methods, fn(method) {
          generate_method_handler(method, service.name)
        })
      let handlers = string.join(method_handlers, "\n\n")
      let error_formatter = generate_error_formatter(service)
      let query_helpers = generate_query_helpers_for_service(service, messages)

      // Analyze which helper functions are actually needed
      let needed_helpers = analyze_needed_helpers(service, messages)
      let query_param_helpers = generate_query_param_helpers_conditional(needed_helpers)

      string.join(
        [
          "/// Auto-generated service setup for " <> service.name,
          "/// Register these handlers with your Mist application",
          "",
          handlers,
          "",
          error_formatter,
          "",
          query_helpers,
          "",
          query_param_helpers,
        ],
        "\n",
      )
    }
  }
}

/// Generate a single HTTP handler from method definition
/// These handlers accept a business logic function as an argument
fn generate_method_handler(method: Method, service_name: String) -> String {
  case method.http_method, method.http_path {
    Some(http_method), Some(path) -> {
      let handler_name = "http_" <> justin.snake_case(method.name)
      let request_type = method.input_type
      let response_type = method.output_type

      let http_method_str = case http_method {
        parser.Get -> "GET"
        parser.Post -> "POST"
        parser.Put -> "PUT"
        parser.Delete -> "DELETE"
        parser.Patch -> "PATCH"
      }

      let http_method_pattern = case http_method {
        parser.Get -> "http.Get"
        parser.Post -> "http.Post"
        parser.Put -> "http.Put"
        parser.Delete -> "http.Delete"
        parser.Patch -> "http.Patch"
      }

      let decoder_name = justin.snake_case(request_type) <> "_decoder()"
      let encoder_name = "encode_" <> justin.snake_case(response_type)

      // Determine if this method should read from body or query params
      let reads_from_body = case http_method {
        parser.Post | parser.Put | parser.Patch -> True
        parser.Get | parser.Delete -> False
      }

      let handler_body = case reads_from_body {
        True ->
          string.join(
            [
              "  case req.method {",
              "    " <> http_method_pattern <> " -> {",
              "      case decode.run(req.body, with: " <> decoder_name <> ") {",
              "        Ok(proto_request) -> {",
              "          case handler(proto_request) {",
              "            Ok(response) -> {",
              "              response.new(200)",
              "              |> response.set_body(mist.Bytes(bytes_tree.from_bit_array("
                <> encoder_name
                <> "(response))))",
              "            }",
              "            Error(err) -> format_error_response(err)",
              "          }",
              "        }",
              "        Error(_) -> {",
              "          response.new(400)",
              "          |> response.set_body(mist.Bytes(bytes_tree.from_string(\"Invalid request body\")))",
              "        }",
              "      }",
              "    }",
              "    _ -> {",
              "      response.new(405)",
              "      |> response.set_body(mist.Bytes(bytes_tree.from_string(\"Method not allowed\")))",
              "    }",
              "  }",
            ],
            "\n",
          )
        False -> {
          // Use method-specific query parameter mapper
          let query_mapper_name =
            "format_query_request_for_" <> justin.snake_case(method.name)

          string.join(
            [
              "  case req.method {",
              "    " <> http_method_pattern <> " -> {",
              "      case " <> query_mapper_name <> "(req) {",
              "        Ok(proto_request) -> {",
              "          case handler(proto_request) {",
              "            Ok(response) -> {",
              "              response.new(200)",
              "              |> response.set_body(mist.Bytes(bytes_tree.from_bit_array("
                <> encoder_name
                <> "(response))))",
              "            }",
              "            Error(err) -> format_error_response(err)",
              "          }",
              "        }",
              "        Error(_) -> {",
              "          response.new(400)",
              "          |> response.set_body(mist.Bytes(bytes_tree.from_string(\"Invalid request\")))",
              "        }",
              "      }",
              "    }",
              "    _ -> {",
              "      response.new(405)",
              "      |> response.set_body(mist.Bytes(bytes_tree.from_string(\"Method not allowed\")))",
              "    }",
              "  }",
            ],
            "\n",
          )
        }
      }

      // Create function signature that accepts request and handler function
      let service_error_type = service_name <> "Error"
      let handler_fn_type =
        "fn("
        <> request_type
        <> ") -> Result("
        <> response_type
        <> ", "
        <> service_error_type
        <> ")"

      string.join(
        [
          "/// HTTP " <> http_method_str <> " " <> path,
          "/// Accepts a handler function that processes the request",
          "pub fn "
            <> handler_name
            <> "(",
          "  req: request.Request(BitArray),",
          "  handler: " <> handler_fn_type <> ",",
          ") -> response.Response(mist.ResponseData) {",
          handler_body,
          "}",
        ],
        "\n",
      )
    }
    _, _ -> ""
  }
}

/// Generate error response formatter for service errors
pub fn generate_error_formatter(service: Service) -> String {
  let error_type = service.name <> "Error"

  string.join(
    [
      "/// Format service errors as HTTP responses using standard HTTP status codes",
      "fn format_error_response(error: "
        <> error_type
        <> ") -> response.Response(mist.ResponseData) {",
      "  case error {",
      "    NotFound ->",
      "      response.new(404)",
      "      |> response.prepend_header(\"content-type\", \"text/plain\")",
      "      |> response.set_body(mist.Bytes(bytes_tree.from_string(\"Not Found\")))",
      "    Unauthorized ->",
      "      response.new(401)",
      "      |> response.prepend_header(\"content-type\", \"text/plain\")",
      "      |> response.prepend_header(\"www-authenticate\", \"Bearer\")",
      "      |> response.set_body(mist.Bytes(bytes_tree.from_string(\"Unauthorized\")))",
      "    BadRequest(msg) ->",
      "      response.new(400)",
      "      |> response.prepend_header(\"content-type\", \"text/plain\")",
      "      |> response.set_body(mist.Bytes(bytes_tree.from_string(\"Bad Request: \" <> msg)))",
      "    InvalidRequest(msg) ->",
      "      response.new(400)",
      "      |> response.prepend_header(\"content-type\", \"text/plain\")",
      "      |> response.set_body(mist.Bytes(bytes_tree.from_string(\"Invalid Request: \" <> msg)))",
      "    InternalError(msg) ->",
      "      response.new(500)",
      "      |> response.prepend_header(\"content-type\", \"text/plain\")",
      "      |> response.set_body(mist.Bytes(bytes_tree.from_string(\"Internal Error: \" <> msg)))",
      "    Unavailable(msg) ->",
      "      response.new(503)",
      "      |> response.prepend_header(\"content-type\", \"text/plain\")",
      "      |> response.prepend_header(\"retry-after\", \"60\")",
      "      |> response.set_body(mist.Bytes(bytes_tree.from_string(\"Service Unavailable: \" <> msg)))",
      "  }",
      "}",
    ],
    "\n",
  )
}

/// Generate query parameter mapping functions for all GET/DELETE methods in the service
pub fn generate_query_helpers_for_service(
  service: Service,
  messages: List(Message),
) -> String {
  // Find all GET/DELETE methods that need query parameter mapping
  let query_methods =
    service.methods
    |> list.filter(fn(method) {
      case method.http_method {
        Some(parser.Get) | Some(parser.Delete) -> True
        _ -> False
      }
    })

  case query_methods {
    [] -> ""
    methods -> {
      let mappers =
        list.map(methods, fn(method) {
          generate_query_mapper_for_method(method, messages)
        })
      string.join(mappers, "\n\n")
    }
  }
}

/// Generate a query parameter mapper for a single method
fn generate_query_mapper_for_method(
  method: Method,
  messages: List(Message),
) -> String {
  let function_name =
    "format_query_request_for_" <> justin.snake_case(method.name)
  let message_type = method.input_type

  // Extract path parameters from the HTTP path
  let path_params = case method.http_path {
    Some(path) -> extract_path_params(path)
    None -> []
  }

  // Find the message definition
  case list.find(messages, fn(msg) { msg.name == message_type }) {
    Ok(message) -> {
      // Check if any fields are path parameters
      let has_path_params = path_params != []

      // Check if any fields are query parameters (not path params)
      let has_query_params =
        message.fields
        |> list.any(fn(field) {
          let field_name_lower = string.lowercase(field.name)
          !list.any(path_params, fn(param) {
            string.lowercase(param) == field_name_lower
          })
        })

      // Generate field mappings, distinguishing between path params and query params
      let field_mappings =
        message.fields
        |> list.map(fn(field) {
          let field_name_lower = string.lowercase(field.name)
          // Check if this field is a path parameter
          let is_path_param =
            list.any(path_params, fn(param) {
              string.lowercase(param) == field_name_lower
            })

          case is_path_param {
            True -> generate_field_path_mapping(field)
            False -> generate_field_query_mapping(field)
          }
        })
        |> string.join("\n  ")

      let field_constructor_args =
        message.fields
        |> list.map(fn(field) {
          let field_name = justin.snake_case(field.name)
          field_name <> ": " <> field_name
        })
        |> string.join(", ")

      // Use _params if there are no query parameters
      let params_var = case has_query_params {
        True -> "params"
        False -> "_params"
      }

      case has_path_params {
        True -> {
          // Generate mapper with path parameter extraction
          let path_pattern = case method.http_path {
            Some(p) -> p
            None -> ""
          }

          string.join(
            [
              "/// Map query parameters to " <> message_type,
              "fn "
                <> function_name
                <> "(req: request.Request(BitArray)) -> Result("
                <> message_type
                <> ", Nil) {",
              "  // Extract path parameters from request path",
              "  let path_params = extract_path_params_from_request(req.path, \""
                <> path_pattern
                <> "\")",
              "  case request.get_query(req) {",
              "    Ok(" <> params_var <> ") -> {",
              "      // Extract and convert each field from parsed query params",
              "      " <> field_mappings,
              "      ",
              "      Ok("
                <> message_type
                <> "("
                <> field_constructor_args
                <> "))",
              "    }",
              "    Error(_) -> {",
              "      // No query params, create message with defaults",
              "      case decode.run(<<>>, with: "
                <> justin.snake_case(message_type)
                <> "_decoder()) {",
              "        Ok(msg) -> Ok(msg)",
              "        Error(_) -> Error(Nil)",
              "      }",
              "    }",
              "  }",
              "}",
            ],
            "\n",
          )
        }
        False -> {
          // Original query-param-only version
          string.join(
            [
              "/// Map query parameters to " <> message_type,
              "fn "
                <> function_name
                <> "(req: request.Request(BitArray)) -> Result("
                <> message_type
                <> ", Nil) {",
              "  case request.get_query(req) {",
              "    Ok(" <> params_var <> ") -> {",
              "      // Extract and convert each field from parsed query params",
              "      " <> field_mappings,
              "      ",
              "      Ok("
                <> message_type
                <> "("
                <> field_constructor_args
                <> "))",
              "    }",
              "    Error(_) -> {",
              "      // No query params, create message with defaults",
              "      case decode.run(<<>>, with: "
                <> justin.snake_case(message_type)
                <> "_decoder()) {",
              "        Ok(msg) -> Ok(msg)",
              "        Error(_) -> Error(Nil)",
              "      }",
              "    }",
              "  }",
              "}",
            ],
            "\n",
          )
        }
      }
    }
    Error(_) -> {
      // Fallback if message not found - use generic approach
      string.join(
        [
          "/// Generic query parameter mapper for " <> method.name,
          "fn format_query_request_for_"
            <> justin.snake_case(method.name)
            <> "(req: request.Request(BitArray)) -> Result("
            <> message_type
            <> ", Nil) {",
          "  // Message definition not found, using default decoder",
          "  case decode.run(<<>>, with: "
            <> justin.snake_case(message_type)
            <> "_decoder()) {",
          "    Ok(msg) -> Ok(msg)",
          "    Error(_) -> Error(Nil)",
          "  }",
          "}",
        ],
        "\n",
      )
    }
  }
}

/// Generate path parameter extraction for a single field
fn generate_field_path_mapping(field: parser.Field) -> String {
  let field_name = justin.snake_case(field.name)
  let param_name = string.lowercase(field.name)

  case field.field_type {
    parser.String ->
      "let "
      <> field_name
      <> " = get_path_param_string(path_params, \""
      <> param_name
      <> "\", \"\")"

    parser.Int32
    | parser.Int64
    | parser.UInt32
    | parser.UInt64
    | parser.SInt32
    | parser.SInt64
    | parser.Fixed32
    | parser.Fixed64
    | parser.SFixed32
    | parser.SFixed64 ->
      "let "
      <> field_name
      <> " = get_path_param_int(path_params, \""
      <> param_name
      <> "\", 0)"

    _ ->
      "let "
      <> field_name
      <> " = get_path_param_string(path_params, \""
      <> param_name
      <> "\", \"\") // Path param with complex type, using string default"
  }
}

/// Generate query parameter extraction for a single field
fn generate_field_query_mapping(field: parser.Field) -> String {
  let field_name = justin.snake_case(field.name)
  let param_name = field.name

  case field.field_type {
    parser.String ->
      "let "
      <> field_name
      <> " = get_query_param_string(params, \""
      <> param_name
      <> "\", \"\")"

    parser.Int32
    | parser.Int64
    | parser.UInt32
    | parser.UInt64
    | parser.SInt32
    | parser.SInt64
    | parser.Fixed32
    | parser.Fixed64
    | parser.SFixed32
    | parser.SFixed64 ->
      "let "
      <> field_name
      <> " = get_query_param_int(params, \""
      <> param_name
      <> "\", 0)"

    parser.Bool ->
      "let "
      <> field_name
      <> " = get_query_param_bool(params, \""
      <> param_name
      <> "\", False)"

    parser.Float | parser.Double ->
      "let "
      <> field_name
      <> " = get_query_param_float(params, \""
      <> param_name
      <> "\", 0.0)"

    parser.Repeated(inner_type) -> {
      // For repeated fields, collect all values with the same param name
      case inner_type {
        parser.String ->
          "let "
          <> field_name
          <> " = get_query_param_list_string(params, \""
          <> param_name
          <> "\")"
        parser.Int32
        | parser.Int64
        | parser.UInt32
        | parser.UInt64
        | parser.SInt32
        | parser.SInt64
        | parser.Fixed32
        | parser.Fixed64
        | parser.SFixed32
        | parser.SFixed64 ->
          "let "
          <> field_name
          <> " = get_query_param_list_int(params, \""
          <> param_name
          <> "\")"
        _ ->
          "let "
          <> field_name
          <> " = []  // Complex repeated types not supported in query params"
      }
    }

    parser.Optional(inner_type) -> {
      case inner_type {
        parser.String ->
          "let "
          <> field_name
          <> " = get_query_param_optional_string(params, \""
          <> param_name
          <> "\")"
        parser.Int32
        | parser.Int64
        | parser.UInt32
        | parser.UInt64
        | parser.SInt32
        | parser.SInt64
        | parser.Fixed32
        | parser.Fixed64
        | parser.SFixed32
        | parser.SFixed64 ->
          "let "
          <> field_name
          <> " = get_query_param_optional_int(params, \""
          <> param_name
          <> "\")"
        _ ->
          "let "
          <> field_name
          <> " = option.None  // Complex optional types not supported in query params"
      }
    }

    parser.Bytes ->
      "let "
      <> field_name
      <> " = <<>>  // Bytes not supported in query params, using empty"

    parser.MessageType(_) ->
      "let "
      <> field_name
      <> " = todo as \"Message types require nested object handling\""

    parser.EnumType(_) ->
      "let "
      <> field_name
      <> " = 0  // Enum not supported in query params, using default"

    parser.Map(_, _) ->
      "let "
      <> field_name
      <> " = dict.new()  // Maps not supported in query params"
  }
}

/// Type to track which helper functions are needed
pub type NeededHelpers {
  NeededHelpers(
    path_extraction: Bool,
    path_string: Bool,
    path_int: Bool,
    query_string: Bool,
    query_int: Bool,
    query_bool: Bool,
    query_float: Bool,
    query_list_string: Bool,
    query_list_int: Bool,
    query_optional_string: Bool,
    query_optional_int: Bool,
  )
}

/// Analyze the service to determine which helper functions are actually needed
fn analyze_needed_helpers(
  service: Service,
  messages: List(Message),
) -> NeededHelpers {
  // Start with all helpers disabled
  let initial = NeededHelpers(
    path_extraction: False,
    path_string: False,
    path_int: False,
    query_string: False,
    query_int: False,
    query_bool: False,
    query_float: False,
    query_list_string: False,
    query_list_int: False,
    query_optional_string: False,
    query_optional_int: False,
  )

  // Analyze each method that uses GET/DELETE (query/path params)
  list.fold(service.methods, initial, fn(acc, method) {
    case method.http_method {
      Some(parser.Get) | Some(parser.Delete) -> {
        // Find the request message
        case list.find(messages, fn(msg) { msg.name == method.input_type }) {
          Ok(message) -> {
            // Check if method has path parameters
            let path_params = case method.http_path {
              Some(path) -> extract_path_params(path)
              None -> []
            }
            let has_path_params = path_params != []

            // Analyze each field
            list.fold(message.fields, acc, fn(field_acc, field) {
              let field_name_lower = string.lowercase(field.name)
              let is_path_param = list.any(path_params, fn(param) {
                string.lowercase(param) == field_name_lower
              })

              case is_path_param {
                True -> analyze_path_param_type(field.field_type, field_acc, has_path_params)
                False -> analyze_query_param_type(field.field_type, field_acc)
              }
            })
          }
          Error(_) -> acc
        }
      }
      _ -> acc
    }
  })
}

/// Analyze a path parameter field type and update needed helpers
fn analyze_path_param_type(
  field_type: parser.ProtoType,
  acc: NeededHelpers,
  has_path_params: Bool,
) -> NeededHelpers {
  case field_type {
    parser.String ->
      NeededHelpers(..acc, path_extraction: has_path_params, path_string: True)
    parser.Int32
    | parser.Int64
    | parser.UInt32
    | parser.UInt64
    | parser.SInt32
    | parser.SInt64
    | parser.Fixed32
    | parser.Fixed64
    | parser.SFixed32
    | parser.SFixed64 ->
      NeededHelpers(..acc, path_extraction: has_path_params, path_int: True)
    _ -> NeededHelpers(..acc, path_extraction: has_path_params)
  }
}

/// Analyze a query parameter field type and update needed helpers
fn analyze_query_param_type(
  field_type: parser.ProtoType,
  acc: NeededHelpers,
) -> NeededHelpers {
  case field_type {
    parser.String -> NeededHelpers(..acc, query_string: True)
    parser.Int32
    | parser.Int64
    | parser.UInt32
    | parser.UInt64
    | parser.SInt32
    | parser.SInt64
    | parser.Fixed32
    | parser.Fixed64
    | parser.SFixed32
    | parser.SFixed64 -> NeededHelpers(..acc, query_int: True)
    parser.Bool -> NeededHelpers(..acc, query_bool: True)
    parser.Float | parser.Double -> NeededHelpers(..acc, query_float: True)
    parser.Repeated(inner_type) -> {
      case inner_type {
        parser.String -> NeededHelpers(..acc, query_list_string: True)
        parser.Int32
        | parser.Int64
        | parser.UInt32
        | parser.UInt64
        | parser.SInt32
        | parser.SInt64
        | parser.Fixed32
        | parser.Fixed64
        | parser.SFixed32
        | parser.SFixed64 -> NeededHelpers(..acc, query_list_int: True)
        _ -> acc
      }
    }
    parser.Optional(inner_type) -> {
      case inner_type {
        parser.String -> NeededHelpers(..acc, query_optional_string: True)
        parser.Int32
        | parser.Int64
        | parser.UInt32
        | parser.UInt64
        | parser.SInt32
        | parser.SInt64
        | parser.Fixed32
        | parser.Fixed64
        | parser.SFixed32
        | parser.SFixed64 -> NeededHelpers(..acc, query_optional_int: True)
        _ -> acc
      }
    }
    _ -> acc
  }
}

/// Generate path and query parameter helper functions (conditional)
fn generate_query_param_helpers_conditional(needed: NeededHelpers) -> String {
  let helpers = []

  // Path extraction helpers
  let helpers = case needed.path_extraction {
    True -> [
      string.join(
        [
          "/// Extract path parameters from request path based on pattern",
          "/// Example: extract_path_params_from_request(\"/v1/temperatures/123\", \"/v1/temperatures/{id}\")",
          "///   returns [(\"id\", \"123\")]",
          "fn extract_path_params_from_request(path: String, pattern: String) -> List(#(String, String)) {",
          "  let path_segments = string.split(path, \"/\") |> list.filter(fn(s) { s != \"\" })",
          "  let pattern_segments = string.split(pattern, \"/\") |> list.filter(fn(s) { s != \"\" })",
          "  extract_params_from_segments(path_segments, pattern_segments, [])",
          "}",
          "",
          "/// Helper to extract parameters by matching path segments with pattern segments",
          "fn extract_params_from_segments(",
          "  path_segments: List(String),",
          "  pattern_segments: List(String),",
          "  acc: List(#(String, String)),",
          ") -> List(#(String, String)) {",
          "  case path_segments, pattern_segments {",
          "    [], _ -> list.reverse(acc)",
          "    _, [] -> list.reverse(acc)",
          "    [path_seg, ..path_rest], [pattern_seg, ..pattern_rest] -> {",
          "      case string.starts_with(pattern_seg, \"{\") && string.ends_with(pattern_seg, \"}\") {",
          "        True -> {",
          "          // This is a path parameter",
          "          let param_name = string.slice(pattern_seg, 1, string.length(pattern_seg) - 2) |> string.lowercase",
          "          extract_params_from_segments(path_rest, pattern_rest, [#(param_name, path_seg), ..acc])",
          "        }",
          "        False -> {",
          "          // This is a literal segment, skip",
          "          extract_params_from_segments(path_rest, pattern_rest, acc)",
          "        }",
          "      }",
          "    }",
          "  }",
          "}",
        ],
        "\n",
      ),
      ..helpers
    ]
    False -> helpers
  }

  // Path parameter getters
  let helpers = case needed.path_string {
    True -> [
      string.join(
        [
          "/// Get path parameter as string with default",
          "fn get_path_param_string(",
          "  params: List(#(String, String)),",
          "  key: String,",
          "  default: String,",
          ") -> String {",
          "  case list.find(params, fn(p) { p.0 == key }) {",
          "    Ok(#(_, value)) -> value",
          "    Error(_) -> default",
          "  }",
          "}",
        ],
        "\n",
      ),
      ..helpers
    ]
    False -> helpers
  }

  let helpers = case needed.path_int {
    True -> [
      string.join(
        [
          "/// Get path parameter as int with default",
          "fn get_path_param_int(",
          "  params: List(#(String, String)),",
          "  key: String,",
          "  default: Int,",
          ") -> Int {",
          "  case list.find(params, fn(p) { p.0 == key }) {",
          "    Ok(#(_, value)) -> {",
          "      case int.parse(value) {",
          "        Ok(i) -> i",
          "        Error(_) -> default",
          "      }",
          "    }",
          "    Error(_) -> default",
          "  }",
          "}",
        ],
        "\n",
      ),
      ..helpers
    ]
    False -> helpers
  }

  // Query parameter getters
  let helpers = case needed.query_string {
    True -> [
      string.join(
        [
          "/// Get string query parameter with default",
          "fn get_query_param_string(",
          "  params: List(#(String, String)),",
          "  key: String,",
          "  default: String,",
          ") -> String {",
          "  case list.find(params, fn(p) { p.0 == key }) {",
          "    Ok(#(_, value)) -> value",
          "    Error(_) -> default",
          "  }",
          "}",
        ],
        "\n",
      ),
      ..helpers
    ]
    False -> helpers
  }

  let helpers = case needed.query_int {
    True -> [
      string.join(
        [
          "/// Get int query parameter with default",
          "fn get_query_param_int(",
          "  params: List(#(String, String)),",
          "  key: String,",
          "  default: Int,",
          ") -> Int {",
          "  case list.find(params, fn(p) { p.0 == key }) {",
          "    Ok(#(_, value)) -> {",
          "      case int.parse(value) {",
          "        Ok(i) -> i",
          "        Error(_) -> default",
          "      }",
          "    }",
          "    Error(_) -> default",
          "  }",
          "}",
        ],
        "\n",
      ),
      ..helpers
    ]
    False -> helpers
  }

  let helpers = case needed.query_bool {
    True -> [
      string.join(
        [
          "/// Get bool query parameter with default",
          "fn get_query_param_bool(",
          "  params: List(#(String, String)),",
          "  key: String,",
          "  default: Bool,",
          ") -> Bool {",
          "  case list.find(params, fn(p) { p.0 == key }) {",
          "    Ok(#(_, value)) -> {",
          "      case string.lowercase(value) {",
          "        \"true\" | \"1\" | \"yes\" -> True",
          "        \"false\" | \"0\" | \"no\" -> False",
          "        _ -> default",
          "      }",
          "    }",
          "    Error(_) -> default",
          "  }",
          "}",
        ],
        "\n",
      ),
      ..helpers
    ]
    False -> helpers
  }

  let helpers = case needed.query_float {
    True -> [
      string.join(
        [
          "/// Get float query parameter with default",
          "fn get_query_param_float(",
          "  params: List(#(String, String)),",
          "  key: String,",
          "  default: Float,",
          ") -> Float {",
          "  case list.find(params, fn(p) { p.0 == key }) {",
          "    Ok(#(_, value)) -> {",
          "      case float.parse(value) {",
          "        Ok(f) -> f",
          "        Error(_) -> default",
          "      }",
          "    }",
          "    Error(_) -> default",
          "  }",
          "}",
        ],
        "\n",
      ),
      ..helpers
    ]
    False -> helpers
  }

  let helpers = case needed.query_list_string {
    True -> [
      string.join(
        [
          "/// Get list of string query parameters",
          "fn get_query_param_list_string(",
          "  params: List(#(String, String)),",
          "  key: String,",
          ") -> List(String) {",
          "  params",
          "  |> list.filter(fn(p) { p.0 == key })",
          "  |> list.map(fn(p) { p.1 })",
          "}",
        ],
        "\n",
      ),
      ..helpers
    ]
    False -> helpers
  }

  let helpers = case needed.query_list_int {
    True -> [
      string.join(
        [
          "/// Get list of int query parameters",
          "fn get_query_param_list_int(",
          "  params: List(#(String, String)),",
          "  key: String,",
          ") -> List(Int) {",
          "  params",
          "  |> list.filter(fn(p) { p.0 == key })",
          "  |> list.filter_map(fn(p) { int.parse(p.1) })",
          "}",
        ],
        "\n",
      ),
      ..helpers
    ]
    False -> helpers
  }

  let helpers = case needed.query_optional_string {
    True -> [
      string.join(
        [
          "/// Get optional string query parameter",
          "fn get_query_param_optional_string(",
          "  params: List(#(String, String)),",
          "  key: String,",
          ") -> option.Option(String) {",
          "  case list.find(params, fn(p) { p.0 == key }) {",
          "    Ok(#(_, value)) -> option.Some(value)",
          "    Error(_) -> option.None",
          "  }",
          "}",
        ],
        "\n",
      ),
      ..helpers
    ]
    False -> helpers
  }

  let helpers = case needed.query_optional_int {
    True -> [
      string.join(
        [
          "/// Get optional int query parameter",
          "fn get_query_param_optional_int(",
          "  params: List(#(String, String)),",
          "  key: String,",
          ") -> option.Option(Int) {",
          "  case list.find(params, fn(p) { p.0 == key }) {",
          "    Ok(#(_, value)) -> {",
          "      case int.parse(value) {",
          "        Ok(i) -> option.Some(i)",
          "        Error(_) -> option.None",
          "      }",
          "    }",
          "    Error(_) -> option.None",
          "  }",
          "}",
        ],
        "\n",
      ),
      ..helpers
    ]
    False -> helpers
  }

  // Join all helpers with double newlines, or return empty string if none needed
  case helpers {
    [] -> ""
    _ -> string.join(list.reverse(helpers), "\n\n")
  }
}

/// Generate path and query parameter helper functions (deprecated - use conditional version)
fn generate_query_param_helpers() -> String {
  string.join(
    [
      "/// Extract path parameters from request path based on pattern",
      "/// Example: extract_path_params_from_request(\"/v1/temperatures/123\", \"/v1/temperatures/{id}\")",
      "///   returns [(\"id\", \"123\")]",
      "fn extract_path_params_from_request(path: String, pattern: String) -> List(#(String, String)) {",
      "  let path_segments = string.split(path, \"/\") |> list.filter(fn(s) { s != \"\" })",
      "  let pattern_segments = string.split(pattern, \"/\") |> list.filter(fn(s) { s != \"\" })",
      "  extract_params_from_segments(path_segments, pattern_segments, [])",
      "}",
      "",
      "/// Helper to extract parameters by matching path segments with pattern segments",
      "fn extract_params_from_segments(",
      "  path_segments: List(String),",
      "  pattern_segments: List(String),",
      "  acc: List(#(String, String)),",
      ") -> List(#(String, String)) {",
      "  case path_segments, pattern_segments {",
      "    [], _ -> list.reverse(acc)",
      "    _, [] -> list.reverse(acc)",
      "    [path_seg, ..path_rest], [pattern_seg, ..pattern_rest] -> {",
      "      case string.starts_with(pattern_seg, \"{\") && string.ends_with(pattern_seg, \"}\") {",
      "        True -> {",
      "          // This is a path parameter",
      "          let param_name = string.slice(pattern_seg, 1, string.length(pattern_seg) - 2) |> string.lowercase",
      "          extract_params_from_segments(path_rest, pattern_rest, [#(param_name, path_seg), ..acc])",
      "        }",
      "        False -> {",
      "          // This is a literal segment, skip",
      "          extract_params_from_segments(path_rest, pattern_rest, acc)",
      "        }",
      "      }",
      "    }",
      "  }",
      "}",
      "",
      "/// Get path parameter as string with default",
      "fn get_path_param_string(",
      "  params: List(#(String, String)),",
      "  key: String,",
      "  default: String,",
      ") -> String {",
      "  case list.find(params, fn(p) { p.0 == key }) {",
      "    Ok(#(_, value)) -> value",
      "    Error(_) -> default",
      "  }",
      "}",
      "",
      "/// Get path parameter as int with default",
      "fn get_path_param_int(",
      "  params: List(#(String, String)),",
      "  key: String,",
      "  default: Int,",
      ") -> Int {",
      "  case list.find(params, fn(p) { p.0 == key }) {",
      "    Ok(#(_, value)) -> {",
      "      case int.parse(value) {",
      "        Ok(i) -> i",
      "        Error(_) -> default",
      "      }",
      "    }",
      "    Error(_) -> default",
      "  }",
      "}",
      "",
      "/// Get string query parameter with default",
      "fn get_query_param_string(",
      "  params: List(#(String, String)),",
      "  key: String,",
      "  default: String,",
      ") -> String {",
      "  case list.find(params, fn(p) { p.0 == key }) {",
      "    Ok(#(_, value)) -> value",
      "    Error(_) -> default",
      "  }",
      "}",
      "",
      "/// Get int query parameter with default",
      "fn get_query_param_int(",
      "  params: List(#(String, String)),",
      "  key: String,",
      "  default: Int,",
      ") -> Int {",
      "  case list.find(params, fn(p) { p.0 == key }) {",
      "    Ok(#(_, value)) -> {",
      "      case int.parse(value) {",
      "        Ok(i) -> i",
      "        Error(_) -> default",
      "      }",
      "    }",
      "    Error(_) -> default",
      "  }",
      "}",
      "",
      "/// Get bool query parameter with default",
      "fn get_query_param_bool(",
      "  params: List(#(String, String)),",
      "  key: String,",
      "  default: Bool,",
      ") -> Bool {",
      "  case list.find(params, fn(p) { p.0 == key }) {",
      "    Ok(#(_, value)) -> {",
      "      case string.lowercase(value) {",
      "        \"true\" | \"1\" | \"yes\" -> True",
      "        \"false\" | \"0\" | \"no\" -> False",
      "        _ -> default",
      "      }",
      "    }",
      "    Error(_) -> default",
      "  }",
      "}",
      "",
      "/// Get float query parameter with default",
      "fn get_query_param_float(",
      "  params: List(#(String, String)),",
      "  key: String,",
      "  default: Float,",
      ") -> Float {",
      "  case list.find(params, fn(p) { p.0 == key }) {",
      "    Ok(#(_, value)) -> {",
      "      case float.parse(value) {",
      "        Ok(f) -> f",
      "        Error(_) -> default",
      "      }",
      "    }",
      "    Error(_) -> default",
      "  }",
      "}",
      "",
      "/// Get list of string query parameters",
      "fn get_query_param_list_string(",
      "  params: List(#(String, String)),",
      "  key: String,",
      ") -> List(String) {",
      "  params",
      "  |> list.filter(fn(p) { p.0 == key })",
      "  |> list.map(fn(p) { p.1 })",
      "}",
      "",
      "/// Get list of int query parameters",
      "fn get_query_param_list_int(",
      "  params: List(#(String, String)),",
      "  key: String,",
      ") -> List(Int) {",
      "  params",
      "  |> list.filter(fn(p) { p.0 == key })",
      "  |> list.filter_map(fn(p) { int.parse(p.1) })",
      "}",
      "",
      "/// Get optional string query parameter",
      "fn get_query_param_optional_string(",
      "  params: List(#(String, String)),",
      "  key: String,",
      ") -> option.Option(String) {",
      "  case list.find(params, fn(p) { p.0 == key }) {",
      "    Ok(#(_, value)) -> option.Some(value)",
      "    Error(_) -> option.None",
      "  }",
      "}",
      "",
      "/// Get optional int query parameter",
      "fn get_query_param_optional_int(",
      "  params: List(#(String, String)),",
      "  key: String,",
      ") -> option.Option(Int) {",
      "  case list.find(params, fn(p) { p.0 == key }) {",
      "    Ok(#(_, value)) -> {",
      "      case int.parse(value) {",
      "        Ok(i) -> option.Some(i)",
      "        Error(_) -> option.None",
      "      }",
      "    }",
      "    Error(_) -> option.None",
      "  }",
      "}",
    ],
    "\n",
  )
}

