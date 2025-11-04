# Initial Spec Idea

## User's Initial Description

Feature: Phase 3 Dart API - File and Directory Embedding

Create a Dart API for Phase 3 (Indexing) functionality in EmbedAnythingInDart. This includes:

1. **File Embedding API**: Ability to embed files (PDF, DOCX, TXT, MD, HTML) and get back chunks with embeddings and metadata
2. **Directory Embedding API**: Batch process entire directories of documents
3. **Chunk Embedding Data Structure**: Dart representation of EmbedData (text chunk + embedding + metadata like file path, page number, etc.)
4. **Text Configuration**: Support for chunking parameters (chunk_size, batch_size, overlap_ratio, etc.)

The goal is to enable users to:
- Embed single files and get structured chunks back (not just raw embeddings)
- Embed entire directories efficiently
- Access metadata about each chunk (source file, page number, chunk index)
- Configure chunking behavior (size, overlap, batching)

This is based on the existing EmbedAnything Rust library's `embed_file()` and `embed_directory_stream()` functions. The implementation should follow the existing FFI pattern used for `embedText()` and `embedTextsBatch()`.

Skip Phase 2 (research) for now - we have sufficient information from the EmbedAnything documentation and source code.

## Metadata
- Date Created: 2025-11-03
- Spec Name: phase-3-dart-api-file-directory-embedding
- Spec Path: /Users/fabier/Documents/code/embedanythingindart/specs/2025-11-03-phase-3-dart-api-file-directory-embedding
