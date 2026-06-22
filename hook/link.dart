// The recordedUses FFI tree-shaking API is currently experimental.
// ignore_for_file: experimental_member_use

import 'package:hooks/hooks.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

import 'c_library.dart';

void main(List<String> arguments) async {
  await link(arguments, (input, output) async {
    final bool keepDecoder;
    final bool keepEncoder;

    final recordedUses = input.recordedUses;
    if (recordedUses == null) {
      // If usages weren't recorded, keep all symbols (default/fallback behavior).
      keepDecoder = true;
      keepEncoder = true;
    } else {
      // Check which class constructors or instances were recorded.
      final classNames = recordedUses.instances.keys.map((e) => e.name).toSet();
      keepDecoder = classNames.contains('BrotliDecoder');
      keepEncoder = classNames.contains('BrotliEncoder');
    }

    final symbolsToKeep = <String>[];
    if (keepDecoder) {
      symbolsToKeep.addAll([
        'BrotliDecoderCreateInstance',
        'BrotliDecoderDecompressStream',
        'BrotliDecoderDestroyInstance',
        'BrotliDecoderHasMoreOutput',
      ]);
    }
    if (keepEncoder) {
      symbolsToKeep.addAll([
        'BrotliEncoderCompress',
        'BrotliEncoderCompressStream',
        'BrotliEncoderCreateInstance',
        'BrotliEncoderDestroyInstance',
        'BrotliEncoderHasMoreOutput',
        'BrotliEncoderIsFinished',
        'BrotliEncoderSetParameter',
        'BrotliEncoderMaxCompressedSize',
      ]);
    }

    // Always keep platform platform-independent common symbols to avoid link errors
    // if at least one of encoder or decoder is kept.
    if (symbolsToKeep.isNotEmpty) {
      symbolsToKeep.addAll([
        'BrotliSharedDictionaryCreateInstance',
        'BrotliSharedDictionaryDestroyInstance',
        'BrotliSharedDictionaryAttach',
      ]);
    }

    await cLibrary.link(
      input: input,
      output: output,
      linkerOptions: LinkerOptions.treeshake(symbolsToKeep: symbolsToKeep),
    );
  });
}
