//// Protocol Buffer Parser Module
////
//// This module provides parsing functionality for Protocol Buffer (.proto) files.
//// It transforms proto3 syntax text into structured Gleam data types that can be
//// used for code generation and type analysis.
////
//// ## Capabilities
////
//// - **Full proto3 syntax support**: Messages, enums, fields, imports, packages
//// - **Nested structures**: Supports nested messages and enums within messages  
//// - **Advanced features**: Oneofs, maps, repeated fields, optional fields
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
import gleam/string

pub type Path {
  Path(path: String, content: ProtoFile)
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

/// Represents a field in a Protocol Buffer message.
pub type Field {
  Field(
    name: String,
    field_type: ProtoType,
    number: Int,
    oneof_name: Option(String),
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

/// Represents a parsed Protocol Buffer file.
pub type ProtoFile {
  ProtoFile(
    syntax: String,
    package: Option(String),
    imports: List(Import),
    messages: List(Message),
    enums: List(Enum),
  )
}

/// Parses a simple Protocol Buffer file from its text content.
/// This is a simplified parser that handles basic proto3 syntax.
/// 
/// ## Limitations
/// - Only supports proto3 syntax
/// - Does not support imports
/// - Does not support services
/// - Limited support for nested types
/// 
/// ## Examples
/// 
/// ```gleam
/// let proto_content = "syntax = 'proto3'; message Person { string name = 1; }"
/// let proto_file = parse(proto_content)
/// ```
pub fn parse(content: String) -> ProtoFile {
  let lines =
    content
    |> string.split("\n")
    |> list.map(string.trim)
    |> list.filter(fn(line) { line != "" && !string.starts_with(line, "//") })

  let syntax = find_syntax(lines)
  let package = find_package(lines)
  let imports = find_imports(lines)
  let #(messages, enums) = parse_items(lines)

  // Post-process messages to correctly identify enum types
  let enum_names = list.map(enums, fn(e) { e.name })
  let messages =
    list.map(messages, fn(msg) {
      Message(
        msg.name,
        fix_field_types(msg.fields, enum_names),
        msg.oneofs,
        msg.nested_messages,
        msg.enums,
      )
    })

  ProtoFile(syntax:, package:, messages:, enums:, imports:)
}

fn find_imports(lines: List(String)) -> List(Import) {
  lines
  |> list.filter(fn(line) {
    let trimmed = string.trim(line)
    string.starts_with(trimmed, "import ")
  })
  |> list.filter_map(fn(line) {
    let trimmed = string.trim(line)

    // Remove any trailing comments
    let clean_line = case string.split(trimmed, "//") {
      [main, ..] -> main
      [] -> trimmed
    }

    // Check for proper syntax
    case string.contains(clean_line, "\"") {
      False -> Error(Nil)
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
          _ -> Error(Nil)
        }
      }
    }
  })
}

fn find_syntax(lines: List(String)) -> String {
  case list.find(lines, fn(line) { string.starts_with(line, "syntax") }) {
    Ok(line) -> {
      case string.contains(line, "proto3") {
        True -> "proto3"
        False -> "proto2"
      }
    }
    Error(_) -> "proto3"
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

fn parse_items(lines: List(String)) -> #(List(Message), List(Enum)) {
  parse_items_helper(lines, [], [])
}

fn parse_items_helper(
  lines: List(String),
  messages: List(Message),
  enums: List(Enum),
) -> #(List(Message), List(Enum)) {
  case lines {
    [] -> #(list.reverse(messages), list.reverse(enums))
    [line, ..rest] -> {
      case string.starts_with(line, "message ") {
        True -> {
          let #(msg, remaining) = parse_message(line, rest)
          case msg {
            Some(m) -> parse_items_helper(remaining, [m, ..messages], enums)
            None -> parse_items_helper(remaining, messages, enums)
          }
        }
        False -> {
          case string.starts_with(line, "enum ") {
            True -> {
              let #(enum, remaining) = parse_enum(line, rest)
              case enum {
                Some(e) -> parse_items_helper(remaining, messages, [e, ..enums])
                None -> parse_items_helper(remaining, messages, enums)
              }
            }
            False -> parse_items_helper(rest, messages, enums)
          }
        }
      }
    }
  }
}

fn parse_message(
  line: String,
  rest: List(String),
) -> #(Option(Message), List(String)) {
  let name =
    line
    |> string.replace("message ", "")
    |> string.replace(" {", "")
    |> string.trim
  let #(body, remaining) = extract_body(rest, [], 0)
  let #(oneofs, regular_fields, nested_messages, enums) =
    parse_message_body(body)
  #(
    Some(Message(name, regular_fields, oneofs, nested_messages, enums)),
    remaining,
  )
}

fn parse_enum(line: String, rest: List(String)) -> #(Option(Enum), List(String)) {
  let name =
    line
    |> string.replace("enum ", "")
    |> string.replace(" {", "")
    |> string.trim
  let #(body, remaining) = extract_body(rest, [], 0)
  let values = parse_enum_values(body)
  #(Some(Enum(name, values)), remaining)
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
) -> #(List(Oneof), List(Field), List(Message), List(Enum)) {
  parse_message_body_helper(lines, [], [], None, [], [])
}

fn parse_message_body_helper(
  lines: List(String),
  oneofs: List(Oneof),
  fields: List(Field),
  current_oneof: Option(#(String, List(Field))),
  messages: List(Message),
  enums: List(Enum),
) -> #(List(Oneof), List(Field), List(Message), List(Enum)) {
  case lines {
    [] -> {
      // Finish any pending oneof
      case current_oneof {
        Some(#(name, oneof_fields)) -> #(
          list.reverse([Oneof(name, list.reverse(oneof_fields)), ..oneofs]),
          list.reverse(fields),
          list.reverse(messages),
          list.reverse(enums),
        )
        None -> #(
          list.reverse(oneofs),
          list.reverse(fields),
          list.reverse(messages),
          list.reverse(enums),
        )
      }
    }
    [line, ..rest] -> {
      let trimmed = string.trim(line)
      case string.starts_with(trimmed, "oneof ") {
        True -> {
          // Start of oneof
          // Finish current oneof if any
          let new_oneofs = case current_oneof {
            Some(#(name, oneof_fields)) -> [
              Oneof(name, list.reverse(oneof_fields)),
              ..oneofs
            ]
            None -> oneofs
          }
          // Start new oneof
          let oneof_name =
            trimmed
            |> string.drop_start(6)
            // Remove "oneof " (6 characters)
            |> string.replace("{", "")
            |> string.trim
          parse_message_body_helper(
            rest,
            new_oneofs,
            fields,
            Some(#(oneof_name, [])),
            messages,
            enums,
          )
        }
        False -> {
          case trimmed {
            "}" -> {
              // End of oneof (we skip lone closing braces as they mark the end of blocks)
              case current_oneof {
                Some(#(name, oneof_fields)) -> {
                  let new_oneofs = [
                    Oneof(name, list.reverse(oneof_fields)),
                    ..oneofs
                  ]
                  parse_message_body_helper(
                    rest,
                    new_oneofs,
                    fields,
                    None,
                    messages,
                    enums,
                  )
                }
                None -> {
                  // This is likely the message closing brace or has already been handled
                  // Continue parsing remaining lines
                  parse_message_body_helper(
                    rest,
                    oneofs,
                    fields,
                    None,
                    messages,
                    enums,
                  )
                }
              }
            }
            // Regular field or oneof field
            _ -> {
              // Check for nested message first
              case string.starts_with(trimmed, "message ") {
                True -> {
                  let #(msg, remaining_lines) = parse_message(trimmed, rest)
                  case msg {
                    Some(message) ->
                      parse_message_body_helper(
                        remaining_lines,
                        oneofs,
                        fields,
                        current_oneof,
                        [message, ..messages],
                        enums,
                      )
                    None ->
                      parse_message_body_helper(
                        remaining_lines,
                        oneofs,
                        fields,
                        current_oneof,
                        messages,
                        enums,
                      )
                  }
                }
                False -> {
                  // Check for nested enum
                  case string.starts_with(trimmed, "enum ") {
                    True -> {
                      let #(enum_def, remaining_lines) =
                        parse_enum(trimmed, rest)
                      case enum_def {
                        Some(enum_val) ->
                          parse_message_body_helper(
                            remaining_lines,
                            oneofs,
                            fields,
                            current_oneof,
                            messages,
                            [enum_val, ..enums],
                          )
                        None ->
                          parse_message_body_helper(
                            remaining_lines,
                            oneofs,
                            fields,
                            current_oneof,
                            messages,
                            enums,
                          )
                      }
                    }
                    False -> {
                      // Regular field parsing
                      case parse_field_line(trimmed, current_oneof) {
                        Ok(field) -> {
                          case current_oneof {
                            Some(#(oneof_name, oneof_fields)) ->
                              // This is a field inside a oneof
                              parse_message_body_helper(
                                rest,
                                oneofs,
                                fields,
                                Some(#(oneof_name, [field, ..oneof_fields])),
                                messages,
                                enums,
                              )
                            None ->
                              // Regular field
                              parse_message_body_helper(
                                rest,
                                oneofs,
                                [field, ..fields],
                                None,
                                messages,
                                enums,
                              )
                          }
                        }
                        Error(_) ->
                          // Skip lines we can't parse
                          parse_message_body_helper(
                            rest,
                            oneofs,
                            fields,
                            current_oneof,
                            messages,
                            enums,
                          )
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
) -> Result(Field, Nil) {
  let clean_line =
    line
    |> string.replace(";", "")
    |> string.trim

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

fn parse_field(
  clean_line: String,
  oneof_name: Option(String),
) -> Result(Field, Nil) {
  case string.split(clean_line, " ") {
    ["repeated", type_str, name, "=", num_str] -> {
      case string_to_int(num_str) {
        Some(num) ->
          Ok(Field(name, Repeated(parse_type(type_str)), num, oneof_name))
        None -> Error(Nil)
      }
    }
    ["optional", type_str, name, "=", num_str] -> {
      case string_to_int(num_str) {
        Some(num) ->
          Ok(Field(name, Optional(parse_type(type_str)), num, oneof_name))
        None -> Error(Nil)
      }
    }
    [type_str, name, "=", num_str] -> {
      case string_to_int(num_str) {
        Some(num) -> Ok(Field(name, parse_type(type_str), num, oneof_name))
        None -> Error(Nil)
      }
    }
    _ -> Error(Nil)
  }
}

fn parse_map_field(clean_line, oneof_name) -> Result(Field, Nil) {
  case string.split(clean_line, ">") {
    [map_type_part, rest] -> {
      let map_type = map_type_part <> ">"
      let parts = string.split(string.trim(rest), " ")
      case parts {
        [name, "=", num_str] -> {
          use tuple <- result.try(parse_map_type(map_type))
          let #(key_type, value_type) = tuple
          int.parse(num_str)
          |> result.map(fn(num) {
            Field(name, Map(key_type, value_type), num, oneof_name)
          })
        }
        _ -> Error(Nil)
      }
    }
    _ -> Error(Nil)
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
