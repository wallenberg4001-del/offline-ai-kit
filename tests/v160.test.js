/* v1.6.0 scriptable acceptance tests. Fake kits only.
   Never deletes this checkout, never erases a disk, never downloads books. */
"use strict";
const crypto = require("crypto");
const fs = require("fs");
const os = require("os");
const path = require("path");
const { spawn, spawnSync } = require("child_process");

const root = path.join(__dirname, "..");
const repo = fs.realpathSync(root);
let fails = 0;
const temps = [];
let sleeper = null;

function check(name, ok, extra) {
  console.log((ok ? "ok  " : "FAIL") + "  " + name);
  if (!ok) {
    fails++;
    if (extra !== undefined) console.log("     " + String(extra).slice(0, 800));
  }
}
function read(rel) { return fs.readFileSync(path.join(root, rel), "utf8"); }
function sha(buf) { return crypto.createHash("sha256").update(buf).digest("hex"); }
function q(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'"; }

function outsideRepo(dir) {
  const resolved = fs.realpathSync(dir);
  if (resolved === repo || resolved.indexOf(repo + path.sep) === 0 || repo.indexOf(resolved + path.sep) === 0) {
    throw new Error("refusing to touch the checkout: " + resolved);
  }
  return resolved;
}

function baseEnv(extra) {
  const env = Object.assign({}, process.env);
  ["OFFLINE_AI_PREPARE_CMD", "OFFLINE_AI_SPLIT_DIE_AFTER", "OFFLINE_AI_SPLIT_INPLACE",
    "OFFLINE_AI_SPLIT_BYTES", "OFFLINE_AI_MIGRATE_YES", "OFFLINE_AI_MIGRATE_NO",
    "OFFLINE_AI_TEST", "OFFLINE_AI_LIBZIM_TEXT", "OFFLINE_AI_KIT_ON_STARTUP",
    "OFFLINE_AI_DISK_PARTITIONS", "OFFLINE_AI_DISK_ID", "OFFLINE_AI_PARTITION_ID",
    "OFFLINE_AI_KIT_LABEL", "OFFLINE_AI_OS", "TEST_MODE", "EASY"].forEach(function (k) { delete env[k]; });
  return Object.assign(env, extra || {});
}

function bash(script, env) {
  const r = spawnSync("bash", ["-c", script], {
    encoding: "utf8",
    timeout: 60000,
    env: env || baseEnv()
  });
  return { status: r.status, out: (r.stdout || "") + (r.stderr || ""), error: r.error };
}

function bashFile(file, env) {
  const r = spawnSync("bash", [file], { encoding: "utf8", timeout: 60000, env: env || baseEnv() });
  return { status: r.status, out: (r.stdout || "") + (r.stderr || ""), error: r.error };
}

function runArgs(file, args, env) {
  const r = spawnSync("bash", [file].concat(args), {
    encoding: "utf8",
    timeout: 60000,
    env: env || baseEnv(),
    input: ""
  });
  return { status: r.status, out: (r.stdout || "") + (r.stderr || ""), error: r.error };
}

function makeKit() {
  const base = outsideRepo(fs.realpathSync(fs.mkdtempSync(path.join(os.tmpdir(), "offline-ai-v160-"))));
  temps.push(base);
  const kit = path.join(base, "Offline AI Kit");
  ["mac", "library/checksums/VERIFIED", "library/checksums/PROBE", "catalog", "runtime/fake-kiwix",
    "ollama-models/blobs", "www", "scripts", "home", "logs"].forEach(function (rel) {
    fs.mkdirSync(path.join(kit, rel), { recursive: true });
  });
  fs.writeFileSync(path.join(kit, "VERSION"), "1.6.0\n");
  ["lib.sh", "v160.sh", "uninstall.sh", "drive-tools.sh", "check-drive.sh"].forEach(function (name) {
    const dest = path.join(kit, "mac", name);
    fs.copyFileSync(path.join(root, "mac", name), dest);
    fs.chmodSync(dest, 0o755);
  });
  fs.copyFileSync(path.join(root, "catalog/runtime-pins.txt"), path.join(kit, "catalog/runtime-pins.txt"));
  const search = [
    "#!/bin/bash",
    "target=\"$1\"",
    "query=\"$2\"",
    "case \"$target\" in",
    "  *bad*) echo 'Cannot read file: Invalid argument' >&2; exit 1 ;;",
    "esac",
    "if [ \"$query\" = water ]; then",
    "  case \"$target\" in",
    "    *nosearch*) exit 0 ;;",
    "    *) echo '1 result'; exit 0 ;;",
    "  esac",
    "fi",
    "case \"$target\" in",
    "  *noindex*) echo 'Cannot create Search without FT Xapian index'; exit 1 ;;",
    "esac",
    "echo opened",
    "exit 0",
    ""
  ].join("\n");
  fs.writeFileSync(path.join(kit, "runtime/fake-kiwix/kiwix-search"), search);
  fs.writeFileSync(path.join(kit, "runtime/fake-kiwix/kiwix-serve"), "#!/bin/bash\necho 'kiwix-tools 3.8.2'\necho 'libzim 9.8.2'\n");
  fs.chmodSync(path.join(kit, "runtime/fake-kiwix/kiwix-search"), 0o755);
  fs.chmodSync(path.join(kit, "runtime/fake-kiwix/kiwix-serve"), 0o755);
  const home = path.join(base, "home");
  fs.mkdirSync(home, { recursive: true });
  outsideRepo(kit);
  return { base: base, kit: kit, home: home };
}

function kitScript(kit, body) {
  const file = path.join(path.dirname(kit), "run.sh");
  fs.writeFileSync(file, "set -u\n. " + q(path.join(kit, "mac/lib.sh")) + "\nKIWIX_DIR=" + q(path.join(kit, "runtime/fake-kiwix")) + "\nexport KIWIX_DIR\n" + body + "\n");
  return file;
}

function treeHashes(dir) {
  const out = {};
  function walk(d) {
    fs.readdirSync(d).forEach(function (name) {
      const p = path.join(d, name);
      const st = fs.lstatSync(p);
      if (st.isSymbolicLink()) return;
      if (st.isDirectory()) walk(p);
      else out[path.relative(dir, p)] = sha(fs.readFileSync(p));
    });
  }
  if (fs.existsSync(dir)) walk(dir);
  return out;
}

function diffKeys(before, after) {
  const keys = {};
  Object.keys(before).forEach(function (k) { keys[k] = true; });
  Object.keys(after).forEach(function (k) { keys[k] = true; });
  return Object.keys(keys).filter(function (k) { return before[k] !== after[k]; }).sort();
}

function ge(have, min) {
  const a = have.split(".").map(Number);
  const b = min.split(".").map(Number);
  for (let i = 0; i < 3; i++) {
    if ((a[i] || 0) > (b[i] || 0)) return true;
    if ((a[i] || 0) < (b[i] || 0)) return false;
  }
  return true;
}

function pins() {
  const rows = [];
  read("catalog/runtime-pins.txt").split(/\n/).forEach(function (line) {
    const t = line.trim();
    if (!t || t.charAt(0) === "#") return;
    const p = t.split("|").map(function (s) { return s.trim(); });
    if (p.length >= 5) rows.push({ component: p[0], platform: p[1], url: p[2], sha256: p[3], version: p[4] });
  });
  return rows;
}

function cleanup() {
  if (sleeper && !sleeper.killed) {
    try { sleeper.kill("SIGKILL"); } catch (e) { /* already gone */ }
  }
  temps.forEach(function (dir) {
    spawnSync("python3", ["-c", "import shutil,sys; shutil.rmtree(sys.argv[1], ignore_errors=True)", dir], { encoding: "utf8" });
  });
}
process.on("exit", cleanup);

["mac/lib.sh", "mac/v160.sh", "mac/uninstall.sh", "mac/drive-tools.sh", "mac/check-drive.sh",
  "mac/setup.sh", "mac/start.sh", "mac/status.sh", "linux/uninstall.sh", "linux/drive-tools.sh",
  "linux/check-drive.sh"].forEach(function (rel) {
  const r = spawnSync("bash", ["-n", path.join(root, rel)], { encoding: "utf8" });
  check("bash -n " + rel, r.status === 0, (r.stdout || "") + (r.stderr || ""));
});
const perl = spawnSync("perl", ["-c", path.join(root, "mac/install-gui.pl")], { encoding: "utf8" });
check("perl -c mac/install-gui.pl", perl.status === 0, (perl.stdout || "") + (perl.stderr || ""));

const pinRows = pins();
const kiwixPlatforms = ["mac-arm64", "mac-x64", "windows-x64", "linux-x64", "linux-arm64", "linux-x64-musl", "linux-arm64-musl"];
kiwixPlatforms.forEach(function (platform) {
  const row = pinRows.filter(function (r) { return r.component === "kiwix-tools" && r.platform === platform; })[0];
  check("pin kiwix " + platform + " is libzim >= 9.6.0", !!row && ge(row.version, "9.6.0") && /^[0-9a-f]{64}$/.test(row.sha256) && row.url.indexOf("2026-11-22") !== -1, row);
});
["mac-arm64", "mac-x64", "windows-x64", "linux-x64", "linux-arm64"].forEach(function (platform) {
  const row = pinRows.filter(function (r) { return r.component === "ollama" && r.platform === platform; })[0];
  check("pin ollama " + platform, !!row && row.version === "v0.40.17" && /^[0-9a-f]{64}$/.test(row.sha256), row);
});
["mac-arm64", "mac-x64"].forEach(function (platform) {
  const row = pinRows.filter(function (r) { return r.component === "ollama-v0.12.9" && r.platform === platform; })[0];
  check("pin ollama v0.12.9 " + platform, !!row && row.sha256 === "a3bd64569cb945133dd714f3568989f6bcd4d988a3ba47d2c0dc644770547f17", row);
});
["darwin-arm64", "darwin-amd64", "linux-amd64", "linux-arm64", "windows-x64"].forEach(function (platform) {
  const row = pinRows.filter(function (r) { return r.component === "zstd" && r.platform === platform; })[0];
  check("pin zstd " + platform, !!row && /^[0-9a-f]{64}$/.test(row.sha256), row);
});
check("pin rows are complete and this test does not fetch them", pinRows.length >= 20 && pinRows.every(function (r) { return r.url.indexOf("http") === 0 && r.sha256.length === 64; }));

const accept = bash("set -u\n. " + q(path.join(root, "mac/lib.sh")) + "\nv160_accept_libzim 9.5.0\necho RC:$?\nv160_accept_libzim 9.6.0\necho RC:$?\nv160_accept_libzim 9.8.2\necho RC:$?\n", baseEnv());
check("libzim 9.5.0 is refused and 9.6.0 and 9.8.2 pass",
  accept.status === 0 && /libzim 9\.5\.0/.test(accept.out) && /9\.6\.0 or newer/.test(accept.out) && /RC:1/.test(accept.out) && /RC:0[\s\S]*RC:0/.test(accept.out),
  accept.out);

const bundled = "/tmp/kiwix-pins/mac-arm/kiwix-tools_macos-arm64-2026-11-22/kiwix-serve";
if (fs.existsSync(bundled)) {
  const ver = spawnSync(bundled, ["--version"], { encoding: "utf8" });
  check("unpacked mac-arm64 kiwix-serve reports libzim >= 9.6.0", ver.status === 0 && /libzim 9\.(6|[7-9]|[1-9][0-9])/.test((ver.stdout || "") + (ver.stderr || "")), (ver.stdout || "") + (ver.stderr || ""));
} else {
  console.log("note  unpacked kiwix-serve is not in /tmp; pin versions were checked instead");
}

function probeEnv(home) {
  return baseEnv({
    HOME: home,
    OFFLINE_AI_TEST: "yes",
    OFFLINE_AI_LIBZIM_TEXT: "libzim 9.8.2",
    USER: "v160tester"
  });
}

(function books() {
  const k = makeKit();
  fs.writeFileSync(path.join(k.kit, "library/good.zim"), "good-book");
  fs.writeFileSync(path.join(k.kit, "library/bad.zim"), "bad-book");
  fs.writeFileSync(path.join(k.kit, "library/checksums/VERIFIED/good.zim"), "ok\n");
  fs.writeFileSync(path.join(k.kit, "library/checksums/VERIFIED/bad.zim"), "ok\n");
  const r = bashFile(kitScript(k.kit, "v160_select_books"), probeEnv(k.home));
  check("a bad book is skipped and the good book is still selected",
    r.status === 0 && /SERVE .*good\.zim/.test(r.out) && /SKIP .*bad\.zim/.test(r.out) && /Skipped bad\.zim/.test(r.out),
    r.out);
})();

(function splitOk() {
  const k = makeKit();
  const body = Buffer.alloc(5000);
  for (let i = 0; i < body.length; i++) body[i] = (i * 17) % 251;
  const original = sha(body);
  fs.writeFileSync(path.join(k.kit, "library/open.zim"), body);
  fs.writeFileSync(path.join(k.kit, "library/checksums/VERIFIED/open.zim"), original + "\n");
  const r = bashFile(kitScript(k.kit, [
    "export OFFLINE_AI_SPLIT_BYTES=2000",
    "v160_finish_split " + q(path.join(k.kit, "library/open.zim")),
    "echo RC:$?",
    "echo LIST",
    "v160_list_books"
  ].join("\n")), probeEnv(k.home));
  const parts = ["aa", "ab", "ac"].map(function (suf) { return path.join(k.kit, "library/open.zim" + suf); });
  const concat = Buffer.concat(parts.filter(fs.existsSync).map(function (p) { return fs.readFileSync(p); }));
  const listed = (r.out.split("LIST")[1] || "").split(/\n/).filter(function (line) { return line.indexOf("open.zim") !== -1; });
  check("split keeps one catalog entry and the original hash",
    r.status === 0 && /RC:0/.test(r.out) && sha(concat) === original && /SHA /.test(r.out) && r.out.indexOf(original) !== -1 && listed.length === 1,
    r.out + "\nconcat=" + sha(concat));
  check("original is deleted only after the probes pass",
    !fs.existsSync(path.join(k.kit, "library/open.zim")) && !fs.existsSync(path.join(k.kit, "library/open.zim.held")) && parts.every(fs.existsSync),
    r.out);
})();

(function splitSearchOff() {
  const k = makeKit();
  const body = Buffer.from("nosearch-book-contents-0123456789");
  fs.writeFileSync(path.join(k.kit, "library/nosearch.zim"), body);
  fs.writeFileSync(path.join(k.kit, "library/checksums/VERIFIED/nosearch.zim"), sha(body) + "\n");
  const r = bashFile(kitScript(k.kit, [
    "export OFFLINE_AI_SPLIT_BYTES=10",
    "v160_finish_split " + q(path.join(k.kit, "library/nosearch.zim")),
    "echo RC:$?"
  ].join("\n")), probeEnv(k.home));
  const after = fs.existsSync(path.join(k.kit, "library/nosearch.zim")) ? fs.readFileSync(path.join(k.kit, "library/nosearch.zim")) : Buffer.alloc(0);
  const partsLeft = fs.readdirSync(path.join(k.kit, "library")).filter(function (n) { return n.indexOf("nosearch.zim") === 0 && n !== "nosearch.zim"; });
  check("search-off restores the original",
    /search-off/.test(r.out) && sha(after) === sha(body) && partsLeft.length === 0,
    r.out + " parts=" + partsLeft.join(","));
})();

(function splitResume() {
  const k = makeKit();
  const body = Buffer.alloc(2500);
  for (let i = 0; i < body.length; i++) body[i] = (i * 3) % 251;
  const original = sha(body);
  const zim = path.join(k.kit, "library/resume.zim");
  fs.writeFileSync(zim, body);
  const first = bashFile(kitScript(k.kit, [
    "export OFFLINE_AI_SPLIT_BYTES=1000",
    "export OFFLINE_AI_SPLIT_INPLACE=yes",
    "export OFFLINE_AI_SPLIT_DIE_AFTER=1",
    "v160_split_book " + q(zim),
    "echo RC:$?"
  ].join("\n")), probeEnv(k.home));
  const peak = /PEAK_EXTRA ([0-9]+)/.exec(first.out);
  const peakOk = peak && Number(peak[1]) <= 1000 + 1000000000;
  const second = bashFile(kitScript(k.kit, [
    "export OFFLINE_AI_SPLIT_BYTES=1000",
    "export OFFLINE_AI_SPLIT_INPLACE=yes",
    "export OFFLINE_AI_SPLIT_DIE_AFTER=0",
    "v160_split_book " + q(zim),
    "echo RC:$?"
  ].join("\n")), probeEnv(k.home));
  const parts = ["aa", "ab", "ac"].map(function (suf) { return path.join(k.kit, "library/resume.zim" + suf); });
  const concat = Buffer.concat(parts.filter(fs.existsSync).map(function (p) { return fs.readFileSync(p); }));
  check("in-place split resumes after a stop and keeps the hash",
    /RC:75/.test(first.out) && peakOk && /RC:0/.test(second.out) && sha(concat) === original && second.out.indexOf(original) !== -1,
    first.out + "\n" + second.out + "\nconcat=" + sha(concat));
})();

(function uninstallGuard() {
  const k = makeKit();
  const marker = path.join(k.kit, "library/marker.txt");
  fs.writeFileSync(marker, "stay\n");
  const secret = path.join(k.home, "secrets.txt");
  fs.writeFileSync(secret, "secret\n");
  const link = path.join(k.home, "offline-ai-kit");
  fs.symlinkSync(k.kit, link);
  const allowed = path.join(k.home, "Library/Caches/offline-ai-kit");
  fs.mkdirSync(allowed, { recursive: true });
  fs.writeFileSync(path.join(allowed, "probe.txt"), "cache\n");
  const r = bashFile(kitScript(k.kit, [
    "safe_remove " + q(marker) + "; echo UNDER:$?",
    "safe_remove " + q(secret) + "; echo NAME:$?",
    "safe_remove " + q(link) + "; echo LINK:$?",
    "safe_remove " + q("/Volumes") + "; echo VOL:$?",
    "safe_remove " + q(allowed) + "; echo ALLOW:$?"
  ].join("\n")), probeEnv(k.home));
  check("safe_remove refuses the kit, a home path, a symlink, and /Volumes",
    /Refused \(on the kit drive\):/.test(r.out) && fs.readFileSync(marker, "utf8") === "stay\n" && fs.existsSync(secret) && fs.existsSync(link) && fs.existsSync("/Volumes") && /UNDER:1/.test(r.out) && /NAME:1/.test(r.out) && /LINK:1/.test(r.out) && /VOL:1/.test(r.out),
    r.out);
  check("safe_remove deletes an allow-listed cache under home", /ALLOW:0/.test(r.out) && !fs.existsSync(allowed), r.out);

  const sh = read("mac/uninstall.sh");
  const ps = read("scripts/uninstall.ps1");
  check("uninstall source does not delete the kit folder",
    sh.indexOf('rm -rf "$KIT"') === -1 && sh.indexOf('remove_dir "$KIT"') === -1 && ps.indexOf("rmdir /s") === -1 && !/Remove-Item[^\n]*\$target/.test(ps));
  const rootTry = runArgs(path.join(root, "mac/uninstall.sh"), ["--yes", "--root", k.kit], probeEnv(k.home));
  check("--root without --dry-run refuses", rootTry.status === 1 && /dry-run/.test(rootTry.out) && fs.existsSync(marker), rootTry.out);
})();

(function uninstallComputer() {
  const k = makeKit();
  fs.writeFileSync(path.join(k.kit, "library/keep.zim"), "book");
  fs.writeFileSync(path.join(k.kit, "library/split.zimaa"), "aa");
  fs.writeFileSync(path.join(k.kit, "library/split.zimab"), "ab");
  fs.writeFileSync(path.join(k.kit, "ollama-models/blobs/blob.bin"), "model");
  fs.writeFileSync(path.join(k.kit, "runtime/marker.txt"), "runtime");
  fs.writeFileSync(path.join(k.kit, "catalog/note.txt"), "catalog");
  fs.writeFileSync(path.join(k.kit, "www/page.txt"), "www");
  fs.writeFileSync(path.join(k.kit, "scripts/note.txt"), "scripts");
  fs.writeFileSync(path.join(k.kit, "home/note.txt"), "home");
  fs.writeFileSync(path.join(k.kit, "kit-id.txt"), "abc123\n");
  fs.writeFileSync(path.join(k.kit, "logs/kiwix.mac.pid"), "999999\n");
  fs.writeFileSync(path.join(k.kit, "logs/kiwix.linux.pid"), "111\n");
  const desk = path.join(k.home, "Desktop");
  fs.mkdirSync(desk, { recursive: true });
  fs.writeFileSync(path.join(desk, "Offline AI.command"), "#!/bin/bash\nexec bash " + q(path.join(k.kit, "mac/start.sh")) + "\n");
  fs.writeFileSync(path.join(desk, "Other Kit.command"), "#!/bin/bash\n# /tmp/other-kit\n");
  const cache = path.join(k.home, "Library/Caches/offline-ai-kit");
  fs.mkdirSync(cache, { recursive: true });
  fs.writeFileSync(path.join(cache, "probe.txt"), "cache\n");
  const agentDir = path.join(k.home, "Library/LaunchAgents");
  fs.mkdirSync(agentDir, { recursive: true });
  const agent = path.join(agentDir, "com.offline-ai.test.plist");
  fs.writeFileSync(agent, "<plist></plist>\n");
  const unitDir = path.join(k.home, ".config/systemd/user");
  fs.mkdirSync(unitDir, { recursive: true });
  const unit = path.join(unitDir, "offline-ai-kit.service");
  fs.writeFileSync(unit, "[Service]\n");
  fs.writeFileSync(path.join(k.home, ".zshrc"), "echo hello\n# >>> offline-ai-kit >>>\nexport PATH=kit\n# <<< offline-ai-kit <<<\necho bye\n");
  fs.mkdirSync(path.join(k.home, ".ollama"), { recursive: true });
  fs.writeFileSync(path.join(k.home, ".ollama/keep.txt"), "system-ollama\n");
  fs.mkdirSync(path.join(k.home, "Applications/Ollama.app"), { recursive: true });
  fs.writeFileSync(path.join(k.home, "Applications/Ollama.app/keep.txt"), "app\n");
  fs.mkdirSync(path.join(k.base, "usr/local/bin"), { recursive: true });
  fs.writeFileSync(path.join(k.base, "usr/local/bin/ollama"), "bin\n");
  const link = path.join(k.home, "offline-ai-kit");
  fs.symlinkSync(k.kit, link);
  fs.writeFileSync(path.join(k.home, "secrets.txt"), "nope\n");
  const receiptDir = path.join(k.home, "Library/Application Support/offline-ai-kit");
  fs.mkdirSync(receiptDir, { recursive: true });
  const receipt = path.join(receiptDir, "receipt-abc123.txt");
  fs.writeFileSync(receipt, [
    "launchagent | " + agent + " | 2026-01-01T00:00:00Z",
    "link | " + link + " | 2026-01-01T00:00:00Z",
    "note | " + path.join(k.home, "secrets.txt") + " | 2026-01-01T00:00:00Z",
    ""
  ].join("\n"));
  const env = probeEnv(k.home);
  env.XDG_CONFIG_HOME = path.join(k.home, ".config");
  const beforeKit = treeHashes(k.kit);
  const beforeHome = treeHashes(k.home);
  const dry = runArgs(path.join(k.kit, "mac/uninstall.sh"), ["--dry-run", "--yes"], env);
  check("dry-run changes nothing",
    dry.status === 0 && dry.out.indexOf("RESULT: UNINSTALL DRY RUN") !== -1 && dry.out.indexOf("RESULT: UNINSTALL OK") === -1 && diffKeys(beforeKit, treeHashes(k.kit)).length === 0 && diffKeys(beforeHome, treeHashes(k.home)).length === 0,
    dry.out + "\nkit " + diffKeys(beforeKit, treeHashes(k.kit)).join(",") + "\nhome " + diffKeys(beforeHome, treeHashes(k.home)).join(","));
  const real = runArgs(path.join(k.kit, "mac/uninstall.sh"), ["--yes"], env);
  const diffs = diffKeys(beforeKit, treeHashes(k.kit));
  const allowed = { "logs/uninstall-mac.log": true, "logs/kiwix.mac.pid": true };
  check("uninstall leaves the drive files and exits 0",
    real.status === 0 && real.out.indexOf("RESULT: UNINSTALL OK") !== -1 && /drive was not changed/.test(real.out) && diffs.every(function (rel) { return allowed[rel]; }) && fs.existsSync(path.join(k.kit, "library/keep.zim")) && fs.existsSync(path.join(k.kit, "library/split.zimaa")) && fs.existsSync(path.join(k.kit, "logs/kiwix.linux.pid")) && fs.existsSync(path.join(k.kit, "VERSION")),
    real.out + "\ndiffs " + diffs.join(","));
  check("uninstall removes this computer's items and continues after a refusal",
    !fs.existsSync(path.join(desk, "Offline AI.command")) && fs.existsSync(path.join(desk, "Other Kit.command")) && !fs.existsSync(cache) && !fs.existsSync(agent) && !fs.existsSync(unit) && !fs.existsSync(receipt) && fs.existsSync(link) && fs.existsSync(path.join(k.home, "secrets.txt")) && /Refused \(on the kit drive\)/.test(real.out) && fs.readFileSync(path.join(k.home, ".zshrc"), "utf8").indexOf("echo bye") !== -1 && fs.readFileSync(path.join(k.home, ".zshrc"), "utf8").indexOf("offline-ai-kit") === -1 && fs.existsSync(path.join(k.home, ".zshrc.bak")) && fs.readFileSync(path.join(k.home, ".ollama/keep.txt"), "utf8") === "system-ollama\n" && fs.existsSync(path.join(k.home, "Applications/Ollama.app/keep.txt")) && fs.existsSync(path.join(k.base, "usr/local/bin/ollama")),
    real.out);
})();

(function driveTools() {
  const k = makeKit();
  fs.writeFileSync(path.join(k.kit, "library/good.zim"), "good");
  fs.writeFileSync(path.join(k.kit, "library/keep.zim"), "keep");
  fs.writeFileSync(path.join(k.kit, "library/checksums/VERIFIED/good.zim"), "hash\n");
  fs.writeFileSync(path.join(k.kit, "library/checksums/VERIFIED/keep.zim"), "hash\n");
  fs.writeFileSync(path.join(k.kit, "library/checksums/PROBE/good.zim"), "probe\n");
  fs.writeFileSync(path.join(k.kit, "library/library.xml"), "<entry>good.zim</entry>\n<entry>keep.zim</entry>\n");
  fs.writeFileSync(path.join(k.kit, "ollama-models/blobs/stay.bin"), "model");
  const env = probeEnv(k.home);
  env.OFFLINE_AI_KIT_ON_STARTUP = "no";
  env.OFFLINE_AI_KIT_LABEL = "OFFLINEAI";
  const script = path.join(k.kit, "mac/drive-tools.sh");
  const wrong = runArgs(script, ["--action", "library", "--files", "good.zim", "--phrase", "WRONG"], env);
  check("wrong phrase shows the dry run and deletes nothing",
    wrong.status === 0 && wrong.out.indexOf("Nothing has been deleted yet.") !== -1 && /Cancelled/.test(wrong.out) && fs.existsSync(path.join(k.kit, "library/good.zim")),
    wrong.out);
  const yes = runArgs(script, ["--action", "library", "--files", "good.zim", "--yes"], env);
  check("--yes without the understand flag refuses",
    yes.status === 1 && /i-understand-this-deletes-data/.test(yes.out) && fs.existsSync(path.join(k.kit, "library/good.zim")),
    yes.out);
  const eraseYes = runArgs(script, ["--action", "erase", "--yes", "--phrase", "OFFLINEAI", "--erase-word", "ERASE"], env);
  check("erase rejects --yes", eraseYes.status === 1 && /not accepted for erase/.test(eraseYes.out) && fs.existsSync(path.join(k.kit, "VERSION")), eraseYes.out);
  const menu = spawnSync("bash", [script], { encoding: "utf8", timeout: 20000, env: env, input: "\n" });
  const menuOut = (menu.stdout || "") + (menu.stderr || "");
  check("Return selects nothing", menu.status === 0 && /Nothing selected/.test(menuOut), menuOut);

  const psProbe = spawnSync("/bin/ps", ["-p", "1", "-o", "command="], { encoding: "utf8" });
  if (psProbe.error && psProbe.error.code === "EPERM") {
    console.log("note  ps is not permitted in this sandbox, so a live service was not started");
    check("drive tools refuses while services are running", /v160_services_running/.test(read("mac/drive-tools.sh")) && /Run STOP/.test(read("mac/drive-tools.sh")));
  } else {
    sleeper = spawn("/usr/bin/python3", ["-c", "import os; os.execv('/bin/sleep', ['kiwix-serve', '60'])"], { stdio: "ignore" });
    fs.writeFileSync(path.join(k.kit, "logs/kiwix.mac.pid"), String(sleeper.pid) + "\n");
    const running = runArgs(script, ["--action", "library", "--files", "good.zim", "--yes", "--i-understand-this-deletes-data"], env);
    check("running services block the delete",
      running.status === 1 && /Nothing has been deleted yet/.test(running.out) && /Run STOP/.test(running.out) && fs.existsSync(path.join(k.kit, "library/good.zim")),
      running.out);
    try { sleeper.kill("SIGKILL"); } catch (e) { /* already gone */ }
    sleeper = null;
  }
  fs.writeFileSync(path.join(k.kit, "library/good.zim"), "good");
  fs.mkdirSync(path.join(k.kit, "library/checksums/VERIFIED"), { recursive: true });
  fs.mkdirSync(path.join(k.kit, "library/checksums/PROBE"), { recursive: true });
  fs.writeFileSync(path.join(k.kit, "library/checksums/VERIFIED/good.zim"), "hash\n");
  fs.writeFileSync(path.join(k.kit, "library/checksums/PROBE/good.zim"), "probe\n");
  fs.writeFileSync(path.join(k.kit, "library/library.xml"), "<entry>good.zim</entry>\n<entry>keep.zim</entry>\n");

  const other = Object.assign({}, env, { OFFLINE_AI_DISK_PARTITIONS: "disk9s2 NTFS-data", OFFLINE_AI_DISK_ID: "disk99" });
  const disk = runArgs(script, ["--action", "erase", "--scope", "disk", "--phrase", "OFFLINEAI", "--erase-word", "ERASE"], other);
  check("whole-disk erase names the other partition and deletes nothing",
    disk.status === 1 && /disk9s2 NTFS-data/.test(disk.out) && fs.existsSync(path.join(k.kit, "library/good.zim")),
    disk.out);
  const capture = path.join(k.base, "prepare.json");
  const partEnv = Object.assign({}, env, {
    OFFLINE_AI_DISK_ID: "disk99",
    OFFLINE_AI_PARTITION_ID: "disk99s2",
    OFFLINE_AI_DISK_PARTITIONS: "",
    OFFLINE_AI_PREPARE_CMD: "cat > " + q(capture)
  });
  const part = runArgs(script, ["--action", "erase", "--scope", "partition", "--phrase", "OFFLINEAI", "--erase-word", "ERASE"], partEnv);
  let captured = "";
  if (fs.existsSync(capture)) captured = fs.readFileSync(capture, "utf8");
  check("partition erase records the prepare JSON and does not erase a disk",
    part.status === 0 && /RESULT: DRIVE TOOLS OK/.test(part.out) && /disk99/.test(captured) && /disk99s2/.test(captured) && /partition/.test(captured) && part.out.indexOf("Erasing the chosen partition") === -1 && fs.existsSync(path.join(k.kit, "library/good.zim")),
    part.out + "\n" + captured);

  const gone = runArgs(script, ["--action", "library", "--files", "good.zim", "--yes", "--i-understand-this-deletes-data"], env);
  const xml = fs.readFileSync(path.join(k.kit, "library/library.xml"), "utf8");
  const manifest = fs.existsSync(path.join(k.kit, "DRIVE-MANIFEST.json")) ? fs.readFileSync(path.join(k.kit, "DRIVE-MANIFEST.json"), "utf8") : "";
  check("library delete removes only the named book and updates the records",
    gone.status === 0 && /RESULT: DRIVE TOOLS OK/.test(gone.out) && !fs.existsSync(path.join(k.kit, "library/good.zim")) && fs.existsSync(path.join(k.kit, "library/keep.zim")) && !fs.existsSync(path.join(k.kit, "library/checksums/VERIFIED/good.zim")) && fs.existsSync(path.join(k.kit, "library/checksums/VERIFIED/keep.zim")) && !fs.existsSync(path.join(k.kit, "library/checksums/PROBE/good.zim")) && xml.indexOf("good.zim") === -1 && xml.indexOf("keep.zim") !== -1 && manifest.indexOf("library/good.zim") === -1 && fs.existsSync(path.join(k.kit, "ollama-models/blobs/stay.bin")),
    gone.out);
})();

(function removeKitFolder() {
  const k = makeKit();
  fs.writeFileSync(path.join(k.kit, "library/gone.zim"), "x");
  const env = probeEnv(k.home);
  env.OFFLINE_AI_KIT_ON_STARTUP = "no";
  const r = runArgs(path.join(k.kit, "mac/drive-tools.sh"), ["--action", "kit", "--phrase", "REMOVE KIT FROM DRIVE"], env);
  check("remove kit from drive deletes only the temp copy",
    !fs.existsSync(k.kit) && fs.existsSync(path.join(root, "VERSION")) && fs.readFileSync(path.join(root, "VERSION"), "utf8").indexOf("1.6.0") !== -1,
    r.out);
})();

(function space() {
  const k = makeKit();
  const before = treeHashes(k.kit);
  const r = bashFile(kitScript(k.kit, [
    "v160_assert_space 10 1000000000",
    "echo RC:$?",
    "v160_assert_space 1 100000000000",
    "echo RC:$?"
  ].join("\n")), probeEnv(k.home));
  check("space check prints the numbers and refuses before a download",
    /Selected 10 GB, free 1 GB → not enough room/.test(r.out) && /Nothing was downloaded/.test(r.out) && /RC:1/.test(r.out) && /Selected 1 GB, free 100 GB → OK/.test(r.out) && /RC:0/.test(r.out) && diffKeys(before, treeHashes(k.kit)).length === 0,
    r.out);
})();

(function migrate() {
  const k = makeKit();
  const book = Buffer.from("library-book-bytes");
  fs.writeFileSync(path.join(k.kit, "library/sample.zim"), book);
  fs.writeFileSync(path.join(k.kit, "library/checksums/VERIFIED/sample.zim"), "ok\n");
  fs.mkdirSync(path.join(k.kit, "mac-library.sparsebundle/books"), { recursive: true });
  fs.writeFileSync(path.join(k.kit, "mac-library.sparsebundle/books/sample.zim"), "bundle-copy");
  const env = probeEnv(k.home);
  env.EASY = "yes";
  const r = bashFile(kitScript(k.kit, "migrate_v160\necho RC:$?"), env);
  check("migration removes the sparsebundle after the probes and leaves the library file",
    r.status === 0 && /RC:0/.test(r.out) && !fs.existsSync(path.join(k.kit, "mac-library.sparsebundle")) && sha(fs.readFileSync(path.join(k.kit, "library/sample.zim"))) === sha(book) && fs.readFileSync(path.join(k.kit, "library/checksums/MIGRATED-1.6"), "utf8").indexOf("1.6") !== -1,
    r.out);

  const old = makeKit();
  fs.mkdirSync(path.join(old.kit, "mac-library.sparsebundle"), { recursive: true });
  fs.writeFileSync(path.join(old.kit, "mac-library.sparsebundle/note.txt"), "stay\n");
  fs.writeFileSync(path.join(old.kit, "library/sample.zim"), "book");
  const oldEnv = probeEnv(old.home);
  oldEnv.TEST_MODE = "yes";
  oldEnv.OFFLINE_AI_TEST = "yes";
  oldEnv.OFFLINE_AI_LIBZIM_TEXT = "libzim 9.5.0";
  const skipped = bashFile(kitScript(old.kit, "migrate_v160\necho RC:$?"), oldEnv);
  check("old programs in test mode delete nothing and write no marker",
    /Nothing was deleted/.test(skipped.out) && fs.existsSync(path.join(old.kit, "mac-library.sparsebundle/note.txt")) && !fs.existsSync(path.join(old.kit, "library/checksums/MIGRATED-1.6")) && sha(fs.readFileSync(path.join(old.kit, "library/sample.zim"))) === sha(Buffer.from("book")),
    skipped.out);
})();

(function checkDrive() {
  const k = makeKit();
  const book = Buffer.from("check-drive-book");
  fs.writeFileSync(path.join(k.kit, "library/book.zim"), book);
  const env = probeEnv(k.home);
  const wrote = bashFile(kitScript(k.kit, "v160_write_manifest\nv160_manifest_clean\necho CLEAN:$?"), env);
  const manifest = fs.readFileSync(path.join(k.kit, "DRIVE-MANIFEST.json"), "utf8");
  const ready = fs.readFileSync(path.join(k.kit, "DRIVE-READY.txt"), "utf8");
  const host = spawnSync("hostname", [], { encoding: "utf8" }).stdout.trim();
  const ident = manifest + "\n" + ready;
  check("manifest has no home, user, or host identity",
    wrote.status === 0 && /CLEAN:0/.test(wrote.out) && ident.indexOf(k.home) === -1 && ident.indexOf("v160tester") === -1 && ident.indexOf(host) === -1 && /No user name/.test(ready),
    wrote.out + "\n" + ready);
  const quick = runArgs(path.join(k.kit, "mac/check-drive.sh"), ["--quick"], env);
  const full = runArgs(path.join(k.kit, "mac/check-drive.sh"), ["--full"], env);
  check("check-drive quick and full pass",
    quick.status === 0 && /RESULT: DRIVE OK/.test(quick.out) && full.status === 0 && /RESULT: DRIVE OK/.test(full.out) && /Checked /.test(full.out),
    quick.out + "\n" + full.out);
  const file = path.join(k.kit, "library/book.zim");
  const bytes = fs.readFileSync(file);
  bytes[0] = bytes[0] === 65 ? 66 : 65;
  fs.writeFileSync(file, bytes);
  const bad = runArgs(path.join(k.kit, "mac/check-drive.sh"), ["--full"], env);
  check("a corrupted byte makes a full check name the file",
    bad.status === 1 && /RESULT: DRIVE INCOMPLETE/.test(bad.out) && /library\/book\.zim/.test(bad.out),
    bad.out);
})();

console.log("note  Test 2 (real exFAT books), Test 6 (Linux reads the same bytes), and Test 18 (offline multi-OS start) stay manual.");
check("manual gates are named in ADVANCED.md", /Tests 2, 6, and 18/.test(read("ADVANCED.md")));
console.log(fails ? fails + " check(s) FAILED" : "All v1.6.0 scriptable checks passed.");
process.exit(fails ? 1 : 0);
