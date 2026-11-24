/* Uninstaller checks. No downloads. Never deletes this checkout or a real drive.
   A real delete runs only against a temporary copy. */
"use strict";
const fs = require("fs");
const os = require("os");
const path = require("path");
const { spawnSync } = require("child_process");

const root = path.join(__dirname, "..");
const repo = fs.realpathSync(root);
const script = path.join(root, "mac/uninstall.sh");
let fails = 0;
function check(name, ok, extra) {
  console.log((ok ? "ok  " : "FAIL") + "  " + name);
  if (!ok) {
    fails++;
    if (extra !== undefined) console.log("     " + (typeof extra === "string" ? extra : JSON.stringify(extra)));
  }
}
function read(rel) { return fs.readFileSync(path.join(root, rel), "utf8"); }
function exists(rel) { return fs.existsSync(path.join(root, rel)); }

function run(file, args, opts) {
  const r = spawnSync("bash", [file].concat(args), Object.assign({
    encoding: "utf8",
    timeout: 60000,
    input: ""
  }, opts || {}));
  return { status: r.status, out: (r.stdout || "") + (r.stderr || ""), error: r.error };
}

function outsideRepo(dir) {
  const resolved = fs.realpathSync(dir);
  if (resolved === repo || resolved.indexOf(repo + path.sep) === 0 || repo.indexOf(resolved + path.sep) === 0) {
    throw new Error("refusing to touch the checkout: " + resolved);
  }
  return resolved;
}

function makeKit() {
  const base = outsideRepo(fs.mkdtempSync(path.join(os.tmpdir(), "offline-ai-uninstall-")));
  const kit = path.join(base, "Offline AI Kit");
  fs.mkdirSync(path.join(kit, "mac"), { recursive: true });
  fs.mkdirSync(path.join(kit, "library"), { recursive: true });
  fs.writeFileSync(path.join(kit, "VERSION"), "1.6.0\n");
  fs.writeFileSync(path.join(kit, "library", "marker.txt"), "keep-until-uninstall\n");
  fs.copyFileSync(script, path.join(kit, "mac/uninstall.sh"));
  fs.copyFileSync(path.join(root, "mac/lib.sh"), path.join(kit, "mac/lib.sh"));
  fs.copyFileSync(path.join(root, "mac/v160.sh"), path.join(kit, "mac/v160.sh"));
  fs.writeFileSync(path.join(base, "sibling.txt"), "leave this\n");
  const other = path.join(base, "Offline AI Kit-other");
  fs.mkdirSync(other);
  fs.writeFileSync(path.join(other, "keep.txt"), "other folder\n");
  const home = path.join(base, "home");
  const desk = path.join(home, "Desktop");
  const cache = path.join(home, "Library", "Caches", "offline-ai-kit");
  fs.mkdirSync(desk, { recursive: true });
  fs.mkdirSync(cache, { recursive: true });
  fs.writeFileSync(path.join(cache, "probe.txt"), "cache\n");
  outsideRepo(kit);
  return { base: base, kit: kit, home: home, desk: desk, cache: cache, other: other };
}

function envFor(home, extra) {
  const env = Object.assign({}, process.env, { HOME: home }, extra || {});
  delete env.XDG_CACHE_HOME;
  delete env.XDG_DESKTOP_DIR;
  if (!extra || !extra.OFFLINE_AI_OS) delete env.OFFLINE_AI_OS;
  return env;
}

function cleanup(base) {
  spawnSync("python3", ["-c", "import shutil,sys; shutil.rmtree(sys.argv[1], ignore_errors=True)", base], { encoding: "utf8" });
}

["mac/uninstall.sh", "linux/uninstall.sh", "UNINSTALL-OFFLINE-AI-MAC.command", "UNINSTALL-OFFLINE-AI-LINUX.sh",
  "Click these/6 Uninstall/Mac.command", "Click these/6 Uninstall/Linux.sh"].forEach(function (rel) {
  const r = spawnSync("bash", ["-n", path.join(root, rel)], { encoding: "utf8" });
  check("bash -n " + rel, r.status === 0, (r.stdout || "") + (r.stderr || ""));
});

check("folder guide explains uninstall", /6 Uninstall/.test(read("FOLDER-GUIDE.txt")) && /type YES/.test(read("FOLDER-GUIDE.txt")) && /Do not delete/.test(read("FOLDER-GUIDE.txt")));
check("start here explains uninstall", /6 Uninstall/.test(read("START-HERE.txt")) && /type YES/.test(read("START-HERE.txt")));
check("readme explains uninstall", /6 Uninstall/.test(read("README.md")) && /type YES/.test(read("README.md")));
check("advanced explains uninstall", /6 Uninstall/.test(read("ADVANCED.md")) && /drive is not changed/.test(read("ADVANCED.md")) && /Before v1\.6\.0/.test(read("ADVANCED.md")));
check("what this does asks first", /type YES/.test(read("Click these/6 Uninstall/WHAT THIS DOES.txt")) && /not erased/.test(read("Click these/6 Uninstall/WHAT THIS DOES.txt")));
["UNINSTALL.bat", "UNINSTALL-OFFLINE-AI-MAC.command", "UNINSTALL-OFFLINE-AI-LINUX.sh"].forEach(function (name) {
  check("copy list includes " + name, read("mac/setup.sh").indexOf(name) !== -1 && read("scripts/setup.ps1").indexOf(name) !== -1);
});
const ps = read("scripts/uninstall.ps1");
check("windows script refuses a whole drive", /whole drive/.test(ps) && /-not \$DryRun/.test(ps) && /UNINSTALL DRY RUN/.test(ps) && /Test-SameOrUnder/.test(ps) && /USERPROFILE/.test(ps));

function refused(args, needle) {
  const r = run(script, args);
  check("refuses " + needle, r.status === 1 && r.out.indexOf("Refused:") === 0 && r.out.indexOf(needle) !== -1 && r.out.indexOf("RESULT: UNINSTALL OK") === -1, r.out);
  return r;
}
refused(["--dry-run", "--root", "/"], "not a kit folder");
refused(["--dry-run", "--root", "/tmp"], "not a kit folder");
refused(["--dry-run", "--root", "/Volumes/OFFLINEAI"], "whole drive");
refused(["--dry-run", "--root", process.env.HOME], "home folder");
refused(["--dry-run", "--root"], "needs a folder");
refused(["--nope"], "unknown option");

const offlineAi = "/Volumes/OfflineAI";
const volumeWasThere = fs.existsSync(offlineAi);
refused(["--dry-run", "--root", offlineAi], "whole drive");
check("real volume was not removed", !volumeWasThere || fs.existsSync(offlineAi));

const dry = run(script, ["--dry-run"]);
check("dry-run of this checkout", dry.status === 0 && dry.out.indexOf("RESULT: UNINSTALL DRY RUN") !== -1 && dry.out.indexOf(repo) !== -1 && dry.out.indexOf("RESULT: UNINSTALL OK") === -1, dry.out);
check("checkout still present", exists("VERSION") && exists("mac/lib.sh"));

const sample = makeKit();
try {
  const looked = run(script, ["--dry-run", "--root", sample.kit]);
  check("dry-run of another folder", looked.status === 0 && looked.out.indexOf(sample.kit) !== -1 && looked.out.indexOf("RESULT: UNINSTALL DRY RUN") !== -1, looked.out);
  check("dry-run deleted nothing", fs.existsSync(path.join(sample.kit, "library", "marker.txt")) && fs.existsSync(path.join(sample.base, "sibling.txt")));

  const blocked = run(script, ["--yes", "--root", sample.kit]);
  check("--yes cannot target another folder", blocked.status === 1 && blocked.out.indexOf("Refused:") === 0 && fs.existsSync(sample.kit), blocked.out);

  const both = run(script, ["--yes", "--dry-run", "--root", sample.kit]);
  check("dry-run wins", both.status === 0 && both.out.indexOf("RESULT: UNINSTALL DRY RUN") !== -1 && fs.existsSync(path.join(sample.kit, "VERSION")), both.out);

  fs.unlinkSync(path.join(sample.kit, "VERSION"));
  const missing = run(script, ["--dry-run", "--root", sample.kit]);
  check("a folder without VERSION is refused", missing.status === 1 && missing.out.indexOf("does not look like") !== -1 && fs.existsSync(path.join(sample.kit, "library", "marker.txt")), missing.out);
  fs.writeFileSync(path.join(sample.kit, "VERSION"), "1.6.0\n");

  const copy = path.join(sample.kit, "mac/uninstall.sh");
  const cancelled = run(copy, [], { input: "no\n", env: envFor(sample.home) });
  check("anything but YES deletes nothing", cancelled.status === 0 && cancelled.out.indexOf("Nothing was deleted.") !== -1 && fs.existsSync(sample.kit), cancelled.out);
  const lower = run(copy, [], { input: "yes\n", env: envFor(sample.home) });
  check("lowercase yes deletes nothing", lower.status === 0 && lower.out.indexOf("Nothing was deleted.") !== -1 && fs.existsSync(path.join(sample.kit, "library", "marker.txt")), lower.out);

  const kitReal = fs.realpathSync(sample.kit);
  const otherReal = fs.realpathSync(sample.other);
  fs.writeFileSync(path.join(sample.desk, "Offline AI.command"), "#!/bin/bash\nexec bash \"" + kitReal + "/START-OFFLINE-AI-MAC.command\"\n");
  fs.writeFileSync(path.join(sample.desk, "Keep Me.command"), "#!/bin/bash\nexec bash \"" + otherReal + "/START\"\n");
  const gone = run(copy, ["--yes"], { env: envFor(sample.home) });
  check("temp copy uninstalls this computer only", gone.status === 0 && gone.out.indexOf("RESULT: UNINSTALL OK") !== -1 && gone.out.indexOf("The drive was not changed") !== -1, gone.out);
  check("the kit folder stays", fs.existsSync(path.join(sample.kit, "library", "marker.txt")) && fs.readFileSync(path.join(sample.base, "sibling.txt"), "utf8") === "leave this\n" && fs.existsSync(path.join(sample.other, "keep.txt")));
  check("matching shortcut is gone", !fs.existsSync(path.join(sample.desk, "Offline AI.command")));
  check("a different shortcut stays", fs.existsSync(path.join(sample.desk, "Keep Me.command")));
  check("program cache is gone", !fs.existsSync(sample.cache));
} finally {
  cleanup(sample.base);
}

const prefix = makeKit();
try {
  fs.writeFileSync(path.join(prefix.desk, "Offline AI.command"), "#!/bin/bash\nexec bash \"" + fs.realpathSync(prefix.other) + "/START-OFFLINE-AI-MAC.command\"\n");
  const kept = run(path.join(prefix.kit, "mac/uninstall.sh"), ["--yes"], { env: envFor(prefix.home) });
  check("a longer folder name is not the shortcut", kept.status === 0 && fs.existsSync(path.join(prefix.desk, "Offline AI.command")) && fs.existsSync(path.join(prefix.kit, "VERSION")) && fs.existsSync(path.join(prefix.other, "keep.txt")), kept.out);
} finally {
  cleanup(prefix.base);
}

const linux = makeKit();
try {
  const kitReal = fs.realpathSync(linux.kit);
  const desktop = path.join(linux.desk, "offline-ai-kit.desktop");
  fs.writeFileSync(desktop, "[Desktop Entry]\nExec=bash \"" + kitReal + "/START-OFFLINE-AI-LINUX.sh\"\nPath=" + kitReal + "\n");
  fs.writeFileSync(path.join(linux.desk, "Offline AI.command"), "#!/bin/bash\nexec bash \"" + kitReal + "/START-OFFLINE-AI-MAC.command\"\n");
  const removed = run(path.join(linux.kit, "mac/uninstall.sh"), ["--yes"], { env: envFor(linux.home, { OFFLINE_AI_OS: "linux" }) });
  check("linux shortcut is removed", removed.status === 0 && !fs.existsSync(desktop), removed.out);
  check("mac shortcut stays when removing the linux one", fs.existsSync(path.join(linux.desk, "Offline AI.command")));
  check("linux run left the kit and the other folder", fs.existsSync(path.join(linux.other, "keep.txt")) && fs.existsSync(path.join(linux.kit, "VERSION")));
} finally {
  cleanup(linux.base);
}

check("checkout survived the tests", exists("VERSION") && exists("mac/uninstall.sh") && exists("mac/lib.sh") && read("VERSION").trim() === "1.6.0");

if (fails) { console.log(fails + " failed"); process.exit(1); }
console.log("all uninstall checks passed");
