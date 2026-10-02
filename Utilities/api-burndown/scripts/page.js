// The burn-down page: decodes the inline data, then renders the totals, the
// chart, the groups and the declaration list against one set of filters.
// Every string from the data goes into the DOM as text, never as markup.
(function () {
  "use strict";

  const DATA = JSON.parse(document.getElementById("burndown-data").textContent);
  const S = DATA.S;
  const str = (i) => (i === undefined || i === null || i < 0 ? null : S[i]);
  const STATES = DATA.states;
  const STATE_LABEL = Object.fromEntries(STATES.map((s) => [s.id, s.label]));
  const FLAGS = DATA.flags;
  const EXCLUDED = new Set(DATA.excluded);
  const PLAT = DATA.platforms;
  const ROLES = DATA.roles;
  const META = DATA.meta;
  const fmt = (n) => Number(n).toLocaleString("en-US");
  const plural = (n, one, many) => `${fmt(n)} ${n === 1 ? one : many || one + "s"}`;
  const stateColor = (id) => `var(--state-${id})`;

  // ---------------------------------------------------------------- data

  const decls = DATA.D.map((r, i) => ({
    i, state: r[0], flagMask: r[1], module: str(r[2]), path: r[3], kind: str(r[4]), area: str(r[5]),
    file: str(r[6]), line: r[7], plat: r[8], pitch: str(r[9]), more: r[10].map(str), cname: str(r[11]),
    header: str(r[12]), sdk: str(r[13]), sub: str(r[14]), decl: r[15], avail: str(r[16]), doc: r[17],
    used: r[18], could: r[19], cnames: r[20], how: str(r[21]), excluded: r[22] === 1, reach: r[18].length,
    historyOnly: false,
  }));
  const extra = DATA.X.map((r, k) => ({
    i: decls.length + k, module: str(r[0]), path: r[1], kind: str(r[2]), area: str(r[3]), plat: r[4],
    flagMask: r[5], excluded: r[6] === 1, historyOnly: true, state: 0, pitch: null, more: [], cname: null,
    header: null, sdk: null, sub: null, reach: 0, used: [], cnames: [], decl: "", doc: "",
  }));
  const units = decls.concat(extra);
  for (const u of units) {
    u.flags = FLAGS.filter((f, b) => u.flagMask & (1 << b));
    u.hay = [u.path, u.cname, u.header, u.pitch, u.decl, u.file, u.sub,
      ...(u.cnames || []).map((c) => str(c[0]))].filter(Boolean).join("\n").toLowerCase();
  }
  const days = DATA.days;

  // ---------------------------------------------------------------- DOM helpers

  function el(tag, attrs, ...kids) {
    const e = document.createElement(tag);
    for (const [k, v] of Object.entries(attrs || {})) {
      if (v === null || v === undefined || v === false) continue;
      if (k === "class") e.className = v;
      else if (k === "text") e.textContent = v;
      else if (k === "style") e.style.cssText = v;
      else if (k.startsWith("on")) e.addEventListener(k.slice(2), v);
      else e.setAttribute(k, v === true ? "" : v);
    }
    for (const k of kids.flat()) {
      if (k === null || k === undefined || k === false) continue;
      e.appendChild(typeof k === "string" || typeof k === "number" ? document.createTextNode(String(k)) : k);
    }
    return e;
  }
  const SVG = "http://www.w3.org/2000/svg";
  function sv(tag, attrs, ...kids) {
    const e = document.createElementNS(SVG, tag);
    for (const [k, v] of Object.entries(attrs || {})) {
      if (v === null || v === undefined) continue;
      if (k === "text") e.textContent = v;
      else if (k === "style") e.setAttribute("style", v);
      else if (k.startsWith("on")) e.addEventListener(k.slice(2), v);
      else e.setAttribute(k, v);
    }
    for (const k of kids.flat()) if (k) e.appendChild(k);
    return e;
  }
  const $ = (id) => document.getElementById(id);
  const clear = (e) => { while (e.firstChild) e.removeChild(e.firstChild); return e; };
  const swatch = (id) => el("span", { class: "swatch", style: `background:${stateColor(id)}` });
  const shortDay = (d) => {
    const [y, m, dd] = d.split("-").map(Number);
    return new Date(Date.UTC(y, m - 1, dd)).toLocaleDateString("en-US", { month: "short", day: "numeric", timeZone: "UTC" });
  };

  // ---------------------------------------------------------------- filters

  const F = { q: "", module: "", kind: "", plat: "", area: "", outside: false, group: null };
  let view = "header";
  let listSort = "state";
  let listLimit = 200;
  const expanded = new Set();
  const openDetails = new Set();

  // Every filter but the one for declarations outside the count.
  function passesBase(u, opts) {
    if (F.module && u.module !== F.module) return false;
    if (F.kind && u.kind !== F.kind) return false;
    if (F.plat && !(u.plat & (1 << PLAT.indexOf(F.plat)))) return false;
    if (F.area && u.area !== F.area) return false;
    if (F.q && !u.hay.includes(F.q)) return false;
    if (!(opts && opts.noGroup) && F.group && !inGroup(u, F.group)) return false;
    return true;
  }
  const passes = (u, opts) => (F.outside || !u.excluded) && passesBase(u, opts);

  function options(select, label, values) {
    clear(select);
    select.appendChild(el("option", { value: "", text: `All (${label})` }));
    for (const [v, n] of values) select.appendChild(el("option", { value: v, text: `${v} (${fmt(n)})` }));
  }
  function countBy(fn) {
    const m = new Map();
    for (const u of decls) for (const k of [].concat(fn(u))) if (k) m.set(k, (m.get(k) || 0) + 1);
    return m;
  }
  options($("f-module"), "modules", [...countBy((u) => u.module)].sort());
  options($("f-kind"), "kinds", [...countBy((u) => u.kind)].sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0])));
  options($("f-plat"), "platforms",
    PLAT.map((p, b) => [p, decls.filter((u) => u.plat & (1 << b)).length]).filter((x) => x[1]));
  options($("f-area"), "areas", [...countBy((u) => u.area)].sort((a, b) => a[0].localeCompare(b[0])));

  let qTimer = null;
  $("f-q").addEventListener("input", (e) => {
    clearTimeout(qTimer);
    qTimer = setTimeout(() => { F.q = e.target.value.trim().toLowerCase(); listLimit = 200; render(); }, 150);
  });
  for (const [id, key] of [["f-module", "module"], ["f-kind", "kind"], ["f-plat", "plat"], ["f-area", "area"]]) {
    $(id).addEventListener("change", (e) => { F[key] = e.target.value; listLimit = 200; render(); });
  }
  $("f-outside").addEventListener("change", (e) => { F.outside = e.target.checked; render(); });
  $("f-reset").addEventListener("click", () => {
    Object.assign(F, { q: "", module: "", kind: "", plat: "", area: "", outside: false, group: null });
    $("f-q").value = "";
    for (const id of ["f-module", "f-kind", "f-plat", "f-area"]) $(id).value = "";
    $("f-outside").checked = false;
    listLimit = 200;
    render();
  });

  // ---------------------------------------------------------------- views

  const SPECIAL = new Set(["(no C name)", "(not on Darwin)", "(not in the macOS SDK)", "(in no SDK module)",
    "(no pitch)", "(unknown)"]);
  const VIEWS = [
    { id: "header", label: "Darwin header", levels: [(u) => u.sdk || "(unknown)", (u) => u.header || "(unknown)",
      (u) => u.cname || "(unknown)"],
      caption: "Each declaration under the first C name its doc comment names that the macOS SDK declares, " +
        "the header that declares it, and the header's SDK module. _DarwinFoundation1 to 3 are parts of the " +
        "C library that Darwin re-exports." },
    { id: "area", label: "System area", levels: [(u) => u.area || "(unknown)"],
      caption: "The directory under Sources/System or Sources/SystemSockets, or for a file at the top, its file group." },
    { id: "pitch", label: "Pitch", levels: [(u) => u.pitch || "(no pitch)"],
      caption: "The first pitch file, by name, whose rules match the declaration." },
    { id: "platform", label: "Platform", overlapping: true, levels: [(u) => PLAT.filter((p, b) => u.plat & (1 << b))],
      caption: "Every platform the declaration compiles on, so a declaration counts under each of its platforms." },
    { id: "kind", label: "Kind", levels: [(u) => u.kind || "(unknown)"], caption: "The declaration's kind." },
    { id: "reach", label: "Adopter reach", levels: [(u) => reachLabel(u.reach)], order: (k) => -reachOf(k),
      caption: "How many packages' migration branches use the declaration (the graph's usedBy)." },
  ];
  const reachLabel = (n) => (n === 0 ? "No packages" : plural(n, "package"));
  const reachOf = (k) => (k === "No packages" ? 0 : parseInt(k.replace(/,/g, ""), 10));
  const viewById = Object.fromEntries(VIEWS.map((v) => [v.id, v]));

  function inGroup(u, g) {
    const v = viewById[g.view];
    for (let lv = 0; lv < g.keys.length; lv++) {
      const k = v.levels[lv](u);
      if (Array.isArray(k) ? !k.includes(g.keys[lv]) : k !== g.keys[lv]) return false;
    }
    return true;
  }

  // ---------------------------------------------------------------- notices and header

  function renderHead() {
    $("subtitle").textContent = `Every public declaration ${META.headRef} adds over ${META.baseRef}, ` +
      `in SystemPackage and SystemSockets, as api-delta reports them. Generated ${META.generated} at ` +
      `${META.headRef} ${META.headCommit.slice(0, 10)}.`;
    const box = $("notices");
    const add = (title, ...rest) => box.appendChild(el("div", { class: "notice", role: "note" },
      el("span", { class: "icon", "aria-hidden": "true", text: "!" }),
      el("div", null, el("strong", { text: title }), " ", ...rest)));
    const up = META.upstream;
    if (up) {
      add(`${META.baseRef} is ${fmt(up.behind)} commits behind ${up.ref}.`,
        `${up.ref} (${up.commit.slice(0, 10)}${up.updated ? `, as of ${up.updated}` : ""}) already has ` +
        `${plural(up.declarations, "declaration")} counted here, flagged “upstream”. ` +
        `States are against ${META.baseRef}, as api-delta's are; update ${META.baseRef} to count them as merged.`);
    }
    const g = META.graph;
    if (!g.matchesHead) {
      add("The API graph isn't the head commit's.",
        `It's ${g.source}, so C names, pitches and adopters are as of ${(g.headCommit || "?").slice(0, 10)}` +
        (g.unitsWithoutNode ? `, and ${plural(g.unitsWithoutNode, "declaration")} it doesn't have show none.`
          : `; it has every declaration.`));
    }
    if (META.pitchesDirty) add("The pitch files have uncommitted changes.", "The states use the working tree's files.");
    for (const p of META.stateProblems) add("states.json:", p);
    for (const p of META.unknownPitches) add("states.json names a pitch with no file:", p);
    for (const p of META.pitchProblems.slice(0, 5)) add("Pitch file problem:", p);
  }

  // ---------------------------------------------------------------- tiles

  function renderTiles() {
    const box = clear($("tiles"));
    const counts = { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0 };
    let main = 0, outside = 0;
    for (const u of decls) {
      if (!passesBase(u)) continue;
      if (u.excluded) { outside++; if (F.outside) counts[u.state]++; continue; }
      counts[u.state]++;
      main++;
    }
    const total = F.outside ? main + outside : main;
    box.appendChild(el("div", { class: "tile hero" },
      el("span", { class: "label", text: F.outside ? "Declarations, including outside the count" : "Declarations to land" }),
      el("span", { class: "value", text: fmt(total) }),
      el("span", { class: "sub", text: `${fmt(counts[5])} merged, ${fmt(total - counts[5])} to go` })));
    for (const s of STATES) {
      box.appendChild(el("div", { class: "tile" },
        el("span", { class: "label" }, swatch(s.id), s.label),
        el("span", { class: "value", text: fmt(counts[s.id]) }),
        el("span", { class: "sub", text: total ? `${Math.round((counts[s.id] / total) * 1000) / 10}%` : "" })));
    }
    box.appendChild(el("div", { class: "tile" },
      el("span", { class: "label", text: "Outside the count" }),
      el("span", { class: "value", text: fmt(outside) }),
      el("span", { class: "sub", text: "deprecated, underscored, SPI, fix-it stubs" })));
  }
  // ---------------------------------------------------------------- chart

  const tip = $("tooltip");
  function showTip(evt, build) {
    clear(tip);
    build(tip);
    tip.hidden = false;
    const r = tip.getBoundingClientRect();
    let x, y;
    if (evt && evt.clientX !== undefined && evt.type !== "focus") { x = evt.clientX + 14; y = evt.clientY + 14; }
    else { const b = evt.target.getBoundingClientRect(); x = b.right + 8; y = b.top; }
    if (x + r.width > window.innerWidth - 8) x = Math.max(8, x - r.width - 28);
    if (y + r.height > window.innerHeight - 8) y = Math.max(8, window.innerHeight - r.height - 8);
    tip.style.left = `${x}px`;
    tip.style.top = `${y}px`;
  }
  const hideTip = () => { tip.hidden = true; };

  // Each day's counts by state. A day's code for a declaration says whether
  // it was outside the count that day (a to e) or in it (1 to 5).
  function dayCounts() {
    return days.map((d) => {
      if (!d.codes) return null;
      const c = { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0 };
      let outside = 0;
      for (let k = 0; k < d.codes.length; k++) {
        const ch = d.codes.charCodeAt(k);
        if (ch === 46 || !passesBase(units[k])) continue;  // "."
        if (ch >= 49 && ch <= 53) c[ch - 48]++;
        else if (F.outside) c[ch - 96]++;
        else outside++;
      }
      c.scope = c[1] + c[2] + c[3] + c[4] + c[5];
      c.outside = outside;
      return c;
    });
  }

  function niceMax(v) {
    if (v <= 0) return 10;
    const p = Math.pow(10, Math.floor(Math.log10(v)));
    for (const m of [1, 1.5, 2, 2.5, 3, 4, 5, 6, 8, 10]) if (m * p >= v) return m * p;
    return 10 * p;
  }
  function ticks(max) {
    const p = Math.pow(10, Math.floor(Math.log10(max)));
    let step = p;
    for (const m of [0.2, 0.25, 0.5, 1, 2, 2.5, 5]) { if (max / (m * p) <= 5) { step = m * p; break; } }
    const out = [];
    for (let v = 0; v <= max + 1e-9; v += step) out.push(Math.round(v));
    return out;
  }

  function renderChart() {
    const box = clear($("chart"));
    const counts = dayCounts();
    const W = Math.max(520, box.clientWidth || 900);
    const H = 340, mt = 22, mb = 40, ml = 54, mr = 120;
    const pw = W - ml - mr, ph = H - mt - mb;
    const n = days.length;
    const band = pw / Math.max(1, n);
    const cw = Math.min(24, band * 0.62);
    const maxScope = Math.max(1, ...counts.filter(Boolean).map((c) => c.scope));
    const ymax = niceMax(maxScope);
    const y = (v) => mt + ph - (v / ymax) * ph;
    const svg = sv("svg", { viewBox: `0 0 ${W} ${H}`, height: H, role: "img",
      "aria-label": `Declarations by state per day, ${days[0].day} to ${days[n - 1].day}` });
    const grid = sv("g", { class: "grid" });
    const axis = sv("g", { class: "axis" });
    for (const t of ticks(ymax)) {
      if (t > 0) grid.appendChild(sv("line", { x1: ml, x2: ml + pw, y1: y(t), y2: y(t) }));
      axis.appendChild(sv("text", { x: ml - 8, y: y(t) + 4, "text-anchor": "end", text: fmt(t) }));
    }
    svg.appendChild(grid);
    svg.appendChild(sv("line", { class: "baseline", x1: ml, x2: ml + pw, y1: y(0), y2: y(0) }));
    const every = Math.max(1, Math.ceil(n / Math.max(1, pw / 58)));
    days.forEach((d, i) => {
      if (i % every === 0 || i === n - 1) {
        axis.appendChild(sv("text", { x: ml + band * (i + 0.5), y: H - mb + 18, "text-anchor": "middle",
          text: shortDay(d.day) }));
      }
    });
    svg.appendChild(axis);

    const cols = sv("g");
    const pts = [];
    days.forEach((d, i) => {
      const cx = ml + band * (i + 0.5);
      const c = counts[i];
      const g = sv("g", { class: "col", tabindex: "0", role: "img",
        "aria-label": c ? `${d.day}: scope ${fmt(c.scope)}; ` +
          STATES.map((s) => `${s.label} ${fmt(c[s.id])}`).join(", ") : `${d.day}: not computed` });
      if (c) {
        // Bottom up: merged, PR open, pitched, draft, not in a pitch.
        let cum = 0;
        const segs = [];
        for (const s of [5, 4, 3, 2, 1]) {
          if (!c[s]) continue;
          const y0 = y(cum);
          cum += c[s];
          segs.push({ s, y0, y1: y(cum) });
        }
        segs.forEach((sg, k) => {
          const top = k === segs.length - 1;
          let y1 = top ? sg.y1 : sg.y1 + 2;
          if (sg.y0 - y1 < 1) y1 = sg.y0 - 1;
          const x0 = cx - cw / 2, x1 = cx + cw / 2;
          let dpath;
          if (top) {
            const r = Math.min(4, (sg.y0 - y1) / 2, cw / 2);
            dpath = `M${x0},${sg.y0}V${y1 + r}Q${x0},${y1} ${x0 + r},${y1}H${x1 - r}Q${x1},${y1} ${x1},${y1 + r}V${sg.y0}Z`;
          } else {
            dpath = `M${x0},${sg.y0}V${y1}H${x1}V${sg.y0}Z`;
          }
          g.appendChild(sv("path", { class: "seg", d: dpath, style: `fill:${stateColor(sg.s)}` }));
        });
        pts.push([cx, y(c.scope), c.scope]);
      } else {
        g.appendChild(sv("text", { class: "skip", x: cx, y: y(0) - 6, "text-anchor": "middle", text: "skipped" }));
      }
      g.appendChild(sv("rect", { class: "col-hit", x: cx - band / 2, y: mt, width: band, height: ph }));
      const show = (evt) => showTip(evt, (t) => dayTip(t, d, c));
      g.addEventListener("pointermove", show);
      g.addEventListener("focus", show);
      g.addEventListener("pointerleave", hideTip);
      g.addEventListener("blur", hideTip);
      cols.appendChild(g);
    });
    svg.appendChild(cols);
    if (pts.length) {
      svg.appendChild(sv("polyline", { class: "scope", points: pts.map((p) => `${p[0]},${p[1]}`).join(" ") }));
      for (const p of pts) svg.appendChild(sv("circle", { class: "scope-dot", cx: p[0], cy: p[1], r: 4 }));
      const last = pts[pts.length - 1];
      svg.appendChild(sv("text", { class: "label", x: last[0] + 12, y: last[1] - 2, text: fmt(last[2]) }));
      svg.appendChild(sv("text", { class: "label sub", x: last[0] + 12, y: last[1] + 13, text: "scope" }));
    }
    box.appendChild(svg);
    renderChartTable(counts);
    const first = counts.find(Boolean), lastc = [...counts].reverse().find(Boolean);
    $("chart-caption").textContent = first && lastc
      ? `The top of each column is the scope: what ${META.headRef} adds over ${META.baseRef} that day, ` +
        `plus what has merged since. ${fmt(first.scope)} on ${shortDay(days[counts.indexOf(first)].day)}, ` +
        `${fmt(lastc.scope)} now. A day without a commit repeats the day before.`
      : "No day could be computed for these filters.";
  }

  function dayTip(t, d, c) {
    t.appendChild(el("div", { class: "t-head" },
      `${shortDay(d.day)} · ${d.commit}` + (d.newCommit ? "" : " (no commit that day)")));
    if (!c) {
      t.appendChild(el("div", { class: "t-note", text: `Not computed: ${d.skipped || "unknown"}` }));
      return;
    }
    for (const s of [1, 2, 3, 4, 5]) {
      t.appendChild(el("div", { class: "t-row" },
        el("span", { class: "key", style: `border-color:${stateColor(s)}` }),
        el("b", { text: fmt(c[s]) }), el("span", { text: STATE_LABEL[s] })));
    }
    t.appendChild(el("div", { class: "t-row" }, el("span", { class: "key", style: "border-color:var(--text-secondary)" }),
      el("b", { text: fmt(c.scope) }), el("span", { text: "Scope" })));
    if (c.outside) t.appendChild(el("div", { class: "t-note", text: `${fmt(c.outside)} more outside the count` }));
    t.appendChild(el("div", { class: "t-note", text: methodText(d) }));
  }
  function methodText(d) {
    const m = { "api-delta": "From api-delta's report", snapshot: "From the source scan and the stored graph",
      scan: "From the source scan, which misses enum cases" }[d.method] || "";
    return d.note ? `${m}; ${d.note}.` : `${m}.`;
  }

  function renderChartTable(counts) {
    const box = clear($("chart-table"));
    const head = el("tr", null, el("th", { text: "Day" }), el("th", { text: "Commit" }), el("th", { text: "Method" }),
      ...STATES.map((s) => el("th", { class: "n", text: s.label })), el("th", { class: "n", text: "Scope" }),
      el("th", { class: "n", text: "Outside the count" }));
    const body = days.map((d, i) => {
      const c = counts[i];
      return el("tr", null, el("td", { text: d.day }), el("td", { class: "mono", text: d.commit }),
        el("td", { text: c ? d.method : `skipped: ${d.skipped}` }),
        ...STATES.map((s) => el("td", { class: "n", text: c ? fmt(c[s.id]) : "" })),
        el("td", { class: "n", text: c ? fmt(c.scope) : "" }), el("td", { class: "n", text: c ? fmt(c.outside) : "" }));
    });
    box.appendChild(el("table", { class: "data" }, el("thead", null, head), el("tbody", null, body)));
  }
  $("chart-table-toggle").addEventListener("click", (e) => {
    const t = $("chart-table");
    t.hidden = !t.hidden;
    e.target.setAttribute("aria-expanded", String(!t.hidden));
    e.target.textContent = t.hidden ? "Show the table" : "Hide the table";
  });

  function renderLegend() {
    const box = clear($("legend"));
    for (const s of STATES) box.appendChild(el("span", null, swatch(s.id), s.label));
    box.appendChild(el("span", null, el("span", { class: "key", style: "border-color:var(--text-secondary)" }), "Scope"));
  }

  // ---------------------------------------------------------------- groups

  function renderViews() {
    const box = clear($("views"));
    for (const v of VIEWS) {
      box.appendChild(el("button", { type: "button", role: "tab", "aria-selected": String(v.id === view),
        onclick: () => { view = v.id; expanded.clear(); render(); }, text: v.label }));
    }
  }

  function aggregate(list, level, v) {
    const m = new Map();
    for (const u of list) {
      const keys = [].concat(v.levels[level](u));
      for (const k of keys) {
        let g = m.get(k);
        if (!g) { g = { key: k, n: 0, by: { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0 }, items: [] }; m.set(k, g); }
        g.n++;
        g.by[u.state]++;
        g.items.push(u);
      }
    }
    const order = v.order || (() => 0);
    return [...m.values()].sort((a, b) => (SPECIAL.has(a.key) - SPECIAL.has(b.key)) || (order(a.key) - order(b.key)) ||
      (b.n - a.n) || String(a.key).localeCompare(String(b.key)));
  }

  function bar(by, n, max) {
    const b = el("div", { class: "bar", style: `width:${Math.max(4, (n / max) * 100)}%` });
    for (const s of [5, 4, 3, 2, 1]) {
      if (by[s]) b.appendChild(el("span", { style: `background:${stateColor(s)};flex:${by[s]} 0 0` }));
    }
    return b;
  }

  function renderGroups() {
    const v = viewById[view];
    const list = decls.filter((u) => passes(u, { noGroup: true }));
    const box = clear($("groups"));
    const top = aggregate(list, 0, v);
    const max = Math.max(1, ...top.map((g) => g.n));
    const rows = [];
    const pitchState = (pid) => {
      const es = META.states[pid];
      if (!es || !es.length) return null;
      const e = es[es.length - 1];
      return `${e.state === "pr" ? "PR open" : "pitched"} ${e.date}`;
    };
    const addRows = (groups, level, keys) => {
      for (const g of groups) {
        const k = keys.concat([g.key]);
        const id = k.join("\u0000");
        const hasKids = level + 1 < v.levels.length;
        const open = expanded.has(id);
        const sel = F.group && F.group.view === view && F.group.keys.join("\u0000") === id;
        const label = el("td", null,
          hasKids ? el("button", { class: "link twisty", type: "button", "aria-expanded": String(open),
            "aria-label": open ? "Collapse" : "Expand",
            onclick: (e) => { e.stopPropagation(); open ? expanded.delete(id) : expanded.add(id); renderGroups(); },
            text: open ? "▾" : "▸" }) : null,
          el("span", { class: SPECIAL.has(g.key) ? "muted" : (view === "header" && level > 0 ? "mono" : ""), text: g.key }),
          view === "pitch" && pitchState(g.key) ? el("span", { class: "flagtag", text: pitchState(g.key) }) : null);
        rows.push(el("tr", { class: `grp lvl${level}${sel ? " sel" : ""}`, tabindex: "0",
          onclick: () => selectGroup(view, k, g.key),
          onkeydown: (e) => { if (e.key === "Enter" || e.key === " ") { e.preventDefault(); selectGroup(view, k, g.key); } } },
        label, el("td", { class: "n", text: fmt(g.n) }), el("td", { style: "width:34%" }, bar(g.by, g.n, max)),
        ...[1, 2, 3, 4, 5].map((s) => el("td", { class: "n muted", text: g.by[s] ? fmt(g.by[s]) : "" }))));
        if (hasKids && open) addRows(aggregate(g.items, level + 1, v), level + 1, k);
      }
    };
    addRows(top, 0, []);
    const head = el("tr", null, el("th", { text: v.label }), el("th", { class: "n", text: "Declarations" }),
      el("th", { text: "By state" }), ...STATES.map((s) => el("th", { class: "n" }, swatch(s.id), " ", s.label)));
    box.appendChild(el("div", { class: "groups-scroll" },
      el("table", { class: "data" }, el("thead", null, head), el("tbody", null, rows))));
    $("groups-caption").textContent = `${v.caption} ${plural(top.length, "group")}; select one to filter the page.`;
  }

  function selectGroup(viewId, keys, label) {
    const id = keys.join("\u0000");
    if (F.group && F.group.view === viewId && F.group.keys.join("\u0000") === id) F.group = null;
    else F.group = { view: viewId, keys, label: `${viewById[viewId].label}: ${keys.join(" › ")}` };
    listLimit = 200;
    render();
  }

  function renderChip() {
    const box = clear($("f-group"));
    if (!F.group) return;
    box.appendChild(el("span", { class: "chip" }, F.group.label,
      el("button", { type: "button", "aria-label": "Clear the group", text: "×",
        onclick: () => { F.group = null; render(); } })));
  }

  // ---------------------------------------------------------------- list

  function renderList() {
    const box = clear($("list"));
    const list = decls.filter((u) => passes(u));
    const cmp = {
      state: (a, b) => a.state - b.state || a.path.localeCompare(b.path),
      path: (a, b) => a.path.localeCompare(b.path) || a.i - b.i,
      reach: (a, b) => b.reach - a.reach || b.could - a.could || a.path.localeCompare(b.path),
      header: (a, b) => String(a.header).localeCompare(String(b.header)) || a.path.localeCompare(b.path),
    }[listSort];
    list.sort(cmp);
    const rows = [];
    for (const u of list.slice(0, listLimit)) {
      const tags = u.flags.filter((f) => f !== "overload").map((f) =>
        el("span", { class: "flagtag", title: DATA.flagText[f], text: EXCLUDED.has(f) ? `${f}, outside the count` : f }));
      const open = openDetails.has(u.i);
      rows.push(el("tr", { class: "list-row", tabindex: "0", "aria-expanded": String(open),
        onclick: () => toggleDetail(u.i),
        onkeydown: (e) => { if (e.key === "Enter" || e.key === " ") { e.preventDefault(); toggleDetail(u.i); } } },
      el("td", { class: "nw" }, el("span", { class: "state-cell" }, swatch(u.state), STATE_LABEL[u.state])),
      el("td", { class: "decl-cell" }, el("span", { class: "path", text: u.path }), tags),
      el("td", { class: "nw", text: u.kind || "" }),
      el("td", { class: "mono", text: u.cname || "" }),
      el("td", { class: "mono", text: u.header && !SPECIAL.has(u.header) ? u.header : "" }),
      el("td", { text: u.pitch || "" }),
      el("td", { class: "n", text: u.reach ? fmt(u.reach) : "" })));
      if (open) rows.push(detailRow(u));
    }
    const head = el("tr", null, ...["State", "Declaration", "Kind", "C name", "Header", "Pitch"].map((h) => el("th", { text: h })),
      el("th", { class: "n", text: "Packages" }));
    box.appendChild(el("table", { class: "data" }, el("thead", null, head), el("tbody", null, rows)));
    if (list.length > listLimit) {
      box.appendChild(el("button", { type: "button", class: "more",
        onclick: () => { listLimit += 200; renderList(); },
        text: `Show ${fmt(Math.min(200, list.length - listLimit))} more of ${fmt(list.length - listLimit)}` }));
    }
    const ex = list.filter((u) => u.excluded).length;
    $("list-caption").textContent = `${plural(list.length, "declaration")}` +
      (ex ? `, ${fmt(ex)} of them outside the count` : "") + ". Select one for its details and adopters.";
  }

  function toggleDetail(i) {
    openDetails.has(i) ? openDetails.delete(i) : openDetails.add(i);
    renderList();
  }

  function detailRow(u) {
    const g = el("div", { class: "d-grid" });
    const add = (k, ...v) => { g.appendChild(el("div", { text: k })); g.appendChild(el("div", null, ...v)); };
    if (u.decl) add("Declaration", el("pre", { class: "mono", text: u.decl }));
    if (u.doc) add("Summary", u.doc);
    let st = STATE_LABEL[u.state];
    if (u.pitch) {
      const es = META.states[u.pitch] || [];
      const e = es[es.length - 1];
      st += ` (pitch ${u.pitch}${e ? `, ${e.state === "pr" ? "PR open" : "pitched"} ${e.date}` : ""})`;
      if (e && e.link) st += ` ${e.link}`;
    }
    add("State", st);
    if (u.more.length) add("Also in", u.more.join(", "));
    if (u.flags.length) {
      add("Flags", el("ul", { class: "sites" }, u.flags.map((f) => el("li", { text: `${f}: ${DATA.flagText[f]}` }))));
    }
    add("Kind", `${u.kind || ""} in ${u.module || ""}`);
    if (u.file) add("Source", el("span", { class: "mono", text: `${u.file}:${u.line}` }));
    add("Platforms", PLAT.filter((p, b) => u.plat & (1 << b)).join(", ") || "none");
    if (u.avail) add("Availability", u.avail);
    if (u.cnames.length) {
      add("C names", u.cnames.map((c, k) =>
        el("span", null, k ? ", " : "", el("code", { text: str(c[0]) }), ` (${ROLES[c[1]]}${c[2] ? ", restricted" : ""})`)));
    }
    add("Header", u.header && !SPECIAL.has(u.header)
      ? el("span", null, el("code", { text: u.header }), ` in ${u.sub} (${u.sdk}), by ${u.how}`)
      : (u.header || "unknown"));
    if (u.used.length) {
      const blocks = [];
      for (const [pk, sites] of u.used) {
        blocks.push(el("div", { text: `${str(pk)}: ${plural(sites.length, "site")}` }));
        blocks.push(el("ul", { class: "sites" }, sites.slice(0, 25).map((s) =>
          el("li", { text: `${str(s[0])}:${s[1]}:${s[2]}${s[3] ? "" : " (lexical)"}` })),
        sites.length > 25 ? el("li", { text: `and ${fmt(sites.length - 25)} more` }) : null));
      }
      add("Used by", ...blocks);
    } else {
      add("Used by", "no package's migration branch");
    }
    if (u.could) add("Could use", `${plural(u.could, "package")} call a C interface it wraps`);
    return el("tr", { class: "detail" }, el("td", { colspan: "7" }, g));
  }
  $("list-sort").addEventListener("change", (e) => { listSort = e.target.value; renderList(); });

  // ---------------------------------------------------------------- footer and theme

  function renderFoot() {
    const box = clear($("foot"));
    const t = DATA.totals;
    box.appendChild(el("h2", { text: "How this was generated" }));
    box.appendChild(el("p", { text: `Utilities/api-burndown/regenerate.sh, from swift-system ${META.tool.commit.slice(0, 10)}` +
      `${META.tool.dirty ? " with uncommitted changes to the tool" : ""}. Its README describes each design call and its limits.` }));
    const items = [
      `Declarations: api-delta's report of ${META.baseRef} ${META.baseCommit.slice(0, 10)} → ${META.headRef} ` +
        `${META.headCommit.slice(0, 10)} (${META.apiDelta.date}, ${META.apiDelta.swift}): ${fmt(META.apiDelta.added)} ` +
        `added in the macOS symbol graphs, and ${fmt(META.apiDelta.hidden)} only the source scan sees. ` +
        `${fmt(t.mainCount)} are in the main count and ${fmt(t.outsideCount)} outside it.`,
      `Pitches: ${META.pitchFiles.length ? META.pitchFiles.join(", ") : "none"}, resolved with api-graph's rules. ` +
        `Pitched and PR open come from Prototype/Burndown/states.json` +
        `${Object.keys(META.states).length ? "" : ", which is empty"}.`,
      `C names and adopters: the API graph at ${(META.graph.headCommit || "?").slice(0, 10)} (${META.graph.date}). ` +
        `Headers: the macOS ${META.sdkVersion} SDK's module maps and headers, with the coverage tools' vocabulary ${META.vocab}.`,
      `History: one day per column, the head ref's last first-parent commit that day; ` +
        `api-delta's source scan of each, and the stored graph where the snapshot store has the commit` +
        `${META.storeCommits.length ? ` (${META.storeCommits.join(", ")})` : ""}.`,
      `Data digest ${DATA.digest.slice(0, 16)}; nothing on this page loads from the network.`,
    ];
    box.appendChild(el("ul", null, items.map((x) => el("li", { text: x }))));
  }

  const THEMES = ["auto", "light", "dark"];
  let theme = "auto";
  function applyTheme() {
    if (theme === "auto") delete document.documentElement.dataset.theme;
    else document.documentElement.dataset.theme = theme;
    $("theme").textContent = `Theme: ${theme}`;
  }
  $("theme").addEventListener("click", () => { theme = THEMES[(THEMES.indexOf(theme) + 1) % 3]; applyTheme(); });

  // ---------------------------------------------------------------- render

  function render() {
    renderChip();
    renderTiles();
    renderChart();
    renderViews();
    renderGroups();
    renderList();
  }
  applyTheme();
  renderHead();
  renderLegend();
  renderFoot();
  render();
  let rt = null;
  window.addEventListener("resize", () => { clearTimeout(rt); rt = setTimeout(renderChart, 120); });
})();
