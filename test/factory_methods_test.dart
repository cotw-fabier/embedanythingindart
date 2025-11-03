import 'package:embedanythingindart/embedanythingindart.dart';
import 'package:test/test.dart';

void main() {
  group('ModelConfig Factory Methods Integration', () {
    test('bertMiniLML6 config produces working embedder', () {
      final config = ModelConfig.bertMiniLML6();
      final embedder = EmbedAnything.fromConfig(config);

      try {
        final result = embedder.embedText('Test with BERT MiniLM-L6');
        expect(result.dimension, equals(384));
      } finally {
        embedder.dispose();
      }
    });

    test('bertMiniLML12 config produces working embedder', () {
      final config = ModelConfig.bertMiniLML12();
      final embedder = EmbedAnything.fromConfig(config);

      try {
        final result = embedder.embedText('Test with BERT MiniLM-L12');
        expect(result.dimension, equals(384));
      } finally {
        embedder.dispose();
      }
    }, tags: ['slow']);

    test('jinaV2Small config produces working embedder', () {
      final config = ModelConfig.jinaV2Small();
      final embedder = EmbedAnything.fromConfig(config);

      try {
        final result = embedder.embedText('Test with Jina v2-small');
        expect(result.dimension, equals(512));
      } finally {
        embedder.dispose();
      }
    }, tags: ['slow']);

    test('jinaV2Base config produces working embedder', () {
      final config = ModelConfig.jinaV2Base();
      final embedder = EmbedAnything.fromConfig(config);

      try {
        final result = embedder.embedText('Test with Jina v2-base');
        expect(result.dimension, equals(768));
      } finally {
        embedder.dispose();
      }
    }, tags: ['slow']);

    test('factory methods have correct default values', () {
      // Test BERT
      final bertConfig = ModelConfig.bertMiniLML6();
      expect(bertConfig.revision, equals('main'));
      expect(bertConfig.dtype, equals(ModelDtype.f32));
      expect(bertConfig.normalize, isTrue);
      expect(bertConfig.defaultBatchSize, equals(32));

      // Test Jina
      final jinaConfig = ModelConfig.jinaV2Small();
      expect(jinaConfig.revision, equals('main'));
      expect(jinaConfig.dtype, equals(ModelDtype.f32));
      expect(jinaConfig.normalize, isTrue);
      expect(jinaConfig.defaultBatchSize, equals(32));
    });

    test('config property is accessible from embedder', () {
      final config = ModelConfig.bertMiniLML6();
      final embedder = EmbedAnything.fromConfig(config);

      try {
        expect(embedder.config, isNotNull);
        expect(embedder.config?.modelId, equals(config.modelId));
        expect(embedder.config?.modelType, equals(config.modelType));
      } finally {
        embedder.dispose();
      }
    });
  });
}
