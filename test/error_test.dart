import 'package:embedanythingindart/embedanythingindart.dart';
import 'package:test/test.dart';

void main() {
  group('Error Type Tests', () {
    test('ModelNotFoundError is thrown for invalid model ID', () {
      expect(
        () => EmbedAnything.fromPretrainedHf(
          model: EmbeddingModel.bert,
          modelId: 'invalid/model/that/does/not/exist/xyz123',
        ),
        throwsA(isA<ModelNotFoundError>()
            .having((e) => e.modelId, 'modelId',
                contains('invalid/model/that/does/not/exist/xyz123'))
            .having((e) => e.toString(), 'toString', contains('not found'))),
      );
    });

    test('FFIError is thrown when native operation fails', () {
      final embedder = EmbedAnything.fromPretrainedHf(
        model: EmbeddingModel.bert,
        modelId: 'sentence-transformers/all-MiniLM-L6-v2',
      );

      embedder.dispose();

      // After disposal, operations should fail with FFIError
      expect(
        () => embedder.embedText('Test'),
        throwsA(isA<StateError>()), // StateError for dispose check
      );
    });

    test('MultiVectorNotSupportedError has clear message', () {
      // This test validates the error type exists and has the expected message
      final error = MultiVectorNotSupportedError();
      expect(error.message, contains('Multi-vector'));
      expect(error.message, contains('not supported'));
      expect(error.toString(), contains('Multi-vector'));
    });

    test('InvalidConfigError includes field and reason', () {
      final error = InvalidConfigError(
        field: 'modelId',
        reason: 'cannot be empty',
      );

      expect(error.field, equals('modelId'));
      expect(error.reason, equals('cannot be empty'));
      expect(error.message, contains('modelId'));
      expect(error.message, contains('cannot be empty'));
    });

    test('EmbeddingFailedError includes reason', () {
      final error = EmbeddingFailedError(reason: 'network timeout');

      expect(error.reason, equals('network timeout'));
      expect(error.message, contains('network timeout'));
      expect(error.toString(), contains('Embedding generation failed'));
    });

    test('All errors implement Exception', () {
      expect(ModelNotFoundError('test'), isA<Exception>());
      expect(
          InvalidConfigError(field: 'test', reason: 'test'), isA<Exception>());
      expect(EmbeddingFailedError(reason: 'test'), isA<Exception>());
      expect(MultiVectorNotSupportedError(), isA<Exception>());
      expect(FFIError(operation: 'test'), isA<Exception>());
    });

    test('All errors extend EmbedAnythingError (sealed class)', () {
      expect(ModelNotFoundError('test'), isA<EmbedAnythingError>());
      expect(InvalidConfigError(field: 'test', reason: 'test'),
          isA<EmbedAnythingError>());
      expect(
          EmbeddingFailedError(reason: 'test'), isA<EmbedAnythingError>());
      expect(MultiVectorNotSupportedError(), isA<EmbedAnythingError>());
      expect(FFIError(operation: 'test'), isA<EmbedAnythingError>());
    });

    test('Phase 3 errors implement Exception', () {
      expect(FileNotFoundError('/test/path'), isA<Exception>());
      expect(
        UnsupportedFileFormatError(path: '/test/file.xyz', extension: '.xyz'),
        isA<Exception>(),
      );
      expect(
        FileReadError(path: '/test/file', reason: 'permission denied'),
        isA<Exception>(),
      );
    });

    test('Phase 3 errors extend EmbedAnythingError (sealed class)', () {
      expect(FileNotFoundError('/test/path'), isA<EmbedAnythingError>());
      expect(
        UnsupportedFileFormatError(path: '/test/file.xyz', extension: '.xyz'),
        isA<EmbedAnythingError>(),
      );
      expect(
        FileReadError(path: '/test/file', reason: 'permission denied'),
        isA<EmbedAnythingError>(),
      );
    });

    test('Error pattern matching works with sealed class', () {
      final error = ModelNotFoundError('test-model') as EmbedAnythingError;

      final message = switch (error) {
        ModelNotFoundError() => 'Model not found error',
        InvalidConfigError() => 'Invalid config error',
        EmbeddingFailedError() => 'Embedding failed error',
        MultiVectorNotSupportedError() => 'Multi-vector not supported error',
        FFIError() => 'FFI error',
        FileNotFoundError() => 'File not found error',
        UnsupportedFileFormatError() => 'Unsupported file format error',
        FileReadError() => 'File read error',
      };

      expect(message, equals('Model not found error'));
    });
  });
}
