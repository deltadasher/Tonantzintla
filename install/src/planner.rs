use std::collections::BTreeSet;
use std::path::{Path, PathBuf};

use crate::cli::{NiriMode, Profile, UmbraMode};
use crate::manifest::{Capability, FeatureManifest};
use crate::model::{
    CapabilityPlan, FeaturePlan, FeatureStatus, InstallPlan, MachineReport, OperationScope,
    OperationState, PlannedOperation,
};
use crate::probe::{ProbeContext, command_set};

#[derive(Clone, Copy, Debug)]
pub struct InstallOptions {
    pub profile: Profile,
    pub niri: NiriMode,
    pub umbra: UmbraMode,
}

const OBARUN_REPOSITORY_NOTICE: &str = "OBARUN DETECTED\nBefore installing, make sure [obcommunity] and its Server line are enabled in /etc/pacman.conf. Tonantzintla relies on that repository for packages that Obarun does not provide in its default repositories.";

pub fn build_plan(
    source: &Path,
    probe: &ProbeContext,
    report: &MachineReport,
    manifest: &FeatureManifest,
    options: &InstallOptions,
) -> InstallPlan {
    let installed_commands = command_set(report);
    let install_root = probe.data_home.join("tonantzintla");
    let mut features = Vec::new();
    let mut operations = Vec::new();
    let mut warnings = Vec::new();

    if !report.is_arch() {
        warnings.push(format!(
            "{} is not supported yet; only read-only inspection is available",
            report.distribution.pretty_name
        ));
    }
    if report.distribution.id == "obarun" {
        warnings.push(OBARUN_REPOSITORY_NOTICE.to_string());
    }
    let local_bin = probe.home.join(".local/bin");
    if !report.path_entries.iter().any(|entry| entry == &local_bin) {
        warnings.push(format!(
            "{} is not in PATH. Tonantzintla will still install its command there; use the absolute path or add `export PATH=\"$HOME/.local/bin:$PATH\"` to your shell startup file.",
            local_bin.display()
        ));
    }

    for group in &manifest.groups {
        let selected = group
            .profiles
            .iter()
            .any(|profile| profile == options.profile.id());
        let mut capabilities = Vec::new();
        for capability in &group.capabilities {
            let (available, available_source) = capability_available(
                capability,
                probe,
                report,
                &installed_commands,
                &report.path_entries,
            );
            capabilities.push(CapabilityPlan {
                id: capability.id.clone(),
                label: capability.label.clone(),
                available,
                source: available_source,
                official_packages: capability.official_packages.clone(),
                aur_packages: capability.aur_packages.clone(),
            });

            if selected && !available {
                operations.push(package_operation(capability, report.is_arch()));
            }
        }
        let available_count = capabilities.iter().filter(|cap| cap.available).count();
        let status = if !selected {
            FeatureStatus::Skipped
        } else if available_count == capabilities.len() {
            FeatureStatus::Ready
        } else if available_count == 0 {
            FeatureStatus::Missing
        } else {
            FeatureStatus::Partial
        };
        features.push(FeaturePlan {
            id: group.id.clone(),
            label: group.label.clone(),
            selected,
            required: group.required,
            status,
            capabilities,
        });
    }

    add_runtime_operation(source, &install_root, &mut operations);
    if probe.config_home.join("astralith").is_dir() {
        warnings.push("Migration: existing Astralith preferences will be copied only if Tonantzintla preferences are absent. Existing Astralith command links will be redirected; its old runtime is retained for recovery.".into());
    }
    add_user_link_operations(&install_root, probe, &mut operations);
    add_desktop_ownership_operations(report, &mut operations);
    operations.push(PlannedOperation {
        id: "validate-source".into(),
        scope: OperationScope::Validation,
        state: OperationState::Planned,
        summary: "Validate the staged and installed runtime".into(),
        detail: format!(
            "Verify runtime structure, executable modes, and run {} doctor",
            install_root.join("bin/blackhole").display()
        ),
        requires_root: false,
    });
    add_niri_operation(&install_root, probe, options.niri, &mut operations);
    add_umbra_operation(&install_root, options.umbra, &mut operations);

    InstallPlan {
        dry_run: true,
        supported: report.is_arch(),
        source: source.to_path_buf(),
        install_root,
        profile: options.profile.id().to_string(),
        machine: report.clone(),
        features,
        operations,
        warnings,
    }
}

fn add_runtime_operation(
    source: &Path,
    install_root: &Path,
    operations: &mut Vec<PlannedOperation>,
) {
    let source_canonical = source
        .canonicalize()
        .unwrap_or_else(|_| source.to_path_buf());
    let target_canonical = install_root.canonicalize().ok();
    let (state, summary, detail) = if target_canonical.as_ref() == Some(&source_canonical) {
        (
            OperationState::Satisfied,
            "Use the existing Tonantzintla runtime".to_string(),
            install_root.display().to_string(),
        )
    } else {
        match std::fs::symlink_metadata(install_root) {
            Err(error) if error.kind() == std::io::ErrorKind::NotFound => (
                OperationState::Planned,
                "Install the Tonantzintla runtime".to_string(),
                format!("Stage the verified checkout at {}", install_root.display()),
            ),
            Ok(metadata)
                if metadata.is_dir()
                    && (install_root.join("src/quickshell/shell.qml").is_file()
                        || (install_root.join("shell.qml").is_file()
                            && install_root.join("bin/blackhole").is_file()
                            && install_root.join(".tonantzintla-install/source").is_file()))
                    && install_root.join("VERSION").is_file() =>
            {
                (
                    OperationState::Planned,
                    "Update the installed Tonantzintla runtime".to_string(),
                    format!("Stage and validate changes in {}", install_root.display()),
                )
            }
            Ok(_) => (
                OperationState::Conflict,
                "Preserve the existing runtime destination".to_string(),
                format!(
                    "{} is not an Tonantzintla installation",
                    install_root.display()
                ),
            ),
            Err(error) => (
                OperationState::Conflict,
                "Could not inspect the runtime destination".to_string(),
                format!("{}: {error}", install_root.display()),
            ),
        }
    };
    operations.push(PlannedOperation {
        id: "install-runtime".into(),
        scope: OperationScope::UserFile,
        state,
        summary,
        detail,
        requires_root: false,
    });
}

fn add_desktop_ownership_operations(
    report: &MachineReport,
    operations: &mut Vec<PlannedOperation>,
) {
    let roles = report
        .desktop_processes
        .iter()
        .filter(|process| !process.tonantzintla_owned)
        .map(|process| process.role.as_str())
        .collect::<BTreeSet<_>>();
    for role in roles.iter().copied() {
        let owners = report
            .desktop_processes
            .iter()
            .filter(|process| !process.tonantzintla_owned && process.role == role)
            .map(|process| format!("{} ({})", process.name, process.pid))
            .collect::<Vec<_>>()
            .join(", ");
        operations.push(PlannedOperation {
            id: format!("desktop-owner-{}", role.replace(['/', ' '], "-")),
            scope: OperationScope::Validation,
            state: OperationState::Conflict,
            summary: format!("Review existing {role} ownership"),
            detail: format!("Detected {owners}; the executor leaves it untouched"),
            requires_root: false,
        });
    }
}

fn capability_available(
    capability: &Capability,
    probe: &ProbeContext,
    report: &MachineReport,
    installed_commands: &BTreeSet<&str>,
    path_entries: &[PathBuf],
) -> (bool, Option<String>) {
    if let Some(command) = &capability.command {
        let available = installed_commands.contains(command.as_str());
        let source = available.then(|| {
            path_entries
                .iter()
                .map(|entry| entry.join(command))
                .find(|path| path.is_file())
                .map(|path| path.display().to_string())
                .unwrap_or_else(|| command.clone())
        });
        return (available, source);
    }
    if let Some(file) = &capability.file {
        let path = Path::new(file);
        let available = probe.path_exists(path);
        return (available, available.then_some(file.clone()));
    }
    if let Some(family) = &capability.font_family {
        let status = report.font(family);
        return (
            status.is_some_and(|font| font.available),
            status.and_then(|font| font.resolved_as.clone()),
        );
    }
    (false, None)
}

fn package_operation(capability: &Capability, supported: bool) -> PlannedOperation {
    let (state, summary, detail) = if !supported {
        (
            OperationState::Blocked,
            format!("Resolve {} manually", capability.label),
            "No package adapter exists for this distribution".to_string(),
        )
    } else if !capability.official_packages.is_empty() {
        (
            OperationState::Planned,
            format!("Install {}", capability.label),
            format!(
                "pacman packages: {}",
                capability.official_packages.join(", ")
            ),
        )
    } else {
        (
            OperationState::Manual,
            format!("Install {} from the AUR", capability.label),
            format!("AUR candidates: {}", capability.aur_packages.join(", ")),
        )
    };
    PlannedOperation {
        id: format!("package-{}", capability.id),
        scope: OperationScope::Package,
        state,
        summary,
        detail,
        requires_root: !capability.official_packages.is_empty(),
    }
}

fn add_user_link_operations(
    install_root: &Path,
    probe: &ProbeContext,
    operations: &mut Vec<PlannedOperation>,
) {
    add_link_operation(
        "link-shell",
        &probe.config_home.join("quickshell/tonantzintla"),
        install_root,
        operations,
    );
    add_link_operation(
        "link-control-command",
        &probe.home.join(".local/bin/blackhole"),
        &install_root.join("bin/blackhole"),
        operations,
    );
}

fn add_link_operation(
    id: &str,
    target: &Path,
    expected: &Path,
    operations: &mut Vec<PlannedOperation>,
) {
    let (state, summary) = match std::fs::symlink_metadata(target) {
        Ok(metadata) if metadata.file_type().is_symlink() => {
            let matches = std::fs::read_link(target)
                .ok()
                .and_then(|link| {
                    let absolute = if link.is_absolute() {
                        link
                    } else {
                        target.parent().unwrap_or_else(|| Path::new("/")).join(link)
                    };
                    absolute.canonicalize().ok()
                })
                .is_some_and(|path| {
                    path == expected
                        .canonicalize()
                        .unwrap_or_else(|_| expected.to_path_buf())
                });
            if matches {
                (
                    OperationState::Satisfied,
                    format!("Keep {}", target.display()),
                )
            } else {
                (
                    OperationState::Conflict,
                    format!("Review existing link {}", target.display()),
                )
            }
        }
        Ok(_) => (
            OperationState::Conflict,
            format!("Preserve existing {}", target.display()),
        ),
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => (
            OperationState::Planned,
            format!("Create link {}", target.display()),
        ),
        Err(_) => (
            OperationState::Conflict,
            format!("Could not inspect {}", target.display()),
        ),
    };
    operations.push(PlannedOperation {
        id: id.into(),
        scope: OperationScope::UserFile,
        state,
        summary,
        detail: format!("{} -> {}", target.display(), expected.display()),
        requires_root: false,
    });
}

fn add_niri_operation(
    source: &Path,
    probe: &ProbeContext,
    mode: NiriMode,
    operations: &mut Vec<PlannedOperation>,
) {
    let target = probe.config_home.join("niri/config.kdl");
    let (state, summary, detail) = match mode {
        NiriMode::Keep => (
            OperationState::Skipped,
            "Keep the current Niri configuration".into(),
            "Tonantzintla bindings will be shown but not installed".into(),
        ),
        NiriMode::Replace => (
            OperationState::Planned,
            "Validate, back up, and replace the Niri configuration".into(),
            format!(
                "{} -> {}; existing config receives a timestamped backup",
                source.join("compositors/niri/config.kdl").display(),
                target.display()
            ),
        ),
    };
    operations.push(PlannedOperation {
        id: "niri-config".into(),
        scope: OperationScope::Niri,
        state,
        summary,
        detail,
        requires_root: false,
    });
}

fn add_umbra_operation(source: &Path, mode: UmbraMode, operations: &mut Vec<PlannedOperation>) {
    let (state, summary, detail) = match mode {
        UmbraMode::Off => (
            OperationState::Skipped,
            "Skip Umbra integration".into(),
            "No lock or greeter changes".into(),
        ),
        UmbraMode::Lock => (
            OperationState::Planned,
            "Install the Umbra session-lock module".into(),
            "Show the non-secure preview command; do not expose a real lock binding".into(),
        ),
        UmbraMode::GreeterPreview => (
            OperationState::Planned,
            "Install Umbra lock and greeter preview files".into(),
            format!(
                "Show the {} backend command without writing /etc or activating a greeter",
                source.join("src/libexec/umbra-greeter-portable").display()
            ),
        ),
    };
    operations.push(PlannedOperation {
        id: "umbra".into(),
        scope: OperationScope::Umbra,
        state,
        summary,
        detail,
        requires_root: false,
    });
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;

    fn fake_context(root: &Path) -> ProbeContext {
        let bin = root.join("bin");
        fs::create_dir_all(&bin).unwrap();
        for command in ["pacman", "niri", "qs", "python3", "wpctl", "pactl"] {
            let path = bin.join(command);
            fs::write(&path, "#!/bin/sh\nexit 0\n").unwrap();
            let mut permissions = fs::metadata(&path).unwrap().permissions();
            std::os::unix::fs::PermissionsExt::set_mode(&mut permissions, 0o755);
            fs::set_permissions(path, permissions).unwrap();
        }
        let release = root.join("os-release");
        fs::write(
            &release,
            "NAME=\"Arch Linux\"\nID=arch\nPRETTY_NAME=\"Arch Linux\"\n",
        )
        .unwrap();
        ProbeContext {
            home: root.join("home"),
            config_home: root.join("home/.config"),
            data_home: root.join("home/.local/share"),
            state_home: root.join("home/.local/state"),
            path_entries: vec![bin],
            os_release: release,
        }
    }

    #[test]
    fn dry_run_planning_does_not_create_user_paths() {
        let temp = tempfile::tempdir().unwrap();
        let source = Path::new(env!("CARGO_MANIFEST_DIR")).parent().unwrap();
        let context = fake_context(temp.path());
        let report = context.inspect();
        let manifest = FeatureManifest::load(&source.join("install/features.toml")).unwrap();
        let plan = build_plan(
            source,
            &context,
            &report,
            &manifest,
            &InstallOptions {
                profile: Profile::Recommended,
                niri: NiriMode::Replace,
                umbra: UmbraMode::GreeterPreview,
            },
        );
        assert!(plan.dry_run);
        assert!(!context.home.exists());
        assert!(plan.operations.iter().any(|op| op.id == "link-shell"));
        assert!(plan.operations.iter().any(|op| op.id == "niri-config"));
    }

    #[test]
    fn obarun_plan_warns_about_obcommunity() {
        let temp = tempfile::tempdir().unwrap();
        let source = Path::new(env!("CARGO_MANIFEST_DIR")).parent().unwrap();
        let context = fake_context(temp.path());
        fs::write(
            &context.os_release,
            "NAME=Obarun\nID=obarun\nID_LIKE=arch\nPRETTY_NAME=Obarun\n",
        )
        .unwrap();
        let report = context.inspect();
        let manifest = FeatureManifest::load(&source.join("install/features.toml")).unwrap();
        let plan = build_plan(
            source,
            &context,
            &report,
            &manifest,
            &InstallOptions {
                profile: Profile::Recommended,
                niri: NiriMode::Replace,
                umbra: UmbraMode::GreeterPreview,
            },
        );
        let notice = plan.warnings.join("\n");
        assert!(notice.contains("OBARUN DETECTED"));
        assert!(notice.contains("[obcommunity]"));
        assert!(notice.contains("/etc/pacman.conf"));
    }

    #[test]
    fn plan_warns_when_user_local_bin_is_not_on_path() {
        let temp = tempfile::tempdir().unwrap();
        let source = Path::new(env!("CARGO_MANIFEST_DIR")).parent().unwrap();
        let context = fake_context(temp.path());
        let report = context.inspect();
        let manifest = FeatureManifest::load(&source.join("install/features.toml")).unwrap();
        let plan = build_plan(
            source,
            &context,
            &report,
            &manifest,
            &InstallOptions {
                profile: Profile::Recommended,
                niri: NiriMode::Keep,
                umbra: UmbraMode::Off,
            },
        );
        let notice = plan.warnings.join("\n");
        assert!(notice.contains(".local/bin"));
        assert!(notice.contains("export PATH="));
    }
}
