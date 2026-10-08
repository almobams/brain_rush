import 'package:brain_rush/screens/results_screen.dart';
import 'package:brain_rush/screens/secondary_screens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../tool/store_assets/capture_app.dart' as capture;

Future<void> waitForDeviceFrame(WidgetTester tester, Duration duration) async {
  await tester.runAsync(() => Future<void>.delayed(duration));
  await tester.pump();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const locale = String.fromEnvironment(
    'STORE_CAPTURE_LOCALE',
    defaultValue: 'en',
  );

  testWidgets('records genuine Brain Rush navigation and gameplay', (
    tester,
  ) async {
    await tester.pumpWidget(await capture.buildCaptureApp('/$locale/video'));
    await tester.pump();
    await waitForDeviceFrame(tester, const Duration(seconds: 2));

    final start = find.text(locale == 'ar' ? 'ابدأ التحدي' : 'START RUSH');
    expect(start, findsOneWidget);
    await tester.tap(start);
    await tester.pump(const Duration(milliseconds: 100));
    await waitForDeviceFrame(tester, const Duration(seconds: 1));

    // The first deterministic question is 8 × 7. This is a real UI tap.
    final correctFirstAnswer = find.text('56');
    expect(correctFirstAnswer, findsOneWidget);
    await tester.tap(correctFirstAnswer);
    await tester.pump();

    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    final answerPoints = <Offset>[
      Offset(size.width * .25, size.height * .71),
      Offset(size.width * .75, size.height * .71),
      Offset(size.width * .25, size.height * .82),
      Offset(size.width * .75, size.height * .82),
    ];
    for (var index = 0; index < 7; index++) {
      await waitForDeviceFrame(tester, const Duration(milliseconds: 650));
      await tester.tapAt(answerPoints[index % answerPoints.length]);
      await tester.pump();
    }

    for (var frame = 0; frame < 20; frame++) {
      await waitForDeviceFrame(tester, const Duration(milliseconds: 300));
      if (find.byType(ResultsScreen).evaluate().isNotEmpty) break;
    }
    expect(find.byType(ResultsScreen), findsOneWidget);
    final daily = find.text(
      locale == 'ar' ? 'التحدي اليومي' : 'Daily Challenge',
    );
    expect(daily, findsWidgets);
    await tester.tap(daily.last);
    await tester.pump(const Duration(milliseconds: 100));
    await waitForDeviceFrame(tester, const Duration(seconds: 4));
    expect(find.byType(DailyScreen), findsOneWidget);
  });
}
