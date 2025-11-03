## FFI and native plugin testing standards

- **Test Layers Separately**: Test FFI bindings, Dart wrappers, and public API independently
- **Unit Tests for Core Logic**: Write unit tests for Dart code that wraps FFI calls
- **Integration Tests for FFI**: Write integration tests that verify correct interaction with native code
- **Mock Native Calls**: For unit tests, consider mocking FFI layer to test Dart logic in isolation
- **Real Native Tests**: Write tests that call actual native code to verify FFI bindings work correctly
- **Platform-Specific Tests**: Test on all supported platforms; native behavior may differ
- **Memory Leak Tests**: Verify finalizers trigger and native resources are freed properly
- **Error Handling Tests**: Test error paths - null pointers, invalid inputs, native errors
- **Thread Safety Tests**: If native library supports multi-threading, test concurrent access
- **Arrange-Act-Assert**: Follow AAA pattern for clear test structure
- **Descriptive Names**: Test names should clearly describe scenario and expected outcome
- **Fast Unit Tests**: Keep unit tests fast; slow integration tests can run less frequently
- **Test Independence**: Each test should be independent; no shared state between tests
- **Cleanup Resources**: Always clean up native resources in tearDown or using try-finally
- **Test Coverage**: Focus on critical paths and error handling; defer edge cases until needed
- **CI/CD Integration**: Run tests in CI across all supported platforms

## Test Structure

```
test/
├── unit/
│   ├── wrapper_test.dart        # Test Dart wrapper logic
│   └── conversion_test.dart     # Test type conversions
├── integration/
│   ├── ffi_bindings_test.dart   # Test actual FFI calls
│   └── memory_test.dart         # Test memory management
└── test_utils/
    └── native_test_lib.dart     # Helper utilities
```

## Unit Testing Patterns

**Testing Dart Wrapper (Mocked FFI):**
```dart
import 'package:test/test.dart';

void main() {
  group('Database wrapper', () {
    test('throws DatabaseException on connection failure', () {
      // Arrange
      final db = Database.forTesting(
        mockNativeCall: () => -1, // Simulate failure
      );

      // Act & Assert
      expect(
        () => db.connect('/path/to/db'),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('converts native error codes to exceptions', () {
      // Test error code mapping logic without calling native code
      expect(
        Database.errorCodeToException(1),
        isA<DatabaseNotFoundException>(),
      );
    });
  });
}
```

## Integration Testing Patterns

**Testing Real FFI Calls:**
```dart
import 'dart:ffi';
import 'dart:io';
import 'package:test/test.dart';
import 'package:my_plugin/my_plugin.dart';

void main() {
  group('Native FFI integration', () {
    test('can call native function and get result', () {
      // Arrange
      const input = 'test string';

      // Act
      final result = NativeFunctions.processString(input);

      // Assert
      expect(result, isNotNull);
      expect(result, isA<String>());
    });

    test('handles null pointer correctly', () {
      // Act & Assert
      expect(
        () => NativeFunctions.processNullablePointer(null),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
```

**Memory Management Testing:**
```dart
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:test/test.dart';

void main() {
  group('Memory management', () {
    test('allocates and frees native memory correctly', () {
      // Arrange
      final ptr = calloc<Uint8>(1024);

      // Act
      try {
        // Use the pointer
        ptr[0] = 42;
        expect(ptr[0], equals(42));
      } finally {
        // Assert cleanup happens
        calloc.free(ptr);
      }
      // No memory leak verification in Dart, but this tests the pattern
    });

    test('finalizer triggers on garbage collection', () async {
      // This is harder to test reliably, but you can verify behavior
      var resource = NativeResource.create();
      final weakRef = WeakReference(resource);

      // Clear strong reference
      resource = null;

      // Force GC (not guaranteed)
      await Future.delayed(Duration.zero);

      // Note: Finalizer timing is not guaranteed
      // This is more of a smoke test than a reliable test
    }, tags: ['gc', 'slow']);
  });
}
```

**Platform-Specific Testing:**
```dart
import 'dart:io';
import 'package:test/test.dart';

void main() {
  group('Platform-specific behavior', () {
    test('works on current platform', () {
      // Test that basic functionality works
      expect(
        () => MyPlugin.initialize(),
        returnsNormally,
      );
    }, testOn: '!browser'); // Skip on web

    test('handles platform differences', () {
      if (Platform.isWindows) {
        // Test Windows-specific behavior
      } else if (Platform.isMacOS || Platform.isLinux) {
        // Test Unix-like behavior
      }
    });
  });
}
```

**Error Handling Testing:**
```dart
void main() {
  group('Error handling', () {
    test('converts native error codes to exceptions', () {
      expect(
        () => callNativeWithError(errorCode: 404),
        throwsA(
          isA<NativeException>()
            .having((e) => e.code, 'code', equals(404))
            .having((e) => e.message, 'message', contains('not found')),
        ),
      );
    });

    test('handles native panics gracefully', () {
      // If using Rust with panic catching
      expect(
        () => callNativeFunctionThatPanics(),
        throwsA(isA<NativePanicException>()),
      );
    });
  });
}
```

## Async Testing Patterns

**Testing Async FFI Wrappers:**
```dart
void main() {
  group('Async operations', () {
    test('completes async native call', () async {
      // Arrange
      final db = Database();

      // Act
      final result = await db.queryAsync('SELECT * FROM users');

      // Assert
      expect(result, isNotEmpty);
    });

    test('handles timeout on slow native call', () async {
      expect(
        () => slowNativeOperation().timeout(Duration(milliseconds: 100)),
        throwsA(isA<TimeoutException>()),
      );
    });
  });
}
```

## Test Utilities

**Helper for Native Resource Tests:**
```dart
class NativeTestHelper {
  /// Creates a temporary native resource for testing
  static Pointer<NativeResource> createTestResource() {
    return nativeCreateResource();
  }

  /// Safely cleans up test resource
  static void cleanup(Pointer<NativeResource> ptr) {
    if (ptr != nullptr) {
      nativeDestroyResource(ptr);
    }
  }
}

/// Use in tests:
void main() {
  test('resource lifecycle', () {
    final resource = NativeTestHelper.createTestResource();
    try {
      // Test with resource
    } finally {
      NativeTestHelper.cleanup(resource);
    }
  });
}
```

## Running Tests

```bash
# Run all tests
dart test

# Run only unit tests
dart test test/unit

# Run integration tests
dart test test/integration

# Run with coverage
dart test --coverage=coverage && dart run coverage:format_coverage --lcov --in=coverage --out=coverage.lcov --report-on=lib
```

## CI/CD Testing

```yaml
# .github/workflows/test.yml
name: Tests

on: [push, pull_request]

jobs:
  test:
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest, windows-latest]
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v3
      - uses: dart-lang/setup-dart@v1
      - run: dart pub get
      - run: dart test
```

## References

- [Dart Testing](https://dart.dev/guides/testing)
- [package:test](https://pub.dev/packages/test)
- [Flutter Testing](https://docs.flutter.dev/testing)
- [FFI Memory Management](https://dart.dev/guides/libraries/c-interop#managing-memory)
