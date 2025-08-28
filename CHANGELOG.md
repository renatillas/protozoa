# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **Core Protocol Buffer Support**
  - Complete proto3 syntax parsing
  - Message and enum definitions
  - All scalar field types (string, int32, int64, bool, bytes, etc.)
  - Repeated and optional fields
  - Nested messages and enums
  - Oneof groups for union types
  - Map fields with proper Dict support

- **Code Generation**
  - Full Gleam code generation from proto files
  - Type-safe message types with proper field accessors
  - Encoding functions for all supported types
  - Decoding functions with comprehensive error handling
  - Support for all protobuf wire format types

- **Import System**
  - Cross-file import support with dependency resolution
  - Configurable search paths for proto file resolution
  - Public and weak import handling
  - Comprehensive type registry for cross-file type resolution
  - Circular dependency detection

- **CLI Integration**
  - Project structure auto-detection (`src/[appname]/proto/`)
  - Automatic proto file discovery and generation
  - `gleam run -m protozoa` integration
  - `--check` mode for CI/build systems
  - Generated file safety headers to prevent manual editing

- **Wire Format Support**
  - Complete Protocol Buffer wire format encoding/decoding
  - Support for all wire types (varint, fixed32, fixed64, length-delimited)
  - Proper handling of field numbers and types
  - Efficient bit array operations

- **Service/RPC Support** - Complete implementation of Protocol Buffer services
  - Added `Service` and `Method` types to parser
  - Full parsing support for service definitions with RPC methods
  - Streaming RPC support detection (client, server, bidirectional)
  - Service code generation with client and server interface stubs
  - Method signature comments with streaming information
  - Comprehensive test coverage for service parsing and code generation
- **Field Options Support** - Enhanced field-level configuration
  - Added `FieldOption` type with `Deprecated`, `JsonName`, and `Packed` variants
  - Extended `Field` type to include `options: List(FieldOption)`
  - Field options parsing with `[option=value]` syntax support
  - Deprecation warnings in generated code for deprecated fields
  - Support for `json_name` and `packed` options (ready for future features)
- **Well-Known Types Integration** - Google's standard protobuf types
  - Auto-loading of well-known types in type registry
  - Full support for `google.protobuf.Timestamp`, `Duration`, `Any`, `Empty`
  - Complete `google.protobuf.Struct`, `Value`, `ListValue` with proper oneof handling
  - Support for wrapper types (`StringValue`, `Int32Value`, etc.)
  - `google.protobuf.FieldMask` support
  - Seamless integration with import system and code generation

### Changed

- **Parser Documentation** - Updated to reflect new capabilities
  - Added service definitions to supported proto3 features
  - Updated capability descriptions to include field options and streaming
  - Removed service limitations from parser documentation
- **ProtoFile Type** - Extended to support services
  - Added `services: List(Service)` field to `ProtoFile` type
  - Updated all ProtoFile constructors across codebase
- **Code Generation Pipeline** - Enhanced with service stub generation
  - Integrated service stub generation into main codegen flow
  - Added service-specific imports and type definitions
  - Service stubs include TODO placeholders for implementation

### Fixed

- **Service Block Parsing** - Proper handling of service definitions
  - Service blocks are now correctly skipped in message/enum parsing
  - Fixed method signature parsing to handle multiple space-separated parts
  - Improved error handling for malformed service definitions

### Technical Details

- **Test Coverage**: 139 tests (increased from 137) with comprehensive service testing
- **Streaming Support**: All 4 streaming modes fully supported
  - Unary: `rpc Method(Request) returns (Response)`
  - Server streaming: `rpc Method(Request) returns (stream Response)`
  - Client streaming: `rpc Method(stream Request) returns (Response)`
  - Bidirectional: `rpc Method(stream Request) returns (stream Response)`
- **Code Generation**: Service stubs generate client/server interfaces with method signatures
- **Language**: Gleam with Erlang runtime
- **Proto Version**: proto3 only
- **Dependencies**: Minimal with stdlib, simplifile, argv, snag
- **Platform**: Cross-platform (Erlang/JavaScript targets)

---

## Future Roadmap

### High Priority

- **Proto2 Support** - Required/optional semantics, default values, extensions
- **JSON Support** - JSON encoding/decoding per proto3 JSON mapping
- **Unknown Field Handling** - Preserve unknown fields during decode/encode

### Medium Priority  

- **File Options** - Support for `java_package`, `optimize_for`, `go_package`
- **Recursive Messages** - Enhanced self-referential message support
- **Advanced Parsing** - Comment preservation, source locations, better errors

### Low Priority

- **Performance Optimizations** - Lazy decoding, streaming for large messages
- **Extended Validation** - Enhanced semantic validation and error reporting
