import 'package:flutter/services.dart';

enum FeedbackCue {
  correct,
  incorrect,
  tap,
  fast,
  streak,
  countdown,
  timeUp,
  achievement,
  levelUp,
}

class FeedbackService {
  const FeedbackService({required this.haptics, required this.sound});
  static const _sounds = MethodChannel('brain_rush/sound_effects');
  final bool haptics, sound;
  void play(FeedbackCue cue) {
    if (haptics) {
      switch (cue) {
        case FeedbackCue.incorrect:
          HapticFeedback.mediumImpact();
        case FeedbackCue.correct || FeedbackCue.fast:
          HapticFeedback.lightImpact();
        case FeedbackCue.streak:
          HapticFeedback.mediumImpact();
        case FeedbackCue.achievement || FeedbackCue.levelUp:
          HapticFeedback.heavyImpact();
        case FeedbackCue.tap:
          HapticFeedback.selectionClick();
        case FeedbackCue.countdown || FeedbackCue.timeUp:
          break;
      }
    }
    if (!sound) return;
    // Native sides synthesize a short, quiet tone without external media.
    _sounds.invokeMethod<void>('play', cue.name).catchError((Object _) {
      // A desktop/web build can still provide a subtle system click.
      return SystemSound.play(SystemSoundType.click);
    });
  }
}
