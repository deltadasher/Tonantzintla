use std::fs;
use std::path::Path;

use anyhow::{Context, Result, ensure};
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, Deserialize, Serialize)]
pub struct FeatureManifest {
    pub schema: u32,
    pub groups: Vec<FeatureGroup>,
}

#[derive(Clone, Debug, Deserialize, Serialize)]
pub struct FeatureGroup {
    pub id: String,
    pub label: String,
    pub description: String,
    pub profiles: Vec<String>,
    #[serde(default)]
    pub required: bool,
    pub capabilities: Vec<Capability>,
}

#[derive(Clone, Debug, Deserialize, Serialize)]
pub struct Capability {
    pub id: String,
    pub label: String,
    pub command: Option<String>,
    pub file: Option<String>,
    pub font_family: Option<String>,
    #[serde(default)]
    pub official_packages: Vec<String>,
    #[serde(default)]
    pub aur_packages: Vec<String>,
}

impl FeatureManifest {
    pub fn load(path: &Path) -> Result<Self> {
        let source = fs::read_to_string(path)
            .with_context(|| format!("could not read feature manifest {}", path.display()))?;
        let manifest: Self = toml::from_str(&source)
            .with_context(|| format!("invalid feature manifest {}", path.display()))?;
        ensure!(manifest.schema == 1, "unsupported feature manifest schema");
        ensure!(
            !manifest.groups.is_empty(),
            "feature manifest contains no groups"
        );
        Ok(manifest)
    }
}
