import 'package:flutter/foundation.dart';

/// Debug-only tracer. The closure AND its string literals are stripped from
/// release builds because they live inside an `assert`. Tag family `[GLM.*]`
/// is project-specific.
void glmTrace(String Function() message) {
  assert(() {
    debugPrint(message());
    return true;
  }());
}
