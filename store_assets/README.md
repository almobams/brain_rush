# Brain Rush store assets

This package separates untouched native framebuffer captures from composed marketing exports:

- `source_capture/` contains screenshots and videos recorded from the running Brain Rush app on Android Emulators and iOS Simulators.
- `final/` contains store-ready compositions and edited preview videos derived from those native sources.
- `metadata/` contains screenshot provenance and accessibility copy.

No screenshot in `source_capture/` was produced by a widget test, golden renderer, HTML, Canvas recreation, or off-screen Flutter renderer.

## Native capture inventory

Each localized device directory contains six untouched source screenshots:

1. `01_home.png`
2. `02_gameplay.png`
3. `03_challenges.png`
4. `04_daily.png`
5. `05_ranking.png`
6. `06_results.png`

| Platform | Device | Runtime | Source dimensions | Locales | Source files |
|---|---|---|---:|---|---:|
| Android | Pixel_8_Pro_API_36 | Android 16, API 36 | 1344 × 2992 | English, Arabic RTL | 12 |
| Android | Brain_Rush_7in_API_36, Nexus 7 2013 profile | Android 16, API 36 | 1200 × 1920 | English, Arabic RTL | 12 |
| Android | Pixel_Tablet_API_36 | Android 16, API 36 | 1600 × 2560 | English, Arabic RTL | 12 |
| iOS | iPhone 17 Pro Max | iOS 26.5 | 1320 × 2868 | English, Arabic RTL | 12 |
| iOS | Brain Rush iPad Pro 13, iPad Pro 13-inch M4 | iOS 18.4 | 2064 × 2752 | English, Arabic RTL | 12 |

Total native screenshots: **60**.

Every source PNG has a neighboring `.metadata.json` sidecar with the platform, device name, device ID, OS version, locale, exact capture command, file timestamp, and native pixel dimensions. The combined manifest is `metadata/source_captures.json`.

## Native screenshot commands

Android screenshots were read from the active emulator framebuffer:

```sh
adb -s emulator-5554 exec-out screencap -p > store_assets/source_capture/android/<locale>/<device>/<file>.png
```

iOS screenshots were read from the named Simulator framebuffer:

```sh
xcrun simctl io 44A0E9FB-E409-4956-90C2-4D8A16784230 screenshot store_assets/source_capture/ios/<locale>/iphone/<file>.png
xcrun simctl io E04D3A2B-A690-43F5-B56F-B8F262A6B9E4 screenshot store_assets/source_capture/ios/<locale>/ipad/<file>.png
```

## Genuine preview recordings

Android source footage was captured with the system recorder while ADB taps navigated the installed app:

```sh
adb shell screenrecord --size 720x1600 --bit-rate 8000000 --time-limit <seconds> /sdcard/brain_rush_<locale>.mp4
adb pull /sdcard/brain_rush_<locale>.mp4 store_assets/source_capture/video/android/<locale>/
```

iPhone source footage was captured by Simulator while `integration_test/store_preview_test.dart` tapped the live app:

```sh
xcrun simctl io 44A0E9FB-E409-4956-90C2-4D8A16784230 recordVideo --codec=h264 store_assets/source_capture/video/ios/<locale>/brain_rush_raw.mov
flutter test integration_test/store_preview_test.dart -d 44A0E9FB-E409-4956-90C2-4D8A16784230 --dart-define=STORE_CAPTURE=true --dart-define=STORE_CAPTURE_LOCALE=<locale>
```

The final videos contain real Home, button taps, live Rush questions, score and timer changes, Results, and Daily ranking. FFmpeg only trims build/idle time, accelerates the long Android countdown, resizes, normalizes to 30 fps, and holds the final recorded Daily frame. There is no music and no screenshot sequence.

| Final video | Resolution | Duration | Codec | Audio |
|---|---:|---:|---|---|
| `final/video/brain_rush_preview_en.mp4` | 1080 × 2400 | 21 s | H.264, yuv420p, 30 fps | none |
| `final/video/brain_rush_preview_ar.mp4` | 1080 × 2400 | 21 s | H.264, yuv420p, 30 fps | none |
| `final/video/brain_rush_appstore_preview_en.mp4` | 886 × 1920 | 21 s | H.264, yuv420p, 30 fps | none |
| `final/video/brain_rush_appstore_preview_ar.mp4` | 886 × 1920 | 21 s | H.264, yuv420p, 30 fps | none |

## Capture-mode safety

`tool/store_assets/capture_app.dart` is a development-only entry point. It:

- throws in release mode or when `STORE_CAPTURE=true` is absent;
- is not imported by `lib/main.dart`;
- feeds deterministic questions, score, XP, personal best, and Daily ranking into the production screens;
- uses in-memory preferences;
- supplies no-op ads and purchases;
- supplies a no-network ranking service;
- performs no Supabase submission or production ranking mutation;
- hides the debug banner and developer labels.

The Android profile manifest uses Google's sample AdMob application ID so the profile-only capture build can launch. Release configuration is unaffected.

## App icon fix

The empty squares came from Material icon-font glyphs used by the previous headless marketing renderer. The final compositions load the existing project artwork directly:

`ios/Runner/Assets.xcassets/AppIcon.appiconset/Rush-Icon-App-1024x1024@1x.png`

The inspection sheet `final/contact_sheet_icon_verification.png` shows the source icon, feature graphic, screenshot 1, poster, and YouTube thumbnail. It verifies that the real icon appears where intended.

## Final marketing assets

- 60 localized screenshots under `final/ios/` and `final/android/`.
- English and Arabic Google Play feature graphics under `final/android/`.
- English and Arabic posters and YouTube thumbnails under `final/video/`.
- Four genuine preview videos under `final/video/`.
- Icon verification sheet at `final/contact_sheet_icon_verification.png`.
- Google Play accessibility copy at `metadata/alt_text.json`.

Marketing screenshots place the corresponding genuine device capture inside the branded composition. The app UI inside each capture is unchanged.

## Regeneration and validation

`generate.sh` does not recapture devices. It requires the 60 native source screenshots and genuine raw video files to exist, then rebuilds only derived assets:

```sh
tool/store_assets/generate.sh
```

Useful partial commands:

```sh
flutter test tool/store_assets/compose_test.dart --update-goldens
tool/store_assets/generate_videos.sh
tool/store_assets/validate.sh
```

Validation checks source and final counts, every PNG dimension, opaque final PNGs, metadata sidecars, the real 1024px icon, native recording dimensions/codecs, and final video dimensions, H.264 codec, yuv420p pixel format, 30 fps rate, 21-second duration, and absence of audio.
