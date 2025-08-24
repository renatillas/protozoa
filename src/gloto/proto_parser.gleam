import gleam/list
import gleam/string
import gleam/int
import gleam/option.{type Option, None, Some}

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
pub type EnumValue {
  EnumValue(
    name: String,
    number: Int,
  )
}

/// Represents a Protocol Buffer enum definition.
pub type Enum {
  Enum(
    name: String,
    values: List(EnumValue),
  )
}

/// Represents a oneof group in a Protocol Buffer message.
/// Only one field in the group can be set at a time.
pub type Oneof {
  Oneof(
    name: String,
    fields: List(Field),
  )
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

/// Represents a parsed Protocol Buffer file.
pub type ProtoFile {
  ProtoFile(
    syntax: String,
    package: Option(String),
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
/// let proto_file = parse_simple(proto_content)
/// ```
pub fn parse_simple(content: String) -> ProtoFile {
  let lines =
    content
    |> string.split("\n")
    |> list.map(string.trim)
    |> list.filter(fn(line) { line != "" && !string.starts_with(line, "//") })
  
  let syntax = find_syntax(lines)
  let package = find_package(lines)
  let #(messages, enums) = parse_items(lines)
  
  // Post-process messages to correctly identify enum types
  let enum_names = list.map(enums, fn(e) { e.name })
  let fixed_messages = list.map(messages, fn(msg) {
    Message(
      msg.name,
      fix_field_types(msg.fields, enum_names),
      msg.oneofs,
      msg.nested_messages,
      msg.enums
    )
  })
  
  ProtoFile(syntax, package, fixed_messages, enums)
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
        |> string.trim
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
  enums: List(Enum)
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

fn parse_message(line: String, rest: List(String)) -> #(Option(Message), List(String)) {
  let name = 
    line
    |> string.replace("message ", "")
    |> string.replace(" {", "")
    |> string.trim
  let #(body, remaining) = extract_body(rest, [], 0)
  let #(oneofs, regular_fields) = parse_message_body(body)
  #(Some(Message(name, regular_fields, oneofs, [], [])), remaining)
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


fn parse_message_body(lines: List(String)) -> #(List(Oneof), List(Field)) {
  parse_message_body_helper(lines, [], [], None)
}

fn parse_message_body_helper(
  lines: List(String),
  oneofs: List(Oneof),
  fields: List(Field),
  current_oneof: Option(#(String, List(Field)))
) -> #(List(Oneof), List(Field)) {
  case lines {
    [] -> {
      // Finish any pending oneof
      case current_oneof {
        Some(#(name, oneof_fields)) -> 
          #(list.reverse([Oneof(name, list.reverse(oneof_fields)), ..oneofs]), list.reverse(fields))
        None -> 
          #(list.reverse(oneofs), list.reverse(fields))
      }
    }
    [line, ..rest] -> {
      let trimmed = string.trim(line)
      case string.starts_with(trimmed, "oneof ") {
        True -> {
          // Start of oneof
          // Finish current oneof if any
          let new_oneofs = case current_oneof {
            Some(#(name, oneof_fields)) -> 
              [Oneof(name, list.reverse(oneof_fields)), ..oneofs]
            None -> oneofs
          }
          // Start new oneof
          let oneof_name = 
            trimmed
            |> string.drop_start(6)  // Remove "oneof " (6 characters)
            |> string.replace("{", "")
            |> string.trim
          parse_message_body_helper(rest, new_oneofs, fields, Some(#(oneof_name, [])))
        }
        False -> {
          case trimmed {
            "}" -> {
              // End of oneof (we skip lone closing braces as they mark the end of blocks)
              case current_oneof {
                Some(#(name, oneof_fields)) -> {
                  let new_oneofs = [Oneof(name, list.reverse(oneof_fields)), ..oneofs]
                  parse_message_body_helper(rest, new_oneofs, fields, None)
                }
                None -> {
                  // This is likely the message closing brace or has already been handled
                  // Continue parsing remaining lines
                  parse_message_body_helper(rest, oneofs, fields, None)
                }
              }
            }
            // Regular field or oneof field
            _ -> {
              case parse_field_line(trimmed, current_oneof) {
                Ok(field) -> {
                  case current_oneof {
                    Some(#(oneof_name, oneof_fields)) ->
                      // This is a field inside a oneof
                      parse_message_body_helper(rest, oneofs, fields, Some(#(oneof_name, [field, ..oneof_fields])))
                    None ->
                      // Regular field
                      parse_message_body_helper(rest, oneofs, [field, ..fields], None)
                  }
                }
                Error(_) -> 
                  // Skip lines we can't parse
                  parse_message_body_helper(rest, oneofs, fields, current_oneof)
              }
            }
          }
        }
      }
    }
  }
}

fn parse_field_line(line: String, oneof_context: Option(#(String, List(Field)))) -> Result(Field, Nil) {
  let clean_line = 
    line
    |> string.replace(";", "")
    |> string.trim
  
  let oneof_name = case oneof_context {
    Some(#(name, _)) -> Some(name)
    None -> None
  }
  
  // Check if it's a map field first
  case string.starts_with(clean_line, "map<") {
    True -> {
      // Find the closing > for the map type
      case string.split(clean_line, ">") {
        [map_type_part, rest] -> {
          let map_type = map_type_part <> ">"
          let parts = string.split(string.trim(rest), " ")
          case parts {
            [name, "=", num_str] -> {
              case parse_map_type(map_type) {
                Ok(#(key_type, value_type)) -> {
                  case string_to_int(num_str) {
                    Some(num) -> Ok(Field(name, Map(key_type, value_type), num, oneof_name))
                    None -> Error(Nil)
                  }
                }
                Error(_) -> Error(Nil)
              }
            }
            _ -> Error(Nil)
          }
        }
        _ -> Error(Nil)
      }
    }
    False -> {
      // Original parsing logic for non-map fields
      case string.split(clean_line, " ") {
        ["repeated", type_str, name, "=", num_str] -> {
          case string_to_int(num_str) {
            Some(num) -> Ok(Field(name, Repeated(parse_type(type_str)), num, oneof_name))
            None -> Error(Nil)
          }
        }
        ["optional", type_str, name, "=", num_str] -> {
          case string_to_int(num_str) {
            Some(num) -> Ok(Field(name, Optional(parse_type(type_str)), num, oneof_name))
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
      field.oneof_name
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
    Map(key, value) -> Map(fix_proto_type(key, enum_names), fix_proto_type(value, enum_names))
    other -> other
  }
}