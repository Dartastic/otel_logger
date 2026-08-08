# Changelog

## [0.2.0-wip]

### Changed

- Semantic conventions updated to the current OTel registry: deprecated
  attribute keys are no longer emitted (`db.system` -> `db.system.name`,
  `db.operation` -> `db.operation.name`, `rpc.system` -> `rpc.system.name`,
  with `rpc.service` folded into a fully-qualified `rpc.method`).
- Dependency floors raised to `dartastic_opentelemetry ^1.1.0-beta.12` and
  `dartastic_opentelemetry_api ^1.0.0-rc.1`. The previous floors declared
  compatibility with API versions that predate the semconv enums this
  package uses and could not actually resolve-and-compile.
- `repository` URL corrected to the canonical `Dartastic` org casing so
  pub.dev repository verification succeeds.

### Added

- `OTelLogOutput extends LogOutput` — drops into any `Logger(...)`
  construction and mirrors every event into the OpenTelemetry logs
  pipeline. Carries `trace_id` / `span_id` from `Context.current`
  so log lines inside a `Tracer.startActiveSpan` block are
  auto-correlated with the surrounding span.
- Maps `logger.Level` → OTel `Severity`:
  trace → TRACE, debug → DEBUG, info → INFO, warning → WARN,
  error → ERROR, fatal → FATAL. Deprecated `verbose` aliases
  TRACE and `wtf` aliases FATAL.
- `LogEvent.error` / `LogEvent.stackTrace` lift to OTel
  `exception.type` / `exception.message` / `exception.stacktrace`
  attributes. `includeStackTrace: false` opts out of the trace.
- `runWithoutLoggerInstrumentation` / async variant —
  zone-scoped suppression matching the rest of the OSS wrappers.
- 5 tests covering severity mapping, exception attribute
  attachment, opt-out, and suppression.
