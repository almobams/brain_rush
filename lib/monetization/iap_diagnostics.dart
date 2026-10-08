import 'package:flutter/foundation.dart';

void iapDebugLog(String message) {
  if (kDebugMode) debugPrint('[BrainRush IAP] $message');
}
