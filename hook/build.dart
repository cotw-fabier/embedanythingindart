import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:native_toolchain_rust/native_toolchain_rust.dart';

/// Build hook for Native Assets
///
/// This hook runs during `dart run` and `flutter run` to compile the Rust code
/// into native libraries for the target platform.
///
/// Platform-specific features are automatically selected:
/// - macOS/iOS: Metal (GPU) + Accelerate (CPU optimization)
/// - Linux/Windows: MKL (CPU optimization) + CUDA (if toolkit detected)
void main(List<String> args) async {
  await build(args, (input, output) async {
    // Only build code assets if requested
    if (!input.config.buildCodeAssets) {
      return;
    }

    // Get target platform from build config
    final codeConfig = input.config.code;
    final targetOS = codeConfig.targetOS;

    // Select features based on target platform
    final features = await _getFeaturesForPlatform(targetOS);

    // Log which features are being enabled
    if (features.isNotEmpty) {
      stderr.writeln('EmbedAnything: Enabling features: ${features.join(', ')}');
    }

    await RustBuilder(
      // Must match the package name in rust/Cargo.toml
      assetName: 'embedanything_dart',
      features: features,
    ).run(input: input, output: output);
  });
}

/// Determine which Cargo features to enable based on target platform.
///
/// Note: MKL and CUDA require external dependencies to be installed:
/// - MKL: Set MKLROOT environment variable to Intel MKL installation
/// - CUDA: Requires NVIDIA CUDA toolkit (nvcc in PATH or CUDA_PATH set)
Future<List<String>> _getFeaturesForPlatform(OS targetOS) async {
  if (targetOS == OS.macOS || targetOS == OS.iOS) {
    // Apple platforms: Metal GPU + Accelerate CPU optimization
    // Accelerate is bundled with macOS, so always available
    return ['metal', 'accelerate'];
  } else if (targetOS == OS.linux || targetOS == OS.windows) {
    // Linux/Windows: Only enable features if dependencies are installed
    final features = <String>[];

    // Check for MKL (requires MKLROOT environment variable)
    if (await _isMklAvailable()) {
      features.add('mkl');
      stderr.writeln('EmbedAnything: Intel MKL detected');
    }

    // Check for CUDA
    if (await _isCudaAvailable()) {
      features.add('cuda');
      stderr.writeln('EmbedAnything: CUDA toolkit detected');
    }

    if (features.isEmpty) {
      stderr.writeln('EmbedAnything: No GPU/accelerator detected, using basic CPU');
    }

    return features;
  } else {
    // Other platforms: no special features
    return [];
  }
}

/// Check if Intel MKL is available on the system.
///
/// MKL requires the MKLROOT environment variable to be set to the
/// installation directory (e.g., /opt/intel/mkl or similar).
Future<bool> _isMklAvailable() async {
  final mklRoot = Platform.environment['MKLROOT'];
  if (mklRoot != null && Directory(mklRoot).existsSync()) {
    return true;
  }

  // Also check common installation paths on Linux
  final commonPaths = [
    '/opt/intel/mkl',
    '/opt/intel/oneapi/mkl/latest',
  ];

  for (final path in commonPaths) {
    if (Directory(path).existsSync()) {
      return true;
    }
  }

  return false;
}

/// Check if CUDA toolkit is available on the system.
///
/// Checks for:
/// 1. CUDA_PATH environment variable pointing to valid directory
/// 2. nvcc compiler available in PATH
Future<bool> _isCudaAvailable() async {
  // Check CUDA_PATH environment variable
  final cudaPath = Platform.environment['CUDA_PATH'];
  if (cudaPath != null && Directory(cudaPath).existsSync()) {
    return true;
  }

  // Try to find nvcc in PATH
  try {
    final result = await Process.run('nvcc', ['--version']);
    return result.exitCode == 0;
  } catch (_) {
    // nvcc not found in PATH
    return false;
  }
}
