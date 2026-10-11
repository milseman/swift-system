#!/usr/bin/env python3
"""The scratch copy's manifests: what a package depends on, and the edits
that make it build offline from the copy.

Every dependency becomes a path dependency on an export under the scratch
directory (`../../deps/<identity>` from the package): System is an export of
the System commit the probe checks, and a remote dependency is an export of
SwiftPM's cached clone at the version the package's Package.resolved pins,
or else the highest cached tag its requirement allows. So nothing is
fetched, and the same copy builds on macOS and in a Linux container, which
sees only the scratch directory. SwiftPM takes a path dependency's identity
from its directory's name, so each export's directory is named for the
identity the manifest's `.product(name:package:)` references use.

System's own manifest loses its Samples executable and swift-argument-parser,
as api-delta's patch_manifest.py does for its exports (that script has no
function to import: it patches on import).

A dependency's `traits:` argument (SwiftPM 6.1) isn't part of its version
requirement, and it stays on the path dependency that replaces the call,
since `traits: []` turns a package's default traits off.

Which path dependencies a manifest takes is SwiftPM's answer, `swift
package dump-package` (`active_dependencies`): a manifest's text also has
the ones in branches it doesn't take, such as swift-nio's
`SWIFTCI_USE_LOCAL_DEPS`.

Only text is edited, and only in the scratch copy.
"""

import sys

sys.dont_write_bytecode = True

import json  # noqa: E402
import os  # noqa: E402
import re  # noqa: E402
import subprocess  # noqa: E402

MANIFEST = re.compile(r"^Package(@swift-[\d.]+)?\.swift$")
CACHE = os.path.expanduser("~/Library/Caches/org.swift.swiftpm/repositories")


def manifests(package_dir):
    """The package's manifests: Package.swift and its version-specific
    variants."""
    return sorted(f for f in os.listdir(package_dir) if MANIFEST.match(f))


def calls(text, token=".package("):
    """(start, end) of each `token...)` call, parentheses balanced, skipping
    string literals and comments."""
    out, i = [], 0
    while True:
        i = text.find(token, i)
        if i < 0:
            return out
        line_start = text.rfind("\n", 0, i) + 1
        if "//" in text[line_start:i]:
            i += len(token)
            continue
        j, depth, quote = i + len(token) - 1, 0, False
        while j < len(text):
            c = text[j]
            if quote:
                if c == "\\":
                    j += 1
                elif c == '"':
                    quote = False
            elif c == '"':
                quote = True
            elif c == "(":
                depth += 1
            elif c == ")":
                depth -= 1
                if depth == 0:
                    break
            j += 1
        out.append((i, j + 1))
        i = j + 1


def identity_of(location):
    """SwiftPM's identity for a URL or a path: its last component, without
    `.git`, lowercased."""
    last = location.rstrip("/").split("/")[-1]
    if last.endswith(".git"):
        last = last[:-4]
    return last.lower()


def arguments(call):
    """[(label or None, value text)] of a call's top-level arguments, from
    the text of the whole call (`.package(url: "x", from: "1.0.0")`):
    commas inside brackets, parentheses, braces, string literals and
    comments don't split, and comments are left out."""
    i = call.find("(")
    if i < 0:
        return []
    out, depth, piece, j = [], 0, [], i
    while j < len(call):
        c = call[j]
        if call.startswith('"""', j) or c == '"':
            if call.startswith('"""', j):
                k = call.find('"""', j + 3)
                k = len(call) if k < 0 else k + 3
            else:
                k = j + 1
                while k < len(call) and call[k] != '"':
                    k += 2 if call[k] == "\\" else 1
                k += 1
            piece.append(call[j:k])
            j = k
            continue
        if call.startswith("//", j):
            k = call.find("\n", j)
            j = len(call) if k < 0 else k
            continue
        if call.startswith("/*", j):
            k = call.find("*/", j + 2)
            j = len(call) if k < 0 else k + 2
            continue
        if c in "([{":
            depth += 1
            if depth == 1:
                j += 1
                continue
        elif c in ")]}":
            depth -= 1
            if depth == 0:
                out.append("".join(piece))
                break
        elif c == "," and depth == 1:
            out.append("".join(piece))
            piece = []
            j += 1
            continue
        if depth >= 1:
            piece.append(c)
        j += 1
    args = []
    for a in out:
        a = a.strip()
        if not a:
            continue
        m = re.match(r"^([A-Za-z_]\w*)\s*:(?!:)\s*(.*)$", a, re.S)
        args.append((m.group(1), m.group(2).strip()) if m else (None, a))
    return args


def dependencies(text):
    """[{kind: url|path, location, requirement, traits, identity, span}] for
    each `.package(...)` call in a manifest. The requirement is the call's
    text after its URL, less `traits:`; `traits` is that argument's text,
    or None."""
    out = []
    for start, end in calls(text):
        call = text[start:end]
        args = arguments(call)
        kind = next((label for label, _ in args if label in ("url", "path")), None)
        if kind is None:
            continue
        value = dict((label, v) for label, v in args if label)[kind]
        m = re.match(r'^"([^"]+)"$', value)
        if not m:
            continue
        rest = [f"{label}: {v}" if label else v for label, v in args if label not in ("name", "url", "path", "traits")]
        traits = next((v for label, v in args if label == "traits"), None)
        out.append({"kind": kind, "location": m.group(1), "requirement": ", ".join(rest), "traits": traits,
                    "identity": identity_of(m.group(1)), "span": (start, end)})
    return out


def rewrite(text, paths):
    """The manifest with each dependency whose identity is in `paths`
    ({identity: relative path}) made `.package(path: ...)` there, with its
    `traits:` if it had one, and the rewrites as [(old location, new
    path)]."""
    done = []
    pieces, last = [], 0
    for d in dependencies(text):
        new = paths.get(d["identity"])
        if new is None:
            continue
        start, end = d["span"]
        pieces.append(text[last:start])
        traits = f", traits: {d['traits']}" if d.get("traits") is not None else ""
        pieces.append(f".package(path: {json.dumps(new)}{traits})")
        last = end
        done.append((d["location"], new))
    pieces.append(text[last:])
    return "".join(pieces), done


def active_dependencies(package_dir, scratch, flags=()):
    """The dependencies a package's manifest takes, as SwiftPM evaluates it
    on this host (`swift package dump-package`, which resolves nothing):
    [{kind: path|url|registry, identity, location}], a path absolute, as
    SwiftPM resolved it from the package's directory."""
    p = subprocess.run(["swift", "package", "--disable-sandbox", *flags, "--package-path", package_dir,
                        "--scratch-path", scratch, "dump-package"], capture_output=True, text=True)
    if p.returncode != 0:
        raise RuntimeError(f"swift package dump-package failed in {package_dir}:\n{p.stderr[-2000:]}")
    out = []
    for d in json.loads(p.stdout).get("dependencies", []):
        for kind, key in (("fileSystem", "path"), ("sourceControl", "url"), ("registry", "registry")):
            for e in d.get(kind) or []:
                location = e.get("path")
                if kind == "sourceControl":
                    loc = e.get("location") or {}
                    location = ((loc.get("remote") or [{}])[0].get("urlString") if "remote" in loc
                                else (loc.get("local") or [None])[0])
                out.append({"kind": key, "identity": e.get("identity"), "location": location})
    return out


# ---------------------------------------------------------------- versions

VERSION = re.compile(r"^v?(\d+)\.(\d+)(?:\.(\d+))?$")


def parse_version(tag):
    m = VERSION.match(tag.strip())
    if not m:
        return None
    return tuple(int(x or 0) for x in m.groups())


def allowed(requirement):
    """A predicate on version tuples for a requirement's text, or a string
    naming a branch or revision, or None when it can't be read. A `traits:`
    argument in the text is passed over."""
    args = arguments(f"({requirement})")
    if any(label == "traits" for label, _ in args):
        requirement = ", ".join(f"{label}: {v}" if label else v for label, v in args if label != "traits")
    r = requirement.replace(" ", "")
    m = re.match(r'^(?:from:|\.upToNextMajor\(from:)"([^"]+)"\)?$', r)
    if m:
        low = parse_version(m.group(1))
        return low and (lambda v: v >= low and v[0] == low[0])
    m = re.match(r'^\.upToNextMinor\(from:"([^"]+)"\)$', r)
    if m:
        low = parse_version(m.group(1))
        return low and (lambda v: v >= low and v[:2] == low[:2])
    m = re.match(r'^(?:exact:|\.exact\()"([^"]+)"\)?$', r)
    if m:
        want = parse_version(m.group(1))
        return want and (lambda v: v == want)
    m = re.match(r'^"([^"]+)"\.\.(<|\.)"([^"]+)"$', r)
    if m:
        low, high = parse_version(m.group(1)), parse_version(m.group(3))
        if low and high:
            return (lambda v: low <= v < high) if m.group(2) == "<" else (lambda v: low <= v <= high)
    m = re.match(r'^(?:branch:|\.branch\(|revision:|\.revision\()"([^"]+)"\)?$', r)
    if m:
        return m.group(1)
    return None


def normalized_url(url):
    u = url.strip().lower().rstrip("/")
    if u.endswith(".git"):
        u = u[:-4]
    return re.sub(r"^(https?://|git@|ssh://git@)", "", u).replace(":", "/")


def git(repo, *args, ok=(0,)):
    env = dict(os.environ, GIT_NO_LAZY_FETCH="1", GIT_TERMINAL_PROMPT="0")
    p = subprocess.run(["git", "--no-optional-locks", "-C", repo, *args], capture_output=True, text=True, env=env)
    if p.returncode not in ok:
        raise RuntimeError(f"git -C {repo} {' '.join(args)}: {p.stderr.strip()}")
    return p.stdout


def cached_clones(url, cache=CACHE):
    """SwiftPM's cached clones of a URL: directories of its repository
    cache whose origin is the URL."""
    want = normalized_url(url)
    out = []
    if not os.path.isdir(cache):
        return out
    for d in sorted(os.listdir(cache)):
        path = os.path.join(cache, d)
        if not os.path.isdir(path):
            continue
        try:
            origin = git(path, "config", "--get", "remote.origin.url", ok=(0, 1)).strip()
        except RuntimeError:
            continue
        if origin and normalized_url(origin) == want:
            out.append(path)
    return out


def resolved_pins(package_dir):
    """{identity: revision} from a committed Package.resolved (versions 1 to
    3)."""
    path = os.path.join(package_dir, "Package.resolved")
    if not os.path.isfile(path):
        return {}
    try:
        doc = json.load(open(path, encoding="utf-8"))
    except ValueError:
        return {}
    pins = doc.get("pins") or (doc.get("object") or {}).get("pins") or []
    out = {}
    for p in pins:
        ident = p.get("identity") or identity_of(p.get("location") or p.get("repositoryURL") or "")
        rev = (p.get("state") or {}).get("revision")
        if ident and rev:
            out[ident] = rev
    return out


def choose(url, requirement, pin=None, cache=CACHE):
    """(clone, revision, version text) for a remote dependency from
    SwiftPM's cache, or raise with what's missing."""
    clones = cached_clones(url, cache)
    if not clones:
        raise LookupError(f"{url} isn't in SwiftPM's repository cache ({cache}); this tool doesn't fetch")
    if pin:
        for c in clones:
            if git(c, "rev-parse", "--verify", "--quiet", pin + "^{commit}", ok=(0, 1)).strip():
                return c, pin, f"pinned {pin[:12]}"
        raise LookupError(f"{url}: the pinned revision {pin[:12]} isn't in SwiftPM's cache")
    pred = allowed(requirement)
    if pred is None:
        raise LookupError(f"{url}: can't read the requirement {requirement!r}")
    best = None
    for c in clones:
        if isinstance(pred, str):
            rev = git(c, "rev-parse", "--verify", "--quiet", pred + "^{commit}", ok=(0, 1)).strip()
            if rev:
                return c, rev, pred
            continue
        for tag in git(c, "tag", "--list").split():
            v = parse_version(tag)
            if v and pred(v) and (best is None or v > best[0]):
                best = (v, c, tag)
    if best is None:
        raise LookupError(f"{url}: no cached version satisfies {requirement!r}")
    v, c, tag = best
    rev = git(c, "rev-parse", "--verify", tag + "^{commit}").strip()
    return c, rev, tag


# ---------------------------------------------------------------- System's manifest

def remove_call(text, token):
    """Text without the first `token(...)` call, its trailing comma, and its
    line when the call is all that's on it."""
    found = [(s, e) for s, e in calls(text, token)]
    if not found:
        return text, False
    i, j = found[0]
    if j < len(text) and text[j] == ",":
        j += 1
    line_start = text.rfind("\n", 0, i) + 1
    if text[line_start:i].strip() == "":
        i = line_start
    if j < len(text) and text[j] == "\n":
        j += 1
    return text[:i] + text[j:], True


def drop_samples(text):
    """System's manifest without Samples and swift-argument-parser, so it
    resolves offline. Raises if they're still referenced."""
    text, _ = remove_call(text, ".executableTarget(")
    text = re.sub(r'\n\s*\.executable\(name:\s*"system-samples",\s*targets:\s*\["Samples"\]\),?', "", text)
    out = []
    for d in dependencies(text):
        if d["identity"] == "swift-argument-parser":
            out.append(d["span"])
    for start, end in reversed(out):
        j = end
        if j < len(text) and text[j] == ",":
            j += 1
        i = text.rfind("\n", 0, start) + 1
        if text[i:start].strip():
            i = start
        if j < len(text) and text[j] == "\n" and i != start:
            j += 1
        text = text[:i] + text[j:]
    if "swift-argument-parser" in text or '"Samples"' in text:
        raise ValueError("Samples or swift-argument-parser is still referenced in System's manifest")
    return text
