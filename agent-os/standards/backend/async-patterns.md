## Async patterns for native FFI operations

- **Never Block UI Thread**: Wrap all blocking native calls in `compute()` or spawn isolates to prevent UI freezing
- **Future-Based APIs**: Expose async operations as `Future<T>` to Dart consumers; never block synchronously
- **Isolate Communication**: Use `SendPort`/`ReceivePort` for isolate message passing; ensure data is sendable across isolates
- **Compute Function**: Use `compute(callback, message)` for one-off background computations; simpler than manual isolates
- **Long-Running Operations**: For continuous background work, spawn dedicated isolates with two-way communication
- **Stream APIs**: Use `Stream<T>` for native events, callbacks, or continuous data flows from native code
- **Callback to Stream**: Convert native callbacks into Dart streams using `StreamController`
- **Cancel Operations**: Provide cancellation mechanism for long-running operations; clean up native resources properly
- **Error Propagation**: Ensure errors from isolates/compute propagate to calling code as exceptions or stream errors
- **Resource Cleanup**: Use finalizers to clean up resources even if operations are cancelled or fail
- **Platform Channels**: For Flutter plugins, consider platform channels alongside FFI for platform-specific functionality
- **Threading Model**: Document threading requirements; state if native library is thread-safe or requires single thread
- **Synchronization**: Use `Mutex` or native locks if native code needs to be called from multiple Dart isolates
- **SendPort Safety**: Only send primitives, `SendPort`, and `Isolate.exit()` compatible types across isolates
- **Memory Across Isolates**: Don't share `Pointer<T>` across isolates unless native library is thread-safe; copy data instead
- **Background Initialization**: Initialize native library lazily or in background isolate to avoid startup delays
- **Timeout Handling**: Apply timeouts to async operations; don't let native code hang indefinitely

## Patterns

**Compute Pattern (Simple Background Work):**
```dart
import 'dart:isolate';
import 'package:flutter/foundation.dart';

Future<int> expensiveNativeOperation(String input) async {
  return compute(_nativeWorker, input);
}

// Top-level or static function
int _nativeWorker(String input) {
  final inputPtr = input.toNativeUtf8();
  try {
    return nativeExpensiveFunction(inputPtr);
  } finally {
    malloc.free(inputPtr);
  }
}
```

**Dedicated Isolate Pattern (Continuous Work):**
```dart
class NativeWorker {
  Isolate? _isolate;
  SendPort? _sendPort;
  final _responses = StreamController<NativeResult>();

  Future<void> start() async {
    final receivePort = ReceivePort();
    _isolate = await Isolate.spawn(_isolateEntry, receivePort.sendPort);

    receivePort.listen((message) {
      if (message is SendPort) {
        _sendPort = message;
      } else if (message is NativeResult) {
        _responses.add(message);
      }
    });
  }

  Future<void> sendCommand(NativeCommand cmd) async {
    _sendPort?.send(cmd);
  }

  Stream<NativeResult> get results => _responses.stream;

  void dispose() {
    _isolate?.kill();
    _responses.close();
  }

  static void _isolateEntry(SendPort sendPort) {
    final receivePort = ReceivePort();
    sendPort.send(receivePort.sendPort);

    receivePort.listen((message) {
      if (message is NativeCommand) {
        final result = _processNativeCommand(message);
        sendPort.send(result);
      }
    });
  }
}
```

**Stream from Native Callbacks:**
```dart
class NativeEventStream {
  final StreamController<NativeEvent> _controller = StreamController();
  late final NativeCallable<Void Function(Pointer<NativeEvent>)> _callback;

  NativeEventStream() {
    _callback = NativeCallable.listener(_onNativeEvent);
    nativeRegisterCallback(_callback.nativeFunction);
  }

  void _onNativeEvent(Pointer<NativeEvent> eventPtr) {
    try {
      final event = NativeEvent.fromNative(eventPtr);
      _controller.add(event);
    } catch (e) {
      _controller.addError(e);
    }
  }

  Stream<NativeEvent> get events => _controller.stream;

  void dispose() {
    nativeUnregisterCallback(_callback.nativeFunction);
    _callback.close();
    _controller.close();
  }
}
```

**Future-based Wrapper:**
```dart
class Database {
  Future<List<Record>> query(String sql) async {
    return compute(_executeQuery, (handle: _handle, sql: sql));
  }

  static List<Record> _executeQuery((Pointer<NativeDb> handle, String sql) params) {
    final sqlPtr = params.sql.toNativeUtf8();
    try {
      final resultPtr = nativeQuery(params.handle, sqlPtr);
      return _convertResults(resultPtr);
    } finally {
      malloc.free(sqlPtr);
    }
  }
}
```

**Timeout Pattern:**
```dart
Future<Result> queryWithTimeout(String query, {Duration timeout = const Duration(seconds: 30)}) async {
  return compute(_nativeQuery, query)
    .timeout(
      timeout,
      onTimeout: () => throw TimeoutException('Query timed out after $timeout'),
    );
}
```

**Cancellable Operation:**
```dart
class CancellableOperation {
  bool _cancelled = false;
  Pointer<NativeHandle>? _handle;

  Future<Result> execute() async {
    return compute(_worker, this);
  }

  void cancel() {
    _cancelled = true;
    if (_handle != null) {
      nativeCancelOperation(_handle!);
    }
  }

  static Result _worker(CancellableOperation op) {
    op._handle = nativeStartOperation();
    try {
      while (!op._cancelled && !nativeIsComplete(op._handle!)) {
        // Do work
      }
      return op._cancelled ? Result.cancelled() : Result.success();
    } finally {
      nativeCloseHandle(op._handle!);
      op._handle = null;
    }
  }
}
```

## Platform Channels Integration (Flutter Plugins)

For Flutter plugins, combine FFI with platform channels when needed:

```dart
class HybridPlugin {
  static const MethodChannel _channel = MethodChannel('com.example/hybrid');

  // Use FFI for performance-critical operations
  int fastOperation(int input) {
    return nativeFastOp(input);
  }

  // Use platform channel for platform-specific features not available via FFI
  Future<String> platformSpecificFeature() async {
    return await _channel.invokeMethod('doSomething');
  }
}
```

## Threading Considerations

**Thread-Safe Native Library:**
```dart
// Can call from any isolate
Future<void> parallelWork() async {
  await Future.wait([
    compute(_work, 1),
    compute(_work, 2),
    compute(_work, 3),
  ]);
}
```

**Non-Thread-Safe Native Library:**
```dart
// Must serialize all calls through single isolate
class SingleThreadedWrapper {
  late final SendPort _sendPort;

  Future<Result> call(Command cmd) async {
    final responsePort = ReceivePort();
    _sendPort.send((cmd, responsePort.sendPort));
    return await responsePort.first as Result;
  }
}
```

## References

- [Dart Isolates](https://dart.dev/language/concurrency)
- [Flutter compute function](https://api.flutter.dev/flutter/foundation/compute.html)
- [Dart async/await](https://dart.dev/codelabs/async-await)
- [Stream API](https://dart.dev/tutorials/language/streams)
- [NativeCallable](https://api.dart.dev/stable/dart-ffi/NativeCallable-class.html)
