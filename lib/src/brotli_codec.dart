import 'dart:convert';

import 'decoder.dart';
import 'encoder.dart';
import 'generated/brotli_bindings.dart' as bindings;
import 'quality.dart';

/// A [Codec] that compresses and decompresses data using Brotli.
class BrotliCodec extends Codec<List<int>, List<int>> {
  /// The compression quality level.
  final int quality;

  /// The window size in bits.
  final int window;

  /// Creates a [BrotliCodec] with the given [quality] and [window] size.
  const BrotliCodec({
    this.quality = BrotliQuality.defaultQuality,
    this.window = bindings.BROTLI_DEFAULT_WINDOW,
  });

  @override
  BrotliEncoder get encoder => BrotliEncoder(quality: quality, window: window);

  @override
  BrotliDecoder get decoder => const BrotliDecoder();
}

/// The default [BrotliCodec].
const BrotliCodec brotli = BrotliCodec();
