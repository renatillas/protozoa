//// Protocol Buffer Parser Module
////
//// This module provides parsing functionality for Protocol Buffer (.proto) files.
//// It transforms proto3 syntax text into structured Gleam data types that can be
//// used for code generation and type analysis.
////
//// ## Capabilities
////
//// - **Full proto3 syntax support**: Messages, enums, services, fields, imports, packages
//// - **Nested structures**: Supports nested messages and enums within messages  
//// - **Advanced features**: Oneofs, maps, repeated fields, optional fields, field options
//// - **Service definitions**: Parses RPC services with method definitions and streaming support
//// - **Import handling**: Parses import statements (public, weak, regular)
//// - **Robust parsing**: Handles comments, whitespace, and malformed input gracefully
//// - **Type definitions**: Comprehensive type system covering all proto3 types
////
//// ## Main Function
////
//// The primary entry point is `parse()` which takes raw proto file content as a string
//// and returns a structured `ProtoFile` representation. All other types in this module
//// are internal data structures used to represent the parsed content.
////
//// ## Proto3 Support
////
//// Supported proto3 features:
//// - Messages with fields (scalar types, message types, enums)
//// - Nested messages and enums  
//// - Oneof groups for union types
//// - Repeated fields for arrays/lists
//// - Map fields for key-value pairs
//// - Service definitions with RPC methods
//// - Streaming RPC support (client, server, bidirectional)
//// - Field options (deprecated, json_name, packed)
//// - Import statements with search path resolution
//// - Package declarations for namespacing
//// - Field numbers and naming
////
//// ## Limitations
////
//// - Only proto3 syntax (no proto2)
//// - No service definitions (RPC)  
//// - Basic comment handling (strips // comments)
//// - Limited validation (focuses on structure over semantics)

import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/set
import gleam/string

pub type Path {
  Path(path: String, content: ProtoFile)
}

pub type ParseError {
  InvalidSyntax(line: String, reason: String)
  MissingRequiredSyntax(String)
  InvalidFieldNumber(field: String, number: String)
  DuplicateFieldNumber(message: String, number: Int)
  MalformedField(line: String)
  MalformedMessage(line: String)
  MalformedEnum(line: String)
  InvalidMapType(line: String)
  EmptyMessage(name: String)
}

pub fn describe_parse_error(error: ParseError) -> String {
  case error {
    InvalidSyntax(line, reason) ->
      "Invalid syntax on line '" <> line <> "': " <> reason
    MissingRequiredSyntax(element) ->
      "Missing required " <> element <> " declaration"
    InvalidFieldNumber(field, number) ->
      "Invalid field number '"
      <> number
      <> "' for field '"
      <> field
      <> "'. Field numbers must be positive integers."
    DuplicateFieldNumber(message, number) ->
      "Duplicate field number "
      <> int.to_string(number)
      <> " in message '"
      <> message
      <> "'"
    MalformedField(line) -> "Malformed field definition: '" <> line <> "'"
    MalformedMessage(line) -> "Malformed message definition: '" <> line <> "'"
    MalformedEnum(line) -> "Malformed enum definition: '" <> line <> "'"
    InvalidMapType(line) -> "Invalid map type definition: '" <> line <> "'"
    EmptyMessage(name) -> "Message '" <> name <> "' is empty and has no fields"
  }
}

/// Represents the different types that can be used in Protocol Buffer definitions.
pub type ProtoType {
  Double
  Float
  Int32
  Int64
  UInt32
  UInt64
  SInt32
  SInt64
  Fixed32
  Fixed64
  SFixed32
  SFixed64
  Bool
  String
  Bytes
  MessageType(String)
  EnumType(String)
  Repeated(ProtoType)
  Optional(ProtoType)
  Map(ProtoType, ProtoType)
}

/// Represents a field option in a Protocol Buffer field definition.
pub type FieldOption {
  Deprecated(Bool)
  JsonName(String)
  Packed(Bool)
}

/// Represents a field in a Protocol Buffer message.
pub type Field {
  Field(
    name: String,
    field_type: ProtoType,
    number: Int,
    oneof_name: Option(String),
    options: List(FieldOption),
  )
}

/// Represents a value in a Protocol Buffer enum.
@internal
pub type EnumValue {
  EnumValue(name: String, number: Int)
}

/// Represents a Protocol Buffer enum definition.
pub type Enum {
  Enum(name: String, values: List(EnumValue))
}

/// Represents a oneof group in a Protocol Buffer message.
/// Only one field in the group can be set at a time.
pub type Oneof {
  Oneof(name: String, fields: List(Field))
}

/// Represents a Protocol Buffer message definition.
pub type Message {
  Message(
    name: String,
    fields: List(Field),
    oneofs: List(Oneof),
    nested_messages: List(Message),
    enums: List(Enum),
  )
}

pub type Import {
  Import(path: String, public: Bool, weak: Bool)
}

/// Represents an RPC method in a Protocol Buffer service.
pub type Method {
  Method(
    name: String,
    input_type: String,
    output_type: String,
    client_streaming: Bool,
    server_streaming: Bool,
  )
}

/// Represents a Protocol Buffer service definition.
pub type Service {
  Service(name: String, methods: List(Method))
}

/// Represents a parsed Protocol Buffer file.
pub type ProtoFile {
  ProtoFile(
    syntax: String,
    package: Option(String),
    imports: List(Import),
    messages: List(Message),
    enums: List(Enum),
    services: List(Service),
  )
}

/// Parses a simple Protocol Buffer file from its text content.
/// This is a simplified parser that handles basic proto3 syntax.
/// 
/// ## Limitations
/// - Only supports proto3 syntax
/// - Limited support for nested types
/// 
/// ## Examples
/// 
/// ```gleam
/// let proto_content = "syntax = 'proto3'; message Person { string name = 1; }"
/// let proto_file = parse(proto_content)
/// ```
pub fn parse(content: String) -> Result(ProtoFile, ParseError) {
  let lines =
    content
    |> string.split("\n")
    |> list.map(string.trim)
    |> list.filter(fn(line) { line != "" && !string.starts_with(line, "//") })

  // Validate basic structure for non-empty files
  case lines {
    [] -> Error(MissingRequiredSyntax("proto content"))
    _ -> {
      use syntax <- result.try(find_syntax(lines))
      let package = find_package(lines)
      use imports <- result.try(find_imports(lines))
      use #(messages, enums) <- result.try(parse_items(lines))
      use services <- result.try(parse_services(lines))

      // Validate messages have at least some content or are explicitly empty
      use validated_messages <- result.try(validate_messages(messages))

      // Post-process messages to correctly identify enum types
      let enum_names = list.map(enums, fn(e) { e.name })
      let messages =
        list.map(validated_messages, fn(msg) {
          Message(
            msg.name,
            fix_field_types(msg.fields, enum_names),
            msg.oneofs,
            msg.nested_messages,
            msg.enums,
          )
        })

      Ok(ProtoFile(syntax:, package:, messages:, enums:, imports:, services:))
    }
  }
}

fn find_imports(lines: List(String)) -> Result(List(Import), ParseError) {
  let import_lines =
    list.filter(lines, fn(line) {
      let trimmed = string.trim(line)
      string.starts_with(trimmed, "import ")
    })

  list.try_map(import_lines, fn(line) {
    let trimmed = string.trim(line)

    // Remove any trailing comments
    let clean_line = case string.split(trimmed, "//") {
      [main, ..] -> main
      [] -> trimmed
    }

    // Check for proper syntax
    case string.contains(clean_line, "\"") {
      False ->
        Error(InvalidSyntax(line, "import statement must contain quoted path"))
      True -> {
        let without_import = string.replace(clean_line, "import ", "")
        let public = string.starts_with(without_import, "public ")
        let weak = string.starts_with(without_import, "weak ")

        let path_part =
          without_import
          |> string.replace("public ", "")
          |> string.replace("weak ", "")
          |> string.trim

        // Extract path between quotes
        case string.split(path_part, "\"") {
          [_, path, ..] -> Ok(Import(path, public, weak))
          _ -> Error(InvalidSyntax(line, "invalid import path syntax"))
        }
      }
    }
  })
}

fn find_syntax(lines: List(String)) -> Result(String, ParseError) {
  case list.find(lines, fn(line) { string.starts_with(line, "syntax") }) {
    Ok(line) -> {
      case string.contains(line, "proto3") {
        True -> Ok("proto3")
        False ->
          case string.contains(line, "proto2") {
            True ->
              Error(InvalidSyntax(
                line,
                "proto2 syntax not supported, only proto3",
              ))
            False -> Error(InvalidSyntax(line, "invalid syntax declaration"))
          }
      }
    }
    Error(_) -> Error(MissingRequiredSyntax("syntax"))
  }
}

fn find_package(lines: List(String)) -> Option(String) {
  case list.find(lines, fn(line) { string.starts_with(line, "package") }) {
    Ok(line) -> {
      Some(
        line
        |> string.replace("package ", "")
        |> string.replace(";", "")
        |> string.trim,
      )
    }
    Error(_) -> None
  }
}

fn parse_items(
  lines: List(String),
) -> Result(#(List(Message), List(Enum)), ParseError) {
  parse_items_helper(lines, [], [])
}

fn parse_items_helper(
  lines: List(String),
  messages: List(Message),
  enums: List(Enum),
) -> Result(#(List(Message), List(Enum)), ParseError) {
  case lines {
    [] -> Ok(#(list.reverse(messages), list.reverse(enums)))
    [line, ..rest] -> {
      case string.starts_with(line, "message ") {
        True -> {
          use #(msg, remaining) <- result.try(parse_message(line, rest))
          case msg {
            Some(m) -> parse_items_helper(remaining, [m, ..messages], enums)
            None -> parse_items_helper(remaining, messages, enums)
          }
        }
        False -> {
          case string.starts_with(line, "enum ") {
            True -> {
              use #(enum, remaining) <- result.try(parse_enum(line, rest))
              case enum {
                Some(e) -> parse_items_helper(remaining, messages, [e, ..enums])
                None -> parse_items_helper(remaining, messages, enums)
              }
            }
            False -> {
              case string.starts_with(line, "service ") {
                True -> {
                  // Skip service blocks - they're parsed separately
                  let #(_, remaining) = extract_body(rest, [], 0)
                  parse_items_helper(remaining, messages, enums)
                }
                False -> {
                  // Check if this line contains unrecognized syntax that should be an error
                  let trimmed = string.trim(line)
                  case trimmed {
                    "" -> parse_items_helper(rest, messages, enums)
                    _ -> {
                      // Skip lines that might be valid proto syntax we don't recognize
                      // but catch obvious errors
                      case
                        string.contains(trimmed, "{")
                        || string.contains(trimmed, "}")
                      {
                        True -> Error(InvalidSyntax(line, "unrecognized syntax"))
                        False -> parse_items_helper(rest, messages, enums)
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}

fn validate_messages(
  messages: List(Message),
) -> Result(List(Message), ParseError) {
  // Check for duplicate field numbers within each message
  list.try_map(messages, fn(msg) {
    let all_field_numbers = list.map(msg.fields, fn(field) { field.number })

    // Check for duplicates
    case has_duplicates(all_field_numbers) {
      Some(dup_num) -> Error(DuplicateFieldNumber(msg.name, dup_num))
      None -> {
        // Validate field numbers are positive
        case list.find(msg.fields, fn(field) { field.number <= 0 }) {
          Ok(invalid_field) ->
            Error(InvalidFieldNumber(
              invalid_field.name,
              int.to_string(invalid_field.number),
            ))
          Error(_) -> Ok(msg)
        }
      }
    }
  })
}

fn has_duplicates(numbers: List(Int)) -> Option(Int) {
  has_duplicates_helper(numbers, set.new())
}

fn has_duplicates_helper(numbers: List(Int), seen: set.Set(Int)) -> Option(Int) {
  case numbers {
    [] -> None
    [num, ..rest] -> {
      case set.contains(seen, num) {
        True -> Some(num)
        False -> has_duplicates_helper(rest, set.insert(seen, num))
      }
    }
  }
}

fn parse_message(
  line: String,
  rest: List(String),
) -> Result(#(Option(Message), List(String)), ParseError) {
  // Validate message declaration syntax
  case
    string.contains(line, " {")
    || list.any(rest, fn(l) { string.trim(l) == "{" })
  {
    False -> Error(MalformedMessage(line))
    True -> {
      let name =
        line
        |> string.replace("message ", "")
        |> string.replace(" {", "")
        |> string.trim

      case name {
        "" -> Error(MalformedMessage(line))
        _ -> {
          let #(body, remaining) = extract_body(rest, [], 0)
          use #(oneofs, regular_fields, nested_messages, enums) <- result.try(
            parse_message_body(body, name),
          )
          Ok(#(
            Some(Message(name, regular_fields, oneofs, nested_messages, enums)),
            remaining,
          ))
        }
      }
    }
  }
}

fn parse_enum(
  line: String,
  rest: List(String),
) -> Result(#(Option(Enum), List(String)), ParseError) {
  // Validate enum declaration syntax
  case
    string.contains(line, " {")
    || list.any(rest, fn(l) { string.trim(l) == "{" })
  {
    False -> Error(MalformedEnum(line))
    True -> {
      let name =
        line
        |> string.replace("enum ", "")
        |> string.replace(" {", "")
        |> string.trim

      case name {
        "" -> Error(MalformedEnum(line))
        _ -> {
          let #(body, remaining) = extract_body(rest, [], 0)
          let values = parse_enum_values(body)
          Ok(#(Some(Enum(name, values)), remaining))
        }
      }
    }
  }
}

fn extract_body(
  lines: List(String),
  body: List(String),
  depth: Int,
) -> #(List(String), List(String)) {
  case lines {
    [] -> #(list.reverse(body), [])
    [line, ..rest] -> {
      let trimmed = string.trim(line)

      // Handle closing braces first
      case string.contains(trimmed, "}") && !string.contains(trimmed, "{") {
        True -> {
          // Pure closing brace
          case depth {
            0 -> {
              // This is the closing brace of the message/enum
              #(list.reverse(body), rest)
            }
            _ -> {
              // This is a closing brace of a nested structure
              extract_body(rest, [line, ..body], depth - 1)
            }
          }
        }
        False -> {
          // Check for opening braces or regular lines
          let new_depth = case string.contains(trimmed, "{") {
            True -> depth + 1
            False -> depth
          }
          // Add line and continue
          extract_body(rest, [line, ..body], new_depth)
        }
      }
    }
  }
}

fn parse_message_body(
  lines: List(String),
  message_name: String,
) -> Result(#(List(Oneof), List(Field), List(Message), List(Enum)), ParseError) {
  parse_message_body_helper(lines, [], [], None, [], [], message_name)
}

fn parse_message_body_helper(
  lines: List(String),
  oneofs: List(Oneof),
  fields: List(Field),
  current_oneof: Option(#(String, List(Field))),
  messages: List(Message),
  enums: List(Enum),
  message_name: String,
) -> Result(#(List(Oneof), List(Field), List(Message), List(Enum)), ParseError) {
  case lines {
    [] -> {
      // Finish any pending oneof
      case current_oneof {
        Some(#(name, oneof_fields)) ->
          Ok(#(
            list.reverse([Oneof(name, list.reverse(oneof_fields)), ..oneofs]),
            list.reverse(fields),
            list.reverse(messages),
            list.reverse(enums),
          ))
        None ->
          Ok(#(
            list.reverse(oneofs),
            list.reverse(fields),
            list.reverse(messages),
            list.reverse(enums),
          ))
      }
    }
    [line, ..rest] -> {
      let trimmed = string.trim(line)

      case trimmed {
        "" ->
          parse_message_body_helper(
            rest,
            oneofs,
            fields,
            current_oneof,
            messages,
            enums,
            message_name,
          )
        _ -> {
          case string.starts_with(trimmed, "oneof ") {
            True -> {
              // Finish any current oneof first
              case current_oneof {
                Some(#(name, oneof_fields)) -> {
                  let new_oneof = Oneof(name, list.reverse(oneof_fields))
                  let oneof_name =
                    string.replace(trimmed, "oneof ", "")
                    |> string.replace(" {", "")
                    |> string.trim
                  parse_message_body_helper(
                    rest,
                    [new_oneof, ..oneofs],
                    fields,
                    Some(#(oneof_name, [])),
                    messages,
                    enums,
                    message_name,
                  )
                }
                None -> {
                  let oneof_name =
                    string.replace(trimmed, "oneof ", "")
                    |> string.replace(" {", "")
                    |> string.trim
                  parse_message_body_helper(
                    rest,
                    oneofs,
                    fields,
                    Some(#(oneof_name, [])),
                    messages,
                    enums,
                    message_name,
                  )
                }
              }
            }
            False -> {
              case string.starts_with(trimmed, "message ") {
                True -> {
                  use #(msg, remaining) <- result.try(parse_message(line, rest))
                  case msg {
                    Some(m) ->
                      parse_message_body_helper(
                        remaining,
                        oneofs,
                        fields,
                        current_oneof,
                        [m, ..messages],
                        enums,
                        message_name,
                      )
                    None ->
                      parse_message_body_helper(
                        remaining,
                        oneofs,
                        fields,
                        current_oneof,
                        messages,
                        enums,
                        message_name,
                      )
                  }
                }
                False -> {
                  case string.starts_with(trimmed, "enum ") {
                    True -> {
                      use #(enum, remaining) <- result.try(parse_enum(
                        line,
                        rest,
                      ))
                      case enum {
                        Some(e) ->
                          parse_message_body_helper(
                            remaining,
                            oneofs,
                            fields,
                            current_oneof,
                            messages,
                            [e, ..enums],
                            message_name,
                          )
                        None ->
                          parse_message_body_helper(
                            remaining,
                            oneofs,
                            fields,
                            current_oneof,
                            messages,
                            enums,
                            message_name,
                          )
                      }
                    }
                    False -> {
                      case trimmed == "}" {
                        True -> {
                          // End of oneof
                          case current_oneof {
                            Some(#(name, oneof_fields)) -> {
                              let new_oneof =
                                Oneof(name, list.reverse(oneof_fields))
                              parse_message_body_helper(
                                rest,
                                [new_oneof, ..oneofs],
                                fields,
                                None,
                                messages,
                                enums,
                                message_name,
                              )
                            }
                            None ->
                              parse_message_body_helper(
                                rest,
                                oneofs,
                                fields,
                                current_oneof,
                                messages,
                                enums,
                                message_name,
                              )
                          }
                        }
                        False -> {
                          // Try to parse as field
                          case parse_field_line(trimmed, current_oneof) {
                            Ok(field) -> {
                              case current_oneof {
                                Some(#(name, oneof_fields)) -> {
                                  parse_message_body_helper(
                                    rest,
                                    oneofs,
                                    fields,
                                    Some(#(name, [field, ..oneof_fields])),
                                    messages,
                                    enums,
                                    message_name,
                                  )
                                }
                                None -> {
                                  parse_message_body_helper(
                                    rest,
                                    oneofs,
                                    [field, ..fields],
                                    current_oneof,
                                    messages,
                                    enums,
                                    message_name,
                                  )
                                }
                              }
                            }
                            Error(_) -> Error(MalformedField(trimmed))
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}

fn parse_field_line(
  line: String,
  oneof_context: Option(#(String, List(Field))),
) -> Result(Field, ParseError) {
  let clean_line =
    line
    |> string.replace(";", "")
    |> string.trim

  // Remove comments before parsing
  let clean_line = case string.split(clean_line, "//") {
    [main, ..] -> string.trim(main)
    [] -> clean_line
  }

  let oneof_name = case oneof_context {
    Some(#(name, _)) -> Some(name)
    None -> None
  }

  case string.starts_with(clean_line, "map<") {
    True -> {
      parse_map_field(clean_line, oneof_name)
    }
    False -> {
      parse_field(clean_line, oneof_name)
    }
  }
}

/// Parse field options from a string like "[deprecated=true, json_name="myfield"]"
fn parse_field_options(options_str: String) -> List(FieldOption) {
  let trimmed = string.trim(options_str)
  case trimmed {
    "" -> []
    _ -> {
      case string.starts_with(trimmed, "[") && string.ends_with(trimmed, "]") {
        True -> {
          let content = trimmed |> string.drop_start(1) |> string.drop_end(1) |> string.trim()
          case content {
            "" -> []
            _ -> parse_option_list(content)
          }
        }
        False -> []
      }
    }
  }
}

fn parse_option_list(content: String) -> List(FieldOption) {
  content
  |> string.split(",")
  |> list.map(string.trim)
  |> list.filter_map(parse_single_option)
}

fn parse_single_option(option_str: String) -> Result(FieldOption, Nil) {
  case string.split(option_str, "=") {
    ["deprecated", "true"] -> Ok(Deprecated(True))
    ["deprecated", "false"] -> Ok(Deprecated(False))
    ["packed", "true"] -> Ok(Packed(True))  
    ["packed", "false"] -> Ok(Packed(False))
    ["json_name", value] -> {
      // Remove quotes from json_name value
      let clean_value = case string.starts_with(value, "\"") && string.ends_with(value, "\"") {
        True -> value |> string.drop_start(1) |> string.drop_end(1)
        False -> value
      }
      Ok(JsonName(clean_value))
    }
    _ -> Error(Nil)
  }
}

fn parse_field(
  clean_line: String,
  oneof_name: Option(String),
) -> Result(Field, ParseError) {
  // Remove comments before parsing
  let clean_line = case string.split(clean_line, "//") {
    [main, ..] -> string.trim(main)
    [] -> clean_line
  }

  // Extract field options if present
  let #(line_without_options, field_options) = case string.split_once(clean_line, "[") {
    Ok(#(before, after)) -> {
      case string.split_once(after, "]") {
        Ok(#(options_content, remaining)) -> {
          let options = parse_field_options("[" <> options_content <> "]")
          // Remove semicolon from remaining part if present
          let cleaned_remaining = string.trim(remaining) |> string.replace(";", "")
          let cleaned_line = case cleaned_remaining {
            "" -> string.trim(before)
            _ -> string.trim(before) <> " " <> cleaned_remaining
          }
          #(cleaned_line, options)
        }
        Error(_) -> #(clean_line, [])  // Malformed options, ignore
      }
    }
    Error(_) -> #(clean_line, [])
  }

  case string.split(line_without_options, " ") {
    ["repeated", type_str, name, "=", num_str] -> {
      case string_to_int(num_str) {
        Some(num) -> {
          case num <= 0 {
            True -> Error(InvalidFieldNumber(name, num_str))
            False ->
              Ok(Field(name, Repeated(parse_type(type_str)), num, oneof_name, field_options))
          }
        }
        None -> Error(InvalidFieldNumber(name, num_str))
      }
    }
    ["optional", type_str, name, "=", num_str] -> {
      case string_to_int(num_str) {
        Some(num) -> {
          case num <= 0 {
            True -> Error(InvalidFieldNumber(name, num_str))
            False ->
              Ok(Field(name, Optional(parse_type(type_str)), num, oneof_name, field_options))
          }
        }
        None -> Error(InvalidFieldNumber(name, num_str))
      }
    }
    [type_str, name, "=", num_str] -> {
      case string_to_int(num_str) {
        Some(num) -> {
          case num <= 0 {
            True -> Error(InvalidFieldNumber(name, num_str))
            False -> Ok(Field(name, parse_type(type_str), num, oneof_name, field_options))
          }
        }
        None -> Error(InvalidFieldNumber(name, num_str))
      }
    }
    _ -> Error(MalformedField(clean_line))
  }
}

fn parse_map_field(
  clean_line: String,
  oneof_name: Option(String),
) -> Result(Field, ParseError) {
  // Extract field options if present
  let #(line_without_options, field_options) = case string.split_once(clean_line, "[") {
    Ok(#(before, after)) -> {
      case string.split_once(after, "]") {
        Ok(#(options_content, remaining)) -> {
          let options = parse_field_options("[" <> options_content <> "]")
          // Remove semicolon from remaining part if present
          let cleaned_remaining = string.trim(remaining) |> string.replace(";", "")
          let cleaned_line = case cleaned_remaining {
            "" -> string.trim(before)
            _ -> string.trim(before) <> " " <> cleaned_remaining
          }
          #(cleaned_line, options)
        }
        Error(_) -> #(clean_line, [])
      }
    }
    Error(_) -> #(clean_line, [])
  }

  case string.split(line_without_options, ">") {
    [map_type_part, rest] -> {
      let map_type = map_type_part <> ">"
      let parts = string.split(string.trim(rest), " ")
      case parts {
        [name, "=", num_str] -> {
          use tuple <- result.try(
            parse_map_type(map_type)
            |> result.map_error(fn(_) { InvalidMapType(clean_line) }),
          )
          let #(key_type, value_type) = tuple

          case int.parse(num_str) {
            Ok(num) -> {
              case num <= 0 {
                True -> Error(InvalidFieldNumber(name, num_str))
                False ->
                  Ok(Field(name, Map(key_type, value_type), num, oneof_name, field_options))
              }
            }
            Error(_) -> Error(InvalidFieldNumber(name, num_str))
          }
        }
        _ -> Error(MalformedField(clean_line))
      }
    }
    _ -> Error(MalformedField(clean_line))
  }
}

fn parse_map_type(map_str: String) -> Result(#(ProtoType, ProtoType), Nil) {
  case string.starts_with(map_str, "map<") && string.ends_with(map_str, ">") {
    True -> {
      let inner =
        map_str
        |> string.drop_start(4)
        |> string.drop_end(1)
        |> string.trim

      case string.split(inner, ",") {
        [key_str, value_str] -> {
          let key_type = parse_type(string.trim(key_str))
          let value_type = parse_type(string.trim(value_str))
          Ok(#(key_type, value_type))
        }
        _ -> Error(Nil)
      }
    }
    False -> Error(Nil)
  }
}

fn parse_type(type_str: String) -> ProtoType {
  case type_str {
    "double" -> Double
    "float" -> Float
    "int32" -> Int32
    "int64" -> Int64
    "uint32" -> UInt32
    "uint64" -> UInt64
    "sint32" -> SInt32
    "sint64" -> SInt64
    "fixed32" -> Fixed32
    "fixed64" -> Fixed64
    "sfixed32" -> SFixed32
    "sfixed64" -> SFixed64
    "bool" -> Bool
    "string" -> String
    "bytes" -> Bytes
    other -> MessageType(other)
  }
}

fn parse_enum_values(lines: List(String)) -> List(EnumValue) {
  lines
  |> list.filter_map(parse_enum_value_line)
}

fn parse_enum_value_line(line: String) -> Result(EnumValue, Nil) {
  let clean_line =
    line
    |> string.replace(";", "")
    |> string.replace(",", "")
    |> string.trim

  case string.split(clean_line, "=") {
    [name_str, num_str] -> {
      let name = string.trim(name_str)
      let num_trimmed = string.trim(num_str)
      case string_to_int(num_trimmed) {
        Some(num) -> Ok(EnumValue(name, num))
        None -> Error(Nil)
      }
    }
    _ -> Error(Nil)
  }
}

fn string_to_int(str: String) -> Option(Int) {
  case int.parse(str) {
    Ok(n) -> Some(n)
    Error(_) -> None
  }
}

fn fix_field_types(fields: List(Field), enum_names: List(String)) -> List(Field) {
  list.map(fields, fn(field) {
    Field(
      field.name,
      fix_proto_type(field.field_type, enum_names),
      field.number,
      field.oneof_name,
      field.options,
    )
  })
}

fn fix_proto_type(proto_type: ProtoType, enum_names: List(String)) -> ProtoType {
  case proto_type {
    MessageType(name) -> {
      case list.contains(enum_names, name) {
        True -> EnumType(name)
        False -> MessageType(name)
      }
    }
    Repeated(inner) -> Repeated(fix_proto_type(inner, enum_names))
    Optional(inner) -> Optional(fix_proto_type(inner, enum_names))
    Map(key, value) ->
      Map(fix_proto_type(key, enum_names), fix_proto_type(value, enum_names))
    other -> other
  }
}

/// Parse all services from proto file lines
fn parse_services(lines: List(String)) -> Result(List(Service), ParseError) {
  let service_lines = 
    list.filter(lines, fn(line) {
      let trimmed = string.trim(line)
      string.starts_with(trimmed, "service ")
    })
  
  case service_lines {
    [] -> Ok([])
    _ -> {
      // Extract service blocks and parse them
      parse_service_blocks(lines, [])
    }
  }
}

/// Parse individual service blocks from proto lines
fn parse_service_blocks(lines: List(String), services: List(Service)) -> Result(List(Service), ParseError) {
  case lines {
    [] -> Ok(list.reverse(services))
    [line, ..rest] -> {
      let trimmed = string.trim(line)
      case string.starts_with(trimmed, "service ") {
        True -> {
          // Extract service name
          case string.split(trimmed, " ") {
            ["service", name, "{"] -> {
              let service_name = string.trim(name) |> string.replace("{", "")
              // Extract service body
              let #(body, remaining) = extract_body(rest, [], 0)
              case parse_service_methods(body) {
                Ok(methods) -> {
                  let service = Service(name: service_name, methods: methods)
                  parse_service_blocks(remaining, [service, ..services])
                }
                Error(err) -> Error(err)
              }
            }
            ["service", name] -> {
              let service_name = string.trim(name)
              // Service definition continues on next line with opening brace
              case rest {
                [brace_line, ..rest2] -> {
                  case string.trim(brace_line) {
                    "{" -> {
                      let #(body, remaining) = extract_body(rest2, [], 0)
                      case parse_service_methods(body) {
                        Ok(methods) -> {
                          let service = Service(name: service_name, methods: methods)
                          parse_service_blocks(remaining, [service, ..services])
                        }
                        Error(err) -> Error(err)
                      }
                    }
                    _ -> Error(MalformedMessage(line))
                  }
                }
                [] -> Error(MalformedMessage(line))
              }
            }
            _ -> Error(MalformedMessage(line))
          }
        }
        False -> parse_service_blocks(rest, services)
      }
    }
  }
}

/// Parse methods within a service body
fn parse_service_methods(body_lines: List(String)) -> Result(List(Method), ParseError) {
  let method_lines = 
    list.filter(body_lines, fn(line) {
      let trimmed = string.trim(line)
      string.starts_with(trimmed, "rpc ")
    })
  
  list.try_map(method_lines, parse_single_method)
}

/// Parse a single RPC method definition
fn parse_single_method(line: String) -> Result(Method, ParseError) {
  let trimmed = string.trim(line) |> string.replace(";", "")
  
  // Handle: rpc MethodName(InputType) returns (OutputType);
  case string.split(trimmed, " ") {
    ["rpc", ..rest_parts] -> {
      // Reconstruct the method signature without "rpc"
      let combined = string.join(rest_parts, " ")
      case parse_method_signature(combined) {
        Ok(#(name, input_type, output_type, client_streaming, server_streaming)) -> {
          Ok(Method(
            name: name,
            input_type: input_type,
            output_type: output_type,
            client_streaming: client_streaming,
            server_streaming: server_streaming,
          ))
        }
        Error(_) -> Error(MalformedField(line))
      }
    }
    _ -> Error(MalformedField(line))
  }
}

/// Parse method signature to extract types and streaming info
fn parse_method_signature(signature: String) -> Result(#(String, String, String, Bool, Bool), Nil) {
  // Extract method name
  case string.split_once(signature, "(") {
    Ok(#(method_name, rest)) -> {
      let name = string.trim(method_name)
      
      // Find the input type
      case string.split_once(rest, ")") {
        Ok(#(input_part, after_input)) -> {
          let input_type = string.trim(input_part)
          let client_streaming = string.starts_with(input_type, "stream ")
          let clean_input = case client_streaming {
            True -> string.drop_start(input_type, 7) |> string.trim()
            False -> input_type
          }
          
          // Find "returns" and output type
          case string.split_once(after_input, "returns") {
            Ok(#(_, returns_part)) -> {
              case string.split_once(returns_part, "(") {
                Ok(#(_, output_part)) -> {
                  case string.split_once(output_part, ")") {
                    Ok(#(output_type, _)) -> {
                      let output_type = string.trim(output_type)
                      let server_streaming = string.starts_with(output_type, "stream ")
                      let clean_output = case server_streaming {
                        True -> string.drop_start(output_type, 7) |> string.trim()
                        False -> output_type
                      }
                      
                      Ok(#(name, clean_input, clean_output, client_streaming, server_streaming))
                    }
                    Error(_) -> Error(Nil)
                  }
                }
                Error(_) -> Error(Nil)
              }
            }
            Error(_) -> Error(Nil)
          }
        }
        Error(_) -> Error(Nil)
      }
    }
    Error(_) -> Error(Nil)
  }
}
