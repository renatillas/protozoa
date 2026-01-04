//// Lexer for Protocol Buffer files
//// 
//// This module provides the lexer that tokenizes proto3 syntax.

import gleam/function
import gleam/set
import nibble/lexer
import protozoa/parser/token.{type ProtoToken}

/// Create a lexer for Protocol Buffer syntax
pub fn proto_lexer() -> lexer.Lexer(ProtoToken, Nil) {
  lexer.simple([
    // Comments (must come before other tokens to have priority)
    lexer.comment("//", function.identity) |> lexer.ignore,
    lexer.comment("/*", function.identity) |> lexer.ignore,
    // Keywords (order matters - must come before identifiers)
    // Longer keywords first to avoid partial matches
    // breaker pattern: [^a-zA-Z0-9_] means "not a word character" - keywords must be followed by non-word chars
    lexer.keyword("sfixed32", "[^a-zA-Z0-9_]", token.SFixed32Type),
    lexer.keyword("sfixed64", "[^a-zA-Z0-9_]", token.SFixed64Type),
    lexer.keyword("fixed32", "[^a-zA-Z0-9_]", token.Fixed32Type),
    lexer.keyword("fixed64", "[^a-zA-Z0-9_]", token.Fixed64Type),
    lexer.keyword("repeated", "[^a-zA-Z0-9_]", token.RepeatedKw),
    lexer.keyword("optional", "[^a-zA-Z0-9_]", token.OptionalKw),
    lexer.keyword("returns", "[^a-zA-Z0-9_]", token.ReturnsKw),
    lexer.keyword("service", "[^a-zA-Z0-9_]", token.ServiceKw),
    lexer.keyword("package", "[^a-zA-Z0-9_]", token.PackageKw),
    lexer.keyword("message", "[^a-zA-Z0-9_]", token.MessageKw),
    lexer.keyword("import", "[^a-zA-Z0-9_]", token.ImportKw),
    lexer.keyword("public", "[^a-zA-Z0-9_]", token.PublicKw),
    lexer.keyword("syntax", "[^a-zA-Z0-9_]", token.SyntaxKw),
    lexer.keyword("stream", "[^a-zA-Z0-9_]", token.StreamKw),
    lexer.keyword("oneof", "[^a-zA-Z0-9_]", token.OneofKw),
    lexer.keyword("option", "[^a-zA-Z0-9_]", token.OptionKw),
    lexer.keyword("uint32", "[^a-zA-Z0-9_]", token.UInt32Type),
    lexer.keyword("uint64", "[^a-zA-Z0-9_]", token.UInt64Type),
    lexer.keyword("sint32", "[^a-zA-Z0-9_]", token.SInt32Type),
    lexer.keyword("sint64", "[^a-zA-Z0-9_]", token.SInt64Type),
    lexer.keyword("double", "[^a-zA-Z0-9_]", token.DoubleType),
    lexer.keyword("string", "[^a-zA-Z0-9_]", token.StringType),
    lexer.keyword("bytes", "[^a-zA-Z0-9_]", token.BytesType),
    lexer.keyword("float", "[^a-zA-Z0-9_]", token.FloatType),
    lexer.keyword("int32", "[^a-zA-Z0-9_]", token.Int32Type),
    lexer.keyword("int64", "[^a-zA-Z0-9_]", token.Int64Type),
    lexer.keyword("bool", "[^a-zA-Z0-9_]", token.BoolType),
    lexer.keyword("enum", "[^a-zA-Z0-9_]", token.EnumKw),
    lexer.keyword("weak", "[^a-zA-Z0-9_]", token.WeakKw),
    lexer.keyword("map", "[^a-zA-Z0-9_]", token.MapKw),
    lexer.keyword("rpc", "[^a-zA-Z0-9_]", token.RpcKw),
    // String literals (support both " and ')
    lexer.string("\"", token.StringLit),
    lexer.string("'", token.StringLit),
    // Integer literals
    lexer.int(token.IntLit),
    // Identifiers (must come after keywords!)
    lexer.identifier(
      "[a-zA-Z_]",
      "[a-zA-Z0-9_]",
      reserved_words(),
      token.Identifier,
    ),
    // Symbols
    lexer.token("{", token.LBrace),
    lexer.token("}", token.RBrace),
    lexer.token("(", token.LParen),
    lexer.token(")", token.RParen),
    lexer.token("[", token.LBracket),
    lexer.token("]", token.RBracket),
    lexer.token("<", token.LAngle),
    lexer.token(">", token.RAngle),
    lexer.token("=", token.Equals),
    lexer.token(";", token.Semicolon),
    lexer.token(",", token.Comma),
    lexer.token(".", token.Dot),
    lexer.token(":", token.Colon),
    // Whitespace (ignore)
    lexer.whitespace(Nil) |> lexer.ignore,
  ])
}

/// Reserved words that cannot be used as identifiers
fn reserved_words() -> set.Set(String) {
  set.from_list([
    "syntax", "package", "import", "public", "weak", "message", "enum",
    "service", "rpc", "returns", "stream", "repeated", "optional", "oneof",
    "map", "option", "double", "float", "int32", "int64", "uint32", "uint64",
    "sint32", "sint64", "fixed32", "fixed64", "sfixed32", "sfixed64", "bool",
    "string", "bytes",
  ])
}
