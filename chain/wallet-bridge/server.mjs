/**
 * Provable SDK wallet bridge (HTTP)
 * - POST /wallet/create  → Aleo account (private key kept local file)
 * - POST /wallet/address → public address
 * - POST /execute        → ProgramManager.execute (needs funded account + network)
 */
import http from "node:http";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PORT = Number(process.env.WALLET_BRIDGE_PORT || 8788);
const KEY_PATH = path.join(__dirname, "dev_account.json");
const NETWORK = process.env.ALEO_NETWORK || "testnet";

let Account, ProgramManager, AleoNetworkClient, initThreadPool;
try {
  const sdk = await import("@provablehq/sdk");
  Account = sdk.Account;
  ProgramManager = sdk.ProgramManager;
  AleoNetworkClient = sdk.AleoNetworkClient;
  initThreadPool = sdk.initThreadPool;
} catch (e) {
  console.error("[wallet-bridge] @provablehq/sdk not installed. Run: npm i");
  console.error(e.message);
}

async function ensureSdk() {
  if (!Account) throw new Error("sdk_missing");
  if (initThreadPool) {
    try {
      await initThreadPool();
    } catch (_) {
      /* already init / node env */
    }
  }
}

function readJsonFile(fp) {
  const text = fs.readFileSync(fp, "utf8").replace(/^\uFEFF/, "");
  return JSON.parse(text);
}

function loadAccount() {
  if (!fs.existsSync(KEY_PATH)) return null;
  const raw = readJsonFile(KEY_PATH);
  // Provable SDK ≥0.9: restore via constructor, not Account.from_string
  return new Account({ privateKey: raw.privateKey });
}

function saveAccount(account) {
  const data = {
    privateKey: account.to_string ? account.to_string() : account.privateKey().to_string(),
    address: account.address().to_string(),
    network: NETWORK,
    created: new Date().toISOString(),
    warning: "DEV ONLY — never commit real mainnet keys",
  };
  // Prefer exporting private key via SDK API variants
  try {
    data.privateKey = account.privateKey().to_string();
  } catch (_) {}
  fs.writeFileSync(KEY_PATH, JSON.stringify(data, null, 2));
  return data;
}

function json(res, code, obj) {
  const body = JSON.stringify(obj);
  res.writeHead(code, {
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin": "*",
  });
  res.end(body);
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

  const url = new URL(req.url, `http://127.0.0.1:${PORT}`);
  let body = {};
  if (req.method === "POST") {
    const chunks = [];
    for await (const c of req) chunks.push(c);
    try {
      body = JSON.parse(Buffer.concat(chunks).toString("utf8") || "{}");
    } catch {
      body = {};
    }
  }

  try {
    if (url.pathname === "/health") {
      json(res, 200, {
        ok: true,
        service: "bv-wallet-bridge",
        sdk: Boolean(Account),
        network: NETWORK,
        hasAccount: fs.existsSync(KEY_PATH),
      });
      return;
    }

    if (url.pathname === "/wallet/create" && req.method === "POST") {
      await ensureSdk();
      const account = new Account();
      const saved = saveAccount(account);
      json(res, 200, {
        ok: true,
        address: saved.address,
        network: NETWORK,
        note: "Fund via faucet before leo execute / ProgramManager.execute",
      });
      return;
    }

    if (url.pathname === "/wallet/address") {
      if (!fs.existsSync(KEY_PATH)) {
        json(res, 404, { ok: false, error: "no_account" });
        return;
      }
      const raw = readJsonFile(KEY_PATH);
      json(res, 200, { ok: true, address: raw.address, network: raw.network || NETWORK });
      return;
    }

    if (url.pathname === "/execute" && req.method === "POST") {
      await ensureSdk();
      const account = loadAccount();
      if (!account) {
        json(res, 400, { ok: false, error: "create_wallet_first" });
        return;
      }
      const program = body.program || "bv_commit.aleo";
      const functionName = body.function || "commit_battle";
      const inputs = body.inputs || [];
      // Offline-friendly: if no network, return mapped inputs for `leo run`
      if (body.offline || process.env.ALEO_OFFLINE === "1") {
        json(res, 200, {
          ok: true,
          mode: "offline_leo_run",
          address: account.address().to_string(),
          leo_cmd: `leo run ${functionName} ${inputs.join(" ")}`,
          program,
          inputs,
        });
        return;
      }
      try {
        const host = process.env.ALEO_API || "https://api.explorer.provable.com/v1";
        const pm = new ProgramManager(host, undefined, account);
        const tx = await pm.execute(program, functionName, inputs);
        json(res, 200, {
          ok: true,
          mode: "network_execute",
          tx: String(tx),
          address: account.address().to_string(),
        });
      } catch (e) {
        json(res, 200, {
          ok: false,
          error: String(e.message || e),
          hint: "Fund account on testnet faucet, or set ALEO_OFFLINE=1 for leo run path",
          address: account.address().to_string(),
          leo_cmd: `leo run ${functionName} ${inputs.join(" ")}`,
        });
      }
      return;
    }

    json(res, 404, { ok: false, error: "not_found" });
  } catch (e) {
    json(res, 500, { ok: false, error: String(e.message || e) });
  }
});

server.listen(PORT, "127.0.0.1", () => {
  console.log(`[wallet-bridge] http://127.0.0.1:${PORT} network=${NETWORK} sdk=${Boolean(Account)}`);
});
