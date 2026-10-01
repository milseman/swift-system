#!/usr/bin/env python3
"""The System API that the adopters' widened branches use, where their C arm
still serves FreeBSD or OpenBSD, and that this checkout's System doesn't
build there.

A widened branch is one whose condition takes Darwin and Linux
(`canImport(Darwin) || os(Linux) || ...`), as unix-adopt's lanes write them;
its C arm is the branch after it. This reads the adopters-unix worktrees and
their scripts (arms.py, inventory.py) without writing there (no bytecode),
and scans this checkout's sources with api-delta's scanner into
.build/bsd-arms-scan.json. Names are matched lexically, as arms.py matches
them, so a local variable named like a System member shows up too.

usage: Prototype/OtherPlatforms/bsd-arms.py [package...]   (default: all)
"""
import importlib.util, json, os, re, subprocess, sys
from collections import defaultdict

sys.dont_write_bytecode = True
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '../..'))
SCRIPTS = os.path.abspath(os.path.join(ROOT, '../adopters-unix/scripts'))
scan_path = os.path.join(ROOT, '.build/bsd-arms-scan.json')
subprocess.run([sys.executable, os.path.join(ROOT, 'Utilities/api-delta/scripts/scan_sources.py'),
                ROOT, scan_path], check=True, stdout=subprocess.DEVNULL)
spec = importlib.util.spec_from_file_location('arms', os.path.join(SCRIPTS, 'arms.py'))
arms = importlib.util.module_from_spec(spec)
spec.loader.exec_module(arms)
inv = arms.inv

names = defaultdict(lambda: defaultdict(set))  # name -> module -> platforms
for e in json.load(open(scan_path))['declarations']:
    if e['access'] in ('public', 'open'):
        names[e['name'].split('(')[0]][e['module']] |= set(e['platforms'])

BSDS = ('FreeBSD', 'OpenBSD')
sites = defaultdict(lambda: defaultdict(list))  # name -> platform -> sites
for pkg in sys.argv[1:] or list(inv.PACKAGES):
    _, _, roots, on = inv.PACKAGES[pkg]
    flags = {'DEBUG': inv.M}
    flags.update({f: inv.T for f in on})
    base = os.path.join(inv.ROOT, pkg)
    for r in roots:
        for d, _, fs in os.walk(os.path.join(base, r)):
            for f in sorted(fs):
                if not f.endswith('.swift'):
                    continue
                p = os.path.join(d, f)
                code = inv.strip_code(open(p, encoding='utf-8', errors='replace').read()).split('\n')
                active = {pl: inv.active_lines(code, pl, flags)[0] for pl in BSDS}
                for branches, _ in arms.blocks(code):
                    for i, (kw, cond, a, b) in enumerate(branches):
                        if kw == 'else' or not arms.WIDENED.search(cond) or i + 1 >= len(branches):
                            continue
                        arm = branches[i + 1]
                        lines = range(arm[2], (arm[3] or arm[2]) + 1)
                        probe = [n for n in lines if code[n - 1].strip()] or [arm[2]]
                        reached = [pl for pl in BSDS if any(
                            active[pl][n - 1] != inv.F for n in probe if not code[n - 1].strip().startswith('#'))]
                        used = set(re.findall(r'(?<![\w$])([A-Za-z_]\w*)', '\n'.join(code[a - 1:b])))
                        for n in sorted(used - arms.SKIP):
                            if n not in names:
                                continue
                            built = list(names[n].values())
                            for pl in reached:
                                if any('Linux' in ps for ps in built) and \
                                        not any(pl in ps and 'Linux' in ps for ps in built):
                                    sites[n][pl].append(f'{pkg}/{os.path.relpath(p, base)}:{a - 1}')

for n in sorted(sites, key=lambda n: -sum(len(v) for v in sites[n].values())):
    built = ','.join(sorted(set().union(*names[n].values())))
    first = (sites[n]['FreeBSD'] or sites[n]['OpenBSD'])[0]
    print(f"{n}: FreeBSD {len(sites[n]['FreeBSD'])}, OpenBSD {len(sites[n]['OpenBSD'])} sites; "
          f"built on {built}; e.g. {first}")
