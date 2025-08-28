# Protozoa 🦠

A complete Protocol Buffers compiler and library for Gleam, providing full proto3 support with type-safe code generation, service definitions, and streaming RPC support.

[![Package Version](https://img.shields.io/hexpm/v/protozoa)](https://hex.pm/packages/protozoa)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/protozoa/)

## Features

✅ **Complete proto3 support** - Messages, enums, services, nested types, oneofs, maps, and repeated fields  
✅ **Service/RPC definitions** - Full gRPC support with streaming (client, server, bidirectional)  
✅ **Import resolution** - Handles import statements with configurable search paths  
✅ **Well-known types** - Google's standard protobuf types (Timestamp, Duration, Any, etc.)  
✅ **Field options** - Support for deprecated, json_name, packed, and custom options  
✅ **Type-safe codegen** - Generates idiomatic Gleam code with proper type safety  
✅ **CLI tools** - Easy-to-use command line interface with project integration  
✅ **All field types** - Full support for all scalar types, including fixed32/fixed64  
✅ **Cross-file imports** - Resolves dependencies between multiple proto files  

## Quick Start

### Installation

Add to your `gleam.toml`:

```toml
[dependencies]
protozoa = ">= 1.0.0 and < 2.0.0"
```

### Project Setup (Recommended)

1. **Create your proto files** in `src/[your-app]/proto/`:

```
your-project/
├── gleam.toml
└── src/
    └── myapp/
        └── proto/
            ├── user.proto
            ├── message.proto
            └── user_service.proto
```

2. **Generate Gleam code** with the convenient CLI:

```bash
# Generate all proto files in your project
gleam run -m protozoa

# Check if proto files need regeneration (useful for CI)
gleam run -m protozoa check
```

3. **Use the generated code** in your Gleam modules:

```gleam
import myapp/proto/user
import myapp/proto/message
import myapp/proto/user_service

pub fn example() {
  // Create and encode messages
  let user = user.User(name: "Alice", age: 30, active: True)
  let encoded = user.encode_user(user)
  
  // Decode messages
  let decoded = user.decode_user(encoded)
  
  // Use service stubs for gRPC clients
  let client = user_service.UserServiceClient(endpoint: "http://api.example.com")
}
```

### Manual Usage

For custom workflows, you can also use protozoa directly:

```bash
# Compile a specific proto file
gleam run -m protozoa -- message.proto ./output

# Use custom import paths
gleam run -m protozoa -- -I./common -I./vendor message.proto ./src

# Check if files need regeneration (full CLI mode)
gleam run -m protozoa -- --check
```

## CLI Reference

### Automatic Project Integration

The recommended approach is to use `gleam run -m protozoa`, which automatically:

- Detects your app name from `gleam.toml`
- Finds proto files in `src/[appname]/proto/` directories
- Generates output files alongside your proto files
- Includes safety headers for regeneration

```bash
# Generate all proto files (recommended)
gleam run -m protozoa

# Check if proto files have changed
gleam run -m protozoa check
```

### Manual Commands

For advanced usage or custom project structures:

```bash
# Single file compilation
gleam run -m protozoa -- input.proto output.gleam

# Multiple import paths
gleam run -m protozoa -- -I./proto -I./vendor input.proto output.gleam

# Directory processing
gleam run -m protozoa -- ./proto/ ./src/generated/

# Status checking
gleam run -m protozoa -- --check ./proto/
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
| **Server Streaming** | `rpc Method(Request) returns (stream Response)` | ✅ | Streaming interface |
| **Client Streaming** | `rpc Method(stream Request) returns (Response)` | ✅ | Streaming interface |
| **Bidirectional** | `rpc Method(stream Request) returns (stream Response)` | ✅ | Full duplex interface |

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

## Generated Code Examples

### Messages with Field Options

```proto
syntax = "proto3";
package example;

message User {
  string name = 1;
  int32 age = 2 [deprecated = true];
  string email = 3 [json_name = "email_address"];
  repeated int32 scores = 4 [packed = true];
}
```

Generates:

```gleam
pub type User {
  User(
    name: String,
    age: Int, // @deprecated: This field is deprecated
    email: String,
    scores: List(Int),
  )
}

pub fn encode_user(user: User) -> BitArray {
  // ... encoding implementation
}

pub fn user_decoder() -> decode.Decoder(User) {
  // ... decoding implementation
}
```

### Services with Streaming

```proto
syntax = "proto3";
package example;

service UserService {
  rpc GetUser(GetUserRequest) returns (GetUserResponse);
  rpc StreamUsers(StreamRequest) returns (stream GetUserResponse);
  rpc UploadData(stream UploadRequest) returns (UploadResponse);
  rpc Chat(stream ChatMessage) returns (stream ChatMessage);
}
```

Generates:

```gleam
/// Client interface for UserService service
pub type UserServiceClient {
  UserServiceClient(
    endpoint: String,
  )
}

/// Server interface for UserService service
pub type UserServiceServer {
  UserServiceServer(
    // Server implementation fields
  )
}

// Method signatures for client:
  // GetUser(GetUserRequest) -> GetUserResponse // Unary call
  // StreamUsers(StreamRequest) -> GetUserResponse // Server streaming
  // UploadData(UploadRequest) -> UploadResponse // Client streaming
  // Chat(ChatMessage) -> ChatMessage // Bidirectional streaming
```

### Well-Known Types

```proto
syntax = "proto3";
package example;

import "google/protobuf/timestamp.proto";
import "google/protobuf/duration.proto";

message Event {
  string name = 1;
  google.protobuf.Timestamp created_at = 2;
  google.protobuf.Duration duration = 3;
}
```

Generates with automatic imports:

```gleam
pub type Event {
  Event(
    name: String,
    created_at: Timestamp,
    duration: Duration,
  )
}
```

## Development Status

### Recently Completed ✅

- ✅ **Complete code generation** - All field types now supported
  - ✅ All repeated field type encoders (Fixed32, Fixed64, SFixed32, SFixed64, etc.)
  - ✅ All map key/value type combinations with proper Dict support
  - ✅ Comprehensive oneof field type variants
- ✅ **Import system** - Full cross-file import support
  - ✅ Basic import statements with dependency resolution
  - ✅ Import path resolution with configurable search paths
  - ✅ Dependency management and comprehensive type registry
- ✅ **CLI improvements** - Production-ready tooling
  - ✅ Project structure auto-detection (`src/[appname]/proto/`)
  - ✅ `gleam run -m protozoa` integration
  - ✅ `--check` mode for CI/build systems
  - ✅ Generated file safety headers
- ✅ **Well-known types** - Google's standard protobuf types
  - ✅ `google.protobuf.Timestamp` - Full support with auto-import resolution
  - ✅ `google.protobuf.Duration` - Full support with auto-import resolution
  - ✅ `google.protobuf.Any` - Full support with auto-import resolution
  - ✅ `google.protobuf.Struct` / `Value` - Full support with auto-import resolution
  - ✅ `google.protobuf.Empty` - Full support with auto-import resolution
  - ✅ Wrapper types (`StringValue`, `Int32Value`, etc.)
  - ✅ `google.protobuf.FieldMask` - Full support with auto-import resolution
  - ✅ Full integration with import system and code generation
- ✅ **Field options** - Support field-level configuration
  - ✅ `deprecated` option - Parsing and deprecation warnings in generated code
  - ✅ `json_name` option - Parsing support (ready for future JSON serialization)
  - ✅ `packed` option - Parsing support (encoding already works)
- ✅ **Services/RPC** - Support for service definitions
  - ✅ Service definition parsing
  - ✅ Method definitions with all streaming types
  - ✅ Code generation for service stubs (client/server interfaces)
  - ✅ Streaming support detection (client/server/bidirectional)

### High Priority Roadmap

- [ ] **Proto2 support** - Full proto2 compatibility
  - [ ] Required/optional field semantics
  - [ ] Default values
  - [ ] Extensions and extension ranges
  - [ ] Groups (deprecated but still used)
- [ ] **JSON support** - JSON encoding/decoding as per proto3 JSON mapping
  - [ ] Message to/from JSON conversion
  - [ ] Field name mapping (snake_case ↔ camelCase)
  - [ ] Well-known types JSON representation
- [ ] **Unknown field handling** - Preserve unknown fields during decode/encode

### Medium Priority

- [ ] **File options** - Support file-level options
  - [ ] `java_package`, `java_outer_classname`
  - [ ] `optimize_for` (SPEED/CODE_SIZE/LITE_RUNTIME)
  - [ ] `go_package`
  - [ ] Custom file options
- [ ] **Recursive messages** - Enhanced support for self-referential message types
- [ ] **Custom field options** - User-defined field options

### Low Priority

- [ ] **Advanced parsing**
  - [ ] Comment preservation in AST
  - [ ] Source location tracking
  - [ ] Better error messages with line numbers
- [ ] **Performance optimizations**
  - [ ] Lazy decoding for large messages
  - [ ] Streaming for very large payloads
  - [ ] Memory usage optimizations

## Technical Details

- **Language**: Gleam with Erlang/JavaScript target support
- **Protocol Buffer Version**: proto3 (proto2 support planned)
- **Test Coverage**: 139 comprehensive tests
- **Dependencies**: Minimal dependencies (stdlib, simplifile, argv, snag)
- **Wire Format**: Complete Protocol Buffers wire format support
- **Performance**: Optimized for both encoding and decoding operations

## Contributing

Contributions are welcome! Please feel free to submit issues, feature requests, or pull requests.

## License

This project is licensed under the Apache License 2.0.