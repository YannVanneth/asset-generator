use std::collections::{BTreeMap, HashMap, HashSet};

const DART_KEYWORDS: &[&str] = &[
    "abstract", "as", "assert", "async", "await", "base", "break", "case", "catch", "class",
    "const", "continue", "covariant", "default", "deferred", "do", "dynamic", "else", "enum",
    "export", "extends", "extension", "external", "factory", "false", "final", "finally", "for",
    "function", "get", "hide", "if", "implements", "import", "in", "interface", "is", "late",
    "library", "mixin", "new", "null", "on", "operator", "part", "required", "rethrow", "return",
    "sealed", "set", "show", "static", "super", "switch", "sync", "this", "throw", "true", "try",
    "type", "typedef", "var", "void", "when", "while", "with", "yield",
];

pub fn sanitize_identifier(input: &str) -> String {
    if input.is_empty() {
        return "_".to_string();
    }

    let base_name = if let Some(last_dot) = input.rfind('.') {
        if last_dot > 0 {
            &input[..last_dot]
        } else {
            input
        }
    } else {
        input
    };

    let parts: Vec<&str> = base_name
        .split(|c: char| !c.is_ascii_alphanumeric())
        .filter(|s| !s.is_empty())
        .collect();

    if parts.is_empty() {
        return "_asset".to_string();
    }

    let first = parts[0].to_ascii_lowercase();
    let rest: String = parts[1..]
        .iter()
        .map(|p| capitalize(p))
        .collect();

    let mut name = format!("{first}{rest}");

    if name.chars().next().map_or(false, |c| c.is_ascii_digit()) {
        name = format!("_{name}");
    }

    if DART_KEYWORDS.contains(&name.as_str()) {
        name = format!("{name}Asset");
    }

    name
}

pub fn capitalize(s: &str) -> String {
    let mut chars = s.chars();
    match chars.next() {
        None => String::new(),
        Some(first) => first.to_uppercase().collect::<String>() + chars.as_str(),
    }
}

fn class_name_for(folder: &str, path_segments: &[&str]) -> String {
    let folder_id = sanitize_identifier(folder);
    let mut parts = vec![capitalize(&folder_id)];
    for segment in path_segments {
        parts.push(capitalize(&sanitize_identifier(segment)));
    }
    format!("_{}", parts.concat())
}

#[derive(Default)]
struct AssetNode {
    files: Vec<AssetFile>,
    children: BTreeMap<String, AssetNode>,
}

struct AssetFile {
    asset_path: String,
    relative_path: String,
    file_name: String,
}

pub fn generate_dart_code(
    input_file_name: &str,
    context_class_name: &str,
    folders: &[String],
    assets_by_folder: &HashMap<String, Vec<String>>,
    include_part: bool,
) -> Result<String, String> {
    if folders.is_empty() {
        return Err("At least one asset folder is required.".to_string());
    }

    let mut normalized_folders: Vec<String> = folders
        .iter()
        .map(|f| f.trim_matches('/').replace('\\', "/"))
        .collect::<HashSet<_>>()
        .into_iter()
        .collect();
    normalized_folders.sort();

    let mut trees: BTreeMap<String, AssetNode> = BTreeMap::new();

    for folder in &normalized_folders {
        let mut root = AssetNode::default();
        let expected_prefix = format!("assets/{folder}/");
        let mut seen_paths = HashSet::new();

        if let Some(assets) = assets_by_folder.get(folder) {
            for asset_path in assets {
                if !seen_paths.insert(asset_path.clone()) {
                    continue;
                }
                if !asset_path.starts_with(&expected_prefix) {
                    return Err(format!(
                        "Asset '{asset_path}' is outside configured folder '{folder}'."
                    ));
                }

                let rel_path = &asset_path[expected_prefix.len()..];
                let segments: Vec<&str> = rel_path.split('/').collect();
                if segments.iter().any(|s| s.is_empty() || *s == "." || *s == "..") {
                    return Err(format!("Invalid asset path '{asset_path}'."));
                }

                insert_asset(&mut root, asset_path, segments);
            }
        }

        if root.files.is_empty() && root.children.is_empty() {
            return Err(format!("No visible assets were found in 'assets/{folder}/'."));
        }

        trees.insert(folder.clone(), root);
    }

    // Validation
    validate_unique_names(&normalized_folders, &trees)?;

    let mut output = String::new();
    if include_part {
        output.push_str(&format!("part of '{input_file_name}';\n\n"));
    }

    output.push_str("class AssetPath {\n");
    output.push_str("  const AssetPath._();\n\n");
    for folder in &normalized_folders {
        let method_name = sanitize_identifier(folder);
        output.push_str(&format!(
            "  static String {method_name}(String assetName) => 'assets/{folder}/$assetName';\n"
        ));
    }
    output.push_str("}\n\n");

    output.push_str(&format!("abstract class _{context_class_name}Context {{\n"));
    for folder in &normalized_folders {
        let helper_class = class_name_for(folder, &[]);
        let instance_name = sanitize_identifier(folder);
        output.push_str(&format!("  {helper_class} {instance_name} = {helper_class}();\n"));
    }
    output.push_str("}\n\n");

    for folder in &normalized_folders {
        render_node(&mut output, &trees[folder], folder, &[]);
    }

    Ok(output)
}

fn insert_asset(mut root: &mut AssetNode, asset_path: &str, segments: Vec<&str>) {
    for (i, segment) in segments.iter().enumerate() {
        if i == segments.len() - 1 {
            root.files.push(AssetFile {
                asset_path: asset_path.to_string(),
                relative_path: segments.join("/"),
                file_name: segment.to_string(),
            });
        } else {
            root = root.children.entry(segment.to_string()).or_default();
        }
    }
}

fn validate_unique_names(
    folders: &[String],
    trees: &BTreeMap<String, AssetNode>,
) -> Result<(), String> {
    let mut root_names = HashMap::new();
    for folder in folders {
        let name = sanitize_identifier(folder);
        if let Some(prev) = root_names.insert(name.clone(), folder.clone()) {
            if prev != *folder {
                return Err(format!(
                    "Asset identifier collision for '{name}' in folders: {prev} and {folder}."
                ));
            }
        }
        validate_node(&trees[folder], folder, &[])?;
    }
    Ok(())
}

fn validate_node(
    node: &AssetNode,
    folder: &str,
    parent_segments: &[&str],
) -> Result<(), String> {
    let mut names = HashMap::new();
    for file in &node.files {
        let name = sanitize_identifier(&file.file_name);
        if let Some(prev) = names.insert(name.clone(), file.asset_path.clone()) {
            if prev != file.asset_path {
                return Err(format!(
                    "Asset identifier collision for '{name}' in 'assets/{folder}/{}': {prev} and {}.",
                    parent_segments.join("/"),
                    file.asset_path
                ));
            }
        }
    }
    for (child_name, child_node) in &node.children {
        let name = sanitize_identifier(child_name);
        if let Some(prev) = names.insert(name.clone(), child_name.clone()) {
            if prev != *child_name {
                return Err(format!(
                    "Asset identifier collision for '{name}' in 'assets/{folder}/{}': {prev} and {child_name}.",
                    parent_segments.join("/")
                ));
            }
        }
        let mut next_segments = parent_segments.to_vec();
        next_segments.push(child_name);
        validate_node(child_node, folder, &next_segments)?;
    }
    Ok(())
}

fn render_node(
    output: &mut String,
    node: &AssetNode,
    folder: &str,
    path_segments: &[&str],
) {
    let class_name = class_name_for(folder, path_segments);
    output.push_str(&format!("class {class_name} {{\n"));

    for (child_name, _) in &node.children {
        let mut child_path = path_segments.to_vec();
        child_path.push(child_name);
        let child_class = class_name_for(folder, &child_path);
        let instance = sanitize_identifier(child_name);
        output.push_str(&format!("  {child_class} {instance} = {child_class}();\n"));
    }

    let mut sorted_files: Vec<&AssetFile> = node.files.iter().collect();
    sorted_files.sort_by(|a, b| a.asset_path.cmp(&b.asset_path));

    for file in sorted_files {
        let id = sanitize_identifier(&file.file_name);
        let method = sanitize_identifier(folder);
        output.push_str(&format!(
            "  final String {id} = AssetPath.{method}(\"{}\");\n",
            file.relative_path
        ));
    }

    output.push_str("}\n\n");

    for (child_name, child_node) in &node.children {
        let mut child_path = path_segments.to_vec();
        child_path.push(child_name);
        render_node(output, child_node, folder, &child_path);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_sanitize_identifier() {
        assert_eq!(sanitize_identifier("logo.png"), "logo");
        assert_eq!(sanitize_identifier("user-profile.svg"), "userProfile");
        assert_eq!(sanitize_identifier("123icon.png"), "_123icon");
        assert_eq!(sanitize_identifier("class.png"), "classAsset");
        assert_eq!(sanitize_identifier("data.sample.json"), "dataSample");
    }

    #[test]
    fn test_nested_code_generation() {
        let mut assets = HashMap::new();
        assets.insert(
            "images".to_string(),
            vec!["assets/images/marketing/logo.png".to_string()],
        );
        let output = generate_dart_code(
            "asset_manager.dart",
            "AssetManager",
            &["images".to_string()],
            &assets,
            true,
        )
        .expect("Generation failed");

        assert!(output.contains("class _ImagesMarketing {"));
        assert!(output.contains("final String logo = AssetPath.images(\"marketing/logo.png\");"));
    }
}
