// The native_toolchain_c and hooks packages are dev_dependencies used by the build hook.
// ignore_for_file: depend_on_referenced_packages
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    final cBuilder = CBuilder.library(
      name: 'brotli',
      assetName: 'brotli_codec.dart',
      sources: [
        'src/brotli/c/common/constants.c',
        'src/brotli/c/common/context.c',
        'src/brotli/c/common/dictionary.c',
        'src/brotli/c/common/platform.c',
        'src/brotli/c/common/shared_dictionary.c',
        'src/brotli/c/common/transform.c',
        'src/brotli/c/dec/bit_reader.c',
        'src/brotli/c/dec/decode.c',
        'src/brotli/c/dec/huffman.c',
        'src/brotli/c/dec/prefix.c',
        'src/brotli/c/dec/state.c',
        'src/brotli/c/dec/static_init.c',
        'src/brotli/c/enc/backward_references.c',
        'src/brotli/c/enc/backward_references_hq.c',
        'src/brotli/c/enc/bit_cost.c',
        'src/brotli/c/enc/block_splitter.c',
        'src/brotli/c/enc/brotli_bit_stream.c',
        'src/brotli/c/enc/cluster.c',
        'src/brotli/c/enc/command.c',
        'src/brotli/c/enc/compound_dictionary.c',
        'src/brotli/c/enc/compress_fragment.c',
        'src/brotli/c/enc/compress_fragment_two_pass.c',
        'src/brotli/c/enc/dictionary_hash.c',
        'src/brotli/c/enc/encode.c',
        'src/brotli/c/enc/encoder_dict.c',
        'src/brotli/c/enc/entropy_encode.c',
        'src/brotli/c/enc/fast_log.c',
        'src/brotli/c/enc/histogram.c',
        'src/brotli/c/enc/literal_cost.c',
        'src/brotli/c/enc/memory.c',
        'src/brotli/c/enc/metablock.c',
        'src/brotli/c/enc/static_dict.c',
        'src/brotli/c/enc/static_dict_lut.c',
        'src/brotli/c/enc/static_init.c',
        'src/brotli/c/enc/utf8_util.c',
      ],
      includes: [
        'src/brotli/c/include',
        'src/brotli/c/common',
        'src/brotli/c/dec',
        'src/brotli/c/enc',
      ],
    );

    await cBuilder.run(input: input, output: output);
  });
}
