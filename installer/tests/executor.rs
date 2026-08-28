use std::fs;
use std::os::unix::fs::{PermissionsExt, symlink};
use std::path::{Path, PathBuf};
use std::process::{Command, Output};

use serde_json::Value;

fn executable(path: &Path, body: &str) {
    fs::write(path, body).unwrap();
    let mut permissions = fs::metadata(path).unwrap().permissions();
    permissions.set_mode(0o755);
    fs::set_permissions(path, permissions).unwrap();
}

fn fixture(root: &Path, version: &str) -> PathBuf {
    let source = root.join("source");
    for directory in [
        "installer",
        "installer/target/debug",
        "modules/ephemeris",
        "modules/umbra",
        "niri",
        "scripts",
        ".git/objects",
    ] {
        fs::create_dir_all(source.join(directory)).unwrap();
    }
    fs::write(source.join("VERSION"), format!("{version}\n")).unwrap();
    fs::write(source.join("shell.qml"), "// shell\n").unwrap();
    fs::write(
        source.join("modules/ephemeris/EphemerisSurface.qml"),
        "// ephemeris\n",
    )
    .unwrap();
    fs::write(source.join("modules/umbra/UmbraSurface.qml"), "// umbra\n").unwrap();
    fs::write(source.join("niri/config.kdl"), "// niri\n").unwrap();
    fs::write(source.join(".git/objects/secret"), "not runtime\n").unwrap();
    fs::write(
        source.join("installer/target/debug/artifact"),
        "not runtime\n",
    )
    .unwrap();
    fs::write(
        source.join("installer/features.toml"),
        r#"schema = 1

[[groups]]
id = "core"
label = "Core"
description = "Core runtime"
profiles = ["core", "recommended", "full"]
required = true

[[groups.capabilities]]
id = "niri"
label = "Niri"
command = "niri"
official_packages = ["niri"]

[[groups.capabilities]]
id = "quickshell"
label = "Quickshell"
command = "qs"
official_packages = ["quickshell"]

[[groups.capabilities]]
id = "python"
label = "Python"
command = "python3"
official_packages = ["python"]

[[groups.capabilities]]
id = "wpctl"
label = "wpctl"
command = "wpctl"
official_packages = ["wireplumber"]

[[groups.capabilities]]
id = "pactl"
label = "pactl"
command = "pactl"
official_packages = ["libpulse"]
"#,
    )
    .unwrap();
    executable(&source.join("scripts/astralithctl"), "#!/bin/sh\nexit 0\n");
    executable(&source.join("scripts/doctor"), "#!/bin/sh\nexit 0\n");
    source
}

struct Sandbox {
    _temp: tempfile::TempDir,
    source: PathBuf,
    home: PathBuf,
    data: PathBuf,
    config: PathBuf,
    state: PathBuf,
    root: PathBuf,
    bin: PathBuf,
    os_release: PathBuf,
}

impl Sandbox {
    fn new(version: &str) -> Self {
        let temp = tempfile::tempdir().unwrap();
        let source = fixture(temp.path(), version);
        let home = temp.path().join("home");
        let data = home.join(".local/share");
        let config = home.join(".config");
        let state = home.join(".local/state");
        let root = temp.path().join("root");
        let bin = temp.path().join("bin");
        fs::create_dir_all(&root).unwrap();
        fs::create_dir_all(&bin).unwrap();
        for command in ["pacman", "niri", "qs", "python3", "wpctl", "pactl"] {
            executable(&bin.join(command), "#!/bin/sh\nexit 0\n");
        }
        let os_release = temp.path().join("os-release");
        fs::write(
            &os_release,
            "NAME=\"Arch Linux\"\nID=arch\nPRETTY_NAME=\"Arch Linux\"\n",
        )
        .unwrap();
        Self {
            _temp: temp,
            source,
            home,
            data,
            config,
            state,
            root,
            bin,
            os_release,
        }
    }

    fn apply(&self, extra: &[&str]) -> Output {
        let mut command = Command::new(env!("CARGO_BIN_EXE_astralith-installer"));
        command
            .arg("--source")
            .arg(&self.source)
            .arg("apply")
            .arg("--profile")
            .arg("core")
            .arg("--umbra")
            .arg("off")
            .arg("--yes")
            .args(extra)
            .env("HOME", &self.home)
            .env("XDG_CONFIG_HOME", &self.config)
            .env("XDG_DATA_HOME", &self.data)
            .env("XDG_STATE_HOME", &self.state)
            .env("ASTRALITH_INSTALLER_ROOT", &self.root)
            .env("ASTRALITH_INSTALLER_OS_RELEASE", &self.os_release)
            .env("ASTRALITH_INSTALLER_TEST_ALLOW_ROOT", "1")
            .env("PATH", &self.bin)
            .output()
            .unwrap()
    }

    fn install_root(&self) -> PathBuf {
        self.data.join("astralith")
    }

    fn journals(&self) -> Vec<Value> {
        let directory = self.state.join("astralith/installer/transactions");
        let mut paths = fs::read_dir(directory)
            .unwrap()
            .flatten()
            .map(|entry| entry.path())
            .collect::<Vec<_>>();
        paths.sort();
        paths
            .into_iter()
            .map(|path| serde_json::from_slice(&fs::read(path).unwrap()).unwrap())
            .collect()
    }
}

#[test]
fn apply_installs_runtime_links_and_complete_journal() {
    let sandbox = Sandbox::new("1.0.0");
    let output = sandbox.apply(&[]);
    assert!(
        output.status.success(),
        "stdout:\n{}\nstderr:\n{}",
        String::from_utf8_lossy(&output.stdout),
        String::from_utf8_lossy(&output.stderr)
    );
    let install = sandbox.install_root();
    assert_eq!(
        fs::read_to_string(install.join("VERSION")).unwrap(),
        "1.0.0\n"
    );
    assert!(!install.join(".git").exists());
    assert!(!install.join("installer/target").exists());
    assert_eq!(
        fs::read_to_string(install.join(".astralith-install/source"))
            .unwrap()
            .trim(),
        sandbox.source.canonicalize().unwrap().to_string_lossy()
    );
    assert_eq!(
        fs::read_to_string(install.join(".astralith-install/profile"))
            .unwrap()
            .trim(),
        "core"
    );
    assert_eq!(
        fs::read_to_string(install.join(".astralith-install/niri"))
            .unwrap()
            .trim(),
        "keep"
    );
    assert_eq!(
        fs::read_to_string(install.join(".astralith-install/umbra"))
            .unwrap()
            .trim(),
        "off"
    );
    let installed_executor = install.join("bin/astralith-installer");
    assert!(installed_executor.is_file());
    assert_ne!(
        fs::metadata(installed_executor)
            .unwrap()
            .permissions()
            .mode()
            & 0o111,
        0
    );
    assert_eq!(
        fs::read_link(sandbox.config.join("quickshell/astralith")).unwrap(),
        install
    );
    assert_eq!(
        fs::read_link(sandbox.home.join(".local/bin/astralithctl")).unwrap(),
        sandbox.install_root().join("scripts/astralithctl")
    );
    let journals = sandbox.journals();
    assert_eq!(journals.len(), 1);
    assert_eq!(journals[0]["status"], "complete");
}

#[test]
fn second_identical_apply_is_idempotent() {
    let sandbox = Sandbox::new("1.0.0");
    assert!(sandbox.apply(&[]).status.success());
    let first_runtime = fs::canonicalize(sandbox.install_root()).unwrap();
    let output = sandbox.apply(&[]);
    assert!(output.status.success());
    assert_eq!(
        fs::canonicalize(sandbox.install_root()).unwrap(),
        first_runtime
    );
    let previous = fs::read_dir(&sandbox.data)
        .unwrap()
        .flatten()
        .filter(|entry| entry.file_name().to_string_lossy().contains(".previous-"))
        .count();
    assert_eq!(previous, 0);
    assert_eq!(sandbox.journals().len(), 2);
}

#[test]
fn update_replaces_runtime_and_preserves_previous_copy() {
    let sandbox = Sandbox::new("1.0.0");
    assert!(sandbox.apply(&[]).status.success());
    fs::write(sandbox.source.join("VERSION"), "2.0.0\n").unwrap();
    let output = sandbox.apply(&[]);
    assert!(output.status.success());
    assert_eq!(
        fs::read_to_string(sandbox.install_root().join("VERSION")).unwrap(),
        "2.0.0\n"
    );
    let previous = fs::read_dir(&sandbox.data)
        .unwrap()
        .flatten()
        .map(|entry| entry.path())
        .find(|path| {
            path.file_name()
                .unwrap()
                .to_string_lossy()
                .contains(".previous-")
        })
        .unwrap();
    assert_eq!(
        fs::read_to_string(previous.join("VERSION")).unwrap(),
        "1.0.0\n"
    );
}

#[test]
fn failed_niri_validation_rolls_back_runtime_links_and_config() {
    let sandbox = Sandbox::new("1.0.0");
    assert!(sandbox.apply(&[]).status.success());
    fs::write(sandbox.source.join("VERSION"), "2.0.0\n").unwrap();
    let niri_config = sandbox.config.join("niri/config.kdl");
    fs::create_dir_all(niri_config.parent().unwrap()).unwrap();
    fs::write(&niri_config, "// original\n").unwrap();
    executable(&sandbox.bin.join("niri"), "#!/bin/sh\nexit 7\n");
    let output = sandbox.apply(&["--niri", "replace"]);
    assert!(!output.status.success());
    assert_eq!(
        fs::read_to_string(sandbox.install_root().join("VERSION")).unwrap(),
        "1.0.0\n"
    );
    assert_eq!(fs::read_to_string(&niri_config).unwrap(), "// original\n");
    assert_eq!(sandbox.journals().last().unwrap()["status"], "rolled-back");
}

#[test]
fn existing_entrypoints_are_backed_up_before_replacement() {
    let sandbox = Sandbox::new("1.0.0");
    let old = sandbox.home.join("old-shell");
    fs::create_dir_all(&old).unwrap();
    let link = sandbox.config.join("quickshell/astralith");
    fs::create_dir_all(link.parent().unwrap()).unwrap();
    symlink(&old, &link).unwrap();
    let output = sandbox.apply(&[]);
    assert!(output.status.success());
    assert_eq!(fs::read_link(&link).unwrap(), sandbox.install_root());
    let journal = sandbox.journals().pop().unwrap();
    assert!(
        journal["backups"]
            .as_array()
            .unwrap()
            .iter()
            .any(|backup| { backup["original"].as_str() == Some(link.to_string_lossy().as_ref()) })
    );
}

#[test]
fn missing_official_capability_uses_privilege_broker_and_pacman_needed() {
    let sandbox = Sandbox::new("1.0.0");
    fs::remove_file(sandbox.bin.join("qs")).unwrap();
    let marker = sandbox._temp.path().join("sudo-arguments");
    executable(
        &sandbox.bin.join("sudo"),
        &format!(
            "#!/bin/sh\nprintf '%s\\n' \"$*\" > '{}'\n",
            marker.display()
        ),
    );
    let output = sandbox.apply(&[]);
    assert!(
        output.status.success(),
        "stdout:\n{}\nstderr:\n{}",
        String::from_utf8_lossy(&output.stdout),
        String::from_utf8_lossy(&output.stderr)
    );
    let arguments = fs::read_to_string(marker).unwrap();
    assert!(
        arguments.contains("pacman -S --needed quickshell"),
        "{arguments}"
    );
    let journal = sandbox.journals().pop().unwrap();
    assert!(
        journal["commands"]
            .as_array()
            .unwrap()
            .iter()
            .any(|command| {
                command["program"]
                    .as_str()
                    .is_some_and(|program| program.ends_with("/sudo"))
            })
    );
}

#[test]
fn failed_installed_doctor_removes_first_install_and_entrypoints() {
    let sandbox = Sandbox::new("1.0.0");
    executable(
        &sandbox.source.join("scripts/doctor"),
        "#!/bin/sh\nexit 9\n",
    );
    let output = sandbox.apply(&[]);
    assert!(!output.status.success());
    assert!(!sandbox.install_root().exists());
    assert!(!sandbox.config.join("quickshell/astralith").exists());
    assert!(!sandbox.home.join(".local/bin/astralithctl").exists());
    assert_eq!(sandbox.journals().pop().unwrap()["status"], "rolled-back");
}

#[test]
fn unavailable_official_candidate_uses_manifest_aur_fallback() {
    let sandbox = Sandbox::new("1.0.0");
    fs::remove_file(sandbox.bin.join("qs")).unwrap();
    executable(
        &sandbox.bin.join("pacman"),
        "#!/bin/sh\n[ \"$1\" != -Si ]\n",
    );
    let marker = sandbox._temp.path().join("aur-arguments");
    executable(
        &sandbox.bin.join("paru"),
        &format!(
            "#!/bin/sh\nprintf '%s\\n' \"$*\" > '{}'\n",
            marker.display()
        ),
    );
    let manifest = sandbox.source.join("installer/features.toml");
    let contents = fs::read_to_string(&manifest).unwrap().replace(
        "official_packages = [\"quickshell\"]",
        "official_packages = [\"quickshell\"]\naur_packages = [\"quickshell-git\"]",
    );
    fs::write(manifest, contents).unwrap();
    let output = sandbox.apply(&[]);
    assert!(
        output.status.success(),
        "stdout:\n{}\nstderr:\n{}",
        String::from_utf8_lossy(&output.stdout),
        String::from_utf8_lossy(&output.stderr)
    );
    assert_eq!(
        fs::read_to_string(marker).unwrap().trim(),
        "-S --needed quickshell-git"
    );
}
