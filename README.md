# 60-Second Brain Rush

A Flutter brain-training game for iOS and Android, with a web preview for convenient review. English and Arabic, RTL, dark/light/system themes, four procedural question types, daily challenges, streak scoring, statistics, settings, haptics, and persistent local progress.

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

SharedPreferences stores one versioned JSON snapshot under `brain_rush_v1`. Saves are serialized, pending writes complete safely if the store is disposed, failures are surfaced in the app, and malformed data falls back safely. Progress belongs to the current installation. There are no accounts, backend, or analytics. Native builds include Google Mobile Ads and store purchase integrations; the web preview has no ads or purchases.

## Monetization

`lib/monetization/ad_policy.dart` sets the interstitial schedule: normal games 1 and 2 are clear; after normal game 3 and then every 3 completed normal games, an ad may appear only when the player leaves Results and at least 2 minutes have passed since the previous shown ad. Daily Challenge never triggers an interstitial. Missing or failed ads continue navigation immediately. Remove Ads ownership disables interstitials.

`lib/monetization/ad_service.dart` owns AdMob and UMP. At launch UMP updates consent, displays a required form, and ads are requested only if `canRequestAds()` allows them. The global Google Mobile Ads request configuration is set to `MaxAdContentRating.g` before SDK initialization. Settings exposes Privacy choices if UMP requires an entry point. Debug Android/iOS builds use Google's official sample app and interstitial IDs. Release IDs are empty by default and ads remain disabled until configured. Rewarded ads are retained behind `AdConfig.rewardedAdsEnabled`, which is `false` for V1: no rewarded ad loads, requests, UI, or XP bonus path is active.

`lib/monetization/purchase_service.dart` owns the non-consumable `brain_rush_remove_ads`. It loads the store's localized price and listens for purchase and restore transactions. Ownership is rechecked through store restoration on each launch, without a locally trusted premium flag. Store callbacks provide the entitlement; because this app has no backend, server-side receipt validation is not implemented. The game opens before store initialization completes.

### Production configuration still required

1. In **AdMob**, create one Android app and one iOS app, with an interstitial unit for each. Create and publish the UMP privacy message, and check regional consent settings. Rewarded units are not needed for V1.
2. Put the **Android AdMob App ID** in `android/app/src/release/AndroidManifest.xml` as `com.google.android.gms.ads.APPLICATION_ID`, and remove its `MobileAdsInitProvider` removal entry. Put the same ID in the `ANDROID_ADMOB_APP_ID` Dart define. A release build with no ID keeps ads disabled; the release manifest currently removes the provider to avoid a startup crash. Keep the debug manifest's official sample ID unchanged.
3. Put the **iOS AdMob App ID** in `ios/Flutter/Release.xcconfig` as `ADMOB_APP_ID`, and the same ID in the `IOS_ADMOB_APP_ID` Dart define. The Info.plist reads that build setting. Keep the debug xcconfig's sample ID unchanged.
4. Supply `ANDROID_INTERSTITIAL_AD_UNIT_ID` and `IOS_INTERSTITIAL_AD_UNIT_ID` as Dart defines for release builds. These names are read in `lib/monetization/ad_service.dart`; never put production IDs into gameplay code. An absent unit ID disables interstitial ads. Rewarded unit defines remain reserved for a future release but are inactive while `REWARDED_ADS_ENABLED` is false.
5. In **App Store Connect**, create a non-consumable in-app purchase with product ID `brain_rush_remove_ads`, localized name/description and price, and configure paid apps agreements/tax/banking and sandbox testers. In **Google Play Console**, create and activate a one-time in-app product with the same product ID, localized listing and price, and configure license testers. The product ID is in `lib/monetization/purchase_service.dart`.
6. Before publishing, provide a real Privacy Policy and Terms, declare Google Mobile Ads and IAP data use in App Store privacy and Google Play Data Safety forms, configure the applicable iOS SKAdNetwork IDs, and verify consent and purchase flows on physical devices. The in-app legal text is preliminary. No ATT prompt is requested by this app.

### AdMob blocking controls for V1

Set **Maximum ad content rating** to **G** in the AdMob dashboard as well as retaining the in-app G request configuration.

Use AdMob Blocking Controls to review and block sensitive categories, especially References to Sex & Sexuality, Dating, Gambling / Social Casino, Alcohol, and other adult or sensitive categories available for this account. Also block unwanted non-game general categories where they are available, including Music/Audio and related entertainment categories.

AdMob does not provide a reliable “games only” guarantee. Google classifies categories automatically, so filtering is best-effort. Periodically inspect the Ad Review Center and manually block unwanted creatives, advertisers, or destination URLs.

## Release work

Review identifiers, signing, store metadata, final legal documents, and device accessibility before store submission. Test physical iOS/Android devices for haptic intensity and OS-specific lifecycle behavior. The browser preview is for review; gameplay remains playable offline on native devices.

On this Mac, cloud-folder metadata in Documents interfered with iOS framework signing. Compiling a copy in `/private/tmp` resolved the issue. If it recurs, copy the source (excluding `build`, `.dart_tool`, and `ios/Pods`) into a non-cloud folder before building. Do not change application code to work around this filesystem issue.
