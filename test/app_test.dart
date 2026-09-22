import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:brain_rush/main.dart';
import 'package:brain_rush/core/store.dart';
import 'package:brain_rush/game/controller.dart';
import 'package:brain_rush/game/generators.dart';
import 'package:brain_rush/game/models.dart';
import 'package:brain_rush/game/progression.dart';
import 'package:brain_rush/screens/game_screen.dart';
import 'package:brain_rush/screens/results_screen.dart';
import 'package:brain_rush/screens/secondary_screens.dart';
import 'package:brain_rush/widgets/components.dart';
import 'package:brain_rush/localization/strings.dart';

void main() {
  test('English and Arabic have identical localization coverage', () {
    expect(Strings.en.keys.toSet(), Strings.ar.keys.toSet());
    for (final key in [
      'rankWarmUp',
      'rankQuickThinker',
      'rankSharpMind',
      'rankBrainRacer',
      'rankLightningMind',
      'rankBrainMaster',
      'levelUp',
      'newRank',
      'secondsShort',
      'fastAnswers',
    ]) {
      expect(Strings('ar').t(key), isNot(key));
    }
  });
  for (final language in ['en', 'ar']) {
    testWidgets('$language compact home shows Start without scrolling', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [preferencesProvider.overrideWithValue(prefs)],
      );
      container.read(storeProvider).language = language;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const BrainRushApp(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      final start = find.widgetWithText(
        GamePrimaryButton,
        Strings(language).t('start'),
      );
      expect(start, findsOneWidget);
      expect(tester.getBottomRight(start).dy, lessThanOrEqualTo(568));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });

    testWidgets('$language compact results show Play Again and XP', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [preferencesProvider.overrideWithValue(prefs)],
      );
      container.read(storeProvider).language = language;
      final date = DateTime(2026, 9, 21);
      final session = GameSession(
        id: 'test',
        mode: GameMode.rush,
        startedAt: date,
        endedAt: date.add(const Duration(seconds: 60)),
        score: 12,
        bestStreak: 4,
        results: const [],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: Locale(language),
            supportedLocales: const [Locale('en'), Locale('ar')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: ResultsScreen(
              session: session,
              award: const ProgressAward(
                earnedXp: 40,
                previousXp: 65,
                totalXp: 105,
                isNewBest: true,
                previousBest: 8,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 800));
      final again = find.widgetWithText(
        GamePrimaryButton,
        Strings(language).t('again'),
      );
      expect(again, findsOneWidget);
      await tester.ensureVisible(again);
      await tester.pump();
      expect(tester.getBottomRight(again).dy, lessThanOrEqualTo(568));
      expect(find.textContaining(Strings(language).t('xp')), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });

    testWidgets('$language fraction layout stays responsive and ordered', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          preferencesProvider.overrideWithValue(prefs),
          gameFactoryProvider.overrideWithValue((mode) {
            final game = GameController(mode: mode);
            game.question = const FractionGenerator(chooseLarger: true)
                .generate(Random(3), 2, 'fraction-layout');
            return game;
          }),
        ],
      );
      container.read(storeProvider).language = language;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const BrainRushApp(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      final start = find.widgetWithText(
        GamePrimaryButton,
        Strings(language).t('start'),
      );
      await tester.ensureVisible(start);
      await tester.tap(start);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(AnswerButton), findsNWidgets(2));
      await tester.ensureVisible(find.byType(AnswerButton).last);
      await tester.pump();
      expect(
        tester.getBottomRight(find.byType(AnswerButton).last).dy,
        lessThanOrEqualTo(568),
      );
      final firstButton = tester.widget<AnswerButton>(
        find.byType(AnswerButton).first,
      );
      final label = firstButton.value.label;
      final numerator = find.byKey(ValueKey('fraction-numerator-$label'));
      final denominator = find.byKey(ValueKey('fraction-denominator-$label'));
      expect(numerator, findsOneWidget);
      expect(denominator, findsOneWidget);
      expect(
        Directionality.of(tester.element(numerator)),
        TextDirection.ltr,
        reason: 'RTL must not reverse numerator and denominator order.',
      );
      expect(
        tester.getCenter(numerator).dy,
        lessThan(tester.getCenter(denominator).dy),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });

    testWidgets('$language small phone completes a rush and saves results', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      var elapsed = Duration.zero;
      final container = ProviderContainer(
        overrides: [
          preferencesProvider.overrideWithValue(prefs),
          gameFactoryProvider.overrideWithValue(
            (mode) => GameController(mode: mode, elapsed: () => elapsed),
          ),
        ],
      );
      container.read(storeProvider).language = language;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const BrainRushApp(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      final start = find.widgetWithText(
        GamePrimaryButton,
        Strings(language).t('start'),
      );
      await tester.ensureVisible(start);
      await tester.tap(start);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        Directionality.of(tester.element(find.byType(GameTimer))),
        language == 'ar' ? TextDirection.rtl : TextDirection.ltr,
      );
      for (var i = 0; i < 8; i++) {
        final answer = find.byType(AnswerButton).first;
        await tester.ensureVisible(answer);
        elapsed += const Duration(seconds: 2);
        await tester.tap(answer);
        await tester.pump();
        elapsed += const Duration(milliseconds: 400);
        await tester.pump(const Duration(milliseconds: 400));
        expect(tester.takeException(), isNull);
      }
      elapsed = const Duration(seconds: 60);
      await tester.pump(const Duration(milliseconds: 80));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text(Strings(language).t('timesUp')), findsOneWidget);
      expect(container.read(storeProvider).stats.totalGames, 1);
      expect(
        container.read(storeProvider).stats.totalCorrect +
            container.read(storeProvider).stats.totalWrong,
        8,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });
    testWidgets(
      '$language secondary screens support large text on small phones',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final container = ProviderContainer(
          overrides: [preferencesProvider.overrideWithValue(prefs)],
        );
        container.read(storeProvider).language = language;
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const BrainRushApp(),
          ),
        );
        await tester.pump();
        final context = tester.element(find.byType(RushScaffold));
        for (final screen in [
          const StatisticsScreen(),
          const SettingsScreen(),
          const DailyScreen(),
        ]) {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(1.8)),
                child: screen,
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          expect(tester.takeException(), isNull);
          Navigator.of(context).pop();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
        }
        await tester.pumpWidget(const SizedBox());
        container.dispose();
      },
    );
  }
  testWidgets('Expiry dismisses an open exit dialog and saves exactly once', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    var elapsed = Duration.zero;
    final container = ProviderContainer(
      overrides: [
        preferencesProvider.overrideWithValue(prefs),
        gameFactoryProvider.overrideWithValue(
          (mode) => GameController(mode: mode, elapsed: () => elapsed),
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const BrainRushApp(),
      ),
    );
    await tester.pump();
    final start = find.widgetWithText(GamePrimaryButton, 'START RUSH');
    await tester.ensureVisible(start);
    await tester.tap(start);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byTooltip('LEAVE RUSH'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(AlertDialog), findsOneWidget);
    elapsed = const Duration(seconds: 60);
    await tester.pump(const Duration(milliseconds: 80));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('TIME’S UP!'), findsOneWidget);
    expect(container.read(storeProvider).stats.totalGames, 1);
    await tester.pump(const Duration(seconds: 2));
    expect(container.read(storeProvider).stats.totalGames, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });
}
