import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'brotli_bindings_generated.dart' as bindings;

/// A compression level for Brotli.
///
/// Levels range from [min] (0) to [max] (11).
class BrotliQuality {
  /// The minimum compression level.
  static const int min = 0;

  /// The maximum compression level.
  static const int max = 11;

  /// The default compression level.
  static const int defaultQuality = 11;
}

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

/// A [Converter] that compresses a sequence of bytes using Brotli.
class BrotliEncoder extends Converter<List<int>, List<int>> {
  /// The compression quality level.
  final int quality;

  /// The window size in bits.
  final int window;

  /// Creates a [BrotliEncoder] with the given [quality] and [window] size.
  BrotliEncoder({
    this.quality = BrotliQuality.defaultQuality,
    this.window = bindings.BROTLI_DEFAULT_WINDOW,
  });

  @override
  Uint8List convert(List<int> input) {
    if (input.isEmpty) {
      // Brotli still produces a header for empty input.
      final outputPtr = calloc<Uint8>();
      final encodedSizePtr = calloc<Size>();
      encodedSizePtr.value = 1;
      try {
        final result = bindings.BrotliEncoderCompress(
          quality,
          window,
          bindings.BrotliEncoderMode.BROTLI_MODE_GENERIC,
          0,
          nullptr,
          encodedSizePtr,
          outputPtr,
        );
        if (result == 0) throw Exception('Brotli compression failed');
        return Uint8List.fromList(outputPtr.asTypedList(encodedSizePtr.value));
      } finally {
        calloc.free(outputPtr);
        calloc.free(encodedSizePtr);
      }
    }

    final inputBytes = input is Uint8List ? input : Uint8List.fromList(input);
    final inputPtr = calloc<Uint8>(inputBytes.length);
    inputPtr.asTypedList(inputBytes.length).setAll(0, inputBytes);

    final maxOutputSize = bindings.BrotliEncoderMaxCompressedSize(
      inputBytes.length,
    );
    final outputPtr = calloc<Uint8>(maxOutputSize);
    final encodedSizePtr = calloc<Size>();
    encodedSizePtr.value = maxOutputSize;

    try {
      final result = bindings.BrotliEncoderCompress(
        quality,
        window,
        bindings.BrotliEncoderMode.BROTLI_MODE_GENERIC,
        inputBytes.length,
        inputPtr,
        encodedSizePtr,
        outputPtr,
      );

      if (result == 0) {
        throw Exception('Brotli compression failed');
      }

      return Uint8List.fromList(outputPtr.asTypedList(encodedSizePtr.value));
    } finally {
      calloc.free(inputPtr);
      calloc.free(outputPtr);
      calloc.free(encodedSizePtr);
    }
  }

  @override
  ByteConversionSink startChunkedConversion(Sink<List<int>> sink) {
    return _BrotliEncoderSink(sink, quality, window);
  }
}

/// A [Converter] that decompresses a Brotli-compressed sequence of bytes.
class BrotliDecoder extends Converter<List<int>, List<int>> {
  /// Creates a [BrotliDecoder].
  const BrotliDecoder();

  @override
  Uint8List convert(List<int> input) {
    final state = bindings.BrotliDecoderCreateInstance(
      nullptr,
      nullptr,
      nullptr,
    );
    if (state == nullptr) {
      throw Exception('Failed to create Brotli decoder instance');
    }

    final inputBytes = input is Uint8List ? input : Uint8List.fromList(input);
    final inputPtr = calloc<Uint8>(inputBytes.length);
    inputPtr.asTypedList(inputBytes.length).setAll(0, inputBytes);

    final availableInPtr = calloc<Size>();
    availableInPtr.value = inputBytes.length;
    final nextInPtr = calloc<Pointer<Uint8>>();
    nextInPtr.value = inputPtr;

    final availableOutPtr = calloc<Size>();
    final nextOutPtr = calloc<Pointer<Uint8>>();

    final outputChunks = <Uint8List>[];
    const chunkSize = 65536;
    final chunkPtr = calloc<Uint8>(chunkSize);

    try {
      while (true) {
        availableOutPtr.value = chunkSize;
        nextOutPtr.value = chunkPtr;

        final result = bindings.BrotliDecoderDecompressStream(
          state,
          availableInPtr,
          nextInPtr,
          availableOutPtr,
          nextOutPtr,
          nullptr,
        );

        final produced = chunkSize - availableOutPtr.value;
        if (produced > 0) {
          outputChunks.add(Uint8List.fromList(chunkPtr.asTypedList(produced)));
        }

        if (result ==
            bindings.BrotliDecoderResult.BROTLI_DECODER_RESULT_SUCCESS) {
          break;
        }

        if (result ==
            bindings
                .BrotliDecoderResult
                .BROTLI_DECODER_RESULT_NEEDS_MORE_OUTPUT) {
          continue;
        }

        throw Exception('Brotli decompression failed with result: $result');
      }

      final totalSize = outputChunks.fold(
        0,
        (sum, chunk) => sum + chunk.length,
      );
      final result = Uint8List(totalSize);
      var offset = 0;
      for (final chunk in outputChunks) {
        result.setAll(offset, chunk);
        offset += chunk.length;
      }
      return result;
    } finally {
      bindings.BrotliDecoderDestroyInstance(state);
      calloc.free(inputPtr);
      calloc.free(availableInPtr);
      calloc.free(nextInPtr);
      calloc.free(availableOutPtr);
      calloc.free(nextOutPtr);
      calloc.free(chunkPtr);
    }
  }

  @override
  ByteConversionSink startChunkedConversion(Sink<List<int>> sink) {
    return _BrotliDecoderSink(sink);
  }
}

class _BrotliEncoderSink extends ByteConversionSinkBase {
  final Sink<List<int>> _outSink;
  final Pointer<bindings.BrotliEncoderStateStruct> _state;
  final Pointer<Size> _availableIn;
  final Pointer<Pointer<Uint8>> _nextIn;
  final Pointer<Size> _availableOut;
  final Pointer<Pointer<Uint8>> _nextOut;
  final Pointer<Uint8> _chunkPtr;
  static const int _chunkSize = 65536;

  _BrotliEncoderSink(this._outSink, int quality, int window)
    : _state = bindings.BrotliEncoderCreateInstance(nullptr, nullptr, nullptr),
      _availableIn = calloc<Size>(),
      _nextIn = calloc<Pointer<Uint8>>(),
      _availableOut = calloc<Size>(),
      _nextOut = calloc<Pointer<Uint8>>(),
      _chunkPtr = calloc<Uint8>(_chunkSize) {
    if (_state == nullptr) {
      throw Exception('Failed to create Brotli encoder instance');
    }
    bindings.BrotliEncoderSetParameter(
      _state,
      bindings.BrotliEncoderParameter.BROTLI_PARAM_QUALITY,
      quality,
    );
    bindings.BrotliEncoderSetParameter(
      _state,
      bindings.BrotliEncoderParameter.BROTLI_PARAM_LGWIN,
      window,
    );
  }

  @override
  void add(List<int> chunk) {
    final bytes = chunk is Uint8List ? chunk : Uint8List.fromList(chunk);
    final inputPtr = calloc<Uint8>(bytes.length);
    inputPtr.asTypedList(bytes.length).setAll(0, bytes);

    _availableIn.value = bytes.length;
    _nextIn.value = inputPtr;

    try {
      while (_availableIn.value > 0 ||
          bindings.BrotliEncoderHasMoreOutput(_state) != 0) {
        _availableOut.value = _chunkSize;
        _nextOut.value = _chunkPtr;

        final result = bindings.BrotliEncoderCompressStream(
          _state,
          bindings.BrotliEncoderOperation.BROTLI_OPERATION_PROCESS,
          _availableIn,
          _nextIn,
          _availableOut,
          _nextOut,
          nullptr,
        );

        if (result == 0) throw Exception('Brotli compression failed');

        final produced = _chunkSize - _availableOut.value;
        if (produced > 0) {
          _outSink.add(Uint8List.fromList(_chunkPtr.asTypedList(produced)));
        }

        if (_availableIn.value == 0 &&
            bindings.BrotliEncoderHasMoreOutput(_state) == 0) {
          break;
        }
      }
    } finally {
      calloc.free(inputPtr);
    }
  }

  @override
  void close() {
    try {
      while (bindings.BrotliEncoderIsFinished(_state) == 0) {
        _availableIn.value = 0;
        _nextIn.value = nullptr;
        _availableOut.value = _chunkSize;
        _nextOut.value = _chunkPtr;

        final result = bindings.BrotliEncoderCompressStream(
          _state,
          bindings.BrotliEncoderOperation.BROTLI_OPERATION_FINISH,
          _availableIn,
          _nextIn,
          _availableOut,
          _nextOut,
          nullptr,
        );

        if (result == 0) throw Exception('Brotli compression failed on finish');

        final produced = _chunkSize - _availableOut.value;
        if (produced > 0) {
          _outSink.add(Uint8List.fromList(_chunkPtr.asTypedList(produced)));
        }
      }
    } finally {
      bindings.BrotliEncoderDestroyInstance(_state);
      calloc.free(_availableIn);
      calloc.free(_nextIn);
      calloc.free(_availableOut);
      calloc.free(_nextOut);
      calloc.free(_chunkPtr);
      _outSink.close();
    }
  }
}

class _BrotliDecoderSink extends ByteConversionSinkBase {
  final Sink<List<int>> _outSink;
  final Pointer<bindings.BrotliDecoderStateStruct> _state;
  final Pointer<Size> _availableIn;
  final Pointer<Pointer<Uint8>> _nextIn;
  final Pointer<Size> _availableOut;
  final Pointer<Pointer<Uint8>> _nextOut;
  final Pointer<Uint8> _chunkPtr;
  static const int _chunkSize = 65536;

  _BrotliDecoderSink(this._outSink)
    : _state = bindings.BrotliDecoderCreateInstance(nullptr, nullptr, nullptr),
      _availableIn = calloc<Size>(),
      _nextIn = calloc<Pointer<Uint8>>(),
      _availableOut = calloc<Size>(),
      _nextOut = calloc<Pointer<Uint8>>(),
      _chunkPtr = calloc<Uint8>(_chunkSize) {
    if (_state == nullptr) {
      throw Exception('Failed to create Brotli decoder instance');
    }
  }

  @override
  void add(List<int> chunk) {
    final bytes = chunk is Uint8List ? chunk : Uint8List.fromList(chunk);
    final inputPtr = calloc<Uint8>(bytes.length);
    inputPtr.asTypedList(bytes.length).setAll(0, bytes);

    _availableIn.value = bytes.length;
    _nextIn.value = inputPtr;

    try {
      while (_availableIn.value > 0 ||
          bindings.BrotliDecoderHasMoreOutput(_state) != 0) {
        _availableOut.value = _chunkSize;
        _nextOut.value = _chunkPtr;

        final result = bindings.BrotliDecoderDecompressStream(
          _state,
          _availableIn,
          _nextIn,
          _availableOut,
          _nextOut,
          nullptr,
        );

        final produced = _chunkSize - _availableOut.value;
        if (produced > 0) {
          _outSink.add(Uint8List.fromList(_chunkPtr.asTypedList(produced)));
        }

        if (result ==
            bindings.BrotliDecoderResult.BROTLI_DECODER_RESULT_SUCCESS) {
          break;
        }

        if (result ==
            bindings
                .BrotliDecoderResult
                .BROTLI_DECODER_RESULT_NEEDS_MORE_OUTPUT) {
          continue;
        }

        if (result ==
            bindings
                .BrotliDecoderResult
                .BROTLI_DECODER_RESULT_NEEDS_MORE_INPUT) {
          break;
        }

        throw Exception('Brotli decompression failed with result: $result');
      }
    } finally {
      calloc.free(inputPtr);
    }
  }

  @override
  void close() {
    bindings.BrotliDecoderDestroyInstance(_state);
    calloc.free(_availableIn);
    calloc.free(_nextIn);
    calloc.free(_availableOut);
    calloc.free(_nextOut);
    calloc.free(_chunkPtr);
    _outSink.close();
  }
}

/// The default [BrotliCodec].
const BrotliCodec brotli = BrotliCodec();
