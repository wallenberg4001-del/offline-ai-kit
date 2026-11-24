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
    var free = (choices && choices.driveFreeGB != null && choices.driveFreeGB !== "") ? Number(choices.driveFreeGB) : (Number(ctx.freeGB) || 0);
    if (!(free >= 0)) free = 0;
    var lines = [
      { label: "AI models", value: picked ? (picked.name + " (about " + gbText(modelGB) + ")") : "Library only. This Mac's system is too old for the AI." },
      { label: "Core library", value: tier.name + " (about " + gbText(tier.gb) + ")" },
      { label: "Full Wikipedia", value: choices.wikipedia ? (choices.wikiNow ? "Yes. About 127 GB, downloaded now, before this page says the drive is ready." : "Not downloaded yet. Run setup with internet to add it. Start does not download it.") : "No" },
      { label: "Extra libraries", value: extraEntries.length ? (extraEntries.map(function (e) { return e.about; }).join("; ") + " (" + gbText(extraGB) + ")") : "None" },
      { label: "Offline maps", value: mapEntries.length ? (mapEntries.map(function (e) { return e.id; }).join(", ") + " (" + gbText(mapGB) + ", shared files counted once)") : "None" },
      { label: "Share on Wi-Fi", value: choices.shareWifi ? "On. Home Wi-Fi you trust only." : "Off" },
      { label: "Computers", value: choices.universal ? ("All computers on this drive (about " + gbText(universalGB) + " more)") : "This computer only" },
      { label: "Folder", value: choices.path || (ctx.folder || "This folder") },
      { label: "Download now", value: (choices.wikipedia && choices.wikiNow) ? ("About " + gbText(total) + ", including Wikipedia") : ("About " + gbText(now) + (choices.wikipedia ? (", then about " + gbText(total) + " once Wikipedia finishes") : "")) },
      { label: "Free space", value: gbText(free) + " on this drive" }
    ];
    var copyGB = 0;
    var need = (choices.wikipedia && choices.wikiNow) ? now + 140 : now;
    return {
      nowGB: now, totalGB: total, lines: lines, copyGB: copyGB,
      tooBig: free > 0 && free < need,
      wikiWarn: !!(choices.wikipedia && !choices.wikiNow && free > 0 && free < now + 140)
    };
  }

  function macCopyGB() {
    return 0;
  }

  var GUIDE_EXTRAS = ["se-medical", "se-outdoors", "trueprepper", "ready-gov"];

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
      universal: false,
      suggestUniversal: false,
      path: "",
      wikiNow: false,
      driveFreeGB: null,
      place: "stay",
      modelsGB: 0
    };
  }

  function windowsDrivePlan(diskGB, sizeGB, modelsGB) {
    var models = Number(modelsGB) || 0;
    var size = Number(sizeGB) || 0;
    var disk = Number(diskGB) || 0;
    if (models < 0) models = 0;
    var kit = disk;
    if (models && disk) kit = size || (disk - models);
    else if (size) kit = size;
    return { models: models, kit: kit };
  }

  function driveFolder(drivePath) {
    var raw = String(drivePath || "");
    var win = /^[A-Za-z]:/.test(raw) || (raw.indexOf("\\") !== -1 && raw.indexOf("/") === -1);
    var p = raw.replace(/[\\/]+$/, "");
    if (!p) return "Offline AI Kit";
    return p + (win ? "\\" : "/") + "Offline AI Kit";
  }

  function fat32Blocked(drive) {
    if (!drive) return true;
    if (drive.fat32) return true;
    var fmt = String(drive.format || "").toLowerCase().replace(/[^a-z0-9]/g, "");
    if (!fmt) return false;
    if (fmt.indexOf("exfat") !== -1) return false;
    return fmt === "fat" || fmt === "fat32" || fmt === "fat16" || fmt === "vfat" || fmt === "msdos" || fmt.indexOf("msdos") !== -1;
  }

  function usableDrive(drive) {
    return !!(drive && drive.path && !fat32Blocked(drive));
  }

  function externalReady(ctx, drive) {
    ctx = ctx || {};
    drive = drive || {};
    var base = defaultChoices(ctx);
    var exfat = /exfat/i.test(String(drive.format || ""));
    base.tier = "2";
    base.wikipedia = true;
    base.extras = GUIDE_EXTRAS.slice();
    base.wikiNow = true;
    base.universal = !fat32Blocked(drive) && exfat;
    base.suggestUniversal = base.universal;
    base.path = drive.current ? (ctx.folder || driveFolder(drive.path)) : driveFolder(drive.path);
    base.driveFreeGB = Number(drive.freeGB);
    if (!(base.driveFreeGB >= 0)) base.driveFreeGB = 0;
    base.macImage = false;
    base.drawerReady = true;
    base.place = "stay";
    return base;
  }

  function offerFor(drives) {
    var current = null, other = null;
    (drives || []).forEach(function (d) {
      if (!d || !d.external || !usableDrive(d)) return;
      if (d.current) current = d;
      else if (!other || Number(d.freeGB) > Number(other.freeGB)) other = d;
    });
    return { current: current, other: other };
  }

  function everyComputerChoices(ctx) {
    var ready = externalReady(ctx || {}, { path: "/", format: "ExFAT", freeGB: 0, fat32: false, current: false, external: true });
    ready.universal = true;
    ready.suggestUniversal = true;
    ready.macImage = false;
    ready.drawerReady = true;
    ready.wikipedia = true;
    ready.wikiNow = true;
    ready.tier = "2";
    ready.extras = GUIDE_EXTRAS.slice();
    ready.place = "prepare";
    ready.path = "";
    return ready;
  }

  function prepareError(disk, req) {
    req = req || {};
    disk = disk || {};
    if (!req.confirmed) return "Tick the box before erasing.";
    if (disk.internal || disk.startup) return "That disk is this computer. It cannot be erased.";
    if (!disk.id) return "Pick a disk.";
    var parts = disk.partitions || [];
    var models = Number(req.modelsGB) || 0;
    if (models < 0) models = 0;
    if (req.mode === "partition") {
      if (models) return "The Windows drive is only made when the whole disk is erased.";
      if (!parts.some(function (p) { return p.id === req.partitionId; })) return "That partition is not on this disk.";
      return "";
    }
    if (req.mode !== "disk") return "Pick what to erase.";
    var size = Number(req.sizeGB) || 0;
    var diskGB = Number(disk.sizeGB) || 0;
    if (size && (size < 200 || (diskGB && size > diskGB + 1))) return "That size does not fit on this disk.";
    if (models) {
      if (models < 200) return "The Windows drive needs at least 200 GB.";
      var plan = windowsDrivePlan(diskGB, size, models);
      if (diskGB && plan.kit < 200) return "The Windows drive does not leave 200 GB for the kit.";
      if (size && diskGB && (size + models) > diskGB + 1) return "Those sizes do not fit on this disk.";
    }
    return "";
  }

  function eraseNames(disk, req) {
    var parts = (disk && disk.partitions) || [];
    if (req && req.mode === "partition") {
      return parts.filter(function (p) { return p.id === req.partitionId; }).map(function (p) { return p.name || p.id; });
    }
    return parts.map(function (p) { return p.name || p.id; });
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
      fetch("/catalog/maps.txt", { cache: "no-store" }).then(function (r) { return r.text(); }),
      fetch("/api/drives", { cache: "no-store" }).then(function (r) { if (!r.ok) return []; return r.json(); }).catch(function () { return []; })
    ]).then(function (parts) {
      render(parts[0], parseCatalog(parts[1]), parseCatalog(parts[2]), Array.isArray(parts[3]) ? parts[3] : []);
    }).catch(function () {
      app.textContent = "";
      app.appendChild(el("h1", null, "Open this from the installer"));
      app.appendChild(el("p", null, "This page has to be opened by the guided installer. In the kit folder, open Click these, then 1 Install - guided, and double-click the file for your computer."));
    });

    function render(ctx, extras, maps, initialDrives) {
      var choices = defaultChoices(ctx);
      var drives = initialDrives || [];
      var disks = [];
      var selectedDisk = null;
      var index = 0;
      app.textContent = "";
      var head = el("p", "progress", "");
      var box = el("div", "card");
      var nav = el("div", "nav");
      app.appendChild(head);
      app.appendChild(box);
      app.appendChild(nav);
      mountDriveTools(app);

      function mountDriveTools(root) {
        var details = el("details", "drive-tools");
        details.open = false;
        details.appendChild(el("summary", null, "Advanced → Drive tools"));
        details.appendChild(el("p", null, "These delete files from the drive. Uninstall does not open this. Nothing is selected. Pressing Return does nothing."));
        function field(placeholder) {
          var input = el("input");
          input.type = "text";
          input.placeholder = placeholder;
          input.setAttribute("autocomplete", "off");
          return input;
        }
        function send(body) {
          fetch("/api/drive-tools", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(body)
          }).then(function (r) { return r.text().then(function (t) { window.alert(t || ("HTTP " + r.status)); }); });
        }
        function add(title, node, onClick) {
          var wrap = el("div");
          wrap.appendChild(el("p", null, title));
          wrap.appendChild(node);
          var button = el("button", "drive-tools", title);
          button.type = "button";
          button.addEventListener("click", onClick);
          wrap.appendChild(button);
          details.appendChild(wrap);
          return button;
        }
        var files = field("file names, separated by commas");
        var countPhrase = field("DELETE 2 FILES");
        var fileWrap = el("div");
        fileWrap.appendChild(files);
        fileWrap.appendChild(countPhrase);
        add("Remove chosen library files", fileWrap, function () {
          var list = files.value.split(",").map(function (s) { return s.trim(); }).filter(Boolean);
          send({ action: "library", files: list, phrase: countPhrase.value });
        });
        var kitPhrase = field("REMOVE KIT FROM DRIVE");
        add("Remove the whole kit from the drive", kitPhrase, function () {
          send({ action: "kit", phrase: kitPhrase.value, files: [] });
        });
        var label = field("volume label");
        var eraseWord = field("ERASE");
        var eraseWrap = el("div");
        eraseWrap.appendChild(label);
        eraseWrap.appendChild(eraseWord);
        add("Erase the kit partition", eraseWrap, function () {
          send({ action: "erase", phrase: label.value, label: label.value, erase: eraseWord.value, scope: "partition", yes: false });
        });
        root.appendChild(details);
      }

      function steps() {
        var ids = ["computer", "where"];
        if (choices.place === "how" || choices.place === "pick" || choices.place === "prepare") ids.push("drive-how");
        if (choices.place === "pick") ids.push("drive");
        if (choices.place === "prepare" || choices.place === "erase") ids.push("disk", "erase-how", "erase-confirm");
        if (ctx.aiAvailable) ids.push("models");
        ids.push("library", "wiki", "extras", "wifi", "maps", "computers", "summary");
        return ids;
      }

      function loadDrives() {
        return fetch("/api/drives", { cache: "no-store" }).then(function (r) {
          if (!r.ok) throw new Error("drives");
          return r.json();
        }).then(function (list) {
          drives = Array.isArray(list) ? list : [];
          return drives;
        }).catch(function () {
          drives = [];
          return drives;
        });
      }

      function applyReady(ready) {
        choices.tier = ready.tier;
        choices.wikipedia = ready.wikipedia;
        choices.extras = (ready.extras || []).slice();
        choices.universal = ready.universal;
        choices.suggestUniversal = ready.suggestUniversal;
        choices.path = ready.path;
        choices.wikiNow = ready.wikiNow;
        choices.driveFreeGB = ready.driveFreeGB;
        choices.macImage = !!ready.macImage;
        choices.place = ready.place;
      }

      function setThisComputer() {
        var fresh = defaultChoices(ctx);
        choices.tier = fresh.tier;
        choices.wikipedia = fresh.wikipedia;
        choices.extras = [];
        choices.maps = choices.maps || [];
        choices.universal = false;
        choices.suggestUniversal = false;
        choices.path = "";
        choices.wikiNow = false;
        choices.driveFreeGB = null;
        choices.macImage = false;
        choices.place = "stay";
      }

      function loadDisks() {
        return fetch("/api/disks", { cache: "no-store" }).then(function (r) {
          if (!r.ok) throw new Error("disks");
          return r.json();
        }).then(function (list) {
          disks = Array.isArray(list) ? list : [];
          return disks;
        }).catch(function () {
          disks = [];
          return disks;
        });
      }

      function goAfter(id) {
        var next = steps();
        var pos = next.indexOf(id);
        if (pos === -1) pos = next.indexOf("where");
        index = pos + 1;
        if (index >= next.length) index = next.length - 1;
        show();
      }

      function show() {
        var stepIds = steps();
        if (index >= stepIds.length) index = stepIds.length - 1;
        if (index < 0) index = 0;
        var id = stepIds[index];
        head.textContent = "Step " + (index + 1) + " of " + stepIds.length;
        box.textContent = "";
        nav.textContent = "";
        if (id === "computer") screenComputer();
        else if (id === "where") screenWhere();
        else if (id === "drive-how") screenDriveHow();
        else if (id === "drive") screenDrive();
        else if (id === "disk") screenDisk();
        else if (id === "erase-how") screenEraseHow();
        else if (id === "erase-confirm") screenEraseConfirm();
        else if (id === "models") screenModels();
        else if (id === "library") screenLibrary();
        else if (id === "wiki") screenWiki();
        else if (id === "extras") screenChecks("Extra libraries", extras, "extras", choices.wikiNow ? "These guides start ticked so the drive is ready for an emergency. Untick any you do not want. You can add more later from Check status." : "None of these are required. Leave them all off if you are not sure. You can add them later from Check status.");
        else if (id === "maps") screenChecks("Offline maps", maps, "maps", "Leave this empty if you do not need maps. Vancouver Island, British Columbia, Alberta, Saskatchewan, and Canada are the same download, counted once.");
        else if (id === "wifi") screenWifi();
        else if (id === "computers") screenComputers();
        else screenSummary();
        var ownNav = id === "summary" || id === "where" || id === "drive" || id === "drive-how" || id === "disk" || id === "erase-how" || id === "erase-confirm";
        if (!ownNav && index > 0) {
          var back = el("button", "secondary", "Back");
          back.type = "button";
          back.addEventListener("click", function () { index -= 1; show(); });
          nav.appendChild(back);
        }
        if (!ownNav) {
          var next = el("button", "primary", index === 0 ? "Show me the choices" : "Next");
          next.type = "button";
          next.addEventListener("click", function () { index += 1; show(); });
          nav.appendChild(next);
        }
      }

      function screenComputer() {
        box.appendChild(el("h1", null, "Install Offline AI Kit"));
        box.appendChild(el("p", null, "This puts a private chat assistant and a library on a computer you choose. After today it works with no internet. Setup usually takes 1 to 3 hours. The next step asks whether to put it on an external hard drive."));
        box.appendChild(el("p", null, "Nothing is downloaded until the last screen, when you press Install."));
        var facts = el("ul", "facts");
        facts.appendChild(el("li", null, ctx.computer || "This computer"));
        facts.appendChild(el("li", null, "This copy is in: " + (ctx.folder || "this folder")));
        box.appendChild(facts);
        if (!ctx.aiAvailable) {
          box.appendChild(el("p", "warn", "This Mac is too old to run the AI. The library can still be installed. The AI needs macOS 13 or newer."));
        }
      }

      function backButton() {
        var back = el("button", "secondary", "Back");
        back.type = "button";
        back.addEventListener("click", function () { index -= 1; show(); });
        nav.appendChild(back);
      }

      function screenWhere() {
        var offer = offerFor(drives);
        box.appendChild(el("h1", null, "Where should this live?"));
        box.appendChild(el("p", null, "You can leave it on this computer, or put the whole kit on an external hard drive. On a drive, Wikipedia and the guides download before this page says it is ready, so the drive is ready to unplug. Press the one you want."));
        var hereName = offer.current ? "Keep this drive" : "This computer";
        var hereDetail = offer.current
          ? (offer.current.name + " — " + offer.current.format + ", " + gbText(offer.current.freeGB) + " free. Wikipedia and the guides finish downloading onto this drive.")
          : ("Install in this folder: " + (ctx.folder || "this folder") + ". If you choose Wikipedia, setup downloads it. Start does not.");
        var driveName = offer.current ? "A different drive" : "An external hard drive";
        var driveDetail = "Plug the drive in. The next screen lists the drives it can use. The kit goes in a folder named Offline AI Kit. Wikipedia and the guides download onto that drive before you unplug it.";
        var cards = [
          { id: "stay", name: hereName, detail: hereDetail, recommended: !!offer.current || !offer.other },
          { id: "pick", name: driveName, detail: driveDetail, recommended: !offer.current && !!offer.other }
        ];
        chooseCards(cards, "", function (id) {
          if (id === "stay") {
            if (offer.current) applyReady(externalReady(ctx, offer.current));
            else setThisComputer();
            choices.place = "stay";
          } else {
            choices.place = "how";
          }
          goAfter("where");
        });
        if (index > 0) backButton();
      }

      function screenDriveHow() {
        box.appendChild(el("h1", null, "How should the drive be prepared?"));
        box.appendChild(el("p", null, "You can use a volume that is already on the drive, or erase one and make it ready for Windows, Mac, and Linux. Press the one you want."));
        chooseCards([
          { id: "use", name: "Use a volume that is already there", detail: "Nothing is erased. Pick a volume on the next screen. FAT32 cannot be used.", recommended: false },
          { id: "prepare", name: "Prepare a drive for every computer", detail: "Erases one partition, or the whole disk, and formats it as exFAT. Wikipedia and the guides then download onto it. Windows, Mac, and Linux can all read that drive.", recommended: true }
        ], "", function (id) {
          if (id === "use") {
            choices.place = "pick";
            choices.macImage = false;
          } else {
            var ready = everyComputerChoices(ctx);
            choices.tier = ready.tier;
            choices.wikipedia = ready.wikipedia;
            choices.wikiNow = ready.wikiNow;
            choices.extras = ready.extras.slice();
            choices.universal = true;
            choices.suggestUniversal = true;
            choices.macImage = false;
            choices.drawerReady = true;
            choices.path = "";
            choices.place = "prepare";
          }
          goAfter("drive-how");
        });
        if (index > 0) backButton();
      }

      function screenDrive() {
        box.appendChild(el("h1", null, "Pick the drive"));
        box.appendChild(el("p", null, "Plug it in and leave it plugged in until the last screen says the drive is ready. The kit goes in a folder named Offline AI Kit."));
        box.appendChild(el("p", null, "FAT32 cannot hold Wikipedia. Format that drive as exFAT if Windows, Mac, and Linux will all open it. NTFS and APFS work too."));
        var list = drives.filter(function (d) { return d && d.external; });
        if (!list.length) {
          box.appendChild(el("p", "warn", "No external drive is plugged in yet. Plug one in, then press Look again."));
        }
        var wrap = el("div", "cards");
        list.forEach(function (drive) {
          var blocked = !usableDrive(drive);
          var b = el("button", "choice");
          b.type = "button";
          if (blocked) b.disabled = true;
          b.appendChild(el("strong", null, drive.name || drive.path));
          var detail = (drive.format || "Unknown format") + ", " + gbText(drive.freeGB) + " free.";
          if (drive.current) detail += " This copy is already on this drive.";
          if (blocked) detail += " FAT32 cannot hold Wikipedia. Format it as exFAT, NTFS, or APFS.";
          b.appendChild(el("span", "detail", detail));
          if (!blocked) {
            b.addEventListener("click", function () {
              applyReady(externalReady(ctx, drive));
              choices.place = "drive";
              goAfter("drive");
            });
          }
          wrap.appendChild(b);
        });
        if (list.length) box.appendChild(wrap);
        if (index > 0) backButton();
        var look = el("button", "secondary", "Look again");
        look.type = "button";
        look.addEventListener("click", function () {
          look.disabled = true;
          look.textContent = "Looking…";
          loadDrives().then(function () { show(); });
        });
        nav.appendChild(look);
        var stay = el("button", "secondary", "Keep it on this computer");
        stay.type = "button";
        stay.addEventListener("click", function () {
          setThisComputer();
          goAfter("where");
        });
        nav.appendChild(stay);
      }

      function screenDisk() {
        box.appendChild(el("h1", null, "Which disk?"));
        box.appendChild(el("p", null, "This list is physical disks plugged into this computer. The startup disk is not here. Each card shows the partitions on that disk. Nothing is erased on this screen."));
        if (!disks.length) {
          box.appendChild(el("p", "warn", "No external disk is plugged in yet. Plug one in, then press Look again."));
        }
        var wrap = el("div", "cards");
        disks.forEach(function (disk) {
          var b = el("button", "choice");
          b.type = "button";
          var names = (disk.partitions || []).map(function (p) {
            return (p.name || p.id) + " (" + gbText(p.sizeGB) + ")";
          }).join(", ");
          var diskLabel = /^disk/i.test(String(disk.id || "")) ? String(disk.id) : ("Disk " + disk.id);
          b.appendChild(el("strong", null, diskLabel + " — " + gbText(disk.sizeGB)));
          b.appendChild(el("span", "detail", names || "No data partition yet. You can still erase the whole disk and make one new volume."));
          b.addEventListener("click", function () {
            selectedDisk = disk;
            choices.partitionId = "";
            choices.eraseMode = "";
            goAfter("disk");
          });
          wrap.appendChild(b);
        });
        if (disks.length) box.appendChild(wrap);
        if (index > 0) backButton();
        var look = el("button", "secondary", "Look again");
        look.type = "button";
        look.addEventListener("click", function () {
          look.disabled = true;
          look.textContent = "Looking…";
          loadDisks().then(function () { show(); });
        });
        nav.appendChild(look);
      }

      function screenEraseHow() {
        var disk = selectedDisk || { partitions: [] };
        var parts = disk.partitions || [];
        box.appendChild(el("h1", null, "What gets erased?"));
        box.appendChild(el("p", null, "Only the item you pick is erased. The rest of this computer is left alone."));
        var cards = parts.map(function (p) {
          return { id: "part:" + p.id, name: "Only " + (p.name || p.id), detail: (p.format || "Unknown format") + ", " + gbText(p.sizeGB) + ". The other partitions on this disk stay.", recommended: parts.length > 1 };
        });
        if (ctx.os !== "linux") {
          cards.push({ id: "wholedisk", name: "The whole disk", detail: "Every partition on this disk is deleted. You can use the whole disk, leave some empty, or make a Windows drive for LLM models.", recommended: parts.length <= 1 });
        }
        if (!cards.length) box.appendChild(el("p", "warn", "This disk has no partition to erase. Go back and pick another disk."));
        chooseCards(cards, "", function (id) {
          if (id === "wholedisk") {
            choices.eraseMode = "disk";
            choices.partitionId = "";
            choices.sizeGB = 0;
            choices.modelsGB = 0;
          } else {
            choices.eraseMode = "partition";
            choices.partitionId = id.replace(/^part:/, "");
            choices.sizeGB = 0;
            choices.modelsGB = 0;
          }
          goAfter("erase-how");
        });
        if (index > 0) backButton();
      }

      function screenEraseConfirm() {
        var disk = selectedDisk || { partitions: [], id: "", sizeGB: 0 };
        var req = { mode: choices.eraseMode, partitionId: choices.partitionId, sizeGB: choices.sizeGB || 0, modelsGB: choices.modelsGB || 0, confirmed: true };
        var names = eraseNames(disk, req);
        box.appendChild(el("h1", null, "Erase, then make the drive"));
        box.appendChild(el("p", null, "This cannot be undone. These will be deleted. The kit drive is then formatted as exFAT and named OFFLINEAI. Windows, Mac, and Linux can all read that. Wikipedia will not fit on FAT32."));
        var list = el("ul", "facts");
        var diskLabel = /^disk/i.test(String(disk.id || "")) ? String(disk.id) : ("Disk " + (disk.id || ""));
        list.appendChild(el("li", null, diskLabel + ", " + gbText(disk.sizeGB)));
        names.forEach(function (name) { list.appendChild(el("li", null, "Deletes: " + name)); });
        if (!names.length) list.appendChild(el("li", null, "Deletes every partition on this disk."));
        var planItem = el("li", null, "");
        box.appendChild(list);
        var sizeWrap = el("div", null, "");
        var windowsNote = el("p", null, "");
        function paintPlan() {
          var plan = windowsDrivePlan(disk.sizeGB, choices.sizeGB, choices.modelsGB);
          if (choices.eraseMode === "disk" && plan.models) {
            planItem.textContent = "Makes AI-DRIVE, " + gbText(plan.models) + ", for a Windows PC to store LLM models. OFFLINEAI gets the rest" + (plan.kit > 0 ? (", about " + gbText(plan.kit)) : "") + ".";
            if (!planItem.parentNode) list.appendChild(planItem);
            var format = ctx.os === "windows" ? "On Windows this drive is NTFS." : "On this computer this drive is exFAT, which Windows reads and writes, including large model files.";
            windowsNote.textContent = "AI-DRIVE is only for the Windows PC. The kit does not use that space. " + format;
          } else if (planItem.parentNode) {
            planItem.parentNode.removeChild(planItem);
            windowsNote.textContent = "";
          }
        }
        if (choices.eraseMode === "disk") {
          box.appendChild(el("p", null, "Leave the size empty to use the whole disk for the kit. Or type a size of at least 200 GB. The rest of the disk becomes empty free space, not a saved copy of the old partitions."));
          var size = document.createElement("input");
          size.type = "number";
          size.min = "200";
          size.placeholder = "Whole disk";
          size.value = choices.sizeGB ? String(choices.sizeGB) : "";
          size.addEventListener("input", function () { choices.sizeGB = Number(size.value) || 0; paintPlan(); });
          sizeWrap.appendChild(size);
          box.appendChild(sizeWrap);
          var windowsLabel = el("label", "check");
          var windowsTick = document.createElement("input");
          windowsTick.type = "checkbox";
          windowsTick.checked = !!choices.modelsGB;
          windowsLabel.appendChild(windowsTick);
          windowsLabel.appendChild(document.createTextNode("Also make a Windows drive for LLM models"));
          box.appendChild(windowsLabel);
          var modelsSize = document.createElement("input");
          modelsSize.type = "number";
          modelsSize.min = "200";
          modelsSize.placeholder = "3000";
          modelsSize.value = choices.modelsGB ? String(choices.modelsGB) : "3000";
          modelsSize.addEventListener("input", function () {
            choices.modelsGB = Number(modelsSize.value) || 0;
            paintPlan();
          });
          var modelsWrap = el("div", null, "");
          modelsWrap.appendChild(el("p", null, "Size of the Windows drive, in GB. 3000 is 3 TB. The kit uses the rest of the disk."));
          modelsWrap.appendChild(modelsSize);
          box.appendChild(modelsWrap);
          box.appendChild(windowsNote);
          function paintWindows() {
            var on = windowsTick.checked;
            modelsWrap.style.display = on ? "" : "none";
            sizeWrap.style.display = on ? "none" : "";
            if (on) {
              choices.sizeGB = 0;
              size.value = "";
              if (!choices.modelsGB) choices.modelsGB = Number(modelsSize.value) || 3000;
            } else {
              choices.modelsGB = 0;
            }
            paintPlan();
          }
          windowsTick.addEventListener("change", paintWindows);
          paintWindows();
        }
        var label = el("label", "check");
        var tick = document.createElement("input");
        tick.type = "checkbox";
        label.appendChild(tick);
        label.appendChild(document.createTextNode("I understand this deletes the items listed above."));
        box.appendChild(label);
        if (index > 0) backButton();
        var go = el("button", "primary", "Erase");
        go.type = "button";
        go.disabled = true;
        tick.addEventListener("change", function () { go.disabled = !tick.checked; });
        go.addEventListener("click", function () {
          if (choices.eraseMode === "disk" && windowsTick && windowsTick.checked && !(Number(choices.modelsGB) >= 200)) {
            box.appendChild(el("p", "warn", "The Windows drive needs at least 200 GB."));
            return;
          }
          var send = { mode: choices.eraseMode, partitionId: choices.partitionId, sizeGB: Number(choices.sizeGB) || 0, modelsGB: Number(choices.modelsGB) || 0, confirmed: true };
          var err = prepareError(disk, send);
          if (err) { box.appendChild(el("p", "warn", err)); return; }
          startPrepare(disk, send);
        });
        nav.appendChild(go);
      }

      function startPrepare(disk, send) {
        nav.textContent = "";
        box.textContent = "";
        head.textContent = "Erasing";
        box.appendChild(el("h1", null, "Preparing the drive"));
        box.appendChild(el("p", null, "Leave the installer window open. Closing it stops the erase."));
        var pre = el("pre", "log", "Starting…");
        box.appendChild(pre);
        fetch("/api/prepare", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            disk: disk.id,
            mode: send.mode,
            partitionId: send.partitionId || "",
            sizeGB: send.sizeGB || 0,
            modelsGB: send.modelsGB || 0,
            diskSizeGB: Number(disk.sizeGB) || 0,
            confirmed: true
          })
        }).then(function (r) {
          if (!r.ok) return r.text().then(function (t) { throw new Error(t || ("HTTP " + r.status)); });
          pollPrepare();
        }).catch(function (e) {
          pre.textContent = "Could not start the erase. " + (e.message || "");
        });
        function pollPrepare() {
          fetch("/api/log", { cache: "no-store" }).then(function (r) { return r.json(); }).then(function (data) {
            pre.textContent = data.text || (data.running ? "Working…" : "");
            pre.scrollTop = pre.scrollHeight;
            if (data.running) { setTimeout(pollPrepare, 1000); return; }
            var mount = "";
            var match = String(data.text || "").match(/PREPARED\s+(\S.*)$/m);
            if (match) mount = match[1].trim();
            if (data.exit === 0 && mount) {
              var part = (disk.partitions || []).filter(function (p) { return p.id === send.partitionId; })[0];
              var plan = windowsDrivePlan(disk.sizeGB, send.sizeGB, send.modelsGB);
              var madeGB = send.mode === "partition" && part ? Number(part.sizeGB) : (plan.models ? plan.kit : (Number(send.sizeGB) || Number(disk.sizeGB) || 0));
              choices.path = driveFolder(mount);
              choices.driveFreeGB = madeGB;
              choices.place = "ready";
              var readyText = "The drive is formatted. Next you will choose the AI and the library. Nothing else is downloaded until you press Install.";
              if (plan.models) readyText = "OFFLINEAI is for the kit. AI-DRIVE is for a Windows PC to store LLM models. Next you will choose the AI and the library. Nothing else is downloaded until you press Install.";
              box.appendChild(el("p", "ok", readyText));
              var next = el("button", "primary", "Continue");
              next.type = "button";
              next.addEventListener("click", function () { goAfter("where"); });
              nav.appendChild(next);
              return;
            }
            box.appendChild(el("p", "warn", "The erase did not finish. The disk was not changed if the message above says it was refused. You can go back and try again."));
          }).catch(function () {
            pre.textContent += "\nThe installer window was closed, so this page cannot see the rest.";
          });
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
        if (choices.wikiNow) {
          box.appendChild(el("p", null, "This is the big one: about 127 GB, with pictures. On the drive you picked, it downloads now, before this page says the drive is ready. That can take many hours. Leave the drive plugged in. If the internet drops, run this installer again. The finished part is kept."));
        } else {
          box.appendChild(el("p", null, "This is the big one: about 127 GB, with pictures. It downloads in the background the first time you start the kit. Chat and the smaller library work while it downloads. If the internet drops, the next start continues where it stopped."));
        }
        if (!ctx.suggestedWikipedia) {
          box.appendChild(el("p", "warn", "This drive does not have a lot of free space, so the suggestion is No. You can add Wikipedia later when you have about 140 GB free."));
        }
        var yesDetail = choices.wikiNow
          ? "About 127 GB, downloaded now, before this page says the drive is ready."
          : "About 127 GB, in the background. Suggested when the drive has room.";
        chooseCards([
          { id: "yes", name: "Yes, download Wikipedia", detail: yesDetail, recommended: !!ctx.suggestedWikipedia },
          { id: "no", name: "No, skip Wikipedia", detail: "The smaller library is still installed. You can add Wikipedia later.", recommended: !ctx.suggestedWikipedia }
        ], choices.wikipedia ? "yes" : "no", function (id) {
          choices.wikipedia = id === "yes";
          choices.wikiNow = id === "yes";
        });
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
        var suggestAll = !!choices.suggestUniversal;
        chooseCards([
          { id: "this", name: "This computer only", detail: suggestAll ? "Smaller and faster to download." : "Suggested. You can still copy the folder later.", recommended: !suggestAll },
          { id: "all", name: "All computers (one drive)", detail: "About " + extra + " more, for the other computers' programs. Use an exFAT drive if Windows, Mac, and Linux will all open it.", recommended: suggestAll }
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
        if (est.tooBig && choices.wikiNow) box.appendChild(el("p", "warn", "This drive does not have room for Wikipedia and these choices. Go back and pick a larger drive, a smaller AI, or skip Wikipedia."));
        else if (est.tooBig) box.appendChild(el("p", "warn", "There is not enough free space for these choices. Go back and pick a smaller AI, skip Wikipedia, or remove extras and maps."));
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
            universal: !!choices.universal,
            path: choices.path || "",
            wikiNow: !!(choices.wikiNow && choices.wikipedia)
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
            var ready = /RESULT: (START OK|SETUP OK|DRIVE READY)/.test(data.text || "");
            if (data.running && !ready) { setTimeout(poll, 1000); return; }
            var onDrive = !!(choices.wikiNow && choices.wikipedia && choices.path);
            var ok = data.exit === 0 || (data.running && ready);
            var message;
            if (ok && onDrive && choices.macImage) message = "This drive is ready. Wikipedia and the guides are on it. You can unplug it. Next time, plug it into a Windows, Mac, or Linux computer, open Click these, then 3 Start. No network is needed then.";
            else if (ok && onDrive) message = "This drive is ready. Wikipedia and the guides are on it. You can unplug it. Next time, open the drive, then Click these, then 3 Start.";
            else if (ok) message = "Finished. If a browser did not open, use Click these, then 3 Start.";
            else message = "The installer stopped before it finished. Read the details above. Run the installer again to continue. Finished downloads are kept.";
            var done = el("p", ok ? "ok" : "warn", message);
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
    estimate: estimate, defaultChoices: defaultChoices, gbText: gbText,
    GUIDE_EXTRAS: GUIDE_EXTRAS, driveFolder: driveFolder, fat32Blocked: fat32Blocked,
    usableDrive: usableDrive, externalReady: externalReady, offerFor: offerFor,
    everyComputerChoices: everyComputerChoices, macCopyGB: macCopyGB,
    prepareError: prepareError, eraseNames: eraseNames
  };
  if (typeof module !== "undefined" && module.exports) module.exports = api;
  else root.InstallWizard = api;
  if (typeof root.document !== "undefined" && root.document.getElementById && root.document.getElementById("wizard")) boot();
})(typeof window !== "undefined" ? window : this);
