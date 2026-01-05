//! Asynchronous embedding operations using background threads.
//!
//! This module provides infrastructure for non-blocking embedding operations.
//! Instead of blocking the Dart UI thread, operations run on background threads
//! and Dart polls for results.
//!
//! ## Pattern (from rhai_dart)
//! 1. Dart calls `start_*` function → returns operation_id immediately
//! 2. Rust spawns std::thread to do the work
//! 3. Dart polls `poll_async_result(op_id)` with 10ms delays
//! 4. When ready, Dart gets the result and frees memory

use crate::{
    clear_last_error, set_last_error, CEmbedData, CEmbedDataBatch, CEmbedder, CTextEmbedConfig,
    CTextEmbedding, CTextEmbeddingBatch, RUNTIME,
};
use embed_anything::config::TextEmbedConfig;
use embed_anything::embeddings::embed::{EmbedData, Embedder, EmbeddingResult};
use embed_anything::Dtype;
use lazy_static::lazy_static;
use std::collections::HashMap;
use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::path::PathBuf;
use std::sync::atomic::{AtomicI64, Ordering};
use std::sync::{Arc, Mutex};
use std::thread;
use tokio_util::sync::CancellationToken;

// ============================================================================
// Result Types for Async Operations
// ============================================================================

/// Status of an async operation
#[derive(Debug, Clone)]
pub enum AsyncOperationStatus {
    InProgress,
    Success,
    Error(String),
    Cancelled,
}

/// Result data for single text embedding
pub struct SingleEmbeddingResult {
    pub values: Vec<f32>,
}

/// Result data for batch text embedding
pub struct BatchEmbeddingResult {
    pub embeddings: Vec<Vec<f32>>,
}

/// Result data for file/directory embedding
pub struct FileEmbeddingResult {
    pub items: Vec<EmbedData>,
}

/// Result data for model loading
pub struct ModelLoadResult {
    pub embedder: Arc<Embedder>,
}

/// Union of all possible async results
pub enum AsyncResultData {
    SingleEmbedding(SingleEmbeddingResult),
    BatchEmbedding(BatchEmbeddingResult),
    FileEmbedding(FileEmbeddingResult),
    ModelLoad(ModelLoadResult),
}

/// Entry in the async operations registry
pub struct AsyncOperation {
    pub status: AsyncOperationStatus,
    pub result: Option<AsyncResultData>,
    pub cancel_token: CancellationToken,
}

// ============================================================================
// Global Registry
// ============================================================================

lazy_static! {
    /// Registry of all async operations.
    /// Maps operation IDs to their current state and results.
    static ref ASYNC_OPERATIONS: Arc<Mutex<HashMap<i64, AsyncOperation>>> =
        Arc::new(Mutex::new(HashMap::new()));
}

/// Atomic counter for generating unique operation IDs.
static NEXT_OPERATION_ID: AtomicI64 = AtomicI64::new(1);

// ============================================================================
// C-Compatible Result Types
// ============================================================================

/// Result type identifier for CAsyncPollResult
#[repr(i32)]
pub enum AsyncResultType {
    SingleEmbedding = 0,
    BatchEmbedding = 1,
    FileEmbedding = 2,
    ModelLoad = 3,
}

/// C-compatible result structure for polling async operations.
#[repr(C)]
pub struct CAsyncPollResult {
    /// Status: 0=pending, 1=success, -1=error, -2=cancelled
    pub status: i32,
    /// Result type: 0=single, 1=batch, 2=file, 3=model
    pub result_type: i32,
    /// Pointer to result data (type depends on result_type)
    pub data: *mut std::ffi::c_void,
    /// Error message (only set if status == -1)
    pub error_message: *mut c_char,
}

impl Default for CAsyncPollResult {
    fn default() -> Self {
        Self {
            status: 0,
            result_type: 0,
            data: std::ptr::null_mut(),
            error_message: std::ptr::null_mut(),
        }
    }
}

// ============================================================================
// Helper Functions
// ============================================================================

/// Store a successful result in the registry.
fn store_success(op_id: i64, result: AsyncResultData) {
    let mut ops = ASYNC_OPERATIONS.lock().unwrap();
    if let Some(op) = ops.get_mut(&op_id) {
        op.status = AsyncOperationStatus::Success;
        op.result = Some(result);
    }
}

/// Store an error result in the registry.
fn store_error(op_id: i64, error: String) {
    let mut ops = ASYNC_OPERATIONS.lock().unwrap();
    if let Some(op) = ops.get_mut(&op_id) {
        op.status = AsyncOperationStatus::Error(error);
    }
}

/// Store a cancelled result in the registry.
fn store_cancelled(op_id: i64) {
    let mut ops = ASYNC_OPERATIONS.lock().unwrap();
    if let Some(op) = ops.get_mut(&op_id) {
        op.status = AsyncOperationStatus::Cancelled;
    }
}

/// Register a new async operation and return its ID.
fn register_operation() -> (i64, CancellationToken) {
    let op_id = NEXT_OPERATION_ID.fetch_add(1, Ordering::SeqCst);
    let cancel_token = CancellationToken::new();

    {
        let mut ops = ASYNC_OPERATIONS.lock().unwrap();
        ops.insert(
            op_id,
            AsyncOperation {
                status: AsyncOperationStatus::InProgress,
                result: None,
                cancel_token: cancel_token.clone(),
            },
        );
    }

    (op_id, cancel_token)
}

/// Convert Vec<f32> to C pointer with ownership transfer.
/// The caller must free this memory.
fn vec_to_c_ptr(vec: Vec<f32>) -> (*mut f32, usize) {
    let len = vec.len();
    let mut boxed = vec.into_boxed_slice();
    let ptr = boxed.as_mut_ptr();
    std::mem::forget(boxed);
    (ptr, len)
}

// ============================================================================
// Async Model Loading
// ============================================================================

/// Start loading a model asynchronously.
///
/// # Parameters
/// - model_id: Model identifier (e.g., "sentence-transformers/all-MiniLM-L6-v2")
/// - revision: Git revision (e.g., "main"), or NULL for default
/// - dtype: Data type for model weights (0=F32, 1=F16, -1=default)
///
/// # Returns
/// Operation ID (positive) on success, -1 on immediate failure.
#[no_mangle]
#[allow(clippy::not_unsafe_ptr_arg_deref)]
pub extern "C" fn start_load_model(
    model_id: *const c_char,
    revision: *const c_char,
    dtype: i32,
) -> i64 {
    clear_last_error();

    // Validate inputs
    if model_id.is_null() {
        set_last_error("INVALID_CONFIG: model_id: cannot be null");
        return -1;
    }

    // Convert C strings to Rust strings
    let model_id_str = unsafe {
        match CStr::from_ptr(model_id).to_str() {
            Ok(s) => s.to_string(),
            Err(_) => {
                set_last_error("INVALID_CONFIG: model_id: invalid UTF-8 encoding");
                return -1;
            }
        }
    };

    let revision_opt = if revision.is_null() {
        None
    } else {
        unsafe {
            match CStr::from_ptr(revision).to_str() {
                Ok(s) => Some(s.to_string()),
                Err(_) => {
                    set_last_error("INVALID_CONFIG: revision: invalid UTF-8 encoding");
                    return -1;
                }
            }
        }
    };

    // Map dtype parameter to Dtype enum
    let dtype_opt = match dtype {
        0 => Some(Dtype::F32),
        1 => Some(Dtype::F16),
        -1 => None,
        _ => {
            set_last_error(&format!("INVALID_CONFIG: dtype: invalid value {}", dtype));
            return -1;
        }
    };

    // Register operation
    let (op_id, cancel_token) = register_operation();

    // Spawn background thread
    thread::spawn(move || {
        // Check cancellation before starting
        if cancel_token.is_cancelled() {
            store_cancelled(op_id);
            return;
        }

        // Load model (synchronous in EmbedAnything)
        let result = Embedder::from_pretrained_hf(
            &model_id_str,
            revision_opt.as_deref(),
            None, // token
            dtype_opt,
        );

        // Check cancellation after loading
        if cancel_token.is_cancelled() {
            store_cancelled(op_id);
            return;
        }

        // Store result
        match result {
            Ok(embedder) => {
                store_success(
                    op_id,
                    AsyncResultData::ModelLoad(ModelLoadResult {
                        embedder: Arc::new(embedder),
                    }),
                );
            }
            Err(e) => {
                let error_str = e.to_string().to_lowercase();
                if error_str.contains("404") {
                    store_error(op_id, format!("MODEL_NOT_FOUND: {}", model_id_str));
                } else {
                    store_error(
                        op_id,
                        format!(
                            "EMBEDDING_FAILED: Failed to load model '{}': {}",
                            model_id_str, e
                        ),
                    );
                }
            }
        }
    });

    op_id
}

// ============================================================================
// Async Text Embedding
// ============================================================================

/// Start embedding a single text asynchronously.
///
/// # Parameters
/// - embedder: Pointer to CEmbedder
/// - text: Text to embed
///
/// # Returns
/// Operation ID (positive) on success, -1 on immediate failure.
#[no_mangle]
#[allow(clippy::not_unsafe_ptr_arg_deref)]
pub extern "C" fn start_embed_text(embedder: *const CEmbedder, text: *const c_char) -> i64 {
    clear_last_error();

    // Validate inputs
    if embedder.is_null() {
        set_last_error("FFI_ERROR: embedder pointer is null");
        return -1;
    }
    if text.is_null() {
        set_last_error("INVALID_CONFIG: text: cannot be null");
        return -1;
    }

    // Clone Arc<Embedder> for thread
    let embedder_arc = unsafe { &*embedder }.inner.clone();

    // Convert C string to Rust string
    let text_str = unsafe {
        match CStr::from_ptr(text).to_str() {
            Ok(s) => s.to_string(),
            Err(_) => {
                set_last_error("INVALID_CONFIG: text: invalid UTF-8 encoding");
                return -1;
            }
        }
    };

    // Register operation
    let (op_id, cancel_token) = register_operation();

    // Spawn background thread
    thread::spawn(move || {
        // Check cancellation
        if cancel_token.is_cancelled() {
            store_cancelled(op_id);
            return;
        }

        // Run embedding in tokio runtime (inside thread, so doesn't block Dart)
        let result = RUNTIME.block_on(async { embedder_arc.embed_query(&[&text_str], None).await });

        // Check cancellation
        if cancel_token.is_cancelled() {
            store_cancelled(op_id);
            return;
        }

        // Process result
        match result {
            Ok(embed_data_vec) => {
                if embed_data_vec.is_empty() {
                    store_error(op_id, "EMBEDDING_FAILED: embed_query returned empty result".to_string());
                    return;
                }

                let embed_data = &embed_data_vec[0];

                // Extract vector from EmbeddingResult enum
                match &embed_data.embedding {
                    EmbeddingResult::DenseVector(vec) => {
                        if vec.is_empty() {
                            store_error(
                                op_id,
                                "EMBEDDING_FAILED: Generated embedding vector is empty".to_string(),
                            );
                            return;
                        }
                        store_success(
                            op_id,
                            AsyncResultData::SingleEmbedding(SingleEmbeddingResult {
                                values: vec.clone(),
                            }),
                        );
                    }
                    EmbeddingResult::MultiVector(_) => {
                        store_error(
                            op_id,
                            "MULTI_VECTOR: Multi-vector embeddings are not supported".to_string(),
                        );
                    }
                }
            }
            Err(e) => {
                store_error(
                    op_id,
                    format!("EMBEDDING_FAILED: Text embedding generation failed: {}", e),
                );
            }
        }
    });

    op_id
}

// ============================================================================
// Async Batch Text Embedding
// ============================================================================

/// Start embedding multiple texts asynchronously.
///
/// # Parameters
/// - embedder: Pointer to CEmbedder
/// - texts: Array of text pointers
/// - count: Number of texts
///
/// # Returns
/// Operation ID (positive) on success, -1 on immediate failure.
#[no_mangle]
#[allow(clippy::not_unsafe_ptr_arg_deref)]
pub extern "C" fn start_embed_texts_batch(
    embedder: *const CEmbedder,
    texts: *const *const c_char,
    count: usize,
) -> i64 {
    clear_last_error();

    // Validate inputs
    if embedder.is_null() {
        set_last_error("FFI_ERROR: embedder pointer is null");
        return -1;
    }
    if texts.is_null() {
        set_last_error("INVALID_CONFIG: texts: cannot be null");
        return -1;
    }
    if count == 0 {
        set_last_error("INVALID_CONFIG: count: must be greater than 0");
        return -1;
    }

    // Clone Arc<Embedder> for thread
    let embedder_arc = unsafe { &*embedder }.inner.clone();

    // Convert C string array to Rust Vec<String>
    let texts_slice = unsafe { std::slice::from_raw_parts(texts, count) };
    let mut text_strings = Vec::with_capacity(count);

    for &text_ptr in texts_slice {
        if text_ptr.is_null() {
            set_last_error("INVALID_CONFIG: texts: array contains null pointer");
            return -1;
        }

        let text_str = unsafe {
            match CStr::from_ptr(text_ptr).to_str() {
                Ok(s) => s.to_string(),
                Err(_) => {
                    set_last_error("INVALID_CONFIG: texts: array contains invalid UTF-8");
                    return -1;
                }
            }
        };
        text_strings.push(text_str);
    }

    // Register operation
    let (op_id, cancel_token) = register_operation();

    // Spawn background thread
    thread::spawn(move || {
        // Check cancellation
        if cancel_token.is_cancelled() {
            store_cancelled(op_id);
            return;
        }

        // Convert to Vec<&str> for embed function
        let text_refs: Vec<&str> = text_strings.iter().map(|s| s.as_str()).collect();

        // Run embedding in tokio runtime
        let result = RUNTIME.block_on(async { embedder_arc.embed(&text_refs, None, None).await });

        // Check cancellation
        if cancel_token.is_cancelled() {
            store_cancelled(op_id);
            return;
        }

        // Process result
        match result {
            Ok(embedding_results) => {
                let mut embeddings = Vec::with_capacity(embedding_results.len());

                for embedding_result in embedding_results {
                    match embedding_result {
                        EmbeddingResult::DenseVector(vec) => {
                            if vec.is_empty() {
                                store_error(
                                    op_id,
                                    "EMBEDDING_FAILED: Generated embedding vector is empty"
                                        .to_string(),
                                );
                                return;
                            }
                            embeddings.push(vec);
                        }
                        EmbeddingResult::MultiVector(_) => {
                            store_error(
                                op_id,
                                "MULTI_VECTOR: Multi-vector embeddings are not supported"
                                    .to_string(),
                            );
                            return;
                        }
                    }
                }

                store_success(
                    op_id,
                    AsyncResultData::BatchEmbedding(BatchEmbeddingResult { embeddings }),
                );
            }
            Err(e) => {
                store_error(
                    op_id,
                    format!(
                        "EMBEDDING_FAILED: Batch embedding generation failed for {} texts: {}",
                        count, e
                    ),
                );
            }
        }
    });

    op_id
}

// ============================================================================
// Async File Embedding
// ============================================================================

/// Start embedding a file asynchronously.
///
/// # Parameters
/// - embedder: Embedder handle
/// - file_path: Path to file (C string)
/// - config: Pointer to CTextEmbedConfig
///
/// # Returns
/// Operation ID (positive) on success, -1 on immediate failure.
#[no_mangle]
#[allow(clippy::not_unsafe_ptr_arg_deref)]
pub extern "C" fn start_embed_file(
    embedder: *const CEmbedder,
    file_path: *const c_char,
    config: *const CTextEmbedConfig,
) -> i64 {
    clear_last_error();

    // Validate pointers
    if embedder.is_null() {
        set_last_error("FFI_ERROR: embedder pointer is null");
        return -1;
    }
    if file_path.is_null() {
        set_last_error("INVALID_CONFIG: file_path: cannot be null");
        return -1;
    }
    if config.is_null() {
        set_last_error("INVALID_CONFIG: config: cannot be null");
        return -1;
    }

    let embedder_arc = unsafe { &*embedder }.inner.clone();
    let config_ref = unsafe { &*config };

    // Convert C string to Rust Path
    let file_path_str = unsafe {
        match CStr::from_ptr(file_path).to_str() {
            Ok(s) => s.to_string(),
            Err(_) => {
                set_last_error("INVALID_CONFIG: file_path: invalid UTF-8 encoding");
                return -1;
            }
        }
    };

    // Check if file exists before spawning thread
    let path = PathBuf::from(&file_path_str);
    if !path.exists() {
        set_last_error(&format!("FILE_NOT_FOUND: {}", file_path_str));
        return -1;
    }

    // Build TextEmbedConfig from CTextEmbedConfig
    let text_config = TextEmbedConfig {
        chunk_size: Some(config_ref.chunk_size),
        overlap_ratio: Some(config_ref.overlap_ratio),
        batch_size: Some(config_ref.batch_size),
        buffer_size: Some(config_ref.buffer_size),
        ..Default::default()
    };

    // Register operation
    let (op_id, cancel_token) = register_operation();

    // Spawn background thread
    thread::spawn(move || {
        // Check cancellation
        if cancel_token.is_cancelled() {
            store_cancelled(op_id);
            return;
        }

        // Run embedding in tokio runtime
        let result = RUNTIME.block_on(async {
            embedder_arc
                .embed_file(path.clone(), Some(&text_config), None)
                .await
        });

        // Check cancellation
        if cancel_token.is_cancelled() {
            store_cancelled(op_id);
            return;
        }

        // Process result
        match result {
            Ok(Some(embed_data_vec)) => {
                store_success(
                    op_id,
                    AsyncResultData::FileEmbedding(FileEmbeddingResult {
                        items: embed_data_vec,
                    }),
                );
            }
            Ok(None) => {
                store_error(op_id, "EMBEDDING_FAILED: embed_file returned None".to_string());
            }
            Err(e) => {
                let error_str = e.to_string().to_lowercase();
                if error_str.contains("not found") || error_str.contains("no such file") {
                    store_error(op_id, format!("FILE_NOT_FOUND: {}", file_path_str));
                } else if error_str.contains("unsupported") || error_str.contains("format") {
                    store_error(op_id, format!("UNSUPPORTED_FORMAT: {}", file_path_str));
                } else if error_str.contains("permission") || error_str.contains("access denied") {
                    store_error(op_id, format!("FILE_READ_ERROR: {}", e));
                } else {
                    store_error(op_id, format!("EMBEDDING_FAILED: {}", e));
                }
            }
        }
    });

    op_id
}

// ============================================================================
// Async Directory Embedding
// ============================================================================

/// Start embedding a directory asynchronously.
///
/// # Parameters
/// - embedder: Embedder handle
/// - directory_path: Path to directory (C string)
/// - extensions: NULL-terminated array of extension strings, or NULL for all files
/// - extensions_count: Number of extensions (0 if extensions is NULL)
/// - config: Pointer to CTextEmbedConfig
///
/// # Returns
/// Operation ID (positive) on success, -1 on immediate failure.
#[no_mangle]
#[allow(clippy::not_unsafe_ptr_arg_deref)]
pub extern "C" fn start_embed_directory(
    embedder: *const CEmbedder,
    directory_path: *const c_char,
    extensions: *const *const c_char,
    extensions_count: usize,
    config: *const CTextEmbedConfig,
) -> i64 {
    clear_last_error();

    // Validate pointers
    if embedder.is_null() {
        set_last_error("FFI_ERROR: embedder pointer is null");
        return -1;
    }
    if directory_path.is_null() {
        set_last_error("INVALID_CONFIG: directory_path: cannot be null");
        return -1;
    }
    if config.is_null() {
        set_last_error("INVALID_CONFIG: config: cannot be null");
        return -1;
    }

    let embedder_arc = unsafe { &*embedder }.inner.clone();
    let config_ref = unsafe { &*config };

    // Convert C string to Rust PathBuf
    let dir_path_str = unsafe {
        match CStr::from_ptr(directory_path).to_str() {
            Ok(s) => s.to_string(),
            Err(_) => {
                set_last_error("INVALID_CONFIG: directory_path: invalid UTF-8 encoding");
                return -1;
            }
        }
    };

    let dir_path = PathBuf::from(&dir_path_str);

    // Check if directory exists
    if !dir_path.exists() {
        set_last_error(&format!("FILE_NOT_FOUND: {}", dir_path_str));
        return -1;
    }

    // Convert C string array to Vec<String> for extensions
    let extensions_opt = if extensions.is_null() || extensions_count == 0 {
        None
    } else {
        let ext_slice = unsafe { std::slice::from_raw_parts(extensions, extensions_count) };
        let mut ext_vec = Vec::with_capacity(extensions_count);

        for &ext_ptr in ext_slice {
            if ext_ptr.is_null() {
                set_last_error("INVALID_CONFIG: extensions: array contains null pointer");
                return -1;
            }

            let ext_str = unsafe {
                match CStr::from_ptr(ext_ptr).to_str() {
                    Ok(s) => s.to_string(),
                    Err(_) => {
                        set_last_error("INVALID_CONFIG: extensions: invalid UTF-8");
                        return -1;
                    }
                }
            };
            ext_vec.push(ext_str);
        }

        Some(ext_vec)
    };

    // Build TextEmbedConfig from CTextEmbedConfig
    let text_config = TextEmbedConfig {
        chunk_size: Some(config_ref.chunk_size),
        overlap_ratio: Some(config_ref.overlap_ratio),
        batch_size: Some(config_ref.batch_size),
        buffer_size: Some(config_ref.buffer_size),
        ..Default::default()
    };

    // Register operation
    let (op_id, cancel_token) = register_operation();

    // Spawn background thread
    thread::spawn(move || {
        // Check cancellation
        if cancel_token.is_cancelled() {
            store_cancelled(op_id);
            return;
        }

        // Run embedding in tokio runtime
        let result = RUNTIME.block_on(async {
            embedder_arc
                .embed_directory_stream(dir_path.clone(), extensions_opt, Some(&text_config), None)
                .await
        });

        // Check cancellation
        if cancel_token.is_cancelled() {
            store_cancelled(op_id);
            return;
        }

        // Process result
        match result {
            Ok(Some(embed_data_vec)) => {
                store_success(
                    op_id,
                    AsyncResultData::FileEmbedding(FileEmbeddingResult {
                        items: embed_data_vec,
                    }),
                );
            }
            Ok(None) => {
                store_error(
                    op_id,
                    "EMBEDDING_FAILED: embed_directory_stream returned None".to_string(),
                );
            }
            Err(e) => {
                let error_str = e.to_string().to_lowercase();
                if error_str.contains("not found") || error_str.contains("no such file") {
                    store_error(op_id, format!("FILE_NOT_FOUND: {}", dir_path_str));
                } else if error_str.contains("permission") || error_str.contains("access denied") {
                    store_error(op_id, format!("FILE_READ_ERROR: {}", e));
                } else {
                    store_error(
                        op_id,
                        format!("EMBEDDING_FAILED: Directory embedding failed - {}", e),
                    );
                }
            }
        }
    });

    op_id
}

// ============================================================================
// Polling and Result Retrieval
// ============================================================================

/// Poll for the result of an async operation.
///
/// # Parameters
/// - op_id: The operation ID returned by a start_* function
///
/// # Returns
/// CAsyncPollResult with:
/// - status: 0=pending, 1=success, -1=error, -2=cancelled
/// - result_type: 0=single, 1=batch, 2=file, 3=model
/// - data: Pointer to result data (caller must free)
/// - error_message: Error message if status == -1
#[no_mangle]
pub extern "C" fn poll_async_result(op_id: i64) -> CAsyncPollResult {
    let mut result = CAsyncPollResult::default();

    let mut ops = ASYNC_OPERATIONS.lock().unwrap();

    match ops.get_mut(&op_id) {
        Some(op) => {
            match &op.status {
                AsyncOperationStatus::InProgress => {
                    result.status = 0; // Pending
                }
                AsyncOperationStatus::Success => {
                    result.status = 1; // Success

                    // Take ownership of the result and convert to C types
                    if let Some(async_result) = op.result.take() {
                        match async_result {
                            AsyncResultData::SingleEmbedding(single) => {
                                result.result_type = AsyncResultType::SingleEmbedding as i32;
                                let (ptr, len) = vec_to_c_ptr(single.values);

                                // Allocate CTextEmbedding
                                let c_embedding =
                                    Box::new(CTextEmbedding { values: ptr, len });
                                result.data = Box::into_raw(c_embedding) as *mut std::ffi::c_void;
                            }
                            AsyncResultData::BatchEmbedding(batch) => {
                                result.result_type = AsyncResultType::BatchEmbedding as i32;

                                // Convert batch to CTextEmbeddingBatch
                                let mut c_embeddings = Vec::with_capacity(batch.embeddings.len());
                                for embedding in batch.embeddings {
                                    let (ptr, len) = vec_to_c_ptr(embedding);
                                    c_embeddings.push(CTextEmbedding { values: ptr, len });
                                }

                                let batch_len = c_embeddings.len();
                                let mut boxed_embeddings = c_embeddings.into_boxed_slice();
                                let embeddings_ptr = boxed_embeddings.as_mut_ptr();
                                std::mem::forget(boxed_embeddings);

                                let c_batch = Box::new(CTextEmbeddingBatch {
                                    embeddings: embeddings_ptr,
                                    count: batch_len,
                                });
                                result.data = Box::into_raw(c_batch) as *mut std::ffi::c_void;
                            }
                            AsyncResultData::FileEmbedding(file_result) => {
                                result.result_type = AsyncResultType::FileEmbedding as i32;

                                // Convert to CEmbedDataBatch
                                match convert_file_result_to_c(file_result.items) {
                                    Ok(batch_ptr) => {
                                        result.data = batch_ptr as *mut std::ffi::c_void;
                                    }
                                    Err(e) => {
                                        result.status = -1;
                                        if let Ok(cstring) = CString::new(e) {
                                            result.error_message = cstring.into_raw();
                                        }
                                    }
                                }
                            }
                            AsyncResultData::ModelLoad(model_result) => {
                                result.result_type = AsyncResultType::ModelLoad as i32;

                                // Create CEmbedder and return pointer
                                let c_embedder = Box::new(CEmbedder {
                                    inner: model_result.embedder,
                                });
                                result.data = Box::into_raw(c_embedder) as *mut std::ffi::c_void;
                            }
                        }
                    }

                    // Remove from registry
                    ops.remove(&op_id);
                }
                AsyncOperationStatus::Error(msg) => {
                    result.status = -1; // Error

                    if let Ok(cstring) = CString::new(msg.clone()) {
                        result.error_message = cstring.into_raw();
                    }

                    // Remove from registry
                    ops.remove(&op_id);
                }
                AsyncOperationStatus::Cancelled => {
                    result.status = -2; // Cancelled

                    // Remove from registry
                    ops.remove(&op_id);
                }
            }
        }
        None => {
            result.status = -1; // Error
            if let Ok(cstring) = CString::new(format!("Invalid operation ID: {}", op_id)) {
                result.error_message = cstring.into_raw();
            }
        }
    }

    result
}

/// Convert file embedding result to C-compatible batch.
fn convert_file_result_to_c(items: Vec<EmbedData>) -> Result<*mut CEmbedDataBatch, String> {
    let mut c_items = Vec::with_capacity(items.len());

    for data in items {
        // Extract Vec<f32> from EmbeddingResult::DenseVector
        let embedding_vec = match data.embedding {
            EmbeddingResult::DenseVector(vec) => vec,
            EmbeddingResult::MultiVector(_) => {
                return Err(
                    "MULTI_VECTOR_NOT_SUPPORTED: Multi-vector embeddings are not supported"
                        .to_string(),
                );
            }
        };

        // Convert embedding vector
        let embedding_len = embedding_vec.len();
        let mut boxed_embedding = embedding_vec.into_boxed_slice();
        let embedding_values = boxed_embedding.as_mut_ptr();
        std::mem::forget(boxed_embedding);

        // Combine text and metadata into single JSON object
        let text_and_metadata_json = {
            use serde_json::json;

            let combined = json!({
                "text": data.text,
                "metadata": data.metadata
            });

            match serde_json::to_string(&combined) {
                Ok(json_str) => match CString::new(json_str) {
                    Ok(cstring) => cstring.into_raw(),
                    Err(_) => std::ptr::null_mut(),
                },
                Err(_) => std::ptr::null_mut(),
            }
        };

        c_items.push(CEmbedData {
            embedding_values,
            embedding_len,
            text_and_metadata_json,
        });
    }

    let count = c_items.len();
    let mut boxed_items = c_items.into_boxed_slice();
    let items = boxed_items.as_mut_ptr();
    std::mem::forget(boxed_items);

    let batch = Box::new(CEmbedDataBatch { items, count });
    Ok(Box::into_raw(batch))
}

// ============================================================================
// Cancellation
// ============================================================================

/// Cancel an async operation.
///
/// # Parameters
/// - op_id: The operation ID to cancel
///
/// # Returns
/// 0 on success, -1 if operation ID not found
#[no_mangle]
pub extern "C" fn cancel_async_operation(op_id: i64) -> i32 {
    let ops = ASYNC_OPERATIONS.lock().unwrap();

    if let Some(op) = ops.get(&op_id) {
        op.cancel_token.cancel();
        0 // Success
    } else {
        set_last_error(&format!("Invalid operation ID: {}", op_id));
        -1 // Not found
    }
}

// ============================================================================
// Memory Cleanup
// ============================================================================

/// Free the error message from a poll result.
#[no_mangle]
#[allow(clippy::not_unsafe_ptr_arg_deref)]
pub extern "C" fn free_async_error_message(ptr: *mut c_char) {
    if !ptr.is_null() {
        unsafe {
            drop(CString::from_raw(ptr));
        }
    }
}

// ============================================================================
// Tests
// ============================================================================

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_register_operation() {
        let (op_id, _token) = register_operation();
        assert!(op_id > 0);

        let ops = ASYNC_OPERATIONS.lock().unwrap();
        assert!(ops.contains_key(&op_id));
    }

    #[test]
    fn test_store_success() {
        let (op_id, _token) = register_operation();

        store_success(
            op_id,
            AsyncResultData::SingleEmbedding(SingleEmbeddingResult {
                values: vec![1.0, 2.0, 3.0],
            }),
        );

        let ops = ASYNC_OPERATIONS.lock().unwrap();
        let op = ops.get(&op_id).unwrap();
        assert!(matches!(op.status, AsyncOperationStatus::Success));
    }

    #[test]
    fn test_store_error() {
        let (op_id, _token) = register_operation();

        store_error(op_id, "Test error".to_string());

        let ops = ASYNC_OPERATIONS.lock().unwrap();
        let op = ops.get(&op_id).unwrap();
        assert!(matches!(op.status, AsyncOperationStatus::Error(_)));
    }

    #[test]
    fn test_cancellation() {
        let (op_id, token) = register_operation();

        assert!(!token.is_cancelled());
        token.cancel();
        assert!(token.is_cancelled());

        store_cancelled(op_id);

        let ops = ASYNC_OPERATIONS.lock().unwrap();
        let op = ops.get(&op_id).unwrap();
        assert!(matches!(op.status, AsyncOperationStatus::Cancelled));
    }

    #[test]
    fn test_vec_to_c_ptr() {
        let vec = vec![1.0f32, 2.0, 3.0];
        let (ptr, len) = vec_to_c_ptr(vec);

        assert!(!ptr.is_null());
        assert_eq!(len, 3);

        // Clean up
        unsafe {
            drop(Vec::from_raw_parts(ptr, len, len));
        }
    }
}
