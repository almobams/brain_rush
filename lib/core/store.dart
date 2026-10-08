import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../game/models.dart';
import '../game/progression.dart';
import '../monetization/ad_policy.dart';
import '../localization/languages.dart';

final preferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(),
);
final storeProvider = ChangeNotifierProvider<AppStore>(
  (ref) => AppStore(ref.watch(preferencesProvider)),
);

class AppStore extends ChangeNotifier {
  AppStore(this.preferences) {
    _load();
  }
  final SharedPreferences preferences;
  PlayerStats stats = PlayerStats();
  Map<String, DailyChallengeResult> daily = {};
  AdSchedule adSchedule = AdSchedule();
  final Set<String> claimedXpSessions = {};
  String language = 'en';
  String? playerName;
  bool onboardingCompleted = false;
  bool dailyRemindersEnabled = false;
  bool dailyReminderPromptHandled = false;
  static const maxPlayerNameLength = 20;
  ThemeMode themeMode = ThemeMode.dark;
  bool haptics = true, sound = false, saveFailed = false;
  Future<void> _pending = Future.value();
  bool _disposed = false;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _load() {
    try {
      final raw = preferences.getString('brain_rush_v1');
      if (raw == null) return;
      onboardingCompleted = true;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      // An existing save predates onboarding; never interrupt that player.
      onboardingCompleted = data['onboardingCompleted'] as bool? ?? true;
      dailyRemindersEnabled = data['dailyRemindersEnabled'] as bool? ?? false;
      dailyReminderPromptHandled =
          data['dailyReminderPromptHandled'] as bool? ?? false;
      final savedName = data['playerName'] as String?;
      final trimmedName = savedName?.trim();
      playerName = trimmedName == null || trimmedName.isEmpty
          ? null
          : trimmedName;
      stats = PlayerStats.fromJson(
        Map<String, dynamic>.from(data['stats'] as Map),
      );
      final savedLanguage = data['language'] as String? ?? 'en';
      language = AppLanguages.contains(savedLanguage) ? savedLanguage : 'en';
      themeMode = ThemeMode.values.firstWhere(
        (t) => t.name == data['theme'],
        orElse: () => ThemeMode.dark,
      );
      haptics = data['haptics'] as bool? ?? true;
      sound = data['sound'] as bool? ?? false;
      final ads = data['ads'] as Map? ?? {};
      adSchedule = AdSchedule(
        normalGames: ads['normalGames'] as int? ?? 0,
        lastShownGame: ads['lastShownGame'] as int? ?? 0,
        lastShownAt: DateTime.tryParse(ads['lastShownAt'] as String? ?? ''),
      );
      claimedXpSessions.addAll(
        (data['claimedXpSessions'] as List? ?? []).whereType<String>(),
      );
      final saved = data['daily'] as Map? ?? {};
      daily = saved.map(
        (key, value) => MapEntry(
          key.toString(),
          DailyChallengeResult.fromJson(
            Map<String, dynamic>.from(value as Map),
          ),
        ),
      );
    } catch (_) {
      saveFailed = true;
    }
  }

  int get currentDailyStreak {
    final last = DateTime.tryParse(stats.lastPlayedDate ?? '');
    if (last == null) return 0;
    final today = DateTime.now();
    final days = DateTime.utc(
      today.year,
      today.month,
      today.day,
    ).difference(DateTime.utc(last.year, last.month, last.day)).inDays;
    return days > 1 ? 0 : stats.dailyStreak;
  }

  DailyChallengeResult dailyStatus(DateTime date) =>
      daily[dateKey(date)] ??
      DailyChallengeResult(dateKey(date), 0, 0, 0, false, attemptsUsed: 0);

  bool canStartDaily(DateTime date, {required bool removeAdsOwned}) {
    final result = dailyStatus(date);
    return result.attemptsUsed < 3 &&
        (removeAdsOwned || result.attemptsUsed < result.unlockedAttempts);
  }

  Future<bool> unlockDailyRetry(DateTime date) async {
    final key = dateKey(date);
    final result = daily[key];
    if (result == null ||
        result.attemptsUsed == 0 ||
        result.attemptsUsed >= 3 ||
        result.unlockedAttempts > result.attemptsUsed) {
      return false;
    }
    daily[key] = result.copyWith(unlockedAttempts: result.attemptsUsed + 1);
    await save();
    return true;
  }

  Future<void> save() {
    final snapshot = jsonEncode({
      'stats': stats.toJson(),
      'daily': daily.map((k, v) => MapEntry(k, v.toJson())),
      'language': language,
      'playerName': playerName,
      'onboardingCompleted': onboardingCompleted,
      'dailyRemindersEnabled': dailyRemindersEnabled,
      'dailyReminderPromptHandled': dailyReminderPromptHandled,
      'theme': themeMode.name,
      'haptics': haptics,
      'sound': sound,
      'ads': {
        'normalGames': adSchedule.normalGames,
        'lastShownGame': adSchedule.lastShownGame,
        'lastShownAt': adSchedule.lastShownAt?.toIso8601String(),
      },
      'claimedXpSessions': claimedXpSessions.toList(),
    });
    _pending = _pending.then((_) async {
      try {
        saveFailed = !await preferences.setString('brain_rush_v1', snapshot);
      } catch (_) {
        saveFailed = true;
      }
      _notify();
    });
    _notify();
    return _pending;
  }

  Future<void> setLanguage(String code) {
    if (!AppLanguages.contains(code)) throw ArgumentError.value(code, 'code');
    language = code;
    return save();
  }

  Future<bool> setPlayerName(String? value) async {
    final trimmed = value?.trim();
    if (trimmed != null &&
        (trimmed.isEmpty || trimmed.runes.length > maxPlayerNameLength)) {
      return false;
    }
    playerName = trimmed;
    await save();
    return true;
  }

  Future<void> completeOnboarding() {
    onboardingCompleted = true;
    return save();
  }

  Future<ProgressAward> record(GameSession session) async {
    final previousBest = stats.bestScore;
    final previousXp = stats.totalXp;
    final isNewBest = session.score > previousBest;
    final date = dateKey(session.startedAt);
    final previousDaily = daily[date];
    if (session.mode == GameMode.daily &&
        (previousDaily?.attemptsUsed ?? 0) >= 3) {
      throw StateError('Daily Challenge attempts exhausted for $date');
    }
    final earnedXp = const XpPolicy().earned(
      session,
      isNewBest: isNewBest,
      firstDailyCompletion: (previousDaily?.attemptsUsed ?? 0) == 0,
    );
    stats.totalXp += earnedXp;
    adSchedule.completed(session.mode);
    stats.totalGames++;
    stats.totalScore += session.score;
    stats.bestScore = max(stats.bestScore, session.score);
    stats.totalCorrect += session.correctAnswers;
    stats.totalWrong += session.wrongAnswers;
    stats.longestStreak = max(stats.longestStreak, session.bestStreak);
    if (stats.lastPlayedDate != date) {
      final yesterday = dateKey(
        DateTime(
          session.startedAt.year,
          session.startedAt.month,
          session.startedAt.day - 1,
        ),
      );
      stats.dailyStreak = stats.lastPlayedDate == yesterday
          ? stats.dailyStreak + 1
          : 1;
      stats.lastPlayedDate = date;
    }
    if (session.mode == GameMode.daily) {
      final completedAttemptNo = (previousDaily?.attemptsUsed ?? 0) + 1;
      final isDailyBest =
          previousDaily == null || session.score > previousDaily.score;
      daily[date] = DailyChallengeResult(
        date,
        isDailyBest ? session.score : previousDaily.score,
        isDailyBest ? session.correctAnswers : previousDaily.correct,
        isDailyBest ? session.wrongAnswers : previousDaily.wrong,
        true,
        attemptsUsed: completedAttemptNo,
        lastScore: session.score,
        unlockedAttempts: previousDaily?.unlockedAttempts ?? 1,
        bestAttemptNo: isDailyBest
            ? completedAttemptNo
            : previousDaily.bestAttemptNo,
      );
    }
    // Keep a bounded local history; aggregate statistics remain lifetime totals.
    if (daily.length > 90) {
      final keys = daily.keys.toList()..sort();
      for (final key in keys.take(daily.length - 90)) {
        daily.remove(key);
      }
    }
    await save();
    return ProgressAward(
      earnedXp: earnedXp,
      previousXp: previousXp,
      totalXp: stats.totalXp,
      isNewBest: isNewBest,
      previousBest: previousBest,
    );
  }

  Future<bool> claimXpBonus(String sessionId, int xp) async {
    if (xp <= 0 || !claimedXpSessions.add(sessionId)) return false;
    stats.totalXp += xp;
    await save();
    return true;
  }

  Future<void> markInterstitialShown(DateTime when) async {
    adSchedule.shown(when);
    await save();
  }
}
