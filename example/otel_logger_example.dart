// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

// Mirrors `package:logger` events into the OpenTelemetry logs
// pipeline. Console output stays pretty; OTel gets structured
// records with severity, timestamp, and exception.* attributes,
// auto-correlated with the active span.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:logger/logger.dart';
import 'package:otel_logger/otel_logger.dart';

Future<void> main() async {
  // 1. Bring up OTel first so records have somewhere to go.
  await OTel.initialize(serviceName: 'otel-logger-example');

  // 2. Add OTelLogOutput alongside your usual console output.
  final logger = Logger(
    output: MultiOutput([
      ConsoleOutput(),
      OTelLogOutput(),
    ]),
  );

  // 3. Log as usual. Each call becomes one OTel log record.
  logger.i('user signed in');
  logger.w('quota at 90%');

  // Errors carry exception.type / exception.message /
  // exception.stacktrace attributes.
  try {
    throw StateError('out of stock');
  } catch (e, s) {
    logger.e('checkout failed', error: e, stackTrace: s);
  }

  // Log inside an active span and the record inherits
  // trace_id / span_id automatically.
  final tracer = OTel.tracerProvider().getTracer('example');
  final span = tracer.startSpan('checkout');
  try {
    logger.i('applying discount'); // correlated with `checkout`
  } finally {
    span.end();
  }

  // Need to log without re-entering instrumentation (for example,
  // from inside an exporter)? Suppress emission for a block:
  runWithoutLoggerInstrumentation(() {
    logger.d('internal diagnostics only');
  });

  await OTel.shutdown();
}
