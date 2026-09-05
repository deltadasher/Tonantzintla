use std::collections::{BTreeMap, BTreeSet};
use std::fs;
use std::hash::{DefaultHasher, Hash, Hasher};
use std::io::{self, IsTerminal, Read, Write};
use std::os::unix::fs::{PermissionsExt, symlink};
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};

use anyhow::{Context, Result, bail, ensure};

use crate::cli::{NiriMode, UmbraMode};
use crate::journal::{
    BackupRecord, CommandRecord, JournalStore, TransactionJournal, TransactionStatus,
};
use crate::model::{CapabilityPlan, InstallPlan, OperationState};
use crate::planner::InstallOptions;
use crate::render;

pub fn execute(plan: &InstallPlan, options: &InstallOptions, assume_yes: bool) -> Result<()> {
    ensure!(
        plan.supported,
        "the executor currently supports compatible Arch Linux derivatives only"
    );
    ensure!(
        !running_as_root() || test_root_override(),
        "run the installer as your normal user, not root"
    );
    ensure!(
        !plan.operations.iter().any(|operation| {
            operation.id == "install-runtime"
                && matches!(
                    operation.state,
                    OperationState::Conflict | OperationState::Blocked
                )
        }),
        "the Tonantzintla runtime destination is occupied by an unrelated path"
    );

    println!("{}", render::execution_plan_text(plan));
    if !assume_yes && !confirm_install()? {
        println!("Installation cancelled. Nothing was changed.");
        return Ok(());
    }

    let mut journal = TransactionJournal::new(&plan.source, &plan.install_root, &plan.profile);
    let store = JournalStore::create(&plan.machine.state_home, &journal)?;
    println!("Transaction: {}", journal.id);
    println!("Journal: {}\n", store.path.display());

    let result = execute_inner(plan, options, &store, &mut journal);
    if let Err(error) = result {
        eprintln!("\nInstallation failed: {error:#}");
        journal.error = Some(format!("{error:#}"));
        match rollback_files(&journal) {
            Ok(()) => {
                journal.status = TransactionStatus::RolledBack;
                eprintln!("Tonantzintla-owned file changes were rolled back.");
            }
            Err(rollback_error) => {
                journal.status = TransactionStatus::Failed;
                journal.error = Some(format!(
                    "{error:#}; rollback also failed: {rollback_error:#}"
                ));
                let _ = store.save(&journal);
                return Err(error.context(format!("rollback failed: {rollback_error:#}")));
            }
        }
        store.save(&journal)?;
        return Err(error);
    }

    journal.status = TransactionStatus::Complete;
    store.save(&journal)?;
    println!(
        "\nTonantzintla is installed at {}",
        plan.install_root.display()
    );
    let control = plan.machine.home.join(".local/bin/blackhole");
    println!("Run: {} start", control.display());
    let local_bin = plan.machine.home.join(".local/bin");
    if !plan
        .machine
        .path_entries
        .iter()
        .any(|entry| entry == &local_bin)
    {
        println!(
            "\nYour shell PATH does not include {}.",
            local_bin.display()
        );
        println!("The absolute command above works now. For future Bash sessions, add:");
        println!("  export PATH=\"$HOME/.local/bin:$PATH\"");
    }
    match options.umbra {
        UmbraMode::Off => {}
        UmbraMode::Lock => println!("Preview Umbra: {} preview-lock", control.display()),
        UmbraMode::GreeterPreview => {
            println!("Preview the greeter: {} greeter preview", control.display())
        }
    }
    Ok(())
}

fn execute_inner(
    plan: &InstallPlan,
    options: &InstallOptions,
    store: &JournalStore,
    journal: &mut TransactionJournal,
) -> Result<()> {
    install_packages(plan, store, journal)?;
    install_runtime(plan, options, store, journal)?;
    migrate_preferences(plan, store, journal)?;
    install_entrypoints(plan, store, journal)?;
    validate_runtime(&plan.install_root)?;
    // Smoke-test the installed tree through its own entry point, which
    // verifies blackhole resolves and its machine report succeeds.
    run_recorded(
        plan.install_root.join("bin/blackhole"),
        vec!["doctor".to_string()],
        store,
        journal,
    )?;
    complete("validate-source", store, journal)?;
    install_niri(plan, options.niri, store, journal)?;
    complete("umbra", store, journal)?;
    Ok(())
}

fn confirm_install() -> Result<bool> {
    ensure!(
        io::stdin().is_terminal(),
        "confirmation needs a terminal; pass --yes after reviewing dry-run output"
    );
    print!("Type INSTALL to execute this transaction: ");
    io::stdout().flush()?;
    let mut answer = String::new();
    io::stdin().read_line(&mut answer)?;
    Ok(answer.trim() == "INSTALL")
}

fn migrate_preferences(
    plan: &InstallPlan,
    store: &JournalStore,
    journal: &mut TransactionJournal,
) -> Result<()> {
    for base in [&plan.machine.config_home, &plan.machine.state_home] {
        let old = base.join("astralith");
        let new = base.join("tonantzintla");
        if old.is_dir() && !path_exists(&new) {
            journal.created_paths.push(new.clone());
            store.save(journal)?;
            copy_tree(&old, &new, false)?;
        }
    }
    Ok(())
}

fn running_as_root() -> bool {
    fs::read_to_string("/proc/self/status")
        .ok()
        .and_then(|status| {
            status
                .lines()
                .find(|line| line.starts_with("Uid:"))
                .and_then(|line| {
                    line.split_whitespace()
                        .nth(2)
                        .and_then(|uid| uid.parse::<u32>().ok())
                })
        })
        == Some(0)
}

fn test_root_override() -> bool {
    cfg!(debug_assertions)
        && std::env::var("TONANTZINTLA_INSTALLER_TEST_ALLOW_ROOT").as_deref() == Ok("1")
}

fn install_packages(
    plan: &InstallPlan,
    store: &JournalStore,
    journal: &mut TransactionJournal,
) -> Result<()> {
    let pacman = command_path(plan, "pacman").context("pacman is required on Arch Linux")?;
    let mut official = BTreeSet::new();
    let mut aur = BTreeSet::new();
    let mut unresolved: Vec<CapabilityPlan> = Vec::new();
    for capability in plan
        .features
        .iter()
        .filter(|feature| feature.selected)
        .flat_map(|feature| &feature.capabilities)
        .filter(|capability| !capability.available)
    {
        let official_available = !capability.official_packages.is_empty()
            && capability
                .official_packages
                .iter()
                .all(|package| package_in_sync_database(&pacman, package));
        if official_available {
            official.extend(capability.official_packages.iter().cloned());
        } else if !capability.aur_packages.is_empty() {
            aur.extend(capability.aur_packages.iter().cloned());
        } else {
            // Naming a package pacman cannot resolve aborts the entire
            // transaction, so every other package fails to install too.
            // Skip it and report it rather than losing the whole batch.
            unresolved.push(capability.clone());
        }
    }

    for capability in &unresolved {
        eprintln!(
            "SKIP  {} is unavailable; no repository provides {}",
            capability.label,
            capability.official_packages.join(", ")
        );
    }
    if !unresolved.is_empty() {
        eprintln!(
            "      Install {} manually, or add an AUR candidate to features.toml.\n",
            if unresolved.len() == 1 { "it" } else { "them" }
        );
    }

    // Being on PATH is not the same as working: paru built against an older
    // libalpm stops loading after a pacman upgrade. Probe each helper so a
    // broken one falls through to the next instead of taking the install down.
    let aur_helper = if aur.is_empty() {
        None
    } else {
        command_path(plan, "paru")
            .filter(|helper| command_runs(helper))
            .or_else(|| command_path(plan, "yay").filter(|helper| command_runs(helper)))
    };

    if !official.is_empty() {
        let packages = official.into_iter().collect::<Vec<_>>();
        let elevation = command_path(plan, "sudo")
            .or_else(|| command_path(plan, "doas"))
            .context("installing official packages requires sudo or doas")?;
        let program = elevation;
        let mut arguments = vec![pacman.display().to_string(), "-S".into(), "--needed".into()];
        arguments.extend(packages);
        run_recorded(program, arguments, store, journal)?;
    }

    if !aur.is_empty() {
        // AUR packages back optional capabilities. Neither a missing helper
        // nor a failed build may roll back an otherwise sound runtime install,
        // so report and carry on rather than failing the transaction.
        let names = aur.iter().cloned().collect::<Vec<_>>().join(", ");
        match aur_helper {
            Some(helper) => {
                let mut arguments = vec!["-S".into(), "--needed".into()];
                arguments.extend(aur);
                if let Err(error) = run_recorded(helper, arguments, store, journal) {
                    eprintln!("SKIP  The AUR helper did not finish: {error:#}");
                    eprintln!("      Install when convenient: {names}\n");
                }
            }
            None => {
                eprintln!("SKIP  No working AUR helper (paru or yay) was found.");
                eprintln!("      Install when convenient: {names}\n");
            }
        }
    }
    complete("packages", store, journal)
}

// Cheapest liveness probe that catches a helper whose shared libraries no
// longer resolve, which exits non-zero before doing any work.
fn command_runs(program: &Path) -> bool {
    Command::new(program)
        .arg("--version")
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()
        .is_ok_and(|status| status.success())
}

fn package_in_sync_database(pacman: &Path, package: &str) -> bool {
    Command::new(pacman)
        .args(["-Si", "--", package])
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()
        .is_ok_and(|status| status.success())
}

fn command_path(plan: &InstallPlan, name: &str) -> Option<PathBuf> {
    plan.machine
        .commands
        .iter()
        .find(|command| command.name == name)
        .and_then(|command| command.path.clone())
        .or_else(|| find_in_path(name, &plan.machine.path_entries))
}

fn find_in_path(name: &str, entries: &[PathBuf]) -> Option<PathBuf> {
    entries.iter().map(|entry| entry.join(name)).find(|path| {
        fs::metadata(path)
            .is_ok_and(|metadata| metadata.is_file() && metadata.permissions().mode() & 0o111 != 0)
    })
}

fn run_recorded(
    program: PathBuf,
    arguments: Vec<String>,
    store: &JournalStore,
    journal: &mut TransactionJournal,
) -> Result<()> {
    println!("→ {} {}", program.display(), arguments.join(" "));
    let success = Command::new(&program)
        .args(&arguments)
        .stdin(Stdio::inherit())
        .stdout(Stdio::inherit())
        .stderr(Stdio::inherit())
        .status()
        .with_context(|| format!("could not run {}", program.display()))?
        .success();
    journal.commands.push(CommandRecord {
        program: program.display().to_string(),
        arguments,
        success,
    });
    store.save(journal)?;
    ensure!(success, "{} failed", program.display());
    Ok(())
}

fn install_runtime(
    plan: &InstallPlan,
    options: &InstallOptions,
    store: &JournalStore,
    journal: &mut TransactionJournal,
) -> Result<()> {
    if plan.install_root.is_dir()
        && trees_equal(&plan.source, &plan.install_root)?
        && runtime_support_files_current(plan, options)?
    {
        println!("✓ Runtime is already current");
        return complete("install-runtime", store, journal);
    }
    let parent = plan
        .install_root
        .parent()
        .context("runtime destination has no parent")?;
    fs::create_dir_all(parent).with_context(|| format!("could not create {}", parent.display()))?;
    let name = plan
        .install_root
        .file_name()
        .and_then(|name| name.to_str())
        .unwrap_or("tonantzintla");
    let stage = parent.join(format!(".{name}.stage-{}", journal.id));
    remove_path(&stage)?;
    copy_tree(&plan.source, &stage, true)?;
    write_runtime_support_files(&stage, plan, options)?;
    if let Err(error) = validate_runtime(&stage) {
        let _ = remove_path(&stage);
        return Err(error.context("staged Tonantzintla validation failed"));
    }

    if path_exists(&plan.install_root) {
        let previous = parent.join(format!(".{name}.previous-{}", journal.id));
        remove_path(&previous)?;
        fs::rename(&plan.install_root, &previous).with_context(|| {
            format!(
                "could not move {} to {}",
                plan.install_root.display(),
                previous.display()
            )
        })?;
        journal.backups.push(BackupRecord {
            original: plan.install_root.clone(),
            backup: previous,
        });
    }
    fs::rename(&stage, &plan.install_root).with_context(|| {
        format!(
            "could not activate staged runtime at {}",
            plan.install_root.display()
        )
    })?;
    journal.created_paths.push(plan.install_root.clone());
    store.save(journal)?;
    complete("install-runtime", store, journal)
}

fn write_runtime_support_files(
    stage: &Path,
    plan: &InstallPlan,
    options: &InstallOptions,
) -> Result<()> {
    let receipt = stage.join(".tonantzintla-install");
    fs::create_dir_all(&receipt)?;
    let source = plan
        .source
        .canonicalize()
        .unwrap_or_else(|_| plan.source.clone());
    for (name, value) in [
        ("source", source.display().to_string()),
        ("profile", plan.profile.clone()),
        ("niri", options.niri.id().to_string()),
        ("umbra", options.umbra.id().to_string()),
    ] {
        fs::write(receipt.join(name), format!("{value}\n"))?;
    }

    let current_exe =
        std::env::current_exe().context("could not locate the installer executable")?;
    let revision = Command::new("git")
        .arg("-C")
        .arg(&source)
        .args(["describe", "--always", "--dirty", "--abbrev=12"])
        .output()
        .ok()
        .filter(|output| output.status.success())
        .map(|output| String::from_utf8_lossy(&output.stdout).trim().to_string())
        .unwrap_or_else(|| "unknown".to_string());
    fs::write(receipt.join("revision"), format!("{revision}\n"))?;
    let installed_exe = stage.join("bin/tonantzintla-installer");
    fs::create_dir_all(
        installed_exe
            .parent()
            .context("installer path has no parent")?,
    )?;
    fs::copy(&current_exe, &installed_exe).with_context(|| {
        format!(
            "could not install executor {} -> {}",
            current_exe.display(),
            installed_exe.display()
        )
    })?;
    fs::set_permissions(&installed_exe, fs::Permissions::from_mode(0o755))?;
    Ok(())
}

fn runtime_support_files_current(plan: &InstallPlan, options: &InstallOptions) -> Result<bool> {
    let receipt = plan.install_root.join(".tonantzintla-install");
    let source = plan
        .source
        .canonicalize()
        .unwrap_or_else(|_| plan.source.clone());
    let expected = [
        ("source", source.display().to_string()),
        ("profile", plan.profile.clone()),
        ("niri", options.niri.id().to_string()),
        ("umbra", options.umbra.id().to_string()),
    ];
    if expected.iter().any(|(name, value)| {
        fs::read_to_string(receipt.join(name))
            .map(|actual| actual.trim() != value)
            .unwrap_or(true)
    }) {
        return Ok(false);
    }

    let current_exe =
        std::env::current_exe().context("could not locate the installer executable")?;
    files_equal(
        &current_exe,
        &plan.install_root.join("bin/tonantzintla-installer"),
    )
}

fn files_equal(left: &Path, right: &Path) -> Result<bool> {
    let Ok(left_metadata) = fs::metadata(left) else {
        return Ok(false);
    };
    let Ok(right_metadata) = fs::metadata(right) else {
        return Ok(false);
    };
    if left_metadata.len() != right_metadata.len() {
        return Ok(false);
    }
    Ok(fs::read(left)? == fs::read(right)?)
}

fn install_entrypoints(
    plan: &InstallPlan,
    store: &JournalStore,
    journal: &mut TransactionJournal,
) -> Result<()> {
    install_link(
        &plan.machine.config_home.join("quickshell/tonantzintla"),
        &plan.install_root,
        store,
        journal,
    )?;
    complete("link-shell", store, journal)?;
    install_link(
        &plan.machine.home.join(".local/bin/blackhole"),
        &plan.install_root.join("bin/blackhole"),
        store,
        journal,
    )?;
    complete("link-control-command", store, journal)?;
    for name in ["astralithctl", "tonantzintlactl"] {
        let legacy = plan.machine.home.join(".local/bin").join(name);
        let old_runtime = plan.machine.data_home.join("astralith");
        let owned = fs::read_link(&legacy)
            .ok()
            .is_some_and(|path| path == plan.install_root.join("bin/tonantzintlactl"))
            || fs::canonicalize(&legacy).ok().is_some_and(|path| {
                path == old_runtime.join("bin/astralithctl")
                    || path == plan.install_root.join("bin/blackhole")
            });
        if owned {
            install_link(
                &legacy,
                &plan.install_root.join("bin/blackhole"),
                store,
                journal,
            )?;
        }
    }
    Ok(())
}

fn install_link(
    target: &Path,
    expected: &Path,
    store: &JournalStore,
    journal: &mut TransactionJournal,
) -> Result<()> {
    if target.is_symlink()
        && fs::read_link(target)
            .ok()
            .and_then(|link| absolutize_link(target, &link).canonicalize().ok())
            == expected.canonicalize().ok()
    {
        println!("✓ {}", target.display());
        return Ok(());
    }
    backup_existing(target, store, journal)?;
    let parent = target.parent().context("entrypoint has no parent")?;
    fs::create_dir_all(parent)?;
    symlink(expected, target).with_context(|| {
        format!(
            "could not link {} -> {}",
            target.display(),
            expected.display()
        )
    })?;
    journal.created_paths.push(target.to_path_buf());
    store.save(journal)?;
    println!("✓ Linked {} -> {}", target.display(), expected.display());
    Ok(())
}

fn absolutize_link(target: &Path, link: &Path) -> PathBuf {
    if link.is_absolute() {
        link.to_path_buf()
    } else {
        target.parent().unwrap_or_else(|| Path::new("/")).join(link)
    }
}

fn install_niri(
    plan: &InstallPlan,
    mode: NiriMode,
    store: &JournalStore,
    journal: &mut TransactionJournal,
) -> Result<()> {
    if matches!(mode, NiriMode::Keep) {
        return complete("niri-config", store, journal);
    }
    let candidate = plan.install_root.join("compositors/niri/config.kdl");
    let niri = command_path(plan, "niri").context("Niri is unavailable for config validation")?;
    run_recorded(
        niri,
        vec![
            "validate".into(),
            "-c".into(),
            candidate.display().to_string(),
        ],
        store,
        journal,
    )?;
    let target = plan.machine.config_home.join("niri/config.kdl");
    backup_existing(&target, store, journal)?;
    if let Some(parent) = target.parent() {
        fs::create_dir_all(parent)?;
    }
    fs::copy(&candidate, &target).with_context(|| {
        format!(
            "could not install Niri configuration at {}",
            target.display()
        )
    })?;
    fs::set_permissions(&target, fs::Permissions::from_mode(0o644))?;
    journal.created_paths.push(target);
    store.save(journal)?;
    complete("niri-config", store, journal)
}

fn backup_existing(
    original: &Path,
    store: &JournalStore,
    journal: &mut TransactionJournal,
) -> Result<()> {
    if !path_exists(original) {
        return Ok(());
    }
    let name = original
        .file_name()
        .and_then(|name| name.to_str())
        .unwrap_or("path");
    let backup = store
        .backup_dir
        .join(format!("{:03}-{name}", journal.backups.len()));
    copy_tree(original, &backup, false)?;
    remove_path(original)?;
    journal.backups.push(BackupRecord {
        original: original.to_path_buf(),
        backup,
    });
    store.save(journal)
}

fn rollback_files(journal: &TransactionJournal) -> Result<()> {
    for path in journal.created_paths.iter().rev() {
        remove_path(path)?;
    }
    for record in journal.backups.iter().rev() {
        remove_path(&record.original)?;
        if record.backup.exists() && record.backup.parent() == record.original.parent() {
            fs::rename(&record.backup, &record.original)?;
        } else if path_exists(&record.backup) {
            copy_tree(&record.backup, &record.original, false)?;
        }
    }
    Ok(())
}

fn complete(id: &str, store: &JournalStore, journal: &mut TransactionJournal) -> Result<()> {
    if !journal
        .completed_operations
        .iter()
        .any(|operation| operation == id)
    {
        journal.completed_operations.push(id.to_string());
        store.save(journal)?;
    }
    Ok(())
}

fn copy_tree(source: &Path, destination: &Path, filter_runtime: bool) -> Result<()> {
    let metadata = fs::symlink_metadata(source)
        .with_context(|| format!("could not inspect {}", source.display()))?;
    if metadata.file_type().is_symlink() {
        if let Some(parent) = destination.parent() {
            fs::create_dir_all(parent)?;
        }
        symlink(fs::read_link(source)?, destination)?;
    } else if metadata.is_dir() {
        fs::create_dir_all(destination)?;
        for entry in fs::read_dir(source)? {
            let entry = entry?;
            let child_source = entry.path();
            let child_destination = destination.join(entry.file_name());
            let relative = child_source.strip_prefix(source).unwrap_or(&child_source);
            if filter_runtime && skip_runtime_entry(&entry.file_name().to_string_lossy(), relative)
            {
                continue;
            }
            copy_tree(&child_source, &child_destination, filter_runtime)?;
        }
        fs::set_permissions(destination, metadata.permissions())?;
    } else if metadata.is_file() {
        if filter_runtime
            && source
                .extension()
                .is_some_and(|extension| extension == "pyc")
        {
            return Ok(());
        }
        if let Some(parent) = destination.parent() {
            fs::create_dir_all(parent)?;
        }
        fs::copy(source, destination)?;
        fs::set_permissions(destination, metadata.permissions())?;
    } else {
        bail!(
            "unsupported file type in install source: {}",
            source.display()
        );
    }
    Ok(())
}

fn validate_runtime(root: &Path) -> Result<()> {
    const REQUIRED_FILES: &[&str] = &[
        "VERSION",
        "src/quickshell/shell.qml",
        "install/features.toml",
        "src/quickshell/modules/ephemeris/EphemerisSurface.qml",
        "src/quickshell/modules/ephemeris/widgets/qmldir",
        "src/quickshell/modules/ephemeris/widgets/productivity/CalendarModeControls.qml",
        "src/quickshell/modules/umbra/UmbraSurface.qml",
        "compositors/niri/config.kdl",
        "bin/blackhole",
        "src/libexec/system-telemetry.py",
        "src/libexec/network-state.py",
        "src/libexec/wallpaper-library.py",
        "src/assets/wallpapers/astral-observatory.png",
        ".tonantzintla-install/source",
        ".tonantzintla-install/profile",
        ".tonantzintla-install/niri",
        ".tonantzintla-install/umbra",
        "bin/tonantzintla-installer",
    ];
    for relative in REQUIRED_FILES {
        let path = root.join(relative);
        ensure!(
            path.is_file(),
            "required runtime file is missing: {}",
            path.display()
        );
    }
    for relative in ["bin/blackhole", "bin/tonantzintla-installer"] {
        let path = root.join(relative);
        let mode = fs::metadata(&path)?.permissions().mode();
        ensure!(
            mode & 0o111 != 0,
            "runtime command is not executable: {}",
            path.display()
        );
    }
    ensure!(
        !fs::read_to_string(root.join("VERSION"))?.trim().is_empty(),
        "runtime VERSION is empty"
    );
    Ok(())
}

fn skip_runtime_entry(name: &str, relative: &Path) -> bool {
    matches!(
        name,
        ".git"
            | ".tonantzintla-install"
            | "target"
            | "__pycache__"
            | ".pytest_cache"
            | ".mypy_cache"
    ) || relative == Path::new("bin/tonantzintla-installer")
}

fn trees_equal(left: &Path, right: &Path) -> Result<bool> {
    Ok(tree_manifest(left, true)? == tree_manifest(right, true)?)
}

fn tree_manifest(root: &Path, filter_runtime: bool) -> Result<BTreeMap<PathBuf, String>> {
    let mut output = BTreeMap::new();
    collect_manifest(root, root, filter_runtime, &mut output)?;
    Ok(output)
}

fn collect_manifest(
    root: &Path,
    path: &Path,
    filter_runtime: bool,
    output: &mut BTreeMap<PathBuf, String>,
) -> Result<()> {
    let metadata = fs::symlink_metadata(path)?;
    let relative = path.strip_prefix(root).unwrap_or(path).to_path_buf();
    if metadata.file_type().is_symlink() {
        output.insert(relative, format!("link:{}", fs::read_link(path)?.display()));
    } else if metadata.is_dir() {
        if relative.as_os_str().is_empty() {
            output.insert(relative.clone(), "dir".into());
        }
        for entry in fs::read_dir(path)? {
            let entry = entry?;
            let name = entry.file_name();
            if filter_runtime && skip_runtime_entry(&name.to_string_lossy(), &relative.join(&name))
            {
                continue;
            }
            collect_manifest(root, &entry.path(), filter_runtime, output)?;
        }
    } else if metadata.is_file() {
        if filter_runtime && path.extension().is_some_and(|extension| extension == "pyc") {
            return Ok(());
        }
        let mut file = fs::File::open(path)?;
        let mut hasher = DefaultHasher::new();
        let mut buffer = [0_u8; 64 * 1024];
        loop {
            let read = file.read(&mut buffer)?;
            if read == 0 {
                break;
            }
            buffer[..read].hash(&mut hasher);
        }
        output.insert(
            relative,
            format!(
                "file:{:03o}:{:016x}",
                metadata.permissions().mode() & 0o777,
                hasher.finish()
            ),
        );
    }
    Ok(())
}

fn path_exists(path: &Path) -> bool {
    fs::symlink_metadata(path).is_ok()
}

fn remove_path(path: &Path) -> Result<()> {
    let Ok(metadata) = fs::symlink_metadata(path) else {
        return Ok(());
    };
    if metadata.is_dir() && !metadata.file_type().is_symlink() {
        fs::remove_dir_all(path)?;
    } else {
        fs::remove_file(path)?;
    }
    Ok(())
}
