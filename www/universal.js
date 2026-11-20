/* Universal-drive rules. Works in node tests. The setup scripts follow the same ids,
   folder names, missing-program sentences, and extra-GB numbers. */
(function (root, factory) {
  var api = factory();
  if (typeof module === "object" && module.exports) module.exports = api;
  if (root) root.KitUniversal = api;
})(typeof globalThis !== "undefined" ? globalThis : this, function () {
  // Allowance for every computer's programs, including room to unpack.
  // Measured unpacked trees (2026-11-20): Windows 2.31 GB, each Mac folder 0.73 GB,
  // Linux x64 5.11 GB and Linux ARM 3.92 GB (about 12.8 GB together). Linux archives
  // expand well past the compressed download. 14 GB sits above the measured 12.1 GB extra.
  var UNIVERSAL_PROGRAM_GB = 14.0;
  // What a this-computer-only estimate already counts for programs.
  var ALREADY_COUNTED_GB = {
    "windows-x64": 2.5,
    "mac-arm64": 1.0,
    "mac-x64": 1.0,
    "linux-x64": 1.0,
    "linux-arm64": 1.0
  };
  var PLATFORM_IDS = ["windows-x64", "mac-arm64", "mac-x64", "linux-x64", "linux-arm64"];

  function normOs(os) {
    var s = String(os || "").toLowerCase();
    if (s === "win32" || s === "windows_nt" || s === "windows") return "windows";
    if (s === "darwin" || s === "macos" || s === "mac") return "mac";
    if (s === "linux") return "linux";
    return s;
  }
  function normArch(arch) {
    var a = String(arch || "").toLowerCase();
    if (a === "amd64" || a === "x86_64" || a === "x64") return "x64";
    if (a === "aarch64" || a === "arm64") return "arm64";
    if (a === "x86" || a === "ia32" || a === "i386") return "x86";
    return a;
  }

  // hwArm64 is true on an Apple-chip Mac even when the shell is running under Rosetta.
  function detectPlatform(info) {
    info = info || {};
    var os = normOs(info.os);
    var arch = normArch(info.arch);
    if (os === "mac" && info.hwArm64) arch = "arm64";
    if (os === "windows" && arch === "x64") return "windows-x64";
    if (os === "windows" && arch === "arm64") return "windows-arm64";
    if (os === "windows") return "windows-x86";
    if (os === "mac" && arch === "arm64") return "mac-arm64";
    if (os === "mac") return "mac-x64";
    if (os === "linux" && arch === "arm64") return "linux-arm64";
    if (os === "linux") return "linux-x64";
    return "";
  }

  function runtimeFolder(platformId) {
    return "runtime/" + platformId;
  }

  function who(platformId) {
    return {
      "windows-x64": "Windows (64-bit)",
      "windows-arm64": "Windows on ARM",
      "windows-x86": "32-bit Windows",
      "mac-arm64": "a Mac with an Apple chip",
      "mac-x64": "an Intel Mac",
      "linux-x64": "64-bit Linux",
      "linux-arm64": "Linux on ARM"
    }[platformId] || "this computer";
  }
  function setupCommand(platformId) {
    if (String(platformId).indexOf("mac-") === 0) return "SETUP-MAC.command";
    if (String(platformId).indexOf("linux-") === 0) return "bash SETUP-LINUX.sh";
    return "SETUP.bat";
  }

  function missingProgramMessage(platformId) {
    var id = platformId || "windows-x64";
    var folder = PLATFORM_IDS.indexOf(id) >= 0 || id === "windows-arm64" || id === "windows-x86" ? id : "windows-x64";
    var lines = [
      "This drive does not have the Offline AI programs for " + who(id) + " (folder runtime/" + folder + ").",
      "The library, models and maps on the drive are shared, and they are still here.",
      "Connect this computer to the internet and run " + setupCommand(id) + ", then choose All computers (universal drive).",
      "You can also choose This computer only, which adds just this computer's programs."
    ];
    if (id === "windows-arm64" || id === "windows-x86") {
      lines.push("The Windows programs in this kit are for 64-bit Intel and AMD PCs (runtime/windows-x64).");
    }
    return lines.join(" ");
  }

  function universalExtraGB(platformId) {
    var mine = ALREADY_COUNTED_GB[platformId];
    if (mine === undefined) mine = 2.5;
    return Math.round((UNIVERSAL_PROGRAM_GB - mine) * 10) / 10;
  }

  function legacyDirs(platformId, channel) {
    if (platformId === "windows-x64") return { ollama: ["runtime/ollama"], kiwix: ["runtime/kiwix"] };
    if (platformId === "mac-arm64" || platformId === "mac-x64") {
      return {
        ollama: [channel === "pinned" ? "runtime/mac-ollama-v0.12.9" : "runtime/mac-ollama"],
        kiwix: [platformId === "mac-x64" ? "runtime/mac-kiwix-intel" : "runtime/mac-kiwix"]
      };
    }
    if (platformId === "linux-arm64") return { ollama: ["runtime/linux-ollama"], kiwix: ["runtime/linux-kiwix-arm"] };
    if (platformId === "linux-x64") return { ollama: ["runtime/linux-ollama"], kiwix: ["runtime/linux-kiwix"] };
    return { ollama: [], kiwix: [] };
  }

  function hasNamed(files, dir, names, nested) {
    var i, n, f, parts, dirParts;
    dirParts = dir.split("/").length;
    for (i = 0; i < files.length; i++) {
      f = String(files[i]).replace(/\\/g, "/");
      for (n = 0; n < names.length; n++) {
        if (f === dir + "/" + names[n]) return true;
        if (nested && f.indexOf(dir + "/") === 0 && f.slice(-names[n].length) === names[n]) {
          parts = f.split("/").length;
          if (parts === dirParts + 2) return true;
        }
      }
    }
    return false;
  }
  function hasOllama(files, dir) {
    return hasNamed(files, dir, ["ollama", "bin/ollama", "ollama.exe", "bin/ollama.exe"], false);
  }
  function hasKiwix(files, dir) {
    return hasNamed(files, dir, ["kiwix-serve", "kiwix-serve.exe"], true);
  }

  // files: kit-relative paths that exist. channel: current | pinned | none.
  function selectRuntime(spec) {
    spec = spec || {};
    var id = spec.platformId || "";
    var files = spec.files || [];
    var channel = spec.channel || "current";
    var ollamaName = channel === "pinned" ? "ollama-v0.12.9" : "ollama";
    var primaryO = "runtime/" + id + "/" + ollamaName;
    var primaryK = "runtime/" + id + "/kiwix";
    var legacy = legacyDirs(id, channel);
    var o = "", k = "", i;
    if (hasOllama(files, primaryO)) o = primaryO;
    else {
      for (i = 0; i < legacy.ollama.length; i++) if (hasOllama(files, legacy.ollama[i])) { o = legacy.ollama[i]; break; }
    }
    if (hasKiwix(files, primaryK)) k = primaryK;
    else {
      for (i = 0; i < legacy.kiwix.length; i++) if (hasKiwix(files, legacy.kiwix[i])) { k = legacy.kiwix[i]; break; }
    }
    var needO = channel !== "none" && !spec.useSystemOllama;
    var missing = !id || !k || (needO && !o);
    return {
      platformId: id,
      ollamaDir: o || primaryO,
      kiwixDir: k || primaryK,
      missing: missing,
      message: missing ? missingProgramMessage(id) : ""
    };
  }

  return {
    UNIVERSAL_PROGRAM_GB: UNIVERSAL_PROGRAM_GB,
    ALREADY_COUNTED_GB: ALREADY_COUNTED_GB,
    PLATFORM_IDS: PLATFORM_IDS,
    detectPlatform: detectPlatform,
    runtimeFolder: runtimeFolder,
    missingProgramMessage: missingProgramMessage,
    universalExtraGB: universalExtraGB,
    selectRuntime: selectRuntime
  };
});
