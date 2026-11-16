use std::path::Path;
use walkdir::WalkDir;

pub struct ScannedFolder {
    pub folder: String,
    pub asset_paths: Vec<String>,
}

pub fn scan_assets<P: AsRef<Path>>(
    project_root: P,
    folder: &str,
    recursive: bool,
) -> Result<Vec<String>, String> {
    let normalized_folder = folder.trim_matches('/').replace('\\', "/");
    let asset_dir = project_root
        .as_ref()
        .join("assets")
        .join(&normalized_folder);

    if !asset_dir.exists() {
        return Err(format!("No visible assets were found in 'assets/{}/'.", normalized_folder));
    }

    let mut paths = Vec::new();

    let walker = if recursive {
        WalkDir::new(&asset_dir).into_iter()
    } else {
        WalkDir::new(&asset_dir).max_depth(1).into_iter()
    };

    for entry in walker {
        let entry = match entry {
            Ok(e) => e,
            Err(err) => return Err(format!("Error reading directory: {err}")),
        };

        let file_name = entry.file_name().to_string_lossy();
        if file_name.starts_with('.') {
            continue;
        }

        if entry.file_type().is_file() {
            let relative = match entry.path().strip_prefix(project_root.as_ref()) {
                Ok(rel) => rel,
                Err(_) => continue,
            };

            let path_str = relative.to_string_lossy().replace('\\', "/");
            paths.push(path_str);
        }
    }

    paths.sort();

    if paths.is_empty() {
        return Err(format!("No visible assets were found in 'assets/{}/'.", normalized_folder));
    }

    Ok(paths)
}
