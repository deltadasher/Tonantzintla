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
use crate::model::{InstallPlan, OperationState};
use crate::planner::InstallOptions;
use crate::render;

pub fn execute(plan: &InstallPlan, options: &InstallOptions, assume_yes: bool) -> Result<()> {
    ensure!(
        plan.supported,
        "the executor currently supports Arch Linux only"
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
        "the Astralith runtime destination is occupied by an unrelated path"
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
                eprintln!("Astralith-owned file changes were rolled back.");
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
        "\nAstralith is installed at {}",
        plan.install_root.display()
    );
    println!("Run: astralithctl start");
    match options.umbra {
        UmbraMode::Off => {}
        UmbraMode::Lock => println!("Preview Umbra: astralithctl preview-lock"),
        UmbraMode::GreeterPreview => {
            println!("Preview the greeter: astralithctl greeter preview")
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
    install_entrypoints(plan, store, journal)?;
    validate_runtime(&plan.install_root)?;
    run_recorded(
        plan.install_root.join("scripts/doctor"),
        Vec::new(),
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
        && std::env::var("ASTRALITH_INSTALLER_TEST_ALLOW_ROOT").as_deref() == Ok("1")
}

fn install_packages(
    plan: &InstallPlan,
    store: &JournalStore,
    journal: &mut TransactionJournal,
) -> Result<()> {
    let pacman = command_path(plan, "pacman").context("pacman is required on Arch Linux")?;
    let mut official = BTreeSet::new();
    let mut aur = BTreeSet::new();
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
            official.extend(capability.official_packages.iter().cloned());
        }
    }

    let aur_helper = if aur.is_empty() {
        None
    } else {
        Some(
            command_path(plan, "paru")
                .or_else(|| command_path(plan, "yay"))
                .context("AUR packages were selected but neither paru nor yay is installed")?,
        )
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

    if let Some(helper) = aur_helper {
        let mut arguments = vec!["-S".into(), "--needed".into()];
        arguments.extend(aur);
        run_recorded(helper, arguments, store, journal)?;
    }
    complete("packages", store, journal)
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
        .unwrap_or("astralith");
    let stage = parent.join(format!(".{name}.stage-{}", journal.id));
    remove_path(&stage)?;
    copy_tree(&plan.source, &stage, true)?;
    write_runtime_support_files(&stage, plan, options)?;
    if let Err(error) = validate_runtime(&stage) {
        let _ = remove_path(&stage);
        return Err(error.context("staged Astralith validation failed"));
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
    let receipt = stage.join(".astralith-install");
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
    let installed_exe = stage.join("bin/astralith-installer");
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
    let receipt = plan.install_root.join(".astralith-install");
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
        &plan.install_root.join("bin/astralith-installer"),
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
        &plan.machine.config_home.join("quickshell/astralith"),
        &plan.install_root,
        store,
        journal,
    )?;
    complete("link-shell", store, journal)?;
    install_link(
        &plan.machine.home.join(".local/bin/astralithctl"),
        &plan.install_root.join("scripts/astralithctl"),
        store,
        journal,
    )?;
    complete("link-control-command", store, journal)
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
    let candidate = plan.install_root.join("niri/config.kdl");
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
        "shell.qml",
        "installer/features.toml",
        "modules/ephemeris/EphemerisSurface.qml",
        "modules/umbra/UmbraSurface.qml",
        "niri/config.kdl",
        "scripts/astralithctl",
        "scripts/doctor",
        ".astralith-install/source",
        ".astralith-install/profile",
        ".astralith-install/niri",
        ".astralith-install/umbra",
        "bin/astralith-installer",
    ];
    for relative in REQUIRED_FILES {
        let path = root.join(relative);
        ensure!(
            path.is_file(),
            "required runtime file is missing: {}",
            path.display()
        );
    }
    for relative in [
        "scripts/astralithctl",
        "scripts/doctor",
        "bin/astralith-installer",
    ] {
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
        ".git" | ".astralith-install" | "target" | "__pycache__" | ".pytest_cache" | ".mypy_cache"
    ) || relative == Path::new("bin/astralith-installer")
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
