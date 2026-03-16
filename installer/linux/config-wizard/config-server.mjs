/**
 * ClawStart Config Wizard — lightweight local API server (Linux).
 *
 * Zero dependencies (Node built-ins only).
 * Exposes endpoints for the HTML wizard to configure OpenClaw's
 * provider, API key, and default model.
 *
 * Usage (called by launch.sh):
 *   node config-server.mjs [--port 18790] [--gateway-port 18789]
 */

import { createServer } from "node:http";
import { readFileSync, writeFileSync, existsSync, mkdirSync } from "node:fs";
import { join, dirname } from "node:path";
import { execFile, exec } from "node:child_process";
import { fileURLToPath } from "node:url";
import { randomBytes } from "node:crypto";

const __dirname = dirname(fileURLToPath(import.meta.url));
const CLAWSTART_HOME = process.env.CLAWSTART_HOME || join(__dirname, "..");
const STATE_DIR = process.env.OPENCLAW_STATE_DIR || join(CLAWSTART_HOME, "state");
const CONFIG_FILE = process.env.OPENCLAW_CONFIG_PATH || join(STATE_DIR, "openclaw.json");
const NODE_BIN = process.env.NODE_BIN || join(CLAWSTART_HOME, "runtime", "node", "bin", "node");
const OPENCLAW_CLI = process.env.OPENCLAW_CLI || join(CLAWSTART_HOME, "runtime", "npm-global", "lib", "node_modules", "openclaw", "openclaw.mjs");

const args = process.argv.slice(2);
function argVal(name, fallback) {
  const idx = args.indexOf(name);
  return idx >= 0 && idx + 1 < args.length ? args[idx + 1] : fallback;
}
const PORT = Number(argVal("--port", "18790"));
const GATEWAY_PORT = Number(argVal("--gateway-port", "18789"));

// ── helpers ──────────────────────────────────────────────────

function readJsonSafe(filePath) {
  try {
    if (!existsSync(filePath)) return null;
    return JSON.parse(readFileSync(filePath, "utf8"));
  } catch {
    return null;
  }
}

function writeJsonPretty(filePath, data) {
  mkdirSync(dirname(filePath), { recursive: true });
  writeFileSync(filePath, JSON.stringify(data, null, 2) + "\n", "utf8");
}

// ── config read / write ─────────────────────────────────────

function resolveDefaultAgentId(config) {
  const agents = config?.agents?.list;
  if (Array.isArray(agents) && agents.length > 0) {
    const id = agents[0]?.id;
    if (typeof id === "string" && id) return id;
  }
  return "default";
}

function getAuthProfilesPath(config) {
  const agentId = resolveDefaultAgentId(config);
  return join(STATE_DIR, "agents", agentId, "agent", "auth-profiles.json");
}

function ensureProviderAuthProfileConfig(config, provider, profileId) {
  const next = JSON.parse(JSON.stringify(config));
  if (!next.auth) next.auth = {};
  if (!next.auth.profiles) next.auth.profiles = {};
  next.auth.profiles[profileId] = { provider, mode: "api_key" };
  return next;
}

function lookupProvider(providerId) {
  try {
    const data = JSON.parse(readFileSync(join(__dirname, "providers.json"), "utf8"));
    return data.find((p) => p.id === providerId) || null;
  } catch {
    return null;
  }
}

// ── API routes ───────────────────────────────────────────────

async function handleSetProvider(body) {
  const provider = typeof body.provider === "string" ? body.provider.trim() : "";
  const apiKey = typeof body.apiKey === "string" ? body.apiKey.trim() : "";
  if (!provider || !/^[a-zA-Z0-9._-]+$/.test(provider)) {
    return { ok: false, error: "provider 名称不合法" };
  }
  if (!apiKey) {
    return { ok: false, error: "API Key 不能为空" };
  }

  const providerInfo = lookupProvider(provider);
  const profileId = `${provider}:default`;

  const config = readJsonSafe(CONFIG_FILE) || {};
  const nextConfig = ensureProviderAuthProfileConfig(config, provider, profileId);

  if (providerInfo?.envVar) {
    if (!nextConfig.env) nextConfig.env = {};
    nextConfig.env[providerInfo.envVar] = apiKey;
  }

  if (providerInfo?.modelsProviderConfig) {
    if (!nextConfig.models) nextConfig.models = {};
    if (!nextConfig.models.providers) nextConfig.models.providers = {};
    nextConfig.models.providers[provider] = providerInfo.modelsProviderConfig;
  }

  // Ensure a gateway auth token exists
  if (!nextConfig.gateway) nextConfig.gateway = {};
  if (!nextConfig.gateway.auth) nextConfig.gateway.auth = {};
  if (!nextConfig.gateway.auth.token) {
    nextConfig.gateway.auth.token = randomBytes(32).toString("hex");
  }

  writeJsonPretty(CONFIG_FILE, nextConfig);

  // Write auth-profiles.json
  const authPath = getAuthProfilesPath(nextConfig);
  const existing = readJsonSafe(authPath) || {};
  const nextAuth = {
    ...existing,
    version: typeof existing.version === "number" ? existing.version : 1,
    profiles: {
      ...(existing.profiles || {}),
      [profileId]: { type: "api_key", provider, key: apiKey },
    },
  };
  writeJsonPretty(authPath, nextAuth);

  return { ok: true };
}

async function handleSetModel(body) {
  const model = typeof body.model === "string" ? body.model.trim() : "";
  if (!model || model.length > 200 || /[\r\n]/.test(model)) {
    return { ok: false, error: "模型名不合法" };
  }

  const config = readJsonSafe(CONFIG_FILE) || {};
  if (!config.agents) config.agents = {};
  if (!config.agents.defaults) config.agents.defaults = {};
  if (!config.agents.defaults.model) config.agents.defaults.model = {};
  config.agents.defaults.model.primary = model;

  const providerPrefix = model.split("/")[0];
  const providerInfo = lookupProvider(providerPrefix);
  if (providerInfo?.models) {
    if (!config.agents.defaults.models) config.agents.defaults.models = {};
    for (const m of providerInfo.models) {
      config.agents.defaults.models[m.id] = {};
    }
  }

  if (!config.gateway) config.gateway = {};
  if (!config.gateway.mode) config.gateway.mode = "local";
  if (!config.gateway.auth) config.gateway.auth = {};
  if (!config.gateway.auth.token) {
    config.gateway.auth.token = randomBytes(32).toString("hex");
  }

  writeJsonPretty(CONFIG_FILE, config);
  return { ok: true };
}

function handleSkipConfig() {
  const config = readJsonSafe(CONFIG_FILE) || {};
  if (!config.gateway) config.gateway = {};
  if (!config.gateway.mode) config.gateway.mode = "local";
  if (!config.gateway.auth) config.gateway.auth = {};
  if (!config.gateway.auth.token) {
    config.gateway.auth.token = randomBytes(32).toString("hex");
  }
  config.gateway.skipWizard = true;
  writeJsonPretty(CONFIG_FILE, config);
  return { ok: true };
}

async function handleTestConnection() {
  try {
    const resp = await fetch(`http://127.0.0.1:${GATEWAY_PORT}/health`, {
      signal: AbortSignal.timeout(5000),
    });
    if (resp.ok) return { ok: true, status: "gateway_healthy" };
    return { ok: false, error: `Gateway 返回状态 ${resp.status}` };
  } catch (e) {
    return { ok: false, error: `无法连接 Gateway: ${e.message}` };
  }
}

function handleGetProviders() {
  try {
    const data = readFileSync(join(__dirname, "providers.json"), "utf8");
    return { ok: true, providers: JSON.parse(data) };
  } catch {
    return { ok: false, error: "无法读取 providers.json" };
  }
}

function handleGetStatus() {
  const config = readJsonSafe(CONFIG_FILE);
  const hasConfig = config !== null;
  const hasAuthProfiles = hasConfig && config?.auth?.profiles && Object.keys(config.auth.profiles).length > 0;
  const hasEnv = hasConfig && config?.env && Object.keys(config.env).length > 0;
  const currentModel = config?.agents?.defaults?.model?.primary || null;
  let currentProvider = null;
  if (hasEnv) {
    const envKeys = Object.keys(config.env);
    const providerMap = { MOONSHOT_API_KEY: "moonshot", VOLCANO_ENGINE_API_KEY: "volcengine-plan", MINIMAX_API_KEY: "minimax", QIANFAN_API_KEY: "qianfan", ZAI_API_KEY: "zai", OPENAI_API_KEY: "openai", ANTHROPIC_API_KEY: "anthropic", OPENROUTER_API_KEY: "openrouter" };
    for (const k of envKeys) {
      if (providerMap[k]) { currentProvider = providerMap[k]; break; }
    }
  }
  const gatewayToken = config?.gateway?.auth?.token || null;
  return { ok: true, hasConfig, hasAuthProfiles, hasEnv, currentProvider, currentModel, gatewayToken };
}

// ── Gateway process control (Linux — lsof/kill) ─────────────

const GATEWAY_RUNNER = join(CLAWSTART_HOME, "gateway-runner.sh");

/** Find PID(s) of process listening on GATEWAY_PORT via lsof */
function findGatewayPid() {
  return new Promise((resolve) => {
    exec(
      `lsof -ti :${GATEWAY_PORT} -sTCP:LISTEN`,
      { timeout: 8000 },
      (err, stdout) => {
        if (err || !stdout.trim()) return resolve([]);
        const pids = [...new Set(stdout.trim().split(/\r?\n/).map(Number).filter(Boolean))];
        resolve(pids);
      },
    );
  });
}

/** Check if the gateway HTTP endpoint is healthy */
async function isGatewayAlive() {
  try {
    const resp = await fetch(`http://127.0.0.1:${GATEWAY_PORT}/health`, {
      signal: AbortSignal.timeout(3000),
    });
    return resp.ok;
  } catch {
    return false;
  }
}

/** Kill process(es) listening on GATEWAY_PORT */
function killGateway(pids) {
  return new Promise((resolve) => {
    if (!pids.length) return resolve(true);
    const cmd = pids.map((p) => `kill -9 ${p}`).join(" ; ");
    exec(cmd, { timeout: 8000 }, () => resolve(true));
  });
}

/** Launch gateway-runner.sh in background */
function launchGateway() {
  return new Promise((resolve) => {
    exec(
      `bash "${GATEWAY_RUNNER}" &`,
      {
        cwd: CLAWSTART_HOME,
        timeout: 5000,
        env: {
          ...process.env,
          CLAWSTART_HOME,
          OPENCLAW_STATE_DIR: STATE_DIR,
          OPENCLAW_CONFIG_PATH: CONFIG_FILE,
        },
      },
      () => resolve(true),
    );
  });
}

/** Wait until gateway is healthy (up to maxWaitMs) */
async function waitForGateway(maxWaitMs = 20000) {
  const start = Date.now();
  while (Date.now() - start < maxWaitMs) {
    if (await isGatewayAlive()) return true;
    await new Promise((r) => setTimeout(r, 1500));
  }
  return false;
}

async function handleGatewayStatus() {
  const alive = await isGatewayAlive();
  const pids = await findGatewayPid();
  return { ok: true, running: alive, pids };
}

async function handleGatewayStart() {
  const alive = await isGatewayAlive();
  if (alive) return { ok: true, message: "网关已在运行中" };
  if (!existsSync(GATEWAY_RUNNER)) {
    return { ok: false, error: "找不到 gateway-runner.sh" };
  }
  await launchGateway();
  const ready = await waitForGateway();
  if (ready) return { ok: true, message: "网关已启动" };
  return { ok: false, error: "网关启动超时，请检查日志" };
}

async function handleGatewayStop() {
  const pids = await findGatewayPid();
  if (!pids.length) return { ok: true, message: "网关未在运行" };
  await killGateway(pids);
  await new Promise((r) => setTimeout(r, 1000));
  return { ok: true, message: "网关已停止" };
}

async function handleGatewayRestart() {
  const pids = await findGatewayPid();
  if (pids.length) {
    await killGateway(pids);
    await new Promise((r) => setTimeout(r, 1500));
  }
  if (!existsSync(GATEWAY_RUNNER)) {
    return { ok: false, error: "找不到 gateway-runner.sh" };
  }
  await launchGateway();
  const ready = await waitForGateway();
  if (ready) return { ok: true, message: "网关已重启" };
  return { ok: false, error: "网关重启超时，请检查日志" };
}

// ── HTTP server ──────────────────────────────────────────────

function parseBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let size = 0;
    req.on("data", (chunk) => {
      size += chunk.length;
      if (size > 1_048_576) {
        reject(new Error("body too large"));
        req.destroy();
        return;
      }
      chunks.push(chunk);
    });
    req.on("end", () => {
      try {
        resolve(JSON.parse(Buffer.concat(chunks).toString("utf8")));
      } catch {
        reject(new Error("invalid JSON"));
      }
    });
    req.on("error", reject);
  });
}

function sendJson(res, data, status = 200) {
  const body = JSON.stringify(data);
  res.writeHead(status, {
    "Content-Type": "application/json; charset=utf-8",
    "Content-Length": Buffer.byteLength(body),
    "Access-Control-Allow-Origin": "*",
  });
  res.end(body);
}

function serveStatic(res, filePath, contentType) {
  try {
    const content = readFileSync(filePath);
    res.writeHead(200, {
      "Content-Type": contentType,
      "Content-Length": content.length,
    });
    res.end(content);
  } catch {
    res.writeHead(404);
    res.end("Not Found");
  }
}

const server = createServer(async (req, res) => {
  if (req.method === "OPTIONS") {
    res.writeHead(204, {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type",
    });
    res.end();
    return;
  }

  const url = new URL(req.url, `http://127.0.0.1:${PORT}`);
  const path = url.pathname;

  try {
    if (req.method === "GET" && (path === "/" || path === "/index.html")) {
      serveStatic(res, join(__dirname, "index.html"), "text/html; charset=utf-8");
      return;
    }
    if (req.method === "GET" && path === "/api/providers") {
      sendJson(res, handleGetProviders());
      return;
    }
    if (req.method === "GET" && path === "/api/status") {
      sendJson(res, handleGetStatus());
      return;
    }
    if (req.method === "POST" && path === "/api/set-provider") {
      const body = await parseBody(req);
      sendJson(res, await handleSetProvider(body));
      return;
    }
    if (req.method === "POST" && path === "/api/set-model") {
      const body = await parseBody(req);
      sendJson(res, await handleSetModel(body));
      return;
    }
    if (req.method === "POST" && path === "/api/test-connection") {
      sendJson(res, await handleTestConnection());
      return;
    }
    if (req.method === "POST" && path === "/api/skip-config") {
      sendJson(res, handleSkipConfig());
      return;
    }
    if (req.method === "POST" && path === "/api/complete") {
      const cfg = readJsonSafe(CONFIG_FILE);
      const gwToken = cfg?.gateway?.auth?.token;
      const dashUrl = gwToken
        ? `http://127.0.0.1:${GATEWAY_PORT}/#token=${gwToken}`
        : `http://127.0.0.1:${GATEWAY_PORT}`;
      sendJson(res, { ok: true, dashboardUrl: dashUrl });
      return;
    }
    if (req.method === "GET" && path === "/api/gateway/status") {
      sendJson(res, await handleGatewayStatus());
      return;
    }
    if (req.method === "POST" && path === "/api/gateway/start") {
      sendJson(res, await handleGatewayStart());
      return;
    }
    if (req.method === "POST" && path === "/api/gateway/stop") {
      sendJson(res, await handleGatewayStop());
      return;
    }
    if (req.method === "POST" && path === "/api/gateway/restart") {
      sendJson(res, await handleGatewayRestart());
      return;
    }

    res.writeHead(404);
    res.end("Not Found");
  } catch (e) {
    sendJson(res, { ok: false, error: e.message }, 500);
  }
});

server.listen(PORT, "127.0.0.1", () => {
  const url = `http://127.0.0.1:${PORT}`;
  console.log(`CONFIG_WIZARD_URL=${url}`);
  console.log(`Config wizard listening on ${url}`);
});
