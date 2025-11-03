# Troubleshooting Guide

This guide covers common issues and their solutions when using EmbedAnythingInDart.

## Table of Contents

- [Model Download Failures](#model-download-failures)
- [First Build Extremely Slow](#first-build-extremely-slow)
- [Asset Not Found Errors](#asset-not-found-errors)
- [Symbol Not Found Errors](#symbol-not-found-errors)
- [Out of Memory Errors](#out-of-memory-errors)
- [Platform-Specific Build Issues](#platform-specific-build-issues)
- [Test Failures](#test-failures)
- [FFI Errors](#ffi-errors)

---

## Model Download Failures

### Problem Description

When loading a model for the first time, you may encounter errors like:
- `ModelNotFoundError: Model not found: <model-id>`
- Network timeout or connection errors
- HTTP 401/403 errors from HuggingFace

### Causes

1. **No Internet Connection**: Model downloads require internet access
2. **Invalid Model ID**: The model doesn't exist on HuggingFace Hub
3. **Private Model**: Model requires authentication but no token provided
4. **Network Issues**: Firewall, proxy, or DNS problems
5. **HuggingFace Hub Down**: Rare, but the service may be temporarily unavailable

### Solutions

#### Verify Internet Connection

```bash
# Test connectivity to HuggingFace
curl -I https://huggingface.co
```

If this fails, check your network connection.

#### Verify Model Exists

Visit https://huggingface.co/models and search for your model ID. Make sure it exists and is publicly accessible.

Common valid models:
- `sentence-transformers/all-MiniLM-L6-v2`
- `sentence-transformers/all-MiniLM-L12-v2`
- `jinaai/jina-embeddings-v2-small-en`
- `jinaai/jina-embeddings-v2-base-en`

#### Authenticate for Private Models

If the model requires authentication, set the HuggingFace token:

```bash
export HF_TOKEN="your_huggingface_token_here"
```

Get your token from https://huggingface.co/settings/tokens

#### Configure Proxy (if needed)

```bash
# For HTTP proxy
export HTTP_PROXY="http://proxy.example.com:8080"
export HTTPS_PROXY="http://proxy.example.com:8080"

# For SOCKS proxy
export ALL_PROXY="socks5://proxy.example.com:1080"
```

#### Check HuggingFace Status

Visit https://status.huggingface.co to check if the service is operational.

#### Clear Model Cache

If downloads are corrupted, clear the cache:

```bash
rm -rf ~/.cache/huggingface/hub
```

Then try loading the model again.

---

## First Build Extremely Slow

### Problem Description

The first time you run `dart run --enable-experiment=native-assets`, the build takes 5-15 minutes or longer.

### Cause

This is **expected behavior**. EmbedAnythingInDart compiles 488 Rust crates on first build, including:
- The Candle ML framework
- Tokenizers and text processing libraries
- Linear algebra and tensor operations
- FFI bindings and utilities

### Solutions

#### Be Patient

The first build is slow, but subsequent builds are incremental:
- **First build**: 5-15 minutes
- **Subsequent builds**: <30 seconds (only changed files recompiled)

#### Monitor Progress

Watch Rust compilation progress:

```bash
# Verbose output to see what's being compiled
CARGO_LOG=info dart run --enable-experiment=native-assets example/embedanythingindart_example.dart
```

#### Optimize Build (Advanced)

Use `sccache` to cache compiled Rust dependencies:

```bash
# Install sccache
cargo install sccache

# Configure Cargo to use it
export RUSTC_WRAPPER=sccache

# Now builds will cache compiled artifacts
dart run --enable-experiment=native-assets
```

#### Parallel Compilation

Increase Cargo's parallel compilation jobs (if you have many CPU cores):

```bash
# In your shell profile (~/.bashrc, ~/.zshrc, etc.)
export CARGO_BUILD_JOBS=8  # Adjust based on your CPU cores
```

#### When to Worry

If the build takes **more than 30 minutes**, there may be an issue:
- Check for disk space (compilation needs ~2GB free)
- Check for memory (needs ~4GB RAM)
- Check CPU temperature (thermal throttling slows compilation)
- Review error messages for actual compilation failures

---

## Asset Not Found Errors

### Problem Description

Runtime errors like:
- `Asset not found: package:embedanythingindart/embedanything_dart`
- `Failed to load dynamic library`
- `DynamicLibrary.open failed`

### Cause

Asset name inconsistency between Rust crate name, build hook, and Dart bindings.

### Solutions

#### Verify Asset Name Consistency

Check that these three files have matching names:

**1. rust/Cargo.toml**
```toml
[package]
name = "embedanything_dart"  # Must match exactly
```

**2. hook/build.dart**
```dart
asset: assetName: 'embedanything_dart',  // Must match exactly
```

**3. lib/src/ffi/bindings.dart**
```dart
assetId: 'package:embedanythingindart/embedanything_dart'
// Format: package:<pubspec_name>/<cargo_name>
```

All three `embedanything_dart` names must match **exactly** (case-sensitive, underscores matter).

#### Clean and Rebuild

```bash
# Clean all build artifacts
dart clean
cargo clean

# Rebuild from scratch
dart run --enable-experiment=native-assets
```

#### Verify Native Assets Enabled

Make sure you're using the `--enable-experiment=native-assets` flag:

```bash
# Correct
dart run --enable-experiment=native-assets

# Wrong - will fail
dart run
```

#### Check Build Output

Look for build errors in the native asset compilation:

```bash
# Verbose build output
dart run --enable-experiment=native-assets --verbose
```

---

## Symbol Not Found Errors

### Problem Description

Errors like:
- `Symbol not found: _embedder_from_pretrained_hf`
- `Undefined symbol: embed_text`
- Dynamic library loaded but functions not found

### Cause

Mismatch between Dart `@Native` function declarations and actual Rust function signatures.

### Solutions

#### Verify Rust Function Attributes

Ensure all FFI functions in `rust/src/lib.rs` have:

```rust
#[no_mangle]
pub extern "C" fn embedder_from_pretrained_hf(
    // function signature
) -> *mut CEmbedder {
    // implementation
}
```

Both `#[no_mangle]` and `extern "C"` are **required**.

#### Check Function Name Matches

In `lib/src/ffi/bindings.dart`:

```dart
@Native<Pointer<CEmbedder> Function(
  Uint8 modelType,
  Pointer<Utf8> modelId,
  Pointer<Utf8> revision,
  Int32 dtype,
)>(symbol: 'embedder_from_pretrained_hf', assetId: '...')
```

The `symbol` name must **exactly match** the Rust function name.

#### Verify Rust Compilation Succeeded

```bash
cd rust
cargo build --release

# Check for warnings
cargo clippy -- -D warnings
```

If there are compilation errors, the symbols won't exist in the library.

#### Platform-Specific Symbol Prefixes

On macOS, symbols may have an underscore prefix. The Dart FFI should handle this automatically, but if not:

```bash
# Check actual symbols in library (macOS)
nm -gU ../target/release/libembedanything_dart.dylib | grep embedder

# Linux
nm -gD ../target/release/libembedanything_dart.so | grep embedder

# Windows
dumpbin /EXPORTS ..\target\release\embedanything_dart.dll
```

---

## Out of Memory Errors

### Problem Description

Errors or crashes when:
- Processing large batches
- Loading multiple models
- Running for extended periods

### Causes

1. **Batch Size Too Large**: Trying to process too many texts at once
2. **Model Size**: Some models are memory-intensive (Jina v2-base uses ~280MB)
3. **Memory Leaks**: Embedders not being disposed properly
4. **System Constraints**: Limited RAM on the system

### Solutions

#### Reduce Batch Size

```dart
// Instead of this:
final hugeList = List.generate(10000, (i) => 'Text $i');
final results = embedder.embedTextsBatch(hugeList);  // May OOM!

// Do this:
List<EmbeddingResult> results = [];
const batchSize = 100;

for (int i = 0; i < hugeList.length; i += batchSize) {
  final end = min(i + batchSize, hugeList.length);
  final batch = hugeList.sublist(i, end);
  results.addAll(embedder.embedTextsBatch(batch));
}
```

#### Use F16 Dtype

Half-precision models use ~50% less memory:

```dart
final config = ModelConfig(
  modelId: 'sentence-transformers/all-MiniLM-L6-v2',
  modelType: EmbeddingModel.bert,
  dtype: ModelDtype.f16,  // Uses ~45MB instead of ~90MB
);
final embedder = EmbedAnything.fromConfig(config);
```

#### Dispose Embedders Properly

```dart
// Bad - creates many embedders without cleanup
for (final text in texts) {
  final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());
  embedder.embedText(text);
  // No dispose - memory leak!
}

// Good - reuse one embedder
final embedder = EmbedAnything.fromConfig(ModelConfig.bertMiniLML6());
try {
  for (final text in texts) {
    embedder.embedText(text);
  }
} finally {
  embedder.dispose();
}
```

#### Monitor Memory Usage

```bash
# macOS
Activity Monitor -> Memory tab

# Linux
htop

# Or programmatically in Dart
import 'dart:io';
print('Max RSS: ${ProcessInfo.maxRss} bytes');
```

#### Increase System Memory Limits

On Linux, you may need to increase ulimits:

```bash
# Check current limits
ulimit -a

# Increase memory limit (in KB)
ulimit -v 4194304  # 4GB
```

---

## Platform-Specific Build Issues

### Problem Description

Build failures specific to macOS, Linux, or Windows.

### macOS Issues

#### Xcode Command Line Tools Missing

**Error**: `xcrun: error: unable to find utility "clang"`

**Solution**:
```bash
xcode-select --install
```

#### Wrong Xcode Version

**Error**: Compilation fails with linker errors

**Solution**:
```bash
# Check Xcode version
xcodebuild -version

# Should be Xcode 13.0 or later
# Update Xcode from App Store if needed
```

#### Apple Silicon (M1/M2) Issues

**Error**: Architecture mismatch errors

**Solution**:
```bash
# Ensure Rust targets are installed
cd rust
rustup show  # This installs targets from rust-toolchain.toml

# Verify target
rustup target list | grep aarch64-apple-darwin
```

### Linux Issues

#### Missing Build Tools

**Error**: `gcc not found` or `pkg-config not found`

**Solution**:
```bash
# Debian/Ubuntu
sudo apt update
sudo apt install build-essential pkg-config

# Fedora/RHEL
sudo dnf install gcc pkg-config

# Arch
sudo pacman -S base-devel
```

#### OpenSSL Missing

**Error**: `Could not find OpenSSL`

**Solution**:
```bash
# Debian/Ubuntu
sudo apt install libssl-dev

# Fedora/RHEL
sudo dnf install openssl-devel

# Arch
sudo pacman -S openssl
```

#### GLIBC Version Too Old

**Error**: `version GLIBC_2.XX not found`

**Solution**: Upgrade your system or use an older Rust version. This is rare and usually only affects very old Linux distributions.

### Windows Issues

#### MSVC Build Tools Missing

**Error**: `link.exe not found` or `cl.exe not found`

**Solution**:
1. Download Visual Studio Build Tools: https://visualstudio.microsoft.com/downloads/
2. Install "Desktop development with C++"
3. Restart your terminal

#### Path Issues

**Error**: Tools not found even after installation

**Solution**:
```powershell
# Ensure VS tools are in PATH
# Run from "Developer Command Prompt for VS" or:
"C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"
```

#### Long Path Issues

**Error**: File path too long errors

**Solution**:
```powershell
# Enable long paths in Windows
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" `
  -Name "LongPathsEnabled" -Value 1 -PropertyType DWORD -Force
```

Restart your computer after this change.

---

## Test Failures

### Problem Description

Tests fail when running `dart test --enable-experiment=native-assets`.

### Common Causes

#### No Internet Connection

**Error**: Tests timeout or fail during model loading

**Solution**: Ensure internet connection is available. Tests need to download models on first run.

#### Models Not Cached

**Error**: First test run is very slow or times out

**Solution**:
```bash
# Pre-download models by running example first
dart run --enable-experiment=native-assets example/embedanythingindart_example.dart

# Then run tests
dart test --enable-experiment=native-assets
```

#### Platform-Specific Failures

**Error**: Tests pass on one platform but fail on another

**Solution**: Check platform-specific code paths. Some tests may use `@TestOn()` annotations:

```dart
@TestOn('mac-os')
test('macOS-specific behavior', () { ... });
```

Run tests only for your platform:
```bash
# macOS
dart test --enable-experiment=native-assets --platform vm --test-randomize-ordering-seed=random

# Linux
dart test --enable-experiment=native-assets --platform vm
```

#### Memory Issues in Tests

**Error**: Tests crash or OOM

**Solution**: Run slow/memory tests separately:

```bash
# Run only fast tests
dart test --enable-experiment=native-assets --exclude-tags slow,memory

# Run memory tests separately with more resources
dart test --enable-experiment=native-assets --tags memory --concurrency=1
```

---

## FFI Errors

### Problem Description

Low-level FFI errors like:
- Segmentation faults
- Null pointer exceptions
- Memory corruption
- Random crashes

### Debugging Steps

#### Enable Rust Backtrace

```bash
RUST_BACKTRACE=full dart run --enable-experiment=native-assets
```

This will show where in the Rust code errors originate.

#### Check for Null Pointers

FFI errors often come from null pointers. In Rust:

```rust
if ptr.is_null() {
    set_last_error("Received null pointer");
    return std::ptr::null_mut();
}
```

#### Verify Memory Ownership

Ensure clear ownership of memory passed across FFI boundary:
- Dart owns memory after it copies from Rust
- Rust owns memory until explicitly freed by Dart
- Never access freed memory

#### Use Valgrind (Linux/macOS)

Detect memory errors:

```bash
valgrind --leak-check=full dart run --enable-experiment=native-assets
```

#### Use AddressSanitizer (Advanced)

Compile Rust with sanitizer:

```bash
cd rust
RUSTFLAGS="-Z sanitizer=address" cargo build --release --target x86_64-unknown-linux-gnu
```

#### Report Issues

If you encounter persistent FFI errors:

1. Create a minimal reproduction case
2. Check if issue exists in upstream EmbedAnything library
3. Open an issue on GitHub with:
   - Platform and version
   - Dart SDK version
   - Rust toolchain version
   - Full error message and backtrace
   - Minimal reproduction code

---

## Still Having Issues?

If this guide doesn't solve your problem:

1. **Check GitHub Issues**: https://github.com/yourusername/embedanythingindart/issues
2. **Review Dart FFI Docs**: https://dart.dev/guides/libraries/c-interop
3. **Check EmbedAnything Docs**: https://github.com/StarlightSearch/EmbedAnything
4. **Open a New Issue**: Include platform, versions, error messages, and reproduction steps

**When Reporting Issues, Include:**

- Operating system and version
- Dart SDK version (`dart --version`)
- Rust version (`rustc --version`)
- Complete error message with stack trace
- Minimal code to reproduce the issue
- Steps you've already tried
