## Converting Python bindings to Dart FFI standards

This guide covers the process of analyzing Python libraries that wrap C/C++/Rust native libraries and creating equivalent Dart FFI bindings.

## Analysis Phase

- **Identify the Native Library**: Determine what C/C++/Rust library the Python package wraps (check setup.py, pyproject.toml, or documentation)
- **Locate Headers**: Find C header files (`.h`) that define the native API; these are your source of truth
- **Map Python API**: Document all public Python functions, classes, and their parameters
- **Trace to Native**: For each Python API, identify which native function(s) it calls (check `.py` files using `ctypes`, `cffi`, or C extension modules)
- **Understand Wrappers**: Note what the Python code adds beyond simple FFI calls (error handling, type conversion, resource management)
- **Document Data Flow**: Map how data flows: Python types → native types → return types → Python types
- **Identify Dependencies**: List native library dependencies and version requirements
- **Review Build Process**: Understand how Python builds/bundles the native library (provides clues for Dart native assets setup)

## Native Library Discovery

**For C libraries via ctypes:**
```python
# Look for patterns like:
lib = ctypes.CDLL('libname.so')
lib.function_name.argtypes = [c_int, c_char_p]
lib.function_name.restype = c_int
```

**For C libraries via cffi:**
```python
# Look for:
ffi = FFI()
ffi.cdef("int function_name(int, char*);")
lib = ffi.dlopen('libname')
```

**For C extension modules:**
- Check for `.c`/`.cpp` files in package
- Look for `PyArg_ParseTuple` calls to understand function signatures
- Review `PyMethodDef` arrays for method definitions

**For Rust libraries:**
- Check for `Cargo.toml` in package directory
- Look for `#[pyfunction]` or `#[pyclass]` macros (PyO3)
- Review `lib.rs` or module files for `#[no_mangle] extern "C"` functions

## Specification Creation

Create detailed specification documents for each component:

**1. Native Function Catalog (`native_functions.md`):**
```markdown
## Function: db_open

**C Signature:** `int db_open(const char* path, db_handle_t** out_handle)`

**Parameters:**
- `path`: Path to database file (null-terminated string)
- `out_handle`: Output parameter for database handle pointer

**Returns:** 0 on success, error code on failure

**Python Equivalent:** `Database(path: str)` constructor

**Notes:** Caller must call db_close() to free handle
```

**2. Type Mapping Specification (`type_mappings.md`):**
```markdown
| Python Type | C Type | Dart Type | Conversion Notes |
|-------------|--------|-----------|------------------|
| str | const char* | String | Python: encode UTF-8; Dart: toNativeUtf8() |
| int | int32_t | int | Range check needed |
| bytes | const uint8_t* | Uint8List | Python: bytes object; Dart: asTypedList() |
| DatabaseHandle | db_handle_t* | Pointer<NativeDatabase> | Opaque handle pattern |
```

**3. API Surface Document (`api_design.md`):**
Document the Dart API you'll create, learning from Python's design but following Dart conventions.

## Implementation Strategy

**Step 1: Native Asset Configuration**

For C/C++ libraries:
```dart
// hook/build.dart
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    await CBuilder.library(
      name: 'native_lib',
      assetName: 'src/ffi_bindings.g.dart',
      sources: ['src/native/*.c'],
    ).run(input: input, output: output);
  });
}
```

For Rust libraries (use native_toolchain_rs instead):
```dart
// hook/build.dart - see rust-integration.md for details
```

**Step 2: FFI Bindings Layer**

Create low-level bindings matching native signatures exactly:

```dart
// lib/src/ffi/bindings.dart
import 'dart:ffi';
import 'package:ffi/ffi.dart';

final class NativeDatabase extends Opaque {}

@Native<Int32 Function(Pointer<Utf8>, Pointer<Pointer<NativeDatabase>>)>(
  symbol: 'db_open',
  assetId: 'package:my_package/native_lib',
)
external int dbOpen(Pointer<Utf8> path, Pointer<Pointer<NativeDatabase>> outHandle);

@Native<Void Function(Pointer<NativeDatabase>)>(
  symbol: 'db_close',
  assetId: 'package:my_package/native_lib',
)
external void dbClose(Pointer<NativeDatabase> handle);
```

**Step 3: Safe Wrapper Layer**

Create Dart-idiomatic API mirroring Python's functionality:

```dart
// lib/src/database.dart
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'ffi/bindings.dart';

class Database {
  final Pointer<NativeDatabase> _handle;

  static final _finalizer = NativeFinalizer(
    Native.addressOf<Void Function(Pointer<NativeDatabase>)>(dbClose)
  );

  Database._(this._handle) {
    _finalizer.attach(this, _handle.cast());
  }

  factory Database(String path) {
    final pathPtr = path.toNativeUtf8();
    final handlePtr = calloc<Pointer<NativeDatabase>>();

    try {
      final result = dbOpen(pathPtr, handlePtr);
      if (result != 0) {
        throw DatabaseException('Failed to open database', code: result);
      }
      return Database._(handlePtr.value);
    } finally {
      calloc.free(handlePtr);
      malloc.free(pathPtr);
    }
  }
}
```

**Step 4: Python Behavior Equivalence**

Match Python behaviors that users expect:

- **Context Managers (`with`)**: Use Dart's try-finally or create `use()` methods
- **Iterators**: Implement Dart `Iterable` or `Stream` for Python generators/iterators
- **Properties**: Use Dart getters/setters for Python `@property`
- **Magic Methods**: Map `__len__` → `length`, `__getitem__` → `operator[]`, etc.
- **Exceptions**: Create Dart exception hierarchy matching Python's exception types

## Testing Strategy

- **Unit Test FFI Layer**: Test that bindings correctly call native functions with proper type conversions
- **Integration Tests**: Compare behavior against Python version for identical inputs
- **Memory Leak Tests**: Verify finalizers trigger and native resources are freed
- **Error Handling Tests**: Ensure native errors are properly caught and converted to Dart exceptions
- **Cross-Platform Tests**: Run on all supported platforms to verify native asset compilation

## Documentation Requirements

- **Migration Guide**: Document differences from Python API for users familiar with Python version
- **API Documentation**: Full dartdoc for all public APIs with examples
- **Setup Guide**: Explain native library installation if not bundled
- **Behavior Notes**: Document any intentional differences from Python version
- **Platform Support**: Clearly state which platforms are supported

## Example Analysis Workflow

1. **Clone Python package**: `git clone <python-package-repo>`
2. **Find native library**: Check `setup.py` for library dependencies or bundled sources
3. **Extract headers**: Locate all `.h` files; these define the native API
4. **Catalog functions**: Create `native_functions.md` documenting each C function
5. **Map Python API**: For each Python function/class, trace to native call(s)
6. **Create type map**: Document type conversions in `type_mappings.md`
7. **Design Dart API**: Create `api_design.md` with Dart-idiomatic interface
8. **Implement bindings**: Start with FFI layer, then safe wrappers
9. **Write tests**: Ensure behavior matches Python version
10. **Document**: Write migration guide and API docs

## Tools and Resources

- **Python source inspection**: Use `inspect` module to examine function signatures
- **ctypes/cffi debugging**: Set `PYTHONVERBOSE=1` to see library loading
- **C header parsing**: Use `dart pub global activate ffigen` for automated binding generation from headers
- **Comparison testing**: Run same operations in Python and Dart, compare outputs

## Common Pitfalls

- **Assuming 1:1 mapping**: Python may hide multiple native calls behind one function
- **Missing error handling**: Python might catch native errors silently; Dart should expose them
- **Memory management**: Python's GC differs from Dart's; carefully manage native resources
- **String encoding**: Python 3 uses UTF-8 by default, but C strings may use different encodings
- **Platform differences**: Python package may have platform-specific code paths to replicate

## References

- [Dart FFI Documentation](https://dart.dev/guides/libraries/c-interop)
- [Dart Native Assets](https://dart.dev/tools/hooks)
- [Python ctypes Documentation](https://docs.python.org/3/library/ctypes.html)
- [Python C API Documentation](https://docs.python.org/3/c-api/)
- [ffigen Package](https://pub.dev/packages/ffigen)
