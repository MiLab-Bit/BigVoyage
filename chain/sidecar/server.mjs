/**
 * BigVoyage Sidecar (Node) — field map → leo run/execute · wallet-bridge · LiveOps
 * Prefer this when system Python is the Windows Store stub.
 */
import http from "node:http";
import fs from "node:fs";
import path from "node:path";
import { spawnSync, spawn } from "node:child_process";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const HOST = "127.0.0.1";
const PORT = Number(process.env.SIDECAR_PORT || 8787);
const REPO = path.resolve(__dirname, "..");
const LEO_DIR = path.join(REPO, "programs", "bv_commit");
const OPS_DB = path.join(__dirname, "ops_state.json");
const WALLET_DB = path.join(__dirname, "wallet_dev.json");
const WALLET_BRIDGE = process.env.WALLET_BRIDGE_URL || "http://127.0.0.1:8788";
const HASH_ALG = "poseidon8_snarkvm_v1";
const FIELD_MOD = 21888242871839275222246405745257275088548364400416034343698204186575808495617n;

function now() {
  return new Date().toISOString();
}

function findLeo() {
  const env = process.env.LEO_BIN;
  if (env && fs.existsSync(env)) return env;
  const candidates = [
    path.join(REPO, "..", "tools", "leo", "leo.exe"),
    "C:\\tools\\leo\\leo.exe",
    path.join(process.env.USERPROFILE || "", ".cargo", "bin", "leo.exe"),
  ];
  for (const c of candidates) if (fs.existsSync(c)) return c;
  return null;
}

function hexToField(hexStr) {
  let h = String(hexStr || "0").trim();
  if (h.startsWith("0x") || h.startsWith("0X")) h = h.slice(2);
  if (!h) h = "0";
  if (h.length > 64) h = h.slice(-64);
  h = h.padStart(64, "0");
  const n = BigInt("0x" + h);
  return n % FIELD_MOD;
}

function winnerCode(w) {
  if (w === 1 || w === "1" || w === "A" || w === "a") return 1;
  if (w === 2 || w === "2" || w === "B" || w === "b") return 2;
  return 0;
}

function mapCommitPayload(data) {
  const ruleset = data.ruleset_hash || data.ruleset_h || data.hash || "0";
  const fleets = data.fleets_h || data.hash || "0";
  const env = data.env_h || "0";
  const logRoot = data.log_root || data.hash || "0";
  return {
    ruleset_h: `${hexToField(String(ruleset))}field`,
    fleets_h: `${hexToField(String(fleets))}field`,
    env_h: `${hexToField(String(env))}field`,
    seed: `${Number(data.seed || 0)}u64`,
    winner: `${winnerCode(data.winner ?? 0)}u8`,
    rounds: `${Number(data.rounds || 0)}u8`,
    log_root: `${hexToField(String(logRoot))}field`,
    season: `${Number(data.season || 1)}u32`,
  };
}

function parseCommit(text) {
  const m1 = text.match(/commit:\s*([0-9]+)field/);
  if (m1) return m1[1];
  const m2 = text.match(/\b([0-9]{20,})field\b/);
  return m2 ? m2[1] : "";
}

function leoRunCommit(mapped) {
  const leo = findLeo();
  if (!leo) return { ok: false, error: "leo_not_found", hint: "Run tools/install_leo.ps1" };
  if (!fs.existsSync(LEO_DIR)) return { ok: false, error: "program_missing", path: LEO_DIR };
  const ver = spawnSync(leo, ["--version"], { encoding: "utf8", timeout: 20000 });
  if (ver.status !== 0) return { ok: false, error: `leo_crash:${ver.stderr || ver.error}`, leo_bin: leo };
  const args = [
    "run",
    "commit_battle",
    mapped.ruleset_h,
    mapped.fleets_h,
    mapped.env_h,
    mapped.seed,
    mapped.winner,
    mapped.rounds,
    mapped.log_root,
    mapped.season,
  ];
  const proc = spawnSync(leo, args, { cwd: LEO_DIR, encoding: "utf8", timeout: 180000 });
  const out = `${proc.stdout || ""}\n${proc.stderr || ""}`;
  const commit = parseCommit(out);
  return {
    ok: proc.status === 0 && Boolean(commit),
    returncode: proc.status,
    commit,
    stdout: (proc.stdout || "").slice(-4000),
    stderr: (proc.stderr || "").slice(-2000),
    cmd: [leo, ...args],
    hash_alg: HASH_ALG,
    leo_bin: leo,
  };
}

async function walletBridge(p, payload) {
  const url = WALLET_BRIDGE.replace(/\/$/, "") + p;
  try {
    // Prefer http.request — Node fetch to 127.0.0.1 can flake after long spawnSync on Windows
    const u = new URL(url);
    const bodyStr = payload === undefined ? null : JSON.stringify(payload);
    const opts = {
      hostname: u.hostname,
      port: u.port || 80,
      path: u.pathname + u.search,
      method: payload === undefined ? "GET" : "POST",
      headers: bodyStr
        ? { "Content-Type": "application/json", "Content-Length": Buffer.byteLength(bodyStr) }
        : {},
      timeout: 30000,
    };
    const raw = await new Promise((resolve, reject) => {
      const req = http.request(opts, (res) => {
        const chunks = [];
        res.on("data", (c) => chunks.push(c));
        res.on("end", () => resolve(Buffer.concat(chunks).toString("utf8")));
      });
      req.on("error", reject);
      req.on("timeout", () => {
        req.destroy();
        reject(new Error("timeout"));
      });
      if (bodyStr) req.write(bodyStr);
      req.end();
    });
    return JSON.parse(raw || "{}");
  } catch (e) {
    return { ok: false, error: `wallet_bridge:${e.message || e}` };
  }
}

function loadJson(fp, def) {
  try {
    if (!fs.existsSync(fp)) return def;
    return JSON.parse(fs.readFileSync(fp, "utf8"));
  } catch {
    return def;
  }
}

function saveJson(fp, obj) {
  fs.writeFileSync(fp, JSON.stringify(obj, null, 2));
}

function send(res, code, obj) {
  const body = JSON.stringify(obj);
  res.writeHead(code, {
    "Content-Type": "application/json; charset=utf-8",
    "Access-Control-Allow-Origin": "*",
    "Content-Length": Buffer.byteLength(body),
  });
  res.end(body);
}

async function readBody(req) {
  const chunks = [];
  for await (const c of req) chunks.push(c);
  try {
    return JSON.parse(Buffer.concat(chunks).toString("utf8") || "{}");
  } catch {
    return {};
  }
}

const server = http.createServer(async (req, res) => {
  if (req.method === "OPTIONS") {
    res.writeHead(204, {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type",
    });
    res.end();
    return;
  }
  const url = new URL(req.url, `http://${HOST}:${PORT}`);
  try {
    if (req.method === "GET" && url.pathname === "/health") {
      send(res, 200, {
        ok: true,
        service: "bv-sidecar-node",
        hash_alg: HASH_ALG,
        leo_bin: findLeo(),
        wallet_bridge: await walletBridge("/health"),
        ts: now(),
      });
      return;
    }
    if (req.method === "GET" && url.pathname === "/wallet") {
      send(res, 200, await walletBridge("/wallet/address"));
      return;
    }
    if (req.method === "GET" && url.pathname === "/ops/events") {
      const db = loadJson(OPS_DB, { events: [], announcements: [] });
      send(res, 200, { ok: true, ...db });
      return;
    }
    if (req.method === "POST") {
      const data = await readBody(req);
      if (url.pathname === "/commit") {
        const mapped = mapCommitPayload(data);
        const leoResult = leoRunCommit(mapped);
        const inputs = [
          mapped.ruleset_h,
          mapped.fleets_h,
          mapped.env_h,
          mapped.seed,
          mapped.winner,
          mapped.rounds,
          mapped.log_root,
          mapped.season,
        ];
        let wb = { ok: true, mode: "skipped", note: "offline leo commit is authoritative; set broadcast=true after faucet" };
        if (Boolean(data.broadcast)) {
          wb = await walletBridge("/execute", {
            program: "bv_commit.aleo",
            function: "commit_battle",
            inputs,
            offline: false,
          });
        } else {
          wb = await walletBridge("/execute", {
            program: "bv_commit.aleo",
            function: "commit_battle",
            inputs,
            offline: true,
          });
        }
        send(res, 200, {
          ok: Boolean(leoResult.ok),
          commit: leoResult.commit || "",
          hash_alg: HASH_ALG,
          mapped,
          leo: leoResult,
          wallet_execute: wb,
          program: "bv_commit.aleo",
          island_id: data.island_id,
          ts: now(),
          note: leoResult.ok
            ? "leo Poseidon8 commit OK · faucet+broadcast=true for network execute"
            : "leo run failed",
        });
        return;
      }
      if (url.pathname === "/wallet/create") {
        const r = await walletBridge("/wallet/create", {});
        if (r.ok) saveJson(WALLET_DB, { address: r.address, via: "provable_sdk", ts: now() });
        send(res, 200, r);
        return;
      }
      if (url.pathname === "/wallet/connect") {
        const r = await walletBridge("/wallet/address");
        send(res, 200, { ...r, connected: Boolean(r.ok) });
        return;
      }
      if (url.pathname === "/ops/announce") {
        const db = loadJson(OPS_DB, { events: [], announcements: [] });
        db.announcements = db.announcements || [];
        db.announcements.push({ msg: data.msg || "", ts: now(), author: data.author || "ops" });
        saveJson(OPS_DB, db);
        send(res, 200, { ok: true });
        return;
      }
      if (url.pathname === "/ops/event_upsert") {
        const db = loadJson(OPS_DB, { events: [], announcements: [] });
        const ev = data.event || data;
        const events = db.events || [];
        const eid = String(ev.id || "");
        const idx = events.findIndex((e) => String(e.id) === eid);
        if (idx >= 0) events[idx] = ev;
        else events.push(ev);
        db.events = events;
        saveJson(OPS_DB, db);
        send(res, 200, { ok: true });
        return;
      }
    }
    send(res, 404, { ok: false, error: "not_found" });
  } catch (e) {
    send(res, 500, { ok: false, error: String(e.message || e) });
  }
});

server.listen(PORT, HOST, () => {
  console.log(`[sidecar-node] http://${HOST}:${PORT} hash=${HASH_ALG} leo=${findLeo()}`);
});
