//// Parser combinators for Protocol Buffer syntax
//// 
//// This module provides the core parser combinators that build up
//// the full proto3 parser.

import gleam/option
import gleam/string
import nibble
import protozoa/parser/token

// ---- BASIC PARSERS ----

/// Parse an identifier token
/// In proto3, keywords can also be used as identifiers (field names, etc.)
pub fn identifier() -> nibble.Parser(String, token.ProtoToken, Nil) {
  use tok <- nibble.take_map("expected identifier")
  case tok {
    token.Identifier(name) -> option.Some(name)
    // Keywords can be used as field names in proto3
    token.SyntaxKw -> option.Some("syntax")
    token.PackageKw -> option.Some("package")
    token.ImportKw -> option.Some("import")
    token.PublicKw -> option.Some("public")
    token.WeakKw -> option.Some("weak")
    token.MessageKw -> option.Some("message")
    token.EnumKw -> option.Some("enum")
    token.ServiceKw -> option.Some("service")
    token.RpcKw -> option.Some("rpc")
    token.ReturnsKw -> option.Some("returns")
    token.StreamKw -> option.Some("stream")
    token.OneofKw -> option.Some("oneof")
    token.MapKw -> option.Some("map")
    token.RepeatedKw -> option.Some("repeated")
    token.OptionalKw -> option.Some("optional")
    token.OptionKw -> option.Some("option")
    _ -> option.None
  }
}

/// Parse a string literal token
pub fn string_literal() -> nibble.Parser(String, token.ProtoToken, Nil) {
  use tok <- nibble.take_map("expected string literal")
  case tok {
    token.StringLit(s) -> option.Some(s)
    _ -> option.None
  }
}

/// Parse an integer literal token
pub fn integer() -> nibble.Parser(Int, token.ProtoToken, Nil) {
  use tok <- nibble.take_map("expected integer")
  case tok {
    token.IntLit(n) -> option.Some(n)
    _ -> option.None
  }
}

/// Parse a qualified identifier (e.g., "google.protobuf.Timestamp")
pub fn qualified_identifier() -> nibble.Parser(String, token.ProtoToken, Nil) {
  use first <- nibble.do(identifier())
  use rest <- nibble.do(
    many({
      use _ <- nibble.do(nibble.token(token.Dot))
      identifier()
    }),
  )
  nibble.return(string.join([first, ..rest], "."))
}

/// Optionally parse something, returning None if it doesn't match
pub fn optional(
  parser: nibble.Parser(a, token.ProtoToken, Nil),
) -> nibble.Parser(option.Option(a), token.ProtoToken, Nil) {
  nibble.one_of([
    parser |> nibble.map(option.Some),
    nibble.return(option.None),
  ])
}

/// Try to match a specific token, returning None if it doesn't match
pub fn optional_token(
  tok: token.ProtoToken,
) -> nibble.Parser(option.Option(Nil), token.ProtoToken, Nil) {
  optional(nibble.token(tok) |> nibble.replace(Nil))
}

/// Parse zero or more occurrences
pub fn many(
  parser: nibble.Parser(a, token.ProtoToken, Nil),
) -> nibble.Parser(List(a), token.ProtoToken, Nil) {
  nibble.many(parser)
}

/// Parse one or more occurrences  
pub fn many1(
  parser: nibble.Parser(a, token.ProtoToken, Nil),
) -> nibble.Parser(List(a), token.ProtoToken, Nil) {
  nibble.many1(parser)
}

/// Parse one or more occurrences separated by a separator
pub fn sep1(
  parser: nibble.Parser(a, token.ProtoToken, Nil),
  separator: nibble.Parser(b, token.ProtoToken, Nil),
) -> nibble.Parser(List(a), token.ProtoToken, Nil) {
  use first <- nibble.do(parser)
  use rest <- nibble.do(
    many({
      use _ <- nibble.do(separator)
      parser
    }),
  )
  nibble.return([first, ..rest])
}
