use std::fs;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};

use anyhow::{Context, Result, bail, ensure};

use crate::probe::ProbeContext;

/// What a previous `apply` recorded about how this machine was installed.
pub struct Receipt {
    pub source: PathBuf,
    pub profile: String,
    pub niri: String,
    pub umbra: String,
}

impl Receipt {
    pub fn read(install_root: &Path) -> Result<Self> {
        let directory = install_root.join(".tonantzintla-install");
        let field = |name: &str| -> Result<String> {
            let path = directory.join(name);
            Ok(fs::read_to_string(&path)
                .with_context(|| format!("reading {}", path.display()))?
                .trim()
                .to_string())
        };
        Ok(Self {
            source: PathBuf::from(field("source")?),
            profile: field("profile")?,
            niri: field("niri")?,
            umbra: field("umbra")?,
        })
    }
}

fn git(repository: &Path, arguments: &[&str]) -> Result<std::process::Output> {
    Command::new("git")
        .arg("-C")
        .arg(repository)
        .args(arguments)
        .output()
        .context("running git")
}

fn git_stdout(repository: &Path, arguments: &[&str]) -> Result<String> {
    let output = git(repository, arguments)?;
    Ok(String::from_utf8_lossy(&output.stdout).trim().to_string())
}

fn git_succeeds(repository: &Path, arguments: &[&str]) -> bool {
    git(repository, arguments).is_ok_and(|output| output.status.success())
}

/// Pull the recorded source and re-apply it with the options it was installed
/// under. Refuses rather than guessing whenever the checkout is not in a state
/// a fast-forward can describe.
pub fn update(probe: &ProbeContext, assume_yes: bool) -> Result<()> {
    let install_root = probe.data_home.join("tonantzintla");
    ensure!(
        install_root.is_dir(),
        "Tonantzintla is not installed at {}",
        install_root.display()
    );
    let receipt = Receipt::read(&install_root)?;
    let source = &receipt.source;
    ensure!(
        source.join(".git").exists(),
        "the recorded source is not a Git checkout: {}",
        source.display()
    );

    let dirty = git_stdout(source, &["status", "--porcelain"])?;
    if !dirty.is_empty() {
        eprintln!("Refusing to update a checkout with local changes:");
        eprintln!("{dirty}");
        bail!("commit, stash, or discard them first");
    }

    // A branch both this machine and a remote session have committed to cannot
    // fast-forward. Name both sides rather than leaving the reader to work out
    // which commits are local.
    if git_succeeds(source, &["rev-parse", "--abbrev-ref", "@{upstream}"]) {
        let _ = git(source, &["fetch", "--quiet"]);
        let ahead = git_stdout(source, &["rev-list", "--count", "@{upstream}..HEAD"])?;
        let behind = git_stdout(source, &["rev-list", "--count", "HEAD..@{upstream}"])?;
        let ahead: u32 = ahead.parse().unwrap_or(0);
        let behind: u32 = behind.parse().unwrap_or(0);
        if ahead > 0 && behind > 0 {
            let branch = git_stdout(source, &["rev-parse", "--abbrev-ref", "HEAD"])?;
            let upstream = git_stdout(source, &["rev-parse", "--abbrev-ref", "@{upstream}"])?;
            eprintln!("This checkout has diverged from {upstream}.\n");
            eprintln!("Only on this machine ({ahead}):");
            eprintln!(
                "{}",
                git_stdout(source, &["log", "--oneline", "@{upstream}..HEAD"])?
            );
            eprintln!("\nOnly on the remote ({behind}):");
            eprintln!(
                "{}",
                git_stdout(source, &["log", "--oneline", "HEAD..@{upstream}"])?
            );
            eprintln!("\nTo keep both sides:");
            eprintln!("  git merge {upstream} && git push -u origin {branch}");
            eprintln!("\nTo discard the local commits listed above:");
            eprintln!("  git reset --hard {upstream}");
            bail!("resolve the divergence, then run update again");
        }
    }

    println!("Updating Tonantzintla with a fast-forward-only pull...");
    let pull = git(source, &["pull", "--ff-only"])?;
    print!("{}", String::from_utf8_lossy(&pull.stdout));
    ensure!(
        pull.status.success(),
        "{}",
        String::from_utf8_lossy(&pull.stderr).trim()
    );

    let running = shell_running(&install_root);

    println!("\nApplying the updated runtime transaction...");
    let installer = install_root.join("bin/tonantzintla-installer");
    ensure!(
        installer.is_file(),
        "no installed executor at {}",
        installer.display()
    );
    let mut apply = Command::new(&installer);
    apply
        .arg("--source")
        .arg(source)
        .arg("apply")
        .arg("--profile")
        .arg(&receipt.profile)
        .arg("--niri")
        .arg(&receipt.niri)
        .arg("--umbra")
        .arg(&receipt.umbra);
    if assume_yes {
        apply.arg("--yes");
    }
    let status = apply.status().context("running the installed executor")?;
    ensure!(status.success(), "the update transaction failed");

    if running {
        println!("\nRestarting the active Tonantzintla shell...");
        let _ = Command::new(install_root.join("bin/blackhole"))
            .arg("restart")
            .status();
    } else {
        println!(
            "\nUpdate complete. Start Tonantzintla with: {} start",
            probe.home.join(".local/bin/blackhole").display()
        );
    }
    Ok(())
}

fn shell_running(install_root: &Path) -> bool {
    Command::new("qs")
        .arg("-p")
        .arg(install_root)
        .arg("list")
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .output()
        .is_ok_and(|output| String::from_utf8_lossy(&output.stdout).contains("Instance"))
}

/// Remove only the links this installer created, and only when they still point
/// at our runtime. Settings, caches, and wallpapers are user data and stay.
pub fn uninstall(probe: &ProbeContext, remove_runtime: bool) -> Result<()> {
    let install_root = probe.data_home.join("tonantzintla");
    let supervisor = install_root.join("src/libexec/session-daemon.py");
    if supervisor.is_file() {
        let stopped = Command::new("python3")
            .arg(&supervisor)
            .arg("stop")
            .status()?;
        ensure!(
            stopped.success(),
            "could not stop Tonantzintla; keeping the installation"
        );
    }
    let links = [
        (
            probe.home.join(".local/bin/tonantzintlactl"),
            install_root.join("bin/blackhole"),
        ),
        (
            probe.home.join(".local/bin/astralithctl"),
            install_root.join("bin/blackhole"),
        ),
        (
            probe.config_home.join("quickshell/tonantzintla"),
            install_root.clone(),
        ),
        (
            probe.home.join(".local/bin/blackhole"),
            install_root.join("bin/blackhole"),
        ),
    ];

    for (link, expected) in &links {
        match fs::read_link(link) {
            Ok(_) if fs::canonicalize(link).ok().as_deref() == Some(expected.as_path()) => {
                fs::remove_file(link).with_context(|| format!("removing {}", link.display()))?;
                println!("Removed link: {}", link.display());
            }
            Ok(_) => println!("Preserved unrelated link: {}", link.display()),
            Err(_) if link.exists() => {
                println!("Preserved unrelated path: {}", link.display())
            }
            Err(_) => println!("Already absent: {}", link.display()),
        }
    }

    if remove_runtime && install_root.is_dir() {
        fs::remove_dir_all(&install_root)
            .with_context(|| format!("removing {}", install_root.display()))?;
        println!("Removed runtime: {}", install_root.display());
    } else if install_root.is_dir() {
        println!("Kept runtime: {}", install_root.display());
        println!("Pass --remove-runtime to delete it.");
    }

    println!("\nSettings and caches were preserved under your XDG directories.");
    Ok(())
}
