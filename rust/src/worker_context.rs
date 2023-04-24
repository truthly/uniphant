use std::path::PathBuf;
use uuid::Uuid;

#[derive(Debug, PartialEq, Eq, Hash, Clone)]
pub struct WorkerContext {
    pub foreground: bool,
    pub host_id: Uuid,
    pub host_id_file: PathBuf,
    pub host_name: String,
    pub process_id: Uuid,
    pub root_dir: PathBuf,
    pub secret_dir: PathBuf,
    pub secrets_root: PathBuf,
    pub worker_dir: PathBuf,
    pub worker_id: Uuid,
    pub worker_type: String,
}
