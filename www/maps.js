/* Offline maps helpers. Works in the browser and in node tests. */
(function (root, factory) {
  var api = factory();
  if (typeof module === "object" && module.exports) module.exports = api;
  if (root) root.KitMaps = api;
})(typeof globalThis !== "undefined" ? globalThis : this, function () {
  function zimName(file) {
    return String(file || "").replace(/\.zim$/i, "");
  }

  // Phones on Share on Wi-Fi use the chat server (port 8091) as libraryBase.
  // This computer uses http://127.0.0.1:8090. Either way the map opens at /content/<name>/.
  function mapHref(libraryBase, zimFile) {
    var base = String(libraryBase || "").replace(/\/+$/, "");
    return base + "/content/" + zimName(zimFile) + "/";
  }

  function escapeRe(s) {
    return String(s).replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  }

  // Newest prefix_YYYY-MM.zim, where the month may have a letter (2026-08 < 2026-08a < 2026-09).
  function pickNewestZim(html, prefix) {
    var re = new RegExp("href=\"(" + escapeRe(prefix) + "_(\\d{4}-\\d{2}[a-z]?)\\.zim)\"", "g");
    var best = null, m;
    while ((m = re.exec(String(html || "")))) {
      if (!best || m[2] > best.date) best = { file: m[1], date: m[2] };
    }
    return best ? best.file : "";
  }

  function dedupeByPrefix(entries) {
    var seen = {};
    var out = [];
    (entries || []).forEach(function (e) {
      var key = e && (e.prefix || e.Prefix);
      if (!key || seen[key]) return;
      seen[key] = true;
      out.push(e);
    });
    return out;
  }

  // FAT32 / vfat / msdos cannot store a file of 4 GiB or more. exFAT, NTFS and APFS can.
  function fat32Blocked(kind) {
    var k = String(kind || "").toLowerCase().replace(/[^a-z0-9]/g, "");
    return k === "fat32" || k === "vfat" || k === "msdos" || k === "msdosfat32" || k === "fat";
  }

  // `ip route get 1.1.1.1` — the src address is this computer, not the gateway.
  function lanIpFromIpRoute(text) {
    var m = String(text || "").match(/\bsrc\s+(\d+\.\d+\.\d+\.\d+)/);
    if (!m) return "";
    if (/^(127\.|169\.254\.|0\.)/.test(m[1])) return "";
    return m[1];
  }

  return {
    zimName: zimName,
    mapHref: mapHref,
    pickNewestZim: pickNewestZim,
    dedupeByPrefix: dedupeByPrefix,
    fat32Blocked: fat32Blocked,
    lanIpFromIpRoute: lanIpFromIpRoute
  };
});
