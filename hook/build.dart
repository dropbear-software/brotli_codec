import 'package:hooks/hooks.dart';

import 'c_library.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    await cLibrary.build(input: input, output: output);
  });
}
