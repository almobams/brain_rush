import 'dart:convert';

import 'package:brain_rush/backend/daily_ranking_service.dart';
import 'package:brain_rush/backend/supabase_config.dart';
import 'package:brain_rush/core/store.dart';
import 'package:brain_rush/game/models.dart';
import 'package:brain_rush/main.dart';
import 'package:brain_rush/screens/secondary_screens.dart';
import 'package:brain_rush/theme/app_theme.dart';
import 'package:brain_rush/widgets/daily_rank_panel.dart';
import 'package:brain_rush/widgets/daily_attempt_indicator.dart';
import 'package:brain_rush/widgets/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakeRankingService implements DailyRankingService {
  bool enabled = true;
  bool fail = false;
  Object? submitError;
  Object? rankError;
  int submissions = 0;
  int fetches = 0;
  int best = 0;
  int bestAttemptNo = 0;
  String? lastDate;
  String? lastInstallationId;

  @override
  bool get configured => enabled;

  @override
  Future<int?> submitBest(
    String installationId,
    String date,
    int score,
    int attemptNo,
  ) async {
    if (submitError != null) throw submitError!;
    if (fail) throw StateError('offline');
    submissions++;
    lastDate = date;
    lastInstallationId = installationId;
    if (score > best) {
      best = score;
      bestAttemptNo = attemptNo;
    }
    return best;
  }

  @override
  Future<DailyRank?> getRank(String installationId, String date) async {
    if (rankError != null) throw rankError!;
    if (fail) throw StateError('offline');
    fetches++;
    return DailyRank(
      bestScore: best,
      highestScore: best + 4,
      rank: 2,
      participantCount: 20,
      topPercent: 10,
    );
  }
}

GameSession completed(DateTime date, int score, GameMode mode) => GameSession(
  id: '${date.microsecondsSinceEpoch}-$score',
  mode: mode,
  startedAt: date,
  endedAt: date.add(const Duration(seconds: 60)),
  score: score,
  bestStreak: 0,
  results: const [],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('ranking defaults to the embedded public production configuration', () {
    final service = SupabaseDailyRankingService();
    expect(service.url, SupabaseConfig.productionUrl);
    expect(service.anonKey, SupabaseConfig.productionAnonKey);
    expect(service.configured, isTrue);
    final payload = jsonDecode(
      utf8.decode(
        base64Url.decode(base64Url.normalize(service.anonKey.split('.')[1])),
      ),
    ) as Map<String, dynamic>;
    expect(payload['iss'], 'supabase');
    expect(payload['role'], 'anon');
    expect(payload['ref'], 'rmcppwjygjvvzawkobai');
  });

  test('debug diagnostics report submit, skip, rank, and PostgREST failures without keys', () async {
    final messages = <String>[];
    final original = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) messages.add(message);
    };
    addTearDown(() => debugPrint = original);
    final prefs = await SharedPreferences.getInstance();
    final store = AppStore(prefs);
    final service = FakeRankingService();
    final ranking = DailyRankingController(prefs, service);
    final date = DateTime(2026, 10, 4);
    final game = completed(date, 8, GameMode.daily);
    await store.record(game);
    await ranking.onCompleted(game, store.daily[dateKey(date)]);
    await ranking.refresh(store.dailyStatus(date));
    expect(
      messages.any((m) => m.contains('[BrainRush Ranking] configured=true')),
      isTrue,
    );
    expect(
      messages.any(
        (m) => m.contains(
          'daily completion: challengeDate=2026-10-04, score=8, localBest=8, bestAttemptNo=1, completedAttemptNo=1, installationId=',
        ),
      ),
      isTrue,
    );
    expect(messages.any((m) => m.contains('submit started')), isTrue);
    expect(
      messages.any((m) => m.contains('submit succeeded: authoritativeBest=8')),
      isTrue,
    );
    expect(
      messages.any(
        (m) => m.contains('submit skipped: local best already synced'),
      ),
      isTrue,
    );
    expect(
      messages.any(
        (m) => m.contains(
          'rank fetch succeeded: rank=2, highestScore=12, participantCount=20, topPercent=10',
        ),
      ),
      isTrue,
    );

    service.rankError = const PostgrestException(
      message: 'rank rejected',
      code: '42501',
      details: 'test details',
      hint: 'test hint',
    );
    await ranking.refresh(store.dailyStatus(date));
    expect(
      messages.any(
        (m) => m.contains('rank fetch failed: type=PostgrestException'),
      ),
      isTrue,
    );
    expect(
      messages.any(
        (m) => m.contains(
          'code=42501, message=rank rejected, details=test details, hint=test hint',
        ),
      ),
      isTrue,
    );
    service.submitError = const PostgrestException(
      message: 'submit rejected',
      code: 'P0001',
      details: 'test submit details',
      hint: 'test submit hint',
    );
    final nextDay = completed(
      date.add(const Duration(days: 1)),
      9,
      GameMode.daily,
    );
    await store.record(nextDay);
    await ranking.onCompleted(nextDay, store.daily[dateKey(nextDay.startedAt)]);
    expect(
      messages.any((m) => m.contains('submit failed: type=PostgrestException')),
      isTrue,
    );
    expect(
      messages.any(
        (m) => m.contains(
          'code=P0001, message=submit rejected, details=test submit details, hint=test submit hint',
        ),
      ),
      isTrue,
    );
    final unconfigured = DailyRankingController(
      prefs,
      SupabaseDailyRankingService(
        url: SupabaseConfig.productionUrl,
        anonKey: '',
      ),
    );
    await unconfigured.refresh(store.dailyStatus(date));
    expect(
      messages.any(
        (m) => m.contains(
          'configured=false, host=rmcppwjygjvvzawkobai.supabase.co',
        ),
      ),
      isTrue,
    );
    expect(
      messages.join('\n').contains(SupabaseConfig.productionAnonKey),
      isFalse,
    );
    unconfigured.dispose();
    ranking.dispose();
    store.dispose();
  });

  test(
    'anonymous UUID is generated once and persists across instances',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final first = await InstallationIdentity(prefs).getOrCreate();
      expect(
        first,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
      expect(await InstallationIdentity(prefs).getOrCreate(), first);
      SharedPreferences.resetStatic();
      expect(
        await InstallationIdentity(await SharedPreferences.getInstance())
            .getOrCreate(),
        first,
      );
    },
  );

  test(
    'best score keeps the attempt that achieved it across all three tries',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final store = AppStore(prefs);
      final service = FakeRankingService();
      final ranking = DailyRankingController(prefs, service);
      final date = DateTime(2026, 10, 2, 12);
      final first = completed(date, 80, GameMode.daily);
      await store.record(first);
      await ranking.onCompleted(first, store.daily[dateKey(date)]);
      expect(service.submissions, 1);
      expect(service.best, 80);
      expect(service.bestAttemptNo, 1);
      expect(store.dailyStatus(date).bestAttemptNo, 1);
      expect(service.lastDate, dateKey(date));
      expect(ranking.rankFor(dateKey(date))?.rank, 2);
      expect(store.dailyStatus(date).attemptsRemaining, 2);

      final lower = completed(
        date.add(const Duration(minutes: 1)),
        70,
        GameMode.daily,
      );
      await store.record(lower);
      await ranking.onCompleted(lower, store.daily[dateKey(date)]);
      expect(store.dailyStatus(date).score, 80);
      expect(store.dailyStatus(date).bestAttemptNo, 1);
      expect(service.submissions, 1);
      expect(service.fetches, 2);
      expect(service.bestAttemptNo, 1);

      final higher = completed(
        date.add(const Duration(minutes: 2)),
        81,
        GameMode.daily,
      );
      await store.record(higher);
      await ranking.onCompleted(higher, store.daily[dateKey(date)]);
      expect(store.dailyStatus(date).score, 81);
      expect(store.dailyStatus(date).bestAttemptNo, 3);
      expect(service.submissions, 2);
      expect(service.best, 81);
      expect(service.bestAttemptNo, 3);
      expect(store.dailyStatus(date).attemptsRemaining, 0);
      store.dispose();
      ranking.dispose();
    },
  );

  test('Rush and an abandoned Daily game do not submit', () async {
    final prefs = await SharedPreferences.getInstance();
    final service = FakeRankingService();
    final ranking = DailyRankingController(prefs, service);
    final date = DateTime(2026, 10, 2);
    await ranking.onCompleted(completed(date, 5, GameMode.rush), null);
    // Abandonment never records a Daily result, so there is nothing to submit.
    await ranking.onCompleted(completed(date, 5, GameMode.daily), null);
    expect(service.submissions, 0);
    expect(service.fetches, 0);
    ranking.dispose();
  });

  test(
    'a local player name is never submitted with anonymous ranking',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final store = AppStore(prefs);
      await store.setPlayerName('محمد 山田');
      final service = FakeRankingService();
      final ranking = DailyRankingController(prefs, service);
      final date = DateTime(2026, 10, 4);
      final game = completed(date, 89, GameMode.daily);
      await store.record(game);
      await ranking.onCompleted(game, store.daily[dateKey(date)]);
      expect(service.submissions, 1);
      expect(
        service.lastInstallationId,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
      expect(service.lastInstallationId, isNot(contains('محمد')));
      expect(service.lastDate, '2026-10-04');
      expect(service.best, 89);
      expect(service.bestAttemptNo, 1);
      ranking.dispose();
      store.dispose();
    },
  );

  test(
    'equal Daily retry preserves the earlier best attempt and skips submission',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final store = AppStore(prefs);
      final service = FakeRankingService();
      final ranking = DailyRankingController(prefs, service);
      final date = DateTime(2026, 10, 2);
      final first = completed(date, 80, GameMode.daily);
      await store.record(first);
      await ranking.onCompleted(first, store.daily[dateKey(date)]);
      final equal = completed(
        date.add(const Duration(minutes: 1)),
        80,
        GameMode.daily,
      );
      await store.record(equal);
      await ranking.onCompleted(equal, store.daily[dateKey(date)]);
      expect(store.dailyStatus(date).bestAttemptNo, 1);
      expect(service.bestAttemptNo, 1);
      expect(service.submissions, 1);
      store.dispose();
      ranking.dispose();
    },
  );

  test(
    'legacy synced score refreshes without claiming an early attempt',
    () async {
      final prefs = await SharedPreferences.getInstance();
      const id = '00000000-0000-4000-8000-000000000001';
      const date = '2026-10-02';
      await prefs.setString(InstallationIdentity.key, id);
      await prefs.setInt('brain_rush_rank_synced_${id}_$date', 80);
      final legacy = DailyChallengeResult.fromJson(const {
        'date': date,
        'score': 80,
        'correct': 0,
        'wrong': 0,
        'completed': true,
        'attemptsUsed': 2,
      });
      expect(legacy.bestAttemptNo, 3);
      final service = FakeRankingService()..best = 80;
      final ranking = DailyRankingController(prefs, service);
      await ranking.refresh(legacy);
      expect(service.submissions, 0);
      expect(service.fetches, 1);
      ranking.dispose();
    },
  );

  test(
    'backend failure preserves local attempts, score, and XP; refresh retries',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final store = AppStore(prefs);
      final service = FakeRankingService()..fail = true;
      final ranking = DailyRankingController(prefs, service);
      final date = DateTime(2026, 10, 2);
      final game = completed(date, 10, GameMode.daily);
      await store.record(game);
      final xp = store.stats.totalXp;
      await ranking.onCompleted(game, store.daily[dateKey(date)]);
      expect(ranking.unavailableFor(dateKey(date)), isTrue);
      expect(store.dailyStatus(date).score, 10);
      expect(store.dailyStatus(date).attemptsUsed, 1);
      service.fail = false;
      await ranking.refresh(store.dailyStatus(date));
      expect(service.submissions, 1);
      expect(ranking.rankFor(dateKey(date))?.topPercent, 10);
      expect(store.stats.totalXp, xp);
      expect(store.dailyStatus(date).attemptsUsed, 1);
      await ranking.refresh(store.dailyStatus(date));
      expect(service.submissions, 1);
      expect(service.fetches, 2);
      store.dispose();
      ranking.dispose();
    },
  );

  test(
    'missing Supabase config is safe and does not consume a retry',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final service = FakeRankingService()..enabled = false;
      final ranking = DailyRankingController(prefs, service);
      final store = AppStore(prefs);
      final date = DateTime(2026, 10, 2);
      final game = completed(date, 2, GameMode.daily);
      await store.record(game);
      await ranking.onCompleted(game, store.daily[dateKey(date)]);
      expect(ranking.unavailableFor(dateKey(date)), isTrue);
      expect(service.submissions, 0);
      expect(store.dailyStatus(date).attemptsRemaining, 2);
      expect(
        SupabaseDailyRankingService(url: '', anonKey: '').configured,
        isFalse,
      );
      store.dispose();
      ranking.dispose();
    },
  );

  test(
    'rank-only refresh never submits and retains cached rank on failure',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final service = FakeRankingService()..best = 42;
      final ranking = DailyRankingController(prefs, service);
      final date = dateKey(DateTime(2026, 10, 4));
      final result = DailyChallengeResult(date, 42, 0, 0, true);

      await ranking.refreshRankOnly(result);
      expect(service.fetches, 1);
      expect(service.submissions, 0);
      expect(ranking.rankFor(date)?.rank, 2);
      expect(ranking.rankFor(date)?.highestScore, 46);

      service.rankError = StateError('offline');
      await ranking.refreshRankOnly(result);
      expect(service.submissions, 0);
      expect(ranking.unavailableFor(date), isTrue);
      expect(ranking.rankFor(date)?.rank, 2);
      expect(ranking.rankFor(date)?.highestScore, 46);
      ranking.dispose();
    },
  );

  test('rank parser accepts the RPC response and rejects invalid values', () {
    final rank = DailyRank.fromJson(const {
      'best_score': 36,
      'highest_score': 40,
      'rank': 84,
      'participant_count': 1527,
      'top_percent': 6,
    });
    expect(rank.bestScore, 36);
    expect(rank.highestScore, 40);
    expect(rank.rank, 84);
    expect(rank.participantCount, 1527);
    expect(rank.topPercent, 6);
    expect(
      () => DailyRank.fromJson(const {
        'best_score': 1,
        'highest_score': 2,
        'rank': 0,
        'participant_count': 1,
        'top_percent': 0,
      }),
      throwsFormatException,
    );
    expect(
      () => DailyRank.fromJson(const {
        'best_score': 40,
        'highest_score': 36,
        'rank': 1,
        'participant_count': 1,
        'top_percent': 100,
      }),
      throwsFormatException,
    );
    expect(
      () => DailyRank.fromJson(const {
        'best_score': 36,
        'rank': 1,
        'participant_count': 1,
        'top_percent': 100,
      }),
      throwsFormatException,
    );
  });

  for (final language in ['en', 'ar']) {
    testWidgets('$language Daily rank shows rank and two scores only', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(language),
          supportedLocales: const [Locale('en'), Locale('ar')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: const Scaffold(
            body: DailyRankPanel(
              rank: DailyRank(
                bestScore: 36,
                highestScore: 40,
                rank: 84,
                participantCount: 1527,
                topPercent: 6,
              ),
              localBest: 36,
              loading: false,
              unavailable: false,
            ),
          ),
        ),
      );
      expect(
        find.text(language == 'en' ? 'Your rank today' : 'ترتيبك اليوم'),
        findsOneWidget,
      );
      expect(find.text('#84'), findsOneWidget);
      expect(find.text('40'), findsOneWidget);
      expect(find.text('36'), findsOneWidget);
      expect(find.textContaining('1527'), findsNothing);
      expect(find.textContaining('6%'), findsNothing);
      final badge = tester.widget<Directionality>(
        find
            .ancestor(
              of: find.byKey(const Key('dailyRankBadge')),
              matching: find.byType(Directionality),
            )
            .first,
      );
      expect(badge.textDirection, TextDirection.ltr);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('first place is celebrated without exposing player count', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DailyRankPanel(
            rank: DailyRank(
              bestScore: 90,
              highestScore: 90,
              rank: 1,
              participantCount: 3,
              topPercent: 34,
            ),
            localBest: 90,
            loading: false,
            unavailable: false,
          ),
        ),
      ),
    );
    expect(find.text('#1'), findsOneWidget);
    expect(find.text('You’re #1 today'), findsOneWidget);
    expect(find.textContaining('3'), findsNothing);
    expect(find.textContaining('34%'), findsNothing);
  });

  testWidgets(
    'unavailable ranking keeps local best and hides stale global data',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DailyRankPanel(
              rank: DailyRank(
                bestScore: 36,
                highestScore: 40,
                rank: 2,
                participantCount: 5,
                topPercent: 40,
              ),
              localBest: 36,
              loading: false,
              unavailable: true,
            ),
          ),
        ),
      );
      expect(find.text('Ranking unavailable'), findsOneWidget);
      expect(find.text('36'), findsOneWidget);
      expect(find.text('40'), findsNothing);
      expect(find.text('#2'), findsNothing);
    },
  );

  testWidgets(
    'Home shows no rank before participation, then rank and final attempts state',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final prefs = await SharedPreferences.getInstance();
      final service = FakeRankingService();
      final container = ProviderContainer(
        overrides: [
          preferencesProvider.overrideWithValue(prefs),
          dailyRankingServiceProvider.overrideWithValue(service),
        ],
      );
      final store = container.read(storeProvider);
      store.onboardingCompleted = true;
      final ranking = container.read(dailyRankingProvider);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const BrainRushApp(),
        ),
      );
      await tester.pump();
      expect(find.byType(DailyAttemptIndicator), findsOneWidget);
      expect(find.text('0/3'), findsOneWidget);
      expect(find.text('Attempts today'), findsOneWidget);
      expect(find.byType(DailyRankPanel), findsNothing);

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, 12);
      final first = completed(today, 80, GameMode.daily);
      await store.record(first);
      await ranking.onCompleted(first, store.dailyStatus(today));
      await tester.pump();
      final panel = find.byType(DailyRankPanel);
      expect(
        find.descendant(of: panel, matching: find.text('#2')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: panel, matching: find.text('84')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: panel, matching: find.text('80')),
        findsOneWidget,
      );
      expect(find.text('1/3'), findsOneWidget);
      expect(find.textContaining('20'), findsNothing);
      expect(find.textContaining('10%'), findsNothing);

      final second = completed(
        today.add(const Duration(minutes: 2)),
        70,
        GameMode.daily,
      );
      final third = completed(
        today.add(const Duration(minutes: 4)),
        81,
        GameMode.daily,
      );
      await store.record(second);
      await ranking.onCompleted(second, store.dailyStatus(today));
      await tester.pump();
      expect(find.text('2/3'), findsOneWidget);
      await store.record(third);
      await ranking.onCompleted(third, store.dailyStatus(today));
      await tester.pump();
      expect(find.text('3/3'), findsOneWidget);
      expect(find.text("You've used all 3 attempts today."), findsNothing);
      expect(
        find.descendant(of: panel, matching: find.text('85')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: panel, matching: find.text('81')),
        findsOneWidget,
      );

      service.fail = true;
      await ranking.refresh(store.dailyStatus(today));
      await tester.pump();
      expect(find.text('Ranking unavailable'), findsOneWidget);
      expect(
        find.descendant(of: panel, matching: find.text('81')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: panel, matching: find.text('85')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      container.dispose();
    },
  );

  for (final (size, language) in [
    (const Size(320, 568), 'en'),
    (const Size(320, 568), 'ar'),
    (const Size(390, 844), 'en'),
    (const Size(390, 844), 'ar'),
  ]) {
    testWidgets('Daily info fits $size in $language with enlarged text', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final prefs = await SharedPreferences.getInstance();
      final service = FakeRankingService();
      final container = ProviderContainer(
        overrides: [
          preferencesProvider.overrideWithValue(prefs),
          dailyRankingServiceProvider.overrideWithValue(service),
        ],
      );
      final store = container.read(storeProvider);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day, 12);
      final game = completed(today, 80, GameMode.daily);
      await store.record(game);
      await container
          .read(dailyRankingProvider)
          .onCompleted(game, store.dailyStatus(today));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: Locale(language),
            supportedLocales: const [Locale('en'), Locale('ar')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            theme: appTheme(Brightness.dark),
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: const TextScaler.linear(1.4),
              ),
              child: const DailyScreen(),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(DailyAttemptIndicator), findsOneWidget);
      expect(find.text('1/3'), findsOneWidget);
      expect(find.byType(DailyRankPanel), findsOneWidget);
      expect(find.text('#2'), findsOneWidget);
      expect(
        find.text(language == 'en' ? 'Your best' : 'أفضل نتيجة لك'),
        findsOneWidget,
      );
      expect(
        find.text(language == 'en' ? 'Today’s highest' : 'أعلى نتيجة اليوم'),
        findsOneWidget,
      );
      expect(
        find.text(language == 'en' ? 'This attempt' : 'نتيجة هذه المحاولة'),
        findsNothing,
      );
      expect(find.textContaining('20 participants'), findsNothing);
      expect(find.textContaining('Top 10%'), findsNothing);
      await tester.ensureVisible(find.byType(GamePrimaryButton));
      await tester.pump();
      expect(
        tester.getBottomRight(find.byType(GamePrimaryButton)).dy,
        lessThanOrEqualTo(size.height),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });
  }
}
