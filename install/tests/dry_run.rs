use std::fs;
use std::os::unix::fs::PermissionsExt;
use std::path::Path;
use std::process::Command;

fn executable(path: &Path, body: &str) {
    fs::write(path, body).unwrap();
    let mut permissions = fs::metadata(path).unwrap().permissions();
    permissions.set_mode(0o755);
    fs::set_permissions(path, permissions).unwrap();
}

#[test]
fn cli_dry_run_does_not_touch_home() {
    let temp = tempfile::tempdir().unwrap();
    let home = temp.path().join("home-that-must-stay-absent");
    let config = home.join("config");
    let state = home.join("state");
    let os_release = temp.path().join("os-release");
    fs::write(
        &os_release,
        "NAME=\"Arch Linux\"\nID=arch\nPRETTY_NAME=\"Arch Linux\"\n",
    )
    .unwrap();
    let repo = Path::new(env!("CARGO_MANIFEST_DIR")).parent().unwrap();
    let output = Command::new(env!("CARGO_BIN_EXE_tonantzintla-installer"))
        .arg("--source")
        .arg(repo)
        .arg("dry-run")
        .arg("--profile")
        .arg("full")
        .arg("--niri")
        .arg("replace")
        .env("HOME", &home)
        .env("XDG_CONFIG_HOME", &config)
        .env("XDG_STATE_HOME", &state)
        .env("TONANTZINTLA_INSTALLER_OS_RELEASE", &os_release)
        .env("PATH", "/nonexistent")
        .output()
        .unwrap();
    assert!(
        output.status.success(),
        "{}",
        String::from_utf8_lossy(&output.stderr)
    );
    assert!(String::from_utf8_lossy(&output.stdout).contains("Zero mutations performed"));
    assert!(!home.exists());
}

#[test]
fn json_dry_run_is_machine_readable() {
    let temp = tempfile::tempdir().unwrap();
    let home = temp.path().join("home");
    let os_release = temp.path().join("os-release");
    fs::write(
        &os_release,
        "NAME=\"Arch Linux\"\nID=arch\nPRETTY_NAME=\"Arch Linux\"\n",
    )
    .unwrap();
    let repo = Path::new(env!("CARGO_MANIFEST_DIR")).parent().unwrap();
    let output = Command::new(env!("CARGO_BIN_EXE_tonantzintla-installer"))
        .arg("--source")
        .arg(repo)
        .arg("dry-run")
        .arg("--format")
        .arg("json")
        .env("HOME", &home)
        .env("TONANTZINTLA_INSTALLER_OS_RELEASE", &os_release)
        .env("PATH", "/nonexistent")
        .output()
        .unwrap();
    assert!(output.status.success());
    let value: serde_json::Value = serde_json::from_slice(&output.stdout).unwrap();
    assert_eq!(value["dry_run"], true);
    assert_eq!(value["machine"]["distribution"]["id"], "arch");
    assert_eq!(
        value["install_root"],
        home.join(".local/share/tonantzintla").display().to_string()
    );
    let shell_link = value["operations"]
        .as_array()
        .unwrap()
        .iter()
        .find(|operation| operation["id"] == "link-shell")
        .unwrap();
    assert!(
        shell_link["detail"]
            .as_str()
            .unwrap()
            .ends_with(".local/share/tonantzintla")
    );
    assert!(!shell_link["detail"].as_str().unwrap().contains("/Codex/"));
}

#[test]
fn dry_run_never_executes_mutating_system_commands() {
    let temp = tempfile::tempdir().unwrap();
    let bin = temp.path().join("bin");
    fs::create_dir(&bin).unwrap();
    let mutation_marker = temp.path().join("mutation-attempted");
    let malicious = format!("#!/bin/sh\ntouch '{}'\n", mutation_marker.display());
    for command in [
        "pacman",
        "paru",
        "yay",
        "niri",
        "qs",
        "python3",
        "wpctl",
        "pactl",
        "systemctl",
        "sudo",
    ] {
        executable(&bin.join(command), &malicious);
    }
    executable(&bin.join("fc-match"), "#!/bin/sh\nprintf '%s\\n' \"$3\"\n");
    let os_release = temp.path().join("os-release");
    fs::write(
        &os_release,
        "NAME=\"Arch Linux\"\nID=arch\nPRETTY_NAME=\"Arch Linux\"\n",
    )
    .unwrap();
    let repo = Path::new(env!("CARGO_MANIFEST_DIR")).parent().unwrap();
    let output = Command::new(env!("CARGO_BIN_EXE_tonantzintla-installer"))
        .arg("--source")
        .arg(repo)
        .arg("dry-run")
        .arg("--profile")
        .arg("full")
        .env("HOME", temp.path().join("home"))
        .env("TONANTZINTLA_INSTALLER_OS_RELEASE", &os_release)
        .env("PATH", &bin)
        .output()
        .unwrap();
    assert!(
        output.status.success(),
        "{}",
        String::from_utf8_lossy(&output.stderr)
    );
    assert!(!mutation_marker.exists());
}

#[test]
fn unsupported_distribution_is_inspection_only() {
    let temp = tempfile::tempdir().unwrap();
    let home = temp.path().join("home-that-must-stay-absent");
    let os_release = temp.path().join("os-release");
    fs::write(
        &os_release,
        "NAME=Fedora\nID=fedora\nPRETTY_NAME=\"Fedora Linux\"\n",
    )
    .unwrap();
    let repo = Path::new(env!("CARGO_MANIFEST_DIR")).parent().unwrap();
    let output = Command::new(env!("CARGO_BIN_EXE_tonantzintla-installer"))
        .arg("--source")
        .arg(repo)
        .arg("dry-run")
        .env("HOME", &home)
        .env("TONANTZINTLA_INSTALLER_OS_RELEASE", &os_release)
        .env("PATH", "/nonexistent")
        .output()
        .unwrap();
    assert!(!output.status.success());
    assert!(String::from_utf8_lossy(&output.stdout).contains("inspection only"));
    assert!(String::from_utf8_lossy(&output.stderr).contains("Arch Linux derivatives only"));
    assert!(!home.exists());
}

#[test]
fn obarun_is_a_supported_arch_derivative() {
    let temp = tempfile::tempdir().unwrap();
    let home = temp.path().join("home-that-must-stay-absent");
    let os_release = temp.path().join("os-release");
    fs::write(
        &os_release,
        "NAME=Obarun\nID=obarun\nID_LIKE=arch\nPRETTY_NAME=Obarun\n",
    )
    .unwrap();
    let repo = Path::new(env!("CARGO_MANIFEST_DIR")).parent().unwrap();
    let output = Command::new(env!("CARGO_BIN_EXE_tonantzintla-installer"))
        .arg("--source")
        .arg(repo)
        .arg("dry-run")
        .env("HOME", &home)
        .env("TONANTZINTLA_INSTALLER_OS_RELEASE", &os_release)
        .env("PATH", "/nonexistent")
        .output()
        .unwrap();
    assert!(
        output.status.success(),
        "{}",
        String::from_utf8_lossy(&output.stderr)
    );
    assert!(String::from_utf8_lossy(&output.stdout).contains("Zero mutations performed"));
    let stdout = String::from_utf8_lossy(&output.stdout);
    assert!(stdout.contains("OBARUN DETECTED"));
    assert!(stdout.contains("[obcommunity]"));
    assert!(stdout.contains("/etc/pacman.conf"));
    assert!(!home.exists());
}

#[test]
fn artix_remains_unsupported() {
    let temp = tempfile::tempdir().unwrap();
    let home = temp.path().join("home-that-must-stay-absent");
    let os_release = temp.path().join("os-release");
    fs::write(
        &os_release,
        "NAME=Artix\nID=artix\nID_LIKE=arch\nPRETTY_NAME=Artix\n",
    )
    .unwrap();
    let repo = Path::new(env!("CARGO_MANIFEST_DIR")).parent().unwrap();
    let output = Command::new(env!("CARGO_BIN_EXE_tonantzintla-installer"))
        .arg("--source")
        .arg(repo)
        .arg("dry-run")
        .env("HOME", &home)
        .env("TONANTZINTLA_INSTALLER_OS_RELEASE", &os_release)
        .env("PATH", "/nonexistent")
        .output()
        .unwrap();
    assert!(!output.status.success());
    assert!(String::from_utf8_lossy(&output.stdout).contains("inspection only"));
    let error = String::from_utf8_lossy(&output.stderr);
    assert!(error.contains("ARTIX detected."));
    assert!(error.contains("OPINION REJECTED."));
    assert!(error.contains("left this checkout intact"));
    assert!(error.contains("Obarun on top!"));
    assert!(!home.exists());
}

#[test]
fn report_reads_hardware_and_desktop_owners_without_starting_them() {
    let temp = tempfile::tempdir().unwrap();
    let root = temp.path().join("root");
    for path in [
        "proc/4242",
        "sys/class/power_supply/BAT0",
        "sys/class/backlight/intel_backlight",
        "sys/class/drm/card0-eDP-1",
        "sys/class/bluetooth/hci0",
        "sys/class/net/lo",
        "sys/class/net/wlan0",
    ] {
        fs::create_dir_all(root.join(path)).unwrap();
    }
    fs::write(root.join("proc/4242/comm"), "mako\n").unwrap();
    fs::write(root.join("proc/4242/cmdline"), b"/usr/bin/mako\0").unwrap();
    fs::write(root.join("sys/class/power_supply/BAT0/type"), "Battery\n").unwrap();
    fs::write(root.join("sys/class/drm/card0-eDP-1/status"), "connected\n").unwrap();
    let os_release = temp.path().join("os-release");
    fs::write(
        &os_release,
        "NAME=\"Arch Linux\"\nID=arch\nPRETTY_NAME=\"Arch Linux\"\n",
    )
    .unwrap();
    let repo = Path::new(env!("CARGO_MANIFEST_DIR")).parent().unwrap();
    let output = Command::new(env!("CARGO_BIN_EXE_tonantzintla-installer"))
        .arg("--source")
        .arg(repo)
        .arg("report")
        .arg("--format")
        .arg("json")
        .env("HOME", temp.path().join("home"))
        .env("TONANTZINTLA_INSTALLER_ROOT", &root)
        .env("TONANTZINTLA_INSTALLER_OS_RELEASE", &os_release)
        .env("PATH", "/nonexistent")
        .output()
        .unwrap();
    assert!(output.status.success());
    let value: serde_json::Value = serde_json::from_slice(&output.stdout).unwrap();
    assert_eq!(value["hardware"]["batteries"], 1);
    assert_eq!(value["hardware"]["backlights"], 1);
    assert_eq!(value["hardware"]["drm_connectors"], 1);
    assert_eq!(value["hardware"]["bluetooth_present"], true);
    assert_eq!(value["hardware"]["network_present"], true);
    assert_eq!(value["desktop_processes"][0]["name"], "mako");
    assert_eq!(value["desktop_processes"][0]["role"], "notifications");
    assert_eq!(value["desktop_processes"][0]["tonantzintla_owned"], false);
}
