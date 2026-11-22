/* Guided installer, emergency screen, and the Click these folder.
   No downloads. Does not start Ollama or Kiwix.
   Starts the Mac/Linux installer page only long enough to read /api/context. */
"use strict";
const fs = require("fs");
const path = require("path");
const { execFileSync, spawn } = require("child_process");
const http = require("http");
const W = require("../www/install-wizard.js");
const F = require("../www/first-aid.js");

const root = path.join(__dirname, "..");
let fails = 0;
function check(name, ok, extra) {
  console.log((ok ? "ok  " : "FAIL") + "  " + name);
  if (!ok) { fails++; if (extra !== undefined) console.log("     " + (typeof extra === "string" ? extra : JSON.stringify(extra))); }
}
function read(rel) { return fs.readFileSync(path.join(root, rel), "utf8"); }
function exists(rel) { return fs.existsSync(path.join(root, rel)); }

check("thirteen emergency topics", F.TOPICS.length === 13, F.TOPICS.length);
const ids = {};
F.TOPICS.forEach(function (t) {
  check(t.id + " has a title and a real search", !ids[t.id] && t.title && t.query.split(/\s+/).length >= 3 && t.group, t);
  ids[t.id] = true;
});
check("no treatment steps are stored in the topic list", !F.TOPICS.some(function (t) { return /press|dosage|mg\b|heimlich/i.test(t.title); }));
check("prefers a small model when one is installed", F.pickModel(["qwen3:14b", "llama3.2:3b", "medgemma:4b"]) === "llama3.2:3b");
check("article links stay on the library host", F.linksFromSearch("http://127.0.0.1:8090/", [{ title: "Burn", path: "/content/x/A", book: "WikiMed" }])[0].url === "http://127.0.0.1:8090/content/x/A");
check("chat page links to first aid", /id="aidLink"[^>]*href="first-aid\.html"/.test(read("www/chat.html")));
check("first-aid page points at the chat", /href="chat\.html"/.test(read("www/first-aid.html")));

{
  const vm = require("vm");
  const html = read("www/first-aid.html");
  const re = /<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/g;
  let m, n = 0, bad = "";
  while ((m = re.exec(html))) {
    n++;
    try { new vm.Script(m[1], { filename: "first-aid.html" }); } catch (e) { bad += e.message; }
  }
  check("first-aid inline script parses", n === 1 && !bad, bad);
}

const extras = W.parseCatalog(read("catalog/extra-libraries.txt"));
const maps = W.parseCatalog(read("catalog/maps.txt"));
check("extra catalog parses", extras.length === 17, extras.length);
check("maps catalog parses", maps.length === 23, maps.length);
const canada = maps.filter(function (e) { return ["vancouver-island", "british-columbia", "alberta", "saskatchewan", "canada"].indexOf(e.id) !== -1; });
check("five Canada choices are one download", W.dedupeGB(canada) === 10, W.dedupeGB(canada));

const win = { os: "windows", family: "windows", aiAvailable: true, suggestedModels: "1", suggestedTier: "2", suggestedWikipedia: true, universalExtraGB: 11.5, programsGB: 2.5, freeGB: 400, ramGB: 32, computer: "Windows PC", folder: "C:\\Kit" };
const winChoices = W.defaultChoices(win);
check("windows suggestion is Core", winChoices.models === "1" && winChoices.tier === "2" && winChoices.wikipedia === true && winChoices.shareWifi === false && winChoices.universal === false);
const winEst = W.estimate(win, winChoices, extras, maps);
check("windows estimate adds programs, library, and models", winEst.nowGB === 28.5, winEst);
check("wikipedia is on top of the download-now size", winEst.totalGB === 155.5, winEst);

const tight = Object.assign({}, win, { freeGB: 20, suggestedWikipedia: false });
const tightChoices = W.defaultChoices(tight);
tightChoices.wikipedia = true;
check("not enough disk disables a huge install", W.estimate(tight, tightChoices, extras, maps).tooBig === true);

const mac = { os: "mac", family: "apple", aiAvailable: true, suggestedModels: "16", suggestedTier: "2", suggestedWikipedia: false, universalExtraGB: 13, programsGB: 1, freeGB: 80, ramGB: 16 };
const macChoices = W.defaultChoices(mac);
macChoices.maps = ["vancouver-island", "canada"];
const macEst = W.estimate(mac, macChoices, extras, maps);
check("apple suggestion is Medium", macChoices.models === "16" && W.modelChoices(mac).some(function (c) { return c.recommended && c.id === "16"; }));
check("two Canada map picks count once", macEst.lines.some(function (l) { return l.label === "Offline maps" && /10 GB/.test(l.value); }), macEst.lines);

const intel = { os: "mac", family: "intel", aiAvailable: true, suggestedModels: "llama3.2:3b,medgemma:4b", intelModels: "llama3.2:3b,medgemma:4b", suggestedTier: "2", programsGB: 1, freeGB: 100 };
check("intel offers only the small set", W.modelChoices(intel).length === 1 && W.modelChoices(intel)[0].id === "llama3.2:3b,medgemma:4b");
check("old mac has no AI step", W.modelChoices({ aiAvailable: false, family: "apple" }).length === 0);
["se-medical", "se-outdoors", "trueprepper", "ready-gov"].forEach(function (id) {
  check(id + " is marked helpful, not selected", W.EMERGENCY_EXTRAS[id] === 1 && W.defaultChoices(win).extras.length === 0);
});

check("folder guide names the numbered folders", /1 Install - guided/.test(read("FOLDER-GUIDE.txt")) && /Do not delete/.test(read("FOLDER-GUIDE.txt")));
[
  ["Click these/1 Install - guided/Windows.bat", "scripts\\install-gui.ps1"],
  ["Click these/1 Install - guided/Mac.command", "mac/install-gui.pl"],
  ["Click these/1 Install - guided/Linux.sh", "OFFLINE_AI_OS=linux"],
  ["Click these/2 Install - no questions/Windows.bat", "EASY-INSTALL (Windows).bat"],
  ["Click these/2 Install - no questions/Mac.command", "EASY-INSTALL (Mac).command"],
  ["Click these/2 Install - no questions/Linux.sh", "EASY-INSTALL (Linux).sh"],
  ["Click these/3 Start/Windows.bat", "START-OFFLINE-AI.bat"],
  ["Click these/3 Start/Mac.command", "START-OFFLINE-AI-MAC.command"],
  ["Click these/3 Start/Linux.sh", "START-OFFLINE-AI-LINUX.sh"],
  ["Click these/4 Stop/Windows.bat", "STOP-OFFLINE-AI.bat"],
  ["Click these/4 Stop/Mac.command", "STOP-OFFLINE-AI-MAC.command"],
  ["Click these/4 Stop/Linux.sh", "STOP-OFFLINE-AI-LINUX.sh"],
  ["Click these/5 Check status/Windows.bat", "STATUS.bat"],
  ["Click these/5 Check status/Mac.command", "STATUS-MAC.command"],
  ["Click these/5 Check status/Linux.sh", "STATUS-LINUX.sh"]
].forEach(function (pair) {
  check("launcher " + pair[0], exists(pair[0]) && read(pair[0]).indexOf(pair[1]) !== -1);
});
["Click these/2 Install - no questions/Windows.bat", "Click these/2 Install - no questions/Mac.command", "Click these/2 Install - no questions/Linux.sh"].forEach(function (f) {
  check(f + " does not pass a maps flag", !/--maps|-Maps/.test(read(f)));
});
check("copy lists include the new folder", /Click these/.test(read("scripts/setup.ps1")) && /Click these/.test(read("mac/setup.sh")) && /FOLDER-GUIDE\.txt/.test(read("scripts/setup.ps1")));
check("guided flags exist on both setups", /NoShareWifi/.test(read("scripts/setup.ps1")) && /ThisComputer/.test(read("scripts/setup.ps1")) && /--no-share-wifi/.test(read("mac/setup.sh")) && /--this-computer/.test(read("mac/setup.sh")));
check("version is 1.4.0", read("VERSION").trim() === "1.4.0");

const ctxText = execFileSync("bash", [path.join(root, "mac/wizard-context.sh")], { encoding: "utf8" });
const ctx = JSON.parse(ctxText);
check("this computer context is JSON", (ctx.os === "mac" || ctx.os === "linux") && typeof ctx.freeGB === "number" && ctx.folder && (ctx.suggestedTier === "1" || ctx.suggestedTier === "2"), ctx);

function get(port, urlPath) {
  return new Promise(function (resolve, reject) {
    http.get({ host: "127.0.0.1", port: port, path: urlPath }, function (res) {
      let body = "";
      res.setEncoding("utf8");
      res.on("data", function (c) { body += c; });
      res.on("end", function () { resolve({ status: res.statusCode, body: body }); });
    }).on("error", reject);
  });
}

const child = spawn("perl", [path.join(root, "mac/install-gui.pl")], {
  cwd: root,
  env: Object.assign({}, process.env, { OFFLINE_AI_NO_BROWSER: "1" }),
  stdio: ["ignore", "pipe", "pipe"]
});
let ready = "";
const started = new Promise(function (resolve, reject) {
  const timer = setTimeout(function () { reject(new Error("installer did not start: " + ready)); }, 8000);
  child.stdout.on("data", function (buf) {
    ready += buf.toString();
    const m = ready.match(/http:\/\/127\.0\.0\.1:(\d+)\//);
    if (m) { clearTimeout(timer); resolve(Number(m[1])); }
  });
  child.on("exit", function (code) { clearTimeout(timer); reject(new Error("installer exited " + code + " " + ready)); });
});

started.then(function (port) {
  return get(port, "/api/context").then(function (res) {
    const live = JSON.parse(res.body);
    check("installer page serves context", res.status === 200 && live.folder && live.os, live);
    return get(port, "/install-wizard.js");
  }).then(function (res) {
    check("installer page serves the script", res.status === 200 && /function estimate/.test(res.body));
    return get(port, "/nope");
  }).then(function (res) {
    check("unknown installer path is 404", res.status === 404, res.status);
  });
}).catch(function (err) {
  check("installer page starts", false, String(err));
}).then(function () {
  child.kill("SIGTERM");
  console.log(fails ? fails + " check(s) FAILED" : "All guided checks passed.");
  process.exit(fails ? 1 : 0);
});
