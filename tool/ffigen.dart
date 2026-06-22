// Copyright (c) 2026, the Brotli Codec project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// MIT-style license that can be found in the LICENSE file.

// Print statements are used to show progression of the code generation.
// ignore_for_file: avoid_print

import 'dart:io';
import 'package:ffigen/ffigen.dart';
import 'package:logging/logging.dart';

void main() {
  final packageRoot = Platform.script.resolve('../');
  final bindingsOutput = packageRoot.resolve(
    'lib/src/third_party/brotli_bindings.g.dart',
  );

  final logger = Logger.detached('Brotli FFIgen')
    ..level = Level.INFO
    ..onRecord.listen((record) {
      if (record.level >= Level.SEVERE) {
        stderr.writeln('${record.level.name}: ${record.message}');
      } else if (record.level == Level.INFO) {
        print(record.message);
      }
    });

  FfiGenerator(
    headers: Headers(
      entryPoints: [
        packageRoot.resolve('src/brotli/c/include/brotli/decode.h'),
        packageRoot.resolve('src/brotli/c/include/brotli/encode.h'),
        packageRoot.resolve('src/brotli/c/include/brotli/types.h'),
      ],
      compilerOptions: [
        '-I${packageRoot.resolve('src/brotli/c/include').toFilePath()}',
        '-I/usr/lib/gcc/x86_64-linux-gnu/15/include',
        '-I/usr/local/include',
        '-I/usr/include/x86_64-linux-gnu',
        '-I/usr/include',
      ],
    ),
    functions: Functions(
      include: (decl) => decl.originalName.startsWith('Brotli'),
    ),
    structs: Structs(include: (decl) => decl.originalName.startsWith('Brotli')),
    enums: Enums(
      include: (decl) => decl.originalName.startsWith('Brotli'),
      silenceWarning: true,
    ),
    unnamedEnums: UnnamedEnums(
      include: (decl) => decl.originalName.startsWith('BROTLI_'),
    ),
    macros: Macros(include: (decl) => decl.originalName.startsWith('BROTLI_')),
    typedefs: Typedefs(
      include: (decl) =>
          decl.originalName.startsWith('Brotli') ||
          decl.originalName.startsWith('brotli_'),
    ),
    output: Output(
      dartFile: bindingsOutput,
      style: const NativeExternalBindings(
        assetId: 'package:brotli_codec/src/third_party/brotli_bindings.g.dart',
      ),
      preamble: '''
// SPDX-FileCopyrightText: 2026 the Brotli Codec project authors
// SPDX-FileCopyrightText: 2009-2016 Google Inc.
//
// SPDX-License-Identifier: MIT

// AUTO-GENERATED FILE - DO NOT MODIFY.
// Generated via ffigen from Google's Brotli C library headers.
// To regenerate: dart run tool/ffigen.dart

// ignore_for_file: always_specify_types
// ignore_for_file: camel_case_types
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: unused_element
// ignore_for_file: unused_field
// ignore_for_file: type=lint
// ignore_for_file: unused_import
''',
    ),
  ).generate(logger: logger);

  print('Generated Brotli FFI bindings.');
}

