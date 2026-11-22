/*
 * Emergency first aid. Big topics that search the offline library.
 * This file does not contain treatment steps. The articles in the library are the source.
 * Works in the browser (window.FirstAid) and in Node (module.exports).
 */
(function (root) {
  "use strict";

  var TOPICS = [
    { id: "bleeding", group: "Body", title: "Severe bleeding", query: "severe bleeding hemorrhage direct pressure first aid" },
    { id: "breathing", group: "Body", title: "Not breathing", query: "cardiopulmonary resuscitation CPR not breathing" },
    { id: "choking", group: "Body", title: "Choking", query: "choking airway obstruction abdominal thrusts" },
    { id: "burns", group: "Body", title: "Burns", query: "burn first aid thermal burn" },
    { id: "bones", group: "Body", title: "Broken bone", query: "fracture broken bone splint first aid" },
    { id: "poison", group: "Body", title: "Poison or overdose", query: "poisoning overdose first aid" },
    { id: "allergy", group: "Body", title: "Severe allergic reaction", query: "anaphylaxis severe allergic reaction first aid" },
    { id: "chest", group: "Body", title: "Chest pain or stroke", query: "heart attack stroke warning signs" },
    { id: "heat", group: "Body", title: "Too hot", query: "heat stroke heat exhaustion first aid" },
    { id: "cold", group: "Body", title: "Too cold", query: "hypothermia frostbite first aid" },
    { id: "water", group: "Around you", title: "Clean water", query: "purify drinking water emergency disinfection" },
    { id: "power", group: "Around you", title: "Power is out", query: "power outage food safety stay warm" },
    { id: "shelter", group: "Around you", title: "Shelter and warmth", query: "emergency shelter warmth cold" }
  ];

  var PREFER = ["llama3.2:3b", "medgemma:4b", "phi4-mini", "qwen3.5:9b", "gemma3:4b"];

  function pickModel(names) {
    names = names || [];
    for (var i = 0; i < PREFER.length; i++) {
      if (names.indexOf(PREFER[i]) !== -1) return PREFER[i];
    }
    return names.length ? names[0] : "";
  }

  function linksFromSearch(base, results, limit) {
    base = String(base || "").replace(/\/+$/, "");
    var out = [], list = (results || []).slice(0, limit || 5);
    list.forEach(function (r) {
      if (!r || !r.path) return;
      var path = String(r.path).charAt(0) === "/" ? String(r.path) : "/" + r.path;
      out.push({ title: r.title || "Library article", book: r.book || "", url: base + path });
    });
    return out;
  }

  function el(tag, cls, text) {
    var node = document.createElement(tag);
    if (cls) node.className = cls;
    if (text != null) node.textContent = text;
    return node;
  }

  function boot() {
    var app = document.getElementById("aid-app");
    if (!app || !root.AskLibrary) return;
    var CFG = root.KIT_CONFIG || {};
    var EP = root.AskLibrary.endpoints(location, CFG);
    var home = document.getElementById("topic-home");
    var result = document.getElementById("topic-result");
    var groups = {};
    TOPICS.forEach(function (t) {
      if (!groups[t.group]) groups[t.group] = [];
      groups[t.group].push(t);
    });
    Object.keys(groups).forEach(function (name) {
      home.appendChild(el("h2", null, name));
      var grid = el("div", "grid");
      groups[name].forEach(function (topic) {
        var b = el("button", "topic", topic.title);
        b.type = "button";
        b.addEventListener("click", function () { openTopic(topic); });
        grid.appendChild(b);
      });
      home.appendChild(grid);
    });

    function showHome() {
      result.hidden = true;
      result.textContent = "";
      home.hidden = false;
    }

    function openTopic(topic) {
      home.hidden = true;
      result.hidden = false;
      result.textContent = "";
      var back = el("button", "back", "Back to emergencies");
      back.type = "button";
      back.addEventListener("click", showHome);
      result.appendChild(back);
      result.appendChild(el("h2", null, topic.title));
      var status = el("p", "status", "Searching the offline library…");
      result.appendChild(status);
      var linkBox = el("div", "links");
      result.appendChild(linkBox);
      var answer = el("div", "answer");
      result.appendChild(answer);

      var lib = new root.AskLibrary.Library(EP.library, { maxSources: 3 });
      lib.search(topic.query).then(function (found) {
        var links = linksFromSearch(EP.library, found.results, 5);
        if (!links.length) {
          status.textContent = "Nothing in the offline library matched this yet. The library may still be starting, or this collection is not installed. Open the library and search there, or go back and try the full chat.";
          return null;
        }
        status.textContent = "Library articles. Read these. A short summary is written underneath after the AI reads them.";
        links.forEach(function (s, i) {
          var a = el("a", "article", (i + 1) + ". " + s.title);
          a.href = s.url;
          a.target = "_blank";
          a.rel = "noopener";
          if (s.book) a.appendChild(el("span", "from", " — " + s.book));
          linkBox.appendChild(a);
        });
        return lib.gather(topic.query, found).then(function (sources) {
          if (!sources.length) {
            answer.appendChild(el("p", "note", "The articles are above. The AI did not get a clear passage to summarize. Read the articles."));
            return;
          }
          return fetch(EP.ollama + "/api/tags").then(function (r) { return r.json(); }).then(function (data) {
            var names = ((data && data.models) || []).map(function (m) { return m.name; });
            var model = pickModel(names);
            if (!model) {
              answer.appendChild(el("p", "note", "The AI is not running, so there is no summary. The articles above are still the right place to read."));
              return;
            }
            var note = el("p", "status", "Writing a short summary from those articles…");
            answer.appendChild(note);
            var messages = root.AskLibrary.buildMessages(topic.query, sources);
            return root.AskLibrary.ollamaChat(EP.ollama, model, messages, function (acc) {
              note.textContent = acc;
            }).then(function (raw) {
              var done = root.AskLibrary.finish(topic.query, raw, sources, found);
              note.textContent = "";
              if (done.status !== "answered") {
                note.textContent = "The articles above are the source. The AI did not produce a summary it could tie to them.";
                return;
              }
              answer.appendChild(el("h3", null, "Summary from those articles"));
              answer.appendChild(el("div", "summary", done.answer));
              answer.appendChild(el("p", "note", "Written by the AI from the articles above. It can be wrong. Read the article. This is not a doctor."));
            });
          });
        });
      }).catch(function (e) {
        status.textContent = "Could not reach the library or the AI (" + (e && e.message ? e.message : "it is not running") + "). Double-click Start in the Click these folder, wait until the chat page opens, then try this screen again.";
      });
    }
  }

  var api = { TOPICS: TOPICS, pickModel: pickModel, linksFromSearch: linksFromSearch };
  if (typeof module !== "undefined" && module.exports) module.exports = api;
  else root.FirstAid = api;
  if (typeof root.document !== "undefined" && root.document.getElementById && root.document.getElementById("aid-app")) boot();
})(typeof window !== "undefined" ? window : this);
