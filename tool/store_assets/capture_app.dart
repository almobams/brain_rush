// Native store-capture entry point. This file is never referenced by lib/main.dart.
// It only runs in a debug build with --dart-define=STORE_CAPTURE=true.
import 'dart:convert';
import 'dart:io';
import 'package:brain_rush/backend/daily_ranking_service.dart';
import 'package:brain_rush/core/store.dart';
import 'package:brain_rush/game/controller.dart';
import 'package:brain_rush/game/models.dart';
import 'package:brain_rush/game/progression.dart';
import 'package:brain_rush/localization/languages.dart';
import 'package:brain_rush/monetization/ad_service.dart';
import 'package:brain_rush/monetization/purchase_service.dart';
import 'package:brain_rush/screens/game_screen.dart';
import 'package:brain_rush/screens/home_screen.dart';
import 'package:brain_rush/screens/results_screen.dart';
import 'package:brain_rush/screens/secondary_screens.dart';
import 'package:brain_rush/theme/app_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum CaptureScene { home, gameplay, challenges, daily, ranking, results, video }

class CapturePurchases extends PurchaseService {
  @override
  bool get owned => true;
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

class CaptureAds extends AdService {
  @override
  bool get privacyChoicesAvailable => false;
  @override
  bool get rewardedReady => false;
  @override
  Future<void> initialize() async {}
  @override
  Future<bool> showInterstitial() async => false;
  @override
  Future<bool> showRewarded() async => false;
  @override
  Future<void> showPrivacyChoices() async {}
}

class NoNetworkRankingService implements DailyRankingService {
  @override
  bool get configured => false;
  @override
  Future<DailyRank?> getRank(String installationId, String date) async => null;
  @override
  Future<int?> submitBest(
    String installationId,
    String date,
    int score,
    int attemptNo,
  ) async => null;
}

class CaptureRanking extends DailyRankingController {
  CaptureRanking(SharedPreferences preferences)
    : super(preferences, NoNetworkRankingService());

  @override
  DailyRank? rankFor(String date) => const DailyRank(
    bestScore: 31,
    highestScore: 47,
    rank: 7,
    participantCount: 128,
    topPercent: 6,
  );
  @override
  bool loadingFor(String date) => false;
  @override
  bool unavailableFor(String date) => false;
  @override
  Future<void> refresh(
    DailyChallengeResult result, {
    bool completedNow = false,
  }) async {}
  @override
  Future<void> refreshRankOnly(DailyChallengeResult result) async {}
}

Map<String, Object?> captureSavedState(String locale, CaptureScene scene) {
  final date = dateKey(DateTime.now());
  final includeDaily =
      scene == CaptureScene.ranking || scene == CaptureScene.video;
  return {
    'language': locale,
    'onboardingCompleted': true,
    'theme': 'dark',
    'haptics': false,
    'sound': false,
    'playerName': null,
    'stats': {
      'totalGames': 42,
      'bestScore': scene == CaptureScene.video
          ? 0
          : scene == CaptureScene.results
          ? 34
          : 31,
      'totalScore': 890,
      'totalCorrect': 372,
      'totalWrong': 54,
      'longestStreak': 14,
      'dailyStreak': 6,
      'totalXp': scene == CaptureScene.results ? 274 : 218,
      'lastPlayedDate': date,
    },
    'daily': includeDaily
        ? {
            date: {
              'date': date,
              'score': 31,
              'correct': 24,
              'wrong': 3,
              'completed': true,
              'attemptsUsed': 2,
              'lastScore': 28,
              'unlockedAttempts': 3,
              'bestAttemptNo': 1,
            },
          }
        : <String, Object?>{},
  };
}

GameController captureGame(CaptureScene scene) {
  final createdAt = DateTime.now();
  Duration elapsed() {
    final real = DateTime.now().difference(createdAt);
    if (scene == CaptureScene.video) {
      return Duration(microseconds: real.inMicroseconds * 6);
    }
    final offset = scene == CaptureScene.gameplay ? 16 : 28;
    return Duration(seconds: offset) + real;
  }

  final controller = GameController(
    mode: GameMode.rush,
    date: DateTime.now(),
    elapsed: elapsed,
  );
  if (scene == CaptureScene.gameplay || scene == CaptureScene.video) {
    controller.question = const BrainQuestion(
      id: 'store-arithmetic',
      type: QuestionType.arithmetic,
      questionText: 'solve',
      expression: '8 × 7 = ?',
      answers: [
        AnswerChoice.number(48),
        AnswerChoice.number(54),
        AnswerChoice.number(56),
        AnswerChoice.number(64),
      ],
      correctAnswerIndex: 2,
      difficulty: 1,
    );
    controller.score = 12;
    controller.streak = 4;
    controller.bestStreak = 4;
  } else if (scene == CaptureScene.challenges) {
    controller.question = const BrainQuestion(
      id: 'store-fraction',
      type: QuestionType.fraction,
      questionText: 'fractionLarger',
      expression: '',
      answers: [
        AnswerChoice.fraction(FractionValue(2, 3)),
        AnswerChoice.fraction(FractionValue(3, 4)),
      ],
      correctAnswerIndex: 1,
      difficulty: 1,
    );
    controller.score = 19;
    controller.streak = 6;
    controller.bestStreak = 6;
  }
  return controller;
}

GameSession captureResultSession() {
  final results = <QuestionResult>[
    for (var index = 0; index < 15; index++)
      QuestionResult(
        'result-$index',
        QuestionType.values[index % QuestionType.values.length],
        index != 11,
        Duration(milliseconds: 720 + index * 55),
        index == 11 ? 0 : 2,
      ),
  ];
  return GameSession(
    id: 'store-result',
    mode: GameMode.rush,
    startedAt: DateTime(2026, 10, 7, 12),
    endedAt: DateTime(2026, 10, 7, 12, 1),
    score: 34,
    bestStreak: 9,
    results: results,
  );
}

Widget captureScreen(CaptureScene scene) => switch (scene) {
  CaptureScene.home || CaptureScene.video => const HomeScreen(),
  CaptureScene.gameplay ||
  CaptureScene.challenges => const GameScreen(mode: GameMode.rush),
  CaptureScene.daily || CaptureScene.ranking => const DailyScreen(),
  CaptureScene.results => ResultsScreen(
    session: captureResultSession(),
    award: const ProgressAward(
      earnedXp: 56,
      previousXp: 218,
      totalXp: 274,
      isNewBest: true,
      previousBest: 31,
    ),
  ),
};

({String locale, CaptureScene scene}) parseCaptureRoute(String route) {
  final parts = route.split('/').where((part) => part.isNotEmpty).toList();
  final locale = parts.isNotEmpty && parts.first == 'ar' ? 'ar' : 'en';
  final requested = parts.length > 1 ? parts[1] : 'home';
  final scene = CaptureScene.values.firstWhere(
    (value) => value.name == requested,
    orElse: () => CaptureScene.home,
  );
  return (locale: locale, scene: scene);
}

Future<Widget> buildCaptureApp(String route) async {
  final configuration = parseCaptureRoute(route);
  // Safe in this isolated capture process and prevents writes to real storage.
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({
    'brain_rush_v1': jsonEncode(
      captureSavedState(configuration.locale, configuration.scene),
    ),
  });
  final preferences = await SharedPreferences.getInstance();
  final needsGame =
      configuration.scene == CaptureScene.gameplay ||
      configuration.scene == CaptureScene.challenges ||
      configuration.scene == CaptureScene.video;
  return ProviderScope(
    overrides: [
      preferencesProvider.overrideWithValue(preferences),
      purchaseServiceProvider.overrideWith((ref) => CapturePurchases()),
      adServiceProvider.overrideWith((ref) => CaptureAds()),
      dailyRankingProvider.overrideWith((ref) => CaptureRanking(preferences)),
      if (needsGame)
        gameFactoryProvider.overrideWithValue(
          (mode) => captureGame(configuration.scene),
        ),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      theme: appTheme(Brightness.dark),
      darkTheme: appTheme(Brightness.dark),
      themeMode: ThemeMode.dark,
      locale: AppLanguages.localeFor(configuration.locale),
      supportedLocales: AppLanguages.supportedLocales,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
        child: child!,
      ),
      home: captureScreen(configuration.scene),
    ),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kReleaseMode || !const bool.fromEnvironment('STORE_CAPTURE')) {
    throw UnsupportedError('The store capture entry point is development-only.');
  }
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  var route = PlatformDispatcher.instance.defaultRouteName;
  for (final argument in Platform.executableArguments) {
    if (argument.startsWith('--capture-route=')) {
      route = argument.substring('--capture-route='.length);
    }
  }
  runApp(await buildCaptureApp(route));
}
