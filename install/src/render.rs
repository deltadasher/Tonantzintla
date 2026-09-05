use std::fmt::Write;

use crate::model::{FeatureStatus, InstallPlan, MachineReport, OperationState};

pub fn report_text(report: &MachineReport) -> String {
    let mut out = String::new();
    let _ = writeln!(out, "TONANTZINTLA // MACHINE REPORT");
    let _ = writeln!(out, "Distribution : {}", report.distribution.pretty_name);
    let _ = writeln!(out, "Architecture : {}", report.architecture);
    let _ = writeln!(
        out,
        "Package tool : {}",
        report.package_manager.as_deref().unwrap_or("not detected")
    );
    let _ = writeln!(out, "Config home  : {}", report.config_home.display());
    let _ = writeln!(out, "Data home    : {}", report.data_home.display());
    let _ = writeln!(
        out,
        "Session      : {} / {}",
        report.session_type.as_deref().unwrap_or("unknown"),
        report.desktop.as_deref().unwrap_or("unknown")
    );
    let _ = writeln!(
        out,
        "Display mgr  : {}",
        report.display_manager.as_deref().unwrap_or("not detected")
    );
    let _ = writeln!(out, "\nCapabilities");
    for command in &report.commands {
        let _ = writeln!(
            out,
            "  {:<10} {:<22} {}",
            if command.path.is_some() {
                "READY"
            } else {
                "MISSING"
            },
            command.name,
            command
                .path
                .as_ref()
                .map(|path| path.display().to_string())
                .unwrap_or_default()
        );
    }
    let _ = writeln!(out, "\nFonts");
    for font in &report.fonts {
        let _ = writeln!(
            out,
            "  {:<10} {:<22} {}",
            if font.available { "READY" } else { "MISSING" },
            font.family,
            font.resolved_as.as_deref().unwrap_or_default()
        );
    }
    let _ = writeln!(out, "\nHardware");
    let _ = writeln!(out, "  Batteries       {}", report.hardware.batteries);
    let _ = writeln!(out, "  Backlights      {}", report.hardware.backlights);
    let _ = writeln!(out, "  Connected DRM   {}", report.hardware.drm_connectors);
    let _ = writeln!(
        out,
        "  Network         {}",
        yes_no(report.hardware.network_present)
    );
    let _ = writeln!(
        out,
        "  Bluetooth       {}",
        yes_no(report.hardware.bluetooth_present)
    );
    let _ = writeln!(
        out,
        "  Power profiles  {}",
        yes_no(report.hardware.power_profiles_present)
    );
    let _ = writeln!(out, "\nDesktop ownership");
    if report.desktop_processes.is_empty() {
        let _ = writeln!(out, "  No known desktop owner processes detected");
    }
    for process in &report.desktop_processes {
        let owner = if process.tonantzintla_owned {
            "Tonantzintla"
        } else {
            "external"
        };
        let _ = writeln!(
            out,
            "  {:<14} {:<16} pid {:<7} {}",
            process.role, process.name, process.pid, owner
        );
    }
    out
}

fn yes_no(value: bool) -> &'static str {
    if value { "yes" } else { "no" }
}

pub fn plan_text(plan: &InstallPlan) -> String {
    plan_text_with_mode(plan, true)
}

pub fn execution_plan_text(plan: &InstallPlan) -> String {
    plan_text_with_mode(plan, false)
}

fn plan_text_with_mode(plan: &InstallPlan, dry_run: bool) -> String {
    let mut out = String::new();
    if dry_run {
        let _ = writeln!(out, "TONANTZINTLA // DRY RUN");
        let _ = writeln!(
            out,
            "No packages, files, services, or settings will be changed.\n"
        );
    } else {
        let _ = writeln!(out, "TONANTZINTLA // EXECUTION PLAN");
        let _ = writeln!(
            out,
            "The reviewed operations below will change this machine.\n"
        );
    }
    let _ = writeln!(
        out,
        "Machine : {} ({})",
        plan.machine.distribution.pretty_name, plan.machine.architecture
    );
    let _ = writeln!(out, "Source  : {}", plan.source.display());
    let _ = writeln!(out, "Install : {}", plan.install_root.display());
    let _ = writeln!(out, "Profile : {}", plan.profile);
    let _ = writeln!(
        out,
        "Support : {}",
        if plan.supported {
            "Arch adapter ready"
        } else {
            "inspection only"
        }
    );

    let _ = writeln!(out, "\nFeature readiness");
    for feature in &plan.features {
        let status = match feature.status {
            FeatureStatus::Ready => "READY",
            FeatureStatus::Partial => "PARTIAL",
            FeatureStatus::Missing => "MISSING",
            FeatureStatus::Skipped => "SKIP",
        };
        let _ = writeln!(out, "  {status:<8} {}", feature.label);
        if feature.selected {
            for capability in feature.capabilities.iter().filter(|cap| !cap.available) {
                let candidates = if !capability.official_packages.is_empty() {
                    capability.official_packages.join(", ")
                } else {
                    format!("AUR: {}", capability.aur_packages.join(", "))
                };
                let _ = writeln!(out, "             - {} [{}]", capability.label, candidates);
            }
        }
    }

    let _ = writeln!(out, "\nPlanned operations");
    for operation in &plan.operations {
        let state = match operation.state {
            OperationState::Satisfied => "DONE",
            OperationState::Planned => "PLAN",
            OperationState::Manual => "MANUAL",
            OperationState::Conflict => "REVIEW",
            OperationState::Skipped => "SKIP",
            OperationState::Blocked => "BLOCKED",
        };
        let root = if operation.requires_root {
            " [sudo]"
        } else {
            ""
        };
        let _ = writeln!(out, "  {state:<8} {}{root}", operation.summary);
        let _ = writeln!(out, "           {}", operation.detail);
    }

    if !plan.warnings.is_empty() {
        let _ = writeln!(out, "\nWarnings");
        for warning in &plan.warnings {
            let _ = writeln!(out, "  - {warning}");
        }
    }
    if dry_run {
        let _ = writeln!(out, "\nDry run complete. Zero mutations performed.");
    }
    out
}
