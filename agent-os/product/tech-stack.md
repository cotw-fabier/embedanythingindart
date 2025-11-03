# Tech Stack

## Languages & Runtimes

### Primary Languages
- **Dart 3.11+**: Primary application language with null safety, pattern matching, records, and sealed classes for type-safe FFI result handling
- **Rust 1.90.0**: Backend ML processing language, pinned version via `rust-toolchain.toml` for reproducible cross-platform builds

### Runtime Environments
- **Dart VM**: Standalone Dart execution for CLI tools and backend services
- **Flutter**: Mobile and desktop UI framework (optional dependency for Flutter plugins)
- **Tokio**: Async Rust runtime for handling blocking ML operations without blocking Dart event loop

## FFI & Native Integration

### FFI Layer
- **dart:ffi**: Core Dart FFI library for C interop and pointer management
- **package:ffi**: Helper utilities for `malloc`, `calloc`, `Utf8` string conversion, and common FFI patterns
- **Native Assets System**: Dart 3.11+ feature for automatic native library compilation at build time via `hook/build.dart`
- **native_toolchain_rs**: Git dependency providing Rust compilation automation within Dart build hooks

### Native Build System
- **Cargo**: Rust package manager and build system with staticlib (iOS) and cdylib (other platforms) output
- **rust-toolchain.toml**: Rust version pinning and target specification for reproducible cross-platform compilation
- **Platform-Specific Toolchains**:
  - macOS: Xcode Command Line Tools
  - Linux: build-essential (GCC/Clang)
  - Windows: MSVC (Visual Studio Build Tools)
  - iOS: Xcode with iOS SDK
  - Android: Android NDK

## Machine Learning Backend

### ML Framework
- **Candle**: Pure Rust ML framework (no Python dependencies) used by EmbedAnything for tensor operations and model inference
- **EmbedAnything**: Git dependency from StarlightSearch providing high-level embedding APIs for text, images, audio, and documents

### Model Ecosystem
- **HuggingFace Hub**: Primary model source for downloading pre-trained embedding models
- **Supported Model Families**:
  - **BERT**: sentence-transformers/all-MiniLM-L6-v2 (384-dim), all-MiniLM-L12-v2 (384-dim)
  - **Jina**: jinaai/jina-embeddings-v2-small-en (512-dim), jina-embeddings-v2-base-en (768-dim)
  - **CLIP** (planned): Image-text multi-modal embeddings
  - **ColPali** (planned): Document visual embeddings
  - **Whisper** (planned): Audio transcription and embeddings

### Model Storage
- **Local Cache**: `~/.cache/huggingface/hub` for downloaded models (100-500MB per model)
- **First-Run Download**: Automatic model download on first use with progress feedback

## Memory Management

### Resource Management
- **NativeFinalizer**: Dart 3.0+ feature for automatic native resource cleanup tied to Dart garbage collector
- **Manual Dispose**: Optional eager cleanup via `dispose()` methods for deterministic resource release
- **Arc<T>**: Rust atomic reference counting for sharing embedder instances across FFI boundary
- **Thread-Local Storage**: Rust thread-local error storage for panic-safe FFI error propagation

### Memory Safety Patterns
- **Box<[T]>**: Heap allocation with ownership transfer from Rust to Dart
- **std::mem::forget()**: Prevent Rust from freeing memory transferred to Dart
- **panic::catch_unwind()**: Wrap all FFI functions to prevent undefined behavior from Rust panics crossing FFI boundary

## Development Tools

### Package Management
- **pub**: Dart package manager for dependency resolution and publishing
- **Cargo**: Rust dependency management with git dependencies for EmbedAnything

### Code Quality
- **dart analyze**: Static analysis with strict linting rules
- **package:lints**: Dart linting rules aligned with Effective Dart guidelines
- **cargo clippy**: Rust linter for catching common mistakes and enforcing best practices
- **dart format**: Automated code formatting with 80-character line limit
- **rustfmt**: Automated Rust code formatting

### Testing
- **package:test**: Dart unit and integration testing framework
- **Native Assets Test Support**: `--enable-experiment=native-assets` flag for testing FFI code
- **Platform Testing**: Manual testing across macOS, Linux, Windows (iOS/Android planned)

### Documentation
- **dartdoc**: API documentation generator for public Dart APIs
- **cargo doc**: Rust documentation generator for internal FFI layer

## Platform Support

### Current Support
- **macOS** (x86_64, Apple Silicon): Full support with Metal acceleration
- **Linux** (x86_64): Full support with CPU inference
- **Windows** (x86_64): Full support with CPU inference

### Planned Support
- **iOS** (arm64): Planned - requires staticlib configuration and App Store compliance
- **Android** (arm64-v8a, armeabi-v7a, x86_64): Planned - requires NDK integration and APK size optimization

### Platform-Specific Configurations
- **Cargo.toml**: Conditional compilation with `crate-type = ["staticlib", "cdylib"]` for iOS/other platforms
- **rust-toolchain.toml**: Platform-specific Rust targets (aarch64-apple-darwin, x86_64-unknown-linux-gnu, etc.)

## Dependencies

### Core Dart Dependencies
```yaml
dependencies:
  ffi: ^2.1.0              # FFI interop and pointer utilities
  hooks: ^0.20.4           # Native Assets build hook system

dev_dependencies:
  test: ^1.24.0            # Testing framework
  lints: ^4.0.0            # Dart linting rules
  native_toolchain_rs:     # Rust compilation automation
    git:
      url: https://github.com/GregoryConrad/native_toolchain_rs
      ref: main
```

### Core Rust Dependencies
```toml
[dependencies]
embed_anything = { git = "https://github.com/StarlightSearch/EmbedAnything" }
tokio = { version = "1", features = ["rt-multi-thread"] }
once_cell = "1.19"        # Lazy static initialization for runtime
anyhow = "1.0"            # Error handling with context
```

### System Requirements
- **Dart SDK**: ^3.11.0-36.0.dev (native assets support)
- **Rust Toolchain**: 1.90.0 (pinned)
- **Disk Space**: 2-5GB for Rust toolchain and ML model cache
- **RAM**: 4GB minimum, 8GB recommended for larger models

## Build & Deployment

### Local Development
```bash
# Install Rust targets
cd rust && rustup show

# Install Dart dependencies
dart pub get

# Run with native assets
dart run --enable-experiment=native-assets example/main.dart

# Run tests
dart test --enable-experiment=native-assets
```

### Build Outputs
- **Desktop**: Shared library (.dylib, .so, .dll) in build/native_assets
- **iOS** (planned): Static library (.a) embedded in .framework
- **Android** (planned): .so files in jniLibs for each architecture

### Asset Naming Convention
**Critical Consistency Requirement:**
1. `rust/Cargo.toml`: `name = "embedanything_dart"`
2. `hook/build.dart`: `assetName: 'embedanything_dart'`
3. `lib/src/ffi/bindings.dart`: `assetId: 'package:embedanythingindart/embedanything_dart'`

Format: `package:<pubspec_name>/<cargo_name>`

## CI/CD (Planned)

### GitHub Actions
- **Platform Matrix**: Test on macOS, Linux, Windows runners
- **Rust Caching**: Cache cargo dependencies to speed up builds
- **Model Caching**: Cache HuggingFace models to avoid repeated downloads
- **Release Automation**: Automated pub.dev publishing on tagged releases

### Quality Gates
- `dart analyze` must pass with zero warnings
- `cargo clippy` must pass with zero warnings
- All tests must pass on all platforms
- dartdoc must generate without errors

## Security Considerations

### Memory Safety
- Rust backend prevents buffer overflows, use-after-free, and data races at compile time
- Dart FFI layer validates all pointer operations and bounds checking
- NativeFinalizer prevents resource leaks even if Dart code throws exceptions

### Model Provenance
- Models downloaded from trusted HuggingFace Hub with checksum validation
- Local caching prevents man-in-the-middle attacks after first download
- No telemetry or network calls after model download

### Data Privacy
- 100% local processing - no data sent to external services
- User content never leaves device
- Suitable for GDPR, HIPAA, and other privacy-regulated applications
