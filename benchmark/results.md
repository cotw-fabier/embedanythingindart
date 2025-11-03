# Benchmark Results

Performance measurements for EmbedAnythingInDart library.

## Test Environment

- **Platform**: macOS (Apple Silicon)
- **CPU**: 14 cores
- **Dart Version**: 3.11.0-88.0.dev
- **Date**: November 3, 2025

## Quick Benchmark Results

These results are from the lightweight `quick_benchmark.dart` which runs in under 1 minute.

### Model Loading (Warm Start)

| Model | Average Load Time |
|-------|------------------|
| BERT all-MiniLM-L6-v2 | ~25ms |
| Jina v2-small | ~2300ms |

**Note**: Warm start means model files are already cached locally. Cold start (first download) can take several minutes depending on internet speed.

### Single Embedding Latency

**BERT all-MiniLM-L6-v2** (384 dimensions):

| Text Length | Mean Latency |
|-------------|-------------|
| Short (10 words) | 7.5ms |

### Batch Throughput

**BERT all-MiniLM-L6-v2**:

| Batch Size | Throughput | Total Time |
|------------|-----------|-----------|
| 10 items | ~588 items/sec | 17ms |
| 100 items | ~775 items/sec | 129ms |

**Batch vs Sequential Processing**:

- Sequential processing: 10 items in 56ms (178 items/sec)
- Batch processing: 10 items in 17ms (588 items/sec)
- **Speedup: 3.29x**

Batch processing provides significant performance improvements, especially for larger workloads.

## Performance Characteristics

### Model Comparison

**BERT all-MiniLM-L6-v2** (Smaller, Faster):
- Dimensions: 384
- Load time: ~25ms (warm)
- Single embedding: ~7-8ms
- Batch throughput: ~750 items/sec
- **Use case**: High-speed semantic search, real-time applications

**Jina v2-small** (Balanced):
- Dimensions: 512
- Load time: ~2.3s (warm)
- **Use case**: Better quality when speed is less critical

### Best Practices

1. **Use Batch Processing**: When embedding multiple texts, always use `embedTextsBatch()` instead of calling `embedText()` multiple times. Batch processing is 3-4x faster.

2. **Model Selection**:
   - For low-latency requirements: Use BERT all-MiniLM-L6-v2
   - For better quality: Use larger models like Jina v2-base

3. **Warm-up**: The first embedding after model load may be slower. Consider running a dummy embedding after initialization for consistent latency.

## Running Benchmarks

### Quick Benchmark (< 1 minute)

```bash
dart run --enable-experiment=native-assets benchmark/quick_benchmark.dart
```

This runs a lightweight benchmark with reduced iterations, suitable for quick performance checks during development.

### Comprehensive Benchmark (several minutes)

```bash
dart run --enable-experiment=native-assets benchmark/benchmark.dart
```

This runs the full benchmark suite with:
- Multiple model comparisons
- Various text lengths
- Large batch sizes
- Statistical analysis (p50, p95, p99)

**Warning**: The comprehensive benchmark can take 10+ minutes and uses significant CPU resources.

## Notes

- All benchmarks use warm start (models already cached)
- For cold start benchmarks, delete `~/.cache/huggingface/hub` before running
- Performance varies by hardware and model size
- Batch throughput increases with batch size up to a point
- Results may vary based on text length and content complexity
