/*
 * Guided installer page. Explains every choice, then asks the local installer
 * to run the existing setup with those answers. Nothing downloads until Install.
 * Works in the browser (window.InstallWizard) and in Node (module.exports).
 */
(function (root) {
  "use strict";

  var WINDOWS = [
    { id: "0", name: "Lite", gb: 5, detail: "Two small models (llama3.2:3b and medgemma). Fast, and it fits a lighter computer. About 5 GB." },
    { id: "1", name: "Core", gb: 15, detail: "Lite, plus two stronger models. A good fit when this PC has an NVIDIA graphics card. About 15 GB." },
    { id: "2", name: "All", gb: 35, detail: "Every model, including the strongest. Best when the graphics card has 12 GB of memory or more. About 35 GB." }
  ];
  var APPLE = [
    { id: "lite", name: "Lite", gb: 5, detail: "Two small models. Right for a computer with about 8 GB of memory. About 5 GB." },
    { id: "8", name: "Small", gb: 8, detail: "Lite plus one more small model. About 8 GB." },
    { id: "16", name: "Medium", gb: 18, detail: "A strong everyday set, including the usual all-rounder. Right for about 16 GB of memory. About 18 GB." },
    { id: "24", name: "Large", gb: 35, detail: "Medium plus two stronger models. Right for about 24 GB of memory. About 35 GB." },
    { id: "32", name: "Largest", gb: 54, detail: "Large plus the biggest model. Right for 32 GB of memory or more. About 54 GB." }
  ];
  var EMERGENCY_EXTRAS = { "se-medical": 1, "se-outdoors": 1, "trueprepper": 1, "ready-gov": 1 };
  var LIBRARY = {
    "1": { name: "Essentials", gb: 4, detail: "Survival, first aid, water, food, knots, and WikiMed. About 4 GB. Enough to start." },
    "2": { name: "Recommended", gb: 11, detail: "Essentials, plus Wikipedia's medicine articles, iFixit repair guides, a travel guide, and gardening answers. About 11 GB." }
  };

  function parseCatalog(text) {
    return String(text || "").split(/\r?\n/).map(function (line) {
      var t = line.trim();
      if (!t || t.charAt(0) === "#") return null;
      var f = t.split("|");
      if (f.length < 6) return null;
      return { id: f[0].trim(), dir: f[1].trim(), prefix: f[2].trim(), gb: Number(f[3]), group: f[4].trim(), about: f[5].trim() };
    }).filter(Boolean);
  }

  function dedupeGB(entries) {
    var seen = {}, total = 0;
    (entries || []).forEach(function (e) {
      if (!e || seen[e.prefix]) return;
      seen[e.prefix] = true;
      total += Number(e.gb) || 0;
    });
    return Math.round(total * 10) / 10;
  }

  function modelChoices(ctx) {
    ctx = ctx || {};
    if (!ctx.aiAvailable) return [];
    if (ctx.family === "windows") {
      return WINDOWS.map(function (c) {
        return { id: c.id, name: c.name, gb: c.gb, detail: c.detail, recommended: String(ctx.suggestedModels) === c.id };
      });
    }
    if (ctx.family === "intel") {
      var names = String(ctx.intelModels || "llama3.2:3b,medgemma:4b");
      var n = names.split(",").filter(Boolean).length;
      return [{
        id: names, name: "Small models", gb: n >= 3 ? 8 : 5, recommended: true,
        detail: "This Intel Mac runs the AI on the processor, so only small models are installed. Bigger ones would be very slow. Models: " + names.replace(/,/g, ", ") + "."
      }];
    }
    return APPLE.map(function (c) {
      return { id: c.id, name: c.name, gb: c.gb, detail: c.detail, recommended: String(ctx.suggestedModels) === c.id };
    });
  }

  function lookup(catalog, ids) {
    var by = {};
    (catalog || []).forEach(function (e) { by[e.id] = e; });
    return (ids || []).map(function (id) { return by[id]; }).filter(Boolean);
  }

  function gbText(n) {
    n = Number(n) || 0;
    if (n > 0 && n < 1) return Math.round(n * 1000) + " MB";
    var rounded = Math.round(n * 10) / 10;
    return (rounded % 1 === 0 ? String(rounded.toFixed(0)) : String(rounded)) + " GB";
  }

  function estimate(ctx, choices, extrasCat, mapsCat) {
    ctx = ctx || {};
    choices = choices || {};
    var models = modelChoices(ctx);
    var picked = null;
    models.forEach(function (m) { if (m.id === String(choices.models)) picked = m; });
    if (!picked && models.length) picked = models[0];
    var modelGB = picked ? picked.gb : 0;
    var tier = String(choices.tier) === "1" ? LIBRARY["1"] : LIBRARY["2"];
    var extraEntries = lookup(extrasCat, choices.extras);
    var mapEntries = lookup(mapsCat, choices.maps);
    var extraGB = dedupeGB(extraEntries);
    var mapGB = dedupeGB(mapEntries);
    var programs = Number(ctx.programsGB);
    if (!programs && programs !== 0) programs = ctx.os === "windows" ? 2.5 : 1;
    var universalGB = choices.universal ? (Number(ctx.universalExtraGB) || 0) : 0;
    var now = programs + tier.gb + modelGB + extraGB + mapGB + universalGB;
    now = Math.round(now * 10) / 10;
    var wikiGB = choices.wikipedia ? 127 : 0;
    var total = Math.round((now + wikiGB) * 10) / 10;
    var free = Number(ctx.freeGB) || 0;
    var lines = [
      { label: "AI models", value: picked ? (picked.name + " (about " + gbText(modelGB) + ")") : "Library only. This Mac's system is too old for the AI." },
      { label: "Core library", value: tier.name + " (about " + gbText(tier.gb) + ")" },
      { label: "Full Wikipedia", value: choices.wikipedia ? "Yes. About 127 GB, in the background after the first start." : "No" },
      { label: "Extra libraries", value: extraEntries.length ? (extraEntries.map(function (e) { return e.about; }).join("; ") + " (" + gbText(extraGB) + ")") : "None" },
      { label: "Offline maps", value: mapEntries.length ? (mapEntries.map(function (e) { return e.id; }).join(", ") + " (" + gbText(mapGB) + ", shared files counted once)") : "None" },
      { label: "Share on Wi-Fi", value: choices.shareWifi ? "On. Home Wi-Fi you trust only." : "Off" },
      { label: "Computers", value: choices.universal ? ("All computers on this drive (about " + gbText(universalGB) + " more)") : "This computer only" },
      { label: "Download now", value: "About " + gbText(now) + (choices.wikipedia ? (", then about " + gbText(total) + " once Wikipedia finishes") : "") },
      { label: "Free space", value: gbText(free) + " on this drive" }
    ];
    return {
      nowGB: now, totalGB: total, lines: lines,
      tooBig: free > 0 && free < now,
      wikiWarn: !!(choices.wikipedia && free > 0 && free < now + 140)
    };
  }

  function defaultChoices(ctx) {
    var models = modelChoices(ctx);
    var suggested = models.filter(function (m) { return m.recommended; })[0] || models[0];
    return {
      models: suggested ? suggested.id : "",
      tier: String(ctx.suggestedTier || "2") === "1" ? "1" : "2",
      wikipedia: !!ctx.suggestedWikipedia,
      extras: [],
      maps: [],
      shareWifi: false,
      universal: false
    };
  }

  function el(tag, cls, text) {
    var node = document.createElement(tag);
    if (cls) node.className = cls;
    if (text != null) node.textContent = text;
    return node;
  }

  function boot() {
    var app = document.getElementById("wizard");
    if (!app) return;
    app.textContent = "Looking at this computer…";
    Promise.all([
      fetch("/api/context", { cache: "no-store" }).then(function (r) { if (!r.ok) throw new Error("context"); return r.json(); }),
      fetch("/catalog/extra-libraries.txt", { cache: "no-store" }).then(function (r) { return r.text(); }),
      fetch("/catalog/maps.txt", { cache: "no-store" }).then(function (r) { return r.text(); })
    ]).then(function (parts) {
      render(parts[0], parseCatalog(parts[1]), parseCatalog(parts[2]));
    }).catch(function () {
      app.textContent = "";
      app.appendChild(el("h1", null, "Open this from the installer"));
      app.appendChild(el("p", null, "This page has to be opened by the guided installer. In the kit folder, open Click these, then 1 Install - guided, and double-click the file for your computer."));
    });

    function render(ctx, extras, maps) {
      var choices = defaultChoices(ctx);
      var stepIds = ["computer", "models", "library", "wiki", "extras", "wifi", "maps", "computers", "summary"];
      if (!ctx.aiAvailable) stepIds = stepIds.filter(function (id) { return id !== "models"; });
      var index = 0;
      app.textContent = "";
      var head = el("p", "progress", "");
      var box = el("div", "card");
      var nav = el("div", "nav");
      app.appendChild(head);
      app.appendChild(box);
      app.appendChild(nav);

      function show() {
        var id = stepIds[index];
        head.textContent = "Step " + (index + 1) + " of " + stepIds.length;
        box.textContent = "";
        nav.textContent = "";
        if (id === "computer") screenComputer();
        else if (id === "models") screenModels();
        else if (id === "library") screenLibrary();
        else if (id === "wiki") screenWiki();
        else if (id === "extras") screenChecks("Extra libraries", extras, "extras", "None of these are required. Leave them all off if you are not sure. You can add them later from Check status.");
        else if (id === "maps") screenChecks("Offline maps", maps, "maps", "Leave this empty if you do not need maps. Vancouver Island, British Columbia, Alberta, Saskatchewan, and Canada are the same download, counted once.");
        else if (id === "wifi") screenWifi();
        else if (id === "computers") screenComputers();
        else screenSummary();
        if (index > 0 && id !== "summary") {
          var back = el("button", "secondary", "Back");
          back.type = "button";
          back.addEventListener("click", function () { index -= 1; show(); });
          nav.appendChild(back);
        }
        if (id !== "summary") {
          var next = el("button", "primary", index === 0 ? "Show me the choices" : "Next");
          next.type = "button";
          next.addEventListener("click", function () { index += 1; show(); });
          nav.appendChild(next);
        }
      }

      function screenComputer() {
        box.appendChild(el("h1", null, "Install Offline AI Kit"));
        box.appendChild(el("p", null, "This puts a private chat assistant and a library on this computer. After today it works with no internet. Setup usually takes 1 to 3 hours. Wikipedia can keep downloading after that."));
        box.appendChild(el("p", null, "Nothing is downloaded until the last screen, when you press Install."));
        var facts = el("ul", "facts");
        facts.appendChild(el("li", null, ctx.computer || "This computer"));
        facts.appendChild(el("li", null, "It will be installed in this folder: " + (ctx.folder || "this folder")));
        facts.appendChild(el("li", null, "To use a different drive, copy this whole folder onto that drive first, then run the installer from the copy."));
        box.appendChild(facts);
        if (!ctx.aiAvailable) {
          box.appendChild(el("p", "warn", "This Mac is too old to run the AI. The library can still be installed. The AI needs macOS 13 or newer."));
        }
      }

      function screenModels() {
        box.appendChild(el("h1", null, "How big should the AI be?"));
        box.appendChild(el("p", null, "Bigger models write better answers and need more disk space. They are also slower on a computer without a strong graphics card. The highlighted choice is the one that fits this computer. You can change it."));
        chooseCards(modelChoices(ctx), choices.models, function (id) { choices.models = id; });
      }

      function screenLibrary() {
        box.appendChild(el("h1", null, "Which library?"));
        box.appendChild(el("p", null, "The library is a set of offline books the chat can search. Recommended is the one most people want. Essentials is smaller, for a drive that is nearly full."));
        var cards = [LIBRARY["1"], LIBRARY["2"]].map(function (item, i) {
          var id = i === 0 ? "1" : "2";
          return { id: id, name: item.name, detail: item.detail, recommended: String(ctx.suggestedTier || "2") === id };
        });
        chooseCards(cards, choices.tier, function (id) { choices.tier = id; });
      }

      function screenWiki() {
        box.appendChild(el("h1", null, "Download all of English Wikipedia?"));
        box.appendChild(el("p", null, "This is the big one: about 127 GB, with pictures. It downloads in the background the first time you start the kit. Chat and the smaller library work while it downloads. If the internet drops, the next start continues where it stopped."));
        if (!ctx.suggestedWikipedia) {
          box.appendChild(el("p", "warn", "This drive does not have a lot of free space, so the suggestion is No. You can add Wikipedia later when you have about 140 GB free."));
        }
        chooseCards([
          { id: "yes", name: "Yes, download Wikipedia", detail: "About 127 GB, in the background. Suggested when the drive has room.", recommended: !!ctx.suggestedWikipedia },
          { id: "no", name: "No, skip Wikipedia", detail: "The smaller library is still installed. You can add Wikipedia later.", recommended: !ctx.suggestedWikipedia }
        ], choices.wikipedia ? "yes" : "no", function (id) { choices.wikipedia = id === "yes"; });
      }

      function screenChecks(title, catalog, key, help) {
        box.appendChild(el("h1", null, title));
        box.appendChild(el("p", null, help));
        var selected = {};
        (choices[key] || []).forEach(function (id) { selected[id] = true; });
        catalog.forEach(function (entry) {
          var label = el("label", "check");
          var input = document.createElement("input");
          input.type = "checkbox";
          input.checked = !!selected[entry.id];
          input.addEventListener("change", function () {
            var ids = [];
            var boxes = box.querySelectorAll("input[type=checkbox]");
            boxes.forEach(function (b, i) { if (b.checked) ids.push(catalog[i].id); });
            choices[key] = ids;
            var note = box.querySelector(".live");
            if (note && key === "maps") note.textContent = mapNote(choices.maps);
          });
          label.appendChild(input);
          var text = el("span", null, entry.about + " (" + gbText(entry.gb) + ")");
          label.appendChild(text);
          if (key === "extras" && EMERGENCY_EXTRAS[entry.id]) label.appendChild(el("span", "tag", "Helpful in an emergency"));
          box.appendChild(label);
        });
        if (key === "maps") box.appendChild(el("p", "live", mapNote(choices.maps)));
      }

      function mapNote(ids) {
        var entries = lookup(maps, ids);
        if (!entries.length) return "Nothing selected. That is fine.";
        return "Selected download: about " + gbText(dedupeGB(entries)) + ". Places that share one file are counted once.";
      }

      function screenWifi() {
        box.appendChild(el("h1", null, "Share with phones on your home Wi-Fi?"));
        box.appendChild(el("p", null, "Off is the right choice for almost everyone. When it is on, a phone or tablet on the same Wi-Fi can open the chat and the library. There is no password. Anyone on that Wi-Fi can open it."));
        box.appendChild(el("p", "warn", "Use this only at home, on Wi-Fi you trust. Never on public Wi-Fi. You can turn it on later from Check status."));
        chooseCards([
          { id: "off", name: "Leave it off", detail: "Only this computer can open the chat. Suggested.", recommended: true },
          { id: "on", name: "Turn it on", detail: "Phones on your home Wi-Fi can use it. No password.", recommended: false }
        ], choices.shareWifi ? "on" : "off", function (id) { choices.shareWifi = id === "on"; });
      }

      function screenComputers() {
        box.appendChild(el("h1", null, "Which computers should this drive work on?"));
        box.appendChild(el("p", null, "This computer only is smaller and faster to download. All computers puts the Windows, Mac, and Linux programs on this same drive, so you can plug it into another computer later. The library, the AI, and the maps stay one shared copy."));
        var extra = gbText(ctx.universalExtraGB || 0);
        chooseCards([
          { id: "this", name: "This computer only", detail: "Suggested. You can still copy the folder later.", recommended: true },
          { id: "all", name: "All computers (one drive)", detail: "About " + extra + " more, for the other computers' programs. Use an exFAT drive if Windows, Mac, and Linux will all open it.", recommended: false }
        ], choices.universal ? "all" : "this", function (id) { choices.universal = id === "all"; });
      }

      function screenSummary() {
        var est = estimate(ctx, choices, extras, maps);
        box.appendChild(el("h1", null, "Check this, then install"));
        box.appendChild(el("p", null, "Nothing has been downloaded yet. Press Install and a download starts. Leave the installer window open. Closing it stops the download. If the internet drops, run this installer again. Finished pieces are kept."));
        var list = el("ul", "facts");
        est.lines.forEach(function (line) {
          list.appendChild(el("li", null, line.label + ": " + line.value));
        });
        box.appendChild(list);
        if (est.tooBig) box.appendChild(el("p", "warn", "There is not enough free space for these choices. Go back and pick a smaller AI, skip Wikipedia, or remove extras and maps."));
        else if (est.wikiWarn) box.appendChild(el("p", "warn", "Wikipedia may not fit after the first download. You can go back and choose No for Wikipedia, or free about 140 GB and add it later."));
        var back = el("button", "secondary", "Back");
        back.type = "button";
        back.addEventListener("click", function () { index -= 1; show(); });
        nav.appendChild(back);
        var go = el("button", "primary", "Install");
        go.type = "button";
        go.disabled = !!est.tooBig;
        go.addEventListener("click", function () { startInstall(est); });
        nav.appendChild(go);
      }

      function chooseCards(cards, current, onPick) {
        var wrap = el("div", "cards");
        cards.forEach(function (card) {
          var b = el("button", "choice" + (card.id === current ? " on" : ""));
          b.type = "button";
          if (card.recommended) b.appendChild(el("span", "tag", "Suggested for this computer"));
          b.appendChild(el("strong", null, card.name));
          b.appendChild(el("span", "detail", card.detail));
          b.addEventListener("click", function () {
            onPick(card.id);
            var all = wrap.querySelectorAll("button.choice");
            all.forEach(function (node, i) { node.className = "choice" + (cards[i].id === card.id ? " on" : ""); });
          });
          wrap.appendChild(b);
        });
        box.appendChild(wrap);
      }

      function startInstall() {
        nav.textContent = "";
        box.textContent = "";
        head.textContent = "Installing";
        box.appendChild(el("h1", null, "Downloading"));
        box.appendChild(el("p", null, "Leave the installer window open. This page shows what it is doing. Closing that window stops the download."));
        var pre = el("pre", "log", "Starting…");
        box.appendChild(pre);
        fetch("/api/install", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            models: choices.models,
            tier: choices.tier,
            wikipedia: !!choices.wikipedia,
            extras: choices.extras,
            maps: choices.maps,
            shareWifi: !!choices.shareWifi,
            universal: !!choices.universal
          })
        }).then(function (r) {
          if (!r.ok) return r.text().then(function (t) { throw new Error(t || ("HTTP " + r.status)); });
          poll();
        }).catch(function (e) {
          pre.textContent = "Could not start the download. " + (e.message || "");
        });
        function poll() {
          fetch("/api/log", { cache: "no-store" }).then(function (r) { return r.json(); }).then(function (data) {
            pre.textContent = data.text || (data.running ? "Working…" : "");
            pre.scrollTop = pre.scrollHeight;
            if (data.running) { setTimeout(poll, 1000); return; }
            var done = el("p", data.exit === 0 ? "ok" : "warn", data.exit === 0
              ? "Finished. If a browser did not open, use Click these, then 3 Start."
              : "The installer stopped before it finished. Read the details above. Run the installer again to continue. Finished downloads are kept.");
            box.appendChild(done);
          }).catch(function () {
            pre.textContent += "\nThe installer window was closed, so this page cannot see the rest.";
          });
        }
      }

      show();
    }
  }

  var api = {
    WINDOWS: WINDOWS, APPLE: APPLE, EMERGENCY_EXTRAS: EMERGENCY_EXTRAS, LIBRARY: LIBRARY,
    parseCatalog: parseCatalog, dedupeGB: dedupeGB, modelChoices: modelChoices,
    estimate: estimate, defaultChoices: defaultChoices, gbText: gbText
  };
  if (typeof module !== "undefined" && module.exports) module.exports = api;
  else root.InstallWizard = api;
  if (typeof root.document !== "undefined" && root.document.getElementById && root.document.getElementById("wizard")) boot();
})(typeof window !== "undefined" ? window : this);
