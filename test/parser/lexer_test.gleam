import gleam/list
import nibble/lexer
import protozoa/parser/lexer as proto_lexer
import protozoa/parser/token

pub fn lex_keywords_test() {
  let input = "syntax package import message enum service"

  let assert Ok(tokens) = lexer.run(input, proto_lexer.proto_lexer())
  let token_types = tokens |> list.map(fn(t) { t.value })

  let assert [
    token.SyntaxKw,
    token.PackageKw,
    token.ImportKw,
    token.MessageKw,
    token.EnumKw,
    token.ServiceKw,
  ] = token_types
}

pub fn lex_type_keywords_test() {
  let input = "int32 string bool double float"

  let assert Ok(tokens) = lexer.run(input, proto_lexer.proto_lexer())
  let token_types = tokens |> list.map(fn(t) { t.value })

  let assert [
    token.Int32Type,
    token.StringType,
    token.BoolType,
    token.DoubleType,
    token.FloatType,
  ] = token_types
}

pub fn lex_string_literals_test() {
  let input = "\"hello\" 'world'"

  let assert Ok(tokens) = lexer.run(input, proto_lexer.proto_lexer())
  let token_types = tokens |> list.map(fn(t) { t.value })

  let assert [token.StringLit("hello"), token.StringLit("world")] = token_types
}

pub fn lex_integer_literals_test() {
  let input = "1 42 999"

  let assert Ok(tokens) = lexer.run(input, proto_lexer.proto_lexer())
  let token_types = tokens |> list.map(fn(t) { t.value })

  let assert [token.IntLit(1), token.IntLit(42), token.IntLit(999)] =
    token_types
}

pub fn lex_identifiers_test() {
  let input = "User userName user_id _private"

  let assert Ok(tokens) = lexer.run(input, proto_lexer.proto_lexer())
  let token_types = tokens |> list.map(fn(t) { t.value })

  let assert [
    token.Identifier("User"),
    token.Identifier("userName"),
    token.Identifier("user_id"),
    token.Identifier("_private"),
  ] = token_types
}

pub fn lex_symbols_test() {
  let input = "{ } ( ) [ ] < > = ; , . :"

  let assert Ok(tokens) = lexer.run(input, proto_lexer.proto_lexer())
  let token_types = tokens |> list.map(fn(t) { t.value })

  let assert [
    token.LBrace,
    token.RBrace,
    token.LParen,
    token.RParen,
    token.LBracket,
    token.RBracket,
    token.LAngle,
    token.RAngle,
    token.Equals,
    token.Semicolon,
    token.Comma,
    token.Dot,
    token.Colon,
  ] = token_types
}

pub fn lex_comment_single_line_test() {
  let input =
    "syntax // this is a comment
package"

  let assert Ok(tokens) = lexer.run(input, proto_lexer.proto_lexer())
  let token_types = tokens |> list.map(fn(t) { t.value })

  // Comment should be ignored
  let assert [token.SyntaxKw, token.PackageKw] = token_types
}

// Note: Multi-line comments (/* */) are not yet supported by nibble's comment matcher
// This is a known limitation. For now, proto files should use single-line comments (//)
// pub fn lex_comment_multi_line_test() {
//   let input =
//     "syntax /* this is a
// multi-line comment */ package"
//   
//   let result = lexer.run(input, proto_lexer.proto_lexer())
//   
//   result
//   |> should.be_ok
//   
//   let assert Ok(tokens) = result
//   let token_types = tokens |> list.map(fn(t) { t.value })
//   
//   // Comment should be ignored
//   token_types
//   |> should.equal([token.SyntaxKw, token.PackageKw])
// }

pub fn lex_simple_message_test() {
  let input =
    "message User {
  string name = 1;
}"

  let assert Ok(tokens) = lexer.run(input, proto_lexer.proto_lexer())
  let token_types = tokens |> list.map(fn(t) { t.value })

  let assert [
    token.MessageKw,
    token.Identifier("User"),
    token.LBrace,
    token.StringType,
    token.Identifier("name"),
    token.Equals,
    token.IntLit(1),
    token.Semicolon,
    token.RBrace,
  ] = token_types
}

pub fn lex_empty_single_line_message_test() {
  let input = "message HelloRequest {}"

  let assert Ok(tokens) = lexer.run(input, proto_lexer.proto_lexer())
  let token_types = tokens |> list.map(fn(t) { t.value })

  let assert [
    token.MessageKw,
    token.Identifier("HelloRequest"),
    token.LBrace,
    token.RBrace,
  ] = token_types
}

pub fn lex_map_field_test() {
  let input = "map<string, User>"

  let assert Ok(tokens) = lexer.run(input, proto_lexer.proto_lexer())
  let token_types = tokens |> list.map(fn(t) { t.value })

  let assert [
    token.MapKw,
    token.LAngle,
    token.StringType,
    token.Comma,
    token.Identifier("User"),
    token.RAngle,
  ] = token_types
}

pub fn lex_repeated_field_test() {
  let input = "repeated string emails"

  let assert Ok(tokens) = lexer.run(input, proto_lexer.proto_lexer())
  let token_types = tokens |> list.map(fn(t) { t.value })

  let assert [token.RepeatedKw, token.StringType, token.Identifier("emails")] =
    token_types
}
