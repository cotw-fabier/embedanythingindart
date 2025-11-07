# Error Handling

Robust error handling is essential for production applications using EmbedAnythingInDart. This guide covers all error types, how to catch and handle them, recovery strategies, and common troubleshooting scenarios.

## Error Hierarchy

All errors in EmbedAnythingInDart extend from a single sealed base class:

```dart
sealed class EmbedAnythingError implements Exception
```

The `sealed` modifier means that all error subtypes are known at compile time, enabling exhaustive pattern matching. The Dart compiler will warn you if you don't handle all possible error cases in a `switch` statement.

### Complete Error Types

EmbedAnythingInDart defines eight specific error types:

| Error Type | When It Occurs | Recovery Strategy |
|------------|---------------|-------------------|
| `ModelNotFoundError` | Model ID not found on HuggingFace Hub | Verify model ID, check network |
| `InvalidConfigError` | Invalid configuration parameters | Review config values |
| `EmbeddingFailedError` | Embedding generation fails | Check input text, retry |
| `MultiVectorNotSupportedError` | Multi-vector embeddings encountered | Use dense single-vector model |
| `FFIError` | FFI layer operation fails | Check native library, restart |
| `FileNotFoundError` | File or directory doesn't exist | Verify path, check permissions |
| `UnsupportedFileFormatError` | File format not supported | Use supported format (PDF/TXT/MD/DOCX/HTML) |
| `FileReadError` | Cannot read file | Check permissions, file locks |

## Catching Errors

### Basic Error Handling

Use a try-catch block to handle all `EmbedAnythingError` types:

```dart
import 'package:embedanythingindart/embedanythingindart.dart';

void basicErrorHandling() {
  try {
    final embedder = EmbedAnything.fromPretrainedHf(
      model: EmbeddingModel.bert,
      modelId: 'invalid/model/id',
    );
    embedder.dispose();
  } on EmbedAnythingError catch (e) {
    print('Error: ${e.message}');
    // Generic error handling
  }
}
```

### Exhaustive Pattern Matching

Use a `switch` statement to handle each error type specifically:

```dart
try {
  final embedder = EmbedAnything.fromPretrainedHf(
    model: EmbeddingModel.bert,
    modelId: 'some/model',
  );
  final result = embedder.embedText('test');
  embedder.dispose();
} on EmbedAnythingError catch (e) {
  switch (e) {
    case ModelNotFoundError():
      print('Model not found: ${e.modelId}');
      print('Check the model ID on https://huggingface.co/');
      // Provide fallback model or prompt user

    case InvalidConfigError():
      print('Invalid config - ${e.field}: ${e.reason}');
      // Use predefined config or fix the issue

    case EmbeddingFailedError():
      print('Embedding failed: ${e.reason}');
      // Retry with different text or log error

    case MultiVectorNotSupportedError():
      print(e.message);
      // Use a different model (BERT or Jina)

    case FFIError():
      print('FFI operation failed: ${e.operation}');
      if (e.nativeError != null) {
        print('Native error: ${e.nativeError}');
      }
      // Restart application or reinitialize embedder

    case FileNotFoundError():
      print('File not found: ${e.path}');
      // Verify path exists or skip this file

    case UnsupportedFileFormatError():
      print('Unsupported format: ${e.extension} for ${e.path}');
      // Skip file or convert to supported format

    case FileReadError():
      print('Cannot read ${e.path}: ${e.reason}');
      // Check permissions or retry later
  }
}
```

> **⚠️ Important:** The `switch` statement above is exhaustive - it handles all possible error types. The Dart compiler enforces this when using sealed classes.

## Error Types in Detail

### ModelNotFoundError

**When it occurs:**
- Model ID is incorrect, misspelled, or doesn't exist on HuggingFace Hub
- Network connectivity issues prevent model download
- Model requires authentication but no token is provided
- HuggingFace Hub is unavailable

**Properties:**
- `modelId` (String): The model ID that was not found

**Example:**
```dart
try {
  final embedder = EmbedAnything.fromPretrainedHf(
    model: EmbeddingModel.bert,
    modelId: 'invalid/model/path',
  );
} on ModelNotFoundError catch (e) {
  print('Model not found: ${e.modelId}');

  // Recovery: Use a known good model
  final fallbackEmbedder = EmbedAnything.fromConfig(
    ModelConfig.bertMiniLML6(),
  );
}
```

**Recovery strategies:**
1. Verify the model ID on https://huggingface.co/
2. Check network connectivity
3. Use a predefined model configuration (`ModelConfig.bertMiniLML6()`)
4. Set `HF_TOKEN` environment variable if model requires authentication
5. Check `~/.cache/huggingface/hub` for cached models

### InvalidConfigError

**When it occurs:**
- Required configuration fields are missing or empty
- Configuration values are out of valid range
- Incompatible configuration options are used together

**Properties:**
- `field` (String): The configuration field that is invalid
- `reason` (String): Why the configuration is invalid

**Example:**
```dart
try {
  final config = ModelConfig(
    modelId: '',  // Invalid: empty string
    modelType: EmbeddingModel.bert,
  );
  config.validate();
} on InvalidConfigError catch (e) {
  print('Invalid ${e.field}: ${e.reason}');

  // Recovery: Use predefined config
  final validConfig = ModelConfig.bertMiniLML6();
  final embedder = EmbedAnything.fromConfig(validConfig);
}
```

**Recovery strategies:**
1. Use predefined configurations (`ModelConfig.bertMiniLML6()`, etc.)
2. Review the configuration documentation
3. Call `config.validate()` before using custom configs
4. Check that all required fields have valid values

### EmbeddingFailedError

**When it occurs:**
- Text processing errors (e.g., invalid characters, encoding issues)
- Model inference failures
- Memory allocation failures during embedding generation
- Internal model errors

**Properties:**
- `reason` (String): Why embedding generation failed

**Example:**
```dart
final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());

try {
  final result = embedder.embedText(problemText);
} on EmbeddingFailedError catch (e) {
  print('Failed to generate embedding: ${e.reason}');

  // Recovery: Sanitize text and retry
  final cleanedText = problemText.trim().replaceAll(RegExp(r'\s+'), ' ');
  try {
    final result = embedder.embedText(cleanedText);
    print('Retry succeeded after text cleaning');
  } catch (_) {
    print('Retry failed - skipping this text');
  }
} finally {
  embedder.dispose();
}
```

**Recovery strategies:**
1. Validate and sanitize input text (trim, remove special characters)
2. Check text length (very long texts may cause issues)
3. Retry the operation once
4. Skip the problematic text and continue processing
5. Log the error with context for debugging

### MultiVectorNotSupportedError

**When it occurs:**
- Model produces multi-vector embeddings (e.g., ColBERT, late-interaction models)
- The current version of EmbedAnythingInDart only supports dense single-vector embeddings

**Properties:**
- None (error message is fixed)

**Example:**
```dart
try {
  final embedder = EmbedAnything.fromPretrainedHf(
    model: EmbeddingModel.bert,
    modelId: 'some-colbert-model',  // ColBERT produces multi-vector
  );
  final result = embedder.embedText('test');
} on MultiVectorNotSupportedError catch (e) {
  print(e.message);

  // Recovery: Use a dense single-vector model
  final denseEmbedder = EmbedAnything.fromConfig(
    ModelConfig.bertMiniLML6(),  // Produces dense vectors
  );
  final result = denseEmbedder.embedText('test');
  denseEmbedder.dispose();
}
```

**Recovery strategies:**
1. Use BERT models (all produce dense single vectors)
2. Use Jina models (produce dense single vectors)
3. Avoid ColBERT and late-interaction models
4. Refer to model documentation to verify output format

### FFIError

**When it occurs:**
- Null pointer errors at FFI boundary
- Invalid memory access between Dart and native code
- Native function call failures
- Rust panic or native crashes (if caught)
- Using a disposed embedder

**Properties:**
- `operation` (String): The FFI operation that failed
- `nativeError` (String?): Optional native error message from Rust/C side

**Example:**
```dart
final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());
embedder.dispose();

try {
  // This will fail - embedder is disposed
  final result = embedder.embedText('test');
} on StateError catch (e) {
  // Note: Disposed embedder throws StateError, not FFIError
  print('Embedder is disposed');

  // Recovery: Create a new embedder
  final newEmbedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());
  final result = newEmbedder.embedText('test');
  newEmbedder.dispose();
}

// True FFIError example (rare)
try {
  final embedder = EmbedAnything.fromPretrainedHf(
    model: EmbeddingModel.bert,
    modelId: 'sentence-transformers/all-MiniLM-L6-v2',
  );
} on FFIError catch (e) {
  print('FFI operation failed: ${e.operation}');
  if (e.nativeError != null) {
    print('Native error: ${e.nativeError}');
  }

  // Recovery: Report bug, restart application
  print('This indicates a serious issue - please report this error');
}
```

**Recovery strategies:**
1. Check that embedder is not disposed before use
2. Restart the application
3. Report the error (FFIError usually indicates a bug)
4. Check native library installation
5. Verify platform compatibility

### FileNotFoundError

**When it occurs:**
- The specified file path does not exist
- The specified directory path does not exist
- Permission denied accessing the file or directory
- Path contains typos or incorrect separators

**Properties:**
- `path` (String): The path that was not found

**Example:**
```dart
final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());

try {
  final chunks = await embedder.embedFile('/path/to/nonexistent.pdf');
} on FileNotFoundError catch (e) {
  print('File not found: ${e.path}');

  // Recovery: Verify path and retry with correct path
  final correctPath = '/path/to/existing.pdf';
  if (File(correctPath).existsSync()) {
    final chunks = await embedder.embedFile(correctPath);
    print('Successfully embedded file');
  }
} finally {
  embedder.dispose();
}
```

**Directory handling:**
```dart
try {
  final stream = embedder.embedDirectory('/nonexistent/dir');
  await stream.toList();
} on FileNotFoundError catch (e) {
  print('Directory not found: ${e.path}');

  // Recovery: Use current directory or prompt user
  final currentDir = Directory.current.path;
  final stream = embedder.embedDirectory(currentDir);
  await for (final chunk in stream) {
    // Process chunks
  }
}
```

**Recovery strategies:**
1. Verify file/directory path exists before embedding
2. Use absolute paths instead of relative paths
3. Check file permissions
4. Handle platform-specific path separators correctly
5. Skip missing files and continue with available ones

### UnsupportedFileFormatError

**When it occurs:**
- File extension is not in the supported list
- File format cannot be parsed by available parsers

**Supported formats:** PDF, TXT, MD, DOCX, HTML

**Properties:**
- `path` (String): The path to the file
- `extension` (String): The file extension that is not supported

**Example:**
```dart
try {
  final chunks = await embedder.embedFile('/path/to/file.xyz');
} on UnsupportedFileFormatError catch (e) {
  print('Unsupported format: ${e.extension} for ${e.path}');
  print('Supported formats: PDF, TXT, MD, DOCX, HTML');

  // Recovery: Skip this file or convert to supported format
  print('Skipping ${e.path}');
}
```

**Directory processing with format filtering:**
```dart
final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());
final results = <ChunkEmbedding>[];

try {
  final stream = embedder.embedDirectory(
    '/path/to/dir',
    extensions: ['.txt', '.md'],  // Only process supported formats
  );

  await for (final chunk in stream) {
    results.add(chunk);
  }
} catch (e) {
  print('Error processing directory: $e');
} finally {
  embedder.dispose();
}
```

**Recovery strategies:**
1. Filter by supported extensions when using `embedDirectory()`
2. Convert unsupported files to supported formats
3. Skip unsupported files and continue processing
4. Check file extension before calling `embedFile()`
5. Maintain a list of supported extensions in your app

### FileReadError

**When it occurs:**
- Permission denied reading the file
- I/O error during file access
- File is locked by another process
- Disk read error
- File is corrupted

**Properties:**
- `path` (String): The path to the file that could not be read
- `reason` (String): Why the file could not be read

**Example:**
```dart
try {
  final chunks = await embedder.embedFile('/protected/file.pdf');
} on FileReadError catch (e) {
  print('Failed to read ${e.path}: ${e.reason}');

  // Recovery: Check permissions and retry
  final file = File(e.path);
  final stat = file.statSync();
  print('File permissions: ${stat.modeString()}');

  // Wait and retry (in case file is temporarily locked)
  await Future.delayed(Duration(seconds: 2));
  try {
    final chunks = await embedder.embedFile(e.path);
    print('Retry succeeded');
  } catch (retryError) {
    print('Retry failed - skipping file');
  }
}
```

**Recovery strategies:**
1. Check file permissions (read access required)
2. Retry after a short delay (file may be locked)
3. Close other programs that may have the file open
4. Skip the file and log the error
5. Verify disk health and available space

## Common Issues & Solutions

### Issue: "Model not found" on first run

**Symptoms:**
- `ModelNotFoundError` thrown when loading model
- Error message mentions model ID

**Causes:**
- First time loading the model (needs to download from HuggingFace)
- Network connectivity issues
- Incorrect model ID

**Solutions:**
1. **Verify network connectivity:**
   ```bash
   # Check if you can reach HuggingFace Hub
   curl -I https://huggingface.co
   ```

2. **Use predefined configurations:**
   ```dart
   // These use verified model IDs
   final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());
   ```

3. **Check model ID on HuggingFace Hub:**
   - Visit https://huggingface.co/
   - Search for your model
   - Copy the exact model ID (e.g., `sentence-transformers/all-MiniLM-L6-v2`)

4. **Set authentication token (if needed):**
   ```bash
   export HF_TOKEN=your_token_here
   ```

### Issue: First model load is extremely slow

**Symptoms:**
- Application hangs for minutes on first model load
- No error thrown, just slow performance

**Cause:**
- Model is downloading from HuggingFace Hub (100-500MB download)
- This is expected behavior on first run

**Solutions:**
1. **Show progress indicator:**
   ```dart
   print('Loading model (first time may take 2-5 minutes)...');
   final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());
   print('Model loaded!');
   ```

2. **Pre-download models:**
   - Models are cached in `~/.cache/huggingface/hub`
   - Subsequent loads are fast (~100-150ms)
   - Download models once during installation/setup

3. **Use smaller models:**
   - BERT MiniLM-L6-v2: ~90MB (fastest)
   - Jina v2-small: ~120MB
   - Jina v2-base: ~500MB (slowest download)

### Issue: Memory leak suspected

**Symptoms:**
- Memory usage grows over time
- Application becomes slow or crashes
- Multiple embedders created

**Cause:**
- Not calling `dispose()` on embedders
- Creating new embedders repeatedly without cleanup

**Solutions:**
1. **Always dispose embedders:**
   ```dart
   final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());
   try {
     // Use embedder
     final result = embedder.embedText('test');
   } finally {
     embedder.dispose();  // Always dispose!
   }
   ```

2. **Reuse embedders:**
   ```dart
   // Bad: Creates 100 embedders
   for (var i = 0; i < 100; i++) {
     final e = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());
     e.embedText('test $i');
     // No dispose - memory leak!
   }

   // Good: Reuse single embedder
   final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());
   try {
     for (var i = 0; i < 100; i++) {
       embedder.embedText('test $i');
     }
   } finally {
     embedder.dispose();
   }
   ```

3. **Use try-finally for guaranteed cleanup:**
   ```dart
   EmbedAnything? embedder;
   try {
     embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());
     // Use embedder
   } finally {
     embedder?.dispose();
   }
   ```

### Issue: "Embedder is disposed" error

**Symptoms:**
- `StateError` thrown when calling embedding methods
- Error message mentions disposed embedder

**Cause:**
- Calling methods on an embedder after `dispose()` has been called

**Solutions:**
1. **Check disposal state:**
   ```dart
   final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());
   embedder.dispose();

   // Don't use embedder after disposal!
   // This will throw StateError:
   // embedder.embedText('test');

   // Instead, create a new embedder:
   final newEmbedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());
   newEmbedder.embedText('test');
   newEmbedder.dispose();
   ```

2. **Structure code to prevent double disposal:**
   ```dart
   void processTexts(List<String> texts) {
     final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());
     try {
       for (final text in texts) {
         embedder.embedText(text);
       }
     } finally {
       embedder.dispose();
       // Don't use embedder after this point
     }
   }
   ```

### Issue: File format not supported

**Symptoms:**
- `UnsupportedFileFormatError` thrown when embedding files
- File has unusual extension

**Cause:**
- File format is not in the supported list
- Currently supported: PDF, TXT, MD, DOCX, HTML

**Solutions:**
1. **Check file extension:**
   ```dart
   import 'dart:io';

   bool isSupportedFormat(String path) {
     final supportedExtensions = ['.pdf', '.txt', '.md', '.docx', '.html'];
     final extension = path.toLowerCase().split('.').last;
     return supportedExtensions.contains('.$extension');
   }

   final file = '/path/to/file.xyz';
   if (isSupportedFormat(file)) {
     final chunks = await embedder.embedFile(file);
   } else {
     print('Unsupported format - skipping');
   }
   ```

2. **Filter when processing directories:**
   ```dart
   // Only process supported formats
   final stream = embedder.embedDirectory(
     '/path/to/dir',
     extensions: ['.txt', '.md', '.pdf'],  // Explicitly list supported
   );
   ```

3. **Convert to supported format:**
   - Convert DOC to DOCX
   - Convert RTF to TXT
   - Convert images (OCR) to TXT
   - Use external tools for conversion

### Issue: Network timeout during model download

**Symptoms:**
- Long delay followed by error
- Model download interrupted

**Cause:**
- Slow network connection
- HuggingFace Hub temporarily unavailable
- Firewall or proxy blocking connection

**Solutions:**
1. **Check HuggingFace Hub status:**
   - Visit https://status.huggingface.co/

2. **Use cached models:**
   - Models are cached in `~/.cache/huggingface/hub`
   - If model is cached, no network needed
   - Pre-download models on fast connection

3. **Configure proxy (if needed):**
   ```bash
   export HTTP_PROXY=http://proxy.example.com:8080
   export HTTPS_PROXY=http://proxy.example.com:8080
   ```

4. **Retry with timeout handling:**
   ```dart
   EmbedAnything? embedder;
   int attempts = 0;
   const maxAttempts = 3;

   while (embedder == null && attempts < maxAttempts) {
     try {
       attempts++;
       print('Attempt $attempts of $maxAttempts...');
       embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());
     } on ModelNotFoundError catch (e) {
       if (attempts >= maxAttempts) {
         print('Failed after $maxAttempts attempts');
         rethrow;
       }
       print('Retrying in 5 seconds...');
       await Future.delayed(Duration(seconds: 5));
     }
   }
   ```

## Debugging Tips

### Enable Verbose Error Information

When handling errors, extract all available information:

```dart
try {
  // Your code here
} on EmbedAnythingError catch (e, stackTrace) {
  print('Error type: ${e.runtimeType}');
  print('Message: ${e.message}');
  print('String: ${e.toString()}');
  print('Stack trace: $stackTrace');

  // Type-specific information
  if (e is ModelNotFoundError) {
    print('Model ID: ${e.modelId}');
  } else if (e is InvalidConfigError) {
    print('Field: ${e.field}');
    print('Reason: ${e.reason}');
  } else if (e is FFIError) {
    print('Operation: ${e.operation}');
    print('Native error: ${e.nativeError}');
  }
}
```

### Check Model Cache

Models are cached locally after first download:

```bash
# Check cached models
ls -lh ~/.cache/huggingface/hub

# Size of cache
du -sh ~/.cache/huggingface/hub

# Clear cache (will re-download models)
rm -rf ~/.cache/huggingface/hub
```

### Verify Platform Compatibility

EmbedAnythingInDart requires native assets (Rust FFI):

```dart
import 'dart:io';

void checkPlatform() {
  if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
    print('Platform supported: ${Platform.operatingSystem}');
  } else {
    print('Platform not supported: ${Platform.operatingSystem}');
    print('EmbedAnythingInDart requires desktop platform (not Web)');
  }
}
```

### Test with Simple Cases First

When debugging, start with the simplest possible case:

```dart
void diagnosticTest() {
  print('=== EmbedAnythingInDart Diagnostic Test ===');

  try {
    print('1. Loading model...');
    final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());
    print('   ✓ Model loaded');

    print('2. Embedding simple text...');
    final result = embedder.embedText('test');
    print('   ✓ Embedding generated (dimension: ${result.dimension})');

    print('3. Computing similarity...');
    final result2 = embedder.embedText('test');
    final similarity = result.cosineSimilarity(result2);
    print('   ✓ Similarity computed: ${similarity.toStringAsFixed(4)}');

    print('4. Disposing embedder...');
    embedder.dispose();
    print('   ✓ Embedder disposed');

    print('\n✓ All tests passed - library is working correctly');
  } catch (e, stackTrace) {
    print('\n✗ Test failed: $e');
    print('Stack trace: $stackTrace');
  }
}
```

### Log Errors for Production

Implement comprehensive error logging:

```dart
import 'dart:developer' as developer;

void logError(String context, Object error, StackTrace stackTrace) {
  // Console logging
  print('[$context] Error: $error');

  // Developer logging (visible in DevTools)
  developer.log(
    'Error in $context',
    error: error,
    stackTrace: stackTrace,
    level: 1000,  // Error level
  );

  // Production logging (to file, analytics, etc.)
  // TODO: Implement your production logging here
}

// Usage
try {
  final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());
  // ...
} catch (e, stackTrace) {
  logError('Model initialization', e, stackTrace);
  rethrow;
}
```

## Best Practices Summary

1. **Always use try-catch-finally:**
   ```dart
   EmbedAnything? embedder;
   try {
     embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());
     // Use embedder
   } catch (e) {
     // Handle error
   } finally {
     embedder?.dispose();
   }
   ```

2. **Use exhaustive pattern matching:**
   - Switch on all error types
   - Let compiler enforce completeness
   - Handle each error appropriately

3. **Provide user feedback:**
   - Show progress for slow operations (model loading)
   - Display helpful error messages
   - Offer recovery options

4. **Log errors with context:**
   - Include operation being performed
   - Include relevant parameters (model ID, file path)
   - Include stack traces for debugging

5. **Test error handling:**
   - Test with invalid model IDs
   - Test with missing files
   - Test with disposed embedders
   - Test network failures

6. **Fail gracefully:**
   - Don't crash on errors
   - Provide fallback behavior
   - Skip problematic items and continue
   - Report errors clearly

## Next Steps

- See [Getting Started](getting-started.md) for basic usage
- See [API Reference](api-reference.md) for complete error type details
- See [Usage Guide](usage-guide.md) for error handling patterns in context
- See [Advanced Topics](advanced-topics.md) for production-grade error handling
