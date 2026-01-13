/// Memory stress test for large batch embedding operations.
///
/// This test embeds 3000 items and tracks memory pressure throughout the process.
/// Run with: dart test --enable-experiment=native-assets test/memory_stress_test.dart -r expanded
///
/// For detailed memory monitoring, run the example script instead:
/// dart run --enable-experiment=native-assets example/memory_stress_example.dart

import 'dart:io';

import 'package:embedanythingindart/embedanythingindart.dart';
import 'package:test/test.dart';

/// Get current process memory usage in MB
Map<String, double> getMemoryUsage() {
  final rss = ProcessInfo.currentRss / (1024 * 1024); // Resident Set Size in MB
  final maxRss = ProcessInfo.maxRss / (1024 * 1024); // Peak RSS in MB
  return {
    'rss_mb': rss,
    'max_rss_mb': maxRss,
  };
}

/// Format memory info for display
String formatMemory(Map<String, double> mem) {
  return 'RSS: ${mem['rss_mb']!.toStringAsFixed(1)} MB, Peak: ${mem['max_rss_mb']!.toStringAsFixed(1)} MB';
}

void main() {
  group('Memory Stress Test - 3000 Items', () {
    late EmbedAnything embedder;
    final memorySnapshots = <Map<String, dynamic>>[];

    void recordMemory(String phase) {
      final mem = getMemoryUsage();
      memorySnapshots.add({
        'phase': phase,
        'timestamp': DateTime.now().toIso8601String(),
        ...mem,
      });
      print('[$phase] ${formatMemory(mem)}');
    }

    setUpAll(() async {
      print('\n${'=' * 60}');
      print('MEMORY STRESS TEST - 3000 ITEMS');
      print('${'=' * 60}\n');

      // Configure thread pool BEFORE loading model
      print('Configuring thread pool...');
      final configured = EmbedAnything.configureThreadPool(4);
      print('Thread pool configured: $configured');
      print('Thread pool size: ${EmbedAnything.getThreadPoolSize()}');

      recordMemory('before_model_load');

      // Load model asynchronously
      print('\nLoading model...');
      embedder = await EmbedAnything.fromPretrainedHfAsync(
        modelId: 'sentence-transformers/all-MiniLM-L6-v2',
        dtype: ModelDtype.f32,
      );
      print('Model loaded successfully');

      recordMemory('after_model_load');
    });

    tearDownAll(() {
      recordMemory('before_dispose');
      embedder.dispose();
      recordMemory('after_dispose');

      // Print summary
      print('\n${'=' * 60}');
      print('MEMORY USAGE SUMMARY');
      print('${'=' * 60}');
      for (final snapshot in memorySnapshots) {
        print(
            '${snapshot['phase'].toString().padRight(30)} RSS: ${(snapshot['rss_mb'] as double).toStringAsFixed(1).padLeft(8)} MB');
      }
      print('${'=' * 60}\n');
    });

    test('embeds 3000 texts with memory tracking', () async {
      // Generate 3000 test texts with varying content
      print('\nGenerating 3000 test texts...');
      final texts = List.generate(3000, (i) {
        final categories = [
          'Machine learning is transforming how we process data and make predictions.',
          'Natural language processing enables computers to understand human text.',
          'Deep neural networks can learn complex patterns from large datasets.',
          'Vector embeddings capture semantic meaning in numerical form.',
          'Transformers revolutionized the field of language modeling.',
          'Attention mechanisms allow models to focus on relevant information.',
          'BERT models provide contextualized word representations.',
          'Sentence transformers create meaningful sentence embeddings.',
          'Semantic search finds documents by meaning, not just keywords.',
          'Clustering algorithms group similar embeddings together.',
        ];
        return '${categories[i % categories.length]} Sample text number $i with unique content.';
      });
      print('Generated ${texts.length} texts');

      recordMemory('before_embedding');

      // Track progress and memory during embedding
      var lastProgressReport = 0;
      final progressMemory = <Map<String, dynamic>>[];

      print('\nStarting batch embedding...');
      final stopwatch = Stopwatch()..start();

      final results = await embedder.embedTextsBatchAsync(
        texts,
        chunkSize: 32, // Process in chunks of 32
        onProgress: (completed, total) {
          // Record memory every 500 items
          if (completed - lastProgressReport >= 500 || completed == total) {
            final mem = getMemoryUsage();
            progressMemory.add({
              'completed': completed,
              'total': total,
              ...mem,
            });
            final elapsed = stopwatch.elapsedMilliseconds / 1000;
            final rate = completed / elapsed;
            print(
                '  Progress: $completed/$total (${(completed / total * 100).toStringAsFixed(1)}%) - '
                '${formatMemory(mem)} - ${rate.toStringAsFixed(1)} items/sec');
            lastProgressReport = completed;
          }
        },
      );

      stopwatch.stop();
      recordMemory('after_embedding');

      // Verify results
      print('\n--- Results ---');
      print('Total embeddings: ${results.length}');
      print('Embedding dimension: ${results.first.dimension}');
      print('Total time: ${(stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(2)} seconds');
      print(
          'Average rate: ${(results.length / (stopwatch.elapsedMilliseconds / 1000)).toStringAsFixed(1)} items/sec');

      // Memory analysis
      print('\n--- Memory Analysis ---');
      final beforeEmbed = memorySnapshots
          .firstWhere((s) => s['phase'] == 'before_embedding')['rss_mb'] as double;
      final afterEmbed = memorySnapshots
          .firstWhere((s) => s['phase'] == 'after_embedding')['rss_mb'] as double;
      final memoryIncrease = afterEmbed - beforeEmbed;
      print('Memory before embedding: ${beforeEmbed.toStringAsFixed(1)} MB');
      print('Memory after embedding: ${afterEmbed.toStringAsFixed(1)} MB');
      print('Memory increase: ${memoryIncrease.toStringAsFixed(1)} MB');

      if (progressMemory.isNotEmpty) {
        final peakDuringEmbed = progressMemory
            .map((m) => m['rss_mb'] as double)
            .reduce((a, b) => a > b ? a : b);
        print('Peak memory during embedding: ${peakDuringEmbed.toStringAsFixed(1)} MB');
      }

      // Assertions
      expect(results.length, equals(3000), reason: 'Should have 3000 embeddings');
      expect(results.first.dimension, equals(384),
          reason: 'BERT MiniLM-L6 should produce 384-dim vectors');

      // Memory sanity check - should not exceed 8GB for this operation
      final peakRss = memorySnapshots
          .map((s) => s['max_rss_mb'] as double)
          .reduce((a, b) => a > b ? a : b);
      expect(peakRss, lessThan(8000),
          reason: 'Peak memory should not exceed 8GB for 3000 embeddings');

      print('\nTest passed!');
    }, timeout: Timeout(Duration(minutes: 10)));

    test('memory returns to reasonable level after GC', () async {
      recordMemory('before_gc');

      // Force garbage collection (hint only in Dart)
      // In practice, Dart's GC runs automatically
      await Future.delayed(Duration(seconds: 2));

      recordMemory('after_gc_delay');

      final afterModel = memorySnapshots
          .firstWhere((s) => s['phase'] == 'after_model_load')['rss_mb'] as double;
      final afterGc = memorySnapshots
          .firstWhere((s) => s['phase'] == 'after_gc_delay')['rss_mb'] as double;

      print('Memory after model load: ${afterModel.toStringAsFixed(1)} MB');
      print('Memory after GC delay: ${afterGc.toStringAsFixed(1)} MB');

      // Memory should not be significantly higher than after model load
      // (allowing 500MB tolerance for embeddings that might be retained)
      expect(afterGc, lessThan(afterModel + 500),
          reason: 'Memory should return to near model-load level after processing');
    });
  });
}
