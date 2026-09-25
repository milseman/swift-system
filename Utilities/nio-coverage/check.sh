#!/bin/bash
# nio-coverage moved to Utilities/adopter-coverage, which audits swift-nio
# and swift-system's other adopters. This wrapper keeps the old command
# working: it runs the new tool for swift-nio alone, whose report is then
# .build/adopter-coverage/nio/COVERAGE.md. See README.md in this directory.
#
# NIO_PATH, NIO_REF and SYSTEM_REF mean what they did. NIO_COVERAGE_OUT,
# NIO_COVERAGE_WORK and NIO_COVERAGE_MAPPING become ADOPTER_COVERAGE_OUT,
# ADOPTER_COVERAGE_WORK and ADOPTER_COVERAGE_MAPPING.
set -euo pipefail
[ -z "${NIO_COVERAGE_OUT:-}" ] || export ADOPTER_COVERAGE_OUT="$NIO_COVERAGE_OUT"
[ -z "${NIO_COVERAGE_WORK:-}" ] || export ADOPTER_COVERAGE_WORK="$NIO_COVERAGE_WORK"
[ -z "${NIO_COVERAGE_MAPPING:-}" ] || export ADOPTER_COVERAGE_MAPPING="$NIO_COVERAGE_MAPPING"
exec "$(dirname "$0")/../adopter-coverage/check.sh" nio
