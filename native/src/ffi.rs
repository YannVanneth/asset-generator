use std::collections::HashMap;
use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::path::Path;

use serde::Deserialize;

use crate::generator::generate_dart_code;
use crate::scanner::scan_assets;

#[derive(Deserialize)]
struct GeneratorConfig {
    input_file_name: String,
    context_class_name: String,
    folders: Vec<String>,
    recursive: bool,
    #[serde(default = "default_true")]
    include_part: bool,
}

fn default_true() -> bool {
    true
}

#[no_mangle]
pub unsafe extern "C" fn lazy_asset_generate(
    project_root_ptr: *const c_char,
    config_json_ptr: *const c_char,
) -> *mut c_char {
    if project_root_ptr.is_null() || config_json_ptr.is_null() {
        return return_error("Null pointer provided to lazy_asset_generate");
    }

    let project_root_str = match CStr::from_ptr(project_root_ptr).to_str() {
        Ok(s) => s,
        Err(_) => return return_error("Invalid UTF-8 in project_root"),
    };

    let config_json_str = match CStr::from_ptr(config_json_ptr).to_str() {
        Ok(s) => s,
        Err(_) => return return_error("Invalid UTF-8 in config_json"),
    };

    let config: GeneratorConfig = match serde_json::from_str(config_json_str) {
        Ok(c) => c,
        Err(err) => return return_error(&format!("JSON deserialization error: {err}")),
    };

    let root_path = Path::new(project_root_str);
    let mut assets_by_folder = HashMap::new();

    for folder in &config.folders {
        match scan_assets(root_path, folder, config.recursive) {
            Ok(paths) => {
                assets_by_folder.insert(folder.clone(), paths);
            }
            Err(err) => return return_error(&err),
        }
    }

    match generate_dart_code(
        &config.input_file_name,
        &config.context_class_name,
        &config.folders,
        &assets_by_folder,
        config.include_part,
    ) {
        Ok(code) => match CString::new(code) {
            Ok(c_str) => c_str.into_raw(),
            Err(_) => return_error("Failed to construct CString output"),
        },
        Err(err) => return_error(&err),
    }
}

fn return_error(msg: &str) -> *mut c_char {
    let err_msg = format!("__ERROR__: {msg}");
    CString::new(err_msg).unwrap().into_raw()
}

#[no_mangle]
pub unsafe extern "C" fn lazy_asset_free_string(ptr: *mut c_char) {
    if !ptr.is_null() {
        drop(CString::from_raw(ptr));
    }
}
