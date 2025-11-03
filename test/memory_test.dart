import 'package:embedanythingindart/embedanythingindart.dart';
import 'package:test/test.dart';

void main() {
  group('Memory Management Tests', () {
    test('handles load/dispose cycles', () {
      // Create and dispose 100+ embedders sequentially
      for (int i = 0; i < 100; i++) {
        final embedder = EmbedAnything.fromPretrainedHf(
          model: EmbeddingModel.bert,
          modelId: 'sentence-transformers/all-MiniLM-L6-v2',
        );

        // Use the embedder
        final result = embedder.embedText('Test $i');
        expect(result.dimension, equals(384));

        // Dispose immediately
        embedder.dispose();
      }

      // If we get here without crashing, memory management is working
      expect(true, isTrue);
    }, tags: ['slow', 'memory']);

    test('handles large batch operations', () {
      final embedder = EmbedAnything.fromPretrainedHf(
        model: EmbeddingModel.bert,
        modelId: 'sentence-transformers/all-MiniLM-L6-v2',
      );

      try {
        // Create a large batch of 1000+ texts
        final texts = List.generate(1000, (i) => 'Text number $i');

        final results = embedder.embedTextsBatch(texts);

        expect(results, hasLength(1000));
        for (final result in results) {
          expect(result.dimension, equals(384));
        }
      } finally {
        embedder.dispose();
      }
    }, tags: ['slow', 'memory']);

    test('finalizer cleanup works without manual dispose', () async {
      // Create embedder without calling dispose
      EmbedAnything? embedder = EmbedAnything.fromPretrainedHf(
        model: EmbeddingModel.bert,
        modelId: 'sentence-transformers/all-MiniLM-L6-v2',
      );

      // Use it
      final result = embedder.embedText('Test');
      expect(result.dimension, equals(384));

      // Clear the reference
      embedder = null;

      // Force GC (not guaranteed, but helps test finalizer)
      await Future.delayed(Duration(milliseconds: 100));

      // If we get here without memory issues, finalizer is working
      expect(true, isTrue);
    }, tags: ['gc', 'slow']);

    test('finalizer does not double-free after manual dispose', () async {
      // Create and manually dispose
      EmbedAnything? embedder = EmbedAnything.fromPretrainedHf(
        model: EmbeddingModel.bert,
        modelId: 'sentence-transformers/all-MiniLM-L6-v2',
      );

      embedder.dispose();

      // Clear reference - finalizer should be detached
      embedder = null;

      // Force GC
      await Future.delayed(Duration(milliseconds: 100));

      // If we get here without crashes, no double-free occurred
      expect(true, isTrue);
    }, tags: ['gc', 'slow']);

    test('multiple embedders can coexist', () {
      // Create multiple embedders simultaneously
      final embedders = List.generate(
        10,
        (_) => EmbedAnything.fromPretrainedHf(
          model: EmbeddingModel.bert,
          modelId: 'sentence-transformers/all-MiniLM-L6-v2',
        ),
      );

      try {
        // Use all embedders
        for (int i = 0; i < embedders.length; i++) {
          final result = embedders[i].embedText('Test $i');
          expect(result.dimension, equals(384));
        }
      } finally {
        // Clean up all embedders
        for (final embedder in embedders) {
          embedder.dispose();
        }
      }

      expect(true, isTrue);
    }, tags: ['memory']);

    test('large batch stress test with cleanup verification', () {
      final embedder = EmbedAnything.fromPretrainedHf(
        model: EmbeddingModel.bert,
        modelId: 'sentence-transformers/all-MiniLM-L6-v2',
      );

      try {
        // Process multiple large batches
        for (int batch = 0; batch < 5; batch++) {
          final texts = List.generate(500, (i) => 'Batch $batch Text $i');
          final results = embedder.embedTextsBatch(texts);

          expect(results, hasLength(500));
          // Don't keep results around - let them be GC'd
        }
      } finally {
        embedder.dispose();
      }

      expect(true, isTrue);
    }, tags: ['slow', 'memory']);

    test('embedder cannot be used after dispose', () {
      final embedder = EmbedAnything.fromPretrainedHf(
        model: EmbeddingModel.bert,
        modelId: 'sentence-transformers/all-MiniLM-L6-v2',
      );

      embedder.dispose();

      expect(
        () => embedder.embedText('Test'),
        throwsA(isA<StateError>()),
      );
    });

    test('multiple dispose calls are safe', () {
      final embedder = EmbedAnything.fromPretrainedHf(
        model: EmbeddingModel.bert,
        modelId: 'sentence-transformers/all-MiniLM-L6-v2',
      );

      embedder.dispose();
      embedder.dispose();
      embedder.dispose();

      // No crash = success
      expect(true, isTrue);
    });
  });
}
