/*
 * Offline AI Kit - "Ask the library" (answers with sources).
 *
 * How it works (no extra programs, no index to build):
 *   1. Ask the local library server (kiwix-serve) which collections it has and which can be searched.
 *   2. Search each collection with kiwix-serve's built-in full-text search (/search?...&format=xml).
 *   3. Download the best few articles from kiwix-serve, turn them into plain text, keep the
 *      paragraphs that match the question, and number them [1], [2], [3].
 *   4. Ask the local AI (Ollama) to answer ONLY from those numbered passages.
 *   5. Check the answer: any [n] that is not one of the articles we actually fetched is removed,
 *      and invented links are removed. Only fetched articles are ever listed as sources.
 *
 * kiwix-serve 3.x sends "Access-Control-Allow-Origin: *", so the page can read it directly,
 * both when served from http://127.0.0.1:8091 (Windows) and when opened as a file (Mac).
 *
 * Works in a browser (window.AskLibrary) and in Node 18+ (module.exports) for automated tests.
 */
(function (root) {
  "use strict";

  var STOP = ("a about above after again against all am an and any are as at be because been before being below between both but by " +
    "can could did do does doing done down during each few for from further get got had has have having he her here hers him his how " +
    "i if in into is it its itself just know let like make me more most my no nor not now of off on once only or other our out over " +
    "own please same she should so some such tell than that the their them then there these they this those through to too under " +
    "until up us use used using very want was way we were what when where which while who whom why will with would you your yours " +
    "best good need needs thing things something someone anything help explain describe show give find info information").split(" ");
  // Words that help the text search but say little about which article is right ("treat", "stop", "signs").
  var WEAK = {};
  ("treat treating treatment treatments fix fixing repair stop stopping cause causes sign signs symptom symptoms way ways " +
   "tip tips safe safely quick quickly mild severe heavy bad deal prevent prevention care step steps long time").split(" ").forEach(function (w) { WEAK[w] = true; });
  var STOPSET = {};
  STOP.forEach(function (w) { STOPSET[w] = true; });

  // Section headings after which a Wikipedia-style article is only lists of links / references.
  var END_SECTIONS = /^(references|external links|see also|notes|further reading|bibliography|sources|footnotes|citations)$/i;
  // Elements whose text is never useful as a passage.
  var SKIP_TAGS = { script: 1, style: 1, noscript: 1, sup: 1, figure: 1, figcaption: 1, nav: 1, math: 1, svg: 1, table: 1, button: 1, form: 1, select: 1, iframe: 1, head: 1, title: 1 };
  var SKIP_CLASS = /(^|\s)(navbox|reflist|references|reference|mw-editsection|metadata|hatnote|noprint|thumb|infobox|mw-references-wrap|toc|catlinks|printfooter|mw-jump-link|vertical-navbox|sistersitebox|shortdescription)(\s|$)/i;
  var VOID = { area: 1, base: 1, br: 1, col: 1, embed: 1, hr: 1, img: 1, input: 1, link: 1, meta: 1, source: 1, track: 1, wbr: 1 };
  var BLOCK = /^(p|div|li|ul|ol|dl|dd|dt|h[1-6]|br|tr|section|article|blockquote|pre|details|summary|header|footer|main)$/;

  function decodeEntities(s) {
    return String(s)
      .replace(/&#x([0-9a-f]+);/gi, function (_, h) { var c = parseInt(h, 16); return c > 0 && c < 0x110000 ? String.fromCodePoint(c) : ""; })
      .replace(/&#(\d+);/g, function (_, d) { var c = parseInt(d, 10); return c > 0 && c < 0x110000 ? String.fromCodePoint(c) : ""; })
      .replace(/&nbsp;/g, " ").replace(/&quot;/g, "\"").replace(/&apos;/g, "'").replace(/&#39;/g, "'")
      .replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&ndash;/g, "\u2013").replace(/&mdash;/g, "\u2014")
      .replace(/&amp;/g, "&");
  }

  // Question -> search keywords (lower case, no filler words, max 8).
  function keywords(question) {
    var words = String(question).toLowerCase().replace(/[\u2019']/g, "'").match(/[a-z0-9][a-z0-9'\-]*/g) || [];
    var out = [];
    words.forEach(function (w) {
      w = w.replace(/'s$/, "").replace(/^'+|'+$/g, "").replace(/^-+|-+$/g, "");
      if (w.length < 3 && !/^\d+$/.test(w)) return;
      if (STOPSET[w]) return;
      if (out.indexOf(w) === -1) out.push(w);
    });
    return out.slice(0, 8);
  }
  // Rough stem so "bleeding" matches "bleed" and "burns" matches "burn".
  function stem(w) {
    w = w.toLowerCase();
    if (w.length > 5) w = w.replace(/(ings|ing|ed|es|s)$/, "");
    else if (w.length > 3) w = w.replace(/s$/, "");
    return w;
  }
  var reCache = {};
  function stemRe(s) {
    if (!reCache[s]) reCache[s] = new RegExp("(^|[^a-z0-9])" + s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"), "i");
    return reCache[s];
  }
  // How many of the keyword stems appear (at the start of a word) in the text.
  function countHits(text, stems) {
    var t = String(text), n = 0;
    stems.forEach(function (s) { if (s && stemRe(s).test(t)) n++; });
    return n;
  }

  // HTML article -> plain text paragraphs. Small tag-aware scanner (same result in every browser and in Node).
  function htmlToText(html) {
    html = String(html);
    var body = html.search(/<body[\s>]/i);
    if (body !== -1) html = html.slice(body);
    html = html.replace(/<!--[\s\S]*?-->/g, "");
    var re = /<(\/?)([a-zA-Z][a-zA-Z0-9]*)([^>]*)>/g, last = 0, m, out = [], skip = null, skipDepth = 0, stopped = false;
    var headingOpen = null, headingText = "";
    while ((m = re.exec(html)) && !stopped) {
      var textChunk = html.slice(last, m.index);
      last = re.lastIndex;
      if (!skip) {
        out.push(textChunk);
        if (headingOpen) headingText += textChunk;
      }
      var closing = m[1] === "/", tag = m[2].toLowerCase(), attrs = m[3] || "";
      var selfClose = /\/\s*$/.test(attrs) || VOID[tag];
      if (skip) {
        if (tag === skip) {
          if (closing) { skipDepth--; if (skipDepth === 0) skip = null; }
          else if (!selfClose) skipDepth++;
        }
        continue;
      }
      if (!closing && !selfClose) {
        var cls = (attrs.match(/\bclass\s*=\s*("([^"]*)"|'([^']*)')/i) || [])[2] || (attrs.match(/\bclass\s*=\s*'([^']*)'/i) || [])[1] || "";
        var role = (attrs.match(/\brole\s*=\s*"([^"]*)"/i) || [])[1] || "";
        if (SKIP_TAGS[tag] || SKIP_CLASS.test(cls) || /navigation|note/i.test(role) || /\bhidden\b|display\s*:\s*none/i.test(attrs)) {
          skip = tag; skipDepth = 1; continue;
        }
      }
      if (/^h[1-6]$/.test(tag)) {
        if (!closing) { headingOpen = tag; headingText = ""; out.push("\n\n## "); }
        else if (headingOpen) {
          var ht = decodeEntities(headingText).replace(/\s+/g, " ").trim();
          headingOpen = null;
          if (END_SECTIONS.test(ht)) { out.push("\n"); stopped = true; break; }
          out.push("\n");
        }
        continue;
      }
      if (tag === "li" && !closing) out.push("\n- ");
      else if (BLOCK.test(tag)) out.push("\n");
      else if (tag === "td" || tag === "th") out.push(" ");
    }
    if (!stopped && !skip) out.push(html.slice(last));
    var text = decodeEntities(out.join(""))
      .replace(/^.*\b(This (page|article) is issued from|Retrieved from|is available under Creative Commons)\b.*$/gim, "")
      .replace(/\[\s*(\d+|[a-z]|edit|citation needed|note \d+)\s*\]/gi, "") // leftover [1] / [edit] markers
      .replace(/[ \t\r\f\v\u00a0]+/g, " ")
      .replace(/ *\n */g, "\n")
      .replace(/\n{3,}/g, "\n\n");
    return text.trim();
  }

  // Keep the lead paragraph plus the paragraphs that best match the question, in article order.
  function selectPassages(text, stems, budget) {
    var paras = String(text).split(/\n+/).map(function (p) { return p.trim(); }).filter(function (p) { return p && !/^##\s*$/.test(p) && p.length > 2; });
    if (!paras.length) return { text: "", hits: 0 };
    var scored = paras.map(function (p, i) { return { i: i, p: p, s: countHits(p, stems) + (i === 0 ? 0.5 : 0) - (p.length < 40 ? 0.4 : 0) }; });
    var firstReal = scored.find(function (x) { return !/^##/.test(x.p) && x.p.length >= 40; }) || scored[0];
    var chosen = {}, used = 0;
    function take(x) {
      if (chosen[x.i] || used >= budget) return;
      var p = x.p;
      if (used + p.length > budget) p = p.slice(0, Math.max(0, budget - used)).replace(/\s+\S*$/, "") + "\u2026";
      chosen[x.i] = p; used += p.length + 1;
    }
    take(firstReal);
    scored.slice().sort(function (a, b) { return b.s - a.s || a.i - b.i; }).forEach(function (x) { if (x.s >= 1) take(x); });
    scored.forEach(function (x) { if (used < budget * 0.6 && !/^##/.test(x.p)) take(x); });
    var keys = Object.keys(chosen).map(Number).sort(function (a, b) { return a - b; });
    var joined = keys.map(function (k) { return chosen[k]; }).join("\n");
    return { text: joined, hits: countHits(joined, stems) };
  }

  function parseCatalog(xml) {
    var books = [], re = /<entry>([\s\S]*?)<\/entry>/g, m;
    while ((m = re.exec(xml))) {
      var e = m[1];
      var title = decodeEntities(((e.match(/<title>([\s\S]*?)<\/title>/) || [])[1] || "").trim());
      var tags = ((e.match(/<tags>([\s\S]*?)<\/tags>/) || [])[1] || "");
      var href = ((e.match(/<link[^>]*type="text\/html"[^>]*href="([^"]+)"/) || e.match(/<link[^>]*href="([^"]+)"[^>]*type="text\/html"/) || [])[1] || "");
      var id = decodeEntities(href).replace(/^\/content\//, "").replace(/\/.*$/, "");
      if (!id) continue;
      var count = parseInt(((e.match(/<articleCount>(\d+)<\/articleCount>/) || [])[1] || "0"), 10);
      books.push({ id: id, title: title || id, searchable: !/_ftindex:no/.test(tags), articles: count });
    }
    return books;
  }

  function parseSearch(xml, book) {
    var items = [], re = /<item>([\s\S]*?)<\/item>/g, m, rank = 0;
    while ((m = re.exec(xml))) {
      var it = m[1];
      var title = decodeEntities(((it.match(/<title>([\s\S]*?)<\/title>/) || [])[1] || "").trim());
      var link = decodeEntities(((it.match(/<link>([\s\S]*?)<\/link>/) || [])[1] || "").trim());
      var bookTitle = decodeEntities(((it.match(/<book>\s*<title>([\s\S]*?)<\/title>/) || [])[1] || (book && book.title) || "").trim());
      if (!link || link.indexOf("/content/") !== 0) continue;
      items.push({ title: title, path: link, book: bookTitle, bookId: book ? book.id : "", rank: rank++ });
    }
    return items;
  }

  // ---------- Citation checking: the safety net against invented sources ----------
  // Keeps only [n] markers where 1 <= n <= sourceCount. Handles [1], [1,2], [1-3], [1][2], (1) is left alone.
  function validateCitations(answer, sourceCount) {
    var removed = [], used = [];
    var text = String(answer).replace(/\[\s*(?:source\s*|ref\s*)?(\d{1,3}(?:\s*(?:,|;|\u2013|-|and)\s*(?:source\s*)?\d{1,3})*)\s*\]/gi, function (whole, inner) {
      var nums = [];
      var parts = inner.split(/\s*(?:,|;|and)\s*/i);
      parts.forEach(function (p) {
        var r = p.match(/^(\d+)\s*(?:\u2013|-)\s*(\d+)$/);
        if (r) { for (var k = +r[1]; k <= +r[2] && k - r[1] < 20; k++) nums.push(k); }
        else nums.push(parseInt(p.replace(/\D/g, ""), 10));
      });
      var good = [];
      nums.forEach(function (n) {
        if (n >= 1 && n <= sourceCount) { if (good.indexOf(n) === -1) good.push(n); }
        else removed.push(n);
      });
      good.forEach(function (n) { if (used.indexOf(n) === -1) used.push(n); });
      return good.map(function (n) { return "[" + n + "]"; }).join("");
    });
    // Drop a "Sources:/References:" list the model may have written itself, and any web links (we are offline).
    text = text.replace(/\n+\s*(?:\*\*)?(?:sources?|references?|citations?|bibliography)(?:\*\*)?\s*:?\s*(?:\*\*)?\s*\n[\s\S]*$/i, "\n");
    text = text.replace(/\bhttps?:\/\/[^\s)\]]+/gi, function (u) { removed.push(u); return ""; });
    text = text.replace(/[ \t]+([.,;:])/g, "$1").replace(/[ \t]{2,}/g, " ").trim();
    used.sort(function (a, b) { return a - b; });
    return { text: text, used: used, removed: removed };
  }

  function looksMedical(s) {
    return /\b(bleed|blood|wound|burn|fractur|broken bone|poison|overdose|dose|dosage|medic|drug|pill|tablet|pain|fever|infect|cpr|unconscious|breath|chok|heart|stroke|seizure|allerg|anaphyla|diabet|insulin|pregnan|injur|sprain|bite|sting|hypotherm|frostbite|heat ?stroke|dehydrat|diarrh|vomit|first aid|antibiotic|sick|illness|disease|symptom|doctor|hospital|emergency)/i.test(s);
  }

  var SYSTEM_LIBRARY = [
    "You answer questions using ONLY the numbered library sources given to you.",
    "Put the source number in square brackets after each sentence that uses it, like [1] or [2]. Use only the numbers of the sources given.",
    "Do not add facts, numbers, doses, links or sources that are not in the sources. Do not write a list of sources at the end.",
    "If the sources answer only part of the question, answer that part and say what the sources do not cover.",
    "Only if the sources say nothing useful about the question, reply with exactly: NOT_IN_LIBRARY",
    "Write clear, practical, step-by-step advice in plain language. Flag dangers.",
    "For medical, first-aid or medication questions: be cautious, never invent doses, and say when to get emergency help or a professional.",
    "You are running offline on this computer, possibly during an outage."
  ].join(" ");

  function buildMessages(question, sources) {
    var parts = sources.map(function (s, i) {
      return "[" + (i + 1) + "] " + s.title + " (from: " + s.book + ")\n" + s.text;
    });
    var user = "LIBRARY SOURCES:\n\n" + parts.join("\n\n") +
      "\n\nQUESTION: " + question +
      "\n\nAnswer using only sources [1] to [" + sources.length + "], with the [number] after each sentence. If they say nothing useful about the question, reply NOT_IN_LIBRARY.";
    return [{ role: "system", content: SYSTEM_LIBRARY }, { role: "user", content: user }];
  }

  // ---------- network helpers ----------
  function withTimeout(ms) {
    if (typeof AbortController === "undefined") return {};
    var c = new AbortController();
    var t = setTimeout(function () { try { c.abort(); } catch (e) { /* ignore */ } }, ms);
    return { signal: c.signal, _timer: t };
  }
  function getText(url, ms) {
    var opts = withTimeout(ms || 15000), timer = opts._timer;
    delete opts._timer;
    opts.cache = "no-store";
    function done(x) { if (timer) clearTimeout(timer); return x; }
    return fetch(url, opts).then(function (r) {
      if (!r.ok) { var e = new Error("HTTP " + r.status); e.status = r.status; throw e; }
      return r.text();
    }).then(done, function (e) { done(); throw e; });
  }

  function getPage(url, ms) {
    var opts = withTimeout(ms || 20000), timer = opts._timer;
    delete opts._timer;
    opts.cache = "no-store";
    return fetch(url, opts).then(function (r) {
      if (timer) clearTimeout(timer);
      if (!r.ok) { var e = new Error("HTTP " + r.status); e.status = r.status; throw e; }
      var finalUrl = r.url || url;
      return r.text().then(function (t) { return { text: t, url: finalUrl }; });
    }, function (e) { if (timer) clearTimeout(timer); throw e; });
  }
  function encodePath(p) { return String(p).split("/").map(function (x) { return encodeURIComponent(x); }).join("/"); }
  function parseSuggest(json, book) {
    var arr; try { arr = JSON.parse(json); } catch (e) { return []; }
    if (!Array.isArray(arr)) return [];
    return arr.filter(function (x) { return x && x.kind === "path" && x.path; }).map(function (x, i) {
      return { title: decodeEntities(x.value || x.path), path: "/content/" + encodeURIComponent(book.id) + "/" + encodePath(x.path), book: book.title, bookId: book.id, rank: i };
    });
  }
  function totalOf(xml) { var m = String(xml).match(/<opensearch:totalResults>(\d+)</); return m ? parseInt(m[1], 10) : 0; }

  function Library(base, opts) {
    this.base = String(base).replace(/\/+$/, "");
    this.opts = opts || {};
    this.books = null;
  }
  Library.prototype.url = function (path) { return this.base + path; };
  Library.prototype.loadBooks = function () {
    var self = this;
    return getText(self.url("/catalog/v2/entries?count=-1"), 10000).then(function (xml) {
      self.books = parseCatalog(xml);
      return self.books;
    });
  };
  // Search every searchable collection (in parallel) and merge into one ranked list.
  // kiwix-serve's full-text search needs ALL words to match, so we also search single words and
  // look up article titles (suggest), then score everything ourselves.
  Library.prototype.search = function (question) {
    var self = this;
    var kws = keywords(question).slice(0, 6);
    var stems = kws.map(stem);
    var strong = kws.filter(function (w) { return !WEAK[w]; }).map(stem);
    if (!strong.length) strong = stems;
    if (!kws.length) return Promise.resolve({ keywords: kws, stems: stems, results: [], searched: 0 });
    var booksP = self.books ? Promise.resolve(self.books) : self.loadBooks();
    return booksP.then(function (books) {
      var searchable = books.filter(function (b) { return b.searchable; });
      var cands = {};
      function add(r, pts, why) {
        var k = r.path;
        if (!cands[k]) { cands[k] = r; r.score = 0; r.why = []; }
        cands[k].score += pts; cands[k].why.push(why);
      }
      function ft(b, words, len) {
        return getText(self.url("/search?content=" + encodeURIComponent(b.id) + "&pattern=" + encodeURIComponent(words) + "&format=xml&pageLength=" + len), 20000)
          .then(function (xml) { return { total: totalOf(xml), items: parseSearch(xml, b) }; }, function () { return { total: 0, items: [] }; });
      }
      function sg(b, term) {
        return getText(self.url("/suggest?content=" + encodeURIComponent(b.id) + "&term=" + encodeURIComponent(term) + "&count=4"), 10000)
          .then(function (j) { return parseSuggest(j, b); }, function () { return []; });
      }
      var phrases = kws.slice();
      for (var i = 0; i + 1 < kws.length; i++) phrases.push(kws[i] + " " + kws[i + 1]);
      return Promise.all(searchable.map(function (b) {
        return ft(b, kws.join(" "), 8).then(function (all) {
          var weight = Math.min(1, Math.log(1 + all.total) / Math.LN10 / 2);
          all.items.forEach(function (r) { add(r, (5 - r.rank * 0.4) * weight, "all"); });
          var jobs = phrases.map(function (ph) {
            return sg(b, ph).then(function (list) {
              var n = ph.split(" ").length;
              list.forEach(function (r) {
                var t = r.title.toLowerCase().replace(/[_,()]/g, " ").replace(/\s+/g, " ").trim();
                if (t === ph || stem(t) === stem(ph)) add(r, 6 * n, "title=" + ph);
                else add(r, 1.2 * n - r.rank * 0.2, "title~" + ph);
              });
            });
          });
          if (kws.length > 1 && all.total < 5) {
            jobs = jobs.concat(kws.map(function (w) {
              return ft(b, w, 4).then(function (one) {
                var wt = 1 / (1 + Math.log(1 + one.total) / Math.LN10 / 3);
                one.items.forEach(function (r) { add(r, (2 - r.rank * 0.3) * wt, "word=" + w); });
              });
            }));
          }
          return Promise.all(jobs);
        });
      })).then(function () {
        var all = Object.keys(cands).map(function (k) { return cands[k]; });
        all.forEach(function (r) {
          var t = r.title.toLowerCase();
          var tWords = t.split(/[^a-z0-9]+/).filter(Boolean);
          var covered = tWords.filter(function (w) { return strong.some(function (s) { return w.indexOf(s) === 0; }); }).length;
          r.titleHits = countHits(t, strong);
          r.score += r.titleHits * 1.5 + (tWords.length ? covered / tWords.length : 0) * 2.5
                    - (/^(list|index|outline|glossary|timeline) of\b/i.test(r.title) ? 3 : 0) - (/^(home|main page|index)$/i.test(r.title) ? 4 : 0) - (/\(disambiguation\)/i.test(r.title) ? 6 : 0);
        });
        all.sort(function (a, b) { return b.score - a.score; });
        return { keywords: kws, stems: stems, strong: strong, results: all, searched: searchable.length, books: books };
      });
    });
  };
  // Fetch the best articles and cut them down to the passages that matter.
  Library.prototype.gather = function (question, found) {
    var self = this;
    var maxSources = self.opts.maxSources || 3, totalBudget = self.opts.charBudget || 7500;
    var perBook = {}, picks = [];
    for (var i = 0; i < found.results.length && picks.length < maxSources + 3; i++) {
      var r = found.results[i];
      if ((perBook[r.bookId] || 0) >= 3) continue;
      perBook[r.bookId] = (perBook[r.bookId] || 0) + 1;
      picks.push(r);
    }
    var per = Math.floor(totalBudget / maxSources);
    var K = found.stems.length;
    return Promise.all(picks.map(function (r) {
      return getPage(self.url(r.path), 20000).then(function (pg) {
        var full = htmlToText(pg.text);
        var distinct = countHits(full, found.stems);
        var sel = selectPassages(full, found.stems, per);
        var titleMatch = (pg.text.match(/<title>([\s\S]*?)<\/title>/i) || [])[1];
        var title = titleMatch ? decodeEntities(titleMatch).trim() : r.title;
        var url = pg.url && pg.url.indexOf(self.base + "/content/") === 0 ? pg.url : self.url(r.path);
        return { title: title || r.title, book: r.book, path: url.slice(self.base.length), url: url, text: sel.text,
                 distinct: distinct, titleHits: Math.max(r.titleHits || 0, countHits(title, found.strong || found.stems)), score: r.score };
      }).catch(function () { return null; });
    })).then(function (arts) {
      var seen = {};
      arts = arts.filter(function (a) {
        if (!a || !a.text || a.text.length < 60) return false;
        if (/\(disambiguation\)|^(list|index|outline|glossary) of\b/i.test(a.title)) return false;
        var key = a.url + "|" + a.text.slice(0, 200);
        if (seen[a.url] || seen[key]) return false;
        seen[a.url] = seen[key] = true;
        return true;
      });
      // Relevant = the title matches a keyword, or the article contains at least half of the keywords.
      var need = Math.max(1, Math.ceil(K * 0.5));
      var relevant = arts.filter(function (a) { return a.titleHits >= 1 || a.distinct >= need; });
      relevant.forEach(function (a) { a.final = a.score + (K ? a.distinct / K : 0) * 3 + a.titleHits * 1.5; });
      relevant.sort(function (a, b) { return b.final - a.final; });
      // Drop weak extras: anything scoring under 40% of the best article.
      if (relevant.length) { var top = relevant[0].final; relevant = relevant.filter(function (a) { return a.final >= top * 0.4; }); }
      return relevant.slice(0, maxSources);
    });
  };

  // Streams a chat from Ollama. onToken(fullTextSoFar) is optional.
  function ollamaChat(api, model, messages, onToken, options) {
    return fetch(api + "/api/chat", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ model: model, messages: messages, stream: true, think: false, keep_alive: "5m", options: options || { temperature: 0.2, num_ctx: 8192, num_predict: 900 } })
    }).then(function (r) {
      if (!r.ok) return r.text().then(function (t) { throw new Error("HTTP " + r.status + " " + t); });
      var reader = r.body.getReader(), dec = new TextDecoder(), acc = "", buf = "";
      function pump() {
        return reader.read().then(function (res) {
          if (res.done) return acc;
          buf += dec.decode(res.value, { stream: true });
          var lines = buf.split("\n"); buf = lines.pop() || "";
          for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim(); if (!line) continue;
            var obj; try { obj = JSON.parse(line); } catch (e) { continue; }
            if (obj.error) throw new Error(obj.error);
            var piece = (obj.message && obj.message.content) || obj.response || "";
            if (piece) { acc += piece; if (onToken) onToken(acc); }
          }
          return pump();
        });
      }
      return pump();
    });
  }

  /*
   * Full "Ask the library" flow. Resolves to:
   *   { status: "answered", answer, sources:[{n,title,book,url}], cited:[n...], removed:[...], medical }
   *   { status: "not_found", reason: "no_results" | "not_relevant" | "model_said_no" | "no_keywords", searched, keywords }
   * Throws if the library or the AI cannot be reached.
   */
  function ask(cfg) {
    var lib = cfg.library instanceof Library ? cfg.library : new Library(cfg.libraryBase, cfg);
    var progress = cfg.onProgress || function () {};
    progress("Searching the offline library\u2026");
    return lib.search(cfg.question).then(function (found) {
      if (!found.keywords.length) return { status: "not_found", reason: "no_keywords", searched: found.searched, keywords: found.keywords };
      if (!found.results.length) return { status: "not_found", reason: "no_results", searched: found.searched, keywords: found.keywords };
      progress("Reading " + Math.min(found.results.length, (cfg.maxSources || 3) + 3) + " library articles\u2026");
      return lib.gather(cfg.question, found).then(function (sources) {
        if (!sources.length) return { status: "not_found", reason: "not_relevant", searched: found.searched, keywords: found.keywords };
        progress("Writing an answer from " + sources.length + " article(s)\u2026");
        var gen = cfg.generate ? cfg.generate(buildMessages(cfg.question, sources), sources)
                               : ollamaChat(cfg.ollamaBase, cfg.model, buildMessages(cfg.question, sources), cfg.onToken, cfg.ollamaOptions);
        return Promise.resolve(gen).then(function (raw) {
          return finish(cfg.question, raw, sources, found);
        });
      });
    });
  }
  function finish(question, raw, sources, found) {
    var cleaned = String(raw || "").replace(/<think>[\s\S]*?<\/think>/g, "").trim();
    if (!cleaned || /^\W*NOT_IN_LIBRARY\W*$/i.test(cleaned) || (/NOT_IN_LIBRARY/i.test(cleaned) && cleaned.length < 120)) {
      return { status: "not_found", reason: "model_said_no", searched: found ? found.searched : 0, keywords: found ? found.keywords : [], sources: sources.map(srcView) };
    }
    cleaned = cleaned.replace(/\s*NOT_IN_LIBRARY\s*/g, " ").trim();
    var v = validateCitations(cleaned, sources.length);
    return {
      status: "answered", answer: v.text, cited: v.used, removed: v.removed,
      sources: sources.map(srcView), medical: looksMedical(question + " " + v.text)
    };
    function srcView(s, i) { return { n: i + 1, title: s.title, book: s.book, url: s.url, path: s.path }; }
  }

  var api = {
    keywords: keywords, stem: stem, htmlToText: htmlToText, selectPassages: selectPassages,
    parseCatalog: parseCatalog, parseSearch: parseSearch, validateCitations: validateCitations,
    buildMessages: buildMessages, looksMedical: looksMedical, finish: finish,
    Library: Library, ask: ask, ollamaChat: ollamaChat, SYSTEM_LIBRARY: SYSTEM_LIBRARY
  };
  if (typeof module !== "undefined" && module.exports) module.exports = api;
  else root.AskLibrary = api;
})(typeof window !== "undefined" ? window : this);
