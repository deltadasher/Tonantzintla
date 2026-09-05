use std::collections::BTreeSet;
use std::env;
use std::fs;
use std::os::unix::fs::PermissionsExt;
use std::path::{Path, PathBuf};
use std::process::Command;

use anyhow::{Context, Result};

use crate::model::{
    CommandStatus, DesktopProcess, Distribution, FontStatus, HardwareReport, MachineReport,
};

pub const PROBED_COMMANDS: &[&str] = &[
    "pacman",
    "sudo",
    "doas",
    "paru",
    "yay",
    "niri",
    "qs",
    "swayidle",
    "python3",
    "wpctl",
    "pactl",
    "amixer",
    "fc-match",
    "nmcli",
    "bluetoothctl",
    "wl-copy",
    "wl-paste",
    "cliphist",
    "grim",
    "slurp",
    "satty",
    "gpu-screen-recorder",
    "awww",
    "mpvpaper",
    "matugen",
    "ffmpeg",
    "cava",
    "easyeffects",
    "brightnessctl",
    "powerprofilesctl",
    "cmake",
    "ninja",
];

pub const PROBED_FONTS: &[&str] = &["JetBrains Mono", "Iosevka Nerd Font"];

#[derive(Clone, Debug)]
pub struct ProbeContext {
    pub home: PathBuf,
    pub config_home: PathBuf,
    pub data_home: PathBuf,
    pub state_home: PathBuf,
    pub path_entries: Vec<PathBuf>,
    pub os_release: PathBuf,
}

impl ProbeContext {
    pub fn from_process() -> Result<Self> {
        let home = PathBuf::from(env::var_os("HOME").context("HOME is not set")?);
        let config_home = env::var_os("XDG_CONFIG_HOME")
            .map(PathBuf::from)
            .unwrap_or_else(|| home.join(".config"));
        let data_home = env::var_os("XDG_DATA_HOME")
            .map(PathBuf::from)
            .unwrap_or_else(|| home.join(".local/share"));
        let state_home = env::var_os("XDG_STATE_HOME")
            .map(PathBuf::from)
            .unwrap_or_else(|| home.join(".local/state"));
        let path_entries = env::split_paths(&env::var_os("PATH").unwrap_or_default()).collect();
        let os_release = env::var_os("TONANTZINTLA_INSTALLER_OS_RELEASE")
            .map(PathBuf::from)
            .unwrap_or_else(|| PathBuf::from("/etc/os-release"));
        Ok(Self {
            home,
            config_home,
            data_home,
            state_home,
            path_entries,
            os_release,
        })
    }

    pub fn inspect(&self) -> MachineReport {
        let distribution = read_os_release(&self.os_release).unwrap_or_default();
        let commands: Vec<CommandStatus> = PROBED_COMMANDS
            .iter()
            .map(|name| CommandStatus {
                name: (*name).to_string(),
                path: find_command(name, &self.path_entries),
            })
            .collect();
        let package_manager =
            find_command("pacman", &self.path_entries).map(|_| "pacman".to_string());
        let font_match = find_command("fc-match", &self.path_entries);
        let fonts = PROBED_FONTS
            .iter()
            .map(|family| inspect_font(font_match.as_deref(), family))
            .collect();
        let hardware = inspect_hardware(self, &commands);
        let desktop_processes = inspect_desktop_processes(self);
        MachineReport {
            distribution,
            architecture: env::consts::ARCH.to_string(),
            home: self.home.clone(),
            config_home: self.config_home.clone(),
            data_home: self.data_home.clone(),
            state_home: self.state_home.clone(),
            path_entries: self.path_entries.clone(),
            package_manager,
            session_type: env::var("XDG_SESSION_TYPE").ok(),
            desktop: env::var("XDG_CURRENT_DESKTOP").ok(),
            display_manager: inspect_display_manager(self),
            commands,
            fonts,
            hardware,
            desktop_processes,
        }
    }

    pub fn path_exists(&self, path: &Path) -> bool {
        self.rooted_absolute(path)
            .map_or_else(|| path.exists(), |candidate| candidate.exists())
    }

    fn rooted_absolute(&self, path: &Path) -> Option<PathBuf> {
        let root = env::var_os("TONANTZINTLA_INSTALLER_ROOT").map(PathBuf::from)?;
        Some(root.join(path.strip_prefix("/").ok()?))
    }
}

fn inspect_hardware(context: &ProbeContext, commands: &[CommandStatus]) -> HardwareReport {
    let power_supply = context
        .rooted_absolute(Path::new("/sys/class/power_supply"))
        .unwrap_or_else(|| PathBuf::from("/sys/class/power_supply"));
    let backlight = context
        .rooted_absolute(Path::new("/sys/class/backlight"))
        .unwrap_or_else(|| PathBuf::from("/sys/class/backlight"));
    let drm = context
        .rooted_absolute(Path::new("/sys/class/drm"))
        .unwrap_or_else(|| PathBuf::from("/sys/class/drm"));
    let bluetooth = context
        .rooted_absolute(Path::new("/sys/class/bluetooth"))
        .unwrap_or_else(|| PathBuf::from("/sys/class/bluetooth"));
    let network = context
        .rooted_absolute(Path::new("/sys/class/net"))
        .unwrap_or_else(|| PathBuf::from("/sys/class/net"));
    let platform_profile = context
        .rooted_absolute(Path::new("/sys/firmware/acpi/platform_profile"))
        .unwrap_or_else(|| PathBuf::from("/sys/firmware/acpi/platform_profile"));

    let batteries = child_paths(&power_supply)
        .into_iter()
        .filter(|path| {
            fs::read_to_string(path.join("type"))
                .is_ok_and(|kind| kind.trim().eq_ignore_ascii_case("battery"))
                || path
                    .file_name()
                    .is_some_and(|name| name.to_string_lossy().starts_with("BAT"))
        })
        .count();
    let drm_connectors = child_paths(&drm)
        .into_iter()
        .filter(|path| {
            fs::read_to_string(path.join("status")).is_ok_and(|status| status.trim() == "connected")
        })
        .count();
    let network_present = child_paths(&network).into_iter().any(|path| {
        path.file_name()
            .is_some_and(|name| name.to_string_lossy() != "lo")
    });
    let power_profiles_present = platform_profile.exists()
        || commands
            .iter()
            .any(|command| command.name == "powerprofilesctl" && command.path.is_some());

    HardwareReport {
        batteries,
        backlights: child_paths(&backlight).len(),
        drm_connectors,
        bluetooth_present: !child_paths(&bluetooth).is_empty(),
        network_present,
        power_profiles_present,
    }
}

fn child_paths(path: &Path) -> Vec<PathBuf> {
    fs::read_dir(path)
        .map(|entries| entries.flatten().map(|entry| entry.path()).collect())
        .unwrap_or_default()
}

fn inspect_display_manager(context: &ProbeContext) -> Option<String> {
    let link = context
        .rooted_absolute(Path::new("/etc/systemd/system/display-manager.service"))
        .unwrap_or_else(|| PathBuf::from("/etc/systemd/system/display-manager.service"));
    fs::read_link(link).ok().and_then(|target| {
        target
            .file_name()
            .map(|name| name.to_string_lossy().into_owned())
    })
}

fn inspect_desktop_processes(context: &ProbeContext) -> Vec<DesktopProcess> {
    let proc_root = context
        .rooted_absolute(Path::new("/proc"))
        .unwrap_or_else(|| PathBuf::from("/proc"));
    let mut processes = child_paths(&proc_root)
        .into_iter()
        .filter_map(|path| {
            let pid = path.file_name()?.to_str()?.parse::<u32>().ok()?;
            let name = fs::read_to_string(path.join("comm"))
                .ok()?
                .trim()
                .to_string();
            let role = desktop_role(&name)?;
            let command_line = fs::read(path.join("cmdline"))
                .ok()
                .map(|bytes| {
                    String::from_utf8_lossy(&bytes)
                        .trim_matches(char::from(0))
                        .replace(char::from(0), " ")
                })
                .unwrap_or_default();
            let tonantzintla_owned = command_line.to_ascii_lowercase().contains("tonantzintla");
            Some(DesktopProcess {
                pid,
                name,
                role: role.to_string(),
                command_line,
                tonantzintla_owned,
            })
        })
        .collect::<Vec<_>>();
    processes.sort_by_key(|process| process.pid);
    processes
}

fn desktop_role(name: &str) -> Option<&'static str> {
    match name.to_ascii_lowercase().as_str() {
        "mako" | "dunst" | "swaync" | "swaync-client" => Some("notifications"),
        "quickshell" | "qs" | "waybar" => Some("shell/bar"),
        "awww-daemon" | "swww-daemon" | "mpvpaper" | "hyprpaper" => Some("wallpaper"),
        "cliphist" | "wl-paste" => Some("clipboard"),
        "swaylock" | "hyprlock" => Some("session lock"),
        _ => None,
    }
}

fn find_command(name: &str, entries: &[PathBuf]) -> Option<PathBuf> {
    entries.iter().map(|entry| entry.join(name)).find(|path| {
        fs::metadata(path)
            .map(|metadata| metadata.is_file() && metadata.permissions().mode() & 0o111 != 0)
            .unwrap_or(false)
    })
}

fn inspect_font(fc_match: Option<&Path>, family: &str) -> FontStatus {
    let resolved_as = fc_match.and_then(|command| {
        Command::new(command)
            .args(["--format", "%{family}\n", family])
            .output()
            .ok()
            .filter(|output| output.status.success())
            .and_then(|output| String::from_utf8(output.stdout).ok())
            .and_then(|output| output.lines().next().map(str::trim).map(str::to_string))
            .filter(|output| !output.is_empty())
    });
    let available = resolved_as.as_ref().is_some_and(|resolved| {
        resolved
            .split(',')
            .any(|candidate| candidate.trim().eq_ignore_ascii_case(family))
    });
    FontStatus {
        family: family.to_string(),
        available,
        resolved_as,
    }
}

fn read_os_release(path: &Path) -> Result<Distribution> {
    let contents =
        fs::read_to_string(path).with_context(|| format!("could not read {}", path.display()))?;
    let mut fields = std::collections::BTreeMap::new();
    for line in contents.lines() {
        let Some((key, raw_value)) = line.split_once('=') else {
            continue;
        };
        let value = raw_value.trim_matches('"').to_string();
        fields.insert(key.to_string(), value);
    }
    Ok(Distribution {
        id: fields.get("ID").cloned().unwrap_or_default(),
        id_like: fields
            .get("ID_LIKE")
            .map(|value| {
                value
                    .split(|character: char| character.is_whitespace() || character == ',')
                    .filter(|value| !value.is_empty())
                    .map(str::to_string)
                    .collect()
            })
            .unwrap_or_default(),
        name: fields.get("NAME").cloned().unwrap_or_default(),
        pretty_name: fields
            .get("PRETTY_NAME")
            .cloned()
            .unwrap_or_else(|| "Unknown Linux".to_string()),
    })
}

pub fn command_set(report: &MachineReport) -> BTreeSet<&str> {
    report
        .commands
        .iter()
        .filter(|command| command.path.is_some())
        .map(|command| command.name.as_str())
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_arch_release() {
        let temp = tempfile::tempdir().unwrap();
        let release = temp.path().join("os-release");
        fs::write(
            &release,
            "NAME=\"Arch Linux\"\nID=arch\nPRETTY_NAME=\"Arch Linux\"\n",
        )
        .unwrap();
        let parsed = read_os_release(&release).unwrap();
        assert_eq!(parsed.id, "arch");
        assert!(parsed.id_like.is_empty());
        assert_eq!(parsed.pretty_name, "Arch Linux");
    }

    #[test]
    fn parses_arch_derivative_release() {
        let temp = tempfile::tempdir().unwrap();
        let release = temp.path().join("os-release");
        fs::write(
            &release,
            "NAME=Obarun\nID=obarun\nID_LIKE=arch\nPRETTY_NAME=Obarun\n",
        )
        .unwrap();
        let parsed = read_os_release(&release).unwrap();
        assert_eq!(parsed.id, "obarun");
        assert_eq!(parsed.id_like, ["arch"]);
    }

    #[test]
    fn desktop_roles_ignore_process_name_case() {
        assert_eq!(desktop_role("Quickshell"), Some("shell/bar"));
        assert_eq!(desktop_role("MAKO"), Some("notifications"));
    }

    #[test]
    fn audio_recovery_command_is_in_the_machine_inventory() {
        assert!(PROBED_COMMANDS.contains(&"amixer"));
        assert!(PROBED_COMMANDS.contains(&"swayidle"));
    }
}
