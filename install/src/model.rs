use std::path::PathBuf;

use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, Deserialize, Serialize)]
pub struct MachineReport {
    pub distribution: Distribution,
    pub architecture: String,
    pub home: PathBuf,
    pub config_home: PathBuf,
    pub data_home: PathBuf,
    pub state_home: PathBuf,
    pub path_entries: Vec<PathBuf>,
    pub package_manager: Option<String>,
    pub session_type: Option<String>,
    pub desktop: Option<String>,
    pub display_manager: Option<String>,
    pub commands: Vec<CommandStatus>,
    pub fonts: Vec<FontStatus>,
    pub hardware: HardwareReport,
    pub desktop_processes: Vec<DesktopProcess>,
}

impl MachineReport {
    pub fn is_arch(&self) -> bool {
        self.distribution.id != "artix"
            && (self.distribution.id == "arch"
                || self
                    .distribution
                    .id_like
                    .iter()
                    .any(|distribution| distribution == "arch"))
    }

    pub fn font(&self, family: &str) -> Option<&FontStatus> {
        self.fonts.iter().find(|font| font.family == family)
    }
}

#[derive(Clone, Debug, Default, Deserialize, Serialize)]
pub struct Distribution {
    pub id: String,
    pub id_like: Vec<String>,
    pub name: String,
    pub pretty_name: String,
}

#[derive(Clone, Debug, Deserialize, Serialize)]
pub struct CommandStatus {
    pub name: String,
    pub path: Option<PathBuf>,
}

#[derive(Clone, Debug, Deserialize, Serialize)]
pub struct FontStatus {
    pub family: String,
    pub available: bool,
    pub resolved_as: Option<String>,
}

#[derive(Clone, Debug, Default, Deserialize, Serialize)]
pub struct HardwareReport {
    pub batteries: usize,
    pub backlights: usize,
    pub drm_connectors: usize,
    pub bluetooth_present: bool,
    pub network_present: bool,
    pub power_profiles_present: bool,
}

#[derive(Clone, Debug, Deserialize, Serialize)]
pub struct DesktopProcess {
    pub pid: u32,
    pub name: String,
    pub role: String,
    pub command_line: String,
    pub tonantzintla_owned: bool,
}

#[derive(Clone, Debug, Deserialize, Serialize)]
pub struct InstallPlan {
    pub dry_run: bool,
    pub supported: bool,
    pub source: PathBuf,
    pub install_root: PathBuf,
    pub profile: String,
    pub machine: MachineReport,
    pub features: Vec<FeaturePlan>,
    pub operations: Vec<PlannedOperation>,
    pub warnings: Vec<String>,
}

#[derive(Clone, Debug, Deserialize, Serialize)]
pub struct FeaturePlan {
    pub id: String,
    pub label: String,
    pub selected: bool,
    pub required: bool,
    pub status: FeatureStatus,
    pub capabilities: Vec<CapabilityPlan>,
}

#[derive(Clone, Copy, Debug, Deserialize, Serialize)]
#[serde(rename_all = "kebab-case")]
pub enum FeatureStatus {
    Ready,
    Partial,
    Missing,
    Skipped,
}

#[derive(Clone, Debug, Deserialize, Serialize)]
pub struct CapabilityPlan {
    pub id: String,
    pub label: String,
    pub available: bool,
    pub source: Option<String>,
    pub official_packages: Vec<String>,
    pub aur_packages: Vec<String>,
}

#[derive(Clone, Debug, Deserialize, Serialize)]
pub struct PlannedOperation {
    pub id: String,
    pub scope: OperationScope,
    pub state: OperationState,
    pub summary: String,
    pub detail: String,
    pub requires_root: bool,
}

#[derive(Clone, Copy, Debug, Deserialize, Serialize)]
#[serde(rename_all = "kebab-case")]
pub enum OperationScope {
    Package,
    UserFile,
    Validation,
    Niri,
    Umbra,
}

#[derive(Clone, Copy, Debug, Deserialize, Serialize)]
#[serde(rename_all = "kebab-case")]
pub enum OperationState {
    Satisfied,
    Planned,
    Manual,
    Conflict,
    Skipped,
    Blocked,
}
