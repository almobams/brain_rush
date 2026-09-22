import 'package:brain_rush/core/store.dart';
import 'package:brain_rush/game/models.dart';
import 'package:brain_rush/game/progression.dart';
import 'package:brain_rush/localization/strings.dart';
import 'package:brain_rush/monetization/ad_service.dart';
import 'package:brain_rush/monetization/purchase_service.dart';
import 'package:brain_rush/screens/results_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeAds extends AdService {
  int rewardedShows = 0, interstitialShows = 0;
  @override
  bool get privacyChoicesAvailable => false;
  @override
  bool get rewardedReady => true;
  @override
  Future<void> initialize() async {}
  @override
  Future<bool> showInterstitial() async {
    interstitialShows++;
    return false;
  }

  @override
  Future<bool> showRewarded() async {
    rewardedShows++;
    return false;
  }

  @override
  Future<void> showPrivacyChoices() async {}
}

class FakePurchases extends PurchaseService {
  FakePurchases(this.isOwned);
  final bool isOwned;
  @override
  bool get owned => isOwned;
  @override
  bool get loading => false;
  @override
  bool get pending => false;
  @override
  String? get price => null;
  @override
  Future<void> initialize() async {}
  @override
  Future<void> buy() async {}
  @override
  Future<RestoreResult> restore() async => RestoreResult.none;
}

void main() {
  for (final language in ['en', 'ar']) {
    testWidgets(
      '$language Results hides rewarded UI and keeps normal XP unchanged',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final ads = FakeAds();
        final purchases = FakePurchases(true);
        final container = ProviderContainer(
          overrides: [
            preferencesProvider.overrideWithValue(prefs),
            adServiceProvider.overrideWith((ref) => ads),
            purchaseServiceProvider.overrideWith((ref) => purchases),
          ],
        );
        final store = container.read(storeProvider);
        store.language = language;
        final now = DateTime(2026, 9, 22);
        final session = GameSession(
          id: '$language-rewarded-disabled',
          mode: GameMode.rush,
          startedAt: now,
          endedAt: now,
          score: 10,
          bestStreak: 1,
          results: const [],
        );
        final award = await store.record(session);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              locale: Locale(language),
              supportedLocales: const [Locale('en'), Locale('ar')],
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              home: ResultsScreen(session: session, award: award),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 800));
        expect(find.text(Strings(language).t('watchDoubleXp')), findsNothing);
        expect(find.text(Strings(language).t('claimXpBonus')), findsNothing);
        expect(store.stats.totalXp, award.totalXp);
        expect(store.stats.bestScore, 10);
        expect(store.stats.totalGames, 1);
        expect(ads.rewardedShows, 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        container.dispose();
      },
    );
  }
  for (final mode in [GameMode.rush, GameMode.daily]) {
    testWidgets('${mode.name} failed interstitial continues Play Again', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final ads = FakeAds();
      final purchases = FakePurchases(false);
      final container = ProviderContainer(
        overrides: [
          preferencesProvider.overrideWithValue(prefs),
          adServiceProvider.overrideWith((ref) => ads),
          purchaseServiceProvider.overrideWith((ref) => purchases),
        ],
      );
      final store = container.read(storeProvider);
      store.adSchedule.normalGames = 3;
      final now = DateTime(2026, 9, 22);
      final session = GameSession(
        id: 'navigation-${mode.name}',
        mode: mode,
        startedAt: now,
        endedAt: now,
        score: 4,
        bestStreak: 1,
        results: const [],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: ResultsScreen(
              session: session,
              award: const ProgressAward(
                earnedXp: 12,
                previousXp: 0,
                totalXp: 12,
                isNewBest: false,
                previousBest: 4,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 700));
      final again = find.text('PLAY AGAIN');
      await tester.ensureVisible(again);
      await tester.tap(again);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(ads.interstitialShows, mode == GameMode.rush ? 1 : 0);
      expect(find.text('PLAY AGAIN'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });
  }
}
