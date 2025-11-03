use std::cell::RefCell;
use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::panic;
use std::sync::Arc;

use embed_anything::embeddings::embed::{Embedder, EmbeddingResult};
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
// FFI Types for Embeddings
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
// Embedding Functions
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
