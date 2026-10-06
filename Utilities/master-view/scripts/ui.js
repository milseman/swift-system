// The master view's page: charts, filters, and the two views (By API and By
// package) over Model's data. Everything the data supplies goes into the DOM
// as text (textContent), never as markup.
"use strict";
(function () {
  var PD = JSON.parse(document.getElementById("data").textContent);
  var M = Model.build(PD);
  var meta = M.meta, L = meta.labels, notes = M.notes;
  var CL = ["update-checkout", "swiftlang and apple", "ecosystem", "Unix tools"];
  var KD = ["migrated", "scanned", "not-scanned", "no-swift"];
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

  function lede() {
    var p = document.getElementById("lede");
    p.textContent = "";
    var used = H.used, users = H.users;
    var mig = M.pkgs.filter(function (x) { return x.k === 0; }).length;
    add(p, ["system-next adds ", el("b", {text: fmt(H.declarations)}), " public declarations to Swift System on top of main (",
            fmt(H.mainCount), " counted below; the rest are renaming stubs and the like). ",
            el("b", {text: fmt(used)}), " of them are used by the ", fmt(users), " packages whose migrations to System were read, of ",
            fmt(mig), " migrated. Pick an API to see who uses it, or a package to see all the System API it uses and what it still needs from C."]);
    if (!H.byState[3] && !H.byState[4] && !H.byState[5]) add(p, " Nothing is pitched yet, so every count below is still to do.");
    var g = meta.graph || {};
    if (!g.matchesHead && g.withoutNode) add(p, " The newest " + fmt(g.withoutNode) + " declarations were added after uses were last read, so they show none yet.");
  }

  // ---------------------------------------------------------------- charts

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

  function niceMax(v) {
    if (v <= 4) return 4;
    var p = Math.pow(10, Math.floor(Math.log10(v)));
    var steps = [1, 1.5, 2, 2.5, 3, 4, 5, 6, 8, 10];
    for (var i = 0; i < steps.length; i++) if (steps[i] * p >= v) return steps[i] * p;
    return 10 * p;
  }

  function moveText(chart, r) {
    var out = [];
    var d = r.detail || {};
    if (chart === "cuses") {
      var ch = d.changes || {};
      var keys = Object.keys(ch).sort(function (a, b) { return Math.abs(ch[b]) - Math.abs(ch[a]); });
      if (keys.length) out.push(keys.map(function (k) { return k + " " + (ch[k] > 0 ? "+" : "") + fmt(ch[k]); }).join(", "));
      if (d.newRepos && d.newRepos.length) out.push("newly read: " + d.newRepos.join(", "));
      var nm = d.newlyMarked || {};
      var mk = Object.keys(nm).sort(function (a, b) { return nm[b] - nm[a]; });
      if (mk.length) out.push("newly marked (SYSTEM-GAP markers): " + mk.map(function (k) { return k + " +" + fmt(nm[k]); }).join(", "));
    } else {
      Object.keys(d).forEach(function (k) { if (d[k]) out.push(k + ": " + fmt(d[k])); });
    }
    return out.join("; ");
  }

  function drawChart(card, chart, series, opts) {
    var W = 360, Hh = 150, ml = 40, mr = 44, mt = 12, mb = 22;
    var pw = W - ml - mr, ph = Hh - mt - mb;
    var s = svg("svg", {viewBox: "0 0 " + W + " " + Hh, role: "img", "aria-label": opts.aria});
    if (!series.length) { card.appendChild(el("p", {cls: "hint", text: "No points yet."})); return; }
    // Each day is a band; a point's count holds across its band, until the next point.
    var d0 = dayNum(series[0].date), d1 = dayNum(series[series.length - 1].date);
    var span = d1 - d0 + 1, bw = pw / span;
    var top = 0;
    series.forEach(function (r, i) {
      top = Math.max(top, r.count);
      if (i > 0 && r.scopeAdded) top = Math.max(top, series[i - 1].count + r.scopeAdded);
    });
    var ymax = niceMax(Math.max(top, 1) * 1.05);
    var X = function (d) { return ml + (dayNum(d) - d0) * bw; };
    var Y = function (v) { return mt + ph - v / ymax * ph; };
    [0, ymax / 2, ymax].forEach(function (t) {
      s.appendChild(svg("line", {x1: ml, x2: ml + pw, y1: Y(t), y2: Y(t), "class": t === 0 ? "base" : "grid"}));
      s.appendChild(svg("text", {x: ml - 6, y: Y(t) + 4, "text-anchor": "end", "class": "tick", text: fmt(t)}));
    });
    s.appendChild(svg("text", {x: ml, y: Hh - 6, "text-anchor": "start", text: dayLabel(series[0].date)}));
    if (d1 > d0) s.appendChild(svg("text", {x: ml + pw, y: Hh - 6, "text-anchor": "end", text: dayLabel(series[series.length - 1].date)}));
    // The step line: each point holds until the next.
    var dpath = "M" + X(series[0].date) + "," + Y(series[0].count);
    for (var i = 1; i < series.length; i++) {
      dpath += " H" + X(series[i].date) + " V" + Y(series[i].count);
    }
    var last = series[series.length - 1];
    var xEnd = X(last.date) + bw;
    dpath += " H" + xEnd;
    var wash = dpath + " V" + Y(0) + " H" + X(series[0].date) + " Z";
    s.appendChild(svg("path", {d: wash, "class": "wash"}));
    s.appendChild(svg("path", {d: dpath, "class": "line"}));
    // Scope added: an orange riser of its size, from the day before's count.
    var risers = [];
    for (i = 1; i < series.length; i++) {
      var r = series[i];
      if (r.scopeAdded > 0) {
        var x = X(r.date), yb = Y(series[i - 1].count), yt = Y(series[i - 1].count + r.scopeAdded);
        s.appendChild(svg("line", {x1: x, x2: x, y1: yb, y2: yt, "class": "scope"}));
        risers.push({x: x, y: yt, n: r.scopeAdded});
      }
    }
    risers.sort(function (a, b) { return b.n - a.n; }).slice(0, 2).forEach(function (rz, k) {
      if (rz.n < ymax * 0.06) return;
      s.appendChild(svg("text", {x: rz.x - 4, y: rz.y + 10, "text-anchor": "end", "class": "lbl",
                                 text: "+" + fmt(rz.n) + (k === 0 ? " scope added" : "")}));
    });
    // The largest rise that isn't scope: labeled too, so that it can't pass for progress.
    var rise = null;
    for (i = 1; i < series.length; i++) {
      var net = series[i].count - series[i - 1].count - (series[i].scopeAdded || 0);
      if (net > 0 && (!rise || net > rise.n)) rise = {n: net, x: X(series[i].date), y: Y(series[i].count)};
    }
    if (rise && rise.n >= ymax * 0.04) {
      s.appendChild(svg("text", {x: rise.x - 4, y: rise.y - 5, "text-anchor": "end", "class": "lbl",
                                 text: "+" + fmt(rise.n) + ", not new scope"}));
    }
    s.appendChild(svg("circle", {cx: xEnd, cy: Y(last.count), r: 4, "class": "dot"}));
    s.appendChild(svg("text", {x: xEnd + 6, y: Y(last.count) + 4, "class": "lbl", text: fmt(last.count)}));
    // Hover: a crosshair at the nearest day, every point's numbers.
    var cross = svg("line", {x1: 0, x2: 0, y1: mt, y2: mt + ph, "class": "cross", visibility: "hidden"});
    s.appendChild(cross);
    var hit = svg("rect", {x: ml - 6, y: mt - 6, width: pw + 12, height: ph + 12, "class": "hit", tabindex: 0});
    function at(evt) {
      var box = s.getBoundingClientRect();
      var px = (evt.clientX - box.left) / box.width * W;
      var day = Math.floor(d0 + (px - ml) / bw);
      day = Math.max(d0, Math.min(d1, day));
      var k = 0;
      for (var j = 0; j < series.length; j++) if (dayNum(series[j].date) <= day) k = j;
      return {k: k, day: day};
    }
    function tipFor(k, day) {
      var r = series[k], prev = series[k - 1];
      var exact = dayNum(r.date) === day;
      var date = new Date(day * 86400000).toISOString().slice(0, 10);
      var out = [el("div", {cls: "tr", text: dayLabel(date) + (exact ? "" : " (not measured; " + dayLabel(r.date) + "'s count)")}),
                 el("div", {cls: "tv", text: fmt(r.count)})];
      if (exact && k === 0) out.push(el("div", {cls: "tr", text: "the first day: everything here is the starting scope"}));
      if (exact && k > 0) {
        var delta = r.count - prev.count;
        out.push(el("div", {cls: "tr", text: (delta >= 0 ? "+" : "") + fmt(delta) + " since " + dayLabel(prev.date)}));
        if (r.scopeAdded) out.push(el("div", null, el("span", {cls: "tk scope"}), "+" + fmt(r.scopeAdded) + " scope added"));
        var mt_ = moveText(chart, r);
        if (mt_) out.push(el("div", {cls: "tr", text: mt_}));
      }
      return out;
    }
    hit.addEventListener("pointermove", function (evt) {
      var a = at(evt);
      var x = ml + (a.day - d0 + 0.5) * bw;
      cross.setAttribute("x1", x); cross.setAttribute("x2", x); cross.setAttribute("visibility", "visible");
      showTip(evt, tipFor(a.k, a.day));
    });
    hit.addEventListener("pointerleave", function () { cross.setAttribute("visibility", "hidden"); hideTip(); });
    hit.addEventListener("focus", function () {
      var b = s.getBoundingClientRect();
      showTip({clientX: b.right - 40, clientY: b.top + 20}, tipFor(series.length - 1, d1));
    });
    hit.addEventListener("blur", hideTip);
    s.appendChild(hit);
    card.appendChild(s);
    var lg = el("div", {cls: "legend"}, el("span", null, el("span", {cls: "key"}), opts.lineLabel));
    if (risers.length) lg.appendChild(el("span", null, el("span", {cls: "key scope"}), "scope added: " + opts.scopeLabel));
    card.appendChild(lg);
    // The table view.
    var tb = el("table", {cls: "nums"}, el("tr", null, el("th", {text: "Day"}), el("th", {text: "Count"}),
                                          el("th", {text: "Scope added"}), el("th", {text: "Other changes"})));
    series.slice().reverse().forEach(function (r) {
      tb.appendChild(el("tr", null, el("td", {text: r.date}), el("td", {text: fmt(r.count)}),
                        el("td", {text: r.scopeAdded ? "+" + fmt(r.scopeAdded) : ""}),
                        el("td", {cls: "l", text: moveText(chart, r) + (r.source && r.source !== "run" ? " (" + r.source + ")" : "")})));
    });
    card.appendChild(el("details", null, el("summary", {text: "Show the numbers"}), tb));
  }

  function charts() {
    var box = document.getElementById("charts");
    box.textContent = "";
    var c = M.charts;
    var draft = H.byState[2];
    var outside = H.declarations - H.mainCount;
    var led = meta.ledger || {};
    var bc = led.byCategory || {};
    var specs = [
      {key: "unpitched", title: "New API not yet in a pitch", value: H.byState[1],
       small: "of " + fmt(H.mainCount) + " new declarations",
       sub: "Public declarations system-next adds over main that no pitch includes yet; " + fmt(draft) +
            " are in pitch drafts. " + fmt(outside) + " renaming stubs and the like aren't counted.",
       line: "not yet in a pitch", scope: "new API joined", aria: "New API not yet in a pitch, by day"},
      {key: "pitched", title: "Pitched, not yet merged", value: H.byState[3] + H.byState[4],
       small: fmt(H.byState[5]) + " merged",
       sub: "Declarations in a pitch that's been posted, or has a PR open, until main has them. " +
            "Flat at zero until the first pitch goes out.",
       line: "pitched or in a PR", scope: "pitched straight away", aria: "Pitched API not yet merged, by day"},
      {key: "cuses", title: "Platform C uses left in the toolchain's packages", value: led.total,
       small: (bc.exception ? fmt(bc.exception) + " approved to stay" : ""),
       sub: "Imports of a platform C module (and markers of a gap) left in the update-checkout cluster's packages, " +
            "each counted once. Goes down as packages move onto System.",
       line: "uses left", scope: "C uses newly marked, or a package read for the first time", aria: "Platform C uses left, by day"}
    ];
    specs.forEach(function (sp) {
      var card = el("article", {cls: "card"},
                    el("h2", {text: sp.title}),
                    el("div", {cls: "fig"}, fmt(sp.value), sp.small ? el("small", {text: sp.small}) : null),
                    el("p", {cls: "sub", text: sp.sub}));
      drawChart(card, sp.key, c[sp.key] || [], {lineLabel: sp.line, scopeLabel: sp.scope, aria: sp.aria});
      box.appendChild(card);
    });
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
    option(u, "used", "Used by a package");
    option(u, "unused", "Not used yet");
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
      charts();
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
      box.appendChild(el("p", {cls: "hint", text: "No migration read so far uses it. Only migrated packages show uses: see About."}));
    }
    box.appendChild(down("More detail", facts([
      ["Module", d.module],
      ["Kind", d.kind],
      ["Full name", el("span", {cls: "mono", text: d.path})],
      ["Type", el("span", {cls: "mono", text: d.type})],
      ["Area", M.areas[d.area].name + " (" + M.areas[d.area].module + ")"],
      ["Listed by", Model.flag(d, "hidden") ? "api-delta's source scan (not in the macOS symbol graphs)" : "api-delta, from the macOS symbol graphs"],
      ["Uses from", "api-graph at " + short(meta.graph.commit) + ", reading each package's " + (meta.graph.adopterBranch || "migration") + " branch"]
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
      return pl(c.sites.length, "C use") + " left";
    }
    if (c.src === "scan") {
      if (!c.files && !c.names.length) return "no Darwin import found";
      var g = c.names.filter(function (x) { return S(x[1]) === "gap"; }).length;
      return pl(c.files || 0, "file") + " import Darwin" + (g ? "; System lacks " + g : "");
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
        el("small", {text: pl(g.length, "package") + ": " + KD.map(function (k, j) { return kinds[j] ? fmt(kinds[j]) + " " + L.kinds[k] : null; }).filter(Boolean).join(", ")})));
      g.forEach(function (i) { pkgRow(root, M.pkgs[i], v.pkgUses[i]); });
    });
    if (!v.pkgs.length) root.appendChild(el("p", {cls: "hint", text: "No package matches. Clear the search or the filters."}));
  }

  function pkgRow(root, p, uses) {
    var isOpen = !!openPkgs[p.i];
    var nm = p.use && p.use.main ? p.use.main.length : 0;
    var apiText = p.use ? fmt(uses.length) + " new · " + fmt(nm) + " already on main" : (p.k === 0 ? "use not read yet" : "—");
    var row = el("div", {cls: "row pkg-row" + (isOpen ? " open" : ""), role: "button", tabindex: 0, "aria-expanded": isOpen, "data-pkg": p.i},
      el("span", {cls: "pn", text: p.n}),
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

  function pkgDetail(p, uses) {
    var box = el("div", {cls: "detail pkg-detail"});
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
      box.appendChild(el("p", {cls: "hint", text: p.mig && p.mig.nb !== p.use.b ?
        "Read from an earlier step of its migration: its newest work isn't counted here yet (More detail says which)." :
        "Read from its newest migration work."}));
    } else if (p.k === 0) {
      box.appendChild(el("p", {cls: "warn", text: "Not read yet: its migration is at a later step than the one uses are read from (More detail)."}));
    } else if (p.c === 3) {
      box.appendChild(el("p", {cls: "hint", text: "Not scanned yet. The tool is written on System from the start, so all of its system calls go through System; nothing here reads which API it calls."}));
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
      marked ? " On " + dayLabel(lastPt.date) + ", " + fmt(marked) + " of them were newly marked: SYSTEM-GAP markers its migration added over C it already used, counted from then on (scope added, not new C)." : null));
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
      el("colgroup", null, [26, 10, 11, 13, 18, 22].map(function (w) { return el("col", {style: "width: " + w + "%"}); })),
      el("tr", null, el("th", {text: "Where"}), el("th", {text: "What"}), el("th", {text: "Platforms"}),
         el("th", {text: "Category"}), el("th", {text: "C names it serves"}), el("th", {text: "Why"})));
    c.sites.forEach(function (s) {
      var f = S(s[0]);
      var what = S(s[9]) === "marker" ? "a gap marker" : (S(s[2]) ? "import " + S(s[2]) + (S(s[10]) && S(s[10]) !== "whole" ? " (" + S(s[10]) + ")" : "") : "");
      tb.appendChild(el("tr", null,
        el("td", {cls: "at"}, ghLink(c.link, f, s[1], f + ":" + s[1])),
        el("td", {text: what}),
        el("td", {text: Model.platforms(s[4]).join(", ") || "none"}),
        el("td", {text: L.categories[CATS[s[3]]]}),
        el("td", null, s[5].slice(0, 12).map(function (k, i) { return [i ? " " : "", code(S(k))]; }), s[5].length > 12 ? " …" : ""),
        el("td", {text: S(s[7])})));
    });
    b.appendChild(el("div", {cls: "scroll"}, tb));
    b.appendChild(el("p", {cls: "hint", text: "Read at its newest migration work, or its clone here; More detail says which."}));
    return b;
  }

  function scanBlock(p, c) {
    var b = el("div");
    var files = c.files === null || c.files === undefined ? "?" : c.files;
    b.appendChild(el("p", null, el("b", {text: fmt(files)}), " library " + (files === 1 ? "file imports" : "files import") + " Darwin."));
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
      rows.push(["Use read at", p.mig.rb ? p.mig.rb + " at " + short(p.mig.rc) + " (" + (p.mig.rr || "?") + (p.mig.bs ? "; build " + p.mig.bs : "") + ")" : "not read (api-graph reads migrate-darwin only)"]);
    }
    if (p.use) rows.push(["Uses from", "the API graph at " + short(meta.graph.commit) + ", reading " + (p.use.b || "?") + " at " + short(p.use.c) +
      (p.use.cache ? "; API already on main from the same build's index (api-graph's adopter cache)" : "")]);
    if (p.use) rows.push(["Links", p.use.link ? "to GitHub, where it has the commit" : "none: the migration's commits are only local"]);
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
    b.appendChild(el("h2", {text: "What the numbers mean"}));
    var ul = el("ul");
    [
      ["New API: ", "a public declaration in SystemPackage or SystemSockets that system-next has and main doesn't, exactly as api-delta lists it as added: " +
        fmt(H.declarations) + " (" + fmt(meta.apiDelta.added) + " in the macOS symbol graphs and " + fmt(meta.apiDelta.hidden) +
        " the source scan finds besides, compiled only on other platforms or renaming stubs). Overloads and per-platform variants count separately."],
      ["Counted: ", fmt(H.mainCount) + " of them. Renaming stubs (unavailable declarations that point from a C name to the Swift one), deprecated, underscored and SPI declarations are listed but not counted, as api-burndown counts."],
      ["Pitch states: ", "not in a pitch; in a pitch draft (a file in Prototype/Pitches includes it); pitched and PR open (dated in Prototype/Burndown/states.json); merged (main has it now)."],
      ["Used by: ", "a package whose migration branch uses the declaration; a site is a file and line where it does, found by the compiler's index of the migration's build, or by name in code the build didn't compile. A type named only to qualify another name (PThread in PThread.Mutex) is a site “naming the type to qualify another name”."],
      ["Already on main: ", "API main already has, used by a migrated package, from the same build's index. It counts toward nothing above: only the third chart counts what's left on C."],
      ["C uses left: ", "for the update-checkout cluster, the ledger's sites: each import of a platform C module (Darwin, Glibc, WinSDK and the rest that modules.ini counts) at its file and line, or a SYSTEM-GAP marker over none, with excluded ones (test data, Apple's internal build) left out: " +
        fmt(led.total) + " now, of which " + fmt((led.byCategory || {}).exception || 0) + " are approved to stay on C. Each has one category: " +
        CATS.filter(function (k) { return (led.byCategory || {})[k]; }).map(function (k) { return L.categories[k] + " " + fmt(led.byCategory[k]); }).join(", ") + "."],
      ["Scope added: ", "the part of a chart's rise that's new to what it counts: new API on system-next (charts 1 and 2); for chart 3, a package read for the first time, or SYSTEM-GAP markers a package's migration added over C it already used, which the ledger counts from then on. It's drawn as an orange riser of its own size, from the day before's count; the blue line is the count itself."]
    ].forEach(function (x) { ul.appendChild(el("li", null, el("b", {text: x[0]}), x[1])); });
    b.appendChild(ul);

    b.appendChild(el("h2", {text: "The packages"}));
    var pu = el("ul");
    [
      [L.clusters[CL[0]] + " (" + fmt(uc[CL[0]]) + "): ", "the repositories swift's update-checkout clones for the main scheme (scheme-main.tsv), but swift-system itself. Those with no Swift code (C and C++ projects) are listed as such."],
      [L.clusters[CL[1]] + " (" + fmt(uc[CL[1]]) + "): ", "the swiftlang and apple GitHub organizations (their snapshots of 2026-10-01), less archived repositories, forks that update-checkout doesn't have, and anything already above. A repository with no clone here is “not scanned yet”, whatever its language."],
      [L.clusters[CL[2]] + " (" + fmt(uc[CL[2]]) + "): ", "the other clones under ../ecosystem: provisional, since no one has picked them."],
      [L.clusters[CL[3]] + " (" + fmt(uc[CL[3]]) + "): ", "the tools of swift-system-examples, on its main."]
    ].forEach(function (x) { pu.appendChild(el("li", null, el("b", {text: x[0]}), x[1])); });
    b.appendChild(pu);
    b.appendChild(el("p", null, "Each package's data: ", el("b", {text: L.kinds.migrated}), " (it has a migration branch with commits: its use of System, and what's left on C at its newest branch, migrate-all, then migrate-unix, then migrate-darwin); ",
      el("b", {text: L.kinds.scanned}), " (no migration: what it uses from C, where a scan exists); ", el("b", {text: L.kinds["not-scanned"]}), "; or ",
      el("b", {text: L.kinds["no-swift"]}), "."));
    var left = (notes.leftOut || []);
    if (left.length) {
      var why = {};
      left.forEach(function (r) { (why[r.why] = why[r.why] || []).push(r.name); });
      b.appendChild(down("Left out of the universe: " + pl(left.length, "repository", "repositories"),
        el("ul", null, Object.keys(why).map(function (k) { return el("li", null, el("b", {text: k + ": "}), why[k].join(", ")); }))));
    }

    b.appendChild(el("h2", {text: "Where the data comes from"}));
    var src = [
      ["New API, pitch states, charts 1 and 2", "api-burndown's burndown.json, from api-delta (" + (meta.base.ref || "main") + " " + short(meta.base.commit) + " → " +
        (meta.head.ref || "system-next") + " " + short(meta.head.commit) + ") and its history, one point per day"],
      ["Uses", "the API graph at " + short(meta.graph.commit) + " (" + (meta.graph.date || "") + "): its usedBy links, read on each package's " + (meta.graph.adopterBranch || "?") + " branch"],
      ["API already on main", "the same migrations' build indexes, in api-graph's adopter cache" + (meta.graph.cache ? " (" + meta.graph.cache + ")" : "")],
      ["C uses left", led.date ? "the ledger, run on " + led.date + " against System at " + short(led.system) + " (status.sh's ledger.json and its STATUS.md); earlier days from STATUS.md's history in git" : "not available"],
      ["Other packages' C use", "the ecosystem survey" + (meta.survey.date ? " (" + meta.survey.date + ")" : "") + " and the coverage tools' newest ecosystem runs: " +
        (meta.runs || []).map(function (r) { return r.id + " (" + r.date + ")"; }).join(", ")],
      ["The Unix tools' gaps", "swift-system-examples' GAPS.md, on main at " + short(meta.examples.commit)],
      ["The packages", "Utilities/master-view/universe.tsv, from scheme-main.tsv, the organizations' snapshots and the clones here"],
      ["This page", "Utilities/master-view/regenerate.sh, on " + meta.generated + ", from " + (meta.head.ref || "system-next") + " at " +
        short(meta.head.commit) + " and " + (meta.base.ref || "main") + " at " + short(meta.base.commit) + "; data digest " + String(PD.digest || "").slice(0, 12)]
    ];
    b.appendChild(facts(src));

    b.appendChild(el("h2", {text: "Known limits"}));
    var lim = el("ul");
    [
      "Uses come only from migrate-darwin branches: api-graph reads no other. Most migrations have moved on to migrate-unix or migrate-all, so their newest uses aren't here yet (the list below), and swift-crypto, swift-stress-tester and swift-testing, migrated only on migrate-all, show none.",
      "A migration's commits are only local, so its use sites have no web link; files at a clone's upstream commit link to GitHub.",
      "API already on main is what the migration's Darwin build compiled, from its index; new API also has uses found by name outside the build.",
      "Packages outside update-checkout were scanned only for Darwin imports in their library targets, and that scan is from " + ((meta.runs || [])[0] || {}).date + "; System has grown since.",
      "The Unix tools' use of System isn't scanned; their gaps are GAPS.md's, kept by hand.",
      "The C-use chart starts on the first day STATUS.md had the ledger; earlier days have no figure. Its counts move when adopters' branches move, not only when System grows."
    ].forEach(function (t) { lim.appendChild(el("li", {text: t})); });
    b.appendChild(lim);

    var bd = notes.branchDiffers || [];
    b.appendChild(down("Packages whose newest branch isn't the one their use was read at: " + fmt(bd.length),
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
    var mw = (notes.migratedWithoutUsage || []).map(function (i) { return M.pkgs[i].n; });
    dis.appendChild(el("li", {text: mw.length ? "Migrated, but with no use read (no migrate-darwin branch): " + mw.join(", ") + "." : "Every migrated package has its use read."}));
    var gp = notes.graphPackagesNotInUniverse || [];
    dis.appendChild(el("li", {text: gp.length ? "In the API graph but not in the universe: " + gp.join(", ") + "." : "Every package in the API graph is in the universe."}));
    var um = Object.keys(notes.usesOfPackagesNotInUniverse || {});
    dis.appendChild(el("li", {text: um.length ? "Uses by packages not in the universe, left out of both views: " + um.join(", ") + "." : "Every use is by a package in the universe."}));
    var lr = notes.ledgerReposNotInUniverse || [];
    dis.appendChild(el("li", {text: lr.length ? "In the ledger but not in the universe: " + lr.join(", ") + "." : "Every repository the ledger reads is in the update-checkout cluster, and the reverse."}));
    var iv = notes.indexVersusGraph || [];
    dis.appendChild(el("li", {text: iv.length ? "Where a build's index and the graph disagree about new API: " + iv.map(function (x) { return M.pkgs[x.package].n + " (" + x.indexOnly + " only in the index, " + x.graphOnly + " only in the graph)"; }).join("; ") + "." :
      "Each migration's build index references exactly the new declarations the graph says it uses."}));
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
  charts();
  controls();
  about();
  foot();
  route();
  window.addEventListener("hashchange", function () { route(); });
  if (window.matchMedia) window.matchMedia("(prefers-color-scheme: dark)").addEventListener("change", charts);
})();
