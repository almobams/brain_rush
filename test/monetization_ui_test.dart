import 'dart:async';

import 'package:brain_rush/core/store.dart';
import 'package:brain_rush/backend/daily_ranking_service.dart';
import 'package:brain_rush/game/models.dart';
import 'package:brain_rush/game/progression.dart';
import 'package:brain_rush/localization/strings.dart';
import 'package:brain_rush/monetization/ad_service.dart';
import 'package:brain_rush/monetization/purchase_service.dart';
import 'package:brain_rush/screens/results_screen.dart';
import 'package:brain_rush/screens/secondary_screens.dart';
import 'package:brain_rush/screens/game_screen.dart';
import 'package:brain_rush/widgets/daily_attempt_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeAds extends AdService {
  int rewardedShows = 0, interstitialShows = 0;
  Future<bool> Function()? rewardedResult;
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
    return await rewardedResult?.call() ?? false;
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

class OfflineRankingService implements DailyRankingService {
  @override
  bool get configured => false;

  @override
  Future<int?> submitBest(
    String installationId,
    String date,
    int score,
    int attemptNo,
  ) async => null;

  @override
  Future<DailyRank?> getRank(String installationId, String date) async => null;
}

void main() {
  testWidgets('Daily retry starts only after a rewarded result', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final ads = FakeAds();
    final purchases = FakePurchases(false);
    final container = ProviderContainer(
      overrides: [
        preferencesProvider.overrideWithValue(
          await SharedPreferences.getInstance(),
        ),
        adServiceProvider.overrideWith((ref) => ads),
        purchaseServiceProvider.overrideWith((ref) => purchases),
        dailyRankingServiceProvider.overrideWithValue(OfflineRankingService()),
      ],
    );
    final store = container.read(storeProvider);
    final today = DateTime.now();
    final first = GameSession(
      id: 'daily-first',
      mode: GameMode.daily,
      startedAt: today,
      endedAt: today.add(const Duration(seconds: 60)),
      score: 8,
      bestStreak: 0,
      results: const [],
    );
    await store.record(first);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: DailyScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(DailyAttemptIndicator), findsOneWidget);
    expect(find.text('1/3'), findsOneWidget);
    expect(find.textContaining('2 attempts remaining'), findsNothing);
    expect(find.text('Your best'), findsOneWidget);
    expect(find.text('This attempt'), findsNothing);
    expect(find.text('WATCH AD TO RETRY'), findsOneWidget);
    final noReward = Completer<bool>();
    ads.rewardedResult = () => noReward.future;
    await tester.ensureVisible(find.text('WATCH AD TO RETRY'));
    await tester.tap(find.text('WATCH AD TO RETRY'));
    await tester.pump();
    expect(store.canStartDaily(today, removeAdsOwned: false), isFalse);
    noReward.complete(false);
    await tester.pump(const Duration(milliseconds: 500));
    expect(store.canStartDaily(today, removeAdsOwned: false), isFalse);
    expect(find.byType(DailyScreen), findsOneWidget);
    final rewarded = Completer<bool>();
    ads.rewardedResult = () => rewarded.future;
    await tester.tap(find.text('WATCH AD TO RETRY'));
    await tester.pump();
    expect(store.canStartDaily(today, removeAdsOwned: false), isFalse);
    rewarded.complete(true);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(store.canStartDaily(today, removeAdsOwned: false), isTrue);
    expect(find.byType(GameScreen), findsOneWidget);
    expect(ads.rewardedShows, 2);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  testWidgets('Remove Ads owner retries Daily without rewarded ad', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final ads = FakeAds();
    final container = ProviderContainer(
      overrides: [
        preferencesProvider.overrideWithValue(
          await SharedPreferences.getInstance(),
        ),
        adServiceProvider.overrideWith((ref) => ads),
        purchaseServiceProvider.overrideWith((ref) => FakePurchases(true)),
        dailyRankingServiceProvider.overrideWithValue(OfflineRankingService()),
      ],
    );
    final today = DateTime.now();
    await container
        .read(storeProvider)
        .record(
          GameSession(
            id: 'premium-first',
            mode: GameMode.daily,
            startedAt: today,
            endedAt: today.add(const Duration(seconds: 60)),
            score: 3,
            bestStreak: 0,
            results: const [],
          ),
        );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: DailyScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('WATCH AD TO RETRY'), findsNothing);
    await tester.ensureVisible(find.text('REPLAY CHALLENGE'));
    await tester.tap(find.text('REPLAY CHALLENGE'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(GameScreen), findsOneWidget);
    expect(ads.rewardedShows, 0);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  testWidgets('Fourth Daily attempt redirects to the capped challenge screen', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(
      overrides: [
        preferencesProvider.overrideWithValue(
          await SharedPreferences.getInstance(),
        ),
        adServiceProvider.overrideWith((ref) => FakeAds()),
        purchaseServiceProvider.overrideWith((ref) => FakePurchases(true)),
        dailyRankingServiceProvider.overrideWithValue(OfflineRankingService()),
      ],
    );
    final now = DateTime.now();
    final store = container.read(storeProvider);
    for (var attempt = 0; attempt < 3; attempt++) {
      await store.record(
        GameSession(
          id: 'capped-$attempt',
          mode: GameMode.daily,
          startedAt: now,
          endedAt: now.add(const Duration(seconds: 60)),
          score: attempt,
          bestStreak: 0,
          results: const [],
        ),
      );
    }
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: GameScreen(mode: GameMode.daily)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(GameScreen), findsNothing);
    expect(find.byType(DailyScreen), findsOneWidget);
    expect(find.text('3/3'), findsOneWidget);
    expect(find.text('New challenge tomorrow'), findsOneWidget);
    expect(find.text("You've used all 3 attempts today."), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

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
  for (final scenario in [
    (mode: GameMode.rush, premium: false),
    (mode: GameMode.daily, premium: false),
    (mode: GameMode.rush, premium: true),
  ]) {
    final mode = scenario.mode;
    testWidgets(
      '${mode.name} premium=${scenario.premium} Results exit policy',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final ads = FakeAds();
        final purchases = FakePurchases(scenario.premium);
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
        expect(
          ads.interstitialShows,
          0,
          reason: 'Game 3 only becomes eligible; reaching Results must not show an ad.',
        );
        final exit = find.text(mode == GameMode.rush ? 'PLAY AGAIN' : 'HOME');
        await tester.ensureVisible(exit);
        await tester.tap(exit);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 400));
        expect(
          ads.interstitialShows,
          mode == GameMode.rush && !scenario.premium ? 1 : 0,
        );
        expect(
          store.adSchedule.lastShownAt,
          isNull,
          reason: 'A skipped/failed ad must not start the cooldown.',
        );
        expect(store.adSchedule.lastShownGame, 0);
        expect(find.text('PLAY AGAIN'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        container.dispose();
      },
    );
  }
}
