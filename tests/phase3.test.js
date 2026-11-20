/* Phase 3: offline maps, Linux launchers, USB / exFAT rules.
   No downloads. Does not start Ollama, Kiwix, or any server. */
const fs = require("fs");
const os = require("os");
const path = require("path");
const { execFileSync } = require("child_process");
const M = require("../www/maps.js");

const root = path.join(__dirname, "..");
let fails = 0;
function check(name, ok, extra) {
  console.log((ok ? "ok  " : "FAIL") + "  " + name);
  if (!ok) { fails++; if (extra !== undefined) console.log("     " + (typeof extra === "string" ? extra : JSON.stringify(extra))); }
}
function read(rel) { return fs.readFileSync(path.join(root, rel), "utf8"); }
function exists(rel) { return fs.existsSync(path.join(root, rel)); }

function parseCatalog(text) {
  return text.split(/\r?\n/).map(function (line) {
    const t = line.trim();
    if (!t || t.charAt(0) === "#") return null;
    const f = t.split("|");
    if (f.length < 6) return null;
    return { id: f[0].trim(), dir: f[1].trim(), prefix: f[2].trim(), gb: Number(f[3]), group: f[4].trim(), about: f[5].trim() };
  }).filter(Boolean);
}

const maps = parseCatalog(read("catalog/maps.txt"));
const byId = {};
maps.forEach(function (e) { byId[e.id] = e; });
check("maps catalog parses", maps.length >= 7, maps.length);
["vancouver-island", "british-columbia", "alberta"].forEach(function (id) {
  check(id + " is an easy Canada alias", byId[id] && byId[id].prefix === "maps_en_canada" && byId[id].group === "Easy" && /10/.test(String(byId[id].gb)) && /Canada/i.test(byId[id].about), byId[id]);
});
check("broader regions are real separate prefixes",
  byId["united-states"].prefix === "maps_en_united-states-of-america" &&
  byId["north-america"].prefix === "maps_en_north-america" &&
  byId.europe.prefix === "maps_en_europe" &&
  byId.world.prefix === "maps_en_all");
const three = M.dedupeByPrefix([byId["vancouver-island"], byId["british-columbia"], byId.alberta]);
check("three Canadian choices are one download", three.length === 1 && three[0].prefix === "maps_en_canada");
const allFiles = M.dedupeByPrefix(maps);
check("all regions dedupe to five files", allFiles.length === 5, allFiles.map(function (e) { return e.prefix; }));

const listing = [
  '<a href="maps_en_nordics_2026-08.zim">a</a>',
  '<a href="maps_en_nordics_2026-08a.zim">b</a>',
  '<a href="maps_en_nordics_2026-09.zim">c</a>',
  '<a href="maps_en_canada_2026-06.zim">d</a>',
  '<a href="maps_en_canada_2025-11.zim">e</a>'
].join("\n");
check("letter suffix: 2026-09 beats 2026-08a and 2026-08", M.pickNewestZim(listing, "maps_en_nordics") === "maps_en_nordics_2026-09.zim");
check("canada resolver ignores other prefixes", M.pickNewestZim(listing, "maps_en_canada") === "maps_en_canada_2026-06.zim");
check("08a beats 08 when it is the newest", M.pickNewestZim(listing.replace("2026-09", "2026-07"), "maps_en_nordics") === "maps_en_nordics_2026-08a.zim");

check("map link stays on the library host", M.mapHref("http://192.168.1.20:8091", "maps_en_canada_2026-06.zim") === "http://192.168.1.20:8091/content/maps_en_canada_2026-06/");
check("map link on this computer uses the library base", M.mapHref("http://127.0.0.1:8090/", "maps_en_canada_2026-06.zim") === "http://127.0.0.1:8090/content/maps_en_canada_2026-06/");

["FAT32", "fat32", "vfat", "msdos", "MS-DOS FAT32", "FAT"].forEach(function (k) {
  check("blocks " + k, M.fat32Blocked(k) === true);
});
["exFAT", "ExFAT", "NTFS", "APFS", "ext4", "fuseblk"].forEach(function (k) {
  check("allows " + k, M.fat32Blocked(k) === false);
});

check("ip route src is the computer", M.lanIpFromIpRoute("1.1.1.1 via 192.168.1.1 dev wlan0 src 192.168.1.50 uid 1000") === "192.168.1.50");
check("ip route ignores a loopback src", M.lanIpFromIpRoute("1.1.1.1 via 10.0.0.1 dev lo src 127.0.0.1") === "");
check("ip route with no src", M.lanIpFromIpRoute("default via 192.168.1.1 dev eth0") === "");

const setupPs = read("scripts/setup.ps1");
const setupSh = read("mac/setup.sh");
check("Windows wizard is 7 steps with a maps step", /\$WizardSteps = 7/.test(setupPs) && /Offline maps \(optional\)/.test(setupPs));
check("Mac/Linux wizard is 7 steps with a maps step", /WIZARD_STEPS=7/.test(setupSh) && /Offline maps \(optional\)/.test(setupSh));
check("Easy Install path does not ask for maps", /Easy Install never reaches this/.test(setupPs) && /Easy Install never reaches this/.test(setupSh));
["EASY-INSTALL (Windows).bat", "EASY-INSTALL (Mac).command", "EASY-INSTALL (Linux).sh"].forEach(function (f) {
  const t = read(f);
  check(f + " does not pass a maps flag", !/--maps|-Maps/.test(t) && /[Ee]asy/.test(t));
});
check("chat page links to the maps page", /id="mapLink"[^>]*href="maps.html"/.test(read("www/chat.html")));
const wwwBad = ["maps.html", "maps.js", "maps-index.js"].filter(function (f) {
  const urls = read("www/" + f).match(/https?:\/\/[^\s"'<>)]+/g) || [];
  return urls.some(function (u) {
    return !/^http:\/\/(127\.0\.0\.1|localhost)/.test(u);
  });
});
check("maps pages have no external URLs", wwwBad.length === 0, wwwBad);

["EASY-INSTALL (Linux).sh", "SETUP-LINUX.sh", "START-OFFLINE-AI-LINUX.sh", "STOP-OFFLINE-AI-LINUX.sh", "STATUS-LINUX.sh",
 "linux/lib.sh", "linux/setup.sh", "linux/start.sh", "linux/stop.sh", "linux/status.sh", "linux/add-maps.sh"].forEach(function (f) {
  check("exists " + f, exists(f));
});
const linuxBlob = ["linux/lib.sh", "linux/setup.sh", "linux/start.sh", "mac/lib.sh"].map(read).join("\n");
check("Linux names kiwix-tools_linux and ollama-linux", /kiwix-tools_linux-x86_64/.test(linuxBlob) && /kiwix-tools_linux-aarch64/.test(linuxBlob) && /ollama-linux-amd64\.tgz/.test(linuxBlob) && /ollama-linux-arm64\.tgz/.test(linuxBlob));
check("Linux LAN lookup uses ip route src", /ip route get 1\.1\.1\.1/.test(linuxBlob) && /src/.test(read("mac/lib.sh")));
check("musl is detected and not the default glibc name", /LINUX_LIBC=glibc/.test(read("mac/lib.sh")) && /ldd --version/.test(read("mac/lib.sh")) && /musl/.test(read("linux/lib.sh")));

const bindBlob = read("scripts/common.ps1") + "\n" + read("mac/lib.sh") + "\n" + read("scripts/serve-chat.ps1") + "\n" + read("mac/serve-chat.py");
check("Kiwix bind stays on 127.0.0.1", /\$addr = '127\.0\.0\.1'/.test(read("scripts/common.ps1")) && /addr=127\.0\.0\.1/.test(read("mac/lib.sh")));
check("Ollama host stays on 127.0.0.1", /OLLAMA_HOST\s*=\s*"127\.0\.0\.1:/.test(read("scripts/common.ps1")) && /OLLAMA_HOST="127\.0\.0\.1:/.test(read("mac/lib.sh")));
check("share exposes only the chat port variable", /bind = 'any'/.test(read("scripts/common.ps1")) && /bind=0\.0\.0\.0/.test(read("mac/lib.sh")));

check("resolver accepts a letter suffix in PowerShell", /\\d\{4\}-\\d\{2\}\[a-z\]\?/.test(read("scripts/common.ps1")));
check("resolver accepts a letter suffix in bash", /\[0-9\]\{4\}-\[0-9\]\{2\}\[a-z\]\?/.test(read("mac/lib.sh")));
check("FAT32 names are refused in both libraries", /fat32/.test(read("scripts/common.ps1")) && /vfat/.test(read("scripts/common.ps1")) && /msdos/.test(read("scripts/common.ps1")) && /fat32\|vfat\|msdos/.test(read("mac/lib.sh")));
check("exFAT mmap limit is explained for macOS", /mmap/.test(read("mac/lib.sh")) && /4 GB/.test(read("README.md")) && /exFAT/.test(read("START-HERE.txt")));
check("USB section is in the README and START-HERE", /Running from a USB drive/.test(read("README.md")) && /RUNNING FROM A USB DRIVE/.test(read("START-HERE.txt")));
check("version is 1.2.0", read("VERSION").trim() === "1.2.0" && /"1\.2\.0"/.test(read("www/version.js")));

const vm = require("vm");
const html = read("www/maps.html");
const re = /<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/g;
let m, n = 0, bad = "";
while ((m = re.exec(html))) {
  n++;
  try { new vm.Script("(function(){" + m[1] + "\n})", { filename: "maps.html" }); }
  catch (e) { bad += e.message; }
}
check("maps.html inline script parses", n === 1 && !bad, bad);

// Real Resolve-LatestZim, against a fixture. Does not download.
const fixture = path.join(os.tmpdir(), "oaik-zim-listing.html");
fs.writeFileSync(fixture, listing);
const ps1 = path.join(os.tmpdir(), "oaik-phase3-resolve.ps1");
const kit = root.replace(/'/g, "''");
const fix = fixture.replace(/'/g, "''");
fs.writeFileSync(ps1, [
  "$ErrorActionPreference = 'Stop'",
  ". '" + kit + "\\scripts\\common.ps1'",
  "$env:OFFLINE_AI_ZIM_LISTING = '" + fix + "'",
  "$z = Resolve-LatestZim ([pscustomobject]@{ Id='n'; Dir='zim/maps'; Prefix='maps_en_nordics'; About='n' })",
  "Write-Output $z.File",
  "$c = Resolve-LatestZim ([pscustomobject]@{ Id='c'; Dir='zim/maps'; Prefix='maps_en_canada'; About='c' })",
  "Write-Output $c.File",
  "$rows = @(Get-MapCatalog)",
  "Write-Output ('COUNT ' + $rows.Count)",
  "$pick = @(Get-MapDownloadSet @(Resolve-MapIds 'vancouver-island,british-columbia,alberta' $rows))",
  "Write-Output ('FILES ' + $pick.Count + ' ' + $pick[0].Prefix)"
].join("\r\n"));
try {
  const out = execFileSync("powershell.exe", ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", ps1], { encoding: "utf8", timeout: 60000 });
  const lines = out.split(/\r?\n/).map(function (s) { return s.trim(); }).filter(Boolean);
  check("PowerShell resolver picks 2026-09 and canada 2026-06", lines.indexOf("maps_en_nordics_2026-09.zim") >= 0 && lines.indexOf("maps_en_canada_2026-06.zim") >= 0, lines);
  check("PowerShell dedupes the Canada aliases", lines.some(function (l) { return l === "FILES 1 maps_en_canada"; }), lines);
} catch (e) {
  check("PowerShell resolver picks 2026-09 and canada 2026-06", false, (e.stdout || "") + (e.stderr || e.message));
  check("PowerShell dedupes the Canada aliases", false, "skipped");
}

function bashExe() {
  const candidates = ["bash", "C:\\\\Program Files\\\\Git\\\\bin\\\\bash.exe", "C:\\\\Program Files\\\\Git\\\\usr\\\\bin\\\\bash.exe"];
  for (let i = 0; i < candidates.length; i++) {
    try { execFileSync(candidates[i], ["--version"], { stdio: "ignore" }); return candidates[i]; } catch (e) { /* next */ }
  }
  return "";
}
const bash = bashExe();
if (!bash) {
  check("bash resolver (bash not installed here)", true);
} else {
  const sh = [
    "export OFFLINE_AI_OS=linux",
    "export OFFLINE_AI_ZIM_LISTING=" + JSON.stringify(fixture),
    ". " + JSON.stringify(path.join(root, "mac/lib.sh").replace(/\\/g, "/")),
    "resolve_latest_zim zim/maps maps_en_nordics",
    "resolve_latest_zim zim/maps maps_en_canada",
    "printf '%s\\n' \"$KIT_OS $LINUX_OLLAMA_ASSET $LINUX_KIWIX_ARCH\"",
    "lan_ip() { :; }",
    "printf '%s\\n' \"$(printf '%s' '1.1.1.1 via 10.0.0.1 dev eth0 src 10.1.2.3' | grep -oE 'src[[:space:]]+[0-9.]+' | awk '{print $2}')\""
  ].join("\n");
  const shFile = path.join(os.tmpdir(), "oaik-phase3-resolve.sh");
  fs.writeFileSync(shFile, sh.replace(/\r\n/g, "\n"), { encoding: "utf8" });
  try {
    const out = execFileSync(bash, [shFile.replace(/\\/g, "/")], { encoding: "utf8", timeout: 60000 });
    const lines = out.split(/\r?\n/).map(function (s) { return s.trim(); }).filter(Boolean);
    check("bash resolver picks 2026-09 and canada 2026-06", lines[0] === "maps_en_nordics_2026-09.zim" && lines[1] === "maps_en_canada_2026-06.zim", lines);
    check("OFFLINE_AI_OS=linux selects linux assets", /^linux ollama-linux-(amd64|arm64)\.tgz (x86_64|aarch64)$/.test(lines[2] || ""), lines);
  } catch (e) {
    check("bash resolver picks 2026-09 and canada 2026-06", false, (e.stdout || "") + "\n" + (e.stderr || e.message));
    check("OFFLINE_AI_OS=linux selects linux assets", false, "skipped");
  }
  ["mac/lib.sh", "mac/setup.sh", "mac/start.sh", "mac/add-maps.sh", "linux/setup.sh", "linux/lib.sh"].forEach(function (f) {
    try {
      execFileSync(bash, ["-n", path.join(root, f).replace(/\\/g, "/")], { stdio: "pipe" });
      check("bash -n " + f, true);
    } catch (e) {
      check("bash -n " + f, false, (e.stderr || e.message || "").toString());
    }
  });
}

console.log(fails ? fails + " check(s) FAILED" : "All checks passed.");
process.exit(fails ? 1 : 0);
