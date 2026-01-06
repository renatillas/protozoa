//// Service Code Generation using Trick
////
//// This module generates transport-agnostic service code from Protocol Buffer
//// service definitions using the trick library for type-safe code generation.

import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/regexp
import gleam/string
import justin
import protozoa/internal/codegen/types.{type Context}
import protozoa/parser/proto.{type Field, type Message, type Method, type Service}
import trick

/// Generate the ServiceRequestError custom type definition
///
/// Example output for service "UserService":
/// ```gleam
/// pub type UserServiceRequestError {
///   UserServiceDecodeError(String)
///   UserServiceHandlerError(UserServiceError)
/// }
/// ```
pub fn generate_error_type_def(service: Service) -> trick.Definition {
  let handler_error_type = justin.pascal_case(service.name) <> "Error"
  let service_error_type = justin.pascal_case(service.name) <> "RequestError"
  let prefix = justin.pascal_case(service.name)

  // DecodeError variant: takes a String
  let decode_error_variant =
    trick.Variant(prefix <> "DecodeError", [
      trick.TypeField("", trick.Custom("gleam", "String", [])),
    ])

  // HandlerError variant: takes the handler error type
  let handler_error_variant =
    trick.Variant(prefix <> "HandlerError", [
      trick.TypeField("", trick.Custom("", handler_error_type, [])),
    ])

  trick.custom_type(
    trick.Public,
    service_error_type,
    [],
    [decode_error_variant, handler_error_variant],
    fn() { trick.empty() },
  )
}

/// Generate a service function definition
///
/// Example output for method "GetUser" in service "UserService":
/// ```gleam
/// pub fn get_user_service(
///   request_bytes: BitArray,
///   handler: fn(GetUserRequest) -> Result(GetUserResponse, UserServiceError),
/// ) -> Result(BitArray, UserServiceRequestError) {
///   case decode.run(request_bytes, with: get_user_request_decoder()) {
///     Ok(proto_request) -> {
///       case handler(proto_request) {
///         Ok(response) -> Ok(encode_get_user_response(response))
///         Error(err) -> Error(UserServiceHandlerError(err))
///       }
///     }
///     Error(_) -> Error(UserServiceDecodeError("Failed to decode GetUserRequest"))
///   }
/// }
/// ```
pub fn generate_service_fn_def(
  method: Method,
  service_name: String,
  ctx: Context,
) -> trick.Definition {
  let function_name = justin.snake_case(method.name) <> "_service"

  // Get qualified type names
  let request_type_qualified = types.qualified_type(method.input_type, ctx)
  let response_type_qualified = types.qualified_type(method.output_type, ctx)
  let request_fn_qualified = types.qualified_fn(method.input_type, ctx)
  let response_fn_qualified = types.qualified_fn(method.output_type, ctx)

  let handler_error_type = justin.pascal_case(service_name) <> "Error"
  let prefix = justin.pascal_case(service_name)

  let decoder_fn_name = request_fn_qualified <> "_decoder"
  let encoder_fn_name = "encode_" <> response_fn_qualified

  // Type for BitArray
  let bit_array_type = trick.Custom("gleam", "BitArray", [])

  // Type for the request message
  let request_type = trick.Custom("", request_type_qualified, [])

  // Type for the response message
  let response_type = trick.Custom("", response_type_qualified, [])

  // Type for the handler error
  let handler_error = trick.Custom("", handler_error_type, [])

  // Result type for handler: Result(Response, HandlerError)
  let handler_result_type =
    trick.Custom("gleam", "Result", [response_type, handler_error])

  // Handler function type: fn(Request) -> Result(Response, HandlerError)
  let handler_fn_type =
    trick.Function([request_type], handler_result_type, None)

  // Build the inner case expression (handler result processing)
  // case handler(proto_request) {
  //   Ok(response) -> Ok(encode_xxx(response))
  //   Error(err) -> Error(PrefixHandlerError(err))
  // }
  let inner_case_ok_body =
    trick.expression(trick.ext_call("Ok", [
      trick.ext_call(encoder_fn_name, [trick.ident("response", response_type)]),
    ]))

  let inner_case_error_body =
    trick.expression(trick.ext_call("Error", [
      trick.ext_call(prefix <> "HandlerError", [
        trick.ident("err", handler_error),
      ]),
    ]))

  let inner_case =
    trick.case_(
      trick.ext_call("handler", [trick.ident("proto_request", request_type)]),
      [
        trick.CaseBranch(
          trick.ConstructorPattern("Ok", [
            trick.PositionalPatternField(trick.VariablePattern("response")),
          ]),
          None,
          inner_case_ok_body,
        ),
        trick.CaseBranch(
          trick.ConstructorPattern("Error", [
            trick.PositionalPatternField(trick.VariablePattern("err")),
          ]),
          None,
          inner_case_error_body,
        ),
      ],
    )

  // Outer case Ok branch body - wraps the inner case in a block
  let outer_ok_body = trick.expression(trick.block(trick.expression(inner_case)))

  // Outer case Error branch body
  // Error(_) -> Error(PrefixDecodeError("Failed to decode Request"))
  let decode_error_msg = "Failed to decode " <> request_type_qualified
  let outer_error_body =
    trick.expression(trick.ext_call("Error", [
      trick.ext_call(prefix <> "DecodeError", [trick.string(decode_error_msg)]),
    ]))

  // Build the outer case expression
  // case decode.run(request_bytes, xxx_decoder()) {
  //   Ok(proto_request) -> { inner_case }
  //   Error(_) -> Error(PrefixDecodeError(...))
  // }
  let outer_case =
    trick.case_(
      trick.ext_call("decode.run", [
        trick.ident("request_bytes", bit_array_type),
        trick.ext_call(decoder_fn_name, []),
      ]),
      [
        trick.CaseBranch(
          trick.ConstructorPattern("Ok", [
            trick.PositionalPatternField(trick.VariablePattern("proto_request")),
          ]),
          None,
          outer_ok_body,
        ),
        trick.CaseBranch(
          trick.ConstructorPattern("Error", [
            trick.PositionalPatternField(trick.DiscardPattern),
          ]),
          None,
          outer_error_body,
        ),
      ],
    )

  // Build the function
  trick.pub_function(
    function_name,
    {
      use _request_bytes <- trick.parameter("request_bytes", bit_array_type)
      use _handler <- trick.parameter("handler", handler_fn_type)
      trick.function_body(trick.expression(outer_case))
    },
    fn(_) { trick.empty() },
  )
}

// =============================================================================
// HTTP Adapter Generation
// =============================================================================

/// Type for request.Request(BitArray)
fn http_request_type() -> trick.Type {
  trick.Custom("gleam/http/request", "Request", [
    trick.Custom("gleam", "BitArray", []),
  ])
}

/// Type for response.Response(BitArray)
fn http_response_type() -> trick.Type {
  trick.Custom("gleam/http/response", "Response", [
    trick.Custom("gleam", "BitArray", []),
  ])
}

/// Type for Result(a, b)
fn result_type(ok_type: trick.Type, err_type: trick.Type) -> trick.Type {
  trick.Custom("gleam", "Result", [ok_type, err_type])
}

/// Type for a custom type by name (for types defined in the generated module)
fn custom_type(name: String) -> trick.Type {
  trick.Custom("", name, [])
}

/// Type for handler function: fn(Request) -> Result(Response, Error)
fn http_handler_fn_type(
  request_type_name: String,
  response_type_name: String,
  error_type_name: String,
) -> trick.Type {
  trick.Function(
    [custom_type(request_type_name)],
    result_type(custom_type(response_type_name), custom_type(error_type_name)),
    None,
  )
}

/// Generate HTTP adapter function definition for a method
/// Returns None if the method has no HTTP annotation
///
/// HTTP adapters handle the translation between HTTP request/response and
/// the underlying service function.
pub fn generate_http_adapter_def(
  method: Method,
  service_name: String,
  ctx: Context,
  messages: List(Message),
) -> Option(trick.Definition) {
  case method.http_method, method.http_path {
    Some(http_method), Some(_path) -> {
      // Determine if this is body-based (POST/PUT/PATCH) or query-based (GET/DELETE)
      let reads_from_body = case http_method {
        proto.Post | proto.Put | proto.Patch -> True
        proto.Get | proto.Delete -> False
      }

      case reads_from_body {
        True -> Some(generate_body_based_http_adapter(method, service_name, ctx))
        False ->
          Some(generate_query_based_http_adapter(method, service_name, ctx, messages))
      }
    }
    _, _ -> None
  }
}

/// Generate HTTP adapter for body-based methods (POST/PUT/PATCH)
///
/// Example output for method "UpdateUser" in service "UserService" with path param:
/// ```gleam
/// pub fn http_update_user(
///   req: request.Request(BitArray),
///   user_id: String,  // path param from URL pattern
///   handler: fn(UpdateUserRequest) -> Result(UpdateUserResponse, UserServiceError),
/// ) -> Result(response.Response(BitArray), UserServiceRequestError) {
///   let request_bytes = req.body
///   case update_user_service(request_bytes, handler) {
///     Ok(response_bytes) ->
///       Ok(response.Response(
///         status: 200,
///         headers: [#("content-type", "application/x-protobuf")],
///         body: response_bytes,
///       ))
///     Error(service_error) -> Error(service_error)
///   }
/// }
/// ```
fn generate_body_based_http_adapter(
  method: Method,
  service_name: String,
  ctx: Context,
) -> trick.Definition {
  let function_name = "http_" <> justin.snake_case(method.name)
  let service_function_name = justin.snake_case(method.name) <> "_service"

  // Extract path parameters from HTTP path
  let path_params = case method.http_path {
    Some(path) -> extract_path_params(path)
    None -> []
  }

  // Get qualified type names
  let request_type_qualified = types.qualified_type(method.input_type, ctx)
  let response_type_qualified = types.qualified_type(method.output_type, ctx)

  let handler_error_type = justin.pascal_case(service_name) <> "Error"
  let service_error_type = justin.pascal_case(service_name) <> "RequestError"

  // Type definitions
  let bit_array_type = trick.Custom("gleam", "BitArray", [])

  // Build the service call case expression
  // case service_function(request_bytes, handler) {
  //   Ok(response_bytes) -> Ok(response.Response(...))
  //   Error(service_error) -> Error(service_error)
  // }
  let service_call_case =
    trick.case_(
      trick.ext_call(service_function_name, [
        trick.ident("request_bytes", bit_array_type),
        trick.ident(
          "handler",
          http_handler_fn_type(
            request_type_qualified,
            response_type_qualified,
            handler_error_type,
          ),
        ),
      ]),
      [
        // Ok(response_bytes) -> Ok(response.Response(...))
        trick.CaseBranch(
          pattern: trick.ConstructorPattern("Ok", [
            trick.PositionalPatternField(
              trick.VariablePattern("response_bytes"),
            ),
          ]),
          guard: None,
          body: trick.expression(
            trick.ext_call("Ok", [
              trick.constructor("response.Response", http_response_type(), [
                #("status", trick.int(200)),
                #(
                  "headers",
                  trick.list([
                    trick.tuple([
                      trick.string("content-type"),
                      trick.string("application/x-protobuf"),
                    ]),
                  ]),
                ),
                #("body", trick.ident("response_bytes", bit_array_type)),
              ]),
            ]),
          ),
        ),
        // Error(service_error) -> Error(service_error)
        trick.CaseBranch(
          pattern: trick.ConstructorPattern("Error", [
            trick.PositionalPatternField(
              trick.VariablePattern("service_error"),
            ),
          ]),
          guard: None,
          body: trick.expression(
            trick.ext_call("Error", [
              trick.ident("service_error", custom_type(service_error_type)),
            ]),
          ),
        ),
      ],
    )

  // Build the function body:
  // let request_bytes = req.body
  // case ... { ... }
  let function_body =
    trick.variable(
      "request_bytes",
      trick.field_access(trick.ident("req", http_request_type()), "body"),
      fn(_request_bytes) { trick.expression(service_call_case) },
    )

  // Build the function with path params as arguments
  trick.pub_function(
    function_name,
    build_http_adapter_params(
      path_params,
      request_type_qualified,
      response_type_qualified,
      handler_error_type,
      function_body,
    ),
    fn(_) { trick.empty() },
  )
}

/// Build function parameters for HTTP adapters with path params
/// Uses specific handling for 0, 1, 2, or 3 path params to avoid type recursion issues
fn build_http_adapter_params(
  path_params: List(String),
  request_type_qualified: String,
  response_type_qualified: String,
  handler_error_type: String,
  body: trick.Statement,
) {
  let handler_type =
    http_handler_fn_type(
      request_type_qualified,
      response_type_qualified,
      handler_error_type,
    )

  case path_params {
    [] -> {
      use _req <- trick.parameter("req", http_request_type())
      use _handler <- trick.parameter("handler", handler_type)
      trick.function_body(body)
    }
    [p1] -> {
      let n1 = justin.snake_case(p1)
      use _req <- trick.parameter("req", http_request_type())
      use _p1 <- trick.parameter(n1, type_string())
      use _handler <- trick.parameter("handler", handler_type)
      trick.function_body(body)
    }
    [p1, p2] -> {
      let n1 = justin.snake_case(p1)
      let n2 = justin.snake_case(p2)
      use _req <- trick.parameter("req", http_request_type())
      use _p1 <- trick.parameter(n1, type_string())
      use _p2 <- trick.parameter(n2, type_string())
      use _handler <- trick.parameter("handler", handler_type)
      trick.function_body(body)
    }
    [p1, p2, p3, ..] -> {
      // For 3+ path params, handle first 3
      let n1 = justin.snake_case(p1)
      let n2 = justin.snake_case(p2)
      let n3 = justin.snake_case(p3)
      use _req <- trick.parameter("req", http_request_type())
      use _p1 <- trick.parameter(n1, type_string())
      use _p2 <- trick.parameter(n2, type_string())
      use _p3 <- trick.parameter(n3, type_string())
      use _handler <- trick.parameter("handler", handler_type)
      trick.function_body(body)
    }
  }
}

/// Generate HTTP adapter for query-based methods (GET/DELETE)
///
/// Example output for method "GetTemperature" in service "TemperatureService":
/// ```gleam
/// pub fn http_get_temperature(
///   req: request.Request(BitArray),
///   sensor_id: String,  // path param from URL pattern
///   handler: fn(GetTemperatureRequest) -> Result(TemperatureResponse, TemperatureServiceError),
/// ) -> Result(response.Response(BitArray), TemperatureServiceRequestError) {
///   case request.get_query(req) {
///     Ok(query_params) -> {
///       let location = get_query_param_string(query_params, "location", "")
///       let include_history = get_query_param_bool(query_params, "include_history", False)
///       let proto_request = GetTemperatureRequest(
///         sensor_id: sensor_id,
///         location: location,
///         include_history: include_history,
///       )
///       let request_bytes = encode_get_temperature_request(proto_request)
///       case get_temperature_service(request_bytes, handler) {
///         Ok(response_bytes) ->
///           Ok(response.Response(
///             status: 200,
///             headers: [#("content-type", "application/x-protobuf")],
///             body: response_bytes,
///           ))
///         Error(service_error) -> Error(service_error)
///       }
///     }
///     Error(_) -> Error(TemperatureServiceDecodeError("Failed to parse query parameters"))
///   }
/// }
/// ```
fn generate_query_based_http_adapter(
  method: Method,
  service_name: String,
  ctx: Context,
  messages: List(Message),
) -> trick.Definition {
  let function_name = "http_" <> justin.snake_case(method.name)

  // Extract path parameters from HTTP path
  let path_params = case method.http_path {
    Some(path) -> extract_path_params(path)
    None -> []
  }

  // Get qualified type names
  let request_type_qualified = types.qualified_type(method.input_type, ctx)
  let response_type_qualified = types.qualified_type(method.output_type, ctx)

  let handler_error_type = justin.pascal_case(service_name) <> "Error"

  // Build the function body based on message definition
  let function_body =
    generate_query_adapter_body(method, service_name, path_params, messages, ctx)

  // Build the function with path params as arguments
  trick.pub_function(
    function_name,
    build_http_adapter_params(
      path_params,
      request_type_qualified,
      response_type_qualified,
      handler_error_type,
      function_body,
    ),
    fn(_) { trick.empty() },
  )
}

/// Generate the body for a query-based HTTP adapter
/// This inlines the request message construction and calls the handler directly (no encode/decode round-trip)
fn generate_query_adapter_body(
  method: Method,
  service_name: String,
  path_params: List(String),
  messages: List(Message),
  ctx: Context,
) -> trick.Statement {
  // Response encode function for encoding the handler's response
  let response_fn_qualified = types.qualified_fn(method.output_type, ctx)
  let response_encode_function_name = "encode_" <> response_fn_qualified

  let request_type_qualified = types.qualified_type(method.input_type, ctx)

  let prefix = justin.pascal_case(service_name)
  let handler_error_type = prefix <> "Error"
  let handler_error_constructor = prefix <> "HandlerError"
  let decode_error_constructor = prefix <> "DecodeError"

  // Find the message definition to know what fields to extract
  case list.find(messages, fn(msg) { msg.name == method.input_type }) {
    Ok(message) -> {
      // Build the Ok branch that constructs the request message and calls handler directly
      let ok_branch_body =
        generate_inline_request_construction(
          message,
          request_type_qualified,
          response_encode_function_name,
          path_params,
          handler_error_type,
          handler_error_constructor,
        )

      let error_branch_body =
        trick.expression(
          trick.ext_call("Error", [
            trick.ext_call(decode_error_constructor, [
              trick.string("Failed to parse query parameters"),
            ]),
          ]),
        )

      // case request.get_query(req) { Ok(query_params) -> {...}, Error(_) -> {...} }
      let outer_case =
        trick.case_(
          trick.ext_call("request.get_query", [
            trick.ident("req", http_request_type()),
          ]),
          [
            trick.CaseBranch(
              pattern: trick.ConstructorPattern("Ok", [
                trick.PositionalPatternField(
                  trick.VariablePattern("query_params"),
                ),
              ]),
              guard: None,
              // Wrap in a block to ensure proper formatting with multiple let bindings
              body: trick.expression(trick.block(ok_branch_body)),
            ),
            trick.CaseBranch(
              pattern: trick.ConstructorPattern("Error", [
                trick.PositionalPatternField(trick.DiscardPattern),
              ]),
              guard: None,
              body: error_branch_body,
            ),
          ],
        )

      trick.expression(outer_case)
    }
    Error(_) -> {
      // Fallback: empty request
      let error_expr =
        trick.ext_call("Error", [
          trick.ext_call(decode_error_constructor, [
            trick.string("Message definition not found"),
          ]),
        ])
      trick.expression(error_expr)
    }
  }
}

/// Generate the inline request construction code
/// This builds let bindings for each query field, then calls handler directly (no encode/decode round-trip)
fn generate_inline_request_construction(
  message: Message,
  message_type_qualified: String,
  response_encode_function_name: String,
  path_params: List(String),
  handler_error_type: String,
  handler_error_constructor: String,
) -> trick.Statement {
  // Separate fields into path params and query params
  let fields_with_source =
    list.map(message.fields, fn(field) {
      let field_name_lower = string.lowercase(field.name)
      let is_path_param =
        list.any(path_params, fn(param) {
          string.lowercase(param) == field_name_lower
        })
      #(field, is_path_param)
    })

  // Generate let bindings for query param fields only
  // Path params are already available as function arguments
  let query_fields =
    list.filter(fields_with_source, fn(pair) {
      let #(_, is_path_param) = pair
      !is_path_param
    })

  // Build the query field bindings and then call the handler directly
  generate_query_field_bindings(
    query_fields,
    message,
    message_type_qualified,
    response_encode_function_name,
    handler_error_type,
    handler_error_constructor,
  )
}

/// Recursively generate let bindings for query fields
fn generate_query_field_bindings(
  remaining_fields: List(#(Field, Bool)),
  message: Message,
  message_type_qualified: String,
  response_encode_function_name: String,
  handler_error_type: String,
  handler_error_constructor: String,
) -> trick.Statement {
  case remaining_fields {
    [] -> {
      // All query field bindings done, now construct the message and call handler directly
      generate_message_construction(
        message,
        message_type_qualified,
        response_encode_function_name,
        handler_error_type,
        handler_error_constructor,
      )
    }
    [#(field, _is_path_param), ..rest] -> {
      let field_name = justin.snake_case(field.name)
      let escaped_name = types.escape_keyword(field_name)
      let field_value = generate_query_field_value_inline(field)

      trick.variable(escaped_name, field_value, fn(_var) {
        generate_query_field_bindings(
          rest,
          message,
          message_type_qualified,
          response_encode_function_name,
          handler_error_type,
          handler_error_constructor,
        )
      })
    }
  }
}

/// Generate the value expression for a query field
fn generate_query_field_value_inline(
  field: Field,
) -> trick.Expression(trick.Variable) {
  let param_name = field.name
  let params_ident =
    trick.ident(
      "query_params",
      type_list(type_tuple2(type_string(), type_string())),
    )

  case field.field_type {
    proto.String ->
      trick.ext_call("get_query_param_string", [
        params_ident,
        trick.string(param_name),
        trick.string(""),
      ])

    proto.Int32
    | proto.Int64
    | proto.UInt32
    | proto.UInt64
    | proto.SInt32
    | proto.SInt64
    | proto.Fixed32
    | proto.Fixed64
    | proto.SFixed32
    | proto.SFixed64 ->
      trick.ext_call("get_query_param_int", [
        params_ident,
        trick.string(param_name),
        trick.int(0),
      ])

    proto.Bool ->
      trick.ext_call("get_query_param_bool", [
        params_ident,
        trick.string(param_name),
        trick.bool(False),
      ])

    proto.Float | proto.Double ->
      trick.ext_call("get_query_param_float", [
        params_ident,
        trick.string(param_name),
        trick.float(0.0),
      ])

    proto.Repeated(inner_type) -> {
      case inner_type {
        proto.String ->
          trick.ext_call("get_query_param_list_string", [
            params_ident,
            trick.string(param_name),
          ])
        proto.Int32
        | proto.Int64
        | proto.UInt32
        | proto.UInt64
        | proto.SInt32
        | proto.SInt64
        | proto.Fixed32
        | proto.Fixed64
        | proto.SFixed32
        | proto.SFixed64 ->
          trick.ext_call("get_query_param_list_int", [
            params_ident,
            trick.string(param_name),
          ])
        _ -> trick.list([])
      }
    }

    proto.Optional(inner_type) -> {
      case inner_type {
        proto.String ->
          trick.ext_call("get_query_param_optional_string", [
            params_ident,
            trick.string(param_name),
          ])
        proto.Int32
        | proto.Int64
        | proto.UInt32
        | proto.UInt64
        | proto.SInt32
        | proto.SInt64
        | proto.Fixed32
        | proto.Fixed64
        | proto.SFixed32
        | proto.SFixed64 ->
          trick.ext_call("get_query_param_optional_int", [
            params_ident,
            trick.string(param_name),
          ])
        _ -> trick.ident("option.None", type_option(type_string()))
      }
    }

    proto.Bytes -> trick.empty_bit_array()

    proto.MessageType(_) ->
      trick.todo_(Some(trick.string("Message types require nested object handling")))

    proto.EnumType(_) -> trick.int(0)

    proto.Map(_, _) -> trick.ext_call("dict.new", [])
  }
}

/// Generate the message constructor and call handler directly (no encode/decode round-trip)
fn generate_message_construction(
  message: Message,
  message_type_qualified: String,
  response_encode_function_name: String,
  handler_error_type: String,
  handler_error_constructor: String,
) -> trick.Statement {
  // Build constructor fields
  let constructor_fields =
    list.map(message.fields, fn(field) {
      let field_name = justin.snake_case(field.name)
      let escaped_name = types.escape_keyword(field_name)
      // Both path params and query params use their escaped name as identifier
      // Path params come from function arguments, query params from let bindings
      let field_type = proto_type_to_trick_type(field.field_type)
      #(escaped_name, trick.ident(escaped_name, field_type))
    })

  let constructor_type = trick.Custom("", message_type_qualified, [])

  // let proto_request = MessageType(field1: field1, field2: field2, ...)
  trick.variable(
    "proto_request",
    trick.constructor(message_type_qualified, constructor_type, constructor_fields),
    fn(proto_request) {
      // case handler(proto_request) {
      //   Ok(response) -> Ok(Response(status: 200, ..., body: encode_response(response)))
      //   Error(err) -> Error(ServiceHandlerError(err))
      // }
      let handler_call_case =
        trick.case_(
          trick.ext_call("handler", [proto_request]),
          [
            // Ok(response) -> Ok(Response(...body: encode_response(response)))
            trick.CaseBranch(
              pattern: trick.ConstructorPattern("Ok", [
                trick.PositionalPatternField(trick.VariablePattern("response")),
              ]),
              guard: None,
              body: trick.expression(trick.block(
                trick.variable(
                  "response_bytes",
                  trick.ext_call(response_encode_function_name, [
                    trick.ident("response", trick.Custom("", "", [])),
                  ]),
                  fn(response_bytes) {
                    trick.expression(
                      trick.ext_call("Ok", [
                        trick.constructor("response.Response", http_response_type(), [
                          #("status", trick.int(200)),
                          #(
                            "headers",
                            trick.list([
                              trick.tuple([
                                trick.string("content-type"),
                                trick.string("application/x-protobuf"),
                              ]),
                            ]),
                          ),
                          #("body", response_bytes),
                        ]),
                      ]),
                    )
                  },
                ),
              )),
            ),
            // Error(err) -> Error(ServiceHandlerError(err))
            trick.CaseBranch(
              pattern: trick.ConstructorPattern("Error", [
                trick.PositionalPatternField(trick.VariablePattern("err")),
              ]),
              guard: None,
              body: trick.expression(
                trick.ext_call("Error", [
                  trick.ext_call(handler_error_constructor, [
                    trick.ident("err", custom_type(handler_error_type)),
                  ]),
                ]),
              ),
            ),
          ],
        )
      trick.expression(handler_call_case)
    },
  )
}

/// Convert a Definition to a string, handling errors
pub fn definition_to_string(
  def: trick.Definition,
) -> Result(String, trick.Error) {
  trick.to_string(def)
}

// =============================================================================
// Type for tracking needed helpers
// =============================================================================

/// Type for tracking which query helper functions are needed
/// Note: Path params are now passed as function arguments, so no path helpers needed
pub type NeededHelpers {
  NeededHelpers(
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

/// Initial empty NeededHelpers
pub fn empty_needed_helpers() -> NeededHelpers {
  NeededHelpers(
    query_string: False,
    query_int: False,
    query_bool: False,
    query_float: False,
    query_list_string: False,
    query_list_int: False,
    query_optional_string: False,
    query_optional_int: False,
  )
}

/// Merge two NeededHelpers by OR-ing all fields
pub fn merge_needed_helpers(a: NeededHelpers, b: NeededHelpers) -> NeededHelpers {
  NeededHelpers(
    query_string: a.query_string || b.query_string,
    query_int: a.query_int || b.query_int,
    query_bool: a.query_bool || b.query_bool,
    query_float: a.query_float || b.query_float,
    query_list_string: a.query_list_string || b.query_list_string,
    query_list_int: a.query_list_int || b.query_list_int,
    query_optional_string: a.query_optional_string || b.query_optional_string,
    query_optional_int: a.query_optional_int || b.query_optional_int,
  )
}

// =============================================================================
// Additional Type Helpers for Query Helpers
// =============================================================================

fn type_string() -> trick.Type {
  trick.Custom("gleam", "String", [])
}

fn type_int() -> trick.Type {
  trick.Custom("gleam", "Int", [])
}

fn type_bool() -> trick.Type {
  trick.Custom("gleam", "Bool", [])
}

fn type_float() -> trick.Type {
  trick.Custom("gleam", "Float", [])
}

fn type_list(element: trick.Type) -> trick.Type {
  trick.Custom("gleam", "List", [element])
}

fn type_option(element: trick.Type) -> trick.Type {
  trick.Custom("gleam/option", "Option", [element])
}

fn type_tuple2(a: trick.Type, b: trick.Type) -> trick.Type {
  trick.Tuple([a, b])
}


fn type_bit_array() -> trick.Type {
  trick.Custom("gleam", "BitArray", [])
}

/// Convert a proto field type to the corresponding trick type
fn proto_type_to_trick_type(field_type: proto.Type) -> trick.Type {
  case field_type {
    proto.String -> type_string()
    proto.Int32
    | proto.Int64
    | proto.UInt32
    | proto.UInt64
    | proto.SInt32
    | proto.SInt64
    | proto.Fixed32
    | proto.Fixed64
    | proto.SFixed32
    | proto.SFixed64 -> type_int()
    proto.Bool -> type_bool()
    proto.Float | proto.Double -> type_float()
    proto.Bytes -> type_bit_array()
    proto.Repeated(inner) -> type_list(proto_type_to_trick_type(inner))
    proto.Optional(inner) -> type_option(proto_type_to_trick_type(inner))
    proto.Map(key, value) ->
      trick.Custom("gleam/dict", "Dict", [
        proto_type_to_trick_type(key),
        proto_type_to_trick_type(value),
      ])
    proto.MessageType(name) -> trick.Custom("", name, [])
    proto.EnumType(_) -> type_int()
  }
}

// =============================================================================
// Extract path parameters from URL pattern
// =============================================================================

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

// =============================================================================
// Query Parameter Helpers
// =============================================================================

/// Generate get_query_param_string helper
pub fn generate_query_string_helper() -> trick.Definition {
  let params_type = type_list(type_tuple2(type_string(), type_string()))

  trick.function(
    "get_query_param_string",
    {
      use _params <- trick.parameter("params", params_type)
      use _key <- trick.parameter("key", type_string())
      use _default <- trick.parameter("default", type_string())

      // Use trick.ident to reference parameters by name inside expressions
      let params_ref = trick.ident("params", params_type)
      let key_ref = trick.ident("key", type_string())
      let default_ref = trick.ident("default", type_string())

      let find_call = trick.ext_call("list.find", [
        params_ref,
        trick.anonymous({
          use _p <- trick.parameter("p", type_tuple2(type_string(), type_string()))
          let p_ref = trick.ident("p", type_tuple2(type_string(), type_string()))
          trick.function_body(trick.expression(
            trick.equal(trick.tuple_index(p_ref, 0), key_ref),
          ))
        }),
      ])

      let ok_branch = trick.CaseBranch(
        trick.ConstructorPattern("Ok", [
          trick.PositionalPatternField(
            trick.TuplePattern([
              trick.DiscardPattern,
              trick.VariablePattern("value"),
            ]),
          ),
        ]),
        None,
        trick.expression(trick.ident("value", type_string())),
      )

      let error_branch = trick.CaseBranch(
        trick.ConstructorPattern("Error", [
          trick.PositionalPatternField(trick.DiscardPattern),
        ]),
        None,
        trick.expression(default_ref),
      )

      trick.function_body(trick.expression(trick.case_(find_call, [ok_branch, error_branch])))
    },
    fn(_) { trick.empty() },
  )
}

/// Generate get_query_param_int helper
pub fn generate_query_int_helper() -> trick.Definition {
  let params_type = type_list(type_tuple2(type_string(), type_string()))

  trick.function(
    "get_query_param_int",
    {
      use params <- trick.parameter("params", params_type)
      use key <- trick.parameter("key", type_string())
      use default <- trick.parameter("default", type_int())

      let find_call = trick.ext_call("list.find", [
        params,
        trick.anonymous({
          use p <- trick.parameter("p", type_tuple2(type_string(), type_string()))
          trick.function_body(trick.expression(
            trick.equal(trick.tuple_index(p, 0), key),
          ))
        }),
      ])

      let ok_branch = trick.CaseBranch(
        trick.ConstructorPattern("Ok", [
          trick.PositionalPatternField(
            trick.TuplePattern([
              trick.DiscardPattern,
              trick.VariablePattern("value"),
            ]),
          ),
        ]),
        None,
        {
          let parse_call = trick.ext_call("int.parse", [
            trick.ident("value", type_string()),
          ])

          let parse_ok = trick.CaseBranch(
            trick.ConstructorPattern("Ok", [
              trick.PositionalPatternField(trick.VariablePattern("i")),
            ]),
            None,
            trick.expression(trick.ident("i", type_int())),
          )

          let parse_error = trick.CaseBranch(
            trick.ConstructorPattern("Error", [
              trick.PositionalPatternField(trick.DiscardPattern),
            ]),
            None,
            trick.expression(default),
          )

          trick.expression(trick.case_(parse_call, [parse_ok, parse_error]))
        },
      )

      let error_branch = trick.CaseBranch(
        trick.ConstructorPattern("Error", [
          trick.PositionalPatternField(trick.DiscardPattern),
        ]),
        None,
        trick.expression(default),
      )

      trick.function_body(trick.expression(trick.case_(find_call, [ok_branch, error_branch])))
    },
    fn(_) { trick.empty() },
  )
}

/// Generate get_query_param_bool helper
pub fn generate_query_bool_helper() -> trick.Definition {
  let params_type = type_list(type_tuple2(type_string(), type_string()))

  trick.function(
    "get_query_param_bool",
    {
      use params <- trick.parameter("params", params_type)
      use key <- trick.parameter("key", type_string())
      use default <- trick.parameter("default", type_bool())

      let find_call = trick.ext_call("list.find", [
        params,
        trick.anonymous({
          use p <- trick.parameter("p", type_tuple2(type_string(), type_string()))
          trick.function_body(trick.expression(
            trick.equal(trick.tuple_index(p, 0), key),
          ))
        }),
      ])

      let ok_branch = trick.CaseBranch(
        trick.ConstructorPattern("Ok", [
          trick.PositionalPatternField(
            trick.TuplePattern([
              trick.DiscardPattern,
              trick.VariablePattern("value"),
            ]),
          ),
        ]),
        None,
        {
          // case string.lowercase(value) { ... }
          let lowercase_call = trick.ext_call("string.lowercase", [
            trick.ident("value", type_string()),
          ])

          // Use guards to check for true/false values
          let true_branch = trick.CaseBranch(
            trick.VariablePattern("s"),
            Some(trick.or(
              trick.or(
                trick.equal(trick.ident("s", type_string()), trick.string("true")),
                trick.equal(trick.ident("s", type_string()), trick.string("1")),
              ),
              trick.equal(trick.ident("s", type_string()), trick.string("yes")),
            )),
            trick.expression(trick.bool(True)),
          )

          let false_branch = trick.CaseBranch(
            trick.VariablePattern("s"),
            Some(trick.or(
              trick.or(
                trick.equal(trick.ident("s", type_string()), trick.string("false")),
                trick.equal(trick.ident("s", type_string()), trick.string("0")),
              ),
              trick.equal(trick.ident("s", type_string()), trick.string("no")),
            )),
            trick.expression(trick.bool(False)),
          )

          let default_branch = trick.CaseBranch(
            trick.DiscardPattern,
            None,
            trick.expression(default),
          )

          trick.expression(trick.case_(lowercase_call, [true_branch, false_branch, default_branch]))
        },
      )

      let error_branch = trick.CaseBranch(
        trick.ConstructorPattern("Error", [
          trick.PositionalPatternField(trick.DiscardPattern),
        ]),
        None,
        trick.expression(default),
      )

      trick.function_body(trick.expression(trick.case_(find_call, [ok_branch, error_branch])))
    },
    fn(_) { trick.empty() },
  )
}

/// Generate get_query_param_float helper
pub fn generate_query_float_helper() -> trick.Definition {
  let params_type = type_list(type_tuple2(type_string(), type_string()))

  trick.function(
    "get_query_param_float",
    {
      use params <- trick.parameter("params", params_type)
      use key <- trick.parameter("key", type_string())
      use default <- trick.parameter("default", type_float())

      let find_call = trick.ext_call("list.find", [
        params,
        trick.anonymous({
          use p <- trick.parameter("p", type_tuple2(type_string(), type_string()))
          trick.function_body(trick.expression(
            trick.equal(trick.tuple_index(p, 0), key),
          ))
        }),
      ])

      let ok_branch = trick.CaseBranch(
        trick.ConstructorPattern("Ok", [
          trick.PositionalPatternField(
            trick.TuplePattern([
              trick.DiscardPattern,
              trick.VariablePattern("value"),
            ]),
          ),
        ]),
        None,
        {
          let parse_call = trick.ext_call("float.parse", [
            trick.ident("value", type_string()),
          ])

          let parse_ok = trick.CaseBranch(
            trick.ConstructorPattern("Ok", [
              trick.PositionalPatternField(trick.VariablePattern("f")),
            ]),
            None,
            trick.expression(trick.ident("f", type_float())),
          )

          let parse_error = trick.CaseBranch(
            trick.ConstructorPattern("Error", [
              trick.PositionalPatternField(trick.DiscardPattern),
            ]),
            None,
            trick.expression(default),
          )

          trick.expression(trick.case_(parse_call, [parse_ok, parse_error]))
        },
      )

      let error_branch = trick.CaseBranch(
        trick.ConstructorPattern("Error", [
          trick.PositionalPatternField(trick.DiscardPattern),
        ]),
        None,
        trick.expression(default),
      )

      trick.function_body(trick.expression(trick.case_(find_call, [ok_branch, error_branch])))
    },
    fn(_) { trick.empty() },
  )
}

/// Generate get_query_param_list_string helper
pub fn generate_query_list_string_helper() -> trick.Definition {
  let params_type = type_list(type_tuple2(type_string(), type_string()))

  trick.function(
    "get_query_param_list_string",
    {
      use params <- trick.parameter("params", params_type)
      use key <- trick.parameter("key", type_string())

      // params |> list.filter(fn(p) { p.0 == key }) |> list.map(fn(p) { p.1 })
      let filter_call = trick.ext_call("list.filter", [
        params,
        trick.anonymous({
          use p <- trick.parameter("p", type_tuple2(type_string(), type_string()))
          trick.function_body(trick.expression(
            trick.equal(trick.tuple_index(p, 0), key),
          ))
        }),
      ])

      let map_call = trick.ext_call("list.map", [
        filter_call,
        trick.anonymous({
          use p <- trick.parameter("p", type_tuple2(type_string(), type_string()))
          trick.function_body(trick.expression(trick.tuple_index(p, 1)))
        }),
      ])

      trick.function_body(trick.expression(map_call))
    },
    fn(_) { trick.empty() },
  )
}

/// Generate get_query_param_list_int helper
pub fn generate_query_list_int_helper() -> trick.Definition {
  let params_type = type_list(type_tuple2(type_string(), type_string()))

  trick.function(
    "get_query_param_list_int",
    {
      use params <- trick.parameter("params", params_type)
      use key <- trick.parameter("key", type_string())

      // params |> list.filter(fn(p) { p.0 == key }) |> list.filter_map(fn(p) { int.parse(p.1) })
      let filter_call = trick.ext_call("list.filter", [
        params,
        trick.anonymous({
          use p <- trick.parameter("p", type_tuple2(type_string(), type_string()))
          trick.function_body(trick.expression(
            trick.equal(trick.tuple_index(p, 0), key),
          ))
        }),
      ])

      let filter_map_call = trick.ext_call("list.filter_map", [
        filter_call,
        trick.anonymous({
          use p <- trick.parameter("p", type_tuple2(type_string(), type_string()))
          trick.function_body(trick.expression(
            trick.ext_call("int.parse", [trick.tuple_index(p, 1)]),
          ))
        }),
      ])

      trick.function_body(trick.expression(filter_map_call))
    },
    fn(_) { trick.empty() },
  )
}

/// Generate get_query_param_optional_string helper
pub fn generate_query_optional_string_helper() -> trick.Definition {
  let params_type = type_list(type_tuple2(type_string(), type_string()))

  trick.function(
    "get_query_param_optional_string",
    {
      use params <- trick.parameter("params", params_type)
      use key <- trick.parameter("key", type_string())

      let find_call = trick.ext_call("list.find", [
        params,
        trick.anonymous({
          use p <- trick.parameter("p", type_tuple2(type_string(), type_string()))
          trick.function_body(trick.expression(
            trick.equal(trick.tuple_index(p, 0), key),
          ))
        }),
      ])

      let ok_branch = trick.CaseBranch(
        trick.ConstructorPattern("Ok", [
          trick.PositionalPatternField(
            trick.TuplePattern([
              trick.DiscardPattern,
              trick.VariablePattern("value"),
            ]),
          ),
        ]),
        None,
        trick.expression(trick.ext_call("option.Some", [
          trick.ident("value", type_string()),
        ])),
      )

      let error_branch = trick.CaseBranch(
        trick.ConstructorPattern("Error", [
          trick.PositionalPatternField(trick.DiscardPattern),
        ]),
        None,
        trick.expression(trick.ident("option.None", type_option(type_string()))),
      )

      trick.function_body(trick.expression(trick.case_(find_call, [ok_branch, error_branch])))
    },
    fn(_) { trick.empty() },
  )
}

/// Generate get_query_param_optional_int helper
pub fn generate_query_optional_int_helper() -> trick.Definition {
  let params_type = type_list(type_tuple2(type_string(), type_string()))

  trick.function(
    "get_query_param_optional_int",
    {
      use params <- trick.parameter("params", params_type)
      use key <- trick.parameter("key", type_string())

      let find_call = trick.ext_call("list.find", [
        params,
        trick.anonymous({
          use p <- trick.parameter("p", type_tuple2(type_string(), type_string()))
          trick.function_body(trick.expression(
            trick.equal(trick.tuple_index(p, 0), key),
          ))
        }),
      ])

      let ok_branch = trick.CaseBranch(
        trick.ConstructorPattern("Ok", [
          trick.PositionalPatternField(
            trick.TuplePattern([
              trick.DiscardPattern,
              trick.VariablePattern("value"),
            ]),
          ),
        ]),
        None,
        {
          let parse_call = trick.ext_call("int.parse", [
            trick.ident("value", type_string()),
          ])

          let parse_ok = trick.CaseBranch(
            trick.ConstructorPattern("Ok", [
              trick.PositionalPatternField(trick.VariablePattern("i")),
            ]),
            None,
            trick.expression(trick.ext_call("option.Some", [
              trick.ident("i", type_int()),
            ])),
          )

          let parse_error = trick.CaseBranch(
            trick.ConstructorPattern("Error", [
              trick.PositionalPatternField(trick.DiscardPattern),
            ]),
            None,
            trick.expression(trick.ident("option.None", type_option(type_int()))),
          )

          trick.expression(trick.case_(parse_call, [parse_ok, parse_error]))
        },
      )

      let error_branch = trick.CaseBranch(
        trick.ConstructorPattern("Error", [
          trick.PositionalPatternField(trick.DiscardPattern),
        ]),
        None,
        trick.expression(trick.ident("option.None", type_option(type_int()))),
      )

      trick.function_body(trick.expression(trick.case_(find_call, [ok_branch, error_branch])))
    },
    fn(_) { trick.empty() },
  )
}

// =============================================================================
// Conditional Helper Generation (String-based for performance)
// =============================================================================

/// Generate all query helpers that are needed based on analysis
pub fn generate_query_helpers_string(needed: NeededHelpers) -> String {
  // Collect trick-based query helpers
  let trick_helpers = []

  let trick_helpers = case needed.query_string {
    True -> [generate_query_string_helper(), ..trick_helpers]
    False -> trick_helpers
  }

  let trick_helpers = case needed.query_int {
    True -> [generate_query_int_helper(), ..trick_helpers]
    False -> trick_helpers
  }

  let trick_helpers = case needed.query_bool {
    True -> [generate_query_bool_helper(), ..trick_helpers]
    False -> trick_helpers
  }

  let trick_helpers = case needed.query_float {
    True -> [generate_query_float_helper(), ..trick_helpers]
    False -> trick_helpers
  }

  let trick_helpers = case needed.query_list_string {
    True -> [generate_query_list_string_helper(), ..trick_helpers]
    False -> trick_helpers
  }

  let trick_helpers = case needed.query_list_int {
    True -> [generate_query_list_int_helper(), ..trick_helpers]
    False -> trick_helpers
  }

  let trick_helpers = case needed.query_optional_string {
    True -> [generate_query_optional_string_helper(), ..trick_helpers]
    False -> trick_helpers
  }

  let trick_helpers = case needed.query_optional_int {
    True -> [generate_query_optional_int_helper(), ..trick_helpers]
    False -> trick_helpers
  }

  // Convert trick helpers to strings
  trick_helpers
  |> list.reverse
  |> list.filter_map(trick.to_string)
  |> string.join("\n\n")
}

// =============================================================================
// Analysis and Main Router Generation
// =============================================================================

/// Analyze which helper functions are needed based on the service methods
/// Note: Path params are now passed as function arguments, so we only analyze query params
pub fn analyze_needed_helpers(
  service: Service,
  messages: List(Message),
) -> NeededHelpers {
  let initial = empty_needed_helpers()

  list.fold(service.methods, initial, fn(acc, method) {
    case method.http_method {
      Some(proto.Get) | Some(proto.Delete) -> {
        case list.find(messages, fn(msg) { msg.name == method.input_type }) {
          Ok(message) -> {
            // Get path params to exclude them from query param analysis
            let path_params = case method.http_path {
              Some(path) -> extract_path_params(path)
              None -> []
            }

            // Only analyze query params (not path params)
            list.fold(message.fields, acc, fn(field_acc, field) {
              let field_name_lower = string.lowercase(field.name)
              let is_path_param =
                list.any(path_params, fn(param) {
                  string.lowercase(param) == field_name_lower
                })

              case is_path_param {
                // Path params are function arguments, no helpers needed
                True -> field_acc
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

fn analyze_query_param_type(
  field_type: proto.Type,
  acc: NeededHelpers,
) -> NeededHelpers {
  case field_type {
    proto.String -> NeededHelpers(..acc, query_string: True)
    proto.Int32
    | proto.Int64
    | proto.UInt32
    | proto.UInt64
    | proto.SInt32
    | proto.SInt64
    | proto.Fixed32
    | proto.Fixed64
    | proto.SFixed32
    | proto.SFixed64 -> NeededHelpers(..acc, query_int: True)
    proto.Bool -> NeededHelpers(..acc, query_bool: True)
    proto.Float | proto.Double -> NeededHelpers(..acc, query_float: True)
    proto.Repeated(inner) -> {
      case inner {
        proto.String -> NeededHelpers(..acc, query_list_string: True)
        proto.Int32
        | proto.Int64
        | proto.UInt32
        | proto.UInt64
        | proto.SInt32
        | proto.SInt64
        | proto.Fixed32
        | proto.Fixed64
        | proto.SFixed32
        | proto.SFixed64 -> NeededHelpers(..acc, query_list_int: True)
        _ -> acc
      }
    }
    proto.Optional(inner) -> {
      case inner {
        proto.String -> NeededHelpers(..acc, query_optional_string: True)
        proto.Int32
        | proto.Int64
        | proto.UInt32
        | proto.UInt64
        | proto.SInt32
        | proto.SInt64
        | proto.Fixed32
        | proto.Fixed64
        | proto.SFixed32
        | proto.SFixed64 -> NeededHelpers(..acc, query_optional_int: True)
        _ -> acc
      }
    }
    _ -> acc
  }
}

/// Main router generation function - generates all service code
pub fn generate_router(
  service: Service,
  messages: List(Message),
  ctx: Context,
) -> String {
  case service.methods {
    [] -> ""
    methods -> {
      // Generate error type definition
      let error_type_def = generate_error_type_def(service)

      // Generate service functions (Layer 1)
      let service_fn_defs =
        list.map(methods, fn(m) {
          generate_service_fn_def(m, service.name, ctx)
        })

      // Generate HTTP adapters (Layer 2) for methods with HTTP annotations
      // Path params are now function arguments, query params are inlined
      let http_adapter_defs =
        methods
        |> list.filter(has_http_annotation)
        |> list.filter_map(fn(m) {
          case generate_http_adapter_def(m, service.name, ctx, messages) {
            Some(def) -> Ok(def)
            None -> Error(Nil)
          }
        })

      // Combine trick definitions (error type, service fns, HTTP adapters)
      let trick_defs =
        list.flatten([
          [error_type_def],
          service_fn_defs,
          http_adapter_defs,
        ])

      // Convert trick definitions to strings
      let trick_code_parts =
        trick_defs
        |> list.filter_map(trick.to_string)

      // Add header comment
      let header =
        "/// Auto-generated service for "
        <> service.name
        <> "\n/// \n/// Layer 1: Core service functions (transport-agnostic BitArray -> Result)\n/// Layer 2: HTTP adapters (gleam/http types, returns Result for middleware)\n/// \n/// HTTP adapters return Result(Response, ServiceError) for middleware pattern"

      case trick_code_parts {
        [] -> ""
        parts -> header <> "\n\n" <> string.join(parts, "\n\n")
      }
    }
  }
}

fn has_http_annotation(method: Method) -> Bool {
  case method.http_method, method.http_path {
    Some(_), Some(_) -> True
    _, _ -> False
  }
}
