// The @RecordUse FFI tree-shaking API is currently experimental.
// ignore_for_file: experimental_member_use

import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:meta/meta.dart';

import 'third_party/brotli_bindings.g.dart' as bindings;

/// A [Converter] that decompresses a Brotli-compressed sequence of bytes.
@RecordUse()
final class BrotliDecoder extends Converter<List<int>, List<int>> {
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
  static const int _chunkSize = 65536;

  static final _finalizer = NativeFinalizer(
    Native.addressOf<
          NativeFunction<Void Function(Pointer<bindings.BrotliDecoderState>)>
        >(bindings.BrotliDecoderDestroyInstance)
        .cast(),
  );

  _BrotliDecoderSink(this._outSink)
    : _state = bindings.BrotliDecoderCreateInstance(nullptr, nullptr, nullptr) {
    if (_state == nullptr) {
      throw Exception('Failed to create Brotli decoder instance');
    }
    _finalizer.attach(this, _state.cast(), detach: this);
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
          bindings.BrotliDecoderHasMoreOutput(_state) != 0) {
        availableOut.value = _chunkSize;
        nextOut.value = chunkPtr;

        final result = bindings.BrotliDecoderDecompressStream(
          _state,
          availableIn,
          nextIn,
          availableOut,
          nextOut,
          nullptr,
        );

        final produced = _chunkSize - availableOut.value;
        if (produced > 0) {
          _outSink.add(Uint8List.fromList(chunkPtr.asTypedList(produced)));
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
    bindings.BrotliDecoderDestroyInstance(_state);
    _state = nullptr;
    _outSink.close();
  }
}
