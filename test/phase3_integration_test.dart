import 'dart:io';
import 'package:test/test.dart';
import 'package:embedanythingindart/embedanythingindart.dart';

/// Integration tests for Phase 3 file and directory embedding feature
///
/// These tests verify end-to-end workflows with real files:
/// - embedFile() with .txt and .md files
/// - embedDirectory() streaming with extension filtering
/// - Error handling for missing files and unsupported formats
/// - Metadata parsing and ChunkEmbedding utilities
///
/// Tests use fixture files in test/fixtures/ directory.
///
/// Note: These tests require internet connection on first run to download
/// the BERT model from HuggingFace Hub (~90MB). Subsequent runs use cached model.
void main() {
  late EmbedAnything embedder;
  late String fixturesPath;

  setUpAll(() {
    // Load embedder once for all tests (model download happens here)
    embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());

    // Get absolute path to fixtures directory
    final testDir = Directory.current.path;
    fixturesPath = '$testDir${Platform.pathSeparator}test${Platform.pathSeparator}fixtures';

    // Verify fixtures exist
    final fixturesDir = Directory(fixturesPath);
    if (!fixturesDir.existsSync()) {
      throw StateError(
          'Fixtures directory not found at $fixturesPath. Run tests from project root.');
    }
  });

  tearDownAll(() {
    embedder.dispose();
  });

  group('embedFile() integration', () {
    test('embeds .txt file and returns chunks with embeddings', () async {
      // Arrange
      final filePath = '$fixturesPath${Platform.pathSeparator}sample.txt';

      // Act
      final chunks = await embedder.embedFile(
        filePath,
        chunkSize: 1000,
        overlapRatio: 0.0,
      );

      // Assert
      expect(chunks, isNotEmpty, reason: 'Should return at least one chunk');
      expect(chunks.length, greaterThanOrEqualTo(1),
          reason: 'sample.txt should produce at least 1 chunk');

      // Verify first chunk has all required components
      final firstChunk = chunks[0];
      expect(firstChunk.embedding, isNotNull);
      expect(firstChunk.embedding.dimension, equals(384),
          reason: 'BERT MiniLM-L6 produces 384-dim embeddings');
      expect(firstChunk.text, isNotNull, reason: 'Chunk should have text');
      expect(firstChunk.text!.isNotEmpty, isTrue);

      // Verify metadata
      expect(firstChunk.metadata, isNotNull);
      expect(firstChunk.filePath, contains('sample.txt'),
          reason: 'Metadata should contain file path');
      expect(firstChunk.chunkIndex, isNotNull,
          reason: 'Chunk should have index');
      expect(firstChunk.chunkIndex, greaterThanOrEqualTo(0));
    });

    test('embeds .md file and extracts markdown content', () async {
      // Arrange
      final filePath = '$fixturesPath${Platform.pathSeparator}sample.md';

      // Act
      final chunks = await embedder.embedFile(
        filePath,
        chunkSize: 1500,
      );

      // Assert
      expect(chunks, isNotEmpty);

      // Verify text extraction worked (should contain content without markdown syntax issues)
      final firstChunk = chunks[0];
      expect(firstChunk.text, isNotNull);
      expect(firstChunk.text, contains('embedding'),
          reason: 'Should extract text from markdown');

      // Verify embedding quality
      expect(firstChunk.embedding.dimension, equals(384));
      expect(firstChunk.filePath, contains('sample.md'));
    });

    test('throws FileNotFoundError for non-existent file', () async {
      // Arrange
      final nonExistentPath =
          '$fixturesPath${Platform.pathSeparator}does_not_exist.txt';

      // Act & Assert
      expect(
        () => embedder.embedFile(nonExistentPath),
        throwsA(isA<FileNotFoundError>()),
        reason: 'Should throw FileNotFoundError for missing file',
      );
    });

    test('throws UnsupportedFileFormatError for unsupported extension',
        () async {
      // Arrange - create a temporary file with unsupported extension
      final tempFile =
          File('$fixturesPath${Platform.pathSeparator}temp_test.xyz');
      tempFile.writeAsStringSync('test content');

      try {
        // Act & Assert
        expect(
          () => embedder.embedFile(tempFile.path),
          throwsA(isA<UnsupportedFileFormatError>()),
          reason: 'Should throw UnsupportedFileFormatError for .xyz files',
        );
      } finally {
        // Cleanup
        if (tempFile.existsSync()) {
          tempFile.deleteSync();
        }
      }
    });
  });

  group('embedDirectory() integration', () {
    test('streams all files from directory', () async {
      // Arrange
      final dirPath = '$fixturesPath${Platform.pathSeparator}sample_dir';

      // Act
      final stream = embedder.embedDirectory(dirPath, chunkSize: 500);
      final chunks = await stream.toList();

      // Assert
      expect(chunks, isNotEmpty,
          reason: 'Should return chunks from directory files');

      // sample_dir has 5 files (3 .txt, 2 .md), each should produce at least 1 chunk
      expect(chunks.length, greaterThanOrEqualTo(5),
          reason:
              'Directory has 5 files, should produce at least 5 chunks total');

      // Verify chunks have valid embeddings
      for (final chunk in chunks) {
        expect(chunk.embedding, isNotNull);
        expect(chunk.embedding.dimension, equals(384));
        expect(chunk.filePath, isNotNull);
      }

      // Verify we got chunks from different files
      final filePaths = chunks.map((c) => c.filePath).toSet();
      expect(filePaths.length, greaterThanOrEqualTo(3),
          reason: 'Should process multiple different files');
    });

    test('filters files by extension (.txt only)', () async {
      // Arrange
      final dirPath = '$fixturesPath${Platform.pathSeparator}sample_dir';

      // Act
      final stream = embedder.embedDirectory(
        dirPath,
        extensions: ['.txt'],
        chunkSize: 500,
      );
      final chunks = await stream.toList();

      // Assert
      expect(chunks, isNotEmpty);

      // Verify only .txt files were processed
      for (final chunk in chunks) {
        expect(chunk.filePath, contains('.txt'),
            reason: 'With .txt filter, only .txt files should be processed');
        expect(chunk.filePath, isNot(contains('.md')));
      }

      // sample_dir has 3 .txt files (doc1, doc2, doc5)
      expect(chunks.length, greaterThanOrEqualTo(3),
          reason: 'Should process at least 3 .txt files');
    });

    test('filters files by extension (.md only)', () async {
      // Arrange
      final dirPath = '$fixturesPath${Platform.pathSeparator}sample_dir';

      // Act
      final stream = embedder.embedDirectory(
        dirPath,
        extensions: ['.md'],
        chunkSize: 500,
      );
      final chunks = await stream.toList();

      // Assert
      expect(chunks, isNotEmpty);

      // Verify only .md files were processed
      for (final chunk in chunks) {
        expect(chunk.filePath, contains('.md'),
            reason: 'With .md filter, only .md files should be processed');
        expect(chunk.filePath, isNot(contains('.txt')));
      }

      // sample_dir has 2 .md files (doc3, doc4)
      expect(chunks.length, greaterThanOrEqualTo(2),
          reason: 'Should process at least 2 .md files');
    });

    test('throws FileNotFoundError for non-existent directory', () async {
      // Arrange
      final nonExistentDir =
          '$fixturesPath${Platform.pathSeparator}does_not_exist_dir';

      // Act & Assert
      final stream = embedder.embedDirectory(nonExistentDir);

      // Stream errors are delivered via stream, not thrown immediately
      expect(
        stream.toList(),
        throwsA(isA<FileNotFoundError>()),
        reason: 'Should emit FileNotFoundError in stream for missing directory',
      );
    });
  });

  group('ChunkEmbedding metadata and utilities', () {
    test('metadata parsing extracts filePath and chunkIndex correctly',
        () async {
      // Arrange
      final filePath = '$fixturesPath${Platform.pathSeparator}sample.txt';

      // Act
      final chunks = await embedder.embedFile(filePath, chunkSize: 1000);

      // Assert
      expect(chunks, isNotEmpty);

      // Verify first chunk metadata
      final chunk = chunks[0];
      expect(chunk.filePath, isNotNull);
      expect(chunk.filePath, contains('sample.txt'));
      expect(chunk.chunkIndex, equals(0),
          reason: 'First chunk should have index 0');

      // If multiple chunks, verify subsequent chunks have incremented indices
      if (chunks.length > 1) {
        expect(chunks[1].chunkIndex, equals(1));
      }
    });

    test('cosineSimilarity computes similarity between chunks', () async {
      // Arrange
      final filePath = '$fixturesPath${Platform.pathSeparator}sample.txt';
      final chunks = await embedder.embedFile(filePath, chunkSize: 1000);

      // Act
      // Compare first chunk with itself (should be 1.0)
      final selfSimilarity = chunks[0].cosineSimilarity(chunks[0]);

      // Assert
      expect(selfSimilarity, closeTo(1.0, 0.001),
          reason: 'Chunk compared with itself should have similarity ~1.0');

      // If we have multiple chunks, compare different chunks
      if (chunks.length > 1) {
        final crossSimilarity = chunks[0].cosineSimilarity(chunks[1]);
        expect(crossSimilarity, greaterThan(0.0),
            reason: 'Related chunks should have positive similarity');
        expect(crossSimilarity, lessThan(1.0),
            reason: 'Different chunks should have similarity < 1.0');
      }
    });
  });

  group('Memory management', () {
    test('multiple embedFile calls do not leak memory', () async {
      // Arrange
      final filePath = '$fixturesPath${Platform.pathSeparator}sample.txt';

      // Act - Run embedFile multiple times
      for (var i = 0; i < 10; i++) {
        final chunks = await embedder.embedFile(filePath, chunkSize: 1000);
        expect(chunks, isNotEmpty,
            reason: 'Each call should return valid chunks');
      }

      // Assert - If we got here without crashing, memory management is working
      // Note: This is a basic smoke test. Proper memory leak detection would
      // require external tools, but repeated calls should not crash or slow down.
      expect(true, isTrue,
          reason: 'Multiple embedFile calls completed without crash');
    });
  });
}
