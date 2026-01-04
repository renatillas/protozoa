//// Main parser module for Protocol Buffer files
//// 
//// This module contains the top-level parsers for proto3 syntax.

import gleam/list
import gleam/option.{type Option}
import nibble
import protozoa/parser/combinator
import protozoa/parser/token

pub type Type {
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
  Repeated(Type)
  Optional(Type)
  Map(Type, Type)
}

pub type HttpMethod {
  Get
  Post
  Put
  Delete
  Patch
}

pub type Method {
  Method(
    name: String,
    input_type: String,
    output_type: String,
    client_streaming: Bool,
    server_streaming: Bool,
    http_method: Option(HttpMethod),
    http_path: Option(String),
  )
}

pub type Service {
  Service(name: String, methods: List(Method))
}

pub type Import {
  Import(path: String, public: Bool, weak: Bool)
}

pub type EnumValue {
  EnumValue(name: String, number: Int)
}

pub type Enum {
  Enum(name: String, values: List(EnumValue))
}

type FieldModifier {
  ModRepeated
  ModOptional
}

type MessageItem {
  ItemField(Field)
  ItemOneof(Oneof)
  ItemNestedMessage(Message)
  ItemNestedEnum(Enum)
}

pub type FieldOption {
  Deprecated(Bool)
  JsonName(String)
  Packed(Bool)
}

pub type Field {
  Field(
    name: String,
    field_type: Type,
    number: Int,
    oneof_name: Option(String),
    options: List(FieldOption),
  )
}

pub type Oneof {
  Oneof(name: String, fields: List(Field))
}

pub type Message {
  Message(
    name: String,
    fields: List(Field),
    oneofs: List(Oneof),
    nested_messages: List(Message),
    nested_enums: List(Enum),
  )
}

/// Parse the syntax declaration (e.g., syntax = "proto3";)
pub fn syntax() -> nibble.Parser(String, token.ProtoToken, Nil) {
  use _ <- nibble.do(nibble.token(token.SyntaxKw))
  use _ <- nibble.do(nibble.token(token.Equals))
  use version <- nibble.do(combinator.string_literal())
  use _ <- nibble.do(nibble.token(token.Semicolon))

  case version {
    "proto3" -> nibble.return("proto3")
    "proto2" -> nibble.throw("proto2 not supported, only proto3")
    _ -> nibble.throw("invalid syntax version, expected 'proto3'")
  }
}

// ---- PACKAGE PARSER ----

/// Parse an optional package declaration
pub fn package() -> nibble.Parser(Option(String), token.ProtoToken, Nil) {
  combinator.optional(package_inner())
}

fn package_inner() -> nibble.Parser(String, token.ProtoToken, Nil) {
  use _ <- nibble.do(nibble.token(token.PackageKw))
  use name <- nibble.do(combinator.qualified_identifier())
  use _ <- nibble.do(nibble.token(token.Semicolon))
  nibble.return(name)
}

// ---- SERVICE PARSER ----

/// Parse zero or more service definitions
pub fn services() -> nibble.Parser(List(Service), token.ProtoToken, Nil) {
  combinator.many(service())
}

pub fn service() -> nibble.Parser(Service, token.ProtoToken, Nil) {
  use _ <- nibble.do(nibble.token(token.ServiceKw))
  use name <- nibble.do(combinator.identifier())
  use _ <- nibble.do(nibble.token(token.LBrace))
  use methods <- nibble.do(combinator.many(rpc_method()))
  use _ <- nibble.do(nibble.token(token.RBrace))

  nibble.return(Service(name: name, methods: methods))
}

fn rpc_method() -> nibble.Parser(Method, token.ProtoToken, Nil) {
  use _ <- nibble.do(nibble.token(token.RpcKw))
  use name <- nibble.do(combinator.identifier())
  use _ <- nibble.do(nibble.token(token.LParen))
  use client_streaming <- nibble.do(combinator.optional_token(token.StreamKw))
  use input_type <- nibble.do(combinator.identifier())
  use _ <- nibble.do(nibble.token(token.RParen))
  use _ <- nibble.do(nibble.token(token.ReturnsKw))
  use _ <- nibble.do(nibble.token(token.LParen))
  use server_streaming <- nibble.do(combinator.optional_token(token.StreamKw))
  use output_type <- nibble.do(combinator.identifier())
  use _ <- nibble.do(nibble.token(token.RParen))
  use http_info <- nibble.do(
    nibble.one_of([
      // Method ends with semicolon (no options)
      nibble.token(token.Semicolon)
        |> nibble.replace(#(option.None, option.None)),
      // Method has an options block
      nibble.token(token.LBrace) |> nibble.then(fn(_) { parse_rpc_options() }),
    ]),
  )

  let #(http_method, http_path) = http_info

  nibble.return(Method(
    name: name,
    input_type: input_type,
    output_type: output_type,
    client_streaming: option.is_some(client_streaming),
    server_streaming: option.is_some(server_streaming),
    http_method: http_method,
    http_path: http_path,
  ))
}

/// Parse RPC options block and extract HTTP annotation
fn parse_rpc_options() -> nibble.Parser(
  #(Option(HttpMethod), Option(String)),
  token.ProtoToken,
  Nil,
) {
  use options <- nibble.do(combinator.many(parse_rpc_option()))
  use _ <- nibble.do(nibble.token(token.RBrace))

  // Find the HTTP option if present
  let http_info =
    list.fold(options, #(option.None, option.None), fn(acc, opt) {
      case opt {
        option.Some(info) -> info
        option.None -> acc
      }
    })

  nibble.return(http_info)
}

/// Parse a single RPC option (option ... = ...;)
fn parse_rpc_option() -> nibble.Parser(
  Option(#(Option(HttpMethod), Option(String))),
  token.ProtoToken,
  Nil,
) {
  use _ <- nibble.do(nibble.token(token.OptionKw))
  use _ <- nibble.do(nibble.token(token.LParen))
  // Parse option name (e.g., google.api.http)
  use option_name <- nibble.do(combinator.qualified_identifier())
  use _ <- nibble.do(nibble.token(token.RParen))
  use _ <- nibble.do(nibble.token(token.Equals))

  case option_name {
    "google.api.http" -> {
      use _ <- nibble.do(nibble.token(token.LBrace))
      use http_info <- nibble.do(parse_http_annotation())
      use _ <- nibble.do(nibble.token(token.RBrace))
      use _ <- nibble.do(nibble.token(token.Semicolon))
      nibble.return(option.Some(http_info))
    }
    _ -> {
      // Skip unknown options
      use _ <- nibble.do(skip_option_value())
      use _ <- nibble.do(nibble.token(token.Semicolon))
      nibble.return(option.None)
    }
  }
}

/// Parse HTTP annotation body { get: "/path" body: "*" }
fn parse_http_annotation() -> nibble.Parser(
  #(Option(HttpMethod), Option(String)),
  token.ProtoToken,
  Nil,
) {
  use entries <- nibble.do(combinator.many(http_annotation_entry()))

  // Find method and path from entries
  let result =
    list.fold(entries, #(option.None, option.None), fn(acc, entry) {
      case entry {
        #(method, path) -> {
          let new_method = case method {
            option.Some(_) -> method
            option.None -> acc.0
          }
          let new_path = case path {
            option.Some(_) -> path
            option.None -> acc.1
          }
          #(new_method, new_path)
        }
      }
    })

  nibble.return(result)
}

/// Parse a single entry like "get: "/path"" or "body: "*""
fn http_annotation_entry() -> nibble.Parser(
  #(Option(HttpMethod), Option(String)),
  token.ProtoToken,
  Nil,
) {
  use key <- nibble.do(combinator.identifier())
  use _ <- nibble.do(nibble.token(token.Colon))
  use value <- nibble.do(combinator.string_literal())

  case key {
    "get" -> nibble.return(#(option.Some(Get), option.Some(value)))
    "post" -> nibble.return(#(option.Some(Post), option.Some(value)))
    "put" -> nibble.return(#(option.Some(Put), option.Some(value)))
    "delete" -> nibble.return(#(option.Some(Delete), option.Some(value)))
    "patch" -> nibble.return(#(option.Some(Patch), option.Some(value)))
    // body, custom, or other fields - ignore but consume
    _ -> nibble.return(#(option.None, option.None))
  }
}

/// Skip an option value (could be string, number, or nested block)
fn skip_option_value() -> nibble.Parser(Nil, token.ProtoToken, Nil) {
  nibble.one_of([
    // Skip string literal
    combinator.string_literal() |> nibble.replace(Nil),
    // Skip integer literal
    combinator.integer() |> nibble.replace(Nil),
    // Skip nested block
    nibble.token(token.LBrace)
      |> nibble.then(fn(_) { skip_until_closing_brace(1) }),
  ])
}

fn skip_until_closing_brace(
  depth: Int,
) -> nibble.Parser(Nil, token.ProtoToken, Nil) {
  case depth {
    0 -> nibble.return(Nil)
    _ -> {
      use tok <- nibble.do(nibble.any())
      case tok {
        token.LBrace -> skip_until_closing_brace(depth + 1)
        token.RBrace -> skip_until_closing_brace(depth - 1)
        _ -> skip_until_closing_brace(depth)
      }
    }
  }
}

// ---- IMPORT PARSER ----

/// Parse zero or more import statements
pub fn imports() -> nibble.Parser(List(Import), token.ProtoToken, Nil) {
  combinator.many(import_statement())
}

fn import_statement() -> nibble.Parser(Import, token.ProtoToken, Nil) {
  use _ <- nibble.do(nibble.token(token.ImportKw))
  use public <- nibble.do(combinator.optional_token(token.PublicKw))
  use weak <- nibble.do(combinator.optional_token(token.WeakKw))
  use path <- nibble.do(combinator.string_literal())
  use _ <- nibble.do(nibble.token(token.Semicolon))

  nibble.return(Import(
    path: path,
    public: option.is_some(public),
    weak: option.is_some(weak),
  ))
}

// ---- ENUM PARSER ----

/// Parse an enum definition
pub fn enum_def() -> nibble.Parser(Enum, token.ProtoToken, Nil) {
  use _ <- nibble.do(nibble.token(token.EnumKw))
  use name <- nibble.do(combinator.identifier())
  use _ <- nibble.do(nibble.token(token.LBrace))
  use values <- nibble.do(combinator.many(enum_value()))
  use _ <- nibble.do(nibble.token(token.RBrace))

  nibble.return(Enum(name: name, values: values))
}

fn enum_value() -> nibble.Parser(EnumValue, token.ProtoToken, Nil) {
  use name <- nibble.do(combinator.identifier())
  use _ <- nibble.do(nibble.token(token.Equals))
  use number <- nibble.do(combinator.integer())
  use _ <- nibble.do(nibble.token(token.Semicolon))

  nibble.return(EnumValue(name: name, number: number))
}

// ---- TYPE PARSER ----

/// Parse a proto type (scalar, message, or map)
pub fn proto_type() -> nibble.Parser(Type, token.ProtoToken, Nil) {
  nibble.one_of([map_type(), scalar_type(), message_type()])
}

fn scalar_type() -> nibble.Parser(Type, token.ProtoToken, Nil) {
  nibble.one_of([
    nibble.token(token.DoubleType) |> nibble.replace(Double),
    nibble.token(token.FloatType) |> nibble.replace(Float),
    nibble.token(token.Int32Type) |> nibble.replace(Int32),
    nibble.token(token.Int64Type) |> nibble.replace(Int64),
    nibble.token(token.UInt32Type) |> nibble.replace(UInt32),
    nibble.token(token.UInt64Type) |> nibble.replace(UInt64),
    nibble.token(token.SInt32Type) |> nibble.replace(SInt32),
    nibble.token(token.SInt64Type) |> nibble.replace(SInt64),
    nibble.token(token.Fixed32Type) |> nibble.replace(Fixed32),
    nibble.token(token.Fixed64Type) |> nibble.replace(Fixed64),
    nibble.token(token.SFixed32Type) |> nibble.replace(SFixed32),
    nibble.token(token.SFixed64Type) |> nibble.replace(SFixed64),
    nibble.token(token.BoolType) |> nibble.replace(Bool),
    nibble.token(token.StringType) |> nibble.replace(String),
    nibble.token(token.BytesType) |> nibble.replace(Bytes),
  ])
}

fn message_type() -> nibble.Parser(Type, token.ProtoToken, Nil) {
  use name <- nibble.do(combinator.qualified_identifier())
  nibble.return(MessageType(name))
}

fn map_type() -> nibble.Parser(Type, token.ProtoToken, Nil) {
  use _ <- nibble.do(nibble.token(token.MapKw))
  use _ <- nibble.do(nibble.token(token.LAngle))
  use key_type <- nibble.do(map_key_type())
  use _ <- nibble.do(nibble.token(token.Comma))
  use value_type <- nibble.do(proto_type())
  use _ <- nibble.do(nibble.token(token.RAngle))

  nibble.return(Map(key_type, value_type))
}

fn map_key_type() -> nibble.Parser(Type, token.ProtoToken, Nil) {
  // Map keys can only be certain scalar types
  nibble.one_of([
    nibble.token(token.Int32Type) |> nibble.replace(Int32),
    nibble.token(token.Int64Type) |> nibble.replace(Int64),
    nibble.token(token.UInt32Type) |> nibble.replace(UInt32),
    nibble.token(token.UInt64Type) |> nibble.replace(UInt64),
    nibble.token(token.SInt32Type) |> nibble.replace(SInt32),
    nibble.token(token.SInt64Type) |> nibble.replace(SInt64),
    nibble.token(token.Fixed32Type) |> nibble.replace(Fixed32),
    nibble.token(token.Fixed64Type) |> nibble.replace(Fixed64),
    nibble.token(token.SFixed32Type) |> nibble.replace(SFixed32),
    nibble.token(token.SFixed64Type) |> nibble.replace(SFixed64),
    nibble.token(token.BoolType) |> nibble.replace(Bool),
    nibble.token(token.StringType) |> nibble.replace(String),
  ])
}

// ---- MESSAGE PARSER ----

/// Parse a message definition
pub fn message() -> nibble.Parser(Message, token.ProtoToken, Nil) {
  use _ <- nibble.do(nibble.token(token.MessageKw))
  use name <- nibble.do(combinator.identifier())
  use _ <- nibble.do(nibble.token(token.LBrace))
  use items <- nibble.do(combinator.many(message_item()))
  use _ <- nibble.do(nibble.token(token.RBrace))

  // Separate fields, oneofs, nested messages, and nested enums
  let #(fields, oneofs, nested_messages, nested_enums) =
    partition_message_items(items)

  nibble.return(Message(
    name: name,
    fields: fields,
    oneofs: oneofs,
    nested_messages: nested_messages,
    nested_enums: nested_enums,
  ))
}

fn message_item() -> nibble.Parser(MessageItem, token.ProtoToken, Nil) {
  nibble.one_of([
    oneof() |> nibble.map(ItemOneof),
    field() |> nibble.map(ItemField),
    message() |> nibble.map(ItemNestedMessage),
    enum_def() |> nibble.map(ItemNestedEnum),
  ])
}

fn partition_message_items(
  items: List(MessageItem),
) -> #(List(Field), List(Oneof), List(Message), List(Enum)) {
  partition_helper(items, [], [], [], [])
}

fn partition_helper(
  items: List(MessageItem),
  fields: List(Field),
  oneofs: List(Oneof),
  messages: List(Message),
  enums: List(Enum),
) -> #(List(Field), List(Oneof), List(Message), List(Enum)) {
  case items {
    [] -> #(
      list.reverse(fields),
      list.reverse(oneofs),
      list.reverse(messages),
      list.reverse(enums),
    )
    [ItemField(f), ..rest] ->
      partition_helper(rest, [f, ..fields], oneofs, messages, enums)
    [ItemOneof(o), ..rest] ->
      partition_helper(rest, fields, [o, ..oneofs], messages, enums)
    [ItemNestedMessage(m), ..rest] ->
      partition_helper(rest, fields, oneofs, [m, ..messages], enums)
    [ItemNestedEnum(e), ..rest] ->
      partition_helper(rest, fields, oneofs, messages, [e, ..enums])
  }
}

fn oneof() -> nibble.Parser(Oneof, token.ProtoToken, Nil) {
  use _ <- nibble.do(nibble.token(token.OneofKw))
  use name <- nibble.do(combinator.identifier())
  use _ <- nibble.do(nibble.token(token.LBrace))
  use fields <- nibble.do(combinator.many(oneof_field(name)))
  use _ <- nibble.do(nibble.token(token.RBrace))

  nibble.return(Oneof(name: name, fields: fields))
}

fn oneof_field(
  oneof_name: String,
) -> nibble.Parser(Field, token.ProtoToken, Nil) {
  use field_type <- nibble.do(proto_type())
  use name <- nibble.do(combinator.identifier())
  use _ <- nibble.do(nibble.token(token.Equals))
  use number <- nibble.do(combinator.integer())
  use _ <- nibble.do(nibble.token(token.Semicolon))

  nibble.return(
    Field(
      name: name,
      field_type: field_type,
      number: number,
      oneof_name: option.Some(oneof_name),
      options: [],
    ),
  )
}

fn field() -> nibble.Parser(Field, token.ProtoToken, Nil) {
  use modifier <- nibble.do(combinator.optional(field_modifier()))
  use field_type <- nibble.do(proto_type())
  use name <- nibble.do(combinator.identifier())
  use _ <- nibble.do(nibble.token(token.Equals))
  use number <- nibble.do(combinator.integer())
  use options <- nibble.do(combinator.optional(field_options()))
  use _ <- nibble.do(nibble.token(token.Semicolon))

  let final_type = case modifier {
    option.Some(ModRepeated) -> Repeated(field_type)
    option.Some(ModOptional) -> Optional(field_type)
    option.None -> field_type
  }

  nibble.return(Field(
    name: name,
    field_type: final_type,
    number: number,
    oneof_name: option.None,
    options: option.unwrap(options, []),
  ))
}

fn field_options() -> nibble.Parser(List(FieldOption), token.ProtoToken, Nil) {
  use _ <- nibble.do(nibble.token(token.LBracket))
  use options <- nibble.do(combinator.sep1(
    field_option(),
    nibble.token(token.Comma),
  ))
  use _ <- nibble.do(nibble.token(token.RBracket))
  nibble.return(options)
}

fn field_option() -> nibble.Parser(FieldOption, token.ProtoToken, Nil) {
  nibble.one_of([deprecated_option(), json_name_option(), packed_option()])
}

fn deprecated_option() -> nibble.Parser(FieldOption, token.ProtoToken, Nil) {
  use _ <- nibble.do(nibble.token(token.Identifier("deprecated")))
  use _ <- nibble.do(nibble.token(token.Equals))
  use value <- nibble.do(bool_literal())
  nibble.return(Deprecated(value))
}

fn json_name_option() -> nibble.Parser(FieldOption, token.ProtoToken, Nil) {
  use _ <- nibble.do(nibble.token(token.Identifier("json_name")))
  use _ <- nibble.do(nibble.token(token.Equals))
  use value <- nibble.do(combinator.string_literal())
  nibble.return(JsonName(value))
}

fn packed_option() -> nibble.Parser(FieldOption, token.ProtoToken, Nil) {
  use _ <- nibble.do(nibble.token(token.Identifier("packed")))
  use _ <- nibble.do(nibble.token(token.Equals))
  use value <- nibble.do(bool_literal())
  nibble.return(Packed(value))
}

fn bool_literal() -> nibble.Parser(Bool, token.ProtoToken, Nil) {
  nibble.one_of([
    nibble.token(token.Identifier("true")) |> nibble.replace(True),
    nibble.token(token.Identifier("false")) |> nibble.replace(False),
  ])
}

fn field_modifier() -> nibble.Parser(FieldModifier, token.ProtoToken, Nil) {
  nibble.one_of([
    nibble.token(token.RepeatedKw) |> nibble.replace(ModRepeated),
    nibble.token(token.OptionalKw) |> nibble.replace(ModOptional),
  ])
}
