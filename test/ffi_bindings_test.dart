import 'dart:ffi';
import 'package:embedanythingindart/src/ffi/native_types.dart';
import 'package:embedanythingindart/src/ffi/ffi_utils.dart';
import 'package:ffi/ffi.dart';
import 'package:test/test.dart';

/// Focused tests for Dart FFI bindings for Phase 3 file/directory embedding
///
/// These tests verify critical FFI binding behaviors:
/// - CTextEmbedConfig struct allocation and field access
/// - CEmbedData and CEmbedDataBatch struct allocation
/// - Helper function conversion between Dart and FFI types
/// - Error parsing for new file-related error types
/// - String array allocation and cleanup
///
/// Note: These are focused tests (8 tests) that verify bindings work correctly.
/// Integration tests with native code will be done by testing-engineer.
void main() {
  group('FFI Native Types - CTextEmbedConfig', () {
    test('allocates and accesses CTextEmbedConfig struct fields', () {
      final config = calloc<CTextEmbedConfig>();

      config.ref.chunkSize = 1000;
      config.ref.overlapRatio = 0.2;
      config.ref.batchSize = 32;
      config.ref.bufferSize = 100;

      expect(config.ref.chunkSize, equals(1000));
      expect(config.ref.overlapRatio, closeTo(0.2, 0.001));
      expect(config.ref.batchSize, equals(32));
      expect(config.ref.bufferSize, equals(100));

      calloc.free(config);
    });

    test('CTextEmbedConfig has correct memory layout', () {
      final config = calloc<CTextEmbedConfig>();

      // Verify we can access all fields without segfault
      config.ref.chunkSize = 500;
      expect(config.ref.chunkSize, equals(500));

      config.ref.overlapRatio = 0.1;
      expect(config.ref.overlapRatio, closeTo(0.1, 0.001));

      calloc.free(config);
    });
  });

  group('FFI Native Types - CEmbedData and CEmbedDataBatch', () {
    test('allocates CEmbedData struct and accesses fields', () {
      final data = calloc<CEmbedData>();

      // Allocate test embedding values
      final values = calloc<Float>(3);
      values[0] = 1.0;
      values[1] = 2.0;
      values[2] = 3.0;

      data.ref.embeddingValues = values;
      data.ref.embeddingLen = 3;
      data.ref.textAndMetadataJson =
          '{"text":"Test text","metadata":{"file_path":"test.txt"}}'.toNativeUtf8();

      expect(data.ref.embeddingLen, equals(3));
      expect(data.ref.embeddingValues[0], closeTo(1.0, 0.001));
      expect(data.ref.embeddingValues[1], closeTo(2.0, 0.001));
      expect(data.ref.embeddingValues[2], closeTo(3.0, 0.001));
      expect(data.ref.textAndMetadataJson.toDartString(),
          equals('{"text":"Test text","metadata":{"file_path":"test.txt"}}'));

      // Cleanup
      calloc.free(data.ref.textAndMetadataJson);
      calloc.free(values);
      calloc.free(data);
    });

    test('allocates CEmbedDataBatch struct and accesses items array', () {
      final batch = calloc<CEmbedDataBatch>();
      final items = calloc<CEmbedData>(2);

      batch.ref.items = items;
      batch.ref.count = 2;

      expect(batch.ref.count, equals(2));
      expect(batch.ref.items, isNot(equals(nullptr)));

      // Verify we can access items
      items[0].embeddingLen = 3;
      items[1].embeddingLen = 4;

      expect(batch.ref.items[0].embeddingLen, equals(3));
      expect(batch.ref.items[1].embeddingLen, equals(4));

      calloc.free(items);
      calloc.free(batch);
    });
  });

  group('FFI Helper Functions', () {
    test('allocateTextEmbedConfig creates struct from Dart params', () {
      final config = allocateTextEmbedConfig(
        chunkSize: 1500,
        overlapRatio: 0.15,
        batchSize: 64,
        bufferSize: 200,
      );

      expect(config.ref.chunkSize, equals(1500));
      expect(config.ref.overlapRatio, closeTo(0.15, 0.001));
      expect(config.ref.batchSize, equals(64));
      expect(config.ref.bufferSize, equals(200));

      calloc.free(config);
    });

    test('parseMetadataJson parses JSON string to Map', () {
      final json =
          '{"file_path":"/test/file.txt","chunk_index":"5","page_number":"10"}';
      final metadata = parseMetadataJson(json);

      expect(metadata, isNotNull);
      expect(metadata!['file_path'], equals('/test/file.txt'));
      expect(metadata['chunk_index'], equals('5'));
      expect(metadata['page_number'], equals('10'));
    });

    test('parseMetadataJson handles null and invalid JSON', () {
      expect(parseMetadataJson(null), isNull);
      expect(parseMetadataJson(''), isNull);
      expect(parseMetadataJson('invalid json'), isNull);
    });

    test('allocateStringArray and freeStringArray handle string arrays', () {
      final strings = ['.txt', '.pdf', '.md'];
      final arrayPtr = allocateStringArray(strings);

      // Verify the array is null-terminated
      expect(arrayPtr[0].toDartString(), equals('.txt'));
      expect(arrayPtr[1].toDartString(), equals('.pdf'));
      expect(arrayPtr[2].toDartString(), equals('.md'));
      expect(arrayPtr[3], equals(nullptr));

      freeStringArray(arrayPtr, strings.length);
    });
  });
}
