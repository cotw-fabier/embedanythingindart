import 'package:embedanythingindart/embedanythingindart.dart';
import 'package:test/test.dart';

void main() {
  group('EmbedAnything Model Loading', () {
    test('loads BERT model successfully', () {
      final embedder = EmbedAnything.fromPretrainedHf(
        model: EmbeddingModel.bert,
        modelId: 'sentence-transformers/all-MiniLM-L6-v2',
      );

      expect(embedder, isNotNull);
      embedder.dispose();
    });

    test('throws exception for invalid model', () {
      expect(
        () => EmbedAnything.fromPretrainedHf(
          model: EmbeddingModel.bert,
          modelId: 'invalid/model/that/does/not/exist',
        ),
        throwsA(isA<EmbedAnythingError>()),
      );
    });
  });

  group('EmbedAnything Single Text Embedding', () {
    late EmbedAnything embedder;

    setUpAll(() {
      embedder = EmbedAnything.fromPretrainedHf(
        model: EmbeddingModel.bert,
        modelId: 'sentence-transformers/all-MiniLM-L6-v2',
      );
    });

    tearDownAll(() {
      embedder.dispose();
    });

    test('generates embedding for simple text', () {
      final result = embedder.embedText('Hello, world!');

      expect(result, isA<EmbeddingResult>());
      expect(result.dimension, equals(384)); // MiniLM-L6-v2 is 384-dim
      expect(result.values, hasLength(384));
    });

    test('generates different embeddings for different texts', () {
      final result1 = embedder.embedText('Machine learning');
      final result2 = embedder.embedText('Cooking recipes');

      expect(result1, isNot(equals(result2)));
    });

    test('generates consistent embeddings for same text', () {
      final result1 = embedder.embedText('Consistency test');
      final result2 = embedder.embedText('Consistency test');

      // Should be very similar (allowing for minor floating point differences)
      final similarity = result1.cosineSimilarity(result2);
      expect(similarity, greaterThan(0.99));
    });

    test('handles empty string', () {
      final result = embedder.embedText('');
      expect(result, isA<EmbeddingResult>());
      expect(result.dimension, equals(384));
    });

    test('handles long text', () {
      final longText = 'word ' * 1000; // 1000 words
      final result = embedder.embedText(longText);
      expect(result, isA<EmbeddingResult>());
      expect(result.dimension, equals(384));
    });
  });

  group('EmbedAnything Batch Embedding', () {
    late EmbedAnything embedder;

    setUpAll(() {
      embedder = EmbedAnything.fromPretrainedHf(
        model: EmbeddingModel.bert,
        modelId: 'sentence-transformers/all-MiniLM-L6-v2',
      );
    });

    tearDownAll(() {
      embedder.dispose();
    });

    test('generates embeddings for multiple texts', () {
      final texts = [
        'First text',
        'Second text',
        'Third text',
      ];

      final results = embedder.embedTextsBatch(texts);

      expect(results, hasLength(3));
      for (final result in results) {
        expect(result.dimension, equals(384));
      }
    });

    test('handles empty batch', () {
      final results = embedder.embedTextsBatch([]);
      expect(results, isEmpty);
    });

    test('handles single item in batch', () {
      final results = embedder.embedTextsBatch(['Single item']);
      expect(results, hasLength(1));
      expect(results[0].dimension, equals(384));
    });

    test('batch results match individual results', () {
      final text = 'Test text for consistency';

      final singleResult = embedder.embedText(text);
      final batchResults = embedder.embedTextsBatch([text]);

      final similarity = singleResult.cosineSimilarity(batchResults[0]);
      expect(similarity, greaterThan(0.99));
    });
  });

  group('EmbeddingResult', () {
    test('computes cosine similarity correctly', () {
      // Create identical embeddings
      final emb1 = EmbeddingResult([1.0, 0.0, 0.0]);
      final emb2 = EmbeddingResult([1.0, 0.0, 0.0]);

      expect(emb1.cosineSimilarity(emb2), closeTo(1.0, 0.001));
    });

    test('computes cosine similarity for orthogonal vectors', () {
      final emb1 = EmbeddingResult([1.0, 0.0, 0.0]);
      final emb2 = EmbeddingResult([0.0, 1.0, 0.0]);

      expect(emb1.cosineSimilarity(emb2), closeTo(0.0, 0.001));
    });

    test('throws error for mismatched dimensions', () {
      final emb1 = EmbeddingResult([1.0, 0.0]);
      final emb2 = EmbeddingResult([1.0, 0.0, 0.0]);

      expect(
        () => emb1.cosineSimilarity(emb2),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('toString shows dimension and preview', () {
      final emb = EmbeddingResult([1.0, 2.0, 3.0, 4.0, 5.0, 6.0]);
      final str = emb.toString();

      expect(str, contains('dimension: 6'));
      expect(str, contains('1.0'));
      expect(str, contains('2.0'));
    });

    test('equality works for same embeddings', () {
      final emb1 = EmbeddingResult([1.0, 2.0, 3.0]);
      final emb2 = EmbeddingResult([1.0, 2.0, 3.0]);

      expect(emb1, equals(emb2));
    });

    test('inequality works for different embeddings', () {
      final emb1 = EmbeddingResult([1.0, 2.0, 3.0]);
      final emb2 = EmbeddingResult([1.0, 2.0, 4.0]);

      expect(emb1, isNot(equals(emb2)));
    });
  });

  group('EmbedAnything Memory Management', () {
    test('can be used after creation', () {
      final embedder = EmbedAnything.fromPretrainedHf(
        model: EmbeddingModel.bert,
        modelId: 'sentence-transformers/all-MiniLM-L6-v2',
      );

      final result = embedder.embedText('Test');
      expect(result, isA<EmbeddingResult>());

      embedder.dispose();
    });

    test('throws error when used after dispose', () {
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

    test('dispose can be called multiple times safely', () {
      final embedder = EmbedAnything.fromPretrainedHf(
        model: EmbeddingModel.bert,
        modelId: 'sentence-transformers/all-MiniLM-L6-v2',
      );

      embedder.dispose();
      embedder.dispose(); // Should not crash

      expect(true, isTrue); // Test completes without error
    });
  });

  group('Semantic Similarity Tests', () {
    late EmbedAnything embedder;

    setUpAll(() {
      embedder = EmbedAnything.fromPretrainedHf(
        model: EmbeddingModel.bert,
        modelId: 'sentence-transformers/all-MiniLM-L6-v2',
      );
    });

    tearDownAll(() {
      embedder.dispose();
    });

    test('similar texts have high similarity', () {
      final emb1 = embedder.embedText('I love programming');
      final emb2 = embedder.embedText('I enjoy coding');

      final similarity = emb1.cosineSimilarity(emb2);
      expect(similarity, greaterThan(0.5)); // Should be relatively similar
    });

    test('dissimilar texts have low similarity', () {
      final emb1 = embedder.embedText('Programming in Rust');
      final emb2 = embedder.embedText('Cooking delicious food');

      final similarity = emb1.cosineSimilarity(emb2);
      expect(similarity, lessThan(0.5)); // Should be relatively dissimilar
    });
  });
}
