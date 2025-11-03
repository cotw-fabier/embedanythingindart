import 'package:embedanythingindart/embedanythingindart.dart';
import 'package:test/test.dart';

void main() {
  group('Edge Case Tests', () {
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

    test('handles empty string', () {
      final result = embedder.embedText('');
      expect(result, isA<EmbeddingResult>());
      expect(result.dimension, equals(384));
      expect(result.values, hasLength(384));
    });

    test('handles Unicode emoji', () {
      final result = embedder.embedText('Hello 👋 World 🌍 😊');
      expect(result, isA<EmbeddingResult>());
      expect(result.dimension, equals(384));
    });

    test('handles Chinese characters', () {
      final result = embedder.embedText('你好世界，这是一个测试');
      expect(result, isA<EmbeddingResult>());
      expect(result.dimension, equals(384));
    });

    test('handles Arabic script', () {
      final result = embedder.embedText('مرحبا بالعالم هذا اختبار');
      expect(result, isA<EmbeddingResult>());
      expect(result.dimension, equals(384));
    });

    test('handles special characters - newlines and tabs', () {
      final result = embedder.embedText('Line 1\nLine 2\tTabbed');
      expect(result, isA<EmbeddingResult>());
      expect(result.dimension, equals(384));
    });

    test('handles special characters - quotes', () {
      final result = embedder.embedText('Text with "quotes" and \'apostrophes\'');
      expect(result, isA<EmbeddingResult>());
      expect(result.dimension, equals(384));
    });

    test('handles very long text exceeding tokenizer limits', () {
      // BERT typically has 512 token limit
      // Create text with ~1000 words to exceed this
      final longText = 'word ' * 1000;
      final result = embedder.embedText(longText);
      expect(result, isA<EmbeddingResult>());
      expect(result.dimension, equals(384));
      // Model should handle this gracefully by truncating
    });

    test('handles whitespace-only strings', () {
      final result = embedder.embedText('   \t  \n  ');
      expect(result, isA<EmbeddingResult>());
      expect(result.dimension, equals(384));
    });

    test('handles mixed-length batch', () {
      final texts = [
        '', // empty
        'Short', // short
        'This is a medium length text with some content', // medium
        'word ' * 200, // long
        '   ', // whitespace only
        'Normal text at the end',
      ];

      final results = embedder.embedTextsBatch(texts);

      expect(results, hasLength(texts.length));
      for (final result in results) {
        expect(result.dimension, equals(384));
        expect(result.values, hasLength(384));
      }
    });
  });
}
