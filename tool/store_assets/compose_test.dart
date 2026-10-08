import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _boundaryKey = Key('store-ready-boundary');
const _background = Color(0xFF070F20);
const _cyan = Color(0xFF6FE7F4);
const _violet = Color(0xFFAFA5FF);

class _DeviceSpec {
  const _DeviceSpec(this.platform, this.name, this.width, this.height);
  final String platform;
  final String name;
  final int width;
  final int height;
}

const _devices = <_DeviceSpec>[
  _DeviceSpec('ios', 'iphone', 1320, 2868),
  _DeviceSpec('ios', 'ipad', 2064, 2752),
  _DeviceSpec('android', 'phone', 1344, 2992),
  _DeviceSpec('android', 'tablet_7', 1200, 1920),
  _DeviceSpec('android', 'tablet_10', 1600, 2560),
];

const _files = <String>[
  '01_home.png',
  '02_gameplay.png',
  '03_challenges.png',
  '04_daily.png',
  '05_ranking.png',
  '06_results.png',
];

const _englishCaptions = <String>[
  'Think Fast. Beat 60 Seconds.',
  'Every Second Counts',
  'A New Mental Challenge Every Round',
  'Take the Daily Challenge',
  'Climb the Daily Ranking',
  'Improve With Every Run',
];

const _arabicCaptions = <String>[
  'فكّر بسرعة. أمامك 60 ثانية.',
  'كل ثانية تصنع الفرق',
  'تحدٍّ ذهني جديد في كل جولة',
  'خض تحدي اليوم',
  'تقدّم في ترتيب اليوم',
  'تطوّر مع كل جولة',
];

Future<ByteData> _fontData(String path) async {
  final bytes = await File(path).readAsBytes();
  return ByteData.view(Uint8List.fromList(bytes).buffer);
}

Future<void> _loadCaptureFonts() async {
  final loader = FontLoader('Arial')
    ..addFont(_fontData('/System/Library/Fonts/Supplemental/Arial.ttf'))
    ..addFont(_fontData('/System/Library/Fonts/Supplemental/Arial Bold.ttf'))
    ..addFont(
      _fontData('/System/Library/Fonts/Supplemental/Arial Unicode.ttf'),
    );
  await loader.load();
}

Widget _glow(double size, Color color) => Container(
  width: size,
  height: size,
  decoration: BoxDecoration(
    shape: BoxShape.circle,
    color: color.withValues(alpha: .13),
    boxShadow: [
      BoxShadow(
        color: color.withValues(alpha: .18),
        blurRadius: size * .42,
        spreadRadius: size * .08,
      ),
    ],
  ),
);

Widget _storeComposition({
  required ui.Image screenshot,
  required String locale,
  required String caption,
  required double width,
  required double height,
}) {
  final rtl = locale == 'ar';
  final screenWidth = width * .83;
  final screenHeight = height * .83;
  return Directionality(
    textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
    child: MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: Material(
        color: _background,
        child: SizedBox(
          width: width,
          height: height,
          child: Stack(
            children: [
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _background,
                        Color(0xFF10233D),
                        Color(0xFF17163D),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: -width * .08,
                top: height * .03,
                child: _glow(width * .28, _cyan),
              ),
              Positioned(
                right: -width * .08,
                top: height * .08,
                child: _glow(width * .25, _violet),
              ),
              Positioned(
                left: width * .07,
                right: width * .07,
                top: height * .025,
                child: Column(
                  children: [
                    Text(
                      rtl ? 'تحدي العقل' : 'BRAIN RUSH',
                      style: TextStyle(
                        fontFamily: 'Arial',
                        color: _cyan,
                        fontWeight: FontWeight.w700,
                        fontSize: width * .027,
                        letterSpacing: rtl ? 0 : width * .0025,
                      ),
                    ),
                    SizedBox(height: height * .009),
                    Text(
                      caption,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Arial',
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: width * .052,
                        height: 1.08,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: (width - screenWidth) / 2,
                top: height * .145,
                width: screenWidth,
                height: screenHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(width * .045),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .55),
                        blurRadius: width * .045,
                        offset: Offset(0, width * .018),
                      ),
                      BoxShadow(
                        color: _cyan.withValues(alpha: .12),
                        blurRadius: width * .045,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(width * .045),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _cyan.withValues(alpha: .42),
                          width: width * .002,
                        ),
                      ),
                      child: RawImage(image: screenshot, fit: BoxFit.fill),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _featureComposition({
  required String locale,
  required ui.Image home,
  required ui.Image gameplay,
  required ui.Image logo,
  required double width,
  required double height,
}) {
  final rtl = locale == 'ar';
  final title = rtl ? 'تحدي العقل' : 'BRAIN RUSH';
  final tagline = rtl
      ? 'فكّر بسرعة.\nأمامك 60 ثانية.'
      : 'Think Fast.\nBeat 60 Seconds.';
  final textSide = rtl ? Alignment.centerRight : Alignment.centerLeft;
  final panelsSide = rtl ? Alignment.centerLeft : Alignment.centerRight;
  return Directionality(
    textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
    child: Material(
      color: _background,
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          children: [
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_background, Color(0xFF10233D), Color(0xFF211B4C)],
                  ),
                ),
              ),
            ),
            Positioned(
              left: width * .31,
              top: -height * .45,
              child: _glow(width * .48, _cyan),
            ),
            Positioned(
              right: -width * .12,
              bottom: -height * .32,
              child: _glow(width * .42, _violet),
            ),
            Align(
              alignment: textSide,
              child: SizedBox(
                width: width * .47,
                child: Padding(
                  padding: EdgeInsetsDirectional.only(
                    start: width * .065,
                    end: width * .02,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: rtl
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: width * .065,
                        height: width * .065,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(width * .016),
                          boxShadow: [
                            BoxShadow(
                              color: _cyan.withValues(alpha: .35),
                              blurRadius: width * .025,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(width * .016),
                          child: RawImage(image: logo, fit: BoxFit.cover),
                        ),
                      ),
                      SizedBox(height: height * .035),
                      Text(
                        title,
                        style: TextStyle(
                          fontFamily: 'Arial',
                          color: _cyan,
                          fontWeight: FontWeight.w800,
                          fontSize: width * .032,
                          letterSpacing: rtl ? 0 : width * .003,
                        ),
                      ),
                      SizedBox(height: height * .018),
                      Text(
                        tagline,
                        style: TextStyle(
                          fontFamily: 'Arial',
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: width * .053,
                          height: 1.05,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Align(
              alignment: panelsSide,
              child: SizedBox(
                width: width * .51,
                child: Stack(
                  children: [
                    PositionedDirectional(
                      start: width * .015,
                      top: height * .14,
                      width: width * .19,
                      height: height * .68,
                      child: _screenPanel(home, width * .02),
                    ),
                    PositionedDirectional(
                      end: width * .045,
                      top: height * .055,
                      width: width * .255,
                      height: height * .89,
                      child: _screenPanel(gameplay, width * .025),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _screenPanel(ui.Image image, double radius) => DecoratedBox(
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(radius),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: .55),
        blurRadius: radius * 1.4,
      ),
    ],
    border: Border.all(color: _cyan.withValues(alpha: .5), width: 2),
  ),
  child: ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: RawImage(
      image: image,
      fit: BoxFit.cover,
      alignment: Alignment.topCenter,
    ),
  ),
);

Future<ui.Image> _decodeFile(String path) async {
  final bytes = await File(path).readAsBytes();
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}

Future<void> _render(
  WidgetTester tester, {
  required Widget child,
  required int width,
  required int height,
  required String output,
}) async {
  await tester.binding.setSurfaceSize(
    Size(width.toDouble(), height.toDouble()),
  );
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(RepaintBoundary(key: _boundaryKey, child: child));
  await tester.pump();
  await tester.pumpAndSettle(const Duration(milliseconds: 50));
  await expectLater(
    find.byKey(_boundaryKey),
    matchesGoldenFile('../../$output'),
  );
  await tester.pumpWidget(const SizedBox.shrink());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadCaptureFonts);
  const deviceFilter = String.fromEnvironment('STORE_DEVICE_FILTER');
  const localeFilter = String.fromEnvironment('STORE_LOCALE_FILTER');

  testWidgets('composes store-ready screenshots from real app captures', (
    tester,
  ) async {
    for (final device in _devices) {
      if (deviceFilter.isNotEmpty && device.name != deviceFilter) continue;
      for (final locale in const ['en', 'ar']) {
        if (localeFilter.isNotEmpty && locale != localeFilter) continue;
        final captions = locale == 'ar' ? _arabicCaptions : _englishCaptions;
        for (var index = 0; index < _files.length; index++) {
          final input = (await tester.runAsync(
            () => _decodeFile(
              'store_assets/source_capture/${device.platform}/$locale/${device.name}/${_files[index]}',
            ),
          ))!;
          await _render(
            tester,
            child: _storeComposition(
              screenshot: input,
              locale: locale,
              caption: captions[index],
              width: device.width.toDouble(),
              height: device.height.toDouble(),
            ),
            width: device.width,
            height: device.height,
            output:
                'store_assets/final/${device.platform}/$locale/${device.name}/${_files[index]}',
          );
          input.dispose();
        }
      }
    }
  });

  testWidgets('creates feature graphics and preview artwork', (tester) async {
    for (final locale in const ['en', 'ar']) {
      if (localeFilter.isNotEmpty && locale != localeFilter) continue;
      final rawRoot = 'store_assets/source_capture/android/$locale/phone';
      final home = (await tester.runAsync(
        () => _decodeFile('$rawRoot/01_home.png'),
      ))!;
      final gameplay = (await tester.runAsync(
        () => _decodeFile('$rawRoot/02_gameplay.png'),
      ))!;
      final logo = (await tester.runAsync(
        () => _decodeFile(
          'ios/Runner/Assets.xcassets/AppIcon.appiconset/Rush-Icon-App-1024x1024@1x.png',
        ),
      ))!;
      await _render(
        tester,
        child: _featureComposition(
          locale: locale,
          home: home,
          gameplay: gameplay,
          logo: logo,
          width: 1024,
          height: 500,
        ),
        width: 1024,
        height: 500,
        output: 'store_assets/final/android/feature_graphic_$locale.png',
      );

      final iphoneGameplay = (await tester.runAsync(
        () =>
            _decodeFile(
              'store_assets/source_capture/ios/$locale/iphone/02_gameplay.png',
            ),
      ))!;
      await _render(
        tester,
        child: _storeComposition(
          screenshot: iphoneGameplay,
          locale: locale,
          caption: locale == 'ar' ? _arabicCaptions[1] : _englishCaptions[1],
          width: 886,
          height: 1920,
        ),
        width: 886,
        height: 1920,
        output: 'store_assets/final/video/poster_$locale.png',
      );

      await _render(
        tester,
        child: _featureComposition(
          locale: locale,
          home: home,
          gameplay: gameplay,
          logo: logo,
          width: 1280,
          height: 720,
        ),
        width: 1280,
        height: 720,
        output: 'store_assets/final/video/youtube_thumbnail_$locale.png',
      );
      home.dispose();
      gameplay.dispose();
      logo.dispose();
      iphoneGameplay.dispose();
    }
  });
}
