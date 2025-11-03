import 'dart:io';
import 'package:embedanythingindart/embedanythingindart.dart';

/// Comprehensive benchmark suite for EmbedAnythingInDart
///
/// This benchmark suite measures:
/// - Model loading performance (cold/warm start)
/// - Single embedding latency (various text lengths)
/// - Batch throughput (various batch sizes)
/// - Model comparison (BERT vs Jina, small vs large)
///
/// Usage:
///   dart run --enable-experiment=native-assets benchmark/benchmark.dart
///
/// Note: For cold start benchmarks, manually delete ~/.cache/huggingface/hub
///       before running to measure first-time model download and load.
void main() async {
  print('==================================================');
  print('EmbedAnythingInDart Benchmark Suite');
  print('==================================================');
  print('Platform: ${Platform.operatingSystem}');
  print('Dart Version: ${Platform.version}');
  print('CPU Count: ${Platform.numberOfProcessors}');
  print('Date: ${DateTime.now()}');
  print('==================================================\n');

  final results = BenchmarkResults();

  // Model Loading Benchmarks
  print('Running Model Loading Benchmarks...\n');
  await _runModelLoadingBenchmarks(results);

  // Single Embedding Latency Benchmarks
  print('\nRunning Single Embedding Latency Benchmarks...\n');
  await _runSingleLatencyBenchmarks(results);

  // Batch Throughput Benchmarks
  print('\nRunning Batch Throughput Benchmarks...\n');
  await _runBatchThroughputBenchmarks(results);

  // Model Comparison Benchmarks
  print('\nRunning Model Comparison Benchmarks...\n');
  await _runModelComparisonBenchmarks(results);

  // Generate results markdown
  print('\n==================================================');
  print('Generating results.md...');
  await _generateResultsMarkdown(results);
  print('Benchmark complete! Results saved to benchmark/results.md');
  print('==================================================\n');
}

/// Run model loading benchmarks (warm start only)
Future<void> _runModelLoadingBenchmarks(BenchmarkResults results) async {
  // BERT all-MiniLM-L6-v2 warm start
  final bertWarmTimes = <Duration>[];
  for (var i = 0; i < 5; i++) {
    final stopwatch = Stopwatch()..start();
    final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());
    // Generate one embedding to ensure model is fully loaded
    embedder.embedText('test');
    stopwatch.stop();
    embedder.dispose();
    bertWarmTimes.add(stopwatch.elapsed);
    print('BERT MiniLM-L6 warm start #${i + 1}: ${stopwatch.elapsedMilliseconds}ms');
  }
  results.bertWarmStartMs = _calculateStats(bertWarmTimes);

  // Jina v2-base warm start
  final jinaWarmTimes = <Duration>[];
  for (var i = 0; i < 5; i++) {
    final stopwatch = Stopwatch()..start();
    final embedder = EmbedAnything.fromConfig(ModelConfig.jinaV2Base());
    // Generate one embedding to ensure model is fully loaded
    embedder.embedText('test');
    stopwatch.stop();
    embedder.dispose();
    jinaWarmTimes.add(stopwatch.elapsed);
    print('Jina v2-base warm start #${i + 1}: ${stopwatch.elapsedMilliseconds}ms');
  }
  results.jinaWarmStartMs = _calculateStats(jinaWarmTimes);

  print('\nCold start benchmarks require manual cache deletion.');
  print('Run: rm -rf ~/.cache/huggingface/hub');
  print('Then re-run this benchmark for cold start measurements.\n');
}

/// Run single embedding latency benchmarks
Future<void> _runSingleLatencyBenchmarks(BenchmarkResults results) async {
  // Create test texts of various lengths
  final shortText = 'The quick brown fox jumps over the lazy dog.'; // ~10 words
  final mediumText = _generateText(100); // ~100 words
  final longText = _generateText(500); // ~500 words
  final veryLongText = _generateText(2000); // ~2000 words

  // BERT benchmarks
  print('Benchmarking BERT all-MiniLM-L6-v2...');
  final bertEmbedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());

  results.bertShortLatencyMs = _benchmarkLatency(bertEmbedder, shortText, 100);
  print('  Short text (10 words): ${_formatStats(results.bertShortLatencyMs)}');

  results.bertMediumLatencyMs = _benchmarkLatency(bertEmbedder, mediumText, 100);
  print('  Medium text (100 words): ${_formatStats(results.bertMediumLatencyMs)}');

  results.bertLongLatencyMs = _benchmarkLatency(bertEmbedder, longText, 100);
  print('  Long text (500 words): ${_formatStats(results.bertLongLatencyMs)}');

  results.bertVeryLongLatencyMs = _benchmarkLatency(bertEmbedder, veryLongText, 100);
  print('  Very long text (2000 words): ${_formatStats(results.bertVeryLongLatencyMs)}');

  bertEmbedder.dispose();

  // Jina benchmarks
  print('\nBenchmarking Jina v2-base...');
  final jinaEmbedder = EmbedAnything.fromConfig(ModelConfig.jinaV2Base());

  results.jinaShortLatencyMs = _benchmarkLatency(jinaEmbedder, shortText, 100);
  print('  Short text (10 words): ${_formatStats(results.jinaShortLatencyMs)}');

  results.jinaMediumLatencyMs = _benchmarkLatency(jinaEmbedder, mediumText, 100);
  print('  Medium text (100 words): ${_formatStats(results.jinaMediumLatencyMs)}');

  results.jinaLongLatencyMs = _benchmarkLatency(jinaEmbedder, longText, 100);
  print('  Long text (500 words): ${_formatStats(results.jinaLongLatencyMs)}');

  results.jinaVeryLongLatencyMs = _benchmarkLatency(jinaEmbedder, veryLongText, 100);
  print('  Very long text (2000 words): ${_formatStats(results.jinaVeryLongLatencyMs)}');

  jinaEmbedder.dispose();
}

/// Run batch throughput benchmarks
Future<void> _runBatchThroughputBenchmarks(BenchmarkResults results) async {
  final testTexts10 = List.generate(10, (i) => 'Test text number $i');
  final testTexts100 = List.generate(100, (i) => 'Test text number $i');
  final testTexts1000 = List.generate(1000, (i) => 'Test text number $i');

  // BERT benchmarks
  print('Benchmarking BERT all-MiniLM-L6-v2 batch processing...');
  final bertEmbedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());

  results.bertBatch10 = _benchmarkBatch(bertEmbedder, testTexts10);
  print('  Batch size 10: ${results.bertBatch10.throughput.toStringAsFixed(2)} items/sec');

  results.bertBatch100 = _benchmarkBatch(bertEmbedder, testTexts100);
  print('  Batch size 100: ${results.bertBatch100.throughput.toStringAsFixed(2)} items/sec');

  results.bertBatch1000 = _benchmarkBatch(bertEmbedder, testTexts1000);
  print('  Batch size 1000: ${results.bertBatch1000.throughput.toStringAsFixed(2)} items/sec');

  // Sequential benchmark for comparison
  final bertSeqTime = _benchmarkSequential(bertEmbedder, testTexts100);
  results.bertBatch100.speedup = bertSeqTime / results.bertBatch100.totalMs;
  print('  Batch vs Sequential (100 items): ${results.bertBatch100.speedup.toStringAsFixed(2)}x speedup');

  bertEmbedder.dispose();

  // Jina benchmarks
  print('\nBenchmarking Jina v2-base batch processing...');
  final jinaEmbedder = EmbedAnything.fromConfig(ModelConfig.jinaV2Base());

  results.jinaBatch10 = _benchmarkBatch(jinaEmbedder, testTexts10);
  print('  Batch size 10: ${results.jinaBatch10.throughput.toStringAsFixed(2)} items/sec');

  results.jinaBatch100 = _benchmarkBatch(jinaEmbedder, testTexts100);
  print('  Batch size 100: ${results.jinaBatch100.throughput.toStringAsFixed(2)} items/sec');

  results.jinaBatch1000 = _benchmarkBatch(jinaEmbedder, testTexts1000);
  print('  Batch size 1000: ${results.jinaBatch1000.throughput.toStringAsFixed(2)} items/sec');

  // Sequential benchmark for comparison
  final jinaSeqTime = _benchmarkSequential(jinaEmbedder, testTexts100);
  results.jinaBatch100.speedup = jinaSeqTime / results.jinaBatch100.totalMs;
  print('  Batch vs Sequential (100 items): ${results.jinaBatch100.speedup.toStringAsFixed(2)}x speedup');

  jinaEmbedder.dispose();
}

/// Run model comparison benchmarks
Future<void> _runModelComparisonBenchmarks(BenchmarkResults results) async {
  final testText = _generateText(50); // 50 words

  print('Comparing BERT models (all-MiniLM-L6-v2 vs all-MiniLM-L12-v2)...');

  // BERT L6 (already benchmarked, use existing data)
  final bertL6Embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());
  final bertL6Stats = _benchmarkLatency(bertL6Embedder, testText, 50);
  print('  BERT all-MiniLM-L6-v2 (6 layers): ${_formatStats(bertL6Stats)}');
  bertL6Embedder.dispose();

  // BERT L12
  final bertL12Embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML12());
  final bertL12Stats = _benchmarkLatency(bertL12Embedder, testText, 50);
  print('  BERT all-MiniLM-L12-v2 (12 layers): ${_formatStats(bertL12Stats)}');
  print('  Speed difference: ${(bertL12Stats.mean / bertL6Stats.mean).toStringAsFixed(2)}x slower (higher quality)');
  bertL12Embedder.dispose();

  print('\nComparing Jina models (jina-embeddings-v2-small-en vs v2-base-en)...');

  // Jina Small
  final jinaSmallEmbedder = EmbedAnything.fromConfig(ModelConfig.jinaV2Small());
  final jinaSmallStats = _benchmarkLatency(jinaSmallEmbedder, testText, 50);
  print('  Jina v2-small-en (512 dim): ${_formatStats(jinaSmallStats)}');
  jinaSmallEmbedder.dispose();

  // Jina Base (already benchmarked, use existing data)
  final jinaBaseEmbedder = EmbedAnything.fromConfig(ModelConfig.jinaV2Base());
  final jinaBaseStats = _benchmarkLatency(jinaBaseEmbedder, testText, 50);
  print('  Jina v2-base-en (768 dim): ${_formatStats(jinaBaseStats)}');
  print('  Speed difference: ${(jinaBaseStats.mean / jinaSmallStats.mean).toStringAsFixed(2)}x slower (higher quality)');
  jinaBaseEmbedder.dispose();

  // Store comparison results
  results.comparison = ModelComparison(
    bertL6Mean: bertL6Stats.mean,
    bertL12Mean: bertL12Stats.mean,
    jinaSmallMean: jinaSmallStats.mean,
    jinaBaseMean: jinaBaseStats.mean,
  );
}

/// Benchmark embedding latency for a single text
LatencyStats _benchmarkLatency(EmbedAnything embedder, String text, int iterations) {
  final times = <double>[];

  // Warmup
  for (var i = 0; i < 10; i++) {
    embedder.embedText(text);
  }

  // Actual benchmark
  for (var i = 0; i < iterations; i++) {
    final stopwatch = Stopwatch()..start();
    embedder.embedText(text);
    stopwatch.stop();
    times.add(stopwatch.elapsedMicroseconds / 1000.0); // Convert to ms
  }

  return _calculateStatsFromMs(times);
}

/// Benchmark batch processing throughput
BatchStats _benchmarkBatch(EmbedAnything embedder, List<String> texts) {
  // Warmup
  embedder.embedTextsBatch(texts);

  // Benchmark
  final stopwatch = Stopwatch()..start();
  embedder.embedTextsBatch(texts);
  stopwatch.stop();

  final totalMs = stopwatch.elapsedMilliseconds.toDouble();
  final throughput = texts.length / (totalMs / 1000.0); // items per second

  return BatchStats(
    batchSize: texts.length,
    totalMs: totalMs,
    throughput: throughput,
  );
}

/// Benchmark sequential processing for comparison
double _benchmarkSequential(EmbedAnything embedder, List<String> texts) {
  final stopwatch = Stopwatch()..start();
  for (final text in texts) {
    embedder.embedText(text);
  }
  stopwatch.stop();
  return stopwatch.elapsedMilliseconds.toDouble();
}

/// Generate text of approximately N words
String _generateText(int words) {
  final base = 'Lorem ipsum dolor sit amet consectetur adipiscing elit sed do eiusmod tempor incididunt ut labore et dolore magna aliqua';
  final baseWords = base.split(' ');
  final result = <String>[];

  for (var i = 0; i < words; i++) {
    result.add(baseWords[i % baseWords.length]);
  }

  return result.join(' ');
}

/// Calculate statistics from a list of durations
LatencyStats _calculateStats(List<Duration> times) {
  final ms = times.map((d) => d.inMicroseconds / 1000.0).toList();
  return _calculateStatsFromMs(ms);
}

/// Calculate statistics from a list of millisecond values
LatencyStats _calculateStatsFromMs(List<double> ms) {
  ms.sort();

  final mean = ms.reduce((a, b) => a + b) / ms.length;
  final p50 = ms[ms.length ~/ 2];
  final p95 = ms[(ms.length * 0.95).floor()];
  final p99 = ms[(ms.length * 0.99).floor()];

  return LatencyStats(mean: mean, p50: p50, p95: p95, p99: p99);
}

/// Format statistics for display
String _formatStats(LatencyStats stats) {
  return 'mean=${stats.mean.toStringAsFixed(2)}ms, '
         'p50=${stats.p50.toStringAsFixed(2)}ms, '
         'p95=${stats.p95.toStringAsFixed(2)}ms, '
         'p99=${stats.p99.toStringAsFixed(2)}ms';
}

/// Generate results.md file with all benchmark results
Future<void> _generateResultsMarkdown(BenchmarkResults results) async {
  final buffer = StringBuffer();

  buffer.writeln('# EmbedAnythingInDart Benchmark Results\n');
  buffer.writeln('**Generated:** ${DateTime.now()}\n');
  buffer.writeln('**Platform:** ${Platform.operatingSystem}\n');
  buffer.writeln('**Dart Version:** ${Platform.version}\n');
  buffer.writeln('**CPU Count:** ${Platform.numberOfProcessors}\n');
  buffer.writeln('---\n');

  // Model Loading
  buffer.writeln('## Model Loading Performance\n');
  buffer.writeln('### Warm Start (Cached Model)\n');
  buffer.writeln('| Model | Mean | P50 | P95 | P99 |');
  buffer.writeln('|-------|------|-----|-----|-----|');
  buffer.writeln('| BERT all-MiniLM-L6-v2 | ${results.bertWarmStartMs.mean.toStringAsFixed(2)}ms | ${results.bertWarmStartMs.p50.toStringAsFixed(2)}ms | ${results.bertWarmStartMs.p95.toStringAsFixed(2)}ms | ${results.bertWarmStartMs.p99.toStringAsFixed(2)}ms |');
  buffer.writeln('| Jina v2-base-en | ${results.jinaWarmStartMs.mean.toStringAsFixed(2)}ms | ${results.jinaWarmStartMs.p50.toStringAsFixed(2)}ms | ${results.jinaWarmStartMs.p95.toStringAsFixed(2)}ms | ${results.jinaWarmStartMs.p99.toStringAsFixed(2)}ms |\n');
  buffer.writeln('**Note:** Cold start includes model download (100-500MB) and is not benchmarked automatically. To test cold start, delete `~/.cache/huggingface/hub` and re-run.\n');

  // Single Embedding Latency
  buffer.writeln('## Single Embedding Latency\n');
  buffer.writeln('### BERT all-MiniLM-L6-v2\n');
  buffer.writeln('| Text Length | Mean | P50 | P95 | P99 |');
  buffer.writeln('|------------|------|-----|-----|-----|');
  buffer.writeln('| Short (10 words) | ${results.bertShortLatencyMs.mean.toStringAsFixed(2)}ms | ${results.bertShortLatencyMs.p50.toStringAsFixed(2)}ms | ${results.bertShortLatencyMs.p95.toStringAsFixed(2)}ms | ${results.bertShortLatencyMs.p99.toStringAsFixed(2)}ms |');
  buffer.writeln('| Medium (100 words) | ${results.bertMediumLatencyMs.mean.toStringAsFixed(2)}ms | ${results.bertMediumLatencyMs.p50.toStringAsFixed(2)}ms | ${results.bertMediumLatencyMs.p95.toStringAsFixed(2)}ms | ${results.bertMediumLatencyMs.p99.toStringAsFixed(2)}ms |');
  buffer.writeln('| Long (500 words) | ${results.bertLongLatencyMs.mean.toStringAsFixed(2)}ms | ${results.bertLongLatencyMs.p50.toStringAsFixed(2)}ms | ${results.bertLongLatencyMs.p95.toStringAsFixed(2)}ms | ${results.bertLongLatencyMs.p99.toStringAsFixed(2)}ms |');
  buffer.writeln('| Very Long (2000 words) | ${results.bertVeryLongLatencyMs.mean.toStringAsFixed(2)}ms | ${results.bertVeryLongLatencyMs.p50.toStringAsFixed(2)}ms | ${results.bertVeryLongLatencyMs.p95.toStringAsFixed(2)}ms | ${results.bertVeryLongLatencyMs.p99.toStringAsFixed(2)}ms |\n');

  buffer.writeln('### Jina v2-base-en\n');
  buffer.writeln('| Text Length | Mean | P50 | P95 | P99 |');
  buffer.writeln('|------------|------|-----|-----|-----|');
  buffer.writeln('| Short (10 words) | ${results.jinaShortLatencyMs.mean.toStringAsFixed(2)}ms | ${results.jinaShortLatencyMs.p50.toStringAsFixed(2)}ms | ${results.jinaShortLatencyMs.p95.toStringAsFixed(2)}ms | ${results.jinaShortLatencyMs.p99.toStringAsFixed(2)}ms |');
  buffer.writeln('| Medium (100 words) | ${results.jinaMediumLatencyMs.mean.toStringAsFixed(2)}ms | ${results.jinaMediumLatencyMs.p50.toStringAsFixed(2)}ms | ${results.jinaMediumLatencyMs.p95.toStringAsFixed(2)}ms | ${results.jinaMediumLatencyMs.p99.toStringAsFixed(2)}ms |');
  buffer.writeln('| Long (500 words) | ${results.jinaLongLatencyMs.mean.toStringAsFixed(2)}ms | ${results.jinaLongLatencyMs.p50.toStringAsFixed(2)}ms | ${results.jinaLongLatencyMs.p95.toStringAsFixed(2)}ms | ${results.jinaLongLatencyMs.p99.toStringAsFixed(2)}ms |');
  buffer.writeln('| Very Long (2000 words) | ${results.jinaVeryLongLatencyMs.mean.toStringAsFixed(2)}ms | ${results.jinaVeryLongLatencyMs.p50.toStringAsFixed(2)}ms | ${results.jinaVeryLongLatencyMs.p95.toStringAsFixed(2)}ms | ${results.jinaVeryLongLatencyMs.p99.toStringAsFixed(2)}ms |\n');

  // Batch Throughput
  buffer.writeln('## Batch Throughput\n');
  buffer.writeln('### BERT all-MiniLM-L6-v2\n');
  buffer.writeln('| Batch Size | Total Time | Throughput | Speedup vs Sequential |');
  buffer.writeln('|-----------|------------|------------|----------------------|');
  buffer.writeln('| 10 items | ${results.bertBatch10.totalMs.toStringAsFixed(2)}ms | ${results.bertBatch10.throughput.toStringAsFixed(2)} items/sec | - |');
  buffer.writeln('| 100 items | ${results.bertBatch100.totalMs.toStringAsFixed(2)}ms | ${results.bertBatch100.throughput.toStringAsFixed(2)} items/sec | ${results.bertBatch100.speedup.toStringAsFixed(2)}x |');
  buffer.writeln('| 1000 items | ${results.bertBatch1000.totalMs.toStringAsFixed(2)}ms | ${results.bertBatch1000.throughput.toStringAsFixed(2)} items/sec | - |\n');

  buffer.writeln('### Jina v2-base-en\n');
  buffer.writeln('| Batch Size | Total Time | Throughput | Speedup vs Sequential |');
  buffer.writeln('|-----------|------------|------------|----------------------|');
  buffer.writeln('| 10 items | ${results.jinaBatch10.totalMs.toStringAsFixed(2)}ms | ${results.jinaBatch10.throughput.toStringAsFixed(2)} items/sec | - |');
  buffer.writeln('| 100 items | ${results.jinaBatch100.totalMs.toStringAsFixed(2)}ms | ${results.jinaBatch100.throughput.toStringAsFixed(2)} items/sec | ${results.jinaBatch100.speedup.toStringAsFixed(2)}x |');
  buffer.writeln('| 1000 items | ${results.jinaBatch1000.totalMs.toStringAsFixed(2)}ms | ${results.jinaBatch1000.throughput.toStringAsFixed(2)} items/sec | - |\n');

  // Model Comparison
  buffer.writeln('## Model Comparison\n');
  buffer.writeln('### BERT Models (50-word text)\n');
  buffer.writeln('| Model | Mean Latency | Relative Speed | Dimensions | Use Case |');
  buffer.writeln('|-------|-------------|----------------|------------|----------|');
  buffer.writeln('| all-MiniLM-L6-v2 | ${results.comparison.bertL6Mean.toStringAsFixed(2)}ms | 1.0x (baseline) | 384 | Fast, general-purpose |');
  buffer.writeln('| all-MiniLM-L12-v2 | ${results.comparison.bertL12Mean.toStringAsFixed(2)}ms | ${(results.comparison.bertL12Mean / results.comparison.bertL6Mean).toStringAsFixed(2)}x slower | 384 | Better quality, slower |\n');

  buffer.writeln('### Jina Models (50-word text)\n');
  buffer.writeln('| Model | Mean Latency | Relative Speed | Dimensions | Use Case |');
  buffer.writeln('|-------|-------------|----------------|------------|----------|');
  buffer.writeln('| jina-v2-small-en | ${results.comparison.jinaSmallMean.toStringAsFixed(2)}ms | 1.0x (baseline) | 512 | Fast, good quality |');
  buffer.writeln('| jina-v2-base-en | ${results.comparison.jinaBaseMean.toStringAsFixed(2)}ms | ${(results.comparison.jinaBaseMean / results.comparison.jinaSmallMean).toStringAsFixed(2)}x slower | 768 | Best quality, slower |\n');

  // Recommendations
  buffer.writeln('## Recommendations\n');
  buffer.writeln('### Batch Size');
  buffer.writeln('- **Small batches (<10 items):** Use single embedding calls or small batches');
  buffer.writeln('- **Medium batches (10-100 items):** Batch processing provides ${results.bertBatch100.speedup.toStringAsFixed(1)}x speedup');
  buffer.writeln('- **Large batches (>100 items):** Maximum throughput, but memory usage scales linearly\n');

  buffer.writeln('### Model Selection');
  buffer.writeln('- **BERT all-MiniLM-L6-v2:** Best for fast, general-purpose embeddings with good quality');
  buffer.writeln('- **BERT all-MiniLM-L12-v2:** Use when quality is more important than speed');
  buffer.writeln('- **Jina v2-small-en:** Fast semantic search with higher quality than BERT');
  buffer.writeln('- **Jina v2-base-en:** Best quality for semantic search and retrieval tasks\n');

  buffer.writeln('### Performance vs Quality Trade-offs');
  buffer.writeln('- Moving from L6 to L12 BERT models: ~${((results.comparison.bertL12Mean / results.comparison.bertL6Mean - 1) * 100).toStringAsFixed(0)}% slower, higher quality');
  buffer.writeln('- Moving from Jina small to base: ~${((results.comparison.jinaBaseMean / results.comparison.jinaSmallMean - 1) * 100).toStringAsFixed(0)}% slower, best quality');
  buffer.writeln('- For most applications, the speed difference is negligible (<10ms)\n');

  buffer.writeln('---');
  buffer.writeln('*Benchmarks measure Dart API overhead + Rust processing time. Actual performance depends on hardware.*');

  // Write to file
  final file = File('benchmark/results.md');
  await file.writeAsString(buffer.toString());
}

/// Container for all benchmark results
class BenchmarkResults {
  late LatencyStats bertWarmStartMs;
  late LatencyStats jinaWarmStartMs;

  late LatencyStats bertShortLatencyMs;
  late LatencyStats bertMediumLatencyMs;
  late LatencyStats bertLongLatencyMs;
  late LatencyStats bertVeryLongLatencyMs;

  late LatencyStats jinaShortLatencyMs;
  late LatencyStats jinaMediumLatencyMs;
  late LatencyStats jinaLongLatencyMs;
  late LatencyStats jinaVeryLongLatencyMs;

  late BatchStats bertBatch10;
  late BatchStats bertBatch100;
  late BatchStats bertBatch1000;

  late BatchStats jinaBatch10;
  late BatchStats jinaBatch100;
  late BatchStats jinaBatch1000;

  late ModelComparison comparison;
}

/// Latency statistics
class LatencyStats {
  final double mean;
  final double p50;
  final double p95;
  final double p99;

  LatencyStats({
    required this.mean,
    required this.p50,
    required this.p95,
    required this.p99,
  });
}

/// Batch processing statistics
class BatchStats {
  final int batchSize;
  final double totalMs;
  final double throughput;
  double speedup = 1.0;

  BatchStats({
    required this.batchSize,
    required this.totalMs,
    required this.throughput,
  });
}

/// Model comparison results
class ModelComparison {
  final double bertL6Mean;
  final double bertL12Mean;
  final double jinaSmallMean;
  final double jinaBaseMean;

  ModelComparison({
    required this.bertL6Mean,
    required this.bertL12Mean,
    required this.jinaSmallMean,
    required this.jinaBaseMean,
  });
}
