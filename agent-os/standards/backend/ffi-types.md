## FFI type mapping and memory management standards

- **Primitive Type Mapping**: Map C types to Dart FFI types: `int8_t→Int8`, `uint32_t→Uint32`, `int64_t→Int64`, `float→Float`, `double→Double`
- **Pointer Types**: Use `Pointer<T>` for C pointers; never dereference raw pointers without null checks
- **Opaque Types**: Define opaque handles with `final class Handle extends Opaque {}` for native object references
- **Struct Definitions**: Create Dart structs extending `Struct` with `@<Type>()` annotations matching native layout exactly
- **Struct Alignment**: Use `@Packed(n)` only when native struct is packed; default alignment matches C compiler
- **Array Handling**: Use `@Array(size)` annotation for fixed-size arrays in structs; dynamic arrays need separate allocation
- **Union Support**: Model C unions as structs with overlapping fields; document which field is active
- **Enum Mapping**: Map C enums to Dart enums or use `int` with named constants; prefer sealed classes for exhaustive handling
- **Boolean Mapping**: Map C `bool`/`int` to Dart `bool`; define convention (0=false, non-zero=true or 1=true only)
- **Size Types**: Use `IntPtr` for `size_t`, `ptrdiff_t`, and pointer-sized integers; it adapts to platform word size
- **Function Pointers**: Define typedefs for callbacks with both Dart signature and native signature
- **String Types**: Convert `char*` to/from Dart String using `Utf8` codec; always specify ownership and free appropriately
- **Wide Strings**: Use `Utf16` for `wchar_t*` on Windows; handle platform differences in string encoding
- **Memory Allocation**: Use `malloc.allocate<T>(count)` for temporary allocations; pair with `malloc.free()` in finally block
- **Zero Initialization**: Use `calloc` when zero-initialization is required; faster than manual zeroing
- **Alignment Requirements**: Respect native alignment; use `sizeOf<T>()` and proper stride calculations for arrays
- **Finalizers**: Attach `NativeFinalizer` to Dart objects wrapping native resources; prevents leaks when Dart object is GC'd
- **Reference Counting**: If native library uses refcounting, wrap in Dart class with proper increment/decrement in constructor/finalizer
- **Shallow vs Deep Copy**: Document whether struct copies are shallow (pointers copied) or deep (pointed data copied)
- **Lifetime Management**: Clearly document lifetime expectations; use comments like `// Caller owns, must free` or `// Borrowed, do not free`

## Type Mapping Reference

| C Type | Dart FFI Type | Notes |
|--------|---------------|-------|
| `int8_t`, `char` | `Int8` | Signed 8-bit |
| `uint8_t`, `unsigned char` | `Uint8` | Unsigned 8-bit |
| `int16_t` | `Int16` | Signed 16-bit |
| `uint16_t` | `Uint16` | Unsigned 16-bit |
| `int32_t`, `int` | `Int32` | Signed 32-bit |
| `uint32_t`, `unsigned int` | `Uint32` | Unsigned 32-bit |
| `int64_t`, `long long` | `Int64` | Signed 64-bit |
| `uint64_t` | `Uint64` | Unsigned 64-bit |
| `size_t`, `intptr_t` | `IntPtr` | Platform word size |
| `float` | `Float` | 32-bit float |
| `double` | `Double` | 64-bit float |
| `void*` | `Pointer<Void>` | Untyped pointer |
| `T*` | `Pointer<T>` | Typed pointer |
| `void` | `Void` | No return value |

## Memory Management Patterns

**Allocation and Cleanup Pattern:**
```dart
Pointer<Utf8> stringToNative(String str) {
  return str.toNativeUtf8(allocator: malloc);
}

void useNativeString() {
  final ptr = stringToNative('Hello');
  try {
    nativeFunction(ptr);
  } finally {
    malloc.free(ptr);
  }
}
```

**Finalizer Pattern:**
```dart
final class NativeResource {
  final Pointer<NativeHandle> _handle;

  static final _finalizer = NativeFinalizer(
    Native.addressOf<NativeVoid Function(Pointer<NativeHandle>)>(
      _destroyHandle
    )
  );

  NativeResource(this._handle) {
    _finalizer.attach(this, _handle.cast());
  }
}
```

**Struct Definition Pattern:**
```dart
final class Point extends Struct {
  @Double()
  external double x;

  @Double()
  external double y;
}

final class Rectangle extends Struct {
  external Point topLeft;
  external Point bottomRight;
}
```

**Array Handling Pattern:**
```dart
final class Matrix3x3 extends Struct {
  @Array(9)
  external Array<Float> elements;
}

void useMatrix() {
  final mat = calloc<Matrix3x3>();
  try {
    for (var i = 0; i < 9; i++) {
      mat.ref.elements[i] = 0.0;
    }
    // Use matrix
  } finally {
    calloc.free(mat);
  }
}
```

## References

- [Dart FFI Types](https://dart.dev/guides/libraries/c-interop#types)
- [FFI Package Documentation](https://pub.dev/documentation/ffi/latest/)
- [Memory Management](https://dart.dev/guides/libraries/c-interop#managing-memory)
- [Finalizers](https://api.dart.dev/stable/dart-ffi/NativeFinalizer-class.html)
