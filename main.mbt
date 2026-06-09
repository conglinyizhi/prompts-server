// ============================================================
// Prompt Server — SQLite 版
// POST /api/prompts                   — 创建
// GET  /api/prompts                   — 最近 N 条
// GET  /api/prompts/search?q=         — 搜索
// GET  /api/prompts/content?id=xxx    — 获取内容
// POST /api/prompts/clean             — GC
// GET  /api/health                    — 健康检查
// ============================================================

pub(all) struct PromptHeader {
  id : String
  title : String
  description : String
  keywords : String
  created_at : String
} derive(ToJson, FromJson)

pub(all) struct PromptContent {
  id : String
  content : String
} derive(ToJson, FromJson)

pub(all) struct CreatePromptRequest {
  title : String
  description : String
  keywords : String
  content : String
} derive(ToJson, FromJson)

pub(all) struct CreatePromptResponse {
  id : String
  message : String
} derive(ToJson, FromJson)

pub(all) struct SearchResult {
  prompt : PromptHeader
  score : Double
} derive(ToJson, FromJson)

pub(all) struct SearchResponse {
  query : String
  results : Array[SearchResult]
} derive(ToJson, FromJson)

pub(all) struct RecentResponse {
  prompts : Array[PromptHeader]
  count : Int
} derive(ToJson, FromJson)

pub(all) struct ContentResponse {
  id : String
  content : String
} derive(ToJson, FromJson)

pub(all) struct CleanResponse {
  headers_removed : Int
  contents_removed : Int
  remaining : Int
} derive(ToJson, FromJson)

pub(all) struct ErrorResponse {
  error : String
} derive(ToJson, FromJson)

let db_file : String = "data/prompts.db"
let recent_limit : Int = 20
let max_content_len : Int = 5000
let host : String = "127.0.0.1:8080"

// ===== SQLite =====

fn exec(conn : @sql.Connection, sql : String) -> Unit raise @sql.SqliteError {
  let s = conn.prepare(sql)
  s.step_once()
  s.finalize()
}

fn insert_prompt(conn : @sql.Connection, h : PromptHeader, content : String) -> Unit raise @sql.SqliteError {
  let s = conn.prepare("INSERT INTO prompts (id, title, description, keywords, content, created_at) VALUES (?, ?, ?, ?, ?, ?)")
  s.bind(index=1, h.id)
  s.bind(index=2, h.title)
  s.bind(index=3, h.description)
  s.bind(index=4, h.keywords)
  s.bind(index=5, content)
  s.bind(index=6, h.created_at)
  s.step_once()
  s.finalize()
}

fn query_headers(conn : @sql.Connection, sql : String) -> Array[PromptHeader] raise @sql.SqliteError {
  let s = conn.prepare(sql)
  let r : Array[PromptHeader] = []
  while s.step() {
    r.push(PromptHeader::{
      id: s.column(index=0), title: s.column(index=1),
      description: s.column(index=2), keywords: s.column(index=3),
      created_at: s.column(index=4)
    })
  }
  s.finalize()
  r
}

// ===== 初始化 =====

async fn init_db() -> @sql.Connection {
  if !@fs.exists("data") { @fs.mkdir("data") }
  let conn = @sql.Connection::open(db_file)
  exec(conn, "CREATE TABLE IF NOT EXISTS prompts (id TEXT PRIMARY KEY, title TEXT NOT NULL DEFAULT '', description TEXT NOT NULL DEFAULT '', keywords TEXT NOT NULL DEFAULT '', content TEXT NOT NULL, created_at TEXT NOT NULL)")
  exec(conn, "CREATE TABLE IF NOT EXISTS vectors (id TEXT PRIMARY KEY, embedding TEXT NOT NULL)")
  conn
}

// ===== 存储 =====

fn load_all_headers(conn : @sql.Connection) -> Array[PromptHeader] raise @sql.SqliteError {
  query_headers(conn, "SELECT id, title, description, keywords, created_at FROM prompts ORDER BY created_at DESC")
}

fn load_recent(conn : @sql.Connection, n : Int) -> Array[PromptHeader] raise @sql.SqliteError {
  query_headers(conn, "SELECT id, title, description, keywords, created_at FROM prompts ORDER BY created_at DESC LIMIT " + n.to_string())
}

fn find_content(conn : @sql.Connection, id : String) -> PromptContent? raise @sql.SqliteError {
  let s = conn.prepare("SELECT content FROM prompts WHERE id = ?")
  s.bind(index=1, id)
  guard s.step() else { s.finalize(); return None }
  let c : String = s.column(index=0)
  s.finalize()
  Some(PromptContent::{ id, content: c })
}

fn search_kw(conn : @sql.Connection, q : String) -> Array[SearchResult] raise @sql.SqliteError {
  let like = "%" + q + "%"
  let s = conn.prepare("SELECT id, title, description, keywords, created_at FROM prompts WHERE title LIKE ? OR keywords LIKE ? OR description LIKE ?")
  s.bind(index=1, like)
  s.bind(index=2, like)
  s.bind(index=3, like)
  let r : Array[SearchResult] = []
  let ql = q.to_lower()
  while s.step() {
    let id : String = s.column(index=0)
    let t : String = s.column(index=1)
    let d : String = s.column(index=2)
    let k : String = s.column(index=3)
    let ts : String = s.column(index=4)
    let h = PromptHeader::{ id, title: t, description: d, keywords: k, created_at: ts }
    let mut score = 0.0
    if h.title.to_lower().contains(ql) { score += 10.0 }
    if h.keywords.to_lower().contains(ql) { score += 8.0 }
    if h.description.to_lower().contains(ql) { score += 3.0 }
    r.push(SearchResult::{ prompt: h, score })
  }
  s.finalize()
  r.sort_by(fn(a, b) { if a.score > b.score { -1 } else if a.score < b.score { 1 } else { 0 } })
  r
}

fn clean_orphans(conn : @sql.Connection) -> Int raise @sql.SqliteError {
  let before = load_all_headers(conn).length()
  let s = conn.prepare("DELETE FROM vectors WHERE id NOT IN (SELECT id FROM prompts)")
  s.step_once()
  s.finalize()
  before - load_all_headers(conn).length()
}

// ===== 辅助 =====

fn try_parse_req(raw : String) -> CreatePromptRequest? {
  try { Some(@json.from_json(@json.parse(raw))) } catch { _ => None }
}

fn extract_param(path : StringView, name : String) -> String {
  match path.split_once("?") {
    Some((_, qs)) => {
      for part in qs.split("&") {
        match part.split_once("=") {
          Some((k, v)) if k.trim() == name => return v.to_owned()
          _ => ()
        }
      }
      ""
    }
    None => ""
  }
}

fn clean_path(path : StringView) -> StringView {
  match path.split_once("?") {
    Some((p, _)) => p
    None => path
  }
}

// ===== HTTP =====

async fn send_json(conn : @http.ServerConnection, code : Int, json_str : String) -> Unit {
  conn.send_response(code, "OK", extra_headers={ "Content-Type": "application/json" })
  conn.write_string(json_str)
  conn.end_response()
}

async fn handle_create(conn : @sql.Connection, body : &@io.Reader, sconn : @http.ServerConnection) -> Unit {
  let raw = try { body.read_all().text() } catch { _ => "" }
  if raw.is_empty() {
    send_json(sconn, 400, ErrorResponse::{ error: "empty request body" }.to_json().stringify())
  } else if try_parse_req(raw) is Some(req) {
    let c = req.content.trim()
    if c.is_empty() {
      send_json(sconn, 400, ErrorResponse::{ error: "content is required" }.to_json().stringify())
    } else if c.length() > max_content_len {
      send_json(sconn, 400, ErrorResponse::{ error: "content too long" }.to_json().stringify())
    } else {
      let now = @async.now()
      let id = now.to_string()
      let h = PromptHeader::{
        id, title: req.title.trim().to_owned(),
        description: req.description.trim().to_owned(),
        keywords: req.keywords.trim().to_owned(),
        created_at: id
      }
      try { insert_prompt(conn, h, c.to_owned()) } catch { _ => () }
      send_json(sconn, 201, CreatePromptResponse::{ id, message: "prompt created" }.to_json().stringify())
    }
  } else {
    send_json(sconn, 400, ErrorResponse::{ error: "invalid JSON" }.to_json().stringify())
  }
}

async fn handle_recent(conn : @sql.Connection, sconn : @http.ServerConnection) -> Unit {
  let prompts = try { load_recent(conn, recent_limit) } catch { _ => [] }
  send_json(sconn, 200, RecentResponse::{ prompts, count: prompts.length() }.to_json().stringify())
}

async fn handle_search(conn : @sql.Connection, path : StringView, sconn : @http.ServerConnection) -> Unit {
  let q = extract_param(path, "q")
  if q.trim().is_empty() {
    handle_recent(conn, sconn)
  } else {
    let results = try { search_kw(conn, q.trim().to_owned()) } catch { _ => [] }
    send_json(sconn, 200, SearchResponse::{ query: q, results }.to_json().stringify())
  }
}

async fn handle_content(conn : @sql.Connection, path : StringView, sconn : @http.ServerConnection) -> Unit {
  let id = extract_param(path, "id")
  if id.trim().is_empty() {
    send_json(sconn, 400, ErrorResponse::{ error: "missing id" }.to_json().stringify())
  } else {
    let found = try { find_content(conn, id.trim().to_owned()) } catch { _ => None }
    match found {
      Some(c) => send_json(sconn, 200, ContentResponse::{ id: c.id, content: c.content }.to_json().stringify())
      None => send_json(sconn, 404, ErrorResponse::{ error: "not found" }.to_json().stringify())
    }
  }
}

async fn handle_clean(conn : @sql.Connection, sconn : @http.ServerConnection) -> Unit {
  let r = try { clean_orphans(conn) } catch { _ => 0 }
  let remaining = try { load_all_headers(conn).length() } catch { _ => 0 }
  send_json(sconn, 200, CleanResponse::{ headers_removed: r, contents_removed: 0, remaining }.to_json().stringify())
}

async fn handle_health(sconn : @http.ServerConnection) -> Unit {
  send_json(sconn, 200, "{\"status\":\"ok\"}")
}

// ===== 主入口 =====

async fn main {
  let db = init_db()
  let vec = @env.get_env_var("EMBEDDING_API_KEY") is Some(_)
  @stdio.stdout.write(
    "Prompts Server running on http://" + host + "\n" +
    "  DB: " + db_file + "\n" +
    "  Embedding: " + (if vec { "enabled" } else { "disabled" }) + "\n" +
    "  POST /api/prompts        - create\n" +
    "  GET  /api/prompts         - recent " + recent_limit.to_string() + "\n" +
    "  GET  /api/prompts/search  - search\n" +
    "  GET  /api/prompts/content - get content\n" +
    "  POST /api/prompts/clean   - gc\n" +
    "  GET  /api/health          - health\n"
  )
  try {
    let server = @http.Server(@socket.Addr::parse(host))
    server.run_forever((request, body, sconn) => {
      let p = clean_path(request.path)
      match (request.meth, p) {
        (Post, "/api/prompts") => handle_create(db, body, sconn)
        (Post, "/api/prompts/clean") => handle_clean(db, sconn)
        (Get, "/api/health") => handle_health(sconn)
        (Get, "/api/prompts") | (Get, "/api/prompts/recent") => handle_recent(db, sconn)
        (Get, "/api/prompts/search") => handle_search(db, request.path, sconn)
        (Get, "/api/prompts/content") => handle_content(db, request.path, sconn)
        _ => {
          sconn.send_response(404, "Not Found")
          sconn.write_string("Not Found")
          sconn.end_response()
        }
      }
    })
  } catch { _ =>
    @stdio.stderr.write("Failed to start server\n")
  }
}
