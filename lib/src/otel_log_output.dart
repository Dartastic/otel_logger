// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:logger/logger.dart' as logger_lib;

import 'logger_suppression.dart';

/// A `package:logger` [LogOutput] that mirrors every event into the
/// OpenTelemetry logs pipeline.
///
/// Use it alongside (or instead of) `ConsoleOutput` so dev-friendly
/// formatted lines still appear in your terminal while structured
/// records flow to your OTel backend:
///
/// ```dart
/// final logger = Logger(
///   output: MultiOutput([
///     ConsoleOutput(),
///     OTelLogOutput(),
///   ]),
/// );
/// logger.i('user signed in');
/// ```
///
/// Each `OutputEvent` becomes one OTel log record:
/// - `body` — the joined output lines (so prettified prefixes etc.
///   are preserved as the visual record body)
/// - `severity_number` — mapped from `logger.Level` (trace → TRACE,
///   debug → DEBUG, info → INFO, warning → WARN, error → ERROR,
///   fatal → FATAL; deprecated `verbose` aliases trace and `wtf`
///   aliases fatal)
/// - `severity_text` — `event.level.name`
/// - `timestamp` — from `event.origin.time`
/// - attributes — `exception.type` / `exception.message` /
///   `exception.stacktrace` when `LogEvent.error` / `.stackTrace`
///   are present
///
/// Records inherit `trace_id` / `span_id` from `Context.current` for
/// free via the OTel logger's `emit` path — log calls inside a
/// `Tracer.startActiveSpan` block are auto-correlated with the
/// surrounding span.
class OTelLogOutput extends logger_lib.LogOutput {
  /// Creates the output.
  ///
  /// - [loggerProvider] — defaults to `OTel.loggerProvider()` at
  ///   first use. Pass a custom one if you've configured a named
  ///   logger provider with a different exporter.
  /// - [loggerName] — the OTel instrumentation scope name (shows up
  ///   as `scope.name` on emitted records). Defaults to
  ///   `package.logger`.
  /// - [includeStackTrace] — when `false`, the stack trace from
  ///   `LogEvent.stackTrace` is not added as an attribute. Defaults
  ///   to `true`.
  OTelLogOutput({
    LoggerProvider? loggerProvider,
    String loggerName = 'package.logger',
    bool includeStackTrace = true,
  })  : _provider = loggerProvider,
        _loggerName = loggerName,
        _includeStackTrace = includeStackTrace;

  final LoggerProvider? _provider;
  final String _loggerName;
  final bool _includeStackTrace;

  @override
  void output(logger_lib.OutputEvent event) {
    if (loggerInstrumentationSuppressed()) return;
    final provider = _provider ?? OTel.loggerProvider();
    final otelLogger = provider.getLogger(_loggerName);

    final attrs = <Attribute<Object>>[];
    final origin = event.origin;
    if (origin.error != null) {
      attrs.add(OTel.attributeString(
        'exception.type',
        origin.error.runtimeType.toString(),
      ));
      attrs.add(OTel.attributeString(
        'exception.message',
        origin.error.toString(),
      ));
    }
    if (_includeStackTrace && origin.stackTrace != null) {
      attrs.add(OTel.attributeString(
        'exception.stacktrace',
        origin.stackTrace.toString(),
      ));
    }

    otelLogger.emit(
      timeStamp: origin.time,
      severityNumber: _mapLevel(event.level),
      severityText: event.level.name,
      body: event.lines.join('\n'),
      attributes: attrs.isEmpty ? null : OTel.attributes(attrs),
    );
  }
}

Severity _mapLevel(logger_lib.Level level) {
  switch (level) {
    // ignore: deprecated_member_use — preserve back-compat with logger 1.x apps
    case logger_lib.Level.verbose:
    case logger_lib.Level.trace:
      return Severity.TRACE;
    case logger_lib.Level.debug:
      return Severity.DEBUG;
    case logger_lib.Level.info:
      return Severity.INFO;
    case logger_lib.Level.warning:
      return Severity.WARN;
    case logger_lib.Level.error:
      return Severity.ERROR;
    // ignore: deprecated_member_use
    case logger_lib.Level.wtf:
    case logger_lib.Level.fatal:
      return Severity.FATAL;
    default:
      // Filter sentinels (all, off, nothing) shouldn't reach an
      // OutputEvent, but if they do, map to UNSPECIFIED rather than
      // throwing.
      return Severity.UNSPECIFIED;
  }
}
