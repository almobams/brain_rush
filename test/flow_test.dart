import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:brain_rush/main.dart';
import 'package:brain_rush/core/store.dart';
import 'package:brain_rush/game/controller.dart';
import 'package:brain_rush/game/models.dart';
import 'package:brain_rush/localization/strings.dart';
import 'package:brain_rush/screens/game_screen.dart';
import 'package:brain_rush/widgets/components.dart';
import 'package:brain_rush/widgets/effects.dart';

void main() {
  for (final language in ['en', 'ar']) {
    testWidgets(
      '$language daily, streak, results, replay, settings and cold restart',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({});
        var elapsed = Duration.zero;
        late GameController active;
        final prefs = await SharedPreferences.getInstance();
        var container = ProviderContainer(
          overrides: [
            preferencesProvider.overrideWithValue(prefs),
            gameFactoryProvider.overrideWithValue((mode) {
              elapsed = Duration.zero;
              active = GameController(mode: mode, elapsed: () => elapsed);
              return active;
            }),
          ],
        );
        container.read(storeProvider).language = language;
        final strings = Strings(language);
        Future<void> settle() async {
          for (var frame = 0; frame < 5; frame++) {
            await tester.pump(const Duration(milliseconds: 200));
          }
        }

        Future<void> tap(Finder finder) async {
          await tester.ensureVisible(finder);
          await tester.tap(finder);
          await settle();
        }

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const BrainRushApp(),
          ),
        );
        await settle();
        expect(
          tester
              .getBottomRight(
                find.widgetWithText(GamePrimaryButton, strings.t('start')),
              )
              .dy,
          lessThanOrEqualTo(568),
        );
        await tap(find.text(strings.t('daily')));
        await tap(
          find.widgetWithText(GamePrimaryButton, strings.t('playDaily')),
        );
        expect(active.mode, GameMode.daily);
        final first = active.question;
        for (var i = 0; i < 6; i++) {
          final previousExpression = active.question.expression;
          final target = find.byWidgetPredicate(
            (w) =>
                w is AnswerButton &&
                w.value ==
                    active.question.answers[active.question.correctAnswerIndex],
          );
          final bottom = tester
              .getBottomRight(find.byType(AnswerButton).last)
              .dy;
          expect(
            bottom,
            lessThanOrEqualTo(568),
            reason:
                'All answers should fit without scrolling at normal text size',
          );
          elapsed += const Duration(milliseconds: 900);
          await tester.tap(target);
          await tester.pump();
          expect(active.locked, true);
          expect(active.score, greaterThan(0));
          expect(tester.widget<AnswerButton>(target).correct, true);
          expect(active.answer(active.question.correctAnswerIndex), false);
          elapsed += const Duration(milliseconds: 400);
          await settle();
          if (previousExpression.isNotEmpty &&
              previousExpression != active.question.expression) {
            expect(
              find.text(previousExpression),
              findsNothing,
              reason: 'The previous question must leave before answers unlock.',
            );
          }
        }
        expect(active.multiplier, 3);
        expect(active.score, 11);
        elapsed += const Duration(milliseconds: 800);
        final wrongIndex =
            (active.question.correctAnswerIndex + 1) %
            active.question.answers.length;
        await tester.tap(
          find.byWidgetPredicate(
            (w) =>
                w is AnswerButton &&
                w.value == active.question.answers[wrongIndex],
          ),
        );
        await tester.pump();
        expect(active.streak, 0);
        expect(active.score, 11);
        expect(
          find.byWidgetPredicate((w) => w is AnswerButton && w.wrong),
          findsOneWidget,
        );
        expect(
          find.byWidgetPredicate((w) => w is AnswerButton && w.correct),
          findsOneWidget,
        );
        elapsed = const Duration(seconds: 60);
        await settle();
        expect(find.text(strings.t('timesUp')), findsOneWidget);
        expect(find.byType(Celebration), findsOneWidget);
        final date = dateKey(active.startedAt);
        expect(container.read(storeProvider).daily[date]!.score, 11);
        await tap(find.widgetWithText(GamePrimaryButton, strings.t('again')));
        expect(active.score, 0);
        expect(active.remaining, 60);
        expect(active.question.answers, first.answers);
        expect(active.question.type, first.type);
        // Resume must catch up even if no frame was rendered while backgrounded.
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        elapsed = const Duration(seconds: 70);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await settle();
        expect(find.text(strings.t('timesUp')), findsOneWidget);
        expect(container.read(storeProvider).stats.totalGames, 2);
        expect(container.read(storeProvider).daily[date]!.score, 11);
        await tap(find.text(strings.t('home')));
        await tap(find.text(strings.t('statistics')));
        expect(find.text(strings.t('totalGames')), findsOneWidget);
        expect(find.text('11'), findsOneWidget);
        Navigator.of(tester.element(find.byType(RushScaffold))).pop();
        await settle();
        await tap(find.widgetWithText(TextButton, strings.t('settings')));
        await tap(find.text(strings.t('light')));
        expect(container.read(storeProvider).themeMode, ThemeMode.light);
        final haptics = find.byWidgetPredicate(
          (w) =>
              w is SwitchListTile &&
              (w.title as Text).data == strings.t('haptics'),
        );
        await tap(haptics);
        expect(container.read(storeProvider).haptics, false);
        await container.read(storeProvider).save();
        await tester.pumpWidget(const SizedBox());
        container.dispose();
        SharedPreferences.resetStatic();
        container = ProviderContainer(
          overrides: [
            preferencesProvider.overrideWithValue(
              await SharedPreferences.getInstance(),
            ),
          ],
        );
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const BrainRushApp(),
          ),
        );
        await settle();
        final restored = container.read(storeProvider);
        expect(restored.language, language);
        expect(restored.themeMode, ThemeMode.light);
        expect(restored.haptics, false);
        expect(restored.stats.totalGames, 2);
        expect(restored.stats.bestScore, 11);
        expect(restored.daily[date]!.score, 11);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        container.dispose();
      },
    );
  }
}
