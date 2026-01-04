//// Token definitions for Protocol Buffer lexer
//// 
//// This module defines all tokens that can appear in a proto3 file.

import gleam/int

/// Represents all possible tokens in Protocol Buffer syntax
pub type ProtoToken {
  // Keywords
  SyntaxKw
  PackageKw
  ImportKw
  PublicKw
  WeakKw
  MessageKw
  EnumKw
  ServiceKw
  RpcKw
  ReturnsKw
  StreamKw
  OneofKw
  MapKw
  RepeatedKw
  OptionalKw
  OptionKw

  // Type keywords
  DoubleType
  FloatType
  Int32Type
  Int64Type
  UInt32Type
  UInt64Type
  SInt32Type
  SInt64Type
  Fixed32Type
  Fixed64Type
  SFixed32Type
  SFixed64Type
  BoolType
  StringType
  BytesType

  // Literals
  StringLit(String)
  IntLit(Int)
  Identifier(String)

  // Symbols
  LBrace
  RBrace
  LParen
  RParen
  LBracket
  RBracket
  LAngle
  RAngle
  Equals
  Semicolon
  Comma
  Dot
  Colon
}

/// Get a human-readable description of a token for error messages
pub fn describe(token: ProtoToken) -> String {
  case token {
    SyntaxKw -> "keyword 'syntax'"
    PackageKw -> "keyword 'package'"
    ImportKw -> "keyword 'import'"
    PublicKw -> "keyword 'public'"
    WeakKw -> "keyword 'weak'"
    MessageKw -> "keyword 'message'"
    EnumKw -> "keyword 'enum'"
    ServiceKw -> "keyword 'service'"
    RpcKw -> "keyword 'rpc'"
    ReturnsKw -> "keyword 'returns'"
    StreamKw -> "keyword 'stream'"
    OneofKw -> "keyword 'oneof'"
    MapKw -> "keyword 'map'"
    RepeatedKw -> "keyword 'repeated'"
    OptionalKw -> "keyword 'optional'"
    OptionKw -> "keyword 'option'"

    DoubleType -> "type 'double'"
    FloatType -> "type 'float'"
    Int32Type -> "type 'int32'"
    Int64Type -> "type 'int64'"
    UInt32Type -> "type 'uint32'"
    UInt64Type -> "type 'uint64'"
    SInt32Type -> "type 'sint32'"
    SInt64Type -> "type 'sint64'"
    Fixed32Type -> "type 'fixed32'"
    Fixed64Type -> "type 'fixed64'"
    SFixed32Type -> "type 'sfixed32'"
    SFixed64Type -> "type 'sfixed64'"
    BoolType -> "type 'bool'"
    StringType -> "type 'string'"
    BytesType -> "type 'bytes'"

    StringLit(s) -> "string literal \"" <> s <> "\""
    IntLit(n) -> "integer " <> int.to_string(n)
    Identifier(s) -> "identifier '" <> s <> "'"

    LBrace -> "'{'"
    RBrace -> "'}'"
    LParen -> "'('"
    RParen -> "')'"
    LBracket -> "'['"
    RBracket -> "']'"
    LAngle -> "'<'"
    RAngle -> "'>'"
    Equals -> "'='"
    Semicolon -> "';'"
    Comma -> "','"
    Dot -> "'.'"
    Colon -> "':'"
  }
}
