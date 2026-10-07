// The master view's page: the headline (what real users need of the new API,
// and what the adopters still use from C), filters, and the two views (By API
// and By package) over Model's data. Everything the data supplies goes into
// the DOM as text (textContent), never as markup.
"use strict";
(function () {
  var PD = JSON.parse(document.getElementById("data").textContent);
  var M = Model.build(PD);
  var meta = M.meta, L = meta.labels, notes = M.notes;
  var CL = Model.CLUSTERS;
  var KD = ["migrated", "on-system", "scanned", "not-scanned", "no-swift"];
  var SPLIT = Model.SPLIT;
  var CATS = ["unexplained", "System gap", "queued", "exception", "undecided", "not System's", "standard library"];
  var F = Model.defaults();
  var tab = "api";
  var sortBy = "name";
  var openAreas = {}, openTypes = {}, openDecls = {}, openPkgs = {};
  var showAll = {};
  var RENDER_CAP = 300;
  var H = Model.headline(M);

  // ---------------------------------------------------------------- helpers

  function el(tag, attrs) {
    var e = document.createElement(tag);
    if (attrs) for (var k in attrs) {
      var v = attrs[k];
      if (v === null || v === undefined || v === false) continue;
      if (k === "text") e.textContent = v;
      else if (k === "cls") e.className = v;
      else if (k.slice(0, 2) === "on") e.addEventListener(k.slice(2), v);
      else e.setAttribute(k, v === true ? "" : v);
    }
    for (var i = 2; i < arguments.length; i++) add(e, arguments[i]);
    return e;
  }
  function add(e, c) {
    if (c === null || c === undefined || c === false) return;
    if (Array.isArray(c)) { c.forEach(function (x) { add(e, x); }); return; }
    e.appendChild(typeof c === "string" || typeof c === "number" ? document.createTextNode(String(c)) : c);
  }
  function svg(tag, attrs) {
    var e = document.createElementNS("http://www.w3.org/2000/svg", tag);
    for (var k in attrs || {}) {
      if (k === "text") e.textContent = attrs[k];
      else e.setAttribute(k, attrs[k]);
    }
    return e;
  }
  function fmt(n) { return n === null || n === undefined ? "—" : Number(n).toLocaleString("en-US"); }
  function pl(n, one, many) { return fmt(n) + " " + (n === 1 ? one : (many || one + "s")); }
  function short(c) { return c ? String(c).slice(0, 10) : "?"; }
  function code(t) { return el("code", {text: t}); }
  // Text with `code` spans, as GAPS.md writes them.
  function ticks(t) {
    var out = [], parts = String(t || "").split("`");
    parts.forEach(function (p, i) { if (p) out.push(i % 2 ? code(p) : p); });
    return out;
  }
  function S(k) { return k >= 0 ? M.S[k] : null; }
  function dayLabel(d) {
    var mo = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    var p = d.split("-");
    return mo[+p[1] - 1] + " " + (+p[2]);
  }
  function dayNum(d) { return Math.round(Date.UTC(+d.slice(0, 4), +d.slice(5, 7) - 1, +d.slice(8, 10)) / 86400000); }
  function ghLink(base, file, line, label) {
    if (!base) return el("span", {cls: "at", text: label});
    return el("a", {cls: "at", href: base + file.split("/").map(encodeURIComponent).join("/") + (line ? "#L" + line : ""),
                    target: "_blank", rel: "noopener", text: label});
  }
  function repoLink(remote) {
    return remote ? el("a", {href: "https://github.com/" + remote, target: "_blank", rel: "noopener", text: remote}) : "—";
  }
  function facts(rows) {
    var dl = el("dl", {cls: "facts"});
    rows.forEach(function (r) {
      if (!r || r[1] === null || r[1] === undefined || r[1] === "") return;
      dl.appendChild(el("dt", {text: r[0]}));
      dl.appendChild(el("dd", null, r[1]));
    });
    return dl;
  }
  function down(title, body) { return el("details", {cls: "down"}, el("summary", {text: title}), body); }

  // ---------------------------------------------------------------- the lede

  var GROUPS = ["update-checkout", "swiftlang and apple", "ecosystem", "the examples"];
  var I = H.intersection, U = I.use;

  function lede() {
    var p = document.getElementById("lede");
    p.textContent = "";
    add(p, ["system-next adds ", el("b", {text: fmt(H.declarations)}), " public declarations to Swift System over main. ",
            "That's the whole universe of API it could ship; what matters is where it meets real users: the packages ",
            "migrating onto System, in three clusters, and the examples' Unix tools. The figures at the top count only that meeting point. ",
            "Below them, every declaration and every package, to explore."]);
    var g = meta.graph || {};
    if (!g.matchesHead && g.withoutNode) add(p, " The newest " + fmt(g.withoutNode) + " declarations were added after uses were last read, so they show none yet.");
    if (U.aside.length) add(p, [" ", el("span", {cls: "hint", text: "Set aside, and in none of the figures: " + U.aside.join(", ") + " (About says why)."})]);
  }

  // ---------------------------------------------------------------- the headline

  var tip = document.getElementById("tip");
  function showTip(evt, nodes) {
    tip.textContent = "";
    add(tip, nodes);
    tip.hidden = false;
    var x = evt.clientX + 14, y = evt.clientY + 14;
    var w = tip.offsetWidth, h = tip.offsetHeight;
    if (x + w > window.innerWidth - 8) x = evt.clientX - w - 14;
    if (y + h > window.innerHeight - 8) y = evt.clientY - h - 14;
    tip.style.left = x + "px";
    tip.style.top = y + "px";
  }
  function hideTip() { tip.hidden = true; }

  function signed(n) { return (n > 0 ? "+" : n < 0 ? "−" : "±") + fmt(Math.abs(n)); }
  function lastTwo(chart) {
    var s = M.charts[chart] || [];
    return {last: s[s.length - 1], prev: s.length > 1 ? s[s.length - 2] : null, n: s.length};
  }
  function asideNames() {
    var o = {};
    U.aside.forEach(function (n) { o[n] = 1; });
    return o;
  }
  // The C uses left in update-checkout on a day, set-aside packages left out.
  function ucTotal(r) {
    var per = (r.detail || {}).perRepo, out = 0, aside = asideNames();
    if (!per) return r.count;
    for (var k in per) if (!aside[k]) out += per[k];
    return out;
  }

  // What moved since the run before, in words: work, and what isn't work
  // (a package read for the first time, a marker over C it already used).
  function since(chart) {
    var t = lastTwo(chart), out = el("p", {cls: "since"});
    if (!t.last) return out;
    if (!t.prev) {
      out.textContent = "First counted " + dayLabel(t.last.date) + "; each run after says what moved, and why.";
      return out;
    }
    var d = t.last.detail || {}, words = [];
    var when = "Since " + dayLabel(t.prev.date) + ": ";
    if (chart === "used") {
      var ch = d.changes || {};
      var keys = Object.keys(ch).sort(function (a, b) { return Math.abs(ch[b][0]) - Math.abs(ch[a][0]); });
      words = keys.slice(0, 4).map(function (k) { return k + " " + signed(ch[k][0]) + " (" + ch[k][1] + ")"; });
      if (keys.length > 4) words.push("and " + pl(keys.length - 4, "more package"));
      out.textContent = when + (t.last.count === t.prev.count && !keys.length ? "no change." :
        signed(t.last.count - t.prev.count) + (words.length ? ": " + words.join("; ") : "") + ".");
    } else if (chart === "unpitched-used") {
      var a = (t.prev.detail || {}).byState || {}, b = d.byState || {};
      ["2", "3", "4", "5"].forEach(function (k) {
        var n = (b[k] || 0) - (a[k] || 0);
        if (n) words.push(signed(n) + " " + L.states[k]);
      });
      out.textContent = when + (t.last.count === t.prev.count && !words.length ? "no change." :
        signed(t.last.count - t.prev.count) + " not in a pitch" + (words.length ? "; " + words.join(", ") : "") + ".");
    } else {
      var aside = asideNames(), c = d.changes || {}, nm = d.newlyMarked || {};
      var moved = Object.keys(c).filter(function (k) { return !aside[k]; }).sort(function (x, y) { return Math.abs(c[y]) - Math.abs(c[x]); });
      var work = moved.reduce(function (n, k) { return n + c[k]; }, 0);
      var fresh = (d.newRepos || []).filter(function (k) { return !aside[k]; });
      var freshN = fresh.reduce(function (n, k) { return n + ((d.perRepo || {})[k] || 0); }, 0);
      var marked = Object.keys(nm).filter(function (k) { return !aside[k]; });
      var markedN = marked.reduce(function (n, k) { return n + nm[k]; }, 0);
      if (moved.length) words.push("in the adopters' code, " + signed(work) + ": " +
        moved.slice(0, 4).map(function (k) { return k + " " + signed(c[k]); }).join(", ") + (moved.length > 4 ? ", …" : ""));
      if (freshN) words.push(signed(freshN) + " newly counted, not new C: " + fresh.join(", ") + " read for the first time");
      if (markedN) words.push(signed(markedN) + " newly counted, not new C: SYSTEM-GAP markers over C already used (" + marked.join(", ") + ")");
      var total = ucTotal(t.last) - ucTotal(t.prev);
      out.textContent = when + (total === 0 && !words.length ? "no change in update-checkout." :
        signed(total) + " in update-checkout" + (words.length ? ". " + words.join("; ").replace(/^./, function (x) { return x.toUpperCase(); }) : "") + ".");
    }
    return out;
  }

  function card(title, figure, small, sub) {
    return el("article", {cls: "card"}, el("h2", {text: title}),
              figure !== null ? el("div", {cls: "fig"}, figure, small ? el("small", {text: small}) : null) : null,
              el("p", {cls: "sub", text: sub}));
  }

  function useCard() {
    var c = card("New API in use", fmt(U.any), "of the " + fmt(H.declarations) + " declarations system-next adds",
                 "Used by the adopters' migrations onto System, or by the examples' tools: what real users need of the new API.");
    var tb = el("table", {cls: "groups"});
    CL.forEach(function (g, ci) {
      var r = U.groups[g], who;
      if (ci === Model.EXAMPLES) who = "in " + fmt(r.packages) + " of its " + fmt(r.inCluster) + " targets: the tools and their shared code";
      else if (!r.migrated) who = "no package here has a migration yet, of " + pl(r.inCluster, "package");
      else who = "by " + fmt(r.packages) + " of the " + fmt(r.migrated) + " migrated packages (" +
        (r.migrated > r.read ? fmt(r.migrated - r.read) + " not read; " : "") + fmt(r.inCluster) + " in the cluster)";
      tb.appendChild(el("tr", null, el("th", {text: GROUPS[ci]}),
        el("td", {cls: "num", text: r.declarations ? fmt(r.declarations) : "none"}), el("td", {cls: "who", text: who})));
    });
    c.appendChild(tb);
    c.appendChild(el("p", {cls: "note", text: fmt(U.both) + " are used by both the adopters and the examples, " +
      fmt(U.adoptersOnly) + " only by the adopters, and " + fmt(U.examplesOnly) + " only by the examples."}));
    c.appendChild(since("used"));
    c.appendChild(el("button", {type: "button", cls: "go", text: "See them in By API", onclick: function () { setFilters({use: "used"}); }}));
    c.appendChild(down("By package", usersTable()));
    return c;
  }

  function usersTable() {
    var rows = M.pkgs.filter(function (p) { return p.uses.length && !p.a; })
      .sort(function (a, b) { return b.uses.length - a.uses.length || (a.n < b.n ? -1 : 1); });
    var tb = el("table", {cls: "nums"}, el("tr", null, el("th", {text: "Package"}), el("th", {text: "New API"}),
      el("th", {text: "Sites"}), el("th", {text: "Read at"})));
    rows.forEach(function (p) {
      tb.appendChild(el("tr", null,
        el("td", null, el("button", {type: "button", cls: "go", text: p.n, onclick: function () { openPkg(p.i); }})),
        el("td", {text: fmt(p.uses.length)}), el("td", {text: fmt(p.newSites)}),
        el("td", {cls: "l", text: p.use ? (p.use.b || "?") + " " + short(p.use.c) : ""})));
    });
    return el("div", {cls: "scroll small"}, tb);
  }

  function meter(part, whole, label) {
    var pct = whole ? Math.round(part / whole * 1000) / 10 : 0;
    var m = el("div", {cls: "meter", role: "img", "aria-label": label});
    m.appendChild(el("span", {cls: "fill", style: "width: " + pct + "%"}));
    return m;
  }

  function pitchCard() {
    var pitchable = U.any - U.outside, inPitch = pitchable - U.unpitched;
    var c = card("Used, not yet in a pitch", fmt(U.unpitched), "of the " + fmt(U.any) + " declarations in use",
                 "In use, and in no pitch file yet: the pitch work that real users drive.");
    c.appendChild(meter(inPitch, pitchable, fmt(inPitch) + " of " + fmt(pitchable) + " in a pitch"));
    c.appendChild(el("p", {cls: "note", text: fmt(inPitch) + " of them are in a pitch: " +
      [2, 3, 4, 5].map(function (k) { return fmt(U.byState[k]) + " " + (k === 2 ? "in a pitch draft" : L.states[k]); }).join(", ") +
      (U.outside ? "; " + fmt(U.outside) + " more are deprecated, underscored or SPI, which pitches leave out" : "") + "."}));
    var tb = el("table", {cls: "groups"});
    [["used by the adopters", U.unpitchedAdopters, U.adopters], ["used by the examples", U.unpitchedExamples, U.examples]].forEach(function (r) {
      tb.appendChild(el("tr", null, el("th", {text: r[0]}), el("td", {cls: "num", text: fmt(r[1])}),
        el("td", {cls: "who", text: "of " + fmt(r[2]) + " not in a pitch"})));
    });
    c.appendChild(tb);
    c.appendChild(since("unpitched-used"));
    c.appendChild(el("button", {type: "button", cls: "go", text: "List them in By API", onclick: function () { setFilters({use: "used", state: "1"}); }}));
    return c;
  }

  var UNITS = {sites: ["site", "imports of a platform C module, and gap markers, on every platform"],
               files: ["file", "in library targets that import Darwin or use its C names (scanned "],
               gaps: ["gap", "the examples list in GAPS.md"]};
  function splitBar(g, row) {
    var total = row.covers + row.lacks + row.other;
    var bar = el("div", {cls: "bar", role: "img", "aria-label": g + ": " + SPLIT.map(function (b) { return fmt(row[b]) + " " + L.split[b]; }).join(", ")});
    SPLIT.forEach(function (b) {
      if (!row[b]) return;
      var seg = el("span", {cls: "seg " + b, tabindex: 0, style: "flex-grow: " + row[b]});
      var parts = Object.keys(row.parts).filter(function (k) { return (L.parts[b] || []).indexOf(k) >= 0; });
      var words = [el("div", {cls: "tv", text: fmt(row[b]) + " " + (row[b] === 1 ? UNITS[row.unit][0] : UNITS[row.unit][0] + "s")}),
                   el("div", {cls: "tr", text: L.split[b] + ", " + Math.round(row[b] / total * 100) + "% of " + g + "'s"})];
      parts.forEach(function (k) { words.push(el("div", {cls: "tr", text: fmt(row.parts[k]) + " " + k})); });
      seg.addEventListener("pointermove", function (e) { showTip(e, words); });
      seg.addEventListener("pointerleave", hideTip);
      seg.addEventListener("focus", function () { var r = seg.getBoundingClientRect(); showTip({clientX: r.left, clientY: r.bottom}, words); });
      seg.addEventListener("blur", hideTip);
      bar.appendChild(seg);
    });
    return bar;
  }

  function cusesCard() {
    var c = card("Platform C uses left, and whose work they are", null, null,
                 "What the adopters still use from C: the part System covers is the adopters' work to move; the part it lacks is System's work first.");
    var lg = el("div", {cls: "legend"});
    SPLIT.forEach(function (b) { lg.appendChild(el("span", null, el("span", {cls: "swatch " + b}), L.split[b] + (b === "covers" ? ": adopter work" : b === "lacks" ? ": System work" : ": neither yet"))); });
    c.appendChild(lg);
    var scanDate = ((meta.runs || [])[0] || {}).date || meta.survey.date || "?";
    CL.forEach(function (g, ci) {
      var row = I.cuses[g], total = row.covers + row.lacks + row.other, u = UNITS[row.unit];
      var what = row.unit === "files" ? u[1] + scanDate + "), in " + fmt(row.withData) + " of " + pl(row.packages, "package") : u[1];
      var box = el("div", {cls: "split-row"},
        el("div", {cls: "split-head"}, el("b", {text: GROUPS[ci]}), " ", el("span", {cls: "n", text: fmt(total) + " " + (total === 1 ? u[0] : u[0] + "s")}),
           el("span", {cls: "hint", text: " " + what})));
      if (total) {
        box.appendChild(splitBar(GROUPS[ci], row));
        box.appendChild(el("div", {cls: "split-nums"}, SPLIT.map(function (b) {
          return el("span", null, el("span", {cls: "swatch " + b}), fmt(row[b]) + " " + L.split[b]);
        })));
      } else {
        box.appendChild(el("div", {cls: "hint", text: row.withData ? "none left" : "not scanned yet"}));
      }
      c.appendChild(box);
    });
    c.appendChild(since("cuses"));
    c.appendChild(down("Show the numbers", cusesNumbers()));
    return c;
  }

  function cusesNumbers() {
    var box = el("div");
    var tb = el("table", {cls: "nums"}, el("tr", null, el("th", {text: "Cluster"}), el("th", {text: "Part"}),
      el("th", {text: "Count"})));
    CL.forEach(function (g, ci) {
      var row = I.cuses[g];
      SPLIT.forEach(function (b) {
        (L.parts[b] || []).forEach(function (k) {
          if (!row.parts[k]) return;
          tb.appendChild(el("tr", null, el("td", {text: GROUPS[ci]}), el("td", {cls: "l", text: L.split[b] + ": " + k}),
            el("td", {text: fmt(row.parts[k])})));
        });
      });
    });
    box.appendChild(tb);
    var uc = I.cuses["update-checkout"];
    if (uc.aside) box.appendChild(el("p", {cls: "hint", text: fmt(uc.aside) + " more sites, in " + U.aside.join(" and ") +
      ", are set aside and counted nowhere above."}));
    var series = (M.charts.cuses || []).slice().reverse();
    if (series.length) {
      var hb = el("table", {cls: "nums"}, el("tr", null, el("th", {text: "Day"}), el("th", {text: "update-checkout"}),
        el("th", {text: "What moved"})));
      series.forEach(function (r) {
        var d = r.detail || {}, moved = [];
        var c = d.changes || {}, aside = asideNames();
        var keys = Object.keys(c).filter(function (k) { return !aside[k]; }).sort(function (x, y) { return Math.abs(c[y]) - Math.abs(c[x]); });
        if (keys.length) moved.push(keys.map(function (k) { return k + " " + signed(c[k]); }).join(", "));
        if ((d.newRepos || []).length) moved.push("read for the first time: " + d.newRepos.filter(function (k) { return !aside[k]; }).join(", "));
        var nm = d.newlyMarked || {};
        var mk = Object.keys(nm).filter(function (k) { return !aside[k]; });
        if (mk.length) moved.push("newly marked: " + mk.map(function (k) { return k + " +" + fmt(nm[k]); }).join(", "));
        hb.appendChild(el("tr", null, el("td", {text: r.date}), el("td", {text: fmt(ucTotal(r))}),
          el("td", {cls: "l", text: moved.join("; ") + (r.source && r.source !== "run" ? " (" + r.source + ")" : "")})));
      });
      box.appendChild(el("h3", {text: "update-checkout's C uses by day, set-aside packages left out"}));
      box.appendChild(hb);
    }
    return box;
  }

  function headline() {
    var box = document.getElementById("headline");
    box.textContent = "";
    box.appendChild(useCard());
    box.appendChild(pitchCard());
    box.appendChild(cusesCard());
  }

  function setFilters(o) {
    F = Model.defaults();
    for (var k in o) F[k] = o[k];
    document.getElementById("q").value = "";
    [["f-cluster", "cluster"], ["f-kind", "kind"], ["f-state", "state"], ["f-use", "use"]].forEach(function (p) {
      document.getElementById(p[0]).value = F[p[1]];
    });
    showAll = {};
    tab = "api";
    document.getElementById("tab-api").setAttribute("aria-selected", true);
    document.getElementById("tab-pkg").setAttribute("aria-selected", false);
    render();
    hash();
    document.getElementById("tabs").scrollIntoView({block: "start"});
  }

  // ---------------------------------------------------------------- controls

  function option(sel, value, label) { sel.appendChild(el("option", {value: value, text: label})); }
  function controls() {
    var c = document.getElementById("f-cluster");
    option(c, "all", "All clusters");
    CL.forEach(function (k, i) { option(c, i, L.clusters[k]); });
    var k = document.getElementById("f-kind");
    option(k, "all", "Any data");
    KD.forEach(function (x, i) { option(k, i, L.kinds[x]); });
    var s = document.getElementById("f-state");
    option(s, "all", "Any pitch state");
    [1, 2, 3, 4, 5].forEach(function (n) { option(s, n, L.states[n]); });
    var u = document.getElementById("f-use");
    option(u, "all", "Used or not");
    option(u, "used", "Used by anyone");
    option(u, "adopters", "Used by adopters");
    option(u, "examples", "Used by the examples");
    option(u, "none", "Used by no one");
    var q = document.getElementById("q");
    var timer = null;
    q.addEventListener("input", function () {
      clearTimeout(timer);
      timer = setTimeout(function () { F.q = q.value; showAll = {}; render(); }, 150);
    });
    [["f-cluster", "cluster"], ["f-kind", "kind"], ["f-state", "state"], ["f-use", "use"]].forEach(function (p) {
      document.getElementById(p[0]).addEventListener("change", function (e) { F[p[1]] = e.target.value; showAll = {}; render(); });
    });
    document.getElementById("reset").addEventListener("click", function () {
      F = Model.defaults();
      q.value = "";
      ["f-cluster", "f-kind", "f-state", "f-use"].forEach(function (id) { document.getElementById(id).value = "all"; });
      render();
    });
    document.getElementById("tab-api").addEventListener("click", function () { setTab("api"); });
    document.getElementById("tab-pkg").addEventListener("click", function () { setTab("pkg"); });
    var th = document.getElementById("theme");
    var modes = ["auto", "light", "dark"], mode = 0;
    th.addEventListener("click", function () {
      mode = (mode + 1) % 3;
      if (modes[mode] === "auto") document.documentElement.removeAttribute("data-theme");
      else document.documentElement.setAttribute("data-theme", modes[mode]);
      th.textContent = "Theme: " + modes[mode];
    });
  }

  function setTab(t) {
    tab = t;
    document.getElementById("tab-api").setAttribute("aria-selected", t === "api");
    document.getElementById("tab-pkg").setAttribute("aria-selected", t === "pkg");
    render();
    hash();
  }

  function chips() {
    var box = document.getElementById("chips");
    box.textContent = "";
    if (F.onlyPkg !== null) box.appendChild(el("span", {cls: "chip"}, "used by " + M.pkgs[F.onlyPkg].n,
      el("button", {type: "button", title: "Clear", "aria-label": "Clear", text: "×", onclick: function () { F.onlyPkg = null; render(); }})));
    if (F.onlyDecl !== null) box.appendChild(el("span", {cls: "chip"}, "users of " + M.decls[F.onlyDecl].path,
      el("button", {type: "button", title: "Clear", "aria-label": "Clear", text: "×", onclick: function () { F.onlyDecl = null; render(); }})));
  }

  // ---------------------------------------------------------------- By API

  function usesText(uses) {
    if (!uses.length) return "not used yet";
    var n = 0;
    uses.forEach(function (u) { n += u.sites.length; });
    return "used by " + pl(uses.length, "package") + " · " + pl(n, "site");
  }
  function stateChip(d) { return el("span", {cls: "state s" + d.state, text: L.states[d.state]}); }

  function renderApi(root, v) {
    var t = Model.tree(M, v.decls);
    var searching = !!v.q || F.onlyPkg !== null;
    var budget = {left: showAll.api ? 1e9 : RENDER_CAP};
    var total = v.decls.length;
    var used = v.decls.filter(function (i) { return v.declUses[i].length; }).length;
    var head = el("p", {cls: "hint"},
      pl(total, "declaration") + " in " + pl(t.length, "area") + "; " + fmt(used) + " used by a package" +
      (F.cluster !== "all" || F.kind !== "all" ? " in the packages chosen" : "") + ".");
    if (v.q) {
      var pm = v.pkgs.length;
      if (pm) add(head, [" ", el("button", {type: "button", cls: "go", text: pl(pm, "package") + " match by name: see By package",
                                            onclick: function () { setTab("pkg"); }})]);
    }
    root.appendChild(head);
    t.forEach(function (a) {
      var ak = a.area.name + "|" + a.area.module;
      var openA = openAreas[ak] !== undefined ? openAreas[ak] : (searching && total <= 600);
      var au = 0, ap = {};
      a.types.forEach(function (ty) { ty.decls.forEach(function (i) { if (v.declUses[i].length) au++; v.declUses[i].forEach(function (u) { ap[u.p] = 1; }); }); });
      var row = el("div", {cls: "row area-row" + (openA ? " open" : ""), role: "button", tabindex: 0, "aria-expanded": openA},
        el("span", null, el("span", {cls: "tw", text: openA ? "▾" : "▸"}), a.area.name, el("span", {cls: "mod", text: a.area.module})),
        el("span", {cls: "n", text: pl(a.n, "declaration")}),
        el("span", {cls: "n", text: au ? fmt(au) + " used · " + pl(Object.keys(ap).length, "package") : "none used"}));
      row.addEventListener("click", function () { openAreas[ak] = !openA; render(); });
      row.addEventListener("keydown", function (e) { if (e.key === "Enter" || e.key === " ") { e.preventDefault(); row.click(); } });
      root.appendChild(row);
      if (!openA) return;
      a.types.forEach(function (ty) {
        var tk = ak + "|" + ty.name;
        var openT = openTypes[tk] !== undefined ? openTypes[tk] : (searching && total <= 150) || a.types.length === 1;
        var tu = 0, tp = {};
        ty.decls.forEach(function (i) { if (v.declUses[i].length) tu++; v.declUses[i].forEach(function (u) { tp[u.p] = 1; }); });
        var tag = (meta.typeTags || {})[ty.name];
        var trow = el("div", {cls: "row type-row" + (openT ? " open" : ""), role: "button", tabindex: 0, "aria-expanded": openT},
          el("span", null, el("span", {cls: "tw", text: openT ? "▾" : "▸"}), el("span", {cls: "tn", text: ty.name}),
             tag ? el("span", {cls: "on-main", text: tag}) : null),
          el("span", {cls: "n", text: pl(ty.decls.length, "declaration")}),
          el("span", {cls: "n", text: tu ? fmt(tu) + " used · " + pl(Object.keys(tp).length, "package") : "none used"}));
        trow.addEventListener("click", function () { openTypes[tk] = !openT; render(); });
        trow.addEventListener("keydown", function (e) { if (e.key === "Enter" || e.key === " ") { e.preventDefault(); trow.click(); } });
        root.appendChild(trow);
        if (!openT) return;
        for (var k = 0; k < ty.decls.length; k++) {
          if (budget.left <= 0) {
            if (!budget.shown) {
              budget.shown = true;
              root.appendChild(el("button", {type: "button", cls: "more", text: "Show all " + fmt(total) + " (rendered " + fmt(RENDER_CAP) + "; narrow the search to see fewer)",
                                             onclick: function () { showAll.api = true; render(); }}));
            }
            return;
          }
          budget.left--;
          declRow(root, ty.decls[k], v.declUses[ty.decls[k]], ty.name);
        }
      });
    });
    if (!t.length) root.appendChild(el("p", {cls: "hint", text: "No declaration matches. Clear the search or the filters."}));
  }

  function memberName(d, type) {
    if (d.path === type) return d.path;
    if (d.path.indexOf(type + ".") === 0) return d.path.slice(type.length + 1);
    return d.path;
  }

  function declRow(root, i, uses, type) {
    var d = M.decls[i];
    var isOpen = !!openDecls[i];
    var row = el("div", {cls: "row decl-row" + (isOpen ? " open" : ""), role: "button", tabindex: 0, "aria-expanded": isOpen, "data-decl": i},
      el("span", {cls: "p", text: memberName(d, type)}),
      el("span", {cls: "k", text: d.kind}),
      el("span", {cls: "u" + (uses.length ? "" : " none"), text: d.sameAs >= 0 && !d.uses.length ? "uses counted under its variant" : usesText(uses)}),
      stateChip(d));
    row.addEventListener("click", function () { openDecls[i] = !isOpen; render(); });
    row.addEventListener("keydown", function (e) { if (e.key === "Enter" || e.key === " ") { e.preventDefault(); row.click(); } });
    root.appendChild(row);
    if (isOpen) root.appendChild(declDetail(d, uses));
  }

  var HOWTEXT = ["", "found by name", "naming the type to qualify another name"];
  var TYPE_KINDS = {"Structure": 1, "Enumeration": 1, "Class": 1, "Protocol": 1, "Actor": 1, "Type Alias": 1};
  // A site's line, and how it was found. api-graph marks any name followed
  // by a member it also references as a qualifier (`ProcessID.current` in
  // `ProcessID.current.rawValue`); only a type's is one, so only a type's
  // says so here.
  function siteList(sites, base, d) {
    var ul = el("ul", {cls: "sites"});
    var isType = d && TYPE_KINDS[d.kind];
    sites.forEach(function (s) {
      var f = S(s[0]), line = s[1];
      var how = s[3] === 2 && !isType ? 0 : s[3];
      ul.appendChild(el("li", null, ghLink(base, f, line, f + ":" + line),
                        el("span", {cls: "src"}, S(s[4]) || "", how ? el("span", {cls: "how", text: "  " + HOWTEXT[how]}) : null)));
    });
    return ul;
  }

  function flagWords(d) {
    var w = [];
    if (Model.flag(d, "stub")) w.push("a renaming stub: unavailable, it points to the Swift name");
    else if (Model.flag(d, "outside")) w.push("not counted in the charts (deprecated, underscored or SPI)");
    if (Model.flag(d, "upstream")) w.push("origin/main already has it (local main is behind)");
    if (Model.flag(d, "overload")) w.push("shares its name with another new declaration (an overload, or a variant for other platforms)");
    if (Model.flag(d, "pitches")) w.push("in more than one pitch");
    if (Model.flag(d, "hidden")) w.push("not in the macOS symbol graphs (compiled only elsewhere, or a stub): from the source scan");
    if (Model.flag(d, "nograph")) w.push("added after the API graph used here was made, so its uses and C name aren't known yet");
    return w.join("; ");
  }

  function declDetail(d, uses) {
    var box = el("div", {cls: "detail"});
    if (d.decl) box.appendChild(el("pre", {cls: "decl", text: d.decl}));
    if (d.doc) box.appendChild(el("p", {cls: "doc", text: d.doc}));
    box.appendChild(facts([
      ["Pitch", d.pitch ? [L.states[d.state] + ": ", code(d.pitch)] : L.states[d.state]],
      ["C name", d.cname ? code(d.cname) : null],
      ["Platforms", Model.platforms(d.plat).join(", ")],
      ["In System", d.file ? el("span", {cls: "mono", text: d.file + ":" + d.line}) : null],
      ["Availability", d.avail || null],
      ["Note", flagWords(d) || null]
    ]));
    if (d.sameAs >= 0 && !d.uses.length) {
      var o = M.decls[d.sameAs];
      box.appendChild(el("p", null, "Its uses are counted once, under its other variant: ",
        el("button", {type: "button", cls: "go", text: o.path + " (" + Model.platforms(o.plat).join(", ") + ")",
                      onclick: function () { openDecl(d.sameAs); }}),
        ". The uses come from Darwin builds, which compile only that one."));
    }
    var h = el("h3", {text: uses.length ? "Used by " + pl(uses.length, "package") : "Not used by a package yet"});
    box.appendChild(h);
    if (uses.length) {
      var ul = el("ul", {cls: "users"});
      uses.slice().sort(function (a, b) { return b.sites.length - a.sites.length || (M.pkgs[a.p].n < M.pkgs[b.p].n ? -1 : 1); }).forEach(function (u) {
        var p = M.pkgs[u.p];
        ul.appendChild(el("li", null,
          el("button", {type: "button", cls: "go who", text: p.n, onclick: function () { openPkg(u.p); }}),
          " · " + pl(u.sites.length, "site"),
          siteList(u.sites, p.use && p.use.link, d)));
      });
      box.appendChild(ul);
      box.appendChild(el("button", {type: "button", cls: "go", text: "Show only these packages in By package",
                                    onclick: function () { F.onlyDecl = d.i; setTab("pkg"); }}));
    } else if (d.uses.length) {
      box.appendChild(el("p", {cls: "hint", text: "Used only by packages the filters leave out: " +
        d.uses.map(function (u) { return M.pkgs[u.p].n; }).join(", ") + "."}));
    } else {
      box.appendChild(el("p", {cls: "hint", text: "Nothing read so far uses it: no migration, and none of the examples' tools. About says what's read."}));
    }
    box.appendChild(down("More detail", facts([
      ["Module", d.module],
      ["Kind", d.kind],
      ["Full name", el("span", {cls: "mono", text: d.path})],
      ["Type", el("span", {cls: "mono", text: d.type})],
      ["Area", M.areas[d.area].name + " (" + M.areas[d.area].module + ")"],
      ["Listed by", Model.flag(d, "hidden") ? "api-delta's source scan (not in the macOS symbol graphs)" : "api-delta, from the macOS symbol graphs"],
      ["Uses from", "api-graph at " + short(meta.graph.commit) + ", reading each migrated package at its newest migration branch (" +
        (meta.graph.adopterBranches || []).join(", else ") + ") and the examples at their main"]
    ])));
    return box;
  }

  function openDecl(i) {
    var d = M.decls[i];
    F.q = ""; document.getElementById("q").value = "";
    F.state = "all"; document.getElementById("f-state").value = "all";
    F.use = "all"; document.getElementById("f-use").value = "all";
    F.onlyDecl = null;
    openAreas[M.areas[d.area].name + "|" + M.areas[d.area].module] = true;
    openTypes[M.areas[d.area].name + "|" + M.areas[d.area].module + "|" + d.type] = true;
    openDecls[i] = true;
    tab = "api";
    document.getElementById("tab-api").setAttribute("aria-selected", true);
    document.getElementById("tab-pkg").setAttribute("aria-selected", false);
    render();
    history.replaceState(null, "", "#decl=" + encodeURIComponent(d.ref));
    var r = document.querySelector('[data-decl="' + i + '"]');
    if (r) r.scrollIntoView({block: "center"});
  }

  // ---------------------------------------------------------------- By package

  function sitesOf(uses) { var n = 0; uses.forEach(function (u) { n += u.sites.length; }); return n; }
  function cuseSummary(p) {
    var c = p.cu;
    if (p.k === 3) return "no Swift code";
    if (!c) return "C use not scanned";
    if (c.src === "ledger") {
      if (c.notRead) return "not read: " + c.notRead;
      var sp = splitOf(c.sites.map(function (s) { return s[11]; }));
      return pl(c.sites.length, "C use") + " left" + (c.sites.length ? ": System covers " + fmt(sp[0]) + ", lacks " + fmt(sp[1]) : "");
    }
    if (c.src === "scan") {
      if (!c.files && !c.names.length) return "no Darwin import found";
      var fs = splitOf((c.fb || []).map(function (x) { return x[1]; }));
      return pl((c.fb || []).length, "file") + " use Darwin: System covers " + fmt(fs[0]) + ", lacks " + fmt(fs[1]);
    }
    if (c.src === "GAPS.md") return c.gaps.length ? pl(c.gaps.length, "gap") + " in GAPS.md" : "no gap in GAPS.md";
    return "";
  }

  function renderPkg(root, v) {
    var sel = el("select", {"aria-label": "Sort packages"});
    [["name", "Sort by name"], ["new", "Sort by new API used"], ["c", "Sort by C uses left"]].forEach(function (o) {
      sel.appendChild(el("option", {value: o[0], text: o[1]}));
    });
    sel.value = sortBy;
    sel.addEventListener("change", function () { sortBy = sel.value; render(); });
    var head = el("p", {cls: "hint"}, pl(v.pkgs.length, "package") + ". ", sel);
    if (v.q && v.decls.length) add(head, [" ", el("button", {type: "button", cls: "go", text: pl(v.decls.length, "declaration") + " match by name: see By API",
                                                           onclick: function () { setTab("api"); }})]);
    root.appendChild(head);
    var groups = CL.map(function () { return []; });
    v.pkgs.forEach(function (i) { groups[M.pkgs[i].c].push(i); });
    var key = {
      name: function (p) { return p.n.toLowerCase(); },
      "new": function (p) { return -v.pkgUses[p.i].length; },
      c: function (p) { return -(p.cu && p.cu.sites ? p.cu.sites.length : -1); }
    }[sortBy];
    groups.forEach(function (g, ci) {
      if (!g.length) return;
      g.sort(function (a, b) {
        var x = key(M.pkgs[a]), y = key(M.pkgs[b]);
        return x < y ? -1 : x > y ? 1 : (M.pkgs[a].n.toLowerCase() < M.pkgs[b].n.toLowerCase() ? -1 : 1);
      });
      var kinds = {};
      g.forEach(function (i) { kinds[M.pkgs[i].k] = (kinds[M.pkgs[i].k] || 0) + 1; });
      root.appendChild(el("div", {cls: "cluster-head"}, L.clusters[CL[ci]],
        el("small", {text: pl(g.length, ci === Model.EXAMPLES ? "target" : "package") + ": " + KD.map(function (k, j) { return kinds[j] ? fmt(kinds[j]) + " " + L.kinds[k] : null; }).filter(Boolean).join(", ")})));
      g.forEach(function (i) { pkgRow(root, M.pkgs[i], v.pkgUses[i]); });
    });
    if (!v.pkgs.length) root.appendChild(el("p", {cls: "hint", text: "No package matches. Clear the search or the filters."}));
  }

  function pkgRow(root, p, uses) {
    var isOpen = !!openPkgs[p.i];
    var nm = p.use && p.use.main ? p.use.main.length : 0;
    var apiText = p.use ? fmt(uses.length) + " new · " + fmt(nm) + " already on main" : (p.k === 0 ? "use not read yet" : "—");
    var row = el("div", {cls: "row pkg-row" + (isOpen ? " open" : ""), role: "button", tabindex: 0, "aria-expanded": isOpen, "data-pkg": p.i},
      el("span", {cls: "pn"}, p.n, p.a ? el("span", {cls: "aside-tag", title: "Set aside (" + p.a.by + "): " + p.a.why, text: "set aside"}) : null),
      el("span", {cls: "cl", text: L.clusters[CL[p.c]]}),
      el("span", {cls: "dk k" + p.k, text: L.kinds[KD[p.k]]}),
      el("span", {cls: "m", text: "System API: " + apiText}),
      el("span", {cls: "m", text: cuseSummary(p)}));
    row.addEventListener("click", function () { openPkgs[p.i] = !isOpen; render(); hash(); });
    row.addEventListener("keydown", function (e) { if (e.key === "Enter" || e.key === " ") { e.preventDefault(); row.click(); } });
    root.appendChild(row);
    if (isOpen) root.appendChild(pkgDetail(p, uses));
  }

  function spark(points) {
    if (points.length < 2) return null;
    var W = 90, Hh = 22, max = 1;
    points.forEach(function (x) { max = Math.max(max, x[1]); });
    var s = svg("svg", {width: W, height: Hh, viewBox: "0 0 " + W + " " + Hh, "class": "spark", role: "img",
                        "aria-label": "by day: " + points.map(function (x) { return x[0] + " " + x[1]; }).join(", ")});
    var d = "";
    points.forEach(function (x, k) {
      var px = 2 + k / (points.length - 1) * (W - 4), py = Hh - 2 - x[1] / max * (Hh - 4);
      d += (k ? " H" + px + " V" + py : "M" + px + "," + py);
    });
    s.appendChild(svg("path", {d: d, "class": "line"}));
    return s;
  }

  function pkgHistory(name) {
    return (M.charts.cuses || []).filter(function (r) { return r.detail && r.detail.perRepo && name in r.detail.perRepo; })
      .map(function (r) { return [r.date, r.detail.perRepo[name]]; });
  }

  function splitOf(buckets) {
    var n = [0, 0, 0];
    buckets.forEach(function (b) { n[b]++; });
    return n;
  }

  function pkgDetail(p, uses) {
    var box = el("div", {cls: "detail pkg-detail"});
    if (p.a) box.appendChild(el("p", {cls: "warn", text: "Set aside (" + p.a.by + "): " + p.a.why +
      ". Shown here, and counted in none of the figures at the top."}));
    box.appendChild(facts([
      ["On GitHub", repoLink(p.r)],
      ["Cluster", L.clusters[CL[p.c]] + (p.c === 2 ? " (provisional)" : "")],
      ["Data", L.kinds[KD[p.k]]],
      ["Note", p.no || null]
    ]));
    // System API it uses.
    box.appendChild(el("h3", {text: "The System API it uses"}));
    if (p.use) {
      var cols = el("div", {cls: "cols"});
      var nsites = sitesOf(uses);
      var newCol = el("div", null, el("div", null, el("b", {text: fmt(uses.length)}), " new in system-next, at " + pl(nsites, "site")));
      var ul = el("ul", {cls: "apilist"});
      uses.slice().sort(function (a, b) { return M.decls[a.d].path < M.decls[b.d].path ? -1 : 1; }).forEach(function (u) {
        var d = M.decls[u.d];
        ul.appendChild(el("li", null,
          el("details", null, el("summary", null, el("span", {cls: "ns", text: pl(u.sites.length, "site")}),
                                 el("span", {cls: "ap", text: d.path}),
                                 d.module !== "SystemPackage" ? el("span", {cls: "hint", text: " (" + d.module + ")"}) : null, " ", stateChip(d)),
             siteList(u.sites, p.use.link, d),
             el("button", {type: "button", cls: "go", text: "Open in By API", onclick: function () { openDecl(u.d); }}))));
      });
      if (uses.length) newCol.appendChild(ul);
      if (uses.length) newCol.appendChild(el("button", {type: "button", cls: "go", text: "Show these in By API, by area",
                                                        onclick: function () { F.onlyPkg = p.i; setTab("api"); }}));
      cols.appendChild(newCol);
      var main = p.use.main || [];
      var msites = 0;
      main.forEach(function (m) { msites += m[2].length; });
      var mainCol = el("div", null, el("div", null, el("b", {text: fmt(main.length)}), " already on main, at " + pl(msites, "site")));
      if (!p.use.cache) mainCol.appendChild(el("p", {cls: "hint", text: "Not available: api-graph's cache of this migration's build isn't here."}));
      var ml = el("ul", {cls: "apilist"});
      main.forEach(function (m) {
        ml.appendChild(el("li", null, el("details", null,
          el("summary", null, el("span", {cls: "ns", text: pl(m[2].length, "site")}), el("span", {cls: "ap", text: S(m[0])}),
             m[1] ? el("span", {cls: "hint", text: " (its signature changed on system-next)"}) : null),
          siteList(m[2].map(function (s) { return [s[0], s[1], s[2], 0, -1]; }), p.use.link))));
      });
      if (main.length) mainCol.appendChild(ml);
      cols.appendChild(mainCol);
      box.appendChild(cols);
      box.appendChild(el("p", {cls: "hint", text: p.c === 3 ? "Read at swift-system-examples' main: the files under " + (p.sd || "its directory") +
        ", written on System from the start." : p.mig && p.mig.nb !== p.use.b ?
        "Read from an earlier step of its migration: its newest work isn't counted here yet (More detail says which)." :
        "Read from its newest migration work."}));
    } else if (p.k === 0) {
      box.appendChild(el("p", {cls: "warn", text: "Not read: api-graph couldn't read its migration (About, Known limits, says why)."}));
    } else if (p.c === 3) {
      box.appendChild(el("p", {cls: "hint", text: "Not read: the API graph used here has no build of the examples."}));
    } else {
      box.appendChild(el("p", {cls: "hint", text: p.k === 3 ? "None: it has no Swift code." : "None yet: it has no migration branch, so there's no use of System to read."}));
    }
    // C it still uses.
    box.appendChild(el("h3", {text: "What it still uses from C"}));
    var c = p.cu;
    if (!c) {
      box.appendChild(el("p", {cls: "hint", text: p.k === 3 ? "Nothing: it has no Swift code." :
        (p.cl ? "Not scanned yet." : "Not scanned yet: there's no clone of it here.")}));
    } else if (c.src === "ledger" && c.notRead) {
      box.appendChild(el("p", {cls: "hint", text: p.k === 3 ? "Nothing: it has no Swift code (the ledger: " + c.notRead + ")." : "Not scanned yet: " + c.notRead + "."}));
    } else if (c.src === "ledger") {
      box.appendChild(ledgerBlock(p, c));
    } else if (c.src === "scan") {
      box.appendChild(scanBlock(p, c));
    } else if (c.src === "GAPS.md") {
      box.appendChild(gapsBlock(c));
    }
    box.appendChild(down("More detail", pkgMore(p)));
    return box;
  }

  function ledgerBlock(p, c) {
    var b = el("div");
    var n = c.sites.length;
    var hist = pkgHistory(p.n);
    var lastPt = (M.charts.cuses || [])[(M.charts.cuses || []).length - 1] || {};
    var marked = ((lastPt.detail || {}).newlyMarked || {})[p.n];
    b.appendChild(el("p", null, el("b", {text: fmt(n)}), " " + (n === 1 ? "use" : "uses") + " of a platform C module left (an import, or a marker of a gap)",
      hist.length > 1 ? ["; by day: ", hist.map(function (x) { return dayLabel(x[0]) + " " + fmt(x[1]); }).join(", "), spark(hist)] : null, ".",
      marked ? " On " + dayLabel(lastPt.date) + ", " + fmt(marked) + " of them were newly marked: SYSTEM-GAP markers its migration added over C it already used, counted from then on (not new C)." : null));
    if (n) b.appendChild(splitLine(splitOf(c.sites.map(function (s) { return s[11]; })), "site"));
    var by = {};
    c.sites.forEach(function (s) { by[s[3]] = (by[s[3]] || 0) + 1; });
    var cats = el("div", {cls: "cats"});
    CATS.forEach(function (k, i) { if (by[i]) cats.appendChild(el("span", {cls: "c"}, el("b", {text: fmt(by[i])}), " " + L.categories[k])); });
    if (n) b.appendChild(cats);
    if (c.lacks && c.lacks.length) {
      var names = function (xs) { return xs.map(function (x, i) { return [i ? " " : "", code(x)]; }); };
      var first = c.lacks.slice(0, 40), rest = c.lacks.slice(40);
      b.appendChild(el("div", {cls: "names"}, pl(c.lacks.length, "C name") + " System lacks here: ", names(first),
        rest.length ? el("details", {cls: "down"}, el("summary", {text: "and " + fmt(rest.length) + " more"}), names(rest)) : null));
    }
    if (c.partial) b.appendChild(el("p", {cls: "hint", text: "Read in part: " + c.partial + "."}));
    if (!n) return b;
    var tb = el("table", {cls: "ledger"},
      el("colgroup", null, [22, 9, 10, 12, 12, 15, 20].map(function (w) { return el("col", {style: "width: " + w + "%"}); })),
      el("tr", null, el("th", {text: "Where"}), el("th", {text: "What"}), el("th", {text: "Platforms"}),
         el("th", {text: "Whose work"}), el("th", {text: "Category"}), el("th", {text: "C names it serves"}), el("th", {text: "Why"})));
    c.sites.forEach(function (s) {
      var f = S(s[0]);
      var what = S(s[9]) === "marker" ? "a gap marker" : (S(s[2]) ? "import " + S(s[2]) + (S(s[10]) && S(s[10]) !== "whole" ? " (" + S(s[10]) + ")" : "") : "");
      tb.appendChild(el("tr", null,
        el("td", {cls: "at"}, ghLink(c.link, f, s[1], f + ":" + s[1])),
        el("td", {text: what}),
        el("td", {text: Model.platforms(s[4]).join(", ") || "none"}),
        el("td", null, el("span", {cls: "swatch " + SPLIT[s[11]]}), L.split[SPLIT[s[11]]]),
        el("td", {text: L.categories[CATS[s[3]]]}),
        el("td", null, s[5].slice(0, 12).map(function (k, i) { return [i ? " " : "", code(S(k))]; }), s[5].length > 12 ? " …" : ""),
        el("td", {text: S(s[7])})));
    });
    b.appendChild(el("div", {cls: "scroll"}, tb));
    b.appendChild(el("p", {cls: "hint", text: "Read at its newest migration work, or its clone here; More detail says which."}));
    return b;
  }

  // The split of a package's C uses, in words, with the page's swatches.
  function splitLine(n, unit) {
    return el("div", {cls: "split-nums"}, SPLIT.map(function (b, i) {
      return el("span", null, el("span", {cls: "swatch " + b}), fmt(n[i]) + " " + L.split[b] +
        (b === "covers" ? " (adopter work)" : b === "lacks" ? " (System work)" : ""));
    }));
  }

  function scanBlock(p, c) {
    var b = el("div");
    var files = c.files === null || c.files === undefined ? "?" : c.files;
    b.appendChild(el("p", null, el("b", {text: fmt(files)}), " library " + (files === 1 ? "file imports" : "files import") + " Darwin" +
      ((c.fb || []).length !== files ? "; " + pl((c.fb || []).length, "file") + " import it or use its C names" : "") + "."));
    if ((c.fb || []).length) b.appendChild(splitLine(splitOf(c.fb.map(function (x) { return x[1]; })), "file"));
    if (c.fileList && c.fileList.length) {
      var ul = el("ul", {cls: "sites"});
      c.fileList.forEach(function (k) { var f = S(k); ul.appendChild(el("li", null, ghLink(c.link, f, null, f))); });
      b.appendChild(ul);
    }
    if (c.names.length) {
      var kinds = {};
      c.names.forEach(function (x) { var k = S(x[1]); kinds[k] = (kinds[k] || 0) + 1; });
      b.appendChild(el("p", null, "Those files use " + pl(c.names.length, "C name") + ": " +
        Object.keys(kinds).map(function (k) { return fmt(kinds[k]) + " " + ((L.queueKinds || {})[k] || k); }).join(", ") + "."));
      var tb = el("table", {cls: "ledger"},
        el("colgroup", null, [22, 22, 8, 48].map(function (w) { return el("col", {style: "width: " + w + "%"}); })),
        el("tr", null, el("th", {text: "C name"}), el("th", {text: "When scanned"}), el("th", {text: "Uses"}), el("th", {text: "Files"})));
      c.names.forEach(function (x) {
        tb.appendChild(el("tr", null, el("td", null, code(S(x[0]))), el("td", {text: (L.queueKinds || {})[S(x[1])] || S(x[1])}),
                          el("td", {text: fmt(x[2])}), el("td", {cls: "at", text: x[3].map(S).join(", ")})));
      });
      b.appendChild(el("div", {cls: "scroll"}, tb));
    }
    b.appendChild(el("p", {cls: "hint", text: "Darwin only, in library targets, scanned " + (c.run ? c.run[1] : c.date || "?") +
      (c.run ? "; System has grown since, so it may cover more now" : "") +
      ". Other platforms' C modules weren't scanned for packages outside update-checkout. More detail says from what."}));
    return b;
  }

  function gapsBlock(c) {
    var b = el("div");
    if (!c.gaps.length) { b.appendChild(el("p", {cls: "hint", text: "GAPS.md lists nothing this tool needs."})); return b; }
    b.appendChild(el("p", null, "It needs " + pl(c.gaps.length, "thing") + " System doesn't have, by the examples' own list of gaps (GAPS.md, kept by hand):"));
    var tb = el("table", {cls: "ledger"},
      el("colgroup", null, [22, 20, 14, 44].map(function (w) { return el("col", {style: "width: " + w + "%"}); })),
      el("tr", null, el("th", {text: "What"}), el("th", {text: "For"}), el("th", {text: "Platforms"}), el("th", {text: "Note"})));
    c.gaps.forEach(function (g) {
      tb.appendChild(el("tr", null, el("td", null, ticks(S(g[0]))), el("td", null, ticks(S(g[1]))), el("td", null, ticks(S(g[2]))), el("td", null, ticks(S(g[3])))));
    });
    b.appendChild(tb);
    return b;
  }

  function pkgMore(p) {
    var rows = [
      ["Listed by", p.s],
      ["Clone here", p.cl ? el("span", {cls: "mono", text: p.cl}) : "none"],
      ["Swift code", p.sw === "yes" ? "yes" : p.sw === "no" ? "no" : "unknown (no clone)"]
    ];
    if (p.mig) {
      rows.push(["Migration branches", Object.keys(p.mig.br).map(function (b) { return b + " " + short(p.mig.br[b]); }).join(", ")]);
      rows.push(["Newest", p.mig.nb + " at " + short(p.mig.nc) + ", " + pl(p.mig.nn, "commit") + " past main" + (p.mig.ns ? ": " + p.mig.ns : "")]);
      rows.push(["Use read at", p.mig.rb ? p.mig.rb + " at " + short(p.mig.rc) + " (" + (p.mig.rr || "?") + (p.mig.bs ? "; build " + p.mig.bs : "") + ")" : "not read: api-graph couldn't read this clone (About, Known limits)"]);
    }
    if (p.a) rows.push(["Set aside", p.a.by + ": " + p.a.why + " (Utilities/master-view/set-aside.tsv)"]);
    if (p.use) rows.push(["Uses from", "the API graph at " + short(meta.graph.commit) + ", reading " + (p.use.b || "?") + " at " + short(p.use.c) +
      (p.sd ? ", the files under " + p.sd : "") +
      (p.use.cache ? "; API already on main from the same build's index (api-graph's adopter cache)" : "")]);
    if (p.use) rows.push(["Links", p.use.link ? "to GitHub, where it has the commit" : "none: the commit is only local"]);
    if (p.cu && p.cu.src === "ledger" && p.cu.where) rows.push(["C use from", "the ledger (status.sh's ledger.json), read at " + p.cu.where.replace(/`/g, "")]);
    if (p.cu && p.cu.src === "scan") rows.push(["C use from", "the ecosystem survey (" + (p.cu.date || "?") + ") at " + short(p.cu.commit) +
      (p.cu.run ? ", and the coverage tools' ecosystem run " + p.cu.run[0] + " of " + p.cu.run[1] + ", against System at " + short(p.cu.run[2]) : "")]);
    if (p.cu && p.cu.src === "GAPS.md") rows.push(["Gaps from", "swift-system-examples' GAPS.md, on main at " + short(p.cu.commit)]);
    return facts(rows);
  }

  function openPkg(i) {
    F.q = ""; document.getElementById("q").value = "";
    F.cluster = "all"; document.getElementById("f-cluster").value = "all";
    F.kind = "all"; document.getElementById("f-kind").value = "all";
    F.onlyPkg = null;
    openPkgs[i] = true;
    tab = "pkg";
    document.getElementById("tab-api").setAttribute("aria-selected", false);
    document.getElementById("tab-pkg").setAttribute("aria-selected", true);
    render();
    history.replaceState(null, "", "#pkg=" + encodeURIComponent(M.pkgs[i].n));
    var r = document.querySelector('[data-pkg="' + i + '"]');
    if (r) r.scrollIntoView({block: "center"});
  }

  // ---------------------------------------------------------------- about

  function about() {
    var b = document.getElementById("about-body");
    b.textContent = "";
    var led = meta.ledger || {};
    var uc = meta.universe.counts;
    var asideRows = M.pkgs.filter(function (p) { return p.a; });
    b.appendChild(el("h2", {text: "What the figures at the top mean"}));
    var ul = el("ul");
    [
      ["New API: ", "a public declaration in SystemPackage or SystemSockets that system-next has and main doesn't, exactly as api-delta lists it as added: " +
        fmt(H.declarations) + " (" + fmt(meta.apiDelta.added) + " in the macOS symbol graphs and " + fmt(meta.apiDelta.hidden) +
        " the source scan finds besides, compiled only on other platforms or renaming stubs). It's the universe of what System could ship, and only grows; it's context, not progress."],
      ["In use: ", "a new declaration that a real user's code uses: an adopter (a package in one of the three library clusters, read at its newest migration branch: migrate-all, else migrate-unix, else migrate-darwin) or the examples (swift-system-examples' tools and their shared code, at its main). A use is a file and line, found by the compiler's index of a build against system-next, or by name where that build doesn't compile."],
      ["Not yet in a pitch: ", "in use, and in no pitch file in Prototype/Pitches (deprecated, underscored and SPI declarations aside, which pitches leave out). In a pitch is a pitch draft, pitched, a PR open, or merged."],
      ["Platform C uses left: ", "what each cluster's packages still use from a platform C module. In update-checkout, the ledger's sites (status.sh): each import of a platform C module that modules.ini counts, at its file and line, or a SYSTEM-GAP marker over none, on any platform, excluded ones aside: " +
        fmt(led.total) + " now. In swiftlang and apple and in ecosystem, the library files that import Darwin or use its C names, from the coverage tools' scans (Darwin and library targets only, dated). For the examples, the gaps GAPS.md lists, each counted once however many tools need it."],
      ["System covers it: ", "the adopter's work. System covers every C name the site or file uses (the ledger's unexplained sites whose names it all covers, and the scans' files that use only names System has)."],
      ["System lacks it: ", "System's work first. A C name System lacks, a SYSTEM-GAP marker (the adopter's own note that System lacks something; the ledger can't tie most of them to a C name), work queued for System, or a gap in GAPS.md."],
      ["Other: ", "neither yet: the standard library has it (the adopter's work, but not System's API), work queued for the adopter, approved to stay on C, undecided, not System's (a lane's verdict), another module or the package's own C shim has it, or no C name was found."],
      ["Since: ", "each figure's change from the run before, in words: what moved, and why. A package read for the first time, or a SYSTEM-GAP marker over C a package already used, is newly counted, not new C."],
      ["Set aside: ", asideRows.length ? asideRows.map(function (p) { return p.n + " (" + p.a.by + ": " + p.a.why + ")"; }).join("; ") +
        ". They're shown in the explorer, and counted in none of the figures at the top. The list is Utilities/master-view/set-aside.tsv." : "nothing."]
    ].forEach(function (x) { ul.appendChild(el("li", null, el("b", {text: x[0]}), x[1])); });
    b.appendChild(ul);

    b.appendChild(el("h2", {text: "The explorer"}));
    var ex = el("ul");
    [
      ["By API: ", "area › type › declaration, every declaration system-next adds, with each user and site, and its pitch state."],
      ["By package: ", "every package of the universe, by cluster: the System API it uses (new, and already on main), and what it still uses from C."],
      ["Use: ", "used by anyone; by adopters (a package of the three library clusters); by the examples; or by no one: among the packages the other filters leave in."],
      ["Data: ", L.kinds.migrated + " (a migration branch with commits); " + L.kinds["on-system"] + " (the examples' tools); " + L.kinds.scanned +
        " (no migration, but a scan of what it uses from C); " + L.kinds["not-scanned"] + "; " + L.kinds["no-swift"] + "."]
    ].forEach(function (x) { ex.appendChild(el("li", null, el("b", {text: x[0]}), x[1])); });
    b.appendChild(ex);

    b.appendChild(el("h2", {text: "The packages"}));
    var pu = el("ul");
    [
      [L.clusters[CL[0]] + " (" + fmt(uc[CL[0]]) + "): ", "the repositories swift's update-checkout clones for the main scheme (scheme-main.tsv), but swift-system itself. Those with no Swift code (C and C++ projects) are listed as such."],
      [L.clusters[CL[1]] + " (" + fmt(uc[CL[1]]) + "): ", "the swiftlang and apple GitHub organizations (their snapshots of 2026-10-01), less archived repositories, forks that update-checkout doesn't have, and anything already above. A repository with no clone here is “not scanned yet”, whatever its language."],
      [L.clusters[CL[2]] + " (" + fmt(uc[CL[2]]) + "): ", "the other clones under ../ecosystem: provisional, since no one has picked them."],
      [L.clusters[CL[3]] + " (" + fmt(uc[CL[3]]) + "): ", "the tools of swift-system-examples, on its main, and the library target they share. Each row is one target's directory."]
    ].forEach(function (x) { pu.appendChild(el("li", null, el("b", {text: x[0]}), x[1])); });
    b.appendChild(pu);
    var left = (notes.leftOut || []);
    if (left.length) {
      var why = {};
      left.forEach(function (r) { (why[r.why] = why[r.why] || []).push(r.name); });
      b.appendChild(down("Left out of the universe: " + pl(left.length, "repository", "repositories"),
        el("ul", null, Object.keys(why).map(function (k) { return el("li", null, el("b", {text: k + ": "}), why[k].join(", ")); }))));
    }

    b.appendChild(el("h2", {text: "Where the data comes from"}));
    var src = [
      ["New API, pitch states", "api-burndown's burndown.json, from api-delta (" + (meta.base.ref || "main") + " " + short(meta.base.commit) + " → " +
        (meta.head.ref || "system-next") + " " + short(meta.head.commit) + ")"],
      ["Uses", "the API graph at " + short(meta.graph.commit) + " (" + (meta.graph.date || "") + "): its usedBy links, each migrated package read at its newest of " +
        (meta.graph.adopterBranches || []).join(", ") + ", and swift-system-examples at its main"],
      ["API already on main", "the same builds' indexes, in api-graph's adopter cache" + (meta.graph.cache ? " (" + meta.graph.cache + ")" : "")],
      ["C uses left in update-checkout", led.date ? "the ledger, run on " + led.date + " against System at " + short(led.system) + " (status.sh's ledger.json and its STATUS.md); earlier days from STATUS.md's history in git" : "not available"],
      ["Other packages' C use", "the ecosystem survey" + (meta.survey.date ? " (" + meta.survey.date + ")" : "") + " and the coverage tools' newest ecosystem runs: " +
        (meta.runs || []).map(function (r) { return r.id + " (" + r.date + ")"; }).join(", ")],
      ["The examples' gaps", "swift-system-examples' GAPS.md, on main at " + short(meta.examples.commit)],
      ["The packages", "Utilities/master-view/universe.tsv, from scheme-main.tsv, the organizations' snapshots and the clones here; set-aside.tsv beside it"],
      ["This page", "Utilities/master-view/regenerate.sh, on " + meta.generated + ", from " + (meta.head.ref || "system-next") + " at " +
        short(meta.head.commit) + " and " + (meta.base.ref || "main") + " at " + short(meta.base.commit) + "; data digest " + String(PD.digest || "").slice(0, 12)]
    ];
    b.appendChild(facts(src));

    b.appendChild(el("h2", {text: "Known limits"}));
    var lim = el("ul");
    var unread = (notes.migratedWithoutUsage || []).map(function (i) { return M.pkgs[i].n; });
    [
      unread.length ? "Migrated, but with no use read: " + unread.join(", ") + ". api-graph reads a package whose manifest is at its clone's root; swift-stress-tester's is in a subdirectory." : null,
      "A use is precise where a Darwin build's index resolved it, and found by name elsewhere: in files the build doesn't compile, in #if branches Darwin doesn't take, and in packages that don't build (swift-testing's migrate-all needs Swift tools 6.3; sourcekit-lsp's build fails in part). API already on main is the Darwin build's index only.",
      "The examples' tests aren't read: only their tools' sources.",
      "Packages outside update-checkout were scanned only for Darwin, in their library targets, on " + ((meta.runs || [])[0] || {}).date + "; System has grown since, and the scan isn't run again here.",
      "The figures' history starts on " + ((M.charts.used || [])[0] || {}).date + " (the C uses in update-checkout, on the first day STATUS.md had the ledger). Their changes move with adopters' branches and System's API both.",
      "A commit only local (a migration's, the examples') has no web link; files at a clone's upstream commit link to GitHub."
    ].forEach(function (t) { if (t) lim.appendChild(el("li", {text: t})); });
    b.appendChild(lim);

    var bd = notes.branchDiffers || [];
    if (bd.length) b.appendChild(down("Packages whose newest branch isn't the one their use was read at: " + fmt(bd.length),
      (function () {
        var tb = el("table", {cls: "nums"}, el("tr", null, el("th", {text: "Package"}), el("th", {text: "Use read at"}), el("th", {text: "Newest branch"})));
        bd.forEach(function (x) {
          tb.appendChild(el("tr", null, el("td", {text: M.pkgs[x.package].n}),
            el("td", {cls: "l", text: x.readBranch ? x.readBranch + " " + short(x.readCommit) : "not read"}),
            el("td", {cls: "l", text: x.newest + " " + short(x.newestCommit)})));
        });
        return tb;
      })()));

    b.appendChild(el("h2", {text: "What the two ways in disagree about"}));
    var dis = el("ul");
    var shared = M.decls.filter(function (d) { return d.sameAs >= 0; });
    var sharedUsed = shared.filter(function (d) { return M.decls[d.sameAs].uses.length; }).length;
    dis.appendChild(el("li", null, fmt(shared.length) + " declarations compiled only off Darwin (or stubs) share their name with a Darwin declaration; api-burndown gives each the Darwin one's uses. Here a use is counted once, under the Darwin declaration, so By API and By package agree; " +
      fmt(sharedUsed) + " of them have uses through their variant."));
    var gp = notes.graphPackagesNotInUniverse || [];
    dis.appendChild(el("li", {text: gp.length ? "In the API graph but not in the universe: " + gp.join(", ") + "." : "Every package in the API graph is in the universe."}));
    var um = Object.keys(notes.usesOfPackagesNotInUniverse || {});
    dis.appendChild(el("li", {text: um.length ? "Uses by packages not in the universe, left out of both views: " + um.join(", ") + "." : "Every use is by a package in the universe, and each of the examples' uses is in one of its rows' directories."}));
    var lr = notes.ledgerReposNotInUniverse || [];
    dis.appendChild(el("li", {text: lr.length ? "In the ledger but not in the universe: " + lr.join(", ") + "." : "Every repository the ledger reads is in the update-checkout cluster, and the reverse."}));
    var iv = notes.indexVersusGraph || [];
    dis.appendChild(el("li", {text: iv.length ? "Where a build's index and the graph disagree about new API: " + iv.map(function (x) { return M.pkgs[x.package].n + " (" + x.indexOnly + " only in the index, " + x.graphOnly + " only in the graph)"; }).join("; ") + "." :
      "Each build's index references exactly the new declarations the graph says its package uses."}));
    if ((meta.problems || []).length) dis.appendChild(el("li", {text: "Inputs missing: " + meta.problems.join("; ")}));
    b.appendChild(dis);
  }

  function foot() {
    var f = document.getElementById("foot");
    f.textContent = "Generated " + meta.generated + " from " + (meta.head.ref || "system-next") + " and " + (meta.base.ref || "main") +
      "; About says from which commits, and how.";
  }

  // ---------------------------------------------------------------- render

  function render() {
    chips();
    var v = Model.view(M, F);
    document.getElementById("tab-api").textContent = "By API (" + fmt(v.decls.length) + ")";
    document.getElementById("tab-pkg").textContent = "By package (" + fmt(v.pkgs.length) + ")";
    var note = document.getElementById("tab-note");
    note.textContent = tab === "api" ? "Area › type › declaration. Click a row to open it." : "Click a package to see the System API it uses and what it still needs.";
    var root = document.getElementById("view");
    root.textContent = "";
    if (tab === "api") renderApi(root, v); else renderPkg(root, v);
  }

  function hash() {
    if (tab === "pkg") {
      var o = Object.keys(openPkgs).filter(function (k) { return openPkgs[k]; });
      history.replaceState(null, "", o.length === 1 ? "#pkg=" + encodeURIComponent(M.pkgs[+o[0]].n) : "#pkg");
    } else history.replaceState(null, "", "#api");
  }

  function route() {
    var h = decodeURIComponent((location.hash || "").slice(1));
    if (h.indexOf("pkg=") === 0) {
      var name = h.slice(4);
      var p = M.pkgs.filter(function (x) { return x.n === name; })[0];
      if (p) { openPkg(p.i); return; }
    }
    if (h.indexOf("decl=") === 0) {
      var ref = h.slice(5);
      if (ref in M.byRef) { openDecl(M.byRef[ref]); return; }
    }
    if (h === "pkg") { setTab("pkg"); return; }
    render();
  }

  lede();
  headline();
  controls();
  about();
  foot();
  route();
  window.addEventListener("hashchange", function () { route(); });
})();
