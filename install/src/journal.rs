use std::fs;
use std::path::{Path, PathBuf};
use std::time::{SystemTime, UNIX_EPOCH};

use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum TransactionStatus {
    Running,
    Complete,
    RolledBack,
    Failed,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct BackupRecord {
    pub original: PathBuf,
    pub backup: PathBuf,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct CommandRecord {
    pub program: String,
    pub arguments: Vec<String>,
    pub success: bool,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct TransactionJournal {
    pub schema: u32,
    pub id: String,
    pub status: TransactionStatus,
    pub source: PathBuf,
    pub install_root: PathBuf,
    pub profile: String,
    pub completed_operations: Vec<String>,
    pub created_paths: Vec<PathBuf>,
    pub backups: Vec<BackupRecord>,
    pub commands: Vec<CommandRecord>,
    pub error: Option<String>,
}

pub struct JournalStore {
    pub path: PathBuf,
    pub backup_dir: PathBuf,
}

impl JournalStore {
    pub fn create(state_home: &Path, journal: &TransactionJournal) -> Result<Self> {
        let root = state_home.join("tonantzintla/installer");
        let transactions = root.join("transactions");
        let backup_dir = root.join("backups").join(&journal.id);
        fs::create_dir_all(&transactions).with_context(|| {
            format!(
                "could not create transaction directory {}",
                transactions.display()
            )
        })?;
        fs::create_dir_all(&backup_dir).with_context(|| {
            format!("could not create backup directory {}", backup_dir.display())
        })?;
        let store = Self {
            path: transactions.join(format!("{}.json", journal.id)),
            backup_dir,
        };
        store.save(journal)?;
        Ok(store)
    }

    pub fn save(&self, journal: &TransactionJournal) -> Result<()> {
        let temporary = self.path.with_extension("json.tmp");
        let data = serde_json::to_vec_pretty(journal)?;
        fs::write(&temporary, data)
            .with_context(|| format!("could not write journal {}", temporary.display()))?;
        fs::rename(&temporary, &self.path)
            .with_context(|| format!("could not publish journal {}", self.path.display()))?;
        Ok(())
    }
}

impl TransactionJournal {
    pub fn new(source: &Path, install_root: &Path, profile: &str) -> Self {
        let elapsed = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap_or_default();
        let id = format!(
            "{}-{:03}-{}",
            elapsed.as_secs(),
            elapsed.subsec_millis(),
            std::process::id()
        );
        Self {
            schema: 1,
            id,
            status: TransactionStatus::Running,
            source: source.to_path_buf(),
            install_root: install_root.to_path_buf(),
            profile: profile.to_string(),
            completed_operations: Vec::new(),
            created_paths: Vec::new(),
            backups: Vec::new(),
            commands: Vec::new(),
            error: None,
        }
    }
}
