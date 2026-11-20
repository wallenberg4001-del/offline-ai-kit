// Offline checks for Share on Wi-Fi endpoints, the QR maker, and "Check for updates":  node tests/phase2.test.js
// Add --live to also ask the real GitHub API (needs internet).
"use strict";
const fs = require("fs");
const path = require("path");
const A = require("../www/ask-library.js");
const Q = require("../www/qr.js");
const U = require("../www/updates.js");
let fails = 0;
function check(name, cond, extra) { console.log((cond ? "PASS " : "FAIL ") + name + (cond || extra === undefined ? "" : "  -> " + JSON.stringify(extra))); if (!cond) fails++; }

// ---- endpoints ----
const cfg = { ollamaPort: 11435, libraryPort: 8090 };
let e = A.endpoints({ protocol: "file:", hostname: "", host: "" }, cfg);
check("file:// page talks to 127.0.0.1 directly", e.ollama === "http://127.0.0.1:11435" && e.library === "http://127.0.0.1:8090" && !e.remote, e);
e = A.endpoints({ protocol: "http:", hostname: "127.0.0.1", host: "127.0.0.1:8091" }, cfg);
check("page on 127.0.0.1:8091 talks to 127.0.0.1 directly", e.ollama === "http://127.0.0.1:11435" && !e.remote, e);
e = A.endpoints({ protocol: "http:", hostname: "localhost", host: "localhost:8091" }, cfg);
check("localhost counts as this computer", !e.remote, e);
e = A.endpoints({ protocol: "http:", hostname: "192.168.68.76", host: "192.168.68.76:8091" }, cfg);
check("phone: AI goes through the page's /ollama proxy", e.ollama === "http://192.168.68.76:8091/ollama" && e.remote, e);
check("phone: library is the computer's LAN address", e.library === "http://192.168.68.76:8090", e);
e = A.endpoints({ protocol: "http:", hostname: "10.0.0.9", host: "10.0.0.9:9000" }, { ollamaPort: 11500, libraryPort: 9001 });
check("custom ports are respected", e.ollama === "http://10.0.0.9:9000/ollama" && e.library === "http://10.0.0.9:9001", e);

// ---- versions ----
const cmp = U.compareVersions;
check("1.0.0 < 1.1.0", cmp("1.0.0", "1.1.0") === -1);
check("v1.1.0 == 1.1.0", cmp("v1.1.0", "1.1.0") === 0);
check("1.10.0 > 1.9.9 (numeric, not text)", cmp("1.10.0", "1.9.9") === 1);
check("1.1.0-beta < 1.1.0", cmp("1.1.0-beta", "1.1.0") === -1);
check("2.0 > 1.9.9", cmp("2.0", "1.9.9") === 1);
const ver = fs.readFileSync(path.join(__dirname, "..", "VERSION"), "utf8").trim();
const vjs = (fs.readFileSync(path.join(__dirname, "..", "www", "version.js"), "utf8").match(/"([^"]+)"/) || [])[1];
check("VERSION file matches www/version.js", ver === vjs && /^\d+\.\d+\.\d+$/.test(ver), { ver, vjs });

// ---- QR ----
const m = Q.encode("http://192.168.68.76:8091/");
check("QR is version 2 (25x25) for a LAN address", m.length === 25 && m.every(function (r) { return r.length === 25; }));
function finder(x, y) { return m[y][x] && m[y][x + 6] && m[y + 6][x] && !m[y + 1][x + 1] && m[y + 3][x + 3]; }
check("QR has its three finder patterns", finder(0, 0) && finder(18, 0) && finder(0, 18));
check("QR SVG has no external references", !/https?:\/\/(?!www\.w3\.org\/2000\/svg)/.test(Q.svg("http://192.168.1.2:8091/")));
let threw = false; try { Q.encode("x".repeat(400)); } catch (err) { threw = true; }
check("QR refuses text that is too long", threw);

// ---- web files never call the internet on their own ----
const www = path.join(__dirname, "..", "www");
const ext = fs.readdirSync(www).filter(function (f) { return /\.(html|js)$/.test(f); }).filter(function (f) {
  const t = fs.readFileSync(path.join(www, f), "utf8");
  const urls = t.match(/https?:\/\/[^\s"'<>)]+/g) || [];
  return urls.some(function (u) { return !/^http:\/\/(127\.0\.0\.1|localhost)/.test(u) && !/^https:\/\/(api\.)?github\.com\/repos\/wallenberg4001-del\/offline-ai-kit|^https:\/\/github\.com\/wallenberg4001-del\/offline-ai-kit/.test(u) && u !== "http://www.w3.org/2000/svg" && !/^https:\/\/example\.com\//.test(u) && !/^http:\/\/192\.168\.|^http:\/\/\[/.test(u); });
});
check("www files only reference this computer (and GitHub for the opt-in update check)", ext.length === 0, ext);

// ---- update check with a pretend GitHub ----
function fakeFetch(status, body) { return function () { return Promise.resolve({ ok: status === 200, status: status, json: function () { return Promise.resolve(body); } }); }; }
const rel = { tag_name: "v1.2.0", html_url: "https://github.com/wallenberg4001-del/offline-ai-kit/releases/tag/v1.2.0",
  assets: [{ name: "Offline-AI-Kit-1.2.0.zip.sha256", browser_download_url: "x.sha256" }, { name: "Offline-AI-Kit-1.2.0.zip", browser_download_url: "https://example.invalid/Offline-AI-Kit-1.2.0.zip" }] };
Promise.all([
  U.checkForUpdates("1.1.0", { fetch: fakeFetch(200, rel) }).then(function (r) { check("newer release -> update with page + ZIP link", r.status === "update" && r.latest === "1.2.0" && /Offline-AI-Kit-1\.2\.0\.zip$/.test(r.zip) && /releases\/tag/.test(r.page), r); }),
  U.checkForUpdates("1.2.0", { fetch: fakeFetch(200, rel) }).then(function (r) { check("same version -> up to date", r.status === "current" && U.describe(r) === "You're on the latest version, v1.2.0.", r); }),
  U.checkForUpdates("1.1.0", { fetch: function () { return Promise.reject(new TypeError("Failed to fetch")); } }).then(function (r) { check("no internet -> friendly offline message", r.status === "offline" && /doesn't need internet/.test(U.describe(r)), r); }),
  U.checkForUpdates("1.1.0", { fetch: fakeFetch(403, {}) }).then(function (r) { check("rate limited -> error, not a crash", r.status === "error" && /busy/.test(r.message), r); }),
  U.checkForUpdates("1.1.0", { fetch: function () { return new Promise(function () {}); }, timeoutMs: 300 }).then(function (r) { check("hanging network -> offline after the timeout", r.status === "offline" || r.status === "error", r); })
]).then(function () {
  if (process.argv.indexOf("--live") === -1) return;
  return U.checkForUpdates(ver).then(function (r) {
    console.log("LIVE (this kit v" + ver + "): " + r.status + " latest=" + r.latest + " :: " + U.describe(r));
    check("live: GitHub answered", r.status === "current" || r.status === "update", r);
    return U.checkForUpdates("0.9.0").then(function (r2) { console.log("LIVE (pretend v0.9.0): " + r2.status + " latest=" + r2.latest); check("live: pretend-old kit sees the right status", r2.status === "update" && !!r2.zip, r2); });
  });
}).then(function () {
  console.log(fails ? fails + " check(s) FAILED" : "All checks passed.");
  process.exit(fails ? 1 : 0);
});
