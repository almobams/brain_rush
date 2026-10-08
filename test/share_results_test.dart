import 'dart:ui' as ui;

import 'package:brain_rush/backend/daily_ranking_service.dart';
import 'package:brain_rush/core/store.dart';
import 'package:brain_rush/game/models.dart';
import 'package:brain_rush/game/progression.dart';
import 'package:brain_rush/localization/languages.dart';
import 'package:brain_rush/localization/strings.dart';
import 'package:brain_rush/monetization/ad_service.dart';
import 'package:brain_rush/screens/results_screen.dart';
import 'package:brain_rush/screens/home_screen.dart';
import 'package:brain_rush/screens/secondary_screens.dart';
import 'package:brain_rush/sharing/result_share_card.dart';
import 'package:brain_rush/sharing/result_share_data.dart';
import 'package:brain_rush/sharing/result_share_service.dart';
import 'package:brain_rush/sharing/share_links.dart';
import 'package:brain_rush/widgets/daily_rank_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeShareService extends ResultShareService {
  ResultShareData? shared;
  @override
  Future<void> share(BuildContext context, ResultShareData data) async {
    shared = data;
  }
}

class _CountingAds extends AdService {
  int shows = 0;
  @override
  bool get privacyChoicesAvailable => false;
  @override
  bool get rewardedReady => false;
  @override
  Future<void> initialize() async {}
  @override
  Future<bool> showInterstitial() async {
    shows++;
    return false;
  }

  @override
  Future<bool> showRewarded() async {
    shows++;
    return false;
  }

  @override
  Future<void> showPrivacyChoices() async {}
}

class _ShareRankingService implements DailyRankingService {
  DailyRank? latest = const DailyRank(
    bestScore: 90,
    highestScore: 100,
    rank: 7,
    participantCount: 18,
    topPercent: 39,
  );
  bool failFetch = false;
  int submissions = 0;
  int fetches = 0;

  @override
  bool get configured => true;

  @override
  Future<int?> submitBest(
    String installationId,
    String date,
    int score,
    int attemptNo,
  ) async {
    submissions++;
    return score;
  }

  @override
  Future<DailyRank?> getRank(String installationId, String date) async {
    fetches++;
    if (failFetch) throw StateError('Offline');
    return latest;
  }
}

Future<void> _markDailyBestSynced(
  SharedPreferences preferences,
  String date,
  int score,
) async {
  final id = await InstallationIdentity(preferences).getOrCreate();
  await preferences.setInt('brain_rush_rank_synced_${id}_$date', score);
}

GameSession _session(GameMode mode) => GameSession(
  id: 'share-test',
  mode: mode,
  startedAt: DateTime(2026, 10, 4, 12),
  endedAt: DateTime(2026, 10, 4, 12, 1),
  score: 92,
  bestStreak: 7,
  results: List.generate(
    8,
    (index) => QuestionResult(
      'q$index',
      QuestionType.larger,
      index != 0,
      const Duration(seconds: 1),
      1,
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'Rush and Daily share models contain only the intended result fields',
    () {
      final rush = ResultShareData.rush(
        session: _session(GameMode.rush),
        award: const ProgressAward(
          earnedXp: 20,
          previousXp: 0,
          totalXp: 20,
          isNewBest: true,
          previousBest: 80,
        ),
        personalBest: 92,
        playerName: 'محمد',
      );
      expect(rush.score, 92);
      expect(rush.personalBest, 92);
      expect(rush.accuracy, 88);
      expect(rush.bestStreak, 7);
      expect(rush.isNewBest, isTrue);
      expect(rush.playerName, 'محمد');
      final dailyResult = DailyChallengeResult(
        '2026-10-04',
        89,
        0,
        0,
        true,
        attemptsUsed: 2,
        bestAttemptNo: 1,
      );
      final daily = ResultShareData.daily(
        result: dailyResult,
        rank: const DailyRank(
          bestScore: 89,
          highestScore: 90,
          rank: 2,
          participantCount: 5,
          topPercent: 40,
        ),
      );
      expect(daily.score, 89);
      expect(daily.highestScore, 90);
      expect(daily.rank, 2);
      expect(daily.playerName, isNull);
      final first = ResultShareData.daily(
        result: dailyResult,
        rank: const DailyRank(
          bestScore: 89,
          highestScore: 89,
          rank: 1,
          participantCount: 1,
          topPercent: 100,
        ),
      );
      expect(first.rank, 1);
      final offline = ResultShareData.daily(result: dailyResult);
      expect(offline.rank, isNull);
      expect(offline.highestScore, isNull);
      final caption = ResultShareService().caption(daily, 'en');
      expect(caption, contains('#2'));
      expect(caption, isNot(contains('5 participants')));
      expect(caption, isNot(contains('40%')));
      expect(ResultShareService().caption(offline, 'en'), contains('89'));
      expect(ResultShareService().caption(rush, 'ar'), contains('92'));
      expect(
        ShareLinks.brainRushLandingUrl,
        'https://brain-rush-almobairik.web.app/go/',
      );
      expect(ShareLinks.shareUrl, ShareLinks.brainRushLandingUrl);
    },
  );

  testWidgets(
    'Share button reads completed Rush result without changing progress or requesting ads',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final fakeShare = _FakeShareService();
      final ads = _CountingAds();
      final container = ProviderContainer(
        overrides: [
          preferencesProvider.overrideWithValue(prefs),
          resultShareServiceProvider.overrideWithValue(fakeShare),
          adServiceProvider.overrideWith((ref) => ads),
        ],
      );
      final store = container.read(storeProvider);
      store.stats.bestScore = 92;
      store.stats.totalXp = 50;
      store.playerName = '李';
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: ResultsScreen(
              session: _session(GameMode.rush),
              award: const ProgressAward(
                earnedXp: 20,
                previousXp: 30,
                totalXp: 50,
                isNewBest: false,
                previousBest: 92,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 700));
      await tester.ensureVisible(find.byKey(const Key('shareResultButton')));
      await tester.tap(find.byKey(const Key('shareResultButton')));
      await tester.pump();
      expect(fakeShare.shared?.score, 92);
      expect(fakeShare.shared?.playerName, '李');
      expect(store.stats.bestScore, 92);
      expect(store.stats.totalXp, 50);
      expect(store.stats.totalGames, 0);
      expect(ads.shows, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    },
  );

  testWidgets('name personalizes Home and #1; absent name stays generic', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        preferencesProvider.overrideWithValue(prefs),
        adServiceProvider.overrideWith((ref) => _CountingAds()),
      ],
    );
    final store = container.read(storeProvider);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pump();
    expect(find.textContaining('Ready,'), findsNothing);
    await store.setPlayerName('محمد');
    await tester.pump();
    expect(find.text('Ready, محمد?'), findsOneWidget);
    const first = DailyRank(
      bestScore: 89,
      highestScore: 89,
      rank: 1,
      participantCount: 1,
      topPercent: 100,
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DailyRankPanel(
            rank: first,
            localBest: 89,
            loading: false,
            unavailable: false,
            playerName: 'محمد',
          ),
        ),
      ),
    );
    expect(find.text('You’re #1 today, محمد!'), findsOneWidget);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DailyRankPanel(
            rank: first,
            localBest: 89,
            loading: false,
            unavailable: false,
          ),
        ),
      ),
    );
    expect(find.text('You’re #1 today'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  testWidgets('Daily Share uses the saved best and never consumes an attempt', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final fakeShare = _FakeShareService();
    final ads = _CountingAds();
    final container = ProviderContainer(
      overrides: [
        preferencesProvider.overrideWithValue(prefs),
        resultShareServiceProvider.overrideWithValue(fakeShare),
        adServiceProvider.overrideWith((ref) => ads),
      ],
    );
    final store = container.read(storeProvider);
    final session = _session(GameMode.daily);
    final date = dateKey(session.startedAt);
    store.daily[date] = DailyChallengeResult(
      date,
      89,
      7,
      1,
      true,
      attemptsUsed: 2,
      bestAttemptNo: 1,
    );
    store.playerName = 'محمد';
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: ResultsScreen(
            session: session,
            award: const ProgressAward(
              earnedXp: 0,
              previousXp: 20,
              totalXp: 20,
              isNewBest: false,
              previousBest: 92,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));
    await tester.ensureVisible(find.byKey(const Key('shareResultButton')));
    await tester.tap(find.byKey(const Key('shareResultButton')));
    await tester.pump();
    expect(fakeShare.shared?.mode, GameMode.daily);
    expect(fakeShare.shared?.score, 89);
    expect(fakeShare.shared?.playerName, 'محمد');
    expect(fakeShare.shared?.rank, isNull);
    expect(store.daily[date]?.attemptsUsed, 2);
    expect(ads.shows, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  testWidgets('Daily screen Share requires a completed attempt today', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final ranking = _ShareRankingService();
    final container = ProviderContainer(
      overrides: [
        preferencesProvider.overrideWithValue(prefs),
        dailyRankingServiceProvider.overrideWithValue(ranking),
        adServiceProvider.overrideWith((ref) => _CountingAds()),
      ],
    );
    final store = container.read(storeProvider);
    final now = DateTime.now();
    final today = dateKey(now);
    final yesterday = dateKey(DateTime(now.year, now.month, now.day - 1));
    store.daily[yesterday] = DailyChallengeResult(yesterday, 88, 0, 0, true);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: DailyScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final share = find.byKey(const Key('shareDailyResultButton'));
    expect(share, findsNothing);
    store.daily[today] = DailyChallengeResult(
      today,
      0,
      0,
      0,
      false,
      attemptsUsed: 0,
    );
    await store.save();
    await tester.pump();
    expect(share, findsNothing);
    store.daily[today] = DailyChallengeResult(today, 80, 0, 0, true);
    await store.save();
    await tester.pump();
    expect(share, findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  testWidgets(
    'Daily screen Share uses best, latest rank, and local name without submitting',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final rankingService = _ShareRankingService();
      final fakeShare = _FakeShareService();
      final container = ProviderContainer(
        overrides: [
          preferencesProvider.overrideWithValue(prefs),
          dailyRankingServiceProvider.overrideWithValue(rankingService),
          resultShareServiceProvider.overrideWithValue(fakeShare),
          adServiceProvider.overrideWith((ref) => _CountingAds()),
        ],
      );
      final store = container.read(storeProvider);
      final today = dateKey(DateTime.now());
      store.daily[today] = DailyChallengeResult(
        today,
        90,
        0,
        0,
        true,
        attemptsUsed: 2,
        lastScore: 60,
        bestAttemptNo: 1,
      );
      store.playerName = 'محمد';
      await _markDailyBestSynced(prefs, today, 90);
      final ranking = container.read(dailyRankingProvider);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: DailyScreen()),
        ),
      );
      await tester.pump();
      await ranking.refreshRankOnly(store.daily[today]!);
      rankingService.latest = const DailyRank(
        bestScore: 90,
        highestScore: 120,
        rank: 2,
        participantCount: 40,
        topPercent: 5,
      );
      final share = find.byKey(const Key('shareDailyResultButton'));
      await tester.ensureVisible(share);
      await tester.tap(share);
      await tester.pump();
      await tester.pump();
      final shared = fakeShare.shared;
      expect(shared?.mode, GameMode.daily);
      expect(shared?.score, 90);
      expect(shared?.challengeDate, DateTime.parse(today));
      expect(shared?.rank, 2);
      expect(shared?.highestScore, 120);
      expect(shared?.playerName, 'محمد');
      expect(rankingService.submissions, 0);
      expect(store.daily[today]?.attemptsUsed, 2);
      final caption = ResultShareService().caption(
        shared!,
        'en',
        url: ShareLinks.shareUrl,
      );
      expect(caption.split(ShareLinks.shareUrl!).length, 2);
      expect(caption, isNot(contains('40 participants')));
      expect(caption, isNot(contains('5%')));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    },
  );

  testWidgets('Daily screen Share uses cached rank when refresh fails', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final rankingService = _ShareRankingService();
    final fakeShare = _FakeShareService();
    final container = ProviderContainer(
      overrides: [
        preferencesProvider.overrideWithValue(prefs),
        dailyRankingServiceProvider.overrideWithValue(rankingService),
        resultShareServiceProvider.overrideWithValue(fakeShare),
        adServiceProvider.overrideWith((ref) => _CountingAds()),
      ],
    );
    final store = container.read(storeProvider);
    final today = dateKey(DateTime.now());
    final result = DailyChallengeResult(today, 90, 0, 0, true);
    store.daily[today] = result;
    await _markDailyBestSynced(prefs, today, 90);
    final ranking = container.read(dailyRankingProvider);
    await ranking.refreshRankOnly(result);
    rankingService.failFetch = true;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: DailyScreen()),
      ),
    );
    await tester.pump();
    final share = find.byKey(const Key('shareDailyResultButton'));
    await tester.ensureVisible(share);
    await tester.tap(share);
    await tester.pump();
    await tester.pump();
    expect(fakeShare.shared?.score, 90);
    expect(fakeShare.shared?.rank, 7);
    expect(fakeShare.shared?.highestScore, 100);
    expect(fakeShare.shared?.playerName, isNull);
    expect(rankingService.submissions, 0);
    expect(store.daily[today]?.attemptsUsed, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  for (final language in ['ar', 'ur', 'fa']) {
    testWidgets('$language Daily Share fits a compact RTL screen', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final prefs = await SharedPreferences.getInstance();
      final rankingService = _ShareRankingService();
      final container = ProviderContainer(
        overrides: [
          preferencesProvider.overrideWithValue(prefs),
          dailyRankingServiceProvider.overrideWithValue(rankingService),
          adServiceProvider.overrideWith((ref) => _CountingAds()),
        ],
      );
      final store = container.read(storeProvider);
      store.language = language;
      final today = dateKey(DateTime.now());
      store.daily[today] = DailyChallengeResult(today, 90, 0, 0, true);
      await _markDailyBestSynced(prefs, today, 90);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: AppLanguages.localeFor(language),
            supportedLocales: AppLanguages.supportedLocales,
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: const DailyScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      final share = find.byKey(const Key('shareDailyResultButton'));
      await tester.ensureVisible(share);
      await tester.pump();
      expect(share, findsOneWidget);
      expect(find.text(Strings(language).t('share')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });
  }

  for (final language in [
    'de',
    'fr',
    'ar',
    'ur',
    'fa',
    'ja',
    'zh_Hans',
    'en',
  ]) {
    final size = language == 'en' ? const Size(390, 844) : const Size(320, 568);
    testWidgets('$language Home, Results, and Settings fit $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          preferencesProvider.overrideWithValue(prefs),
          adServiceProvider.overrideWith((ref) => _CountingAds()),
        ],
      );
      final store = container.read(storeProvider);
      store.language = language;
      store.playerName = 'محمد 山田 李 — Zoë';
      Widget shell(Widget screen) => UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: AppLanguages.localeFor(language),
          supportedLocales: AppLanguages.supportedLocales,
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: screen,
        ),
      );
      await tester.pumpWidget(shell(const HomeScreen()));
      await tester.pump(const Duration(milliseconds: 700));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(shell(const SettingsScreen()));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        shell(
          ResultsScreen(
            session: _session(GameMode.rush),
            award: const ProgressAward(
              earnedXp: 5,
              previousXp: 0,
              totalXp: 5,
              isNewBest: false,
              previousBest: 92,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 700));
      await tester.ensureVisible(find.byKey(const Key('shareResultButton')));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });
  }

  for (final language in [
    'en',
    'ar',
    'ur',
    'fa',
    'de',
    'fr',
    'ja',
    'ko',
    'zh_Hans',
    'zh_Hant',
    'hi',
    'bn',
  ]) {
    testWidgets(
      '$language result image cards fit without participant count or percentile',
      (tester) async {
        final locale = AppLanguages.localeFor(language);
        final data = ResultShareData.daily(
          result: DailyChallengeResult(
            '2026-10-04',
            89,
            0,
            0,
            true,
            attemptsUsed: 2,
            bestAttemptNo: 1,
          ),
          rank: const DailyRank(
            bestScore: 89,
            highestScore: 90,
            rank: 2,
            participantCount: 5,
            topPercent: 40,
          ),
          playerName: 'محمد 山田 李 — Zoë',
        );
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            supportedLocales: AppLanguages.supportedLocales,
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: Scaffold(
              body: Center(
                child: ResultShareCard(data: data, language: language),
              ),
            ),
          ),
        );
        expect(find.text('#2'), findsOneWidget);
        expect(find.text('89'), findsOneWidget);
        expect(find.text('90'), findsOneWidget);
        expect(find.text(Strings(language).t('currentRank')), findsOneWidget);
        expect(find.text(Strings(language).t('yourBest')), findsOneWidget);
        expect(find.text(Strings(language).t('todayHighest')), findsOneWidget);
        expect(find.textContaining('40%'), findsNothing);
        expect(find.textContaining('5 participants'), findsNothing);
        expect(find.text('2/3'), findsNothing);
        expect(find.textContaining('12:00'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('local image capture produces a crisp 1080 x 1350 PNG', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (buildContext) {
            context = buildContext;
            return const Scaffold(body: SizedBox.expand());
          },
        ),
      ),
    );
    final result = ResultShareData.rush(
      session: _session(GameMode.rush),
      award: const ProgressAward(
        earnedXp: 20,
        previousXp: 0,
        totalXp: 20,
        isNewBest: true,
        previousBest: 80,
      ),
      personalBest: 92,
    );
    final pending = tester.runAsync(
      () => ResultShareService().capture(context, result),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    final bytes = await pending;
    final codec = await tester.runAsync(() => ui.instantiateImageCodec(bytes!));
    final frame = await tester.runAsync(() => codec!.getNextFrame());
    expect(frame!.image.width, 1080);
    expect(frame.image.height, 1350);
    frame.image.dispose();
    codec!.dispose();
    expect(tester.takeException(), isNull);
  });
}
