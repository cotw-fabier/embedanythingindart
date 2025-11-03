## Native FFI bindings standards

- **Two-Layer Architecture**: Separate low-level FFI bindings (`lib/src/ffi/`) from high-level Dart API (`lib/src/`)
- **Native Annotations**: Use `@Native` decorator with asset IDs for automatic symbol resolution via native assets
- **Opaque Handles**: Represent native objects as opaque handles extending `Opaque` rather than exposing internal structure
- **Memory Ownership**: Document ownership clearly - who allocates, who frees; use `NativeFinalizer` for automatic cleanup
- **Type Safety**: Create type-safe wrappers around raw pointers; never expose `Pointer<T>` in public API
- **Function Signatures**: Define clear `typedef` for native functions with both Dart and C signatures
- **String Handling**: Convert between Dart `String` and native `Pointer<Utf8>` carefully; always free allocated native strings
- **Buffer Management**: Use `malloc`/`calloc` for native allocations; pair every allocation with corresponding `free`
- **Null Safety**: Map null pointers to Dart null or throw exceptions; document nullability contracts clearly
- **Error Codes**: Convert native error codes to Dart exceptions immediately at binding layer; don't leak error codes to API
- **Callback Registration**: Use `NativeCallable.isolateLocal()` for callbacks from native to Dart; manage lifecycle properly
- **Thread Safety**: Document thread safety guarantees; use `NativeCallable.listener()` for cross-thread callbacks
- **Platform Differences**: Abstract platform-specific implementations behind uniform interface; use conditional imports if needed
- **Struct Mapping**: Define Dart struct classes extending `Struct` matching native layout exactly; respect alignment
- **Enum Mapping**: Map native enums to Dart enums or sealed classes for exhaustive handling
- **Version Detection**: Query native library version at initialization; validate compatibility with binding version
- **Symbol Validation**: Check that required symbols exist after loading library; fail fast with clear errors if missing
- **Lazy Loading**: Consider lazy initialization of native library to defer platform checks until first use
- **Extension Methods**: Add extension methods on `Pointer<T>` types for common operations to improve ergonomics

## FFI Binding Patterns

**Opaque Handle Pattern:**
```dart
final class NativeDatabase extends Opaque {}

@Native<Pointer<NativeDatabase> Function()>(
  symbol: 'db_create',
  assetId: 'package:my_package/native_lib'
)
external Pointer<NativeDatabase> _nativeDbCreate();
```

**Finalizer Pattern:**
```dart
final class Database {
  final Pointer<NativeDatabase> _handle;
  static final _finalizer = NativeFinalizer(
    Native.addressOf<NativeVoid Function(Pointer<NativeDatabase>)>(
      _nativeDbDestroy
    )
  );

  Database._(this._handle) {
    _finalizer.attach(this, _handle.cast());
  }
}
```

**String Conversion Pattern:**
```dart
String fromNative(Pointer<Utf8> ptr) {
  try {
    return ptr.toDartString();
  } finally {
    malloc.free(ptr);
  }
}

Pointer<Utf8> toNative(String str) {
  return str.toNativeUtf8(allocator: malloc);
}
```

**Error Propagation Pattern:**
```dart
void checkError(int code) {
  if (code != 0) {
    throw NativeException(
      getNativeErrorMessage(code),
      code: code,
    );
  }
}
```

## References

- [Dart FFI Documentation](https://dart.dev/guides/libraries/c-interop)
- [FFI Package API](https://pub.dev/documentation/ffi/latest/)
- [Native Assets Guide](https://dart.dev/tools/hooks)
- [Memory Management in FFI](https://dart.dev/guides/libraries/c-interop#managing-memory)
