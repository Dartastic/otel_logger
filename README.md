# otel_logger

OpenTelemetry instrumentation for
[`package:logger`](https://pub.dev/packages/logger) — the popular
pretty-print logger by leisim.

```dart
import 'package:logger/logger.dart';
import 'package:otel_logger/otel_logger.dart';

final logger = Logger(
  output: MultiOutput([
    ConsoleOutput(),   // keep the pretty terminal output
    OTelLogOutput(),   // mirror every event into OTel logs
  ]),
);

logger.i('user signed in');
// → terminal: prettified line
// → OTel logs: structured record with severity_number=INFO,
//   body="user signed in", trace_id/span_id from the active span
```

Each `OutputEvent` becomes one OTel log record:
- `body` — joined output lines (prettified prefixes preserved)
- `severity_number` — `logger.Level` → OTel `Severity`:
  trace→TRACE, debug→DEBUG, info→INFO, warning→WARN,
  error→ERROR, fatal→FATAL
- `severity_text` — `event.level.name`
- `timestamp` — from `event.origin.time`
- `exception.type` / `.message` / `.stacktrace` — when
  `LogEvent.error` / `.stackTrace` are non-null

## Span correlation

Log calls inside a `Tracer.startActiveSpan` block automatically
carry the surrounding span's `trace_id` / `span_id` via
`Context.current` — no extra plumbing needed.

```dart
await tracer.startActiveSpanAsync('checkout', (span) async {
  logger.i('starting cart validation');
  // ... this record will be correlated to the checkout span
});
```

## Knobs

| Constructor arg | Default | Effect |
|---|---|---|
| `loggerProvider` | `OTel.loggerProvider()` (lazy) | Custom logger provider |
| `loggerName` | `'package.logger'` | OTel instrumentation scope name |
| `includeStackTrace` | `true` | Set to `false` to omit `exception.stacktrace` attribute |

## Suppression

```dart
runWithoutLoggerInstrumentation(() {
  logger.i('this one will not reach OTel');
});
```

Inside the zone, `OTelLogOutput.output` short-circuits. The
`ConsoleOutput` half (if you set up `MultiOutput`) still runs.

## License

Apache 2.0
