import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'generated/brotli_bindings.dart' as bindings;

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

    final builder = BytesBuilder();
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
          builder.add(chunkPtr.asTypedList(produced));
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

      return builder.takeBytes();
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

class _BrotliDecoderSink extends ByteConversionSinkBase implements Finalizable {
  final Sink<List<int>> _outSink;
  Pointer<bindings.BrotliDecoderStateStruct> _state;
  final Pointer<Size> _availableIn;
  final Pointer<Pointer<Uint8>> _nextIn;
  final Pointer<Size> _availableOut;
  final Pointer<Pointer<Uint8>> _nextOut;
  final Pointer<Uint8> _chunkPtr;
  static const int _chunkSize = 65536;

  static final _finalizer = NativeFinalizer(
    Native.addressOf<
          NativeFunction<Void Function(Pointer<bindings.BrotliDecoderState>)>
        >(bindings.BrotliDecoderDestroyInstance)
        .cast(),
  );

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
    _finalizer.attach(this, _state.cast(), detach: this);
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
    if (_state == nullptr) return;
    _finalizer.detach(this);
    bindings.BrotliDecoderDestroyInstance(_state);
    _state = nullptr;
    calloc.free(_availableIn);
    calloc.free(_nextIn);
    calloc.free(_availableOut);
    calloc.free(_nextOut);
    calloc.free(_chunkPtr);
    _outSink.close();
  }
}
