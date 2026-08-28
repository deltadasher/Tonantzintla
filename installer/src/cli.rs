use std::path::PathBuf;

use clap::{Args, Parser, Subcommand, ValueEnum};
use serde::{Deserialize, Serialize};

#[derive(Debug, Parser)]
#[command(name = "astralith-installer", version, about)]
pub struct Cli {
    /// Astralith source checkout. Defaults to the current or compiled checkout.
    #[arg(long, global = true)]
    pub source: Option<PathBuf>,

    #[command(subcommand)]
    pub command: Option<Command>,
}

#[derive(Debug, Subcommand)]
pub enum Command {
    /// Inspect the machine and print the complete install plan without changing it.
    DryRun(DryRunArgs),
    /// Execute a reviewed installation or update transaction.
    Apply(ApplyArgs),
    /// Print the read-only machine capability report.
    Report(ReportArgs),
}

#[derive(Debug, Args)]
pub struct ApplyArgs {
    #[arg(long, value_enum, default_value_t = Profile::Recommended)]
    pub profile: Profile,

    #[arg(long, value_enum, default_value_t = NiriMode::Keep)]
    pub niri: NiriMode,

    #[arg(long, value_enum, default_value_t = UmbraMode::Lock)]
    pub umbra: UmbraMode,

    /// Accept the rendered plan without the INSTALL confirmation prompt.
    #[arg(long)]
    pub yes: bool,
}

#[derive(Debug, Args)]
pub struct DryRunArgs {
    #[arg(long, value_enum, default_value_t = Profile::Recommended)]
    pub profile: Profile,

    #[arg(long, value_enum, default_value_t = NiriMode::Keep)]
    pub niri: NiriMode,

    #[arg(long, value_enum, default_value_t = UmbraMode::Lock)]
    pub umbra: UmbraMode,

    #[arg(long, value_enum, default_value_t = OutputFormat::Text)]
    pub format: OutputFormat,
}

#[derive(Debug, Args)]
pub struct ReportArgs {
    #[arg(long, value_enum, default_value_t = OutputFormat::Text)]
    pub format: OutputFormat,
}

#[derive(Clone, Copy, Debug, Default, Deserialize, Serialize, ValueEnum)]
#[serde(rename_all = "kebab-case")]
pub enum Profile {
    Core,
    #[default]
    Recommended,
    Full,
}

impl Profile {
    pub const ALL: [Self; 3] = [Self::Core, Self::Recommended, Self::Full];

    pub fn id(self) -> &'static str {
        match self {
            Self::Core => "core",
            Self::Recommended => "recommended",
            Self::Full => "full",
        }
    }
}

#[derive(Clone, Copy, Debug, Default, Deserialize, Serialize, ValueEnum)]
#[serde(rename_all = "kebab-case")]
pub enum NiriMode {
    #[default]
    Keep,
    Replace,
}

impl NiriMode {
    pub const ALL: [Self; 2] = [Self::Keep, Self::Replace];

    pub fn id(self) -> &'static str {
        match self {
            Self::Keep => "keep",
            Self::Replace => "replace",
        }
    }

    pub fn label(self) -> &'static str {
        match self {
            Self::Keep => "Keep current config",
            Self::Replace => "Back up and replace",
        }
    }
}

#[derive(Clone, Copy, Debug, Default, Deserialize, Serialize, ValueEnum)]
#[serde(rename_all = "kebab-case")]
pub enum UmbraMode {
    Off,
    #[default]
    Lock,
    GreeterPreview,
}

impl UmbraMode {
    pub const ALL: [Self; 3] = [Self::Off, Self::Lock, Self::GreeterPreview];

    pub fn id(self) -> &'static str {
        match self {
            Self::Off => "off",
            Self::Lock => "lock",
            Self::GreeterPreview => "greeter-preview",
        }
    }

    pub fn label(self) -> &'static str {
        match self {
            Self::Off => "Disabled",
            Self::Lock => "Session lock preview",
            Self::GreeterPreview => "Lock + display-manager greeter files",
        }
    }
}

#[derive(Clone, Copy, Debug, Default, ValueEnum)]
pub enum OutputFormat {
    #[default]
    Text,
    Json,
}
