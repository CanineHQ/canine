use rusqlite::{Connection, params};
use std::sync::Mutex;

pub struct Database {
    conn: Mutex<Connection>,
}

#[derive(Debug, Clone, serde::Serialize)]
pub struct Source {
    pub id: i64,
    pub name: String,
    pub platform: Option<String>,
    pub public_key: String,
    pub created_at: String,
}

#[derive(Debug, Clone, serde::Serialize)]
pub struct Event {
    pub id: i64,
    pub source_id: i64,
    pub event_id: String,
    pub level: String,
    pub platform: Option<String>,
    pub server_name: Option<String>,
    pub environment: Option<String>,
    pub release: Option<String>,
    pub transaction_name: Option<String>,
    pub message: Option<String>,
    pub exception_data: String,
    pub tags: String,
    pub extra: String,
    pub contexts: String,
    pub request_data: String,
    pub user_data: String,
    pub payload: String,
    pub occurred_at: String,
    pub created_at: String,
}

const SOURCE_COLS: &str = "id, name, platform, public_key, created_at";
const EVENT_COLS: &str = "id, source_id, event_id, level, platform, server_name, environment, release_version, transaction_name, message, exception_data, tags, extra, contexts, request_data, user_data, payload, occurred_at, created_at";

impl Database {
    pub fn new() -> Result<Self, rusqlite::Error> {
        let path = std::env::var("DATABASE_PATH").unwrap_or_else(|_| "data/errors.db".into());

        if let Some(parent) = std::path::Path::new(&path).parent() {
            std::fs::create_dir_all(parent).ok();
        }

        let conn = Connection::open(&path)?;
        conn.execute_batch("PRAGMA journal_mode=WAL; PRAGMA busy_timeout=5000;")?;

        conn.execute_batch(
            "CREATE TABLE IF NOT EXISTS sources (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL UNIQUE,
                platform TEXT,
                public_key TEXT NOT NULL UNIQUE,
                created_at TEXT NOT NULL DEFAULT (datetime('now'))
            );
            CREATE TABLE IF NOT EXISTS events (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                source_id INTEGER NOT NULL REFERENCES sources(id),
                event_id TEXT NOT NULL UNIQUE,
                level TEXT NOT NULL DEFAULT 'error',
                platform TEXT,
                server_name TEXT,
                environment TEXT,
                release_version TEXT,
                transaction_name TEXT,
                message TEXT,
                exception_data TEXT NOT NULL DEFAULT '{}',
                tags TEXT NOT NULL DEFAULT '{}',
                extra TEXT NOT NULL DEFAULT '{}',
                contexts TEXT NOT NULL DEFAULT '{}',
                request_data TEXT NOT NULL DEFAULT '{}',
                user_data TEXT NOT NULL DEFAULT '{}',
                payload TEXT NOT NULL DEFAULT '{}',
                occurred_at TEXT NOT NULL,
                created_at TEXT NOT NULL DEFAULT (datetime('now'))
            );
            CREATE INDEX IF NOT EXISTS idx_events_source_id ON events(source_id);
            CREATE INDEX IF NOT EXISTS idx_events_occurred_at ON events(occurred_at);
            CREATE INDEX IF NOT EXISTS idx_events_level ON events(level);
            CREATE INDEX IF NOT EXISTS idx_events_environment ON events(environment);",
        )?;

        Ok(Self { conn: Mutex::new(conn) })
    }

    pub fn create_source(&self, name: &str, platform: Option<&str>) -> Result<Source, rusqlite::Error> {
        let conn = self.conn.lock().unwrap();
        let public_key = uuid::Uuid::new_v4().simple().to_string();
        conn.execute(
            "INSERT INTO sources (name, platform, public_key) VALUES (?1, ?2, ?3)",
            params![name, platform, public_key],
        )?;
        let id = conn.last_insert_rowid();
        let mut stmt = conn.prepare(&format!("SELECT {SOURCE_COLS} FROM sources WHERE id = ?1"))?;
        let result = stmt.query_row(params![id], row_to_source);
        result
    }

    pub fn list_sources(&self) -> Result<Vec<Source>, rusqlite::Error> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare(&format!("SELECT {SOURCE_COLS} FROM sources ORDER BY created_at DESC"))?;
        let result = stmt.query_map([], row_to_source)?.collect();
        result
    }

    pub fn get_source_by_id(&self, id: i64) -> Result<Option<Source>, rusqlite::Error> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare(&format!("SELECT {SOURCE_COLS} FROM sources WHERE id = ?1"))?;
        let result = stmt.query_row(params![id], row_to_source);
        match result {
            Ok(p) => Ok(Some(p)),
            Err(rusqlite::Error::QueryReturnedNoRows) => Ok(None),
            Err(e) => Err(e),
        }
    }

    #[allow(clippy::too_many_arguments)]
    pub fn insert_event(
        &self,
        source_id: i64,
        event_id: &str,
        level: &str,
        platform: Option<&str>,
        server_name: Option<&str>,
        environment: Option<&str>,
        release: Option<&str>,
        transaction_name: Option<&str>,
        message: Option<&str>,
        exception_data: &str,
        tags: &str,
        extra: &str,
        contexts: &str,
        request_data: &str,
        user_data: &str,
        payload: &str,
        occurred_at: &str,
    ) -> Result<i64, rusqlite::Error> {
        let conn = self.conn.lock().unwrap();
        conn.execute(
            "INSERT OR IGNORE INTO events (source_id, event_id, level, platform, server_name, environment, release_version, transaction_name, message, exception_data, tags, extra, contexts, request_data, user_data, payload, occurred_at)
             VALUES (?1,?2,?3,?4,?5,?6,?7,?8,?9,?10,?11,?12,?13,?14,?15,?16,?17)",
            params![source_id, event_id, level, platform, server_name, environment, release, transaction_name, message, exception_data, tags, extra, contexts, request_data, user_data, payload, occurred_at],
        )?;
        Ok(conn.last_insert_rowid())
    }

    pub fn list_events(&self, source_id: i64, limit: i64) -> Result<Vec<Event>, rusqlite::Error> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare(
            &format!("SELECT {EVENT_COLS} FROM events WHERE source_id = ?1 ORDER BY occurred_at DESC LIMIT ?2"),
        )?;
        let result = stmt.query_map(params![source_id, limit], row_to_event)?.collect();
        result
    }

    pub fn get_event(&self, event_id: &str) -> Result<Option<Event>, rusqlite::Error> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare(
            &format!("SELECT {EVENT_COLS} FROM events WHERE event_id = ?1"),
        )?;
        let result = stmt.query_row(params![event_id], row_to_event);
        match result {
            Ok(e) => Ok(Some(e)),
            Err(rusqlite::Error::QueryReturnedNoRows) => Ok(None),
            Err(e) => Err(e),
        }
    }

    pub fn event_count(&self, source_id: i64) -> Result<i64, rusqlite::Error> {
        let conn = self.conn.lock().unwrap();
        conn.query_row("SELECT COUNT(*) FROM events WHERE source_id = ?1", params![source_id], |r| r.get(0))
    }
}

fn row_to_source(row: &rusqlite::Row) -> rusqlite::Result<Source> {
    Ok(Source {
        id: row.get(0)?,
        name: row.get(1)?,
        platform: row.get(2)?,
        public_key: row.get(3)?,
        created_at: row.get(4)?,
    })
}

fn row_to_event(row: &rusqlite::Row) -> rusqlite::Result<Event> {
    Ok(Event {
        id: row.get(0)?,
        source_id: row.get(1)?,
        event_id: row.get(2)?,
        level: row.get(3)?,
        platform: row.get(4)?,
        server_name: row.get(5)?,
        environment: row.get(6)?,
        release: row.get(7)?,
        transaction_name: row.get(8)?,
        message: row.get(9)?,
        exception_data: row.get(10)?,
        tags: row.get(11)?,
        extra: row.get(12)?,
        contexts: row.get(13)?,
        request_data: row.get(14)?,
        user_data: row.get(15)?,
        payload: row.get(16)?,
        occurred_at: row.get(17)?,
        created_at: row.get(18)?,
    })
}
