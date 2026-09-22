# 60-Second Brain Rush

A complete offline Flutter MVP for iOS and Android, with a web preview for convenient review. English and Arabic, RTL, dark/light/system themes, four procedural question types, daily challenges, streak scoring, statistics, settings, haptics, and persistent local progress.

## Run

Built with Flutter **3.47.4 stable / Dart 3.13.3**. Install a compatible stable Flutter SDK and the native platform tools, then from this directory:

```sh
flutter pub get
flutter run
```

For the browser preview:

```sh
flutter run -d chrome
```

Validation and native builds:

```sh
flutter analyze
flutter test
flutter build apk --release
flutter build ios --release --no-codesign
```

An unsigned iOS build is a compile check, not an installable IPA. A developer signing identity and provisioning profile are required to install on iPhone or submit to Apple. Android release signing is also required before publishing; the scaffold's debug signing is only for development.

## How it plays

A round begins when the first question has been rendered and lasts 60 seconds. A monotonic stopwatch determines the deadline; periodic callbacks only refresh the display. Time continues while backgrounded, and resume catches up. The score/timer header stays fixed; compact question cards and answer buttons fit short phone screens at normal text size. Larger text can scroll beneath the header. Inputs at or beyond the deadline are rejected. An answer locks immediately, reveals the correct choice, then advances after 320 ms. Leaving early discards the round.

Correct answers award 1 point, increasing to 2 at 3 consecutive correct answers, 3 at 6, and 4 at 10. Wrong answers award zero and reset the consecutive count. Set `ScoringPolicy(streakBonuses: false)` for flat +1 scoring. “FAST!” recognizes responses under 1.4 seconds without adding points.

Normal rush difficulty changes at 15 and 35 seconds. Daily mode uses a local calendar-date seed and increases difficulty every 12 questions, so answering speed cannot change the shared question sequence. The sequence is deterministic within this engine version. Calendar dates follow each device's timezone. Daily replay is intentionally available; the best completed result for each date is retained. All completed replays count toward lifetime statistics. Daily history is bounded to 90 dates; lifetime aggregates remain intact.

## Structure

- `lib/game/`: models, independently testable generators, configurable scoring, and timer/session controller.
- `lib/core/`: Riverpod application state, versioned SharedPreferences storage, and feedback service.
- `lib/localization/`: centralized English/Arabic strings and day-count grammar. Math expressions use LTR inside RTL layouts.
- `lib/theme/`, `lib/widgets/`: visual system, reusable controls, score/timer feedback, emblem, and confetti.
- `lib/screens/`: playable home, game, results, daily, statistics, and settings screens.
- `test/`: generator invariants across 6,000 questions; deterministic daily seeds; scoring thresholds; deadline and double-answer protection; difficulty; persistence; localization coverage; complete rounds and responsive layouts. Full-flow tests also cover daily replay, wrong-answer feedback, streak scoring, background expiry, settings, and a fresh SharedPreferences instance after restart.
- `tool/`: original launcher artwork and its reproducible Flutter drawing source.

SharedPreferences stores one versioned JSON snapshot under `brain_rush_v1`. Saves are serialized, pending writes complete safely if the store is disposed, failures are surfaced in the app, and malformed data falls back safely. Progress belongs to the current installation. No accounts, backend, tracking, analytics, or advertising SDKs are included.

## Deliberate V1 placeholders

Sound cues have a service boundary and a saved setting, but remain silent until licensed offline audio is added. Premium, restore purchases, and rewarded extra time are clearly marked as future functionality; no purchases or ads occur. Privacy and terms screens contain preliminary local-only explanations, not release-ready legal documents. Monetization should be integrated outside the game controller.

## Release work

Review identifiers, signing, store metadata, final legal documents, and device accessibility before store submission. Test physical iOS/Android devices for haptic intensity and OS-specific lifecycle behavior. The browser preview is for review; the native apps are the offline targets.

On this Mac, cloud-folder metadata in Documents interfered with iOS framework signing. Compiling a copy in `/private/tmp` resolved the issue. If it recurs, copy the source (excluding `build`, `.dart_tool`, and `ios/Pods`) into a non-cloud folder before building. Do not change application code to work around this filesystem issue.
# brain_rush
