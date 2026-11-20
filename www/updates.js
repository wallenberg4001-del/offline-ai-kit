/*
 * Offline AI Kit - "Check for updates" (only runs when you click the button; never on its own).
 * Asks GitHub for the newest release and compares versions. Never downloads or changes anything.
 * Works in a browser (window.KitUpdates) and in Node 18+ (module.exports) for automated tests.
 */
(function (root) {
  "use strict";
  var RELEASES_API = "https://api.github.com/repos/wallenberg4001-del/offline-ai-kit/releases/latest";
  var RELEASES_PAGE = "https://github.com/wallenberg4001-del/offline-ai-kit/releases/latest";

  function parse(v) {
    v = String(v || "").trim().replace(/^v/i, "");
    var pre = "", i = v.indexOf("-");
    if (i >= 0) { pre = v.slice(i + 1); v = v.slice(0, i); }
    var p = v.split(".");
    return { n: [0, 1, 2].map(function (k) { return parseInt(p[k], 10) || 0; }), pre: pre };
  }
  // -1 if a < b, 0 if equal, 1 if a > b. "1.2.0-beta" < "1.2.0".
  function compareVersions(a, b) {
    var x = parse(a), y = parse(b);
    for (var k = 0; k < 3; k++) { if (x.n[k] < y.n[k]) return -1; if (x.n[k] > y.n[k]) return 1; }
    if (x.pre === y.pre) return 0;
    if (!x.pre) return 1; if (!y.pre) return -1;
    return x.pre < y.pre ? -1 : 1;
  }

  /*
   * Resolves to one of:
   *   { status: "current", current, latest }
   *   { status: "update", current, latest, page, zip }
   *   { status: "offline", current }      (no internet, GitHub unreachable, or it timed out)
   *   { status: "error", current, message } (GitHub answered but not usefully, e.g. rate limit)
   */
  function checkForUpdates(current, opts) {
    opts = opts || {};
    var f = opts.fetch || (typeof fetch !== "undefined" ? fetch : null);
    var url = opts.url || RELEASES_API;
    var ms = opts.timeoutMs || 10000;
    var ctl = typeof AbortController !== "undefined" ? new AbortController() : null;
    var timer = null;
    // Give up after the timeout even if the network never answers (then say "offline").
    var giveUp = new Promise(function (resolve) { timer = setTimeout(function () { if (ctl) ctl.abort(); resolve({ status: "offline", current: current }); }, ms); });
    var ask = Promise.resolve().then(function () {
      if (!f) throw new TypeError("no fetch");
      return f(url, { headers: { Accept: "application/vnd.github+json" }, cache: "no-store", signal: ctl ? ctl.signal : undefined });
    }).then(function (r) {
      if (!r.ok) return { status: "error", current: current, message: r.status === 403 || r.status === 429 ? "GitHub is busy right now (too many requests). Try again in an hour." : "GitHub answered with HTTP " + r.status + "." };
      return r.json().then(function (rel) {
        var latest = String(rel.tag_name || "").replace(/^v/i, "");
        if (!latest) return { status: "error", current: current, message: "GitHub did not say which version is newest." };
        if (compareVersions(current, latest) >= 0) return { status: "current", current: current, latest: latest };
        var zip = null;
        (rel.assets || []).forEach(function (a) { if (!zip && /^Offline-AI-Kit-.*\.zip$/.test(a.name || "")) zip = a.browser_download_url; });
        return { status: "update", current: current, latest: latest, page: rel.html_url || RELEASES_PAGE, zip: zip || rel.zipball_url || RELEASES_PAGE };
      });
    }, function () {
      return { status: "offline", current: current };
    }).then(function (res) { return res; },
            function (e) { return { status: "error", current: current, message: String(e && e.message || e) }; });
    return Promise.race([ask, giveUp]).then(function (res) { clearTimeout(timer); return res; });
  }

  function describe(res) {
    switch (res.status) {
      case "current": return "You're on the latest version, v" + res.current + ".";
      case "update": return "A newer version is available: v" + res.latest + " (you have v" + res.current + ").";
      case "offline": return "You appear to be offline \u2014 that's fine, the kit doesn't need internet to run.";
      default: return "Couldn't check for updates: " + (res.message || "unknown problem") + " The kit keeps working as it is.";
    }
  }

  var api = { compareVersions: compareVersions, checkForUpdates: checkForUpdates, describe: describe, RELEASES_API: RELEASES_API, RELEASES_PAGE: RELEASES_PAGE };
  if (typeof module !== "undefined" && module.exports) module.exports = api;
  else root.KitUpdates = api;
})(typeof window !== "undefined" ? window : this);
