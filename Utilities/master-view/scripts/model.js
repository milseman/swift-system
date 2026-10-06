// The master view's data model: the page's data (the JSON in #data) turned
// into declarations and packages that refer to each other, and the filters
// both views share. No DOM here: `regenerate.sh --check` runs this file in
// node on the page's own data and checks its counts against the inputs.
"use strict";
var Model = (function () {
  var PLATFORMS = ["Darwin", "Linux", "Musl", "Android", "FreeBSD", "OpenBSD", "WASI", "Windows"];
  var FLAGS = ["outside", "stub", "deprecated", "underscored", "spi", "overload", "upstream", "pitches",
               "unexplained", "nograph", "hidden"];
  var HOW = ["precise", "lexical", "qualifier"];

  function flag(d, name) { return (d.flags & (1 << FLAGS.indexOf(name))) !== 0; }

  function platforms(mask) {
    var out = [];
    for (var i = 0; i < PLATFORMS.length; i++) if (mask & (1 << i)) out.push(PLATFORMS[i]);
    return out;
  }

  function build(PD) {
    var S = PD.S;
    var s = function (k) { return k >= 0 ? S[k] : null; };
    var M = {PD: PD, S: S, meta: PD.meta, charts: PD.charts, notes: PD.notes, labels: PD.meta.labels};
    M.areas = PD.A.map(function (a, i) { return {i: i, name: S[a[0]], module: S[a[1]]}; });
    M.decls = PD.D.map(function (d, i) {
      return {i: i, path: S[d[0]], kind: S[d[1]], area: d[2], type: S[d[3]], state: d[4], pitch: s(d[5]),
              flags: d[6], plat: d[7], file: s(d[8]), line: d[9], avail: s(d[10]), decl: s(d[11]),
              doc: s(d[12]), cname: s(d[13]), sameAs: d[14], module: S[d[15]], uses: [], users: 0, sites: 0};
    });
    M.pkgs = PD.P.map(function (p, i) {
      var o = {i: i, uses: [], newSites: 0};
      for (var k in p) o[k] = p[k];
      return o;
    });
    M.uses = PD.U.map(function (u) {
      var x = {d: u[0], p: u[1], sites: u[2]};
      M.decls[x.d].uses.push(x);
      M.pkgs[x.p].uses.push(x);
      M.decls[x.d].sites += x.sites.length;
      M.pkgs[x.p].newSites += x.sites.length;
      return x;
    });
    // A link to a declaration names it by module and name, and which of
    // the declarations with that name it is (overloads), so that it still
    // finds it after a regeneration.
    var seen = {};
    M.byRef = {};
    M.decls.forEach(function (d) {
      var base = d.module + ":" + d.path;
      seen[base] = (seen[base] || 0) + 1;
      d.ref = seen[base] > 1 ? base + "~" + seen[base] : base;
      M.byRef[d.ref] = d.i;
    });
    M.decls.forEach(function (d) {
      d.users = d.uses.length;
      d.key = (d.path + " " + d.type + " " + (d.cname || "") + " " + M.areas[d.area].name + " " + d.kind).toLowerCase();
    });
    M.pkgs.forEach(function (p) {
      p.key = (p.n + " " + (p.r || "")).toLowerCase();
      p.mainSites = 0;
      if (p.use && p.use.main) p.use.main.forEach(function (m) { p.mainSites += m[2].length; });
    });
    return M;
  }

  // The filters: package scope (cluster, kind of data, one package), and
  // declaration scope (pitch state, use, one declaration), and the search,
  // which each view applies to its own rows.
  function defaults() {
    return {q: "", cluster: "all", kind: "all", state: "all", use: "all", onlyPkg: null, onlyDecl: null};
  }

  function pkgInScope(M, f, p) {
    return (f.cluster === "all" || p.c === +f.cluster) && (f.kind === "all" || p.k === +f.kind) &&
           (f.onlyPkg === null || p.i === f.onlyPkg);
  }

  // A declaration's uses by packages in scope.
  function scopedUses(M, f, d, pkOk) {
    var out = [];
    for (var k = 0; k < d.uses.length; k++) if (pkOk[d.uses[k].p]) out.push(d.uses[k]);
    return out;
  }

  function declInScope(M, f, d, uses) {
    if (f.state !== "all" && d.state !== +f.state) return false;
    if (f.onlyDecl !== null && d.i !== f.onlyDecl) return false;
    if (f.onlyPkg !== null && uses.length === 0) return false;   // "used by" one package
    if (f.use === "used" && uses.length === 0) return false;
    if (f.use === "unused" && uses.length !== 0) return false;
    return true;
  }

  // Everything both views show, for a set of filters: the declarations
  // listed (By API), the packages listed (By package), and each one's uses
  // in scope. The two views' uses are the same set, seen from each end.
  function view(M, f) {
    var q = (f.q || "").trim().toLowerCase();
    var pkOk = new Uint8Array(M.pkgs.length);
    M.pkgs.forEach(function (p) { pkOk[p.i] = pkgInScope(M, f, p) ? 1 : 0; });
    var declUses = new Array(M.decls.length);
    var dOk = new Uint8Array(M.decls.length);
    M.decls.forEach(function (d) {
      var u = scopedUses(M, f, d, pkOk);
      declUses[d.i] = u;
      dOk[d.i] = declInScope(M, f, d, u) ? 1 : 0;
    });
    var decls = [], pkgs = [];
    M.decls.forEach(function (d) { if (dOk[d.i] && (!q || d.key.indexOf(q) >= 0)) decls.push(d.i); });
    var pkgUses = new Array(M.pkgs.length);
    M.pkgs.forEach(function (p) {
      var u = [];
      for (var k = 0; k < p.uses.length; k++) if (dOk[p.uses[k].d]) u.push(p.uses[k]);
      pkgUses[p.i] = u;
      if (!pkOk[p.i]) return;
      if (f.use === "used" && u.length === 0) return;
      if (f.use === "unused" && u.length !== 0) return;
      if (f.onlyDecl !== null && u.length === 0) return;
      if (q && p.key.indexOf(q) < 0) return;
      pkgs.push(p.i);
    });
    return {decls: decls, pkgs: pkgs, declUses: declUses, pkgUses: pkgUses, pkOk: pkOk, dOk: dOk, q: q};
  }

  // The sums each view shows, for the check and the page's headings: By
  // API's declarations, their users and sites; By package's packages, their
  // declarations and sites (over the same filters, before the search).
  function sums(M, f) {
    var v = view(M, Object.assign({}, f, {q: ""}));
    var api = {declarations: v.decls.length, used: 0, pairs: 0, sites: 0, byPkg: {}};
    v.decls.forEach(function (i) {
      var u = v.declUses[i];
      if (u.length) api.used++;
      u.forEach(function (x) {
        api.pairs++;
        api.sites += x.sites.length;
        var k = M.pkgs[x.p].n;
        api.byPkg[k] = api.byPkg[k] || {declarations: 0, sites: 0};
        api.byPkg[k].declarations++;
        api.byPkg[k].sites += x.sites.length;
      });
    });
    var pk = {packages: v.pkgs.length, pairs: 0, sites: 0, byPkg: {}};
    M.pkgs.forEach(function (p) {
      if (!v.pkOk[p.i]) return;
      var u = v.pkgUses[p.i], n = 0;
      u.forEach(function (x) { n += x.sites.length; });
      if (u.length) pk.byPkg[p.n] = {declarations: u.length, sites: n};
      pk.pairs += u.length;
      pk.sites += n;
    });
    return {api: api, packages: pk};
  }

  // A tree of the declarations listed: area > type > declaration.
  function tree(M, decls) {
    var areas = {};
    decls.forEach(function (i) {
      var d = M.decls[i];
      var a = areas[d.area] || (areas[d.area] = {area: M.areas[d.area], types: {}, n: 0});
      var t = a.types[d.type] || (a.types[d.type] = {name: d.type, decls: []});
      t.decls.push(i);
      a.n++;
    });
    return Object.keys(areas).map(function (k) { return areas[k]; }).sort(function (x, y) {
      return x.area.name < y.area.name ? -1 : x.area.name > y.area.name ? 1 :
             (x.area.module < y.area.module ? -1 : 1);
    }).map(function (a) {
      a.types = Object.keys(a.types).map(function (k) { return a.types[k]; })
        .sort(function (x, y) { return x.name < y.name ? -1 : x.name > y.name ? 1 : 0; });
      a.types.forEach(function (t) {
        t.decls.sort(function (x, y) {
          var p = M.decls[x].path, q = M.decls[y].path;
          return p < q ? -1 : p > q ? 1 : x - y;
        });
      });
      return a;
    });
  }

  // The headline figures (no filters).
  function headline(M) {
    var byState = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0}, main = 0, used = 0;
    M.decls.forEach(function (d) {
      if (!flag(d, "outside")) { byState[d.state]++; main++; }
      if (d.uses.length) used++;
    });
    var kinds = {};
    M.pkgs.forEach(function (p) { kinds[p.k] = (kinds[p.k] || 0) + 1; });
    var users = 0;
    M.pkgs.forEach(function (p) { if (p.uses.length) users++; });
    var cuses = 0, uc = 0;
    M.pkgs.forEach(function (p) {
      if (p.cu && p.cu.src === "ledger" && p.cu.sites) cuses += p.cu.sites.length;
      if (p.c === 0) uc++;
    });
    return {declarations: M.decls.length, mainCount: main, byState: byState, used: used, packages: M.pkgs.length,
            kinds: kinds, users: users, cuses: cuses, updateCheckout: uc};
  }

  return {build: build, defaults: defaults, view: view, sums: sums, tree: tree, headline: headline,
          flag: flag, platforms: platforms, PLATFORMS: PLATFORMS, FLAGS: FLAGS, HOW: HOW};
})();
if (typeof module !== "undefined") module.exports = Model;
