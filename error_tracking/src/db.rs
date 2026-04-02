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
pub struct Issue {
    pub id: i64,
    pub source_id: i64,
    pub fingerprint: String,
    pub level: String,
    pub exception_type: Option<String>,
    pub exception_value: Option<String>,
    pub transaction_name: Option<String>,
    pub event_count: i64,
    pub first_seen: String,
    pub last_seen: String,
}

#[derive(Debug, Clone, serde::Serialize)]
pub struct Event {
    pub id: i64,
    pub source_id: i64,
    pub event_id: String,
    pub issue_id: Option<i64>,
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
const ISSUE_COLS: &str = "id, source_id, fingerprint, level, exception_type, exception_value, transaction_name, event_count, first_seen, last_seen";
const EVENT_COLS: &str = "id, source_id, event_id, issue_id, level, platform, server_name, environment, release_version, transaction_name, message, exception_data, tags, extra, contexts, request_data, user_data, payload, occurred_at, created_at";

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
            CREATE TABLE IF NOT EXISTS issues (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                source_id INTEGER NOT NULL REFERENCES sources(id),
                fingerprint TEXT NOT NULL,
                level TEXT NOT NULL DEFAULT 'error',
                exception_type TEXT,
                exception_value TEXT,
                transaction_name TEXT,
                event_count INTEGER NOT NULL DEFAULT 0,
                first_seen TEXT NOT NULL DEFAULT (datetime('now')),
                last_seen TEXT NOT NULL DEFAULT (datetime('now')),
                UNIQUE(source_id, fingerprint)
            );
            CREATE INDEX IF NOT EXISTS idx_issues_source_id ON issues(source_id);
            CREATE INDEX IF NOT EXISTS idx_issues_last_seen ON issues(last_seen);

            CREATE TABLE IF NOT EXISTS events (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                source_id INTEGER NOT NULL REFERENCES sources(id),
                event_id TEXT NOT NULL UNIQUE,
                issue_id INTEGER REFERENCES issues(id),
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
            CREATE INDEX IF NOT EXISTS idx_events_issue_id ON events(issue_id);
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
        exception_type: Option<&str>,
        exception_value: Option<&str>,
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

        // Build fingerprint from exception type + transaction
        let fingerprint = format!(
            "{}@{}",
            exception_type.unwrap_or("(none)"),
            transaction_name.unwrap_or("(none)")
        );

        // Upsert issue
        conn.execute(
            "INSERT INTO issues (source_id, fingerprint, level, exception_type, exception_value, transaction_name, event_count, first_seen, last_seen)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, 1, ?7, ?7)
             ON CONFLICT(source_id, fingerprint) DO UPDATE SET
                event_count = event_count + 1,
                last_seen = ?7,
                level = ?3,
                exception_value = ?5",
            params![source_id, fingerprint, level, exception_type, exception_value, transaction_name, occurred_at],
        )?;

        let issue_id: i64 = conn.query_row(
            "SELECT id FROM issues WHERE source_id = ?1 AND fingerprint = ?2",
            params![source_id, fingerprint],
            |r| r.get(0),
        )?;

        conn.execute(
            "INSERT OR IGNORE INTO events (source_id, event_id, issue_id, level, platform, server_name, environment, release_version, transaction_name, message, exception_data, tags, extra, contexts, request_data, user_data, payload, occurred_at)
             VALUES (?1,?2,?3,?4,?5,?6,?7,?8,?9,?10,?11,?12,?13,?14,?15,?16,?17,?18)",
            params![source_id, event_id, issue_id, level, platform, server_name, environment, release, transaction_name, message, exception_data, tags, extra, contexts, request_data, user_data, payload, occurred_at],
        )?;
        Ok(conn.last_insert_rowid())
    }

    pub fn list_events(&self, source_id: i64, limit: i64, offset: i64) -> Result<Vec<Event>, rusqlite::Error> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare(
            &format!("SELECT {EVENT_COLS} FROM events WHERE source_id = ?1 ORDER BY occurred_at DESC LIMIT ?2 OFFSET ?3"),
        )?;
        let result = stmt.query_map(params![source_id, limit, offset], row_to_event)?.collect();
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

    pub fn list_issues(&self, source_id: i64, limit: i64, offset: i64) -> Result<Vec<Issue>, rusqlite::Error> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare(
            &format!("SELECT {ISSUE_COLS} FROM issues WHERE source_id = ?1 ORDER BY last_seen DESC LIMIT ?2 OFFSET ?3"),
        )?;
        let result = stmt.query_map(params![source_id, limit, offset], row_to_issue)?.collect();
        result
    }

    pub fn get_issue(&self, id: i64) -> Result<Option<Issue>, rusqlite::Error> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare(&format!("SELECT {ISSUE_COLS} FROM issues WHERE id = ?1"))?;
        match stmt.query_row(params![id], row_to_issue) {
            Ok(i) => Ok(Some(i)),
            Err(rusqlite::Error::QueryReturnedNoRows) => Ok(None),
            Err(e) => Err(e),
        }
    }

    pub fn list_events_for_issue(&self, issue_id: i64, limit: i64, offset: i64) -> Result<Vec<Event>, rusqlite::Error> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare(
            &format!("SELECT {EVENT_COLS} FROM events WHERE issue_id = ?1 ORDER BY occurred_at DESC LIMIT ?2 OFFSET ?3"),
        )?;
        let result = stmt.query_map(params![issue_id, limit, offset], row_to_event)?.collect();
        result
    }

    pub fn issue_count(&self, source_id: i64) -> Result<i64, rusqlite::Error> {
        let conn = self.conn.lock().unwrap();
        conn.query_row("SELECT COUNT(*) FROM issues WHERE source_id = ?1", params![source_id], |r| r.get(0))
    }

    pub fn event_count(&self, source_id: i64) -> Result<i64, rusqlite::Error> {
        let conn = self.conn.lock().unwrap();
        conn.query_row("SELECT COUNT(*) FROM events WHERE source_id = ?1", params![source_id], |r| r.get(0))
    }

    /// Delete all events and issues for a source.
    pub fn flush_source(&self, source_id: i64) -> Result<u64, rusqlite::Error> {
        let conn = self.conn.lock().unwrap();
        let deleted = conn.execute("DELETE FROM events WHERE source_id = ?1", params![source_id])? as u64;
        conn.execute("DELETE FROM issues WHERE source_id = ?1", params![source_id])?;
        Ok(deleted)
    }

    /// Delete events older than `days` and remove issues with no remaining events.
    pub fn cleanup_older_than(&self, days: i64) -> Result<(u64, u64), rusqlite::Error> {
        let conn = self.conn.lock().unwrap();
        let events_deleted = conn.execute(
            "DELETE FROM events WHERE occurred_at < datetime('now', ?1)",
            params![format!("-{days} days")],
        )? as u64;
        let issues_deleted = conn.execute(
            "DELETE FROM issues WHERE id NOT IN (SELECT DISTINCT issue_id FROM events WHERE issue_id IS NOT NULL)",
            [],
        )? as u64;
        Ok((events_deleted, issues_deleted))
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

fn row_to_issue(row: &rusqlite::Row) -> rusqlite::Result<Issue> {
    Ok(Issue {
        id: row.get(0)?,
        source_id: row.get(1)?,
        fingerprint: row.get(2)?,
        level: row.get(3)?,
        exception_type: row.get(4)?,
        exception_value: row.get(5)?,
        transaction_name: row.get(6)?,
        event_count: row.get(7)?,
        first_seen: row.get(8)?,
        last_seen: row.get(9)?,
    })
}

fn row_to_event(row: &rusqlite::Row) -> rusqlite::Result<Event> {
    Ok(Event {
        id: row.get(0)?,
        source_id: row.get(1)?,
        event_id: row.get(2)?,
        issue_id: row.get(3)?,
        level: row.get(4)?,
        platform: row.get(5)?,
        server_name: row.get(6)?,
        environment: row.get(7)?,
        release: row.get(8)?,
        transaction_name: row.get(9)?,
        message: row.get(10)?,
        exception_data: row.get(11)?,
        tags: row.get(12)?,
        extra: row.get(13)?,
        contexts: row.get(14)?,
        request_data: row.get(15)?,
        user_data: row.get(16)?,
        payload: row.get(17)?,
        occurred_at: row.get(18)?,
        created_at: row.get(19)?,
    })
}
