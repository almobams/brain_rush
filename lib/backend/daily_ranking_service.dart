import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/store.dart';
import '../game/models.dart';
import 'supabase_config.dart';

void _rankingDebug(String message) {
  if (kDebugMode) debugPrint('[BrainRush Ranking] $message');
}

class DailyRank {
  const DailyRank({
    required this.bestScore,
    required this.highestScore,
    required this.rank,
    required this.participantCount,
    required this.topPercent,
  });

  final int bestScore;
  final int highestScore;
  final int rank;
  final int participantCount;
  final int topPercent;

  factory DailyRank.fromJson(Map<String, dynamic> data) {
    int number(String key) {
      final value = data[key];
      if (value is! int) throw FormatException('Invalid $key in Daily rank');
      return value;
    }

    final result = DailyRank(
      bestScore: number('best_score'),
      highestScore: number('highest_score'),
      rank: number('rank'),
      participantCount: number('participant_count'),
      topPercent: number('top_percent'),
    );
    if (result.bestScore < 0 ||
        result.highestScore < result.bestScore ||
        result.rank < 1 ||
        result.rank > result.participantCount ||
        result.topPercent < 1 ||
        result.topPercent > 100) {
      throw const FormatException('Invalid Daily rank response');
    }
    return result;
  }
}

class InstallationIdentity {
  InstallationIdentity(this.preferences);

  static const key = 'brain_rush_installation_id';
  final SharedPreferences preferences;
  String? _cached;

  Future<String> getOrCreate() async {
    final existing = _cached ?? preferences.getString(key);
    if (existing != null &&
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ).hasMatch(existing)) {
      return _cached = existing;
    }
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    final id =
        '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
    if (!await preferences.setString(key, id)) {
      throw StateError('Could not persist installation ID');
    }
    return _cached = id;
  }
}

abstract class DailyRankingService {
  bool get configured;
  Future<int?> submitBest(
    String installationId,
    String date,
    int score,
    int attemptNo,
  );
  Future<DailyRank?> getRank(String installationId, String date);
}

class SupabaseDailyRankingService implements DailyRankingService {
  SupabaseDailyRankingService({
    this.url = const String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: SupabaseConfig.productionUrl,
    ),
    this.anonKey = const String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: SupabaseConfig.productionAnonKey,
    ),
  });

  final String url;
  final String anonKey;
  SupabaseClient? _client;

  @override
  bool get configured {
    final uri = Uri.tryParse(url);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        anonKey.isNotEmpty;
  }

  SupabaseClient get _api => _client ??= SupabaseClient(url, anonKey);

  @override
  Future<int?> submitBest(
    String installationId,
    String date,
    int score,
    int attemptNo,
  ) async {
    if (!configured) return null;
    final result = await _api.rpc(
      'submit_daily_score',
      params: {
        'p_installation_id': installationId,
        'p_challenge_date': date,
        'p_score': score,
        'p_attempt_no': attemptNo,
      },
    );
    return (result as num).toInt();
  }

  @override
  Future<DailyRank?> getRank(String installationId, String date) async {
    if (!configured) return null;
    final result = await _api.rpc(
      'get_daily_rank',
      params: {'p_installation_id': installationId, 'p_challenge_date': date},
    );
    if (result is List && result.isEmpty) return null;
    final row = result is List ? result.single : result;
    return DailyRank.fromJson(Map<String, dynamic>.from(row as Map));
  }
}

final dailyRankingServiceProvider = Provider<DailyRankingService>(
  (ref) => SupabaseDailyRankingService(),
);

final dailyRankingProvider = ChangeNotifierProvider<DailyRankingController>((
  ref,
) {
  return DailyRankingController(
    ref.watch(preferencesProvider),
    ref.watch(dailyRankingServiceProvider),
  );
});

class DailyRankingController extends ChangeNotifier {
  DailyRankingController(this.preferences, this.service)
    : identity = InstallationIdentity(preferences);

  final SharedPreferences preferences;
  final DailyRankingService service;
  final InstallationIdentity identity;
  final Map<String, DailyRank> _ranks = {};
  final Set<String> _loading = {};
  final Set<String> _unavailable = {};
  final Map<String, Future<void>> _operations = {};
  bool _disposed = false;

  DailyRank? rankFor(String date) => _ranks[date];
  bool loadingFor(String date) => _loading.contains(date);
  bool unavailableFor(String date) => _unavailable.contains(date);

  Future<void> onCompleted(GameSession session, DailyChallengeResult? result) {
    if (session.mode != GameMode.daily ||
        result == null ||
        !result.completed ||
        result.date != dateKey(session.startedAt)) {
      return Future.value();
    }
    return refresh(result, completedNow: true);
  }

  Future<void> refresh(
    DailyChallengeResult result, {
    bool completedNow = false,
  }) {
    if (_disposed || !result.completed) return Future.value();
    final date = result.date;
    // Serialize operations per day. A higher retry score then sees the first
    // submission's persisted marker and cannot be lost to a network race.
    final previous = _operations[date] ?? Future.value();
    final operation = previous.then((_) => _sync(result, completedNow));
    _operations[date] = operation;
    unawaited(
      operation.then((_) {
        if (identical(_operations[date], operation)) _operations.remove(date);
      }),
    );
    return operation;
  }

  /// Refreshes the displayed rank without retrying a score submission.
  Future<void> refreshRankOnly(DailyChallengeResult result) {
    if (_disposed || !result.completed) return Future.value();
    final date = result.date;
    final previous = _operations[date] ?? Future.value();
    final operation = previous.then((_) => _fetchRankOnly(date));
    _operations[date] = operation;
    unawaited(
      operation.then((_) {
        if (identical(_operations[date], operation)) _operations.remove(date);
      }),
    );
    return operation;
  }

  Future<void> _fetchRankOnly(String date) async {
    _loading.add(date);
    _unavailable.remove(date);
    _notify();
    try {
      if (!service.configured) throw StateError('Ranking not configured');
      final id = await identity.getOrCreate();
      _rankingDebug('rank fetch started: challengeDate=$date');
      final rank = await service
          .getRank(id, date)
          .timeout(const Duration(seconds: 8));
      if (rank == null) throw StateError('Daily rank unavailable');
      _ranks[date] = rank;
      _rankingDebug(
        'rank fetch succeeded: rank=${rank.rank}, '
        'highestScore=${rank.highestScore}, '
        'participantCount=${rank.participantCount}, '
        'topPercent=${rank.topPercent}',
      );
    } catch (error) {
      _logError('rank fetch', error);
      _unavailable.add(date);
    } finally {
      _loading.remove(date);
      _notify();
    }
  }

  String _safeErrorText(Object? value) {
    var message = '$value';
    final key = service is SupabaseDailyRankingService
        ? (service as SupabaseDailyRankingService).anonKey
        : '';
    if (key.isNotEmpty) message = message.replaceAll(key, '[redacted]');
    return message;
  }

  void _logError(String stage, Object error) {
    if (!kDebugMode) return;
    _rankingDebug(
      '$stage failed: type=${error.runtimeType}, message=${_safeErrorText(error)}',
    );
    if (error is PostgrestException) {
      _rankingDebug(
        '$stage PostgREST: code=${_safeErrorText(error.code)}, '
        'message=${_safeErrorText(error.message)}, '
        'details=${_safeErrorText(error.details)}, '
        'hint=${_safeErrorText(error.hint)}',
      );
    }
  }

  Future<void> _sync(DailyChallengeResult result, bool completedNow) async {
    final date = result.date;
    _loading.add(date);
    _unavailable.remove(date);
    _notify();
    var stage = 'configuration';
    try {
      final host = service is SupabaseDailyRankingService
          ? (Uri.tryParse((service as SupabaseDailyRankingService).url)?.host ??
                'invalid')
          : 'custom';
      _rankingDebug('configured=${service.configured}, host=$host');
      stage = 'installation ID';
      final id = await identity.getOrCreate();
      if (completedNow) {
        _rankingDebug(
          'daily completion: challengeDate=$date, score=${result.lastScore}, '
          'localBest=${result.score}, bestAttemptNo=${result.bestAttemptNo}, '
          'completedAttemptNo=${result.attemptsUsed}, installationId=$id',
        );
      }
      stage = 'configuration';
      if (!service.configured) throw StateError('Ranking not configured');
      final syncKey = 'brain_rush_rank_synced_${id}_$date';
      final syncedScore = preferences.getInt(syncKey) ?? -1;
      if (syncedScore < result.score) {
        stage = 'submit';
        _rankingDebug(
          'submit started: challengeDate=$date, score=${result.score}, '
          'bestAttemptNo=${result.bestAttemptNo}',
        );
        final stored = await service
            .submitBest(id, date, result.score, result.bestAttemptNo)
            .timeout(const Duration(seconds: 8));
        if (stored == null || stored < result.score) {
          throw const FormatException('Invalid Daily score response');
        }
        _rankingDebug('submit succeeded: authoritativeBest=$stored');
        await preferences.setInt(syncKey, stored);
      } else {
        _rankingDebug(
          'submit skipped: ${completedNow && result.lastScore <= syncedScore ? 'completed score did not improve an already synced best' : 'local best already synced'} '
          '(syncedScore=$syncedScore, localBest=${result.score})',
        );
      }
      stage = 'rank fetch';
      _rankingDebug('rank fetch started: challengeDate=$date');
      final rank = await service
          .getRank(id, date)
          .timeout(const Duration(seconds: 8));
      if (rank == null) throw StateError('Daily rank unavailable');
      _ranks[date] = rank;
      _rankingDebug(
        'rank fetch succeeded: rank=${rank.rank}, '
        'highestScore=${rank.highestScore}, '
        'participantCount=${rank.participantCount}, '
        'topPercent=${rank.topPercent}',
      );
    } catch (error) {
      _logError(stage, error);
      _unavailable.add(date);
    } finally {
      _loading.remove(date);
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
