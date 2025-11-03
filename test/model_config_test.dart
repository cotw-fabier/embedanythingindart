import 'package:embedanythingindart/embedanythingindart.dart';
import 'package:test/test.dart';

void main() {
  group('ModelConfig Validation', () {
    test('validates empty modelId', () {
      final config = ModelConfig(
        modelId: '',
        modelType: EmbeddingModel.bert,
      );

      expect(
        () => config.validate(),
        throwsA(isA<InvalidConfigError>()
            .having((e) => e.field, 'field', 'modelId')
            .having((e) => e.reason, 'reason', contains('cannot be empty'))),
      );
    });

    test('validates negative defaultBatchSize', () {
      final config = ModelConfig(
        modelId: 'test/model',
        modelType: EmbeddingModel.bert,
        defaultBatchSize: -1,
      );

      expect(
        () => config.validate(),
        throwsA(isA<InvalidConfigError>()
            .having((e) => e.field, 'field', 'defaultBatchSize')
            .having((e) => e.reason, 'reason', contains('must be positive'))),
      );
    });

    test('validates zero defaultBatchSize', () {
      final config = ModelConfig(
        modelId: 'test/model',
        modelType: EmbeddingModel.bert,
        defaultBatchSize: 0,
      );

      expect(
        () => config.validate(),
        throwsA(isA<InvalidConfigError>()
            .having((e) => e.field, 'field', 'defaultBatchSize')
            .having((e) => e.reason, 'reason', contains('must be positive'))),
      );
    });

    test('accepts valid configuration', () {
      final config = ModelConfig(
        modelId: 'sentence-transformers/all-MiniLM-L6-v2',
        modelType: EmbeddingModel.bert,
      );

      expect(() => config.validate(), returnsNormally);
    });
  });

  group('ModelConfig Factory Methods', () {
    test('creates BERT MiniLM-L6 config', () {
      final config = ModelConfig.bertMiniLML6();

      expect(config.modelId, 'sentence-transformers/all-MiniLM-L6-v2');
      expect(config.modelType, EmbeddingModel.bert);
      expect(config.revision, 'main');
      expect(config.dtype, ModelDtype.f32);
      expect(config.normalize, true);
      expect(config.defaultBatchSize, 32);
    });

    test('creates BERT MiniLM-L12 config', () {
      final config = ModelConfig.bertMiniLML12();

      expect(config.modelId, 'sentence-transformers/all-MiniLM-L12-v2');
      expect(config.modelType, EmbeddingModel.bert);
    });

    test('creates Jina v2-small config', () {
      final config = ModelConfig.jinaV2Small();

      expect(config.modelId, 'jinaai/jina-embeddings-v2-small-en');
      expect(config.modelType, EmbeddingModel.jina);
    });

    test('creates Jina v2-base config', () {
      final config = ModelConfig.jinaV2Base();

      expect(config.modelId, 'jinaai/jina-embeddings-v2-base-en');
      expect(config.modelType, EmbeddingModel.jina);
    });
  });

  group('ModelConfig Custom Models', () {
    test('can create custom model configuration', () {
      final config = ModelConfig(
        modelId: 'custom/model',
        modelType: EmbeddingModel.bert,
        revision: 'v1.0',
        dtype: ModelDtype.f16,
        normalize: false,
        defaultBatchSize: 64,
      );

      expect(config.modelId, 'custom/model');
      expect(config.revision, 'v1.0');
      expect(config.dtype, ModelDtype.f16);
      expect(config.normalize, false);
      expect(config.defaultBatchSize, 64);
    });

    test('can load custom model via fromConfig', () {
      final config = ModelConfig(
        modelId: 'sentence-transformers/all-MiniLM-L6-v2',
        modelType: EmbeddingModel.bert,
        dtype: ModelDtype.f32,
      );

      final embedder = EmbedAnything.fromConfig(config);

      expect(embedder, isNotNull);

      // Verify it works
      final result = embedder.embedText('test');
      expect(result.dimension, 384);

      embedder.dispose();
    });
  });

  group('EmbedAnything.fromConfig Integration', () {
    test('fromConfig works with valid configuration', () {
      final config = ModelConfig.bertMiniLML6();
      final embedder = EmbedAnything.fromConfig(config);

      expect(embedder, isNotNull);

      final result = embedder.embedText('Hello, world!');
      expect(result.dimension, 384);

      embedder.dispose();
    });

    test('fromConfig validates configuration before loading', () {
      final config = ModelConfig(
        modelId: '',
        modelType: EmbeddingModel.bert,
      );

      expect(
        () => EmbedAnything.fromConfig(config),
        throwsA(isA<InvalidConfigError>()),
      );
    });
  });
}
