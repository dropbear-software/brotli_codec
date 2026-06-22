// The @RecordUse FFI tree-shaking API is currently experimental.
// ignore_for_file: experimental_member_use

import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:meta/meta.dart';

import 'quality.dart';
import 'third_party/brotli_bindings.g.dart' as bindings;

/// A [Converter] that compresses a sequence of bytes using Brotli.
@RecordUse()
final class BrotliEncoder extends Converter<List<int>, List<int>> {
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
  static const int _chunkSize = 65536;

  static final _finalizer = NativeFinalizer(
    Native.addressOf<
          NativeFunction<Void Function(Pointer<bindings.BrotliEncoderState>)>
        >(bindings.BrotliEncoderDestroyInstance)
        .cast(),
  );

  _BrotliEncoderSink(this._outSink, int quality, int window)
    : _state = bindings.BrotliEncoderCreateInstance(nullptr, nullptr, nullptr) {
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
    final inputPtr = malloc<Uint8>(bytes.length);
    inputPtr.asTypedList(bytes.length).setAll(0, bytes);

    final availableIn = malloc<Size>()..value = bytes.length;
    final nextIn = malloc<Pointer<Uint8>>()..value = inputPtr;
    final availableOut = malloc<Size>();
    final nextOut = malloc<Pointer<Uint8>>();
    final chunkPtr = malloc<Uint8>(_chunkSize);

    try {
      while (availableIn.value > 0 ||
          bindings.BrotliEncoderHasMoreOutput(_state) != 0) {
        availableOut.value = _chunkSize;
        nextOut.value = chunkPtr;

        final result = bindings.BrotliEncoderCompressStream(
          _state,
          bindings.BrotliEncoderOperation.BROTLI_OPERATION_PROCESS,
          availableIn,
          nextIn,
          availableOut,
          nextOut,
          nullptr,
        );

        if (result == 0) throw Exception('Brotli compression failed');

        final produced = _chunkSize - availableOut.value;
        if (produced > 0) {
          _outSink.add(Uint8List.fromList(chunkPtr.asTypedList(produced)));
        }

        if (availableIn.value == 0 &&
            bindings.BrotliEncoderHasMoreOutput(_state) == 0) {
          break;
        }
      }
    } finally {
      malloc.free(inputPtr);
      malloc.free(availableIn);
      malloc.free(nextIn);
      malloc.free(availableOut);
      malloc.free(nextOut);
      malloc.free(chunkPtr);
    }
  }

  @override
  void close() {
    if (_state == nullptr) return;
    _finalizer.detach(this);

    final availableIn = malloc<Size>();
    final nextIn = malloc<Pointer<Uint8>>();
    final availableOut = malloc<Size>();
    final nextOut = malloc<Pointer<Uint8>>();
    final chunkPtr = malloc<Uint8>(_chunkSize);

    try {
      while (bindings.BrotliEncoderIsFinished(_state) == 0) {
        availableIn.value = 0;
        nextIn.value = nullptr;
        availableOut.value = _chunkSize;
        nextOut.value = chunkPtr;

        final result = bindings.BrotliEncoderCompressStream(
          _state,
          bindings.BrotliEncoderOperation.BROTLI_OPERATION_FINISH,
          availableIn,
          nextIn,
          availableOut,
          nextOut,
          nullptr,
        );

        if (result == 0) throw Exception('Brotli compression failed on finish');

        final produced = _chunkSize - availableOut.value;
        if (produced > 0) {
          _outSink.add(Uint8List.fromList(chunkPtr.asTypedList(produced)));
        }
      }
    } finally {
      bindings.BrotliEncoderDestroyInstance(_state);
      _state = nullptr;
      malloc.free(availableIn);
      malloc.free(nextIn);
      malloc.free(availableOut);
      malloc.free(nextOut);
      malloc.free(chunkPtr);
      _outSink.close();
    }
  }
}
