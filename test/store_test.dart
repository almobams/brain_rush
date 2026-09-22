import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:brain_rush/core/store.dart';
import 'package:brain_rush/game/models.dart';
import 'package:brain_rush/game/progression.dart';

GameSession session(
  DateTime date,
  int score, {
  GameMode mode = GameMode.rush,
}) => GameSession(
  id: date.toString(),
  mode: mode,
  startedAt: date,
  endedAt: date.add(const Duration(seconds: 60)),
  score: score,
  bestStreak: score,
  results: List.generate(
    score,
    (_) => const QuestionResult(
      'q',
      QuestionType.larger,
      true,
      Duration(seconds: 1),
      1,
    ),
  ),
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'Persists statistics, settings, streaks, and daily best across reloads',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final store = AppStore(prefs);
      final date = DateTime(2026, 9, 19);
      await store.record(session(date, 10, mode: GameMode.daily));
      await store.record(session(date, 5, mode: GameMode.daily));
      expect(store.stats.dailyStreak, 1);
      expect(store.daily[dateKey(date)]!.score, 10);
      await store.record(session(date.add(const Duration(days: 1)), 4));
      expect(store.stats.dailyStreak, 2);
      store.language = 'ar';
      store.haptics = false;
      store.sound = true;
      store.themeMode = ThemeMode.light;
      await store.save();
      SharedPreferences.resetStatic();
      final reloaded = AppStore(await SharedPreferences.getInstance());
      expect(reloaded.stats.totalGames, 3);
      expect(reloaded.stats.totalCorrect, 19);
      expect(reloaded.stats.bestScore, 10);
      expect(reloaded.stats.totalXp, greaterThan(0));
      expect(reloaded.stats.averageScore, 19 / 3);
      expect(reloaded.language, 'ar');
      expect(reloaded.haptics, false);
      expect(reloaded.sound, true);
      expect(reloaded.themeMode, ThemeMode.light);
      expect(reloaded.daily.length, 1);
      await reloaded.record(session(date.add(const Duration(days: 4)), 1));
      expect(reloaded.stats.dailyStreak, 1);
      store.dispose();
      reloaded.dispose();
    },
  );
  test('Corrupt local data safely falls back without crashing', () async {
    SharedPreferences.setMockInitialValues({'brain_rush_v1': 'broken json'});
    final store = AppStore(await SharedPreferences.getInstance());
    expect(store.stats.totalGames, 0);
    expect(store.saveFailed, true);
    store.dispose();
  });
  test('Queued saves complete safely after store disposal', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = AppStore(prefs);
    store.language = 'ar';
    final first = store.save();
    store.haptics = false;
    final second = store.save();
    store.dispose();
    await Future.wait([first, second]);
    SharedPreferences.resetStatic();
    final restored = AppStore(await SharedPreferences.getInstance());
    expect(restored.language, 'ar');
    expect(restored.haptics, false);
    expect(restored.saveFailed, false);
    restored.dispose();
  });

  test('Old saves without XP migrate to level one', () async {
    SharedPreferences.setMockInitialValues({
      'brain_rush_v1':
          '{"stats":{"totalGames":4,"bestScore":12},"language":"ar"}',
    });
    final store = AppStore(await SharedPreferences.getInstance());
    expect(store.stats.totalGames, 4);
    expect(store.stats.totalXp, 0);
    expect(const XpPolicy().levelFor(store.stats.totalXp), 1);
    await store.record(session(DateTime(2026, 9, 21), 3));
    expect(store.stats.totalXp, greaterThan(0));
    store.dispose();
  });

  test('XP awards include new-best and Daily bonuses', () async {
    final store = AppStore(await SharedPreferences.getInstance());
    final date = DateTime(2026, 9, 21);
    final first = await store.record(session(date, 4));
    expect(first.earnedXp, 12 + 4 * 2 + 20);
    expect(first.isNewBest, true);
    final daily = await store.record(session(date, 3, mode: GameMode.daily));
    expect(daily.earnedXp, 12 + 3 * 2 + 15);
    expect(daily.isNewBest, false);
    final replay = await store.record(session(date, 2, mode: GameMode.daily));
    expect(replay.earnedXp, 12 + 2 * 2);
    expect(
      store.stats.totalXp,
      first.earnedXp + daily.earnedXp + replay.earnedXp,
    );
    store.dispose();
  });

  test('XP level and rank transitions derive from total XP', () {
    const policy = XpPolicy();
    expect(policy.levelFor(0), 1);
    expect(policy.levelFor(79), 1);
    expect(policy.levelFor(80), 2);
    expect(policy.levelFor(180), 3);
    expect(policy.rankKey(2), 'rankWarmUp');
    expect(policy.rankKey(3), 'rankQuickThinker');
    expect(policy.rankKey(6), 'rankSharpMind');
    expect(policy.rankKey(10), 'rankBrainRacer');
    expect(policy.rankKey(15), 'rankLightningMind');
    expect(policy.rankKey(20), 'rankBrainMaster');
    const award = ProgressAward(
      earnedXp: 20,
      previousXp: 170,
      totalXp: 190,
      isNewBest: false,
      previousBest: 10,
    );
    expect(award.leveledUp, true);
    expect(award.rankChanged, true);
  });
}
