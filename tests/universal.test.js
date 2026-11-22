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

check("extra GB windows", U.universalExtraGB("windows-x64") === 11.5);
check("extra GB mac", U.universalExtraGB("mac-arm64") === 13 && U.universalExtraGB("mac-x64") === 13);
check("extra GB linux", U.universalExtraGB("linux-x64") === 13 && U.universalExtraGB("linux-arm64") === 13);
check("allowance is 14 GB", U.UNIVERSAL_PROGRAM_GB === 14);

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
check("powershell allowance is 14", /\$script:UniversalProgramGB = 14\.0/.test(ps));
check("bash allowance is 14", /UNIVERSAL_PROGRAM_GB=14\.0/.test(sh));

const zstdPins = [
  "d81be8618553d7d658e09da669ffd68ec76d8095161a590c9b8a1a99fce67ca8",
  "9848858f7332effb071818f282b3ac3052085e3dafa9ae09f0060b7e211a80dc",
  "190c196b46883a234238d9c52a211c1494df79bb170fbe30c6fc22639d5d4731",
  "4fa2386a975c2120f91f3103bd4268a19a341cb9063417f3829018e94f28c8c6",
  "8765d39af6a89f5b7b05854d08027e739c8f2245c4488c8365b3ddaf5cdbcf28",
  "ef983e169862f9d32652c9017e500052bd31ce5a2c7cb16bccdb71bcfa90c884"
];
zstdPins.forEach(function (pin) {
  check("zstd pin " + pin.slice(0, 8), sh.indexOf(pin) >= 0 && prog.indexOf(pin) >= 0);
});
check("checked zst download is kept", /Left the checked download in place/.test(sh) && /Left the checked download in place/.test(prog));
const oneSh = sh.slice(sh.indexOf("install_one_ollama()"), sh.indexOf("install_darwin_copies()"));
const onePs = prog.slice(prog.indexOf("function Install-OllamaAsset"), prog.indexOf("function Install-DarwinOllamaCopies"));
check("bash reuses a checked ollama archive", oneSh.indexOf("Using the checked download already on the drive") >= 0 && oneSh.indexOf("download_resumable") > oneSh.indexOf("Using the checked download already on the drive"));
check("powershell reuses a checked ollama archive", onePs.indexOf("Using the checked download already on the drive") >= 0 && onePs.indexOf("Save-ResumableFile") > onePs.indexOf("Using the checked download already on the drive"));
check("a failed platform does not stop the others", /Some programs for other computers were not installed/.test(sh) && /Some programs for other computers were not installed/.test(prog));
check("installed programs stay put", /Programs that installed were left in place/.test(sh) && /Programs that installed were left in place/.test(prog));

const uniSh = sh.slice(sh.indexOf("install_universal_programs()"), sh.indexOf("install_portable_ollama()"));
check("linux arm is still attempted if linux x64 fails", /linux-x64\/ollama/.test(uniSh) && /linux-arm64\/ollama/.test(uniSh) && !/\|\| return 1/.test(uniSh));
const uniPs = prog.slice(prog.indexOf("function Install-UniversalPrograms"));
check("windows universal install continues", /linux-x64\/ollama/.test(uniPs) && /linux-arm64\/ollama/.test(uniPs) && /\$failed \+= \$step\.Name/.test(uniPs));

check("test mode does not count extra programs", /not downloaded in test mode\./.test(setupSh) && /not downloaded in test mode\./.test(setupPs));
check("test mode leaves the extra at zero", /EXTRA_PROG=0/.test(setupSh) && /\$extraProg = 0\.0/.test(setupPs) && /TEST_MODE" != yes/.test(setupSh) && /-not \$TestMode/.test(setupPs));

const cancelAt = setupSh.indexOf("RESULT: SETUP CANCELLED");
const testWrites = [];
let from = 0;
let at = setupSh.indexOf("set_setting TEST_MODE yes", from);
while (at >= 0) { testWrites.push(at); from = at + 1; at = setupSh.indexOf("set_setting TEST_MODE yes", from); }
check("TEST_MODE is saved only after Proceed", cancelAt >= 0 && testWrites.length === 1 && testWrites[0] > cancelAt);
check("system ollama setting is saved only after Proceed", setupSh.indexOf("set_setting USE_SYSTEM_OLLAMA yes") > cancelAt);
check("setup writes no settings before cancel", setupSh.indexOf("set_setting") > cancelAt);
const cancelPs = setupPs.indexOf("RESULT: SETUP CANCELLED");
check("windows TEST_MODE is saved only after Proceed", cancelPs >= 0 && setupPs.indexOf("Set-KitSetting 'TEST_MODE'") > cancelPs);

const startSh = read("mac/start.sh");
const startPs = read("scripts/start.ps1");
check("start always runs the chat server", /Chat page \(port \$CHAT_PORT\)/.test(startSh) && /fi\r?\nstart_chat_server \|\| true/.test(startSh));
check("chat url follows the server, not only Share on Wi-Fi", /if kit_pid chat-server >\/dev\/null; then CHAT_URL=/.test(startSh));
check("chat server binds to this computer unless sharing", /bind=127\.0\.0\.1/.test(sh) && /\[ "\$SHARE_ON_WIFI" = yes \] && bind=0\.0\.0\.0/.test(sh));
check("share toggle still serves the chat page", /stop_kit chat-server\r?\n  start_chat_server \|\| true/.test(sh));
check("status always shows the chat page server", /show "Chat page server" "\$CHAT_PORT"/.test(read("mac/status.sh")) && !/&& show "Chat page server"/.test(read("mac/status.sh")));
check("windows start always runs the chat server", /Start-ChatServer/.test(startPs) && !/if \(\$ShareOnWifi\) \{[^}]*Start-ChatServer/.test(startPs));
check("wikipedia names the ini only when the key is in the file", /is_yes "\$\(setting SKIP_WIKIPEDIA no\)"/.test(startSh) && /ContainsKey\('SKIP_WIKIPEDIA'\)/.test(startPs));
check("wikipedia can be off without blaming the ini", /Wikipedia is switched off\. Everything else works\./.test(startSh) && /Wikipedia is switched off\. Everything else works\./.test(startPs));
check("test mode names the ini only when the key is in the file", /is_yes "\$\(setting TEST_MODE no\)"/.test(startSh) && /ContainsKey\('TEST_MODE'\)/.test(startPs));
check("test mode can be on without blaming the ini", /warn "TEST MODE is on\."/.test(startSh) && /'TEST MODE is on\.'/.test(startPs));
check("test mode still names the ini when the key is set", /TEST MODE is on \(kit-settings\.ini\)\./.test(startSh) && /TEST MODE is on \(kit-settings\.ini\)\./.test(startPs));
check("linux start uses the mac script", /mac\/start\.sh/.test(read("linux/start.sh")));
check("linux setup uses the mac script", /mac\/setup\.sh/.test(read("linux/setup.sh")));

const advanced = read("ADVANCED.md");
check("docs use the 14 GB allowance", /11\.5 GB on Windows, 13\.0 GB on Mac and Linux/.test(advanced) && /allowance is 14 GB/.test(advanced));
check("chat port is not Mac-only", !/Mac only with Share on Wi-Fi/.test(advanced));
check("readme extra space matches", /11\.5 GB more on Windows, about 13 GB more on Mac and Linux/.test(read("README.md")));
check("outage card uses the chat url", /http:\/\/127\.0\.0\.1:8091\/chat\.html/.test(read("README-OUTAGE.txt")) && !/chat\.html file/.test(read("README-OUTAGE.txt")));

check("version is 1.4.0", read("VERSION").trim() === "1.4.0" && /"1\.4\.0"/.test(read("www/version.js")));

if (fails) { console.log(fails + " failed"); process.exit(1); }
console.log("all universal checks passed");
