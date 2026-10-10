#!/usr/bin/env python3
"""Tests of import-probe over fixture packages: small git repositories made
in a temporary directory, deleted afterward.

- Path dependencies: followed transitively from the checkouts' commits, an
  inactive branch's not taken, --path-dep's ref, the local packages'
  manifests rewritten (`swift package dump-package` runs; nothing is built).
- `traits:`: a remote dependency's survives its rewrite, from a stand-in
  for SwiftPM's repository cache in the temporary directory.
- Nested packages: found in the branch, and one probed in place (a build).
- --own-modules and --reexport, each over a package built on macOS.

What the tests can touch: their own temporary directory, where they make
the repositories (git with no global or system configuration, so no hooks,
signing or credential helpers), the probe's scratch and SwiftPM's caches
(`--cache-path`, `--config-path`, `--security-path`, `--manifest-cache
local`), with TMPDIR pointed there for the builds. They read this worktree
(`git archive` of HEAD, as the probe exports System; modules.ini) and run
`swift`, never a product they build. No fixture has a remote dependency,
so nothing reaches the network; nothing is signalled and no permission is
changed. The builds need macOS and its toolchain, and take about a minute;
IMPORT_PROBE_SKIP_BUILDS=1 skips them.

  PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Utilities/import-probe/scripts -p 'test_*.py'
"""

import sys

sys.dont_write_bytecode = True

import argparse  # noqa: E402
import functools  # noqa: E402
import json  # noqa: E402
import os  # noqa: E402
import shutil  # noqa: E402
import subprocess  # noqa: E402
import tempfile  # noqa: E402
import unittest  # noqa: E402

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import probe  # noqa: E402
import manifests  # noqa: E402
import reexport  # noqa: E402

REPO = probe.git(probe.HERE, "rev-parse", "--show-toplevel").strip()
HEAD = probe.commit_of(REPO, "HEAD")
HAVE_SWIFT = shutil.which("swift") is not None
BUILDS = HAVE_SWIFT and sys.platform == "darwin" and not os.environ.get("IMPORT_PROBE_SKIP_BUILDS")
GIT_ENV = dict(os.environ, GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_SYSTEM=os.devnull, GIT_AUTHOR_NAME="t",
               GIT_AUTHOR_EMAIL="t@example.invalid", GIT_COMMITTER_NAME="t", GIT_COMMITTER_EMAIL="t@example.invalid",
               GIT_TERMINAL_PROMPT="0")
TOOLS = "// swift-tools-version:6.1\nimport PackageDescription\n"
C_IMPORT = "#if canImport(Darwin)\nimport Darwin\n#elseif canImport(Glibc)\nimport Glibc\n#endif\n"


def g(repo, *args):
    return subprocess.run(["git", "-C", repo, *args], env=GIT_ENV, check=True, capture_output=True,
                          text=True).stdout.strip()


def commit(repo, files, message="fixture"):
    """Writes files ({relative path: text}) into a repository, made if it
    isn't one, and commits them; returns the commit."""
    os.makedirs(repo, exist_ok=True)
    if not os.path.isdir(os.path.join(repo, ".git")):
        g(repo, "init", "-q")
    for rel, text in files.items():
        path = os.path.join(repo, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w") as f:
            f.write(text)
    g(repo, "add", "-A")
    g(repo, "commit", "-q", "--no-verify", "--no-gpg-sign", "-m", message)
    return g(repo, "rev-parse", "HEAD")


class Stub:
    """A classifier that knows nothing: every name a gap."""
    system_commit = HEAD

    def classify(self, name, platform, kind="value"):
        return "gap", name, "stub"


class FixtureCase(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp(prefix="import-probe-test-")
        self.clones = os.path.join(self.tmp, "clones")
        self.work = os.path.join(self.tmp, "work")
        os.makedirs(self.work)
        sp = os.path.join(self.tmp, "swiftpm")
        self.swiftpm = ["--cache-path", os.path.join(sp, "cache"), "--config-path", os.path.join(sp, "config"),
                        "--security-path", os.path.join(sp, "security"), "--manifest-cache", "local"]
        self.saved = {k: os.environ.get(k) for k in ("TMPDIR", "IMPORT_PROBE_TEST_DECOY")}
        os.makedirs(os.path.join(self.tmp, "tmpdir"))
        os.environ["TMPDIR"] = os.path.join(self.tmp, "tmpdir")
        self.saved_classifier = probe.CLASSIFIER.get("c")
        probe.CLASSIFIER["c"] = Stub()

    def tearDown(self):
        for k, v in self.saved.items():
            if v is None:
                os.environ.pop(k, None)
            else:
                os.environ[k] = v
        if self.saved_classifier is None:
            probe.CLASSIFIER.pop("c", None)
        else:
            probe.CLASSIFIER["c"] = self.saved_classifier
        shutil.rmtree(self.tmp)

    def args(self, **kw):
        a = dict(system="HEAD", path_dep=[], targets=None, no_skip=False, own_modules=False, reexport=False,
                 keep=False, work=self.work, min_free_gb=0, swift=None, linux=False, swiftpm=self.swiftpm)
        a.update(kw)
        return argparse.Namespace(**a)

    def clone(self, name, files):
        return commit(os.path.join(self.clones, name), files)

    def graph(self):
        """app (a nested package Examples/Tool, which takes it by `../..`)
        -> ../lib -> ../core; ../decoy only when IMPORT_PROBE_TEST_DECOY is
        set. lib has two commits."""
        self.clone("core", {"Package.swift": TOOLS + 'let package = Package(name: "core", products: [.library(name: '
                            '"Core", targets: ["Core"])], targets: [.target(name: "Core")])\n',
                            "Sources/Core/Core.swift": "public let zero: Int32 = 0\n"})
        self.clone("decoy", {"Package.swift": TOOLS + 'let package = Package(name: "decoy")\n'})
        lib = TOOLS + ('let package = Package(name: "lib", products: [.library(name: "Lib", targets: ["Lib"])], '
                       'dependencies: [.package(path: "../core")], targets: [.target(name: "Lib", dependencies: '
                       '[.product(name: "Core", package: "core")])])\n')
        self.lib1 = self.clone("lib", {"Package.swift": lib, "Sources/Lib/Lib.swift": "import Core\n"
                                       "public let zero: Int32 = Core.zero\n"})
        self.lib2 = self.clone("lib", {"Sources/Lib/Lib.swift": "import Core\n// Two.\npublic let zero: Int32 = "
                                       "Core.zero\n"})
        self.app = self.clone("app", {
            "Package.swift": TOOLS + 'var deps: [Package.Dependency] = [.package(path: "../lib")]\n'
            'if Context.environment["IMPORT_PROBE_TEST_DECOY"] != nil {\n    deps.append(.package(path: "../decoy"))\n'
            '}\nlet package = Package(name: "app", products: [.library(name: "App", targets: ["App"])], '
            'dependencies: deps, targets: [.target(name: "App", dependencies: [.product(name: "Lib", package: '
            '"lib")])])\n',
            "Sources/App/App.swift": C_IMPORT + "import Lib\npublic func pid() -> Int32 { getpid() + zero }\n",
            "Examples/Tool/Package.swift": TOOLS + 'let package = Package(name: "Tool", dependencies: '
            '[.package(path: "../..")], targets: [.executableTarget(name: "Tool", dependencies: [.product(name: '
            '"App", package: "app")])])\n',
            "Examples/Tool/Sources/Tool/main.swift": C_IMPORT + "import App\nprint(getpid(), pid())\n"})
        return os.path.join(self.clones, "app")


@unittest.skipUnless(HAVE_SWIFT, "needs swift")
class PathDependencyTests(FixtureCase):
    def test_followed_transitively_from_their_checkouts(self):
        app = self.graph()
        work = os.path.join(self.work, "app-macos")
        probe.fresh_work(work)
        pkg, rec = probe.prepare(app, self.app, "app", work, REPO, HEAD, swiftpm=self.swiftpm)
        self.assertEqual(pkg, os.path.join(work, "src", "app"))
        deps = {d["identity"]: d for d in rec["dependencies"]}
        self.assertEqual(sorted(deps), ["core", "lib"])
        self.assertEqual(deps["lib"]["revision"], self.lib2)
        self.assertEqual(deps["lib"]["requirement"], "path: ../lib")
        self.assertEqual(deps["core"]["revision"], g(os.path.join(self.clones, "core"), "rev-parse", "HEAD"))
        self.assertEqual(rec["local"], ["deps/lib", "deps/core"])
        self.assertFalse(os.path.exists(os.path.join(work, "deps", "decoy")))
        with open(os.path.join(pkg, "Package.swift")) as f:
            text = f.read()
        self.assertIn('.package(path: "../../deps/lib")', text)
        self.assertIn('.package(path: "../decoy")', text)
        with open(os.path.join(work, "deps", "lib", "Package.swift")) as f:
            self.assertIn('.package(path: "../core")', f.read())
        self.assertEqual(rec["rewrites"]["../../deps/lib/Package.swift"], [["../core", "../core"]]
                         if False else [("../core", "../core")])
        with open(os.path.join(work, "deps", "lib", "Sources", "Lib", "Lib.swift")) as f:
            self.assertIn("// Two.", f.read())
        # The clones are only read.
        self.assertEqual(g(os.path.join(self.clones, "app"), "status", "--porcelain"), "")

    def test_an_active_branch_is_followed(self):
        app = self.graph()
        os.environ["IMPORT_PROBE_TEST_DECOY"] = "1"
        work = os.path.join(self.work, "app-macos")
        probe.fresh_work(work)
        _, rec = probe.prepare(app, self.app, "app", work, REPO, HEAD, swiftpm=self.swiftpm)
        self.assertEqual(sorted(d["identity"] for d in rec["dependencies"]), ["core", "decoy", "lib"])

    def test_a_nested_package_in_place_and_a_ref(self):
        app = self.graph()
        self.assertEqual(probe.nested_packages(app, self.app), ["Examples/Tool"])
        self.assertEqual(probe.display_name("app", "Examples/Tool"), "app-Examples-Tool")
        work = os.path.join(self.work, "app-Examples-Tool-macos")
        probe.fresh_work(work)
        pkg, rec = probe.prepare(app, self.app, "app", work, REPO, HEAD, "Examples/Tool",
                                 probe.path_dep_refs([f"lib={self.lib1}"]), self.swiftpm)
        self.assertEqual(pkg, os.path.join(work, "src", "app", "Examples", "Tool"))
        self.assertEqual(rec["local"], ["src/app", "deps/lib", "deps/core"])
        self.assertEqual({d["identity"]: d["revision"] for d in rec["dependencies"]}["lib"], self.lib1)
        with open(os.path.join(pkg, "Package.swift")) as f:
            self.assertIn('.package(path: "../..")', f.read())
        with open(os.path.join(work, "src", "app", "Package.swift")) as f:
            self.assertIn('.package(path: "../../deps/lib")', f.read())
        self.assertEqual(rec["rewrites"]["Package.swift"], [])
        self.assertEqual(rec["rewrites"]["../../Package.swift"], [("../lib", "../../deps/lib")])

    def test_traits_survive_the_rewrite(self):
        cache = os.path.join(self.tmp, "cache")
        traited = os.path.join(cache, "traited-1234")
        commit(traited, {"Package.swift": TOOLS + 'let package = Package(name: "traited", products: [.library(name: '
                         '"Traited", targets: ["Traited"])], traits: [.default(enabledTraits: ["Loud"]), "Loud"], '
                         'targets: [.target(name: "Traited")])\n',
                         "Sources/Traited/T.swift": "#if Loud\npublic let loud = true\n#endif\npublic let t = 1\n"})
        g(traited, "config", "remote.origin.url", "https://example.invalid/traited")
        g(traited, "tag", "1.0.0")
        clone = os.path.join(self.clones, "withtraits")
        c = commit(clone, {"Package.swift": TOOLS + 'let package = Package(name: "withtraits", dependencies: ['
                           '.package(url: "https://example.invalid/traited.git", from: "1.0.0", traits: [])], targets: '
                           '[.target(name: "W", dependencies: [.product(name: "Traited", package: "traited")])])\n',
                           "Sources/W/W.swift": "import Traited\n"})
        work = os.path.join(self.work, "withtraits-macos")
        probe.fresh_work(work)
        choose = manifests.choose
        manifests.choose = functools.partial(choose, cache=cache)
        try:
            pkg, rec = probe.prepare(clone, c, "withtraits", work, REPO, HEAD, swiftpm=self.swiftpm)
        finally:
            manifests.choose = choose
        self.assertEqual(rec["dependencies"][0]["version"], "1.0.0")
        with open(os.path.join(pkg, "Package.swift")) as f:
            self.assertIn('.package(path: "../../deps/traited", traits: [])', f.read())
        p = subprocess.run(["swift", "package", "--disable-sandbox", *self.swiftpm, "--package-path", pkg,
                            "--scratch-path", os.path.join(work, "scratch-macos"), "dump-package"],
                           capture_output=True, text=True, check=True)
        dep = json.loads(p.stdout)["dependencies"][0]["fileSystem"][0]
        self.assertEqual((dep["identity"], dep["traits"]), ("traited", []))


@unittest.skipUnless(BUILDS, "builds need macOS and swift (IMPORT_PROBE_SKIP_BUILDS unset)")
class BuildTests(FixtureCase):
    def test_a_nested_package_is_probed_on_its_own(self):
        app = self.graph()
        result = probe.probe(app, self.app, "macos", self.args(), REPO, HEAD, "Examples/Tool")
        self.assertEqual(result["meta"]["nested"], "Examples/Tool")
        self.assertEqual(result["meta"]["name"], "app-Examples-Tool")
        self.assertEqual([(r["file"], r["name"], r["nested"]) for r in result["records"]],
                         [("Sources/Tool/main.swift", "getpid", "Examples/Tool")])
        self.assertFalse(os.path.exists(os.path.join(self.work, "app-Examples-Tool-macos")))

    def test_own_modules(self):
        clone = os.path.join(self.clones, "own")
        c = commit(clone, {
            "Package.swift": TOOLS + 'let package = Package(name: "own", targets: [.target(name: "CShim"), '
            '.target(name: "App", dependencies: ["CShim"]), .target(name: "App2", dependencies: ["CShim"])])\n',
            "Sources/CShim/include/CShim.h": "#include <unistd.h>\nint shim_answer(void);\n",
            "Sources/CShim/CShim.c": '#include "CShim.h"\nint shim_answer(void) { return 42; }\n',
            # getpid only through CShim, which re-exports unistd.h.
            "Sources/App/App.swift": "import CShim\npublic func f() -> Int32 { getpid() + shim_answer() }\n",
            # getppid through both the file's own import and CShim: the
            # ordinary probe can't see it.
            "Sources/App2/App2.swift": C_IMPORT + "import CShim\npublic func g() -> Int32 { getppid() }\n"})
        result = probe.probe(clone, c, "macos", self.args(own_modules=True), REPO, HEAD)
        self.assertEqual(result["records"], [])
        om = result["ownModules"]
        self.assertEqual(om["modules"], ["CShim"])
        self.assertEqual(sorted((r["file"], r["name"], tuple(r["via"])) for r in om["records"]),
                         [("Sources/App/App.swift", "getpid", ("CShim",)),
                          ("Sources/App2/App2.swift", "getppid", ("CShim",))])
        self.assertEqual(om["ownNames"], {"Sources/App/App.swift": ["shim_answer"]})
        self.assertEqual(sorted(t["name"] for t in om["targets"]), ["App", "App2"])

    def test_reexport_run(self):
        commit(os.path.join(self.clones, "re"), {
            "Package.swift": TOOLS + 'let package = Package(name: "re", products: [.library(name: "Re", targets: '
            '["Re"])], targets: [.target(name: "Re")])\n',
            "Sources/Re/Exports.swift": "#if canImport(Darwin)\n@_exported import Darwin\n#elseif canImport(Glibc)\n"
            "@_exported import Glibc\n#endif\n",
            # Served by the other file's re-export, module-wide.
            "Sources/Re/Uses.swift": "public func repid() -> Int32 { getpid() }\n"})
        clone = os.path.join(self.clones, "user")
        c = commit(clone, {
            "Package.swift": TOOLS + 'let package = Package(name: "user", dependencies: [.package(path: "../re")], '
            'targets: [.target(name: "User", dependencies: [.product(name: "Re", package: "re")]), '
            '.executableTarget(name: "Tool", dependencies: ["User", .product(name: "Re", package: "re")])])\n',
            "Sources/User/User.swift": "import Re\npublic func u() -> Int32 { getppid() + repid() }\n",
            "Sources/User/Own.swift": "import Re\n" + C_IMPORT + "public func o() -> Int32 { getpid() }\n",
            # Built only once User builds: a later round.
            "Sources/Tool/main.swift": "import Re\nimport User\nexit(u() == 0 ? 0 : 1)\n"})
        result = reexport.run(clone, c, "macos", self.args(reexport=True), REPO, HEAD)
        self.assertEqual([(s["file"], s["line"], s["active"], s["built"]) for s in result["demoted"]],
                         [("deps/re/Sources/Re/Exports.swift", 2, True, True),
                          ("deps/re/Sources/Re/Exports.swift", 4, False, True)])
        self.assertEqual(result["fixups"]["module"], ["deps/re/Sources/Re/Uses.swift"])
        self.assertEqual(sorted((r["file"], r["name"], r["round"]) for r in result["records"]),
                         [("Sources/Tool/main.swift", "exit", 2), ("Sources/User/User.swift", "getppid", 1)])
        self.assertEqual([r["exit"] != 0 for r in result["rounds"]], [True, True, False])
        self.assertEqual(sorted(result["fixups"]["own"]), ["src/user/Sources/Tool/main.swift",
                                                           "src/user/Sources/User/User.swift"])
        self.assertEqual(result["baseline"]["exit"], 0)


if __name__ == "__main__":
    unittest.main()
