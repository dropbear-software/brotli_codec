// The benchmark script uses print for CLI output.
// ignore_for_file: avoid_print

import 'dart:math';
import 'dart:typed_data';

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:brotli_codec/brotli_codec.dart';

class BrotliEncoderBenchmark extends BenchmarkBase {
  final List<int> data;
  final int quality;

  BrotliEncoderBenchmark(
    this.data, {
    this.quality = BrotliQuality.defaultQuality,
  }) : super('BrotliEncoder(q=$quality)');

  @override
  void run() {
    BrotliEncoder(quality: quality).convert(data);
  }
}

class BrotliDecoderBenchmark extends BenchmarkBase {
  final List<int> compressed;

  BrotliDecoderBenchmark(this.compressed) : super('BrotliDecoder');

  @override
  void run() {
    const BrotliDecoder().convert(compressed);
  }
}

void main() {
  final random = Random(42);
  // 1MB of mixed data: 50% repetitive, 50% random-ish
  final input = Uint8List(1024 * 1024);
  for (var i = 0; i < input.length; i++) {
    if (i < input.length / 2) {
      input[i] = i % 256; // Repetitive
    } else {
      input[i] = random.nextInt(256); // Random
    }
  }

  print('Benchmark data size: ${input.length} bytes');

  // Benchmark encoding at different quality levels
  BrotliEncoderBenchmark(input, quality: BrotliQuality.min).report();
  BrotliEncoderBenchmark(input, quality: 6).report();
  BrotliEncoderBenchmark(input).report();

  // Benchmark decoding
  final compressed = brotli.encode(input);
  print('Compressed size: ${compressed.length} bytes');
  BrotliDecoderBenchmark(compressed).report();
}
