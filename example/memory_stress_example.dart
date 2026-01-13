/// Memory stress test example - embeds 3000 items and tracks memory.
///
/// Run with:
/// dart run --enable-experiment=native-assets example/memory_stress_example.dart
///
/// Monitor system resources in another terminal:
/// Linux: watch -n 1 'ps -o pid,rss,vsz,comm -p $(pgrep -f memory_stress)'
/// macOS: top -pid $(pgrep -f memory_stress)

import 'dart:io';

import 'package:embedanythingindart/embedanythingindart.dart';

/// Memory tracking utilities
class MemoryTracker {
  final List<MemorySnapshot> snapshots = [];
  final Stopwatch _stopwatch = Stopwatch();

  void start() => _stopwatch.start();

  void record(String phase) {
    final rss = ProcessInfo.currentRss;
    final maxRss = ProcessInfo.maxRss;
    final elapsed = _stopwatch.elapsedMilliseconds;

    snapshots.add(MemorySnapshot(
      phase: phase,
      rssMB: rss / (1024 * 1024),
      maxRssMB: maxRss / (1024 * 1024),
      elapsedMs: elapsed,
    ));

    print(_formatSnapshot(snapshots.last));
  }

  String _formatSnapshot(MemorySnapshot s) {
    final time = (s.elapsedMs / 1000).toStringAsFixed(1).padLeft(6);
    final rss = s.rssMB.toStringAsFixed(1).padLeft(8);
    final peak = s.maxRssMB.toStringAsFixed(1).padLeft(8);
    return '[${time}s] ${s.phase.padRight(25)} RSS: $rss MB  Peak: $peak MB';
  }

  void printSummary() {
    print('\n${'=' * 70}');
    print('MEMORY USAGE SUMMARY');
    print('${'=' * 70}');

    double? minRss, maxRss;
    for (final s in snapshots) {
      if (minRss == null || s.rssMB < minRss) minRss = s.rssMB;
      if (maxRss == null || s.rssMB > maxRss) maxRss = s.rssMB;
      print(_formatSnapshot(s));
    }

    print('${'=' * 70}');
    print('Min RSS: ${minRss?.toStringAsFixed(1)} MB');
    print('Max RSS: ${maxRss?.toStringAsFixed(1)} MB');
    print('Memory range: ${((maxRss ?? 0) - (minRss ?? 0)).toStringAsFixed(1)} MB');
    print('${'=' * 70}\n');
  }
}

class MemorySnapshot {
  final String phase;
  final double rssMB;
  final double maxRssMB;
  final int elapsedMs;

  MemorySnapshot({
    required this.phase,
    required this.rssMB,
    required this.maxRssMB,
    required this.elapsedMs,
  });
}

void main() async {
  print('\n${'=' * 70}');
  print('MEMORY STRESS TEST - 3000 EMBEDDINGS');
  print('${'=' * 70}');
  print('PID: $pid');
  print('Platform: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
  print('Dart: ${Platform.version}');
  print('${'=' * 70}\n');

  final tracker = MemoryTracker();
  tracker.start();
  tracker.record('startup');

  // ============================================================
  // STEP 1: Configure thread pool BEFORE any other operations
  // ============================================================
  print('\n--- Step 1: Configure Thread Pool ---');
  final threadCount = 4; // Adjust this to test different configurations
  final configured = EmbedAnything.configureThreadPool(threadCount);
  print('Configured thread pool to $threadCount threads: $configured');
  print('Actual thread pool size: ${EmbedAnything.getThreadPoolSize()}');
  tracker.record('thread_pool_configured');

  // ============================================================
  // STEP 2: Load model
  // ============================================================
  print('\n--- Step 2: Load Model ---');
  print('Loading BERT MiniLM-L6-v2...');

  final modelStopwatch = Stopwatch()..start();
  final embedder = await EmbedAnything.fromPretrainedHfAsync(
    modelId: 'sentence-transformers/all-MiniLM-L6-v2',
    dtype: ModelDtype.f32,
  );
  modelStopwatch.stop();

  print('Model loaded in ${(modelStopwatch.elapsedMilliseconds / 1000).toStringAsFixed(2)}s');
  print('Active device: ${EmbedAnything.getActiveDevice()}');
  tracker.record('model_loaded');

  // ============================================================
  // STEP 3: Generate test data
  // ============================================================
  print('\n--- Step 3: Generate Test Data ---');
  const totalTexts = 3000;
  const chunkSize = 32;

  final texts = List.generate(totalTexts, (i) {
    // Create diverse texts to simulate real-world usage
    final templates = [
      'Machine learning algorithms can identify patterns in complex datasets. Item $i.',
      'Natural language processing enables semantic understanding of text. Item $i.',
      'Deep learning models require substantial computational resources. Item $i.',
      'Vector embeddings represent semantic meaning numerically. Item $i.',
      'Transformer architectures have revolutionized NLP tasks. Item $i.',
      'Attention mechanisms help models focus on relevant features. Item $i.',
      'Pre-trained models transfer knowledge to downstream tasks. Item $i.',
      'Semantic search improves information retrieval accuracy. Item $i.',
      'Clustering groups similar data points together. Item $i.',
      'Dimensionality reduction simplifies high-dimensional data. Item $i.',
    ];
    return templates[i % templates.length];
  });

  print('Generated $totalTexts texts');
  print('Chunk size: $chunkSize');
  print('Expected chunks: ${(totalTexts / chunkSize).ceil()}');
  tracker.record('data_generated');

  // ============================================================
  // STEP 4: Run embedding with progress tracking
  // ============================================================
  print('\n--- Step 4: Embed 3000 Texts ---');
  print('Starting batch embedding...\n');

  final embedStopwatch = Stopwatch()..start();
  var lastMilestone = 0;

  final results = await embedder.embedTextsBatchAsync(
    texts,
    chunkSize: chunkSize,
    onProgress: (completed, total) {
      // Record at every 10% milestone
      final milestone = (completed / total * 10).floor();
      if (milestone > lastMilestone || completed == total) {
        final pct = (completed / total * 100).toStringAsFixed(0);
        tracker.record('embed_${pct}%');
        lastMilestone = milestone;
      }
    },
  );

  embedStopwatch.stop();
  tracker.record('embedding_complete');

  // ============================================================
  // STEP 5: Report results
  // ============================================================
  print('\n--- Step 5: Results ---');
  print('Total embeddings: ${results.length}');
  print('Embedding dimension: ${results.first.dimension}');
  print('Total time: ${(embedStopwatch.elapsedMilliseconds / 1000).toStringAsFixed(2)}s');
  print(
      'Throughput: ${(results.length / (embedStopwatch.elapsedMilliseconds / 1000)).toStringAsFixed(1)} items/sec');

  // Verify embeddings are valid
  print('\n--- Verification ---');
  var validCount = 0;
  for (final result in results) {
    if (result.dimension == 384 && result.values.isNotEmpty) {
      validCount++;
    }
  }
  print('Valid embeddings: $validCount / ${results.length}');

  // Sample similarity check
  final sim = results[0].cosineSimilarity(results[1]);
  print('Sample similarity (item 0 vs 1): ${sim.toStringAsFixed(4)}');

  // ============================================================
  // STEP 6: Cleanup
  // ============================================================
  print('\n--- Step 6: Cleanup ---');
  tracker.record('before_dispose');

  embedder.dispose();
  tracker.record('after_dispose');

  // Wait a moment for any deferred cleanup
  await Future.delayed(Duration(seconds: 2));
  tracker.record('final');

  // ============================================================
  // Summary
  // ============================================================
  tracker.printSummary();

  // Exit status
  if (validCount == totalTexts) {
    print('SUCCESS: All $totalTexts embeddings generated correctly.\n');
    exit(0);
  } else {
    print('FAILURE: Only $validCount of $totalTexts embeddings valid.\n');
    exit(1);
  }
}
