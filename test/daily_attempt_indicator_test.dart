import 'package:brain_rush/theme/app_theme.dart';
import 'package:brain_rush/widgets/daily_attempt_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (var used = 0; used <= 3; used++) {
    testWidgets('attempt indicator shows $used/3 filled segments in Arabic', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ar'),
          supportedLocales: const [Locale('en'), Locale('ar')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: appTheme(Brightness.dark),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 180,
                child: DailyAttemptIndicator(attemptsUsed: used),
              ),
            ),
          ),
        ),
      );
      expect(find.text('$used/3'), findsOneWidget);
      final direction = tester.widget<Directionality>(
        find
            .ancestor(
              of: find.byKey(const Key('dailyAttemptFraction')),
              matching: find.byType(Directionality),
            )
            .first,
      );
      expect(direction.textDirection, TextDirection.ltr);
      for (var index = 0; index < 3; index++) {
        final segment = tester.widget<Container>(
          find.byKey(Key('dailyAttemptSegment$index')),
        );
        final color = (segment.decoration! as BoxDecoration).color;
        if (index < used) {
          expect(color, index.isEven ? energyCyan : violet);
        } else {
          expect(color, isNot(anyOf(energyCyan, violet)));
        }
      }
      expect(tester.takeException(), isNull);
    });
  }
}
