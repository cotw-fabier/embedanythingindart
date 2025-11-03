## Rust integration via native_toolchain_rs standards

- **GitHub Dependency**: Pin native_toolchain_rs to specific GitHub commit, not pub.dev version: `git: {url: ..., ref: <commit-hash>}`
- **Build Hook Setup**: Create `hook/build.dart` with `RustBuilder` to automatically compile Rust code during Dart build
- **Asset Naming**: Use descriptive asset names matching your FFI binding file: `assetName: 'src/my_ffi_bindings.g.dart'`
- **Rust Toolchain Pinning**: Always specify exact Rust version in `rust-toolchain.toml`; never use `stable` or `nightly` alone
- **Multi-Platform Targets**: List all target platforms in `rust-toolchain.toml` targets array for cross-compilation support
- **Library Type**: Set `crate-type = ["staticlib", "cdylib"]` in `Cargo.toml` for proper FFI linking across platforms
- **FFI Convention**: Use `#[no_mangle]` and `extern "C"` for all Rust functions exposed to Dart
- **Panic Handling**: Wrap FFI entry points with `std::panic::catch_unwind` to prevent unwinding into Dart code
- **String Handling**: Use `CString`/`CStr` for C string interop; never return Rust `String` directly across FFI boundary
- **Memory Safety**: Use `Box::into_raw()` for owned data passed to Dart; provide destructor function for Dart to call
- **Error Propagation**: Return error codes or use out-parameters for errors; never panic or return `Result` across FFI
- **Null Pointers**: Check for null pointers from Dart before dereferencing; return null for "not found" cases
- **Thread Safety**: Document thread safety; use `Mutex`/`RwLock` if Rust objects accessed from multiple Dart isolates
- **Cargo Features**: Use Cargo features for optional functionality; pass feature flags through `RustBuilder` configuration
- **Testing**: Write Rust unit tests for core logic; use Dart integration tests for FFI boundary testing
- **Documentation**: Document Rust public API with rustdoc; explain ownership and safety contracts for FFI functions
- **Build Configuration**: Use `[profile.release]` settings in Cargo.toml to optimize for size or speed based on needs
- **Platform-Specific Code**: Use `#[cfg(target_os = "...")]` for platform-specific implementations in Rust

## Rust FFI Setup

**pubspec.yaml:**
```yaml
dependencies:
  ffi: ^2.1.0

dev_dependencies:
  native_toolchain_rs:
    git:
      url: https://github.com/GregoryConrad/native_toolchain_rs
      ref: abc123def456  # Pin to specific commit
```

**hook/build.dart:**
```dart
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_rs/native_toolchain_rs.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    await RustBuilder(
      assetName: 'src/native_api.g.dart',
      // Optional: pass Cargo features
      // cargoArgs: ['--features', 'advanced'],
    ).run(input: input, output: output);
  });
}
```

**rust-toolchain.toml:**
```toml
[toolchain]
channel = "1.90.0"  # Pin exact version
targets = [
  "aarch64-apple-darwin",
  "x86_64-apple-darwin",
  "aarch64-apple-ios",
  "aarch64-linux-android",
  "armv7-linux-androideabi",
  "x86_64-pc-windows-msvc",
  "x86_64-unknown-linux-gnu",
  "aarch64-unknown-linux-gnu"
]
```

**Cargo.toml:**
```toml
[package]
name = "my_native_lib"
version = "0.1.0"
edition = "2021"

[lib]
crate-type = ["staticlib", "cdylib"]

[dependencies]
# Your Rust dependencies here

[profile.release]
opt-level = "z"     # Optimize for size
lto = true          # Enable link-time optimization
codegen-units = 1   # Better optimization, slower compile
strip = true        # Strip symbols from binary
```

## Rust FFI Patterns

**Safe String Passing (Rust → Dart):**
```rust
use std::ffi::CString;
use std::os::raw::c_char;

#[no_mangle]
pub extern "C" fn get_message() -> *mut c_char {
    let msg = CString::new("Hello from Rust").unwrap();
    msg.into_raw()
}

#[no_mangle]
pub extern "C" fn free_string(s: *mut c_char) {
    if !s.is_null() {
        unsafe { let _ = CString::from_raw(s); }
    }
}
```

**Safe String Passing (Dart → Rust):**
```rust
use std::ffi::CStr;
use std::os::raw::c_char;

#[no_mangle]
pub extern "C" fn process_string(s: *const c_char) -> i32 {
    if s.is_null() {
        return -1;
    }
    let c_str = unsafe { CStr::from_ptr(s) };
    match c_str.to_str() {
        Ok(str_slice) => {
            println!("Received: {}", str_slice);
            0
        }
        Err(_) => -1,
    }
}
```

**Panic Safety:**
```rust
use std::panic;

#[no_mangle]
pub extern "C" fn safe_operation() -> i32 {
    match panic::catch_unwind(|| {
        // Your Rust code that might panic
        perform_operation()
    }) {
        Ok(result) => result,
        Err(_) => {
            eprintln!("Rust panic caught in FFI");
            -1
        }
    }
}
```

**Opaque Object Pattern:**
```rust
pub struct Database {
    // Internal fields
}

#[no_mangle]
pub extern "C" fn db_create() -> *mut Database {
    Box::into_raw(Box::new(Database::new()))
}

#[no_mangle]
pub extern "C" fn db_destroy(ptr: *mut Database) {
    if !ptr.is_null() {
        unsafe { let _ = Box::from_raw(ptr); }
    }
}

#[no_mangle]
pub extern "C" fn db_query(ptr: *mut Database) -> i32 {
    if ptr.is_null() {
        return -1;
    }
    let db = unsafe { &mut *ptr };
    db.query()
}
```

## References

- [native_toolchain_rs GitHub](https://github.com/GregoryConrad/native_toolchain_rs)
- [Dart Native Assets](https://dart.dev/tools/hooks)
- [The Rustonomicon FFI Chapter](https://doc.rust-lang.org/nomicon/ffi.html)
- [Rust FFI Omnibus](http://jakegoulding.com/rust-ffi-omnibus/)
