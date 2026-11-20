/* Universal drive: OS/CPU detection, runtime folder selection, missing-program text.
   No downloads. Does not start Ollama, Kiwix, or any server. */
const fs = require("fs");
const path = require("path");
const U = require("../www/universal.js");

const root = path.join(__dirname, "..");
let fails = 0;
function check(name, ok, extra) {
  console.log((ok ? "ok  " : "FAIL") + "  " + name);
  if (!ok) { fails++; if (extra !== undefined) console.log("     " + extra); }
}
function read(rel) { return fs.readFileSync(path.join(root, rel), "utf8"); }

check("windows x64", U.detectPlatform({ os: "win32", arch: "x64" }) === "windows-x64");
check("windows amd64", U.detectPlatform({ os: "Windows_NT", arch: "AMD64" }) === "windows-x64");
check("windows arm is not the x64 folder", U.detectPlatform({ os: "windows", arch: "arm64" }) === "windows-arm64");
check("32-bit windows", U.detectPlatform({ os: "win32", arch: "x86" }) === "windows-x86");
check("apple chip", U.detectPlatform({ os: "darwin", arch: "arm64" }) === "mac-arm64");
check("rosetta still counts as apple chip", U.detectPlatform({ os: "darwin", arch: "x86_64", hwArm64: true }) === "mac-arm64");
check("intel mac", U.detectPlatform({ os: "mac", arch: "x86_64" }) === "mac-x64");
check("linux x64", U.detectPlatform({ os: "linux", arch: "amd64" }) === "linux-x64");
check("linux arm", U.detectPlatform({ os: "linux", arch: "aarch64" }) === "linux-arm64");
check("unknown os", U.detectPlatform({ os: "freebsd", arch: "x64" }) === "");

U.PLATFORM_IDS.forEach(function (id) {
  check("folder " + id, U.runtimeFolder(id) === "runtime/" + id);
});

var fresh = U.selectRuntime({
  platformId: "linux-arm64",
  files: ["runtime/linux-arm64/ollama/bin/ollama", "runtime/linux-arm64/kiwix/kiwix-tools_linux-aarch64/kiwix-serve"]
});
check("selects linux-arm64", fresh.missing === false && fresh.ollamaDir === "runtime/linux-arm64/ollama" && fresh.kiwixDir === "runtime/linux-arm64/kiwix");

var win = U.selectRuntime({
  platformId: "windows-x64",
  files: ["runtime/windows-x64/ollama/ollama.exe", "runtime/windows-x64/kiwix/kiwix-tools/kiwix-serve.exe"]
});
check("selects windows-x64", win.missing === false && win.ollamaDir === "runtime/windows-x64/ollama");

var legacy = U.selectRuntime({
  platformId: "windows-x64",
  files: ["runtime/ollama/ollama.exe", "runtime/kiwix/kiwix-serve.exe"]
});
check("legacy windows folders still count", legacy.missing === false && legacy.ollamaDir === "runtime/ollama" && legacy.kiwixDir === "runtime/kiwix");

var prefer = U.selectRuntime({
  platformId: "mac-arm64",
  files: [
    "runtime/mac-arm64/ollama/ollama",
    "runtime/mac-arm64/kiwix/kiwix-serve",
    "runtime/mac-ollama/ollama",
    "runtime/mac-kiwix/kiwix-serve"
  ]
});
check("new mac folder wins over the old one", prefer.ollamaDir === "runtime/mac-arm64/ollama" && prefer.kiwixDir === "runtime/mac-arm64/kiwix");

var intel = U.selectRuntime({
  platformId: "mac-x64",
  channel: "pinned",
  files: ["runtime/mac-ollama-v0.12.9/bin/ollama", "runtime/mac-kiwix-intel/kiwix-tools/kiwix-serve"]
});
check("intel mac can use the older folders", intel.missing === false && intel.ollamaDir === "runtime/mac-ollama-v0.12.9" && intel.kiwixDir === "runtime/mac-kiwix-intel");

var miss = U.selectRuntime({ platformId: "mac-x64", files: ["runtime/linux-x64/ollama/bin/ollama"] });
check("missing intel mac is reported", miss.missing === true);
check("missing message names the folder", /runtime\/mac-x64/.test(miss.message), miss.message);
check("missing message says how to add programs", /All computers \(universal drive\)/.test(miss.message) && /This computer only/.test(miss.message) && /internet/.test(miss.message));
check("linux missing message names SETUP-LINUX", /bash SETUP-LINUX\.sh/.test(U.missingProgramMessage("linux-arm64")));
check("windows arm message", /runtime\/windows-x64/.test(U.missingProgramMessage("windows-arm64")) && /Windows on ARM/.test(U.missingProgramMessage("windows-arm64")));
check("macos 12 does not require ollama", U.selectRuntime({ platformId: "mac-arm64", channel: "none", files: ["runtime/mac-arm64/kiwix/kiwix-serve"] }).missing === false);

check("extra GB windows", U.universalExtraGB("windows-x64") === 5.5);
check("extra GB mac", U.universalExtraGB("mac-arm64") === 7 && U.universalExtraGB("mac-x64") === 7);
check("extra GB linux", U.universalExtraGB("linux-x64") === 7 && U.universalExtraGB("linux-arm64") === 7);
check("allowance is 8 GB", U.UNIVERSAL_PROGRAM_GB === 8);

const ps = read("scripts/common.ps1");
const prog = read("scripts/programs.ps1");
const sh = read("mac/lib.sh");
const setupPs = read("scripts/setup.ps1");
const setupSh = read("mac/setup.sh");
const sentence = "This drive does not have the Offline AI programs for";
check("powershell says the program folder is missing", ps.indexOf(sentence) >= 0);
check("bash says the program folder is missing", sh.indexOf(sentence) >= 0);
check("both mention universal drive and this computer only", /All computers \(universal drive\)/.test(ps) && /This computer only/.test(ps) && /All computers \(universal drive\)/.test(sh) && /This computer only/.test(sh));
U.PLATFORM_IDS.forEach(function (id) {
  check("scripts name " + id, prog.indexOf(id) >= 0 && sh.indexOf(id) >= 0);
});
check("windows flag -Universal", /-Universal/.test(setupPs));
check("mac and linux flag --universal", /--universal/.test(setupSh));
check("wizard is 8 steps", /\$WizardSteps = 8/.test(setupPs) && /WIZARD_STEPS=8/.test(setupSh));
check("summary prints the extra GB", /Extra programs:/.test(setupPs) && /Extra programs:/.test(setupSh));
check("no new symlinks under runtime", !/SymbolicLink|ln -s/.test(prog) && !/ln -s/.test(sh));
check("quarantine is cleared", /com\.apple\.quarantine/.test(sh));
check("execute bit still stages a local copy", /stage_program_tree/.test(sh));
check("linux ollama accepts the current tar.zst name", /tar\.zst/.test(sh) && /ollama-linux-amd64\.tgz/.test(sh) && /ollama-linux-arm64\.tgz/.test(sh));
check("version is 1.3.0", read("VERSION").trim() === "1.3.0" && /"1\.3\.0"/.test(read("www/version.js")));

if (fails) { console.log(fails + " failed"); process.exit(1); }
console.log("all universal checks passed");
