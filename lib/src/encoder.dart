import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'generated/brotli_bindings.dart' as bindings;
import 'quality.dart';

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

class _BrotliEncoderSink extends ByteConversionSinkBase implements Finalizable {
  final Sink<List<int>> _outSink;
  Pointer<bindings.BrotliEncoderStateStruct> _state;
  final Pointer<Size> _availableIn;
  final Pointer<Pointer<Uint8>> _nextIn;
  final Pointer<Size> _availableOut;
  final Pointer<Pointer<Uint8>> _nextOut;
  final Pointer<Uint8> _chunkPtr;
  static const int _chunkSize = 65536;

  static final _finalizer = NativeFinalizer(
    Native.addressOf<
          NativeFunction<Void Function(Pointer<bindings.BrotliEncoderState>)>
        >(bindings.BrotliEncoderDestroyInstance)
        .cast(),
  );

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
    _finalizer.attach(this, _state.cast(), detach: this);
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
    if (_state == nullptr) throw StateError('Sink is closed');
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
    if (_state == nullptr) return;
    _finalizer.detach(this);
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
      _state = nullptr;
      calloc.free(_availableIn);
      calloc.free(_nextIn);
      calloc.free(_availableOut);
      calloc.free(_nextOut);
      calloc.free(_chunkPtr);
      _outSink.close();
    }
  }
}
