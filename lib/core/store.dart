import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../game/models.dart';
import '../game/progression.dart';

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
  String language = 'en';
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
      final data = jsonDecode(raw) as Map<String, dynamic>;
      stats = PlayerStats.fromJson(
        Map<String, dynamic>.from(data['stats'] as Map),
      );
      language = data['language'] == 'ar' ? 'ar' : 'en';
      themeMode = ThemeMode.values.firstWhere(
        (t) => t.name == data['theme'],
        orElse: () => ThemeMode.dark,
      );
      haptics = data['haptics'] as bool? ?? true;
      sound = data['sound'] as bool? ?? false;
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

  Future<void> save() {
    final snapshot = jsonEncode({
      'stats': stats.toJson(),
      'daily': daily.map((k, v) => MapEntry(k, v.toJson())),
      'language': language,
      'theme': themeMode.name,
      'haptics': haptics,
      'sound': sound,
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

  Future<ProgressAward> record(GameSession session) async {
    final previousBest = stats.bestScore;
    final previousXp = stats.totalXp;
    final isNewBest = session.score > previousBest;
    final date = dateKey(session.startedAt);
    final earnedXp = const XpPolicy().earned(
      session,
      isNewBest: isNewBest,
      firstDailyCompletion: daily[date] == null,
    );
    stats.totalXp += earnedXp;
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
    if (session.mode == GameMode.daily &&
        (daily[date] == null || session.score > daily[date]!.score)) {
      daily[date] = DailyChallengeResult(
        date,
        session.score,
        session.correctAnswers,
        session.wrongAnswers,
        true,
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
}
