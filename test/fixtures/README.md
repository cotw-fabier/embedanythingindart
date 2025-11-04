# Test Fixtures for Phase 3 File/Directory Embedding

This directory contains test files used for integration testing of the Phase 3 file and directory embedding feature.

## Fixture Files

### Individual Files

- **sample.txt**: Multi-paragraph text about machine learning and AI (5 paragraphs, ~900 words)
  - Purpose: Test basic text file embedding with multiple chunks
  - Expected chunks: 2-3 chunks depending on chunk_size configuration
  - Contains: General ML/AI content suitable for semantic similarity testing

- **sample.md**: Markdown document about vector embeddings (structured with headers)
  - Purpose: Test markdown file parsing and chunking
  - Expected chunks: 3-4 chunks with structured content
  - Contains: Headers, bold text, lists, code-style formatting

### Directory

- **sample_dir/**: Directory with 5 test files (3 .txt, 2 .md)
  - **doc1.txt**: Neural networks overview (~150 words)
  - **doc2.txt**: NLP introduction (~120 words)
  - **doc3.md**: Deep learning fundamentals with markdown formatting
  - **doc4.md**: Transfer learning explanation with lists
  - **doc5.txt**: Transformers and attention mechanisms (~100 words)

  Purpose: Test directory streaming with mixed file types
  Expected behavior:
  - With no filter: Process all 5 files
  - With `.txt` filter: Process only doc1, doc2, doc5 (3 files)
  - With `.md` filter: Process only doc3, doc4 (2 files)

## Usage in Tests

### embedFile() Tests

```dart
final chunks = await embedder.embedFile(
  '/path/to/test/fixtures/sample.txt',
  chunkSize: 1000,
);
// Verify chunks.length >= 1
// Verify chunks[0].metadata['file_path'] contains 'sample.txt'
// Verify chunks[0].text is not null
```

### embedDirectory() Tests

```dart
final stream = embedder.embedDirectory(
  '/path/to/test/fixtures/sample_dir',
  extensions: ['.txt'],
);
final chunks = await stream.toList();
// Verify chunks.length matches expected file count
// Verify all chunks have valid embeddings
```

## Maintenance

These fixtures are intentionally simple and focused on testing core functionality:
- Text is readable and semantic (allows testing similarity)
- File sizes are small (fast tests)
- Content is technical (consistent domain for similarity testing)
- Mixed formats test format handling (.txt and .md)

Do NOT modify these files without updating tests that depend on them.

## File Sizes

- sample.txt: ~1.8 KB
- sample.md: ~1.4 KB
- sample_dir files: ~0.5-1.0 KB each
- Total: < 5 KB (small enough for fast tests)
