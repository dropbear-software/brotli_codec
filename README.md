# Brotli Codec

High-performance Brotli compression and decompression for Dart.

This package provides a Dart wrapper around Google's official [Brotli C library](https://github.com/google/brotli), utilizing the modern Dart "hooks" feature for seamless native code integration.

## Features

- **Full Brotli Support**: Both compression and decompression.
- **`dart:convert` Integration**: Implements standard `Codec`, `Converter`, and `ChunkedConverter` patterns.
- **Streaming Support**: Efficiently process large data sets using streams and `transform()`.
- **High Performance**: Direct FFI bindings to the highly optimized C implementation.
- **Configurable**: Support for adjustable compression quality and window sizes.
- **Dart Build Hooks**: No manual compilation or complex setup required; the C library is automatically compiled and bundled.

## Getting started

Add `brotli_codec` to your `pubspec.yaml`:

```yaml
dependencies:
  brotli_codec: ^1.0.0
```

*Note: This package requires Dart 3.10 or later.*

## Usage

### Simple Encoding and Decoding

For most use cases, the top-level `brotli` codec is the easiest way to compress and decompress data.

```dart
import 'dart:convert';
import 'package:brotli_codec/brotli_codec.dart';

void main() {
  final text = 'Brotli compression is powerful!';
  final input = utf8.encode(text);

  // Compress
  final compressed = brotli.encode(input);

  // Decompress
  final decompressed = brotli.decode(compressed);

  print(utf8.decode(decompressed)); // 'Brotli compression is powerful!'
}
```

### Streaming and Chunked Conversion

You can use the encoder and decoder as stream transformers for large files or network data.

```dart
import 'dart:io';
import 'package:brotli_codec/brotli_codec.dart';

void main() async {
  final inputFile = File('large_file.txt');
  final outputFile = File('large_file.txt.br');

  await inputFile.openRead()
      .transform(brotli.encoder)
      .pipe(outputFile.openWrite());
}
```

### Fusing with Other Codecs

The Brotli codec can be fused with others, such as `utf8`, for convenient one-step conversion.

```dart
final fused = utf8.encoder.fuse(brotli.encoder);
final compressed = fused.convert('Some text to compress');
```

## Platform Support

This package uses Dart build hooks to bundle code assets and supports the following platforms:

- Linux (x64)
- macOS (x64, arm64)
- Windows (x64)
- Android
- iOS

## Additional information

- **Issues**: Please file upstream bug reports and feature requests on the [GitHub issue tracker](https://github.com/google/brotli/issues).
- **License**: This wrapper is distributed under the MIT License. The underlying Brotli C library is also licensed under the MIT License.
