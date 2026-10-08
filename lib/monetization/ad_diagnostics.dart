import 'package:flutter/foundation.dart';

/// Local development diagnostics only; no player identifiers or gameplay data.
void adDebugLog(String message) {
  if (kDebugMode) debugPrint('[BrainRush Ads] $message');
}
