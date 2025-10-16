# Protozoa 🦠

A Protocol Buffers library for Gleam, providing encoding and decoding of protobuf messages.

[![Package Version](https://img.shields.io/hexpm/v/protozoa)](https://hex.pm/packages/protozoa)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/protozoa/)

## Features

✅ **Complete proto3 support** - Messages, enums, nested types, oneofs, maps, and repeated fields  
✅ **Type-safe encoding/decoding** - Compile-time guarantees for message structure  
✅ **All field types** - Full support for all scalar types, including fixed32/fixed64  
✅ **Wire format compliance** - Correct Protocol Buffers binary format  
✅ **Performance optimized** - Efficient encoding and decoding operations  

## Installation

Add to your `gleam.toml`:

```toml
[dependencies]
protozoa = ">= 2.0.3 and < 3.0.0"
```

## Usage

### Basic Encoding and Decoding

```gleam
import protozoa/encode
import protozoa/decode

// Define your message type
pub type User {
  User(name: String, age: Int, active: Bool)
}

// Encode a message
pub fn encode_user(user: User) -> BitArray {
  encode.message([
    encode.string_field(1, user.name),
    encode.int32_field(2, user.age),
    encode.bool_field(3, user.active),
  ])
}

// Create a decoder
fn user_decoder() -> decode.Decoder(User) {
  use name <- decode.then(decode.string_with_default(1, ""))
  use age <- decode.then(decode.int32_with_default(2, 0))
  use active <- decode.then(decode.bool_with_default(3, False))
  decode.success(User(name: name, age: age, active: active))
}

// Decode a message
pub fn decode_user(data: BitArray) -> Result(User, List(decode.DecodeError)) {
  decode.run(data, user_decoder())
}
```

## Supported Features

### Protocol Buffer Features

| Feature | Support | Description |
|---------|---------|-------------|
| **Messages** | ✅ Complete | Message definitions with all field types |
| **Enums** | ✅ Complete | Enum definitions with proper value handling |
| **Services** | ✅ Complete | gRPC service definitions with streaming support |
| **Nested Types** | ✅ Complete | Messages and enums nested within messages |
| **Oneofs** | ✅ Complete | Union types with proper variant handling |
| **Maps** | ✅ Complete | Map fields with Dict support |
| **Repeated Fields** | ✅ Complete | List/array fields with proper encoding |
| **Import System** | ✅ Complete | Cross-file dependencies and path resolution |
| **Well-Known Types** | ✅ Complete | Google's standard types auto-imported |
| **Field Options** | ✅ Complete | deprecated, json_name, packed options |

### RPC/Service Features

| Streaming Type | Syntax | Support | Generated Code |
|---------------|--------|---------|----------------|
| **Unary** | `rpc Method(Request) returns (Response)` | ✅ | Client/server stubs |
| **Server Streaming** | `rpc Method(Request) returns (stream Response)` | ✅ | Streaming support |
| **Client Streaming** | `rpc Method(stream Request) returns (Response)` | ✅ | Streaming support |
| **Bidirectional** | `rpc Method(stream Request) returns (stream Response)` | ✅ | Bidirectional streaming |

### Field Types

| Proto Type | Gleam Type | Wire Type | Support |
|------------|------------|-----------|---------|
| `bool` | `Bool` | Varint | ✅ |
| `int32`, `sint32` | `Int` | Varint | ✅ |
| `int64`, `sint64` | `Int` | Varint | ✅ |
| `uint32`, `uint64` | `Int` | Varint | ✅ |
| `fixed32`, `sfixed32` | `Int` | Fixed32 | ✅ |
| `fixed64`, `sfixed64` | `Int` | Fixed64 | ✅ |
| `float` | `Float` | Fixed32 | ✅ |
| `double` | `Float` | Fixed64 | ✅ |
| `string` | `String` | Length-delimited | ✅ |
| `bytes` | `BitArray` | Length-delimited | ✅ |
| Message types | Custom types | Length-delimited | ✅ |
| Enum types | Custom types | Varint | ✅ |


## Contributing

Contributions are welcome! Please feel free to submit issues, feature requests, or pull requests.

## License

This project is licensed under the MIT License.

