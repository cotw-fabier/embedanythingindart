# Getting Started with EmbedAnythingInDart

Welcome to EmbedAnythingInDart! This guide will help you install the library and create your first text embeddings in just a few minutes.

## What is EmbedAnythingInDart?

EmbedAnythingInDart is a high-performance Dart wrapper for the Rust-based [EmbedAnything](https://github.com/StarlightSearch/EmbedAnything) library. It allows you to generate vector embeddings for text using state-of-the-art models from HuggingFace Hub. These embeddings enable powerful semantic search, similarity matching, and other natural language processing tasks.

**Key Features:**
- **Fast**: Rust-powered performance with native FFI bindings
- **Easy**: Idiomatic Dart API with automatic memory management
- **Powerful**: Support for popular BERT and Jina models from HuggingFace
- **Efficient**: Batch processing for 5-10x speedup over sequential operations
- **Cross-platform**: Works on macOS, Linux, and Windows

## Prerequisites

Before you begin, ensure you have the following installed:

### Required Software

1. **Dart SDK 3.11.0 or later**
   ```bash
   # Check your Dart version
   dart --version

   # Should show: Dart SDK version: 3.11.0 or higher
   ```

   If you need to install or upgrade Dart, visit [dart.dev](https://dart.dev/get-dart).

2. **Rust Toolchain 1.90.0 or later**
   ```bash
   # Check if Rust is installed
   rustc --version

   # Install Rust if needed
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
   ```

   After installation, restart your terminal and verify: `rustc --version`

3. **Platform-Specific Build Tools**

   **macOS:**
   ```bash
   # Install Xcode Command Line Tools
   xcode-select --install
   ```

   **Linux (Debian/Ubuntu):**
   ```bash
   sudo apt update
   sudo apt install build-essential pkg-config
   ```

   **Linux (Fedora/RHEL):**
   ```bash
   sudo dnf install gcc pkg-config
   ```

   **Windows:**
   - Install Visual Studio 2019 or later with "Desktop development with C++"
   - Or install [Visual Studio Build Tools](https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2022)

### Internet Connection

You'll need an internet connection for:
- Initial library setup (downloading dependencies)
- First model load (downloading from HuggingFace Hub, 100-500MB depending on model)
- After the first download, models are cached locally and work offline

## Installation

### Step 1: Add Dependency

Add EmbedAnythingInDart to your `pubspec.yaml`:

```yaml
dependencies:
  embedanythingindart:
    git:
      url: https://github.com/yourusername/embedanythingindart.git
      ref: main
```

> **Note:** Replace `yourusername` with the actual repository owner once published.

### Step 2: Install Dependencies

Run the following command in your project directory:

```bash
dart pub get
```

This will download the Dart package and prepare the native assets build system.

### Step 3: First Build (Be Patient!)

The first time you run your application, the Rust code will compile. This process compiles 488 Rust crates and can take **5-15 minutes** depending on your hardware.

```bash
# Enable native assets and run your app
dart run --enable-experiment=native-assets your_app.dart
```

> **Important:** Subsequent builds are incremental and much faster (typically under 30 seconds). This initial wait only happens once.

## Your First Embedding

Let's create a simple program that generates text embeddings and computes semantic similarity.

### Hello World Example

Create a file called `hello_embed.dart`:

```dart
import 'package:embedanythingindart/embedanythingindart.dart';

void main() {
  print('Loading BERT model...');

  // Load a pre-trained model from HuggingFace
  // First load will download the model (~90MB)
  final embedder = EmbedAnything.fromPretrainedHf(
    model: EmbeddingModel.bert,
    modelId: 'sentence-transformers/all-MiniLM-L6-v2',
  );

  print('Model loaded successfully!\n');

  // Generate embeddings for text
  final text = 'Hello, world!';
  final result = embedder.embedText(text);

  print('Text: "$text"');
  print('Embedding dimension: ${result.dimension}');
  print('First 10 values: ${result.values.take(10).toList()}');

  // Clean up resources
  embedder.dispose();
  print('\nDone!');
}
```

### Run Your First Example

```bash
dart run --enable-experiment=native-assets hello_embed.dart
```

**Expected Output:**

```
Loading BERT model...
Model loaded successfully!

Text: "Hello, world!"
Embedding dimension: 384
First 10 values: [0.0234, -0.1456, 0.0891, 0.2134, -0.0567, 0.1823, -0.0912, 0.0456, 0.1289, -0.0734]

Done!
```

> **First Run:** The first execution will take longer as it downloads the model from HuggingFace Hub. The model is cached locally in `~/.cache/huggingface/hub`, so subsequent runs load in under 100ms.

## Computing Semantic Similarity

Now let's explore a more practical example that demonstrates semantic similarity:

```dart
import 'package:embedanythingindart/embedanythingindart.dart';

void main() {
  // Load model
  final embedder = EmbedAnything.fromPretrainedHf(
    model: EmbeddingModel.bert,
    modelId: 'sentence-transformers/all-MiniLM-L6-v2',
  );

  // Create embeddings for related texts
  final text1 = 'I love programming in Dart';
  final text2 = 'Dart is my favorite programming language';
  final text3 = 'I enjoy cooking delicious meals';

  final emb1 = embedder.embedText(text1);
  final emb2 = embedder.embedText(text2);
  final emb3 = embedder.embedText(text3);

  // Compute semantic similarity
  final similarity12 = emb1.cosineSimilarity(emb2);
  final similarity13 = emb1.cosineSimilarity(emb3);

  print('Comparing texts:\n');
  print('Text 1: "$text1"');
  print('Text 2: "$text2"');
  print('Similarity: ${similarity12.toStringAsFixed(4)} (highly related)\n');

  print('Text 1: "$text1"');
  print('Text 3: "$text3"');
  print('Similarity: ${similarity13.toStringAsFixed(4)} (unrelated)\n');

  // Clean up
  embedder.dispose();
}
```

**Expected Output:**

```
Comparing texts:

Text 1: "I love programming in Dart"
Text 2: "Dart is my favorite programming language"
Similarity: 0.7845 (highly related)

Text 1: "I love programming in Dart"
Text 3: "I enjoy cooking delicious meals"
Similarity: 0.1923 (unrelated)
```

**Understanding Similarity Scores:**
- **0.9-1.0**: Nearly identical meaning
- **0.7-0.9**: Highly related (same topic)
- **0.5-0.7**: Moderately related
- **0.3-0.5**: Somewhat related
- **0.0-0.3**: Weakly related or unrelated

## Batch Processing for Performance

When processing multiple texts, use batch methods for significantly better performance:

```dart
import 'package:embedanythingindart/embedanythingindart.dart';

void main() {
  final embedder = EmbedAnything.fromPretrainedHf(
    model: EmbeddingModel.bert,
    modelId: 'sentence-transformers/all-MiniLM-L6-v2',
  );

  // Prepare multiple texts
  final texts = [
    'Machine learning is transforming technology',
    'Artificial intelligence powers modern applications',
    'Deep learning uses neural networks',
    'Natural language processing enables text understanding',
    'Computer vision recognizes images and patterns',
  ];

  print('Processing ${texts.length} texts...\n');

  // Process all at once (5-10x faster than individual calls)
  final embeddings = embedder.embedTextsBatch(texts);

  // Display results
  for (var i = 0; i < texts.length; i++) {
    print('[$i] "${texts[i]}"');
    print('    Dimension: ${embeddings[i].dimension}');
  }

  print('\n✓ Batch processing complete!');

  embedder.dispose();
}
```

**Performance Benefit:** Batch processing is **5-10x faster** than processing texts individually. For 100 texts, batch processing takes ~170ms while individual calls take ~850ms.

## Error Handling

It's important to handle errors gracefully when loading models or generating embeddings:

```dart
import 'package:embedanythingindart/embedanythingindart.dart';

void main() {
  try {
    // Attempt to load an invalid model
    final embedder = EmbedAnything.fromPretrainedHf(
      model: EmbeddingModel.bert,
      modelId: 'invalid/model/path',
    );
    embedder.dispose();
  } on EmbedAnythingError catch (e) {
    print('Error loading model: ${e.message}');

    // Handle specific error types
    switch (e) {
      case ModelNotFoundError():
        print('Action: Check model ID on HuggingFace Hub');
      case InvalidConfigError():
        print('Action: Review configuration parameters');
      case FFIError():
        print('Action: Check native library installation');
      default:
        print('Action: See documentation for troubleshooting');
    }
  }
}
```

**Common Errors:**
- `ModelNotFoundError`: The model ID doesn't exist on HuggingFace Hub
- `InvalidConfigError`: Configuration parameters are invalid
- `EmbeddingFailedError`: Text embedding operation failed
- `FFIError`: Problem with native library communication

## What You Can Do

With EmbedAnythingInDart, you can:

### Text Embedding
- **Single text**: Generate embeddings for individual strings
- **Batch processing**: Efficiently embed multiple texts at once
- **Any length**: Handles short phrases to long documents (auto-truncated at 512 tokens)

### Semantic Operations
- **Similarity search**: Find most similar texts from a collection
- **Clustering**: Group texts by semantic similarity
- **Classification**: Compare against labeled examples
- **Deduplication**: Identify near-duplicate content

### Supported Models
- **BERT models**: Fast general-purpose embeddings (384 dimensions)
- **Jina models**: Optimized for semantic search (512-768 dimensions)
- **HuggingFace Hub**: Any compatible model from the hub

### File and Directory Processing
- **File embedding**: Process PDF, TXT, MD, DOCX files with automatic chunking
- **Directory streaming**: Efficiently embed entire document collections
- **Metadata extraction**: Track file paths, page numbers, chunk indices

## Memory Management

EmbedAnythingInDart provides automatic memory management, but you should still follow best practices:

### Recommended Pattern

```dart
void processTexts() {
  final embedder = EmbedAnything.fromPretrainedHf(
    model: EmbeddingModel.bert,
    modelId: 'sentence-transformers/all-MiniLM-L6-v2',
  );

  try {
    // Use the embedder
    final result = embedder.embedText('Test text');
    print(result.dimension);
  } finally {
    // Always dispose in finally block
    embedder.dispose();
  }
}
```

**Best Practices:**
- Call `dispose()` when you're done with an embedder
- Use try-finally to ensure cleanup even if errors occur
- Reuse embedders instead of creating many instances
- Don't call `dispose()` multiple times (it's safe but unnecessary)

> **Note:** Even without manual disposal, the library uses `NativeFinalizer` to clean up resources automatically when the embedder is garbage collected. However, manual disposal is recommended for predictable resource management in long-running applications.

## Using Predefined Configurations

For convenience, the library provides predefined configurations for popular models:

```dart
import 'package:embedanythingindart/embedanythingindart.dart';

void main() {
  // Using predefined configuration (recommended)
  final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());

  final result = embedder.embedText('Test with predefined config');
  print('Dimension: ${result.dimension}');

  embedder.dispose();
}
```

**Available Predefined Configs:**
- `ModelConfig.bertMiniLML6()` - BERT MiniLM-L6 (fast, 384-dim)
- `ModelConfig.bertMiniLML12()` - BERT MiniLM-L12 (better quality, 384-dim)
- `ModelConfig.jinaV2Small()` - Jina v2 Small (balanced, 512-dim)
- `ModelConfig.jinaV2Base()` - Jina v2 Base (best quality, 768-dim)

## Next Steps

Now that you've created your first embeddings, explore more advanced features:

### Learn Core Concepts
- Understand the library architecture
- Learn about vector embeddings and semantic similarity
- Explore memory management in depth
- See [`docs/core-concepts.md`](core-concepts.md)

### Complete API Reference
- Browse all available methods and classes
- See parameter details and return types
- Review comprehensive examples
- See [`docs/api-reference.md`](api-reference.md)

### Practical Usage Patterns
- Semantic search implementation
- Batch processing optimization
- File and directory embedding
- Semantic clustering
- See [`docs/usage-guide.md`](usage-guide.md)

### Choose the Right Model
- Compare BERT vs Jina models
- Understand precision tradeoffs (F32 vs F16)
- Learn about custom configurations
- See performance characteristics
- See [`docs/models-and-configuration.md`](models-and-configuration.md)

### Handle Errors Robustly
- Understand the error hierarchy
- Learn recovery strategies
- Debug common issues
- See [`docs/error-handling.md`](error-handling.md)

### Advanced Topics
- File embedding with chunking strategies
- Directory streaming for large collections
- Performance optimization techniques
- Multiple embedders and model comparison
- See [`docs/advanced-topics.md`](advanced-topics.md)

## Quick Reference

### Loading a Model
```dart
final embedder = EmbedAnything.fromPretrainedHf(
  model: EmbeddingModel.bert,
  modelId: 'sentence-transformers/all-MiniLM-L6-v2',
);
```

### Embedding Text
```dart
// Single text
final result = embedder.embedText('Your text here');

// Batch of texts
final results = embedder.embedTextsBatch(['Text 1', 'Text 2', 'Text 3']);
```

### Computing Similarity
```dart
final similarity = embedding1.cosineSimilarity(embedding2);
```

### Cleanup
```dart
embedder.dispose();
```

## Common Issues

### First Build Takes Forever
This is expected! The first build compiles 488 Rust crates and takes 5-15 minutes. Subsequent builds are much faster (under 30 seconds).

### Model Download is Slow
Models range from 90MB to 500MB and download from HuggingFace Hub. After the first download, models are cached locally in `~/.cache/huggingface/hub`.

### "Asset not found" Error
Ensure you're running with the Native Assets flag:
```bash
dart run --enable-experiment=native-assets your_app.dart
```

### Out of Memory
- Reduce batch size when processing many texts
- Use F16 precision instead of F32 (2x memory reduction)
- Process files in smaller chunks

For more troubleshooting help, see the main [README troubleshooting section](../README.md#troubleshooting).

## Getting Help

- **Examples**: See [`example/embedanythingindart_example.dart`](../example/embedanythingindart_example.dart) for comprehensive examples
- **Tests**: Browse [`test/`](../test/) directory for usage patterns
- **Issues**: Open an issue on [GitHub](https://github.com/yourusername/embedanythingindart/issues)
- **Documentation**: Continue to other docs pages for in-depth guides

## Summary

You've learned how to:
- ✓ Install EmbedAnythingInDart and its prerequisites
- ✓ Load embedding models from HuggingFace Hub
- ✓ Generate embeddings for single and multiple texts
- ✓ Compute semantic similarity between embeddings
- ✓ Handle errors gracefully
- ✓ Manage memory with dispose()
- ✓ Use predefined model configurations

Ready to build powerful semantic applications with Dart!
