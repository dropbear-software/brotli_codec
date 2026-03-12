// Example uses print to display compression results.
// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:brotli_codec/brotli_codec.dart';

void main() {
  final text = 'Brotli compression is powerful! ' * 10;
  final input = utf8.encode(text);

  final compressed = brotli.encode(input);
  final decompressed = brotli.decode(compressed);

  print('Original size: ${input.length} bytes');
  print('Compressed size: ${compressed.length} bytes');
  print('Decompressed size: ${decompressed.length} bytes');

  final result = utf8.decode(decompressed);
  if (result == text) {
    print('Success: Round-trip matches original text!');
  } else {
    print('Error: Round-trip does not match!');
  }
}
