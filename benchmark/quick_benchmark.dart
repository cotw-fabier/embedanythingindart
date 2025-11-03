import 'dart:io';
import 'package:embedanythingindart/embedanythingindart.dart';

/// Quick benchmark for testing (fewer iterations)
///
/// Usage:
///   dart run --enable-experiment=native-assets benchmark/quick_benchmark.dart
void main() async {
  print('Quick Benchmark (reduced iterations for faster execution)');
  print('Platform: ${Platform.operatingSystem}');
  print('CPU Count: ${Platform.numberOfProcessors}\n');

  // Test with single model for speed
  print('Loading BERT all-MiniLM-L6-v2...');
  final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());

  // Single embedding latency
  print('\nTesting single embedding latency...');
  final shortText = 'The quick brown fox jumps over the lazy dog.';
  final times = <int>[];

  for (var i = 0; i < 10; i++) {
    final sw = Stopwatch()..start();
    embedder.embedText(shortText);
    sw.stop();
    times.add(sw.elapsedMilliseconds);
  }

  times.sort();
  print('Short text (10 iterations): mean=${times.reduce((a, b) => a + b) / times.length}ms');

  // Batch throughput
  print('\nTesting batch throughput...');
  final testTexts = List.generate(100, (i) => 'Test text number $i');

  final batchSw = Stopwatch()..start();
  embedder.embedTextsBatch(testTexts);
  batchSw.stop();
  print('Batch 100 items: ${batchSw.elapsedMilliseconds}ms (${(testTexts.length / (batchSw.elapsedMilliseconds / 1000)).toStringAsFixed(2)} items/sec)');

  // Sequential for comparison (only 10 items to avoid long runtime)
  final seqTexts = List.generate(10, (i) => 'Test text number $i');
  final seqSw = Stopwatch()..start();
  for (final text in seqTexts) {
    embedder.embedText(text);
  }
  seqSw.stop();
  print('Sequential 10 items: ${seqSw.elapsedMilliseconds}ms');

  // Batch 10 for fair comparison
  final batch10Sw = Stopwatch()..start();
  embedder.embedTextsBatch(seqTexts);
  batch10Sw.stop();
  print('Batch 10 items: ${batch10Sw.elapsedMilliseconds}ms');
  print('Speedup: ${(seqSw.elapsedMilliseconds / batch10Sw.elapsedMilliseconds).toStringAsFixed(2)}x\n');

  embedder.dispose();
  print('Quick benchmark complete!');
}
