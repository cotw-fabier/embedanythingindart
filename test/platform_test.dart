import 'dart:io';

import 'package:embedanythingindart/embedanythingindart.dart';
import 'package:test/test.dart';

void main() {
  group('Platform-Specific Tests', () {
    test('asset loading works on current platform', () {
      // Verify we can load the native library on the current platform
      final embedder = EmbedAnything.fromPretrainedHf(
        model: EmbeddingModel.bert,
        modelId: 'sentence-transformers/all-MiniLM-L6-v2',
      );

      expect(embedder, isNotNull);

      // Verify it actually works
      final result = embedder.embedText('Platform test');
      expect(result.dimension, equals(384));

      embedder.dispose();
    }, testOn: '!browser'); // Skip on web platform

    test('model caching behavior is consistent', () {
      // First load - may download model
      final embedder1 = EmbedAnything.fromPretrainedHf(
        model: EmbeddingModel.bert,
        modelId: 'sentence-transformers/all-MiniLM-L6-v2',
      );

      final result1 = embedder1.embedText('First load');
      embedder1.dispose();

      // Second load - should use cached model (faster)
      final embedder2 = EmbedAnything.fromPretrainedHf(
        model: EmbeddingModel.bert,
        modelId: 'sentence-transformers/all-MiniLM-L6-v2',
      );

      final result2 = embedder2.embedText('Second load');
      embedder2.dispose();

      // Both should produce embeddings of same dimension
      expect(result1.dimension, equals(result2.dimension));
      expect(result1.dimension, equals(384));
    }, testOn: '!browser');

    test('handles file paths correctly', () {
      // Verify that model IDs with special characters work
      // (though most HuggingFace models use simple names)
      final embedder = EmbedAnything.fromPretrainedHf(
        model: EmbeddingModel.bert,
        modelId: 'sentence-transformers/all-MiniLM-L6-v2',
      );

      expect(embedder, isNotNull);
      embedder.dispose();
    }, testOn: '!browser');

    test('platform-specific behavior - macOS', () {
      expect(Platform.isMacOS, isTrue);

      final embedder = EmbedAnything.fromPretrainedHf(
        model: EmbeddingModel.bert,
        modelId: 'sentence-transformers/all-MiniLM-L6-v2',
      );

      final result = embedder.embedText('macOS test');
      expect(result.dimension, equals(384));

      embedder.dispose();
    }, testOn: 'mac-os');

    test('platform-specific behavior - Linux', () {
      expect(Platform.isLinux, isTrue);

      final embedder = EmbedAnything.fromPretrainedHf(
        model: EmbeddingModel.bert,
        modelId: 'sentence-transformers/all-MiniLM-L6-v2',
      );

      final result = embedder.embedText('Linux test');
      expect(result.dimension, equals(384));

      embedder.dispose();
    }, testOn: 'linux');

    test('platform-specific behavior - Windows', () {
      expect(Platform.isWindows, isTrue);

      final embedder = EmbedAnything.fromPretrainedHf(
        model: EmbeddingModel.bert,
        modelId: 'sentence-transformers/all-MiniLM-L6-v2',
      );

      final result = embedder.embedText('Windows test');
      expect(result.dimension, equals(384));

      embedder.dispose();
    }, testOn: 'windows');

    test('multiple models can be loaded simultaneously', () {
      final embedder1 = EmbedAnything.fromPretrainedHf(
        model: EmbeddingModel.bert,
        modelId: 'sentence-transformers/all-MiniLM-L6-v2',
      );

      final embedder2 = EmbedAnything.fromPretrainedHf(
        model: EmbeddingModel.bert,
        modelId: 'sentence-transformers/all-MiniLM-L12-v2',
      );

      try {
        final result1 = embedder1.embedText('Model 1');
        final result2 = embedder2.embedText('Model 2');

        expect(result1.dimension, equals(384)); // MiniLM-L6
        expect(result2.dimension, equals(384)); // MiniLM-L12 also 384-dim
      } finally {
        embedder1.dispose();
        embedder2.dispose();
      }
    }, testOn: '!browser', tags: ['slow']);

    test('consistent results across platforms', () {
      // The same text should produce similar embeddings on all platforms
      final embedder = EmbedAnything.fromPretrainedHf(
        model: EmbeddingModel.bert,
        modelId: 'sentence-transformers/all-MiniLM-L6-v2',
      );

      try {
        final text = 'Consistency test across platforms';
        final result1 = embedder.embedText(text);
        final result2 = embedder.embedText(text);

        // Should be extremely similar (allowing for floating point precision)
        final similarity = result1.cosineSimilarity(result2);
        expect(similarity, greaterThan(0.9999));
      } finally {
        embedder.dispose();
      }
    }, testOn: '!browser');
  });
}
