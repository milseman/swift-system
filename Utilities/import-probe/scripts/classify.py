#!/usr/bin/env python3
"""What System answers for each name a probe finds: adopter-coverage's
ledger reading, imported read-only.

System's coverage at a commit is the ledger's (status.sh's section 5):
api-delta's scan of System's sources and derive.py's reading of their doc
sentences ("The corresponding C function is `x`."), CInterop's aliases and
accessors, mapping.ini's hand statuses and equivalences, and its answers
outside System (`swift`, `wrap = no`). `ledger.Coverage.answer` decides a
name on one platform; this maps its kinds to the probe's classes:

  covered            System covers it on this platform: work for the adopter
  gap                System lacks it there: a System gap
  not System's       mapping.ini's `wrap = no`, a lane's verdict
  standard library   mapping.ini's `swift` answer
  module             a module the file can't find (not a name)

mapping.ini and modules.ini are read at this worktree's HEAD commit, as
the ledger reads them, and System's sources at the commit the probe built
against.
"""

import sys

sys.dont_write_bytecode = True

import os  # noqa: E402
import subprocess  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
UTILITIES = os.path.dirname(os.path.dirname(HERE))
COVERAGE_SCRIPTS = os.path.join(UTILITIES, "adopter-coverage", "scripts")
if COVERAGE_SCRIPTS not in sys.path:
    sys.path.append(COVERAGE_SCRIPTS)

import ledger  # noqa: E402
import check  # noqa: E402

MODULES_FILE = "Utilities/adopter-coverage/modules.ini"
MAPPING_FILE = "Utilities/adopter-coverage/mapping.ini"
PLATFORM = {"macos": "Darwin", "linux": "Linux", "musl": "Musl", "wasi": "WASI"}
CLASSES = ("covered", "gap", "not System's", "standard library", "module")


def show(repo, commit, path):
    p = subprocess.run(["git", "--no-optional-locks", "-C", repo, "show", f"{commit}:{path}"],
                       capture_output=True, text=True, env=dict(os.environ, GIT_NO_LAZY_FETCH="1"))
    if p.returncode != 0:
        raise RuntimeError(f"{path} isn't in {commit[:12]}: {p.stderr.strip()}")
    return p.stdout


def modules(repo, commit):
    """modules.ini's groups at a commit (ledger.Modules)."""
    return ledger.Modules(show(repo, commit, MODULES_FILE))


class Classifier:
    def __init__(self, repo, head, system_commit, work):
        os.makedirs(work, exist_ok=True)
        mapping_path = os.path.join(work, "mapping.ini")
        with open(mapping_path, "w", encoding="utf-8") as f:
            f.write(show(repo, head, MAPPING_FILE))
        _, mapping, self.mapping_problems = check.load_mapping(mapping_path)
        scan, derived = ledger.system_api(repo, system_commit, work)
        self.coverage = ledger.Coverage(scan, derived, mapping)
        self.system_commit = system_commit

    def classify(self, name, platform, kind="value"):
        """(class, unit, how) for a name on a platform (Darwin, Linux...).
        A member is a C field when the diagnostic says it's a property or
        doesn't say."""
        if kind == "module":
            return "module", name, "a module the file imports, not a name"
        field = kind == "member"
        k, unit, how = self.coverage.answer(name, platform, field=field)
        return k, unit, how
