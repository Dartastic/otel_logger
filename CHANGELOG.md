# Changelog

## [0.1.0-beta.1-wip]

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
