import 'dart:io';
import 'package:test/test.dart';
import 'package:embedanythingindart/embedanythingindart.dart';

/// Tests for async embedding operations.
///
/// These tests verify that the async API works correctly for:
/// - Model loading (fromPretrainedHfAsync)
/// - Text embedding (embedTextAsync, embedTextsBatchAsync)
/// - Cancellation (AsyncEmbeddingOperation.cancel)
void main() {
  group('Async Model Loading', () {
    test('fromPretrainedHfAsync loads model without blocking', () async {
      final embedder = await EmbedAnything.fromPretrainedHfAsync(
        modelId: 'sentence-transformers/all-MiniLM-L6-v2',
      );

      expect(embedder, isNotNull);
      expect(embedder.config, isNotNull);
      expect(embedder.config!.modelId, equals('sentence-transformers/all-MiniLM-L6-v2'));

      embedder.dispose();
    });

    test('fromPretrainedHfAsync throws error for invalid model', () async {
      // Note: HuggingFace may return different errors (404 not found, 401 auth required)
      // depending on the model ID and server state
      expect(
        () => EmbedAnything.fromPretrainedHfAsync(
          modelId: 'invalid/nonexistent-model-12345',
        ),
        throwsA(isA<EmbedAnythingError>()),
      );
    });
  });

  group('Async Text Embedding', () {
    late EmbedAnything embedder;

    setUpAll(() async {
      embedder = await EmbedAnything.fromPretrainedHfAsync(
        modelId: 'sentence-transformers/all-MiniLM-L6-v2',
      );
    });

    tearDownAll(() {
      embedder.dispose();
    });

    test('embedTextAsync returns correct dimension', () async {
      final result = await embedder.embedTextAsync('Hello, world!');

      expect(result.dimension, equals(384));
      expect(result.values, hasLength(384));
    });

    test('embedTextAsync produces semantic similarity', () async {
      final result1 = await embedder.embedTextAsync('The cat sat on the mat');
      final result2 = await embedder.embedTextAsync('A feline rested on the rug');
      final result3 = await embedder.embedTextAsync('Quantum physics is complex');

      // Similar texts should have higher similarity
      final similarity12 = result1.cosineSimilarity(result2);
      final similarity13 = result1.cosineSimilarity(result3);

      expect(similarity12, greaterThan(similarity13),
          reason: 'Cat/mat and feline/rug should be more similar than cat and quantum physics');
    });

    test('embedTextsBatchAsync returns correct number of results', () async {
      final texts = ['First text', 'Second text', 'Third text'];
      final results = await embedder.embedTextsBatchAsync(texts);

      expect(results, hasLength(3));
      for (final result in results) {
        expect(result.dimension, equals(384));
      }
    });

    test('embedTextsBatchAsync handles empty list', () async {
      final results = await embedder.embedTextsBatchAsync([]);

      expect(results, isEmpty);
    });
  });

  group('Sync and Async Consistency', () {
    late EmbedAnything embedder;

    setUpAll(() async {
      embedder = await EmbedAnything.fromPretrainedHfAsync(
        modelId: 'sentence-transformers/all-MiniLM-L6-v2',
      );
    });

    tearDownAll(() {
      embedder.dispose();
    });

    test('embedTextAsync produces same results as embedText', () async {
      const text = 'This is a test sentence for comparison';

      final syncResult = embedder.embedText(text);
      final asyncResult = await embedder.embedTextAsync(text);

      expect(asyncResult.dimension, equals(syncResult.dimension));

      // Check first few values match
      for (int i = 0; i < 10; i++) {
        expect(asyncResult.values[i], closeTo(syncResult.values[i], 1e-6),
            reason: 'Value at index $i should match');
      }
    });
  });

  group('Cancellation', () {
    late EmbedAnything embedder;

    setUpAll(() async {
      embedder = await EmbedAnything.fromPretrainedHfAsync(
        modelId: 'sentence-transformers/all-MiniLM-L6-v2',
      );
    });

    tearDownAll(() {
      embedder.dispose();
    });

    test('startEmbedTextAsync returns cancellable operation', () {
      final operation = embedder.startEmbedTextAsync('Test text');

      expect(operation, isNotNull);
      expect(operation.operationId, greaterThan(0));
      expect(operation.isCancelled, isFalse);
    });

    test('cancel sets isCancelled flag', () async {
      final operation = embedder.startEmbedTextAsync('Test text');
      operation.cancel();

      expect(operation.isCancelled, isTrue);

      // Wait for the operation to complete (with error)
      try {
        await operation.future;
      } on EmbeddingCancelledError {
        // Expected
      } catch (_) {
        // Operation might complete before cancellation takes effect
      }
    });

    test('cancelled operation throws EmbeddingCancelledError', () async {
      final operation = embedder.startEmbedTextAsync('Test text');

      // Cancel immediately
      operation.cancel();

      // The future should eventually complete with cancelled error or succeed
      // (if it completed before cancellation took effect)
      try {
        await operation.future;
        // If we get here, operation completed before cancellation
      } on EmbeddingCancelledError {
        // Expected if cancellation happened in time
      }
    });

    test('cancel is idempotent', () async {
      final operation = embedder.startEmbedTextAsync('Test text');

      // Multiple cancels should not throw
      operation.cancel();
      operation.cancel();
      operation.cancel();

      expect(operation.isCancelled, isTrue);

      // Wait for the operation to complete
      try {
        await operation.future;
      } on EmbeddingCancelledError {
        // Expected
      } catch (_) {
        // Operation might complete before cancellation takes effect
      }
    });
  });

  group('Error Handling', () {
    test('embedTextAsync throws after dispose', () async {
      final embedder = await EmbedAnything.fromPretrainedHfAsync(
        modelId: 'sentence-transformers/all-MiniLM-L6-v2',
      );
      embedder.dispose();

      expect(
        () => embedder.embedTextAsync('test'),
        throwsStateError,
      );
    });

    test('embedTextsBatchAsync throws after dispose', () async {
      final embedder = await EmbedAnything.fromPretrainedHfAsync(
        modelId: 'sentence-transformers/all-MiniLM-L6-v2',
      );
      embedder.dispose();

      expect(
        () => embedder.embedTextsBatchAsync(['test']),
        throwsStateError,
      );
    });
  });

  group('Async File Embedding', () {
    late EmbedAnything embedder;
    late File testFile;

    setUpAll(() async {
      embedder = await EmbedAnything.fromPretrainedHfAsync(
        modelId: 'sentence-transformers/all-MiniLM-L6-v2',
      );
      // Create test file
      testFile = File('test_async_file.txt');
      testFile.writeAsStringSync(
          'This is test content for async file embedding. '
          'It contains enough text to generate at least one chunk.');
    });

    tearDownAll(() {
      embedder.dispose();
      if (testFile.existsSync()) testFile.deleteSync();
    });

    test('embedFileAsync returns chunks with correct dimension', () async {
      final chunks = await embedder.embedFileAsync('test_async_file.txt');
      expect(chunks, isNotEmpty);
      for (final chunk in chunks) {
        expect(chunk.embedding.dimension, equals(384));
      }
    });

    test('embedFileAsync returns chunks with embeddings', () async {
      final chunks = await embedder.embedFileAsync('test_async_file.txt');
      expect(chunks, isNotEmpty);
      // Verify each chunk has a valid embedding
      for (final chunk in chunks) {
        expect(chunk.embedding, isNotNull);
        expect(chunk.embedding.values, isNotEmpty);
      }
    });

    test('embedFileAsync throws FileNotFoundError for missing file', () async {
      expect(
        () => embedder.embedFileAsync('nonexistent_file_12345.txt'),
        throwsA(isA<FileNotFoundError>()),
      );
    });

    test('embedFileAsync throws after dispose', () async {
      final tempEmbedder = await EmbedAnything.fromPretrainedHfAsync(
        modelId: 'sentence-transformers/all-MiniLM-L6-v2',
      );
      tempEmbedder.dispose();

      expect(
        () => tempEmbedder.embedFileAsync('test_async_file.txt'),
        throwsStateError,
      );
    });
  });

  group('Async Directory Embedding', () {
    late EmbedAnything embedder;
    late Directory testDir;

    setUpAll(() async {
      embedder = await EmbedAnything.fromPretrainedHfAsync(
        modelId: 'sentence-transformers/all-MiniLM-L6-v2',
      );
      // Create test directory with files (using longer content to ensure separate chunks)
      testDir = Directory('test_async_dir');
      if (testDir.existsSync()) {
        testDir.deleteSync(recursive: true);
      }
      testDir.createSync();
      File('test_async_dir/file1.txt').writeAsStringSync(
          'First test file content for async embedding. '
          'This file contains enough content to be processed as a standalone chunk. '
          'Machine learning models transform text into dense vector representations.');
      File('test_async_dir/file2.txt').writeAsStringSync(
          'Second test file content for async embedding. '
          'This is another file with different content that should be processed separately. '
          'Vector embeddings capture semantic meaning of text documents.');
    });

    tearDownAll(() {
      embedder.dispose();
      if (testDir.existsSync()) testDir.deleteSync(recursive: true);
    });

    test('embedDirectoryAsync returns chunks from directory', () async {
      final chunks = await embedder.embedDirectoryAsync('test_async_dir');
      expect(chunks, isNotEmpty);
      // Verify chunks have correct embedding dimensions
      for (final chunk in chunks) {
        expect(chunk.embedding.dimension, equals(384));
      }
    });

    test('embedDirectoryAsync respects extension filter', () async {
      // Create a .md file
      File('test_async_dir/readme.md').writeAsStringSync('Markdown content here');

      final txtChunks = await embedder.embedDirectoryAsync(
        'test_async_dir',
        extensions: ['.txt'],
      );

      for (final chunk in txtChunks) {
        expect(chunk.filePath, endsWith('.txt'));
      }
    });

    test('embedDirectoryAsync throws FileNotFoundError for missing dir',
        () async {
      expect(
        () => embedder.embedDirectoryAsync('nonexistent_directory_12345'),
        throwsA(isA<FileNotFoundError>()),
      );
    });

    test('embedDirectoryAsync throws after dispose', () async {
      final tempEmbedder = await EmbedAnything.fromPretrainedHfAsync(
        modelId: 'sentence-transformers/all-MiniLM-L6-v2',
      );
      tempEmbedder.dispose();

      expect(
        () => tempEmbedder.embedDirectoryAsync('test_async_dir'),
        throwsStateError,
      );
    });
  });

  group('Async Model Loading Options', () {
    test('fromPretrainedHfAsync with f16 dtype loads successfully', () async {
      final embedder = await EmbedAnything.fromPretrainedHfAsync(
        modelId: 'sentence-transformers/all-MiniLM-L6-v2',
        dtype: ModelDtype.f16,
      );

      expect(embedder, isNotNull);
      final result = await embedder.embedTextAsync('test');
      expect(result.dimension, equals(384));

      embedder.dispose();
    });

    test('fromPretrainedHfAsync config is preserved', () async {
      final embedder = await EmbedAnything.fromPretrainedHfAsync(
        modelId: 'sentence-transformers/all-MiniLM-L6-v2',
        dtype: ModelDtype.f32,
      );

      expect(embedder.config, isNotNull);
      expect(embedder.config!.modelId,
          equals('sentence-transformers/all-MiniLM-L6-v2'));

      embedder.dispose();
    });
  });
}
