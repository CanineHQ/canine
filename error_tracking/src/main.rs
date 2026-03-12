mod db;

use axum::{
    Router,
    extract::{Path, Query, State},
    http::{HeaderMap, StatusCode},
    response::Html,
    routing::{get, post},
};
use serde::Deserialize;
use std::sync::Arc;

type Db = Arc<db::Database>;

fn build_app(db: Db) -> Router {
    Router::new()
        // Sentry-compatible ingest (uses project_id in URL per Sentry protocol)
        .route("/api/{source_id}/store/", post(sentry_store))
        .route("/api/{source_id}/envelope/", post(sentry_envelope))
        // JSON API
        .route("/api/sources", get(api_list_sources).post(api_create_source))
        .route("/api/sources/{source_id}/events", get(api_list_events))
        // HTML UI
        .route("/", get(ui_index))
        .route("/sources/{source_id}", get(ui_source))
        .route("/events/{event_id}", get(ui_event))
        .with_state(db)
}

#[tokio::main]
async fn main() {
    let db = Arc::new(db::Database::new().expect("Failed to initialize database"));
    let app = build_app(db);

    let port = std::env::var("PORT").unwrap_or_else(|_| "3001".into());
    let addr = format!("0.0.0.0:{port}");
    eprintln!("error-tracking listening on {addr}");

    let listener = tokio::net::TcpListener::bind(&addr).await.unwrap();
    axum::serve(listener, app).await.unwrap();
}

// ---------------------------------------------------------------------------
// Sentry ingest
// ---------------------------------------------------------------------------

fn extract_sentry_key(headers: &HeaderMap, query: &Query<SentryQuery>) -> Option<String> {
    for name in ["x-sentry-auth", "authorization"] {
        if let Some(val) = headers.get(name).and_then(|v| v.to_str().ok()) {
            if let Some(key) = val
                .split(',')
                .find_map(|part| part.trim().strip_prefix("sentry_key="))
            {
                return Some(key.to_string());
            }
        }
    }
    query.sentry_key.clone()
}

#[derive(Deserialize, Default)]
struct SentryQuery {
    sentry_key: Option<String>,
}

async fn sentry_store(
    State(db): State<Db>,
    Path(source_id): Path<i64>,
    headers: HeaderMap,
    query: Query<SentryQuery>,
    body: String,
) -> (StatusCode, String) {
    let _key = match extract_sentry_key(&headers, &query) {
        Some(k) => k,
        None => return (StatusCode::UNAUTHORIZED, r#"{"error":"missing sentry key"}"#.into()),
    };

    let data: serde_json::Value = match serde_json::from_str(&body) {
        Ok(v) => v,
        Err(_) => return (StatusCode::BAD_REQUEST, r#"{"error":"invalid json"}"#.into()),
    };

    match store_event(&db, source_id, &data) {
        Ok(eid) => (StatusCode::OK, format!(r#"{{"id":"{eid}"}}"#)),
        Err(e) => (StatusCode::INTERNAL_SERVER_ERROR, format!(r#"{{"error":"{e}"}}"#)),
    }
}

async fn sentry_envelope(
    State(db): State<Db>,
    Path(source_id): Path<i64>,
    headers: HeaderMap,
    query: Query<SentryQuery>,
    body: String,
) -> (StatusCode, String) {
    let _key = match extract_sentry_key(&headers, &query) {
        Some(k) => k,
        None => return (StatusCode::UNAUTHORIZED, r#"{"error":"missing sentry key"}"#.into()),
    };

    let lines: Vec<&str> = body.lines().collect();
    if lines.len() < 3 {
        return (StatusCode::OK, r#"{"id":""}"#.into());
    }

    let envelope_header: serde_json::Value =
        serde_json::from_str(lines[0]).unwrap_or_default();

    let mut last_id = String::new();
    let mut i = 1;
    while i + 1 < lines.len() {
        let item_header: serde_json::Value =
            serde_json::from_str(lines[i]).unwrap_or_default();
        i += 1;

        let item_type = item_header["type"].as_str().unwrap_or("");
        if item_type == "event" || item_type == "error" {
            if let Ok(payload) = serde_json::from_str::<serde_json::Value>(lines[i]) {
                if let Ok(eid) = store_event(&db, source_id, &payload) {
                    last_id = eid;
                }
            }
        }
        i += 1;
    }

    let id = envelope_header["event_id"]
        .as_str()
        .unwrap_or(&last_id);
    (StatusCode::OK, format!(r#"{{"id":"{id}"}}"#))
}

fn store_event(db: &db::Database, source_id: i64, data: &serde_json::Value) -> Result<String, String> {
    db.get_source_by_id(source_id)
        .map_err(|e| e.to_string())?
        .ok_or_else(|| "source not found".to_string())?;

    let event_id = data["event_id"]
        .as_str()
        .map(|s| s.to_string())
        .unwrap_or_else(|| uuid::Uuid::new_v4().simple().to_string());

    let level = data["level"].as_str().unwrap_or("error");
    let platform = data["platform"].as_str();
    let server_name = data["server_name"].as_str();
    let environment = data["environment"].as_str();
    let release = data["release"].as_str();
    let transaction = data["transaction"].as_str();

    let message = if let Some(s) = data["message"].as_str() {
        Some(s.to_string())
    } else if let Some(obj) = data["message"].as_object() {
        obj.get("formatted")
            .or_else(|| obj.get("message"))
            .and_then(|v| v.as_str())
            .map(|s| s.to_string())
    } else {
        data["exception"]["values"]
            .as_array()
            .and_then(|vals| vals.first())
            .map(|ex| {
                let t = ex["type"].as_str().unwrap_or("");
                let v = ex["value"].as_str().unwrap_or("");
                if t.is_empty() { v.to_string() } else { format!("{t}: {v}") }
            })
    };

    let occurred_at = data["timestamp"]
        .as_f64()
        .map(|ts| {
            chrono::DateTime::from_timestamp(ts as i64, ((ts.fract()) * 1_000_000_000.0) as u32)
                .unwrap_or_else(chrono::Utc::now)
                .to_rfc3339()
        })
        .unwrap_or_else(|| chrono::Utc::now().to_rfc3339());

    let j = |v: &serde_json::Value| {
        if v.is_null() { "{}".to_string() } else { v.to_string() }
    };

    db.insert_event(
        source_id,
        &event_id,
        level,
        platform,
        server_name,
        environment,
        release,
        transaction,
        message.as_deref(),
        &j(&data["exception"]),
        &j(&data["tags"]),
        &j(&data["extra"]),
        &j(&data["contexts"]),
        &j(&data["request"]),
        &j(&data["user"]),
        &data.to_string(),
        &occurred_at,
    )
    .map_err(|e| e.to_string())?;

    Ok(event_id)
}

// ---------------------------------------------------------------------------
// JSON API
// ---------------------------------------------------------------------------

#[derive(Deserialize)]
struct CreateSource {
    name: String,
    platform: Option<String>,
}

async fn api_create_source(
    State(db): State<Db>,
    axum::Json(body): axum::Json<CreateSource>,
) -> (StatusCode, String) {
    match db.create_source(&body.name, body.platform.as_deref()) {
        Ok(s) => (StatusCode::CREATED, serde_json::to_string(&s).unwrap()),
        Err(e) => (StatusCode::UNPROCESSABLE_ENTITY, format!(r#"{{"error":"{e}"}}"#)),
    }
}

async fn api_list_sources(State(db): State<Db>) -> (StatusCode, String) {
    match db.list_sources() {
        Ok(sources) => (StatusCode::OK, serde_json::to_string(&sources).unwrap()),
        Err(e) => (StatusCode::INTERNAL_SERVER_ERROR, format!(r#"{{"error":"{e}"}}"#)),
    }
}

#[derive(Deserialize, Default)]
struct EventQuery {
    limit: Option<i64>,
}

async fn api_list_events(
    State(db): State<Db>,
    Path(source_id): Path<i64>,
    Query(q): Query<EventQuery>,
) -> (StatusCode, String) {
    match db.list_events(source_id, q.limit.unwrap_or(100)) {
        Ok(events) => (StatusCode::OK, serde_json::to_string(&events).unwrap()),
        Err(e) => (StatusCode::INTERNAL_SERVER_ERROR, format!(r#"{{"error":"{e}"}}"#)),
    }
}

// ---------------------------------------------------------------------------
// HTML UI
// ---------------------------------------------------------------------------

const STYLE: &str = r#"
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #0f1117; color: #e1e4e8; line-height: 1.5; }
  .container { max-width: 960px; margin: 0 auto; padding: 20px; }
  h1 { font-size: 24px; margin-bottom: 16px; }
  h2 { font-size: 20px; margin-bottom: 12px; }
  a { color: #58a6ff; text-decoration: none; }
  a:hover { text-decoration: underline; }
  .card { background: #161b22; border: 1px solid #30363d; border-radius: 6px; padding: 16px; margin-bottom: 12px; }
  .card:hover { border-color: #58a6ff; }
  table { width: 100%; border-collapse: collapse; }
  th, td { text-align: left; padding: 8px 12px; border-bottom: 1px solid #21262d; }
  th { color: #8b949e; font-size: 12px; text-transform: uppercase; }
  .badge { display: inline-block; padding: 2px 8px; border-radius: 12px; font-size: 12px; font-weight: 600; }
  .badge-error { background: #da3633; color: #fff; }
  .badge-warning { background: #d29922; color: #fff; }
  .badge-info { background: #388bfd; color: #fff; }
  .badge-fatal { background: #8b0000; color: #fff; }
  .dsn { background: #0d1117; border: 1px solid #30363d; border-radius: 4px; padding: 8px 12px; font-family: monospace; font-size: 13px; word-break: break-all; }
  .muted { color: #8b949e; }
  .mono { font-family: monospace; font-size: 13px; }
  pre { background: #0d1117; border: 1px solid #30363d; border-radius: 4px; padding: 12px; overflow-x: auto; font-size: 13px; margin: 8px 0; }
  .header { border-bottom: 1px solid #21262d; padding-bottom: 12px; margin-bottom: 20px; display: flex; justify-content: space-between; align-items: center; }
  .empty { text-align: center; padding: 40px; color: #8b949e; }
</style>
"#;

async fn ui_index(State(db): State<Db>) -> Html<String> {
    let sources = db.list_sources().unwrap_or_default();

    let mut rows = String::new();
    for s in &sources {
        let count = db.event_count(s.id).unwrap_or(0);
        rows.push_str(&format!(
            r#"<tr>
                <td><a href="/sources/{id}">{name}</a></td>
                <td class="muted">{platform}</td>
                <td>{count}</td>
                <td class="muted mono">{created}</td>
            </tr>"#,
            id = s.id,
            name = s.name,
            platform = s.platform.as_deref().unwrap_or("-"),
            created = s.created_at,
        ));
    }

    let empty = if sources.is_empty() {
        r#"<div class="empty">No sources yet. Create one via <code>POST /api/sources</code></div>"#
    } else {
        ""
    };

    Html(format!(
        r#"<!DOCTYPE html><html><head><title>Error Tracking</title>{STYLE}</head><body>
        <div class="container">
            <div class="header">
                <h1>Error Tracking</h1>
            </div>
            {empty}
            <table>
                <thead><tr><th>Source</th><th>Platform</th><th>Events</th><th>Created</th></tr></thead>
                <tbody>{rows}</tbody>
            </table>
        </div>
        </body></html>"#,
    ))
}

async fn ui_source(State(db): State<Db>, Path(source_id): Path<i64>) -> Result<Html<String>, StatusCode> {
    let source = db
        .get_source_by_id(source_id)
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?
        .ok_or(StatusCode::NOT_FOUND)?;

    let events = db.list_events(source_id, 100).unwrap_or_default();

    let dsn = format!("http://{key}@<HOST>:3001/api/{id}", key = source.public_key, id = source.id);

    let mut rows = String::new();
    for e in &events {
        let badge_class = match e.level.as_str() {
            "fatal" => "badge-fatal",
            "error" => "badge-error",
            "warning" => "badge-warning",
            _ => "badge-info",
        };
        let msg = e.message.as_deref().unwrap_or("-");
        let msg_short = if msg.len() > 120 { &msg[..120] } else { msg };
        rows.push_str(&format!(
            r#"<tr>
                <td><a href="/events/{event_id}">{short_id}</a></td>
                <td><span class="badge {badge_class}">{level}</span></td>
                <td>{msg}</td>
                <td class="muted">{env}</td>
                <td class="muted mono">{occurred}</td>
            </tr>"#,
            event_id = e.event_id,
            short_id = &e.event_id[..8.min(e.event_id.len())],
            badge_class = badge_class,
            level = e.level,
            msg = msg_short,
            env = e.environment.as_deref().unwrap_or("-"),
            occurred = e.occurred_at,
        ));
    }

    let empty = if events.is_empty() {
        r#"<div class="empty">No events yet. Configure your app with the DSN above.</div>"#
    } else {
        ""
    };

    Ok(Html(format!(
        r#"<!DOCTYPE html><html><head><title>{name} - Error Tracking</title>{STYLE}</head><body>
        <div class="container">
            <div class="header">
                <h1><a href="/">Error Tracking</a> / {name}</h1>
            </div>
            <div class="card">
                <strong>DSN</strong>
                <div class="dsn">{dsn}</div>
                <p class="muted" style="margin-top:8px;font-size:13px">Replace &lt;HOST&gt; with the service address in your cluster (e.g. <code>error-tracking.default.svc.cluster.local</code>)</p>
            </div>
            {empty}
            <table>
                <thead><tr><th>ID</th><th>Level</th><th>Message</th><th>Env</th><th>Time</th></tr></thead>
                <tbody>{rows}</tbody>
            </table>
        </div>
        </body></html>"#,
        name = source.name,
    )))
}

async fn ui_event(State(db): State<Db>, Path(event_id): Path<String>) -> Result<Html<String>, StatusCode> {
    let event = db
        .get_event(&event_id)
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?
        .ok_or(StatusCode::NOT_FOUND)?;

    let source = db
        .get_source_by_id(event.source_id)
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?
        .ok_or(StatusCode::NOT_FOUND)?;

    let badge_class = match event.level.as_str() {
        "fatal" => "badge-fatal",
        "error" => "badge-error",
        "warning" => "badge-warning",
        _ => "badge-info",
    };

    let exception_pretty = pretty_json(&event.exception_data);
    let tags_pretty = pretty_json(&event.tags);
    let contexts_pretty = pretty_json(&event.contexts);
    let request_pretty = pretty_json(&event.request_data);
    let user_pretty = pretty_json(&event.user_data);

    Ok(Html(format!(
        r#"<!DOCTYPE html><html><head><title>Event {eid} - Error Tracking</title>{STYLE}</head><body>
        <div class="container">
            <div class="header">
                <h1><a href="/">Error Tracking</a> / <a href="/sources/{sid}">{sname}</a> / {short_id}</h1>
            </div>

            <div class="card">
                <span class="badge {badge_class}">{level}</span>
                <h2 style="margin-top:8px">{message}</h2>
                <p class="muted" style="margin-top:4px">
                    {env} &middot; {server} &middot; {occurred}
                </p>
            </div>

            <h2>Exception</h2>
            <pre>{exception_pretty}</pre>

            <h2>Tags</h2>
            <pre>{tags_pretty}</pre>

            <h2>Request</h2>
            <pre>{request_pretty}</pre>

            <h2>User</h2>
            <pre>{user_pretty}</pre>

            <h2>Contexts</h2>
            <pre>{contexts_pretty}</pre>
        </div>
        </body></html>"#,
        eid = event.event_id,
        sid = source.id,
        sname = source.name,
        short_id = &event.event_id[..8.min(event.event_id.len())],
        badge_class = badge_class,
        level = event.level,
        message = event.message.as_deref().unwrap_or("(no message)"),
        env = event.environment.as_deref().unwrap_or("-"),
        server = event.server_name.as_deref().unwrap_or("-"),
        occurred = event.occurred_at,
    )))
}

fn pretty_json(s: &str) -> String {
    serde_json::from_str::<serde_json::Value>(s)
        .and_then(|v| serde_json::to_string_pretty(&v))
        .unwrap_or_else(|_| s.to_string())
}

#[cfg(test)]
mod tests {
    use super::*;
    use axum::body::Body;
    use axum::http::{Request, StatusCode};
    use http_body_util::BodyExt;
    use tower::ServiceExt;

    fn test_db() -> Db {
        std::env::set_var("DATABASE_PATH", ":memory:");
        Arc::new(db::Database::new().unwrap())
    }

    async fn body_string(body: Body) -> String {
        let bytes = body.collect().await.unwrap().to_bytes();
        String::from_utf8(bytes.to_vec()).unwrap()
    }

    #[tokio::test]
    async fn test_create_and_list_sources() {
        let app = build_app(test_db());

        let res = app.clone()
            .oneshot(
                Request::builder()
                    .method("POST")
                    .uri("/api/sources")
                    .header("content-type", "application/json")
                    .body(Body::from(r#"{"name":"test-app","platform":"ruby"}"#))
                    .unwrap(),
            )
            .await
            .unwrap();

        assert_eq!(res.status(), StatusCode::CREATED);
        let body: serde_json::Value = serde_json::from_str(&body_string(res.into_body()).await).unwrap();
        assert_eq!(body["name"], "test-app");
        assert_eq!(body["platform"], "ruby");
        assert!(body["public_key"].as_str().unwrap().len() > 10);

        let res = app
            .oneshot(
                Request::builder()
                    .uri("/api/sources")
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();

        assert_eq!(res.status(), StatusCode::OK);
        let body: Vec<serde_json::Value> = serde_json::from_str(&body_string(res.into_body()).await).unwrap();
        assert_eq!(body.len(), 1);
        assert_eq!(body[0]["name"], "test-app");
    }

    #[tokio::test]
    async fn test_duplicate_source_fails() {
        let app = build_app(test_db());

        let create = |app: Router| async move {
            app.oneshot(
                Request::builder()
                    .method("POST")
                    .uri("/api/sources")
                    .header("content-type", "application/json")
                    .body(Body::from(r#"{"name":"dup"}"#))
                    .unwrap(),
            )
            .await
            .unwrap()
        };

        let res = create(app.clone()).await;
        assert_eq!(res.status(), StatusCode::CREATED);

        let res = create(app).await;
        assert_eq!(res.status(), StatusCode::UNPROCESSABLE_ENTITY);
    }

    #[tokio::test]
    async fn test_sentry_store_endpoint() {
        let db = test_db();
        let source = db.create_source("sentry-test", Some("python")).unwrap();
        let app = build_app(db);

        let event_payload = serde_json::json!({
            "event_id": "abc123def456",
            "level": "error",
            "message": "Something broke",
            "platform": "python",
            "environment": "production",
            "timestamp": 1710000000.0
        });

        let res = app.clone()
            .oneshot(
                Request::builder()
                    .method("POST")
                    .uri(format!("/api/{}/store/?sentry_key={}", source.id, source.public_key))
                    .header("content-type", "application/json")
                    .body(Body::from(event_payload.to_string()))
                    .unwrap(),
            )
            .await
            .unwrap();

        assert_eq!(res.status(), StatusCode::OK);
        let body: serde_json::Value = serde_json::from_str(&body_string(res.into_body()).await).unwrap();
        assert_eq!(body["id"], "abc123def456");

        let res = app
            .oneshot(
                Request::builder()
                    .uri(format!("/api/sources/{}/events", source.id))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();

        assert_eq!(res.status(), StatusCode::OK);
        let events: Vec<serde_json::Value> = serde_json::from_str(&body_string(res.into_body()).await).unwrap();
        assert_eq!(events.len(), 1);
        assert_eq!(events[0]["message"], "Something broke");
        assert_eq!(events[0]["level"], "error");
        assert_eq!(events[0]["environment"], "production");
    }

    #[tokio::test]
    async fn test_sentry_store_with_auth_header() {
        let db = test_db();
        let source = db.create_source("auth-test", None).unwrap();
        let app = build_app(db);

        let res = app
            .oneshot(
                Request::builder()
                    .method("POST")
                    .uri(format!("/api/{}/store/", source.id))
                    .header("content-type", "application/json")
                    .header("x-sentry-auth", format!("Sentry sentry_version=7, sentry_key={}", source.public_key))
                    .body(Body::from(r#"{"message":"auth header test","level":"warning"}"#))
                    .unwrap(),
            )
            .await
            .unwrap();

        assert_eq!(res.status(), StatusCode::OK);
    }

    #[tokio::test]
    async fn test_sentry_store_missing_auth() {
        let db = test_db();
        let source = db.create_source("no-auth", None).unwrap();
        let app = build_app(db);

        let res = app
            .oneshot(
                Request::builder()
                    .method("POST")
                    .uri(format!("/api/{}/store/", source.id))
                    .header("content-type", "application/json")
                    .body(Body::from(r#"{"message":"no key"}"#))
                    .unwrap(),
            )
            .await
            .unwrap();

        assert_eq!(res.status(), StatusCode::UNAUTHORIZED);
    }

    #[tokio::test]
    async fn test_sentry_store_nonexistent_source() {
        let db = test_db();
        db.create_source("exists", None).unwrap();
        let app = build_app(db);

        let res = app
            .oneshot(
                Request::builder()
                    .method("POST")
                    .uri("/api/9999/store/?sentry_key=anything")
                    .header("content-type", "application/json")
                    .body(Body::from(r#"{"message":"nope"}"#))
                    .unwrap(),
            )
            .await
            .unwrap();

        assert_eq!(res.status(), StatusCode::INTERNAL_SERVER_ERROR);
        let body = body_string(res.into_body()).await;
        assert!(body.contains("source not found"));
    }

    #[tokio::test]
    async fn test_sentry_envelope_endpoint() {
        let db = test_db();
        let source = db.create_source("envelope-test", None).unwrap();
        let app = build_app(db);

        let envelope = format!(
            "{}\n{}\n{}",
            r#"{"event_id":"envelopeid123"}"#,
            r#"{"type":"event"}"#,
            r#"{"event_id":"envelopeid123","message":"envelope error","level":"fatal","environment":"staging"}"#,
        );

        let res = app
            .oneshot(
                Request::builder()
                    .method("POST")
                    .uri(format!("/api/{}/envelope/?sentry_key={}", source.id, source.public_key))
                    .body(Body::from(envelope))
                    .unwrap(),
            )
            .await
            .unwrap();

        assert_eq!(res.status(), StatusCode::OK);
        let body: serde_json::Value = serde_json::from_str(&body_string(res.into_body()).await).unwrap();
        assert_eq!(body["id"], "envelopeid123");
    }

    #[tokio::test]
    async fn test_sentry_store_exception_message_extraction() {
        let db = test_db();
        let source = db.create_source("exception-test", None).unwrap();
        let app = build_app(db.clone());

        let payload = serde_json::json!({
            "event_id": "exceptionevent1",
            "exception": {
                "values": [{
                    "type": "ValueError",
                    "value": "invalid literal"
                }]
            }
        });

        let res = app
            .oneshot(
                Request::builder()
                    .method("POST")
                    .uri(format!("/api/{}/store/?sentry_key={}", source.id, source.public_key))
                    .header("content-type", "application/json")
                    .body(Body::from(payload.to_string()))
                    .unwrap(),
            )
            .await
            .unwrap();

        assert_eq!(res.status(), StatusCode::OK);

        let events = db.list_events(source.id, 10).unwrap();
        assert_eq!(events.len(), 1);
        assert_eq!(events[0].message.as_deref(), Some("ValueError: invalid literal"));
    }

    #[tokio::test]
    async fn test_ui_index_returns_html() {
        let app = build_app(test_db());

        let res = app
            .oneshot(Request::builder().uri("/").body(Body::empty()).unwrap())
            .await
            .unwrap();

        assert_eq!(res.status(), StatusCode::OK);
        let body = body_string(res.into_body()).await;
        assert!(body.contains("Error Tracking"));
        assert!(body.contains("<!DOCTYPE html>"));
    }

    #[tokio::test]
    async fn test_ui_source_not_found() {
        let app = build_app(test_db());

        let res = app
            .oneshot(Request::builder().uri("/sources/999").body(Body::empty()).unwrap())
            .await
            .unwrap();

        assert_eq!(res.status(), StatusCode::NOT_FOUND);
    }

    #[tokio::test]
    async fn test_ui_event_not_found() {
        let app = build_app(test_db());

        let res = app
            .oneshot(Request::builder().uri("/events/nonexistent").body(Body::empty()).unwrap())
            .await
            .unwrap();

        assert_eq!(res.status(), StatusCode::NOT_FOUND);
    }

    #[tokio::test]
    async fn test_full_flow() {
        let db = test_db();
        let app = build_app(db.clone());

        // Create source via API
        let res = app.clone()
            .oneshot(
                Request::builder()
                    .method("POST")
                    .uri("/api/sources")
                    .header("content-type", "application/json")
                    .body(Body::from(r#"{"name":"full-flow","platform":"go"}"#))
                    .unwrap(),
            )
            .await
            .unwrap();
        let source: serde_json::Value = serde_json::from_str(&body_string(res.into_body()).await).unwrap();
        let sid = source["id"].as_i64().unwrap();
        let key = source["public_key"].as_str().unwrap();

        // Send multiple events
        for i in 0..3 {
            app.clone()
                .oneshot(
                    Request::builder()
                        .method("POST")
                        .uri(format!("/api/{sid}/store/?sentry_key={key}"))
                        .header("content-type", "application/json")
                        .body(Body::from(
                            serde_json::json!({
                                "event_id": format!("event{i}"),
                                "message": format!("Error number {i}"),
                                "level": "error"
                            })
                            .to_string(),
                        ))
                        .unwrap(),
                )
                .await
                .unwrap();
        }

        // List events
        let res = app.clone()
            .oneshot(
                Request::builder()
                    .uri(format!("/api/sources/{sid}/events"))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        let events: Vec<serde_json::Value> = serde_json::from_str(&body_string(res.into_body()).await).unwrap();
        assert_eq!(events.len(), 3);

        // UI source page renders
        let res = app.clone()
            .oneshot(
                Request::builder()
                    .uri(format!("/sources/{sid}"))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(res.status(), StatusCode::OK);
        let body = body_string(res.into_body()).await;
        assert!(body.contains("full-flow"));
        assert!(body.contains("Error number"));

        // UI event detail page
        let res = app
            .oneshot(
                Request::builder()
                    .uri("/events/event0")
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(res.status(), StatusCode::OK);
        let body = body_string(res.into_body()).await;
        assert!(body.contains("Error number 0"));
    }
}
