# nio-coverage

Moved to [`Utilities/adopter-coverage`](../adopter-coverage/README.md), which audits swift-nio and swift-system's other adopters the same way.

`check.sh` here keeps the old command working: it runs the new tool for swift-nio alone. The report is now `.build/adopter-coverage/nio/COVERAGE.md`.

| Old variable | Now |
|---|---|
| `NIO_PATH`, `NIO_REF`, `SYSTEM_REF` | unchanged |
| `NIO_COVERAGE_OUT` | `ADOPTER_COVERAGE_OUT`, which holds a directory per package |
| `NIO_COVERAGE_WORK` | `ADOPTER_COVERAGE_WORK` |
| `NIO_COVERAGE_MAPPING` | `ADOPTER_COVERAGE_MAPPING` |

The old default directories, `.build/nio-coverage` and `.build/nio-coverage-work`, are no longer used and can be deleted.
