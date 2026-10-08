# 60-Second Brain Rush

A Flutter brain-training game for iOS and Android, with a web preview for convenient review. First-launch language selection, 18 languages, RTL, dark/light/system themes, procedural question types, daily challenges, streak scoring, statistics, settings, haptics, and persistent local progress.

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

Normal rush difficulty changes at 15 and 35 seconds. Daily mode uses a local calendar-date seed and increases difficulty every 12 questions, so answering speed cannot change the shared question sequence. The sequence is deterministic within this engine version. Calendar dates follow each device's timezone. Daily allows three completed attempts per date; the first is free, free users earn a rewarded ad for each retry, and Remove Ads owners retry directly. Abandoned games do not consume an attempt. The best completed result for each date is retained, and the first Daily XP bonus is awarded only once. Daily history is bounded to 90 dates; lifetime aggregates remain intact.

## Structure

- `lib/game/`: models, independently testable generators, configurable scoring, and timer/session controller.
- `lib/core/`: Riverpod application state, versioned SharedPreferences storage, and feedback service.
- `lib/localization/`: centralized strings for 18 languages. Arabic, Urdu, and Persian use RTL; math expressions use LTR inside RTL layouts.
- `lib/theme/`, `lib/widgets/`: visual system, reusable controls, score/timer feedback, emblem, and confetti.
- `lib/screens/`: playable home, game, results, daily, statistics, and settings screens.
- `test/`: generator invariants across 6,000 questions; deterministic daily seeds; scoring thresholds; deadline and double-answer protection; difficulty; persistence; localization coverage; complete rounds and responsive layouts. Full-flow tests also cover daily replay, wrong-answer feedback, streak scoring, background expiry, settings, and a fresh SharedPreferences instance after restart.
- `tool/`: original launcher artwork and its reproducible Flutter drawing source.

SharedPreferences stores one versioned JSON snapshot under `brain_rush_v1`. Saves are serialized, pending writes complete safely if the store is disposed, failures are surfaced in the app, and malformed data falls back safely. Progress belongs to the current installation. There are no accounts or analytics. Supabase is optional and used only for anonymous Daily ranking; gameplay works offline. Native builds include Google Mobile Ads and store purchase integrations; the web preview has no ads or purchases.

## Language, local name, and sharing

On a fresh install, the player chooses a language, then may enter a name or skip it. Supported languages are English, Arabic, Spanish, Brazilian Portuguese, French, German, Italian, Turkish, Russian, Indonesian, Hindi, Japanese, Korean, Simplified Chinese, Traditional Chinese, Urdu, Persian, and Bengali. Hebrew is not included. Language changes apply immediately. Existing installations with a `brain_rush_v1` snapshot keep their language and progress and skip onboarding; they can set or remove a name in Settings. Both language and optional name are saved only on the device. The name appears sparingly on Home, new-best, and Daily #1 messages. It is never submitted to Supabase, AdMob, purchases, or analytics, and ranking stays anonymous. Localization key coverage and compact layouts are tested; native-speaker review is recommended before publishing all new translations.

Rush and Daily Results each have a Share action. The app renders a 4:5 result card locally at **1080 × 1350 PNG** and opens the native share sheet through `share_plus`. Rush shows score, personal best, accuracy, and best multiplier. Daily shows the saved personal best, challenge date, rank, and today's highest score when ranking is available. The image and captions omit participant count and percentile. If a player has set a local name, it appears in the shared image only after the player explicitly taps Share. Sharing does not create a Daily attempt, grant XP, submit a score, or trigger an ad; no image is uploaded by the app.

`lib/sharing/share_links.dart` uses the permanent Firebase Hosting URL **https://brain-rush-almobairik.web.app/go/** for both Rush and Daily captions. Future App Store and Google Play destinations are changed only in `hosting/public/store-links.js`; existing app builds and shared `/go/` links can stay the same. The image contains the result because some share targets may discard accompanying caption text.

## Local Daily reminders

Daily Challenge reminders are optional. After onboarding, Home shows one in-app explanation before any OS permission prompt; **Not now** prevents the explanation from repeating on every launch. Settings has a Daily Challenge Reminder switch. If permission is granted, the app schedules at most **30 individual local notifications** at about **1:00 PM in the device's current timezone**, each with ID `100000000 + YYYYMMDD` and a `daily_challenge:YYYY-MM-DD` payload. The IDs are reserved for this feature and fit within a signed 32-bit integer. The first completed Daily attempt cancels today's reminder; Rush, abandoned Daily games, and ranking/ad failures have no effect. Tomorrow's reminder stays scheduled. Startup, resume, language changes, and local name changes refresh the rolling schedule; disabling reminders cancels only Brain Rush Daily IDs. On Android, the plugin's boot receiver restores scheduled alarms after reboot. The schedule is replenished when the app opens again; after more than 30 unopened days there are no further reminders until the next launch.

The app uses `flutter_local_notifications`, `flutter_timezone`, and `timezone`. iOS requests alert and sound only after the player opts in; badge permission is not requested. Android requests notification permission when needed and uses a default-importance Daily Challenge channel and inexact scheduling. No exact-alarm permission, push server, device token, background network job, or notification backend is used. A notification tap opens the Daily Challenge screen, including after a cold launch. Permission denial or revocation turns the switch off without affecting the game. Localized reminder copy is available in all 18 app languages.

## Static Firebase Hosting site

`firebase.json` serves the lightweight files in `hosting/public`: a game overview with a real Home screenshot, a `/go/` Coming Soon page, and privacy pages at `/privacy/` (English) and `/privacy/ar/` (Arabic). The Firebase project is `brain-rush-almobairik`, and the permanent share URL is `https://brain-rush-almobairik.web.app/go/`. The privacy pages use `almobams1@gmail.com` as the contact address and should be reviewed against final store disclosures before publication.

The `/go/` page currently shows Coming Soon to everyone. Later, add the real HTTPS `APP_STORE_URL` and `PLAY_STORE_URL` in `hosting/public/store-links.js` and redeploy only the site. Its small browser script sends iPhone/iPad visitors to the App Store, Android visitors to Google Play, and leaves desktop or unsupported visitors on the page with visible store buttons. There are no forms, analytics, cookies set by page code, or Firebase Dynamic Links.

## Monetization

`lib/monetization/ad_policy.dart` sets the interstitial schedule: normal games 1 and 2 are clear; after normal game 3 and then every 3 completed normal games, an ad may appear only when the player leaves Results and at least 2 minutes have passed since the previous shown ad. Daily Challenge never triggers an interstitial. Missing or failed ads continue navigation immediately. Remove Ads ownership disables interstitials.

`lib/monetization/ad_service.dart` owns AdMob and UMP. At launch UMP updates consent, displays a required form, and ads are requested only if `canRequestAds()` allows them. The global Google Mobile Ads request configuration is set to `MaxAdContentRating.g` before SDK initialization. Settings exposes Privacy choices if UMP requires an entry point. Debug Android/iOS builds use Google's official sample app and ad-unit IDs. Release IDs are empty by default and ads remain disabled until configured. Rewarded ads unlock free users' Daily retries only after the reward callback; they do not change XP.

`lib/monetization/purchase_service.dart` owns the non-consumable `brain_rush_remove_ads`. It loads the store's localized price and listens for purchase and restore transactions. Ownership is rechecked through store restoration on each launch, without a locally trusted premium flag. Store callbacks provide the entitlement; the ranking backend does not validate purchase receipts. The game opens before store initialization completes.

### Physical-device interstitial testing

Run a **debug** build to use the official test ad units, including on a physical iPhone. Completing normal game 3 makes an interstitial eligible; simply arriving at Results does not display one. Tap **Play Again** or **Home** to attempt presentation. The first ad has no cooldown wait. Counts and the previous shown-ad state persist across launches; a skipped or failed ad does not consume eligibility or start the cooldown.

Watch the Flutter console for `[BrainRush Ads]` debug-only messages: consent update/errors and `canRequestAds`, G configuration and SDK initialization, load start/success/errors, completed normal-game count, Results eligibility and suppression reason, and presentation/dismissal/errors. If an ad is still loading, navigation continues and the next eligible Results exit can use it. If loading failed, an eligible exit starts another preload and continues navigation. Remove Ads ownership is reported as a suppression reason. No player identifiers or answer/score data are logged.

Consent initialization runs asynchronously and allows slow UMP updates to finish. Ads remain gated by the UMP SDK's `canRequestAds()` result, including its cached consent decision when an update fails; see [Google's UMP guidance](https://developers.google.com/admob/flutter/privacy). A test ad unit does not bypass this consent gate. If the console reports a consent configuration error, inspect the privacy message associated with the native AdMob app ID; do not force permission in Flutter.

### Production configuration still required

1. In **AdMob**, create one Android app and one iOS app, with interstitial and rewarded units for each. Create and publish the UMP privacy message, and check regional consent settings.
2. Put the **Android AdMob App ID** in `android/app/src/release/AndroidManifest.xml` as `com.google.android.gms.ads.APPLICATION_ID`, and remove its `MobileAdsInitProvider` removal entry. Put the same ID in the `ANDROID_ADMOB_APP_ID` Dart define. A release build with no ID keeps ads disabled; the release manifest currently removes the provider to avoid a startup crash. Keep the debug manifest's official sample ID unchanged.
3. Put the **iOS AdMob App ID** in `ios/Flutter/Release.xcconfig` as `ADMOB_APP_ID`, and the same ID in the `IOS_ADMOB_APP_ID` Dart define. The Info.plist reads that build setting. Keep the debug xcconfig's sample ID unchanged.
4. Supply `ANDROID_INTERSTITIAL_AD_UNIT_ID`, `IOS_INTERSTITIAL_AD_UNIT_ID`, `ANDROID_REWARDED_AD_UNIT_ID`, and `IOS_REWARDED_AD_UNIT_ID` as Dart defines for release builds. These names are read in `lib/monetization/ad_service.dart`; never put production IDs into gameplay code. An absent rewarded unit ID leaves a free Daily retry unavailable until the unit is configured.
5. In **App Store Connect**, create a non-consumable in-app purchase with product ID `brain_rush_remove_ads`, localized name/description and price, and configure paid apps agreements/tax/banking and sandbox testers. In **Google Play Console**, create and activate a one-time in-app product with the same product ID, localized listing and price, and configure license testers. The product ID is in `lib/monetization/purchase_service.dart`.
6. Before publishing, provide a real Privacy Policy and Terms, declare Google Mobile Ads and IAP data use in App Store privacy and Google Play Data Safety forms, configure the applicable iOS SKAdNetwork IDs, and verify consent and purchase flows on physical devices. The in-app legal text is preliminary. No ATT prompt is requested by this app.

### AdMob blocking controls for V1

Set **Maximum ad content rating** to **G** in the AdMob dashboard as well as retaining the in-app G request configuration.

Use AdMob Blocking Controls to review and block sensitive categories, especially References to Sex & Sexuality, Dating, Gambling / Social Casino, Alcohol, and other adult or sensitive categories available for this account. Also block unwanted non-game general categories where they are available, including Music/Audio and related entertainment categories.

AdMob does not provide a reliable “games only” guarantee. Google classifies categories automatically, so filtering is best-effort. Periodically inspect the Ad Review Center and manually block unwanted creatives, advertisers, or destination URLs.

## Anonymous Daily ranking

Ranking is optional. `lib/backend/daily_ranking_service.dart` keeps a random UUIDv4 in SharedPreferences under `brain_rush_installation_id`; it uses no hardware, advertising, account, or contact identifier. Clearing app data or reinstalling may create a new identity. A completed Daily game saves attempts, best score, the attempt that achieved that best, and XP locally first. The ranking controller then submits only a best score that has not already synced, with its actual completed attempt number, and fetches a fresh rank. Opening Daily again refreshes rank without resubmitting the same score; after a failed submission it retries the unsynced local best. Network calls time out, and any failure affects only the rank display. Rush and abandoned games never submit. There is no public leaderboard or backend name/profile; the optional display name is local only.

The first migration, `supabase/migrations/20261002000100_daily_ranking.sql`, creates `public.daily_scores` with one row per `(challenge_date, installation_id)`. The second migration, `supabase/migrations/20261002000200_daily_ranking_best_attempt.sql`, adds `best_attempt_no smallint`, restricts it to 1–3, and replaces the ranking index with `(challenge_date, best_score desc, best_attempt_no asc)`. Existing rows are backfilled to attempt **3**, because their actual best attempt is unknown; claiming attempt 1 would unfairly improve their rank. Old local save snapshots use the same conservative default. The old three-argument submit RPC is removed, and `public.submit_daily_score(uuid,date,integer,integer)` stores both fields in one transactional upsert **only when the submitted score is higher**. Equal and lower scores keep the earlier stored score and attempt. The third migration, `supabase/migrations/20261004000100_daily_rank_highest_score.sql`, changes the rank RPC return shape to include `highest_score`, calculated as `max(best_score)` for the challenge date. The rank RPC remains `public.get_daily_rank(uuid,date)` and returns `best_score`, `highest_score`, `rank`, `participant_count`, and `top_percent`; the app presents rank and scores but hides count and percentile. Rank is `1 + count(higher score OR equal score with fewer attempts)`, so equal scores achieved on the same attempt share rank. Dates within one day of the current UTC date are accepted because the game uses local dates. Score validation accepts 0–736: the 60-second game allows at most 188 answers with a minimum 320 ms advance gap, and its streak multiplier tops out at four points.

RLS is enabled on the table, with no client-facing policies; direct table privileges are revoked from `anon` and `authenticated`. Both `SECURITY DEFINER` RPCs use a fixed empty `search_path` and schema-qualified table names. Only `anon` receives `EXECUTE` on the RPCs. The app uses a Supabase public/anon key, **never** a service-role key. This limits the exposed database operations, but an anonymous UUID cannot prove installation ownership and a modified client can still submit fabricated scores within the accepted range or create more UUIDs.

No Supabase project is linked in this repository. To set up or upgrade a project:

1. Use the Brain Rush Supabase project in the dashboard. The production URL and public anon key are embedded in `lib/backend/supabase_config.dart`; do not put a service-role key in the app.
2. For a fresh project, apply **all three** migrations in filename order. For the existing Brain Rush project with the first two already applied, apply **only** `20261004000100_daily_rank_highest_score.sql` in the project's SQL Editor before running an app build that expects `highest_score`. If using CLI migration tracking, initialize/link with `supabase init`, `supabase login`, `supabase link --project-ref <PROJECT_REF>`, inspect `supabase db push --dry-run`, then run `supabase db push` only when its migration history correctly records any migration already applied. Do not replay applied migrations or use `supabase db reset --linked` on a live project.
3. On a fresh disposable test project after all three migrations, run `supabase/tests/daily_ranking.sql` in the SQL Editor. It checks score/attempt upserts, score and attempt tie breaks, global high score, response fields, rank/count/percentage, invalid attempts/dates/scores, and grants, then rolls back its test rows.
4. Run the app normally: no Supabase Dart defines are required. `SUPABASE_URL` and `SUPABASE_ANON_KEY` remain optional overrides for development/testing. If the configured backend is unreachable, the app shows “Ranking unavailable” and continues locally. Test a completed Daily game, a lower and higher retry, returning to Daily to refresh rank, offline behavior, and Rush/abandoned games.

For a **future** Android release build, retain the existing ad configuration; Supabase defines are not needed:

```sh
flutter build appbundle --release \
  --dart-define=ANDROID_ADMOB_APP_ID=YOUR_ANDROID_APP_ID \
  --dart-define=ANDROID_INTERSTITIAL_AD_UNIT_ID=YOUR_INTERSTITIAL_UNIT_ID \
  --dart-define=ANDROID_REWARDED_AD_UNIT_ID=YOUR_REWARDED_UNIT_ID
```

The native Android AdMob app ID and release signing configuration must already be set as documented above. This ranking change does not change the app version or deploy the migration.

## Release work

The ads plugin is pinned to the published `google_mobile_ads` **9.0.0** release, with its supported iOS Google Mobile Ads SDK **13.3.0** and UMP **3.1.0**. Version 9.1.0 adds preloading headers that import the native SDK's private `GoogleMobileAds_Beta.h`; with this project's CocoaPods framework integration, Xcode rejects those imports as non-modular headers. Brain Rush uses regular interstitial loading and does not require the new preloader APIs. Keep the exact pin until an upstream compatible release is verified; do not patch the pub cache or enable non-modular header exceptions. After changing this dependency, run `flutter clean`, `flutter pub get`, then `pod update google_mobile_ads Google-Mobile-Ads-SDK --no-repo-update --clean-install` from `ios` before rebuilding.

Review identifiers, signing, store metadata, final legal documents, and device accessibility before store submission. Test physical iOS/Android devices for haptic intensity and OS-specific lifecycle behavior. The browser preview is for review; gameplay remains playable offline on native devices.

On this Mac, cloud-folder metadata in Documents interfered with iOS framework signing. Compiling a copy in `/private/tmp` resolved the issue. If it recurs, copy the source (excluding `build`, `.dart_tool`, and `ios/Pods`) into a non-cloud folder before building. Do not change application code to work around this filesystem issue.
