import 'dart:js_interop';

@JS('window._initialWebHash')
external String? get _initialWebHash;

String get initialWebHash => _initialWebHash ?? '';

void captureWebHash() {} // No-op, ya se capturó en index.html
