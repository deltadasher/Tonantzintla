mod app;
mod cli;
mod executor;
mod journal;
mod maintain;
mod manifest;
mod model;
mod planner;
mod probe;
mod render;

use std::path::PathBuf;

use anyhow::{Context, Result, bail};
use clap::Parser;

use crate::cli::{Cli, Command, OutputFormat};
use crate::manifest::FeatureManifest;
use crate::planner::{InstallOptions, build_plan};
use crate::probe::ProbeContext;

fn main() {
    if let Err(error) = run() {
        eprintln!("tonantzintla-installer: {error:#}");
        std::process::exit(1);
    }
}

fn run() -> Result<()> {
    let cli = Cli::parse();
    let source = discover_source(cli.source.as_ref())?;
    let manifest = FeatureManifest::load(&source.join("install/features.toml"))?;
    let probe = ProbeContext::from_process()?;
    let report = probe.inspect();

    match cli.command {
        Some(Command::DryRun(args)) => {
            let options = InstallOptions {
                profile: args.profile,
                niri: args.niri,
                umbra: args.umbra,
            };
            let plan = build_plan(&source, &probe, &report, &manifest, &options);
            match args.format {
                OutputFormat::Text => print!("{}", render::plan_text(&plan)),
                OutputFormat::Json => println!("{}", serde_json::to_string_pretty(&plan)?),
            }
            if !report.is_arch() {
                if report.distribution.id == "artix" {
                    bail!(
                        "ARTIX detected.\nOPINION REJECTED.\nTonantzintla made no changes and left this checkout intact.\nPlease reconsider your life choices before using ARTIX. Obarun on top!"
                    );
                }
                bail!(
                    "this installer currently supports compatible Arch Linux derivatives only; no changes were made"
                );
            }
        }
        Some(Command::Apply(args)) => {
            let options = InstallOptions {
                profile: args.profile,
                niri: args.niri,
                umbra: args.umbra,
            };
            let plan = build_plan(&source, &probe, &report, &manifest, &options);
            executor::execute(&plan, &options, args.yes)?;
        }
        Some(Command::Report(args)) => match args.format {
            OutputFormat::Text => print!("{}", render::report_text(&report)),
            OutputFormat::Json => println!("{}", serde_json::to_string_pretty(&report)?),
        },
        Some(Command::Update(args)) => maintain::update(&probe, args.yes)?,
        Some(Command::Uninstall(args)) => maintain::uninstall(&probe, args.remove_runtime)?,
        None => {
            if let Some(options) = app::run(
                source.clone(),
                probe.clone(),
                report.clone(),
                manifest.clone(),
            )? {
                let plan = build_plan(&source, &probe, &report, &manifest, &options);
                executor::execute(&plan, &options, false)?;
            }
        }
    }

    Ok(())
}

fn discover_source(explicit: Option<&PathBuf>) -> Result<PathBuf> {
    if let Some(path) = explicit {
        return canonical_source(path);
    }

    let cwd = std::env::current_dir().context("could not read the current directory")?;
    if is_source(&cwd) {
        return Ok(cwd);
    }

    let compiled_from = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .expect("installer crate has a repository parent")
        .to_path_buf();
    canonical_source(&compiled_from)
}

fn canonical_source(path: &std::path::Path) -> Result<PathBuf> {
    let path = path
        .canonicalize()
        .with_context(|| format!("source checkout does not exist: {}", path.display()))?;
    if !is_source(&path) {
        bail!("{} is not an Tonantzintla source checkout", path.display());
    }
    Ok(path)
}

fn is_source(path: &std::path::Path) -> bool {
    path.join("src/quickshell/shell.qml").is_file()
        && path.join("VERSION").is_file()
        && path.join("bin/blackhole").is_file()
}
