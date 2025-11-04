use std::cell::RefCell;
use std::ffi::{CStr, CString};
use std::os::raw::{c_char, c_void};
use std::panic;
use std::path::PathBuf;
use std::sync::Arc;

use embed_anything::config::TextEmbedConfig;
use embed_anything::embeddings::embed::{EmbedData, Embedder, EmbeddingResult};
use embed_anything::text_loader::TextLoader;
use embed_anything::Dtype;
use once_cell::sync::Lazy;
use tokio::runtime::Runtime;

// ============================================================================
// Thread-Local Error Storage
// ============================================================================

thread_local! {
    static LAST_ERROR: RefCell<Option<String>> = const { RefCell::new(None) };
}

fn set_last_error(error: &str) {
    LAST_ERROR.with(|e| *e.borrow_mut() = Some(error.to_string()));
}

fn clear_last_error() {
    LAST_ERROR.with(|e| *e.borrow_mut() = None);
}

#[no_mangle]
pub extern "C" fn get_last_error() -> *mut c_char {
    LAST_ERROR.with(|e| match e.borrow_mut().take() {
        Some(err) => match CString::new(err) {
            Ok(cstr) => cstr.into_raw(),
            Err(_) => std::ptr::null_mut(),
        },
        None => std::ptr::null_mut(),
    })
}

#[no_mangle]
#[allow(clippy::not_unsafe_ptr_arg_deref)]
pub extern "C" fn free_error_string(ptr: *mut c_char) {
    if !ptr.is_null() {
        unsafe {
            drop(CString::from_raw(ptr));
        }
    }
}

// ============================================================================
// Tokio Runtime Initialization
// ============================================================================

static RUNTIME: Lazy<Runtime> = Lazy::new(|| {
    tokio::runtime::Builder::new_multi_thread()
        .enable_all()
        .build()
        .expect("Failed to create Tokio runtime")
});

#[no_mangle]
pub extern "C" fn init_runtime() -> i32 {
    match panic::catch_unwind(|| {
        Lazy::force(&RUNTIME);
        0
    }) {
        Ok(result) => result,
        Err(_) => {
            set_last_error("FFI_ERROR: Failed to initialize Tokio runtime");
            -1
        }
    }
}

// ============================================================================
// Opaque Handle for Embedder
// ============================================================================

pub struct CEmbedder {
    inner: Arc<Embedder>,
}

// ============================================================================
// FFI Types for Text Embeddings
// ============================================================================

#[repr(C)]
pub struct CTextEmbedding {
    pub values: *mut f32,
    pub len: usize,
}

#[repr(C)]
pub struct CTextEmbeddingBatch {
    pub embeddings: *mut CTextEmbedding,
    pub count: usize,
}

// ============================================================================
// FFI Types for File/Directory Embeddings (Phase 3)
// ============================================================================

/// C-compatible configuration for text embedding
#[repr(C)]
pub struct CTextEmbedConfig {
    pub chunk_size: usize,
    pub overlap_ratio: f32,
    pub batch_size: usize,
    pub buffer_size: usize,
}

/// C-compatible representation of EmbedData
#[repr(C)]
pub struct CEmbedData {
    pub embedding_values: *mut f32,
    pub embedding_len: usize,
    pub text: *mut c_char,           // NULL if no text
    pub metadata_json: *mut c_char,  // JSON string or NULL
}

/// Batch of CEmbedData
#[repr(C)]
pub struct CEmbedDataBatch {
    pub items: *mut CEmbedData,
    pub count: usize,
}

/// Type alias for streaming callback
/// Called from Rust with batches of embeddings
type StreamCallback = extern "C" fn(*mut CEmbedDataBatch, *mut c_void);

// ============================================================================
// Helper Functions
// ============================================================================

/// Convert Rust EmbedData to C-compatible CEmbedData
///
/// # Safety
/// This function uses std::mem::forget() to transfer ownership to Dart.
/// The caller MUST call free_embed_data() to reclaim memory.
fn embed_data_to_c(data: EmbedData) -> Result<CEmbedData, String> {
    // Extract Vec<f32> from EmbeddingResult::DenseVector
    let embedding_vec = match data.embedding {
        EmbeddingResult::DenseVector(vec) => vec,
        EmbeddingResult::MultiVector(_) => {
            return Err("MULTI_VECTOR_NOT_SUPPORTED: Multi-vector embeddings are not supported in this version".to_string());
        }
    };

    // Convert embedding vector
    let embedding_len = embedding_vec.len();
    let mut boxed_embedding = embedding_vec.into_boxed_slice();
    let embedding_values = boxed_embedding.as_mut_ptr();
    std::mem::forget(boxed_embedding); // Transfer ownership to Dart

    // Convert Option<String> text to *mut c_char (NULL if None)
    let text = match data.text {
        Some(text_str) => match CString::new(text_str) {
            Ok(cstring) => cstring.into_raw(),
            Err(_) => std::ptr::null_mut(),
        },
        None => std::ptr::null_mut(),
    };

    // Serialize HashMap<String, String> metadata to JSON string
    let metadata_json = match data.metadata {
        Some(metadata_map) => {
            match serde_json::to_string(&metadata_map) {
                Ok(json_str) => match CString::new(json_str) {
                    Ok(cstring) => cstring.into_raw(),
                    Err(_) => std::ptr::null_mut(),
                },
                Err(_) => std::ptr::null_mut(),
            }
        }
        None => std::ptr::null_mut(),
    };

    Ok(CEmbedData {
        embedding_values,
        embedding_len,
        text,
        metadata_json,
    })
}

/// Convert Vec<EmbedData> to CEmbedDataBatch
///
/// # Safety
/// This function uses std::mem::forget() to transfer ownership to Dart.
/// The caller MUST call free_embed_data_batch() to reclaim memory.
fn embed_data_vec_to_batch(data_vec: Vec<EmbedData>) -> Result<*mut CEmbedDataBatch, String> {
    let mut c_items = Vec::with_capacity(data_vec.len());

    for data in data_vec {
        match embed_data_to_c(data) {
            Ok(c_data) => c_items.push(c_data),
            Err(e) => {
                // Clean up already-allocated items
                for item in c_items {
                    unsafe {
                        free_embed_data_single(item);
                    }
                }
                return Err(e);
            }
        }
    }

    let count = c_items.len();
    let mut boxed_items = c_items.into_boxed_slice();
    let items = boxed_items.as_mut_ptr();
    std::mem::forget(boxed_items);

    let batch = Box::new(CEmbedDataBatch { items, count });
    Ok(Box::into_raw(batch))
}

/// Free a single CEmbedData (helper for cleanup)
unsafe fn free_embed_data_single(data: CEmbedData) {
    if !data.embedding_values.is_null() {
        drop(Vec::from_raw_parts(
            data.embedding_values,
            data.embedding_len,
            data.embedding_len,
        ));
    }
    if !data.text.is_null() {
        drop(CString::from_raw(data.text));
    }
    if !data.metadata_json.is_null() {
        drop(CString::from_raw(data.metadata_json));
    }
}

// ============================================================================
// Model Loading Functions
// ============================================================================

/// Creates an embedder from a pretrained HuggingFace model
///
/// # Parameters
/// - model_type: Currently unused (for backward compatibility)
/// - model_id: Model identifier (e.g., "sentence-transformers/all-MiniLM-L6-v2")
/// - revision: Git revision (e.g., "main"), or NULL for default
/// - dtype: Data type for model weights (0=F32, 1=F16, -1=default)
///
/// # Returns
/// - Pointer to CEmbedder on success
/// - NULL on failure (check get_last_error)
#[no_mangle]
#[allow(clippy::not_unsafe_ptr_arg_deref)]
pub extern "C" fn embedder_from_pretrained_hf(
    _model_type: u8,
    model_id: *const c_char,
    revision: *const c_char,
    dtype: i32,
) -> *mut CEmbedder {
    clear_last_error();

    // Validate inputs
    if model_id.is_null() {
        set_last_error("INVALID_CONFIG: model_id: cannot be null");
        return std::ptr::null_mut();
    }

    // Convert C strings to Rust strings
    let model_id_str = unsafe {
        match CStr::from_ptr(model_id).to_str() {
            Ok(s) => s,
            Err(_) => {
                set_last_error("INVALID_CONFIG: model_id: invalid UTF-8 encoding");
                return std::ptr::null_mut();
            }
        }
    };

    let revision_opt = if revision.is_null() {
        None
    } else {
        unsafe {
            match CStr::from_ptr(revision).to_str() {
                Ok(s) => Some(s),
                Err(_) => {
                    set_last_error("INVALID_CONFIG: revision: invalid UTF-8 encoding");
                    return std::ptr::null_mut();
                }
            }
        }
    };

    // Map dtype parameter to Dtype enum
    let dtype_opt = match dtype {
        0 => Some(Dtype::F32),
        1 => Some(Dtype::F16),
        -1 => None, // Use default
        _ => {
            set_last_error(&format!("INVALID_CONFIG: dtype: invalid value {}", dtype));
            return std::ptr::null_mut();
        }
    };

    // Create embedder (synchronous - EmbedAnything auto-detects architecture)
    let embedder_result = Embedder::from_pretrained_hf(
        model_id_str,
        revision_opt,
        None, // token - use default
        dtype_opt,
    );

    match embedder_result {
        Ok(embedder) => {
            let boxed = Box::new(CEmbedder {
                inner: Arc::new(embedder),
            });
            Box::into_raw(boxed)
        }
        Err(e) => {
            let error_str = e.to_string().to_lowercase();
            // Check if error indicates model not found
            // HuggingFace returns 404 status code for non-existent models
            if error_str.contains("404") {
                set_last_error(&format!("MODEL_NOT_FOUND: {}", model_id_str));
            } else {
                set_last_error(&format!(
                    "EMBEDDING_FAILED: Failed to load model '{}': {}",
                    model_id_str, e
                ));
            }
            std::ptr::null_mut()
        }
    }
}

// ============================================================================
// Text Embedding Functions
// ============================================================================

/// Embeds a single text query
///
/// # Parameters
/// - embedder: Pointer to CEmbedder
/// - text: Text to embed
///
/// # Returns
/// - Pointer to CTextEmbedding on success
/// - NULL on failure (check get_last_error)
#[no_mangle]
#[allow(clippy::not_unsafe_ptr_arg_deref)]
pub extern "C" fn embed_text(
    embedder: *const CEmbedder,
    text: *const c_char,
) -> *mut CTextEmbedding {
    clear_last_error();

    // Validate inputs
    if embedder.is_null() {
        set_last_error("FFI_ERROR: embedder pointer is null");
        return std::ptr::null_mut();
    }
    if text.is_null() {
        set_last_error("INVALID_CONFIG: text: cannot be null");
        return std::ptr::null_mut();
    }

    let embedder = unsafe { &*embedder };

    // Convert C string to Rust string
    let text_str = unsafe {
        match CStr::from_ptr(text).to_str() {
            Ok(s) => s,
            Err(_) => {
                set_last_error("INVALID_CONFIG: text: invalid UTF-8 encoding");
                return std::ptr::null_mut();
            }
        }
    };

    // Generate embedding - embed_query takes &[&str] and returns Vec<EmbedData>
    let result = RUNTIME.block_on(async { embedder.inner.embed_query(&[text_str], None).await });

    match result {
        Ok(embed_data_vec) => {
            // Extract the first (and only) EmbedData
            if embed_data_vec.is_empty() {
                set_last_error("EMBEDDING_FAILED: embed_query returned empty result");
                return std::ptr::null_mut();
            }

            let embed_data = &embed_data_vec[0];

            // Extract vector from EmbeddingResult enum
            let embedding_vec = match &embed_data.embedding {
                EmbeddingResult::DenseVector(vec) => vec,
                EmbeddingResult::MultiVector(_) => {
                    set_last_error(
                        "MULTI_VECTOR: Multi-vector embeddings are not supported in this version",
                    );
                    return std::ptr::null_mut();
                }
            };

            // Validate vector is non-empty
            if embedding_vec.is_empty() {
                set_last_error("EMBEDDING_FAILED: Generated embedding vector is empty");
                return std::ptr::null_mut();
            }

            let len = embedding_vec.len();
            let mut boxed = embedding_vec.clone().into_boxed_slice();
            let ptr = boxed.as_mut_ptr();
            std::mem::forget(boxed); // Prevent Rust from freeing

            let c_embedding = Box::new(CTextEmbedding { values: ptr, len });

            Box::into_raw(c_embedding)
        }
        Err(e) => {
            set_last_error(&format!(
                "EMBEDDING_FAILED: Text embedding generation failed: {}",
                e
            ));
            std::ptr::null_mut()
        }
    }
}

/// Embeds a batch of texts
///
/// # Parameters
/// - embedder: Pointer to CEmbedder
/// - texts: Array of text pointers
/// - count: Number of texts
///
/// # Returns
/// - Pointer to CTextEmbeddingBatch on success
/// - NULL on failure (check get_last_error)
#[no_mangle]
#[allow(clippy::not_unsafe_ptr_arg_deref)]
pub extern "C" fn embed_texts_batch(
    embedder: *const CEmbedder,
    texts: *const *const c_char,
    count: usize,
) -> *mut CTextEmbeddingBatch {
    clear_last_error();

    // Validate inputs
    if embedder.is_null() {
        set_last_error("FFI_ERROR: embedder pointer is null");
        return std::ptr::null_mut();
    }
    if texts.is_null() {
        set_last_error("INVALID_CONFIG: texts: cannot be null");
        return std::ptr::null_mut();
    }
    if count == 0 {
        set_last_error("INVALID_CONFIG: count: must be greater than 0");
        return std::ptr::null_mut();
    }

    let embedder = unsafe { &*embedder };

    // Convert C string array to Rust Vec<String>
    let texts_slice = unsafe { std::slice::from_raw_parts(texts, count) };
    let mut text_strings = Vec::with_capacity(count);

    for &text_ptr in texts_slice {
        if text_ptr.is_null() {
            set_last_error("INVALID_CONFIG: texts: array contains null pointer");
            return std::ptr::null_mut();
        }

        let text_str = unsafe {
            match CStr::from_ptr(text_ptr).to_str() {
                Ok(s) => s.to_string(),
                Err(_) => {
                    set_last_error("INVALID_CONFIG: texts: array contains invalid UTF-8");
                    return std::ptr::null_mut();
                }
            }
        };
        text_strings.push(text_str);
    }

    // Convert to Vec<&str> for embed function
    let text_refs: Vec<&str> = text_strings.iter().map(|s| s.as_str()).collect();

    // Generate embeddings - embed() returns Vec<EmbeddingResult> directly
    let result = RUNTIME.block_on(async { embedder.inner.embed(&text_refs, None, None).await });

    match result {
        Ok(embedding_results) => {
            let mut c_embeddings = Vec::with_capacity(embedding_results.len());

            for embedding_result in embedding_results {
                // Extract vector from EmbeddingResult enum
                let embedding_vec = match embedding_result {
                    EmbeddingResult::DenseVector(vec) => vec,
                    EmbeddingResult::MultiVector(_) => {
                        set_last_error("MULTI_VECTOR: Multi-vector embeddings are not supported in this version");
                        return std::ptr::null_mut();
                    }
                };

                // Validate vector is non-empty
                if embedding_vec.is_empty() {
                    set_last_error("EMBEDDING_FAILED: Generated embedding vector is empty");
                    return std::ptr::null_mut();
                }

                let len = embedding_vec.len();
                let mut boxed = embedding_vec.into_boxed_slice();
                let ptr = boxed.as_mut_ptr();
                std::mem::forget(boxed);

                c_embeddings.push(CTextEmbedding { values: ptr, len });
            }

            let batch_len = c_embeddings.len();
            let mut boxed_embeddings = c_embeddings.into_boxed_slice();
            let embeddings_ptr = boxed_embeddings.as_mut_ptr();
            std::mem::forget(boxed_embeddings);

            let batch = Box::new(CTextEmbeddingBatch {
                embeddings: embeddings_ptr,
                count: batch_len,
            });

            Box::into_raw(batch)
        }
        Err(e) => {
            set_last_error(&format!(
                "EMBEDDING_FAILED: Batch embedding generation failed for {} texts: {}",
                count, e
            ));
            std::ptr::null_mut()
        }
    }
}

// ============================================================================
// File/Directory Embedding Functions (Phase 3)
// ============================================================================

/// Embed a single file
///
/// Returns a batch of CEmbedData, one per chunk.
///
/// # Parameters
/// - embedder: Embedder handle
/// - file_path: Path to file (C string)
/// - config: Pointer to CTextEmbedConfig
///
/// # Returns
/// - Pointer to CEmbedDataBatch on success
/// - NULL on failure (check get_last_error)
///
/// # Error Prefixes
/// - "FILE_NOT_FOUND:" - File does not exist
/// - "UNSUPPORTED_FORMAT:" - File format not supported
/// - "FILE_READ_ERROR:" - Permission or I/O error reading file
/// - "EMBEDDING_FAILED:" - Embedding generation failed
#[no_mangle]
#[allow(clippy::not_unsafe_ptr_arg_deref)]
pub extern "C" fn embed_file(
    embedder: *const CEmbedder,
    file_path: *const c_char,
    config: *const CTextEmbedConfig,
) -> *mut CEmbedDataBatch {
    clear_last_error();
// Validate pointers
        if embedder.is_null() {
            set_last_error("FFI_ERROR: embedder pointer is null");
            return std::ptr::null_mut();
        }
        if file_path.is_null() {
            set_last_error("INVALID_CONFIG: file_path: cannot be null");
            return std::ptr::null_mut();
        }
        if config.is_null() {
            set_last_error("INVALID_CONFIG: config: cannot be null");
            return std::ptr::null_mut();
        }

        let embedder_ref = unsafe { &*embedder };
        let config_ref = unsafe { &*config };

        // Convert C string to Rust Path
        let file_path_str = unsafe {
            match CStr::from_ptr(file_path).to_str() {
                Ok(s) => s,
                Err(_) => {
                    set_last_error("INVALID_CONFIG: file_path: invalid UTF-8 encoding");
                    return std::ptr::null_mut();
                }
            }
        };

        let path = PathBuf::from(file_path_str);

        // Check if file exists
        if !path.exists() {
            set_last_error(&format!("FILE_NOT_FOUND: {}", file_path_str));
            return std::ptr::null_mut();
        }

        // Build TextEmbedConfig from CTextEmbedConfig
        let text_config = TextEmbedConfig {
            chunk_size: Some(config_ref.chunk_size),
            overlap_ratio: Some(config_ref.overlap_ratio),
            batch_size: Some(config_ref.batch_size),
            buffer_size: Some(config_ref.buffer_size),
            ..Default::default()
        };

        // Extract metadata manually before calling embed_file
        // This ensures we have metadata even if upstream function fails to extract it
        eprintln!("DEBUG: Attempting to embed file: {:?}", path);
        let extracted_metadata = match TextLoader::get_metadata(&path) {
            Ok(metadata) => {
                eprintln!("DEBUG: Metadata extracted successfully");
                eprintln!("  file_name: {:?}", metadata.get("file_name"));
                eprintln!("  created: {:?}", metadata.get("created"));
                eprintln!("  modified: {:?}", metadata.get("modified"));
                Some(metadata)
            }
            Err(e) => {
                eprintln!("DEBUG: Failed to extract metadata: {}", e);
                None
            }
        };

        // Call Arc<Embedder>::embed_file() using RUNTIME.block_on()
        let embed_result = RUNTIME.block_on(async {
            embedder_ref.inner.embed_file(path, Some(&text_config), None).await
        });

        match embed_result {
            Ok(Some(mut embed_data_vec)) => {
                // Inject metadata into any EmbedData items that have None metadata
                if let Some(ref metadata) = extracted_metadata {
                    for embed_data in embed_data_vec.iter_mut() {
                        if embed_data.metadata.is_none() {
                            eprintln!("DEBUG: Injecting extracted metadata into EmbedData");
                            embed_data.metadata = Some(metadata.clone());
                        }
                    }
                }

                // Convert Vec<EmbedData> to CEmbedDataBatch
                match embed_data_vec_to_batch(embed_data_vec) {
                    Ok(batch_ptr) => batch_ptr,
                    Err(e) => {
                        set_last_error(&e);
                        std::ptr::null_mut()
                    }
                }
            }
            Ok(None) => {
                set_last_error("EMBEDDING_FAILED: embed_file returned None");
                std::ptr::null_mut()
            }
            Err(e) => {
                let error_str = e.to_string().to_lowercase();
                if error_str.contains("not found") || error_str.contains("no such file") {
                    set_last_error(&format!("FILE_NOT_FOUND: {}", file_path_str));
                } else if error_str.contains("unsupported") || error_str.contains("format") {
                    set_last_error(&format!("UNSUPPORTED_FORMAT: {}", file_path_str));
                } else if error_str.contains("permission") || error_str.contains("access denied") {
                    set_last_error(&format!("FILE_READ_ERROR: {}", e));
                } else {
                    set_last_error(&format!("EMBEDDING_FAILED: {}", e));
                }
                std::ptr::null_mut()
            }
        }
    
}

/// Embed directory with streaming callback
///
/// Calls callback multiple times with batches of embeddings.
/// Returns 0 on success, -1 on failure.
///
/// # Parameters
/// - embedder: Embedder handle
/// - directory_path: Path to directory (C string)
/// - extensions: NULL-terminated array of extension strings, or NULL for all files
/// - extensions_count: Number of extensions (0 if extensions is NULL)
/// - config: Pointer to CTextEmbedConfig
/// - callback: Function to call with each batch
/// - callback_context: User data passed to callback
///
/// # Returns
/// - 0 on success
/// - -1 on failure (check get_last_error)
///
/// # Safety
/// The callback pointer and context must remain valid for the duration of this call.
/// This function blocks until all files are processed.
#[no_mangle]
#[allow(clippy::not_unsafe_ptr_arg_deref)]
pub extern "C" fn embed_directory_stream(
    embedder: *const CEmbedder,
    directory_path: *const c_char,
    extensions: *const *const c_char,
    extensions_count: usize,
    config: *const CTextEmbedConfig,
    callback: StreamCallback,
    callback_context: *mut c_void,
) -> i32 {
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

        let embedder_ref = unsafe { &*embedder };
        let config_ref = unsafe { &*config };

        // Convert C string to Rust PathBuf
        let dir_path_str = unsafe {
            match CStr::from_ptr(directory_path).to_str() {
                Ok(s) => s,
                Err(_) => {
                    set_last_error("INVALID_CONFIG: directory_path: invalid UTF-8 encoding");
                    return -1;
                }
            }
        };

        let dir_path = PathBuf::from(dir_path_str);

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

        // Call embed_directory_stream without adapter to collect all results
        // When adapter is None, the function returns all embeddings in the result
        eprintln!("DEBUG: Embedding directory: {:?}", dir_path);
        eprintln!("DEBUG: Extensions filter: {:?}", extensions_opt);
        eprintln!("DEBUG: Config - chunk_size: {}, overlap_ratio: {}",
                  config_ref.chunk_size, config_ref.overlap_ratio);

        let embed_result = RUNTIME.block_on(async {
            embedder_ref.inner.embed_directory_stream(
                dir_path,
                extensions_opt,
                Some(&text_config),
                None,  // No adapter - collect all results instead of streaming
            ).await
        });

        eprintln!("DEBUG: embed_directory_stream completed");

        match embed_result {
            Ok(Some(embed_data_vec)) => {
                eprintln!("DEBUG: Got {} embeddings from directory", embed_data_vec.len());

                // Log first few results if available
                for (i, data) in embed_data_vec.iter().take(3).enumerate() {
                    if let Some(ref metadata) = data.metadata {
                        eprintln!("DEBUG: Result {}: metadata present with {} keys",
                                 i, metadata.len());
                    } else {
                        eprintln!("DEBUG: Result {}: NO metadata", i);
                    }
                }

                // Convert Vec<EmbedData> to CEmbedDataBatch
                match embed_data_vec_to_batch(embed_data_vec) {
                    Ok(batch_ptr) => {
                        // Call the callback once with all results
                        (callback)(batch_ptr, callback_context);
                        // Note: Dart side is responsible for freeing the batch
                        0  // Success
                    }
                    Err(e) => {
                        set_last_error(&e);
                        -1
                    }
                }
            }
            Ok(None) => {
                // This shouldn't happen when adapter is None, but handle it gracefully
                set_last_error("EMBEDDING_FAILED: embed_directory_stream returned None");
                -1
            }
            Err(e) => {
                let error_str = e.to_string().to_lowercase();
                if error_str.contains("not found") || error_str.contains("no such file") {
                    set_last_error(&format!("FILE_NOT_FOUND: {}", dir_path_str));
                } else if error_str.contains("permission") || error_str.contains("access denied") {
                    set_last_error(&format!("FILE_READ_ERROR: {}", e));
                } else {
                    set_last_error(&format!("EMBEDDING_FAILED: Directory embedding failed - {}", e));
                }
                -1
            }
        }
    
}

// ============================================================================
// Memory Management Functions
// ============================================================================

#[no_mangle]
#[allow(clippy::not_unsafe_ptr_arg_deref)]
pub extern "C" fn embedder_free(embedder: *mut CEmbedder) {
    if !embedder.is_null() {
        unsafe {
            drop(Box::from_raw(embedder));
        }
    }
}

#[no_mangle]
#[allow(clippy::not_unsafe_ptr_arg_deref)]
pub extern "C" fn free_embedding(embedding: *mut CTextEmbedding) {
    if !embedding.is_null() {
        unsafe {
            let embedding = Box::from_raw(embedding);
            if !embedding.values.is_null() {
                drop(Vec::from_raw_parts(
                    embedding.values,
                    embedding.len,
                    embedding.len,
                ));
            }
        }
    }
}

#[no_mangle]
#[allow(clippy::not_unsafe_ptr_arg_deref)]
pub extern "C" fn free_embedding_batch(batch: *mut CTextEmbeddingBatch) {
    if !batch.is_null() {
        unsafe {
            let batch = Box::from_raw(batch);
            if !batch.embeddings.is_null() {
                let embeddings = Vec::from_raw_parts(batch.embeddings, batch.count, batch.count);
                for embedding in embeddings {
                    if !embedding.values.is_null() {
                        drop(Vec::from_raw_parts(
                            embedding.values,
                            embedding.len,
                            embedding.len,
                        ));
                    }
                }
            }
        }
    }
}

/// Free a CEmbedData instance
#[no_mangle]
#[allow(clippy::not_unsafe_ptr_arg_deref)]
pub extern "C" fn free_embed_data(data: *mut CEmbedData) {
    if !data.is_null() {
        unsafe {
            let data = Box::from_raw(data);
            free_embed_data_single(*data);
        }
    }
}

/// Free a CEmbedDataBatch instance
#[no_mangle]
#[allow(clippy::not_unsafe_ptr_arg_deref)]
pub extern "C" fn free_embed_data_batch(batch: *mut CEmbedDataBatch) {
    if !batch.is_null() {
        unsafe {
            let batch = Box::from_raw(batch);
            if !batch.items.is_null() {
                let items = Vec::from_raw_parts(batch.items, batch.count, batch.count);
                for item in items {
                    free_embed_data_single(item);
                }
            }
        }
    }
}

// ============================================================================
// Tests
// ============================================================================

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::HashMap;

    #[test]
    fn test_embed_data_to_c_dense_vector() {
        // Arrange
        let embedding = EmbeddingResult::DenseVector(vec![0.1, 0.2, 0.3]);
        let text = Some("test text".to_string());
        let mut metadata = HashMap::new();
        metadata.insert("file_path".to_string(), "/path/to/file.txt".to_string());
        metadata.insert("chunk_index".to_string(), "0".to_string());

        let embed_data = EmbedData {
            embedding,
            text,
            metadata: Some(metadata),
        };

        // Act
        let result = embed_data_to_c(embed_data);

        // Assert
        assert!(result.is_ok());
        let c_data = result.unwrap();
        assert!(!c_data.embedding_values.is_null());
        assert_eq!(c_data.embedding_len, 3);
        assert!(!c_data.text.is_null());
        assert!(!c_data.metadata_json.is_null());

        // Cleanup
        unsafe {
            free_embed_data_single(c_data);
        }
    }

    #[test]
    fn test_embed_data_to_c_multi_vector_error() {
        // Arrange
        let embedding = EmbeddingResult::MultiVector(vec![vec![0.1, 0.2], vec![0.3, 0.4]]);
        let embed_data = EmbedData {
            embedding,
            text: None,
            metadata: None,
        };

        // Act
        let result = embed_data_to_c(embed_data);

        // Assert
        assert!(result.is_err());
        if let Err(err) = result {
            assert!(err.contains("MULTI_VECTOR_NOT_SUPPORTED"));
        } else {
            panic!("Expected error but got Ok");
        }
    }

    #[test]
    fn test_embed_data_to_c_null_text_and_metadata() {
        // Arrange
        let embedding = EmbeddingResult::DenseVector(vec![1.0, 2.0]);
        let embed_data = EmbedData {
            embedding,
            text: None,
            metadata: None,
        };

        // Act
        let result = embed_data_to_c(embed_data);

        // Assert
        assert!(result.is_ok());
        let c_data = result.unwrap();
        assert!(!c_data.embedding_values.is_null());
        assert_eq!(c_data.embedding_len, 2);
        assert!(c_data.text.is_null());
        assert!(c_data.metadata_json.is_null());

        // Cleanup
        unsafe {
            free_embed_data_single(c_data);
        }
    }

    #[test]
    fn test_free_embed_data_batch_null_safe() {
        // Act - should not crash
        free_embed_data_batch(std::ptr::null_mut());
    }

    #[test]
    fn test_error_storage() {
        // Arrange
        clear_last_error();

        // Act
        set_last_error("TEST_ERROR: This is a test error");
        let error_ptr = get_last_error();

        // Assert
        assert!(!error_ptr.is_null());
        let error_str = unsafe { CStr::from_ptr(error_ptr).to_str().unwrap() };
        assert_eq!(error_str, "TEST_ERROR: This is a test error");

        // Cleanup
        free_error_string(error_ptr);

        // Verify error was cleared
        let error_ptr2 = get_last_error();
        assert!(error_ptr2.is_null());
    }

    #[test]
    fn test_embed_file_null_embedder() {
        // Act
        let result = embed_file(
            std::ptr::null(),
            "test.txt\0".as_ptr() as *const c_char,
            std::ptr::null(),
        );

        // Assert
        assert!(result.is_null());
        let error_ptr = get_last_error();
        assert!(!error_ptr.is_null());
        let error_str = unsafe { CStr::from_ptr(error_ptr).to_str().unwrap() };
        assert!(error_str.contains("FFI_ERROR"));

        // Cleanup
        free_error_string(error_ptr);
    }

    #[test]
    fn test_embed_directory_stream_null_directory() {
        // Define a test callback
        extern "C" fn test_callback(_batch: *mut CEmbedDataBatch, _context: *mut c_void) {
            // No-op callback for testing
        }

        // Act
        let result = embed_directory_stream(
            std::ptr::null(),
            std::ptr::null(),
            std::ptr::null(),
            0,
            std::ptr::null(),
            test_callback,
            std::ptr::null_mut(),
        );

        // Assert
        assert_eq!(result, -1);
        let error_ptr = get_last_error();
        assert!(!error_ptr.is_null());

        // Cleanup
        free_error_string(error_ptr);
    }

    #[test]
    fn test_metadata_json_serialization() {
        // Arrange
        let mut metadata = HashMap::new();
        metadata.insert("file_path".to_string(), "/test/file.pdf".to_string());
        metadata.insert("page_number".to_string(), "5".to_string());
        metadata.insert("chunk_index".to_string(), "2".to_string());

        let embedding = EmbeddingResult::DenseVector(vec![0.5]);
        let embed_data = EmbedData {
            embedding,
            text: Some("chunk text".to_string()),
            metadata: Some(metadata),
        };

        // Act
        let result = embed_data_to_c(embed_data);

        // Assert
        assert!(result.is_ok());
        let c_data = result.unwrap();
        assert!(!c_data.metadata_json.is_null());

        let json_str = unsafe { CStr::from_ptr(c_data.metadata_json).to_str().unwrap() };
        let parsed: HashMap<String, String> = serde_json::from_str(json_str).unwrap();
        assert_eq!(parsed.get("file_path").unwrap(), "/test/file.pdf");
        assert_eq!(parsed.get("page_number").unwrap(), "5");
        assert_eq!(parsed.get("chunk_index").unwrap(), "2");

        // Cleanup
        unsafe {
            free_embed_data_single(c_data);
        }
    }
}
