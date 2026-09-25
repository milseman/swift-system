#!/bin/bash
# nio-coverage moved to Utilities/adopter-coverage, which audits swift-nio
# and swift-system's other adopters. This wrapper keeps the old command
# working; see README.md in this directory.
exec "$(dirname "$0")/../adopter-coverage/check.sh" "$@"
