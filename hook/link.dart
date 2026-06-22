// The recordedUses FFI tree-shaking API is currently experimental.
// ignore_for_file: experimental_member_use

import 'package:brotli_codec/src/third_party/brotli_bindings.record_use_mapping.g.dart';
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';
import 'package:record_use/record_use.dart';

import 'c_library.dart';

void main(List<String> arguments) async {
  await link(arguments, (input, output) async {
    final symbolsToKeep = input.recordedUses?.calls.keys
        .cast<Method>()
        .map((e) => recordUseMapping[e.name])
        .whereType<String>();

    await cLibrary.link(
      input: input,
      output: output,
      linkerOptions: LinkerOptions.treeshake(symbolsToKeep: symbolsToKeep),
    );
  });
}

