/* Guided installer, emergency screen, and the Click these folder.
   No downloads. Does not start Ollama or Kiwix.
   Starts the Mac/Linux installer page only long enough to read /api/context. */
"use strict";
const fs = require("fs");
const path = require("path");
const { execFileSync, spawn, spawnSync } = require("child_process");
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
  ["Click these/5 Check status/Linux.sh", "STATUS-LINUX.sh"],
  ["Click these/6 Uninstall/Windows.bat", "UNINSTALL.bat"],
  ["Click these/6 Uninstall/Mac.command", "UNINSTALL-OFFLINE-AI-MAC.command"],
  ["Click these/6 Uninstall/Linux.sh", "UNINSTALL-OFFLINE-AI-LINUX.sh"]
].forEach(function (pair) {
  check("launcher " + pair[0], exists(pair[0]) && read(pair[0]).indexOf(pair[1]) !== -1);
});
["Click these/2 Install - no questions/Windows.bat", "Click these/2 Install - no questions/Mac.command", "Click these/2 Install - no questions/Linux.sh"].forEach(function (f) {
  check(f + " does not pass a maps flag", !/--maps|-Maps/.test(read(f)));
});
check("copy lists include the new folder", /Click these/.test(read("scripts/setup.ps1")) && /Click these/.test(read("mac/setup.sh")) && /FOLDER-GUIDE\.txt/.test(read("scripts/setup.ps1")));
check("guided flags exist on both setups", /NoShareWifi/.test(read("scripts/setup.ps1")) && /ThisComputer/.test(read("scripts/setup.ps1")) && /--no-share-wifi/.test(read("mac/setup.sh")) && /--this-computer/.test(read("mac/setup.sh")));
check("version is 1.6.0", read("VERSION").trim() === "1.6.0");
check("folder on a drive is Offline AI Kit", W.driveFolder("/Volumes/SSD") === "/Volumes/SSD/Offline AI Kit" && W.driveFolder("E:\\") === "E:\\Offline AI Kit");
check("FAT32 cannot be a ready drive", W.usableDrive({ path: "F:\\", format: "FAT32", fat32: true }) === false && W.fat32Blocked({ format: "ExFAT", fat32: false }) === false);
{
  const ext = W.externalReady(win, { path: "/Volumes/SSD", format: "ExFAT", freeGB: 400, fat32: false, current: false });
  check("external drive turns Wikipedia and the guides on", ext.wikipedia === true && ext.wikiNow === true && ext.tier === "2" && ext.path === "/Volumes/SSD/Offline AI Kit");
  W.GUIDE_EXTRAS.forEach(function (id) { check(id + " is included on a new drive", ext.extras.indexOf(id) !== -1); });
  check("exFAT suggests every computer", ext.universal === true && ext.suggestUniversal === true);
  const extEst = W.estimate(Object.assign({}, win, { freeGB: 20 }), ext, extras, maps);
  check("estimate uses the chosen drive's free space", extEst.tooBig === false && extEst.lines.some(function (l) { return l.label === "Folder" && l.value === ext.path; }), extEst);
  const small = W.externalReady(win, { path: "E:\\", format: "NTFS", freeGB: 50, fat32: false, current: false });
  check("a drive that cannot hold Wikipedia is too small", W.estimate(win, small, extras, maps).tooBig === true && small.path === "E:\\Offline AI Kit");
  const kept = W.externalReady(Object.assign({}, win, { folder: "/Volumes/SSD/offline-ai-kit" }), { path: "/Volumes/SSD", format: "APFS", freeGB: 800, current: true });
  check("keeping this drive uses the current folder", kept.path === "/Volumes/SSD/offline-ai-kit" && kept.universal === false);
}
check("foreground Wikipedia flag is in both setups", /--wiki-now/.test(read("mac/setup.sh")) && /WikiNow/.test(read("scripts/setup.ps1")) && /--wiki-now/.test(read("mac/install-gui.pl")) && /-WikiNow/.test(read("scripts/install-gui.ps1")));
check("drive list script exists", exists("mac/list-drives.sh") && /api\/drives/.test(read("mac/install-gui.pl")) && /api\/drives/.test(read("scripts/install-gui.ps1")));
{
  const every = W.everyComputerChoices(win);
  check("every computer choice downloads Wikipedia now", every.wikipedia === true && every.wikiNow === true && every.tier === "2" && every.universal === true && every.suggestUniversal === true && every.macImage === false && every.drawerReady === true);
  W.GUIDE_EXTRAS.forEach(function (id) { check(id + " is included for every computer", every.extras.indexOf(id) !== -1); });
  check("mac copy is not added", W.macCopyGB("mac", [{ gb: 4 }, { gb: 3.9 }]) === 0 && W.macCopyGB("windows", [{ gb: 127.4 }]) === 0);
  const macCtx = Object.assign({}, win, { os: "mac" });
  const macDrive = Object.assign({}, every, { driveFreeGB: 900, path: "/Volumes/OFFLINEAI/Offline AI Kit" });
  const macEst = W.estimate(macCtx, macDrive, extras, maps);
  check("estimate has one copy of the books", macEst.copyGB === 0 && macEst.lines.every(function (l) { return l.label !== "Mac copy"; }), macEst);
  const winDrive = Object.assign({}, every, { driveFreeGB: 900, path: "E:\\Offline AI Kit" });
  const winCopy = W.estimate(win, winDrive, extras, maps);
  check("estimate does not add a second copy on Windows", winCopy.copyGB === 0 && winCopy.lines.every(function (l) { return l.label !== "Mac copy"; }), winCopy);
  const disk = { id: "disk9", sizeGB: 1000, internal: false, startup: false, partitions: [{ id: "disk9s2", name: "ONE" }, { id: "disk9s3", name: "TWO" }] };
  check("erase stays off until the box is ticked", W.prepareError(disk, { mode: "partition", partitionId: "disk9s2", confirmed: false }) !== "");
  check("startup disk is rejected", W.prepareError({ id: "disk0", startup: true, sizeGB: 500, partitions: [] }, { mode: "disk", confirmed: true, sizeGB: 0 }) !== "");
  check("internal disk is rejected", W.prepareError({ id: "disk1", internal: true, sizeGB: 500, partitions: [] }, { mode: "disk", confirmed: true, sizeGB: 0 }) !== "");
  check("partition erase names only that partition", JSON.stringify(W.eraseNames(disk, { mode: "partition", partitionId: "disk9s2" })) === "[\"ONE\"]");
  check("whole-disk erase names every partition", W.eraseNames(disk, { mode: "disk" }).join(",") === "ONE,TWO");
  check("a size below 200 GB is rejected", W.prepareError(disk, { mode: "disk", confirmed: true, sizeGB: 100 }) !== "");
  check("a size larger than the disk is rejected", W.prepareError(disk, { mode: "disk", confirmed: true, sizeGB: 5000 }) !== "");
  check("a partition that is not on the disk is rejected", W.prepareError(disk, { mode: "partition", partitionId: "disk8s2", confirmed: true }) !== "");
  const big = { id: "disk9", sizeGB: 4000, internal: false, startup: false, partitions: [{ id: "disk9s2", name: "ONE" }, { id: "disk9s3", name: "TWO" }] };
  check("a 3 TB Windows drive leaves the rest for the kit", W.prepareError(big, { mode: "disk", confirmed: true, sizeGB: 0, modelsGB: 3000 }) === "");
  check("a Windows drive must leave 200 GB for the kit", W.prepareError(disk, { mode: "disk", confirmed: true, sizeGB: 0, modelsGB: 3000 }) !== "");
  check("a Windows drive is not made from one partition", W.prepareError(disk, { mode: "partition", partitionId: "disk9s2", confirmed: true, modelsGB: 3000 }) !== "");
  check("a Windows drive below 200 GB is rejected", W.prepareError(big, { mode: "disk", confirmed: true, modelsGB: 100 }) !== "");
}
check("prepare scripts refuse the startup disk", /startup disk/.test(read("mac/prepare-disk.sh")) && /startup disk/.test(read("scripts/prepare-disk.ps1")) && /IsSystem/.test(read("scripts/prepare-disk.ps1")) && /BusType/.test(read("scripts/prepare-disk.ps1")));
check("linux prepare does not offer a whole-disk erase", /not offered on Linux/.test(read("mac/prepare-disk.sh")));
check("disk list endpoint exists", /api\/disks/.test(read("mac/install-gui.pl")) && /api\/disks/.test(read("scripts/install-gui.ps1")) && /api\/prepare/.test(read("mac/install-gui.pl")) && /api\/prepare/.test(read("scripts/install-gui.ps1")));
check("mac copy is gone", !/prepare_mac_library_image/.test(read("mac/lib.sh")) && !/prepare_mac_library_image/.test(read("mac/setup.sh")) && /libzim 9\.6/.test(read("README.md")));
{
  const safe = spawnSync("bash", [path.join(root, "mac/prepare-disk.sh")], {
    input: JSON.stringify({ confirmed: false, disk: "disk4", mode: "disk", diskSizeGB: 1000, sizeGB: 0 }),
    encoding: "utf8",
    timeout: 8000
  });
  const safeOut = (safe.stdout || "") + (safe.stderr || "");
  check("unconfirmed prepare refuses before an erase", safe.status !== 0 && /Refused/.test(safeOut) && !/eraseVolume|partitionDisk|deleteContainer|mkfs/.test(safeOut), safeOut.slice(0, 300));
  const missing = spawnSync("bash", [path.join(root, "mac/prepare-disk.sh")], {
    input: JSON.stringify({ confirmed: true, mode: "partition", disk: "disk99", partitionId: "disk99s2", diskSizeGB: 10, sizeGB: 0 }),
    encoding: "utf8",
    timeout: 15000
  });
  const missingOut = (missing.stdout || "") + (missing.stderr || "");
  check("a missing disk is refused", missing.status !== 0 && /Refused/.test(missingOut) && !/Started partitioning|Finished erase|Formatting/i.test(missingOut), missingOut.slice(0, 300));
  const smallWindows = spawnSync("bash", [path.join(root, "mac/prepare-disk.sh")], {
    input: JSON.stringify({ confirmed: true, mode: "disk", disk: "disk99", diskSizeGB: 4000, sizeGB: 0, modelsGB: 100 }),
    encoding: "utf8",
    timeout: 8000
  });
  const smallOut = (smallWindows.stdout || "") + (smallWindows.stderr || "");
  check("a small Windows drive is refused before an erase", smallWindows.status !== 0 && /at least 200 GB/.test(smallOut) && !/partitionDisk|eraseVolume|mkfs/.test(smallOut), smallOut.slice(0, 300));
}
if (process.platform === "darwin") {
  const info = execFileSync("diskutil", ["info", "/"], { encoding: "utf8" });
  const whole = ((info.match(/Part of Whole:\s+(\S+)/) || [])[1] || "");
  const phys = ((info.match(/Physical Store:\s+(\S+)/) || [])[1] || "").replace(/s\d.*$/, "");
  const listed = execFileSync("bash", [path.join(root, "mac/list-disks.sh")], { encoding: "utf8", timeout: 60000 });
  const liveDisks = JSON.parse(listed);
  check("list-disks prints a JSON array", Array.isArray(liveDisks));
  check("list-disks omits the startup disk", !liveDisks.some(function (d) { return d.id === whole || d.id === phys || d.startup === true || d.internal === true; }), liveDisks.map(function (d) { return d.id; }));
  liveDisks.forEach(function (d) {
    check(d.id + " is an external disk id", /^disk\d+$/.test(d.id) && typeof d.sizeGB === "number");
    (d.partitions || []).forEach(function (p) {
      check(p.id + " stays on its disk", p.id.indexOf(d.id + "s") === 0 && !/^EFI$/i.test(p.name));
    });
  });
}

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
function post(port, urlPath, obj) {
  const body = JSON.stringify(obj);
  return new Promise(function (resolve, reject) {
    const req = http.request({
      host: "127.0.0.1", port: port, path: urlPath, method: "POST",
      headers: { "Content-Type": "application/json", "Content-Length": Buffer.byteLength(body) }
    }, function (res) {
      let data = "";
      res.setEncoding("utf8");
      res.on("data", function (c) { data += c; });
      res.on("end", function () { resolve({ status: res.statusCode, body: data }); });
    });
    req.on("error", reject);
    req.write(body);
    req.end();
  });
}
function waitForPrepareLog(port) {
  const started = Date.now();
  function once() {
    return get(port, "/api/log").then(function (res) {
      let data = {};
      try { data = JSON.parse(res.body); } catch (e) { data = { text: res.body || "" }; }
      if (typeof data.exit === "number") return data;
      if (Date.now() - started > 20000) return data;
      return new Promise(function (resolve) { setTimeout(resolve, 250); }).then(once);
    });
  }
  return once();
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
    return get(port, "/api/drives");
  }).then(function (res) {
    const drives = JSON.parse(res.body);
    check("installer lists drives", res.status === 200 && Array.isArray(drives), res.body.slice(0, 240));
    check("drive list includes this copy", drives.some(function (d) { return d.current === true && d.path && typeof d.freeGB === "number" && typeof d.fat32 === "boolean"; }), drives);
    return get(port, "/api/disks");
  }).then(function (res) {
    const disks = JSON.parse(res.body);
    check("installer lists disks", res.status === 200 && Array.isArray(disks), res.body.slice(0, 240));
    return post(port, "/api/prepare", { confirmed: false, disk: "disk99", mode: "disk", diskSizeGB: 1 });
  }).then(function (res) {
    check("installer refuses an erase that is not confirmed", res.status === 400 && /Tick|eras/i.test(res.body), res.status + " " + res.body.slice(0, 200));
    return post(port, "/api/prepare", { confirmed: true, mode: "partition", disk: "disk99", partitionId: "disk99s2", diskSizeGB: 10, sizeGB: 0 });
  }).then(function (res) {
    check("installer starts prepare for a missing disk", res.status === 200 && /"ok":true/.test(res.body), res.status + " " + res.body.slice(0, 200));
    if (res.status !== 200) return null;
    return waitForPrepareLog(port);
  }).then(function (log) {
    if (log) {
      const text = log.text || "";
      check("prepare log shows the refusal", log.exit === 1 && text.trim().length > 0 && /Refused:/.test(text) && !/eraseVolume|partitionDisk|deleteContainer|mkfs/.test(text), JSON.stringify(log).slice(0, 400));
    }
    return get(port, "/install-wizard.js");
  }).then(function (res) {
    check("installer page serves the script", res.status === 200 && /function estimate/.test(res.body));
    return post(port, "/api/drive-tools", { action: "library", phrase: "WRONG PHRASE", files: ["not-a-real-book.zim"] });
  }).then(function (res) {
    check("drive tools rejects a wrong phrase", res.status === 400 && /confirmation/.test(res.body), res.status + " " + res.body.slice(0, 200));
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
