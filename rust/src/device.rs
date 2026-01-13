//! Device detection and query functions for FFI
//!
//! This module provides runtime detection of available compute devices
//! and exposes functions to query which device is currently active.

// Device import is only used when GPU features are enabled
#[cfg(any(feature = "cuda", feature = "metal"))]
use candle_core::Device;

/// Compute device types exposed to Dart via FFI.
///
/// The numeric values correspond to the Dart `ComputeDevice` enum values.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[repr(i32)]
pub enum ComputeDevice {
    /// CPU computation (always available)
    Cpu = 0,
    /// NVIDIA CUDA GPU (Linux/Windows with CUDA toolkit)
    Cuda = 1,
    /// Apple Metal GPU (macOS/iOS)
    Metal = 2,
}

/// Get the currently active device type based on compiled features and availability.
///
/// This follows the same priority order as EmbedAnything's `select_device()`:
/// 1. Metal (if compiled with `metal` feature and GPU available)
/// 2. CUDA (if compiled with `cuda` feature and GPU available)
/// 3. CPU (fallback, always available)
///
/// Note: MKL and Accelerate features optimize CPU operations but don't change
/// the device type - they're linked at compile time for faster math operations.
pub fn get_active_device_type() -> ComputeDevice {
    // Try Metal first (macOS/iOS)
    #[cfg(feature = "metal")]
    {
        if Device::new_metal(0).is_ok() {
            return ComputeDevice::Metal;
        }
    }

    // Try CUDA (Linux/Windows with NVIDIA GPU)
    #[cfg(feature = "cuda")]
    {
        if let Ok(device) = Device::cuda_if_available(0) {
            // cuda_if_available returns Device::Cpu if CUDA is not available
            if !matches!(device, Device::Cpu) {
                return ComputeDevice::Cuda;
            }
        }
    }

    // Fallback to CPU (always available)
    // Note: MKL/Accelerate optimizations are applied automatically if compiled in
    ComputeDevice::Cpu
}

/// Check if a specific device type is available.
///
/// Returns `true` if the device can be used for computation, `false` otherwise.
pub fn is_device_available(device: ComputeDevice) -> bool {
    match device {
        ComputeDevice::Cpu => true, // CPU is always available

        ComputeDevice::Cuda => {
            #[cfg(feature = "cuda")]
            {
                Device::cuda_if_available(0)
                    .map(|d| !matches!(d, Device::Cpu))
                    .unwrap_or(false)
            }
            #[cfg(not(feature = "cuda"))]
            {
                false // CUDA feature not compiled in
            }
        }

        ComputeDevice::Metal => {
            #[cfg(feature = "metal")]
            {
                Device::new_metal(0).is_ok()
            }
            #[cfg(not(feature = "metal"))]
            {
                false // Metal feature not compiled in
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_cpu_always_available() {
        assert!(is_device_available(ComputeDevice::Cpu));
    }

    #[test]
    fn test_get_active_device_returns_valid_device() {
        let device = get_active_device_type();
        // The active device should always be available
        assert!(is_device_available(device));
    }

    #[test]
    fn test_device_enum_values() {
        // Verify enum values match Dart ComputeDevice
        assert_eq!(ComputeDevice::Cpu as i32, 0);
        assert_eq!(ComputeDevice::Cuda as i32, 1);
        assert_eq!(ComputeDevice::Metal as i32, 2);
    }
}
