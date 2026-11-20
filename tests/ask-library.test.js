// Offline checks for www/ask-library.js (no servers needed): node tests/ask-library.test.js
"use strict";
const A = require("../www/ask-library.js");
let fails = 0;
function check(name, cond, extra) { console.log((cond ? "PASS " : "FAIL ") + name + (cond || extra === undefined ? "" : "  -> " + JSON.stringify(extra))); if (!cond) fails++; }

check("keywords drop filler words", JSON.stringify(A.keywords("How do I stop heavy bleeding from a deep cut?")) === JSON.stringify(["stop", "heavy", "bleeding", "deep", "cut"]), A.keywords("How do I stop heavy bleeding from a deep cut?"));
check("keywords empty for filler-only", A.keywords("how do I do it?").length === 0);

let v = A.validateCitations("Press hard [1]. Raise the leg [2, 7]. See [9]. Range [1-3].\nSources:\n[9] Fake Journal https://fake.example", 3);
check("forged [7] and [9] removed", v.text.indexOf("[7]") === -1 && v.text.indexOf("[9]") === -1 && v.removed.indexOf(7) !== -1 && v.removed.indexOf(9) !== -1, v);
check("valid markers kept", /\[1\]/.test(v.text) && /\[2\]/.test(v.text) && JSON.stringify(v.used) === "[1,2,3]", v);
check("model-written source list and links dropped", v.text.indexOf("Fake Journal") === -1 && v.text.indexOf("http") === -1, v.text);
check("[0] is not a valid source", A.validateCitations("x [0].", 2).text === "x.");

const html = '<html><head><title>Burn</title><style>.x{}</style></head><body><div class="hatnote">For other uses see Burn (disambiguation)</div>' +
  '<p>A <b>burn</b> is an injury to skin.<sup class="reference">[1]</sup></p><table class="infobox"><tr><td>Specialty</td></tr></table>' +
  '<h2>Treatment</h2><p>Cool the burn with running water for 20 minutes.</p><h2>References</h2><ol class="references"><li>Ref text</li></ol></body></html>';
const t = A.htmlToText(html);
check("html to text keeps article text", t.indexOf("A burn is an injury to skin.") !== -1 && t.indexOf("Cool the burn") !== -1, t);
check("html to text drops refs, hatnotes, infobox", t.indexOf("Ref text") === -1 && t.indexOf("disambiguation") === -1 && t.indexOf("Specialty") === -1 && t.indexOf("[1]") === -1, t);

const cat = '<feed><entry><title>Medical Library</title><tags>medical;_ftindex:no</tags><link type="text/html" href="/content/zimgit-medicine_en_2024-08" /></entry>' +
  '<entry><title>WikiMed</title><tags>medical;_ftindex:yes</tags><articleCount>5</articleCount><link type="text/html" href="/content/wikipedia_en_medicine_mini_2026-10" /></entry></feed>';
const books = A.parseCatalog(cat);
check("catalog: PDF-only collections are not searchable", books.length === 2 && !books[0].searchable && books[1].searchable && books[1].id === "wikipedia_en_medicine_mini_2026-10", books);

const srcs = [{ title: "Burn", book: "WikiMed", url: "http://127.0.0.1:8090/content/x/Burn", path: "/content/x/Burn", text: "..." }];
check("NOT_IN_LIBRARY -> not found", A.finish("q", "NOT_IN_LIBRARY", srcs, { searched: 1, keywords: ["q"] }).status === "not_found");
const f = A.finish("how to treat a burn", "Cool it [1]. Use butter [4].", srcs, { searched: 1, keywords: [] });
check("finish lists only fetched sources", f.sources.length === 1 && f.sources[0].url === srcs[0].url && f.removed.indexOf(4) !== -1 && f.medical === true, f);

const msgs = A.buildMessages("How?", srcs);
check("prompt numbers the sources", /\[1\] Burn \(from: WikiMed\)/.test(msgs[1].content) && /NOT_IN_LIBRARY/.test(msgs[0].content));

console.log(fails ? fails + " check(s) FAILED" : "All checks passed.");
process.exit(fails ? 1 : 0);
