@TestOn('vm')
library;

import 'dart:convert';
import 'dart:typed_data';
import 'package:brotli_codec/brotli_codec.dart';
import 'package:test/test.dart';

void main() {
  group('BrotliCodec', () {
    final inputs = {
      'empty': <int>[],
      'short string': utf8.encode('Hello Brotli!'),
      'repetitive string': utf8.encode('Brotli' * 1000),
      'binary data': Uint8List.fromList(List.generate(1000, (i) => i % 256)),
    };

    group('One-shot API', () {
      for (final entry in inputs.entries) {
        test('round-trip for ${entry.key}', () {
          final compressed = brotli.encode(entry.value);
          final decompressed = brotli.decode(compressed);
          expect(decompressed, equals(entry.value));
        });
      }

      test('custom quality levels', () {
        final input = utf8.encode('Quality level test' * 100);

        final compressedMin = BrotliCodec(
          quality: BrotliQuality.min,
        ).encode(input);
        final compressedMax = BrotliCodec().encode(input);

        expect(brotli.decode(compressedMin), equals(input));
        expect(brotli.decode(compressedMax), equals(input));
        // Max quality should generally be smaller for this input
        expect(compressedMax.length, lessThanOrEqualTo(compressedMin.length));
      });
    });

    group('Streaming API', () {
      test('encoder handles multiple chunks', () async {
        final inputData = utf8.encode('Streaming chunks test' * 100);
        final stream = Stream<List<int>>.fromIterable([
          inputData.sublist(0, 10),
          inputData.sublist(10, 100),
          inputData.sublist(100),
        ]);

        final compressed = await stream
            .transform<List<int>>(brotli.encoder)
            .fold<List<int>>([], (p, e) => p..addAll(e));

        expect(brotli.decode(compressed), equals(inputData));
      });

      test('decoder handles multiple chunks', () async {
        final inputData = utf8.encode('Streaming decoder test' * 100);
        final compressed = brotli.encode(inputData);

        final stream = Stream<List<int>>.fromIterable([
          compressed.sublist(0, 5),
          compressed.sublist(5, 20),
          compressed.sublist(20),
        ]);

        final decompressed = await stream
            .transform<List<int>>(brotli.decoder)
            .fold<List<int>>([], (p, e) => p..addAll(e));

        expect(decompressed, equals(inputData));
      });
    });

    group('Fusing', () {
      test('utf8.encoder.fuse(brotli.encoder)', () {
        const input = 'Fused compression test';
        final fused = utf8.encoder.fuse(brotli.encoder);
        final compressed = fused.convert(input);
        expect(brotli.decode(compressed), equals(utf8.encode(input)));
      });

      test('brotli.decoder.fuse(utf8.decoder)', () {
        const input = 'Fused decompression test';
        final compressed = brotli.encode(utf8.encode(input));
        final fused = brotli.decoder.fuse(utf8.decoder);
        expect(fused.convert(compressed), equals(input));
      });
    });

    group('Edge Cases', () {
      test('extremely high compression ratio', () {
        final input = Uint8List(1000000); // 1MB of zeros
        final compressed = brotli.encode(input);
        expect(compressed.length, lessThan(1000)); // Should be very small
        expect(brotli.decode(compressed), equals(input));
      });

      test('invalid data throws exception', () {
        final invalidData = Uint8List.fromList([0, 1, 2, 3, 4, 5]);
        expect(() => brotli.decode(invalidData), throwsException);
      });
    });
  });
}
