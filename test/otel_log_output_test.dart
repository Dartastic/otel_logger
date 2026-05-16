// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:logger/logger.dart' as l;
import 'package:otel_logger/otel_logger.dart';
import 'package:test/test.dart';

class _MemoryLogExporter implements LogRecordExporter {
  final List<LogRecord> records = [];
  bool _shutdown = false;

  @override
  Future<ExportResult> export(List<LogRecord> r) async {
    if (_shutdown) return ExportResult.failure;
    records.addAll(r);
    return ExportResult.success;
  }

  @override
  Future<void> forceFlush() async {}

  @override
  Future<void> shutdown() async {
    _shutdown = true;
  }
}

void main() {
  group('OTelLogOutput', () {
    late _MemoryLogExporter exporter;

    setUp(() async {
      await OTel.reset();
      exporter = _MemoryLogExporter();
      await OTel.initialize(
        serviceName: 'otel-logger-test',
        detectPlatformResources: false,
        logRecordProcessor: SimpleLogRecordProcessor(exporter),
      );
    });

    tearDown(() async {
      await OTel.shutdown();
      await OTel.reset();
    });

    test('info event becomes an OTel record with severity INFO', () {
      final out = OTelLogOutput();
      out.output(l.OutputEvent(
        l.LogEvent(l.Level.info, 'hello'),
        ['hello'],
      ));

      final rec = exporter.records.single;
      expect(rec.body, equals('hello'));
      expect(rec.severityNumber, equals(Severity.INFO));
      expect(rec.severityText, equals('info'));
    });

    test('each level maps to the right OTel severity', () {
      final out = OTelLogOutput();
      const cases = <l.Level, Severity>{
        l.Level.trace: Severity.TRACE,
        l.Level.debug: Severity.DEBUG,
        l.Level.info: Severity.INFO,
        l.Level.warning: Severity.WARN,
        l.Level.error: Severity.ERROR,
        l.Level.fatal: Severity.FATAL,
      };
      for (final entry in cases.entries) {
        out.output(l.OutputEvent(
          l.LogEvent(entry.key, entry.key.name),
          [entry.key.name],
        ));
      }

      final mapped = exporter.records.map((r) => r.severityNumber).toList();
      expect(mapped, equals(cases.values.toList()));
    });

    test('error + stackTrace land as exception.* attributes', () {
      final out = OTelLogOutput();
      final stack = StackTrace.current;
      out.output(l.OutputEvent(
        l.LogEvent(
          l.Level.error,
          'boom',
          error: StateError('out of stock'),
          stackTrace: stack,
        ),
        ['boom'],
      ));

      final attrs = {
        for (final a in exporter.records.single.attributes!.toList())
          a.key: a.value
      };
      expect(attrs['exception.type'], equals('StateError'));
      expect(attrs['exception.message'], contains('out of stock'));
      expect(attrs['exception.stacktrace'], isA<String>());
    });

    test('includeStackTrace:false omits stacktrace attribute', () {
      final out = OTelLogOutput(includeStackTrace: false);
      out.output(l.OutputEvent(
        l.LogEvent(
          l.Level.error,
          'boom',
          error: StateError('x'),
          stackTrace: StackTrace.current,
        ),
        ['boom'],
      ));

      final keys = exporter.records.single.attributes!
          .toList()
          .map((a) => a.key)
          .toSet();
      expect(keys.contains('exception.message'), isTrue);
      expect(keys.contains('exception.stacktrace'), isFalse);
    });

    test('runWithoutLoggerInstrumentation bypasses emission', () {
      final out = OTelLogOutput();
      runWithoutLoggerInstrumentation(() {
        out.output(l.OutputEvent(
          l.LogEvent(l.Level.info, 'quiet'),
          ['quiet'],
        ));
      });
      expect(exporter.records, isEmpty);
    });
  });
}
