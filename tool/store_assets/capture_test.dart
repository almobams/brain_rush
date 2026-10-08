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
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _captureKey = Key('store-capture-boundary');

Future<ByteData> _fontData(String path) async {
  final bytes = await File(path).readAsBytes();
  return ByteData.view(Uint8List.fromList(bytes).buffer);
}

Future<void> _loadCaptureFonts() async {
  final loader = FontLoader('Arial')
    ..addFont(_fontData('/System/Library/Fonts/Supplemental/Arial.ttf'))
    ..addFont(_fontData('/System/Library/Fonts/Supplemental/Arial Bold.ttf'))
    ..addFont(
      _fontData('/System/Library/Fonts/Supplemental/Arial Unicode.ttf'),
    );
  await loader.load();
}

class _DeviceSpec {
  const _DeviceSpec(
    this.platform,
    this.name,
    this.width,
    this.height,
    this.scale,
  );

  final String platform;
  final String name;
  final int width;
  final int height;
  final double scale;
}

const _devices = <_DeviceSpec>[
  _DeviceSpec('ios', 'iphone', 1320, 2868, 3),
  _DeviceSpec('ios', 'ipad', 2064, 2752, 2),
  _DeviceSpec('android', 'phone', 1080, 2400, 3),
  _DeviceSpec('android', 'tablet_7', 1200, 1920, 2),
  _DeviceSpec('android', 'tablet_10', 1600, 2560, 2),
];

enum _CaptureState { home, gameplay, challenges, daily, ranking, results }

class _CapturePurchases extends PurchaseService {
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

class _CaptureAds extends AdService {
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

class _NoNetworkRankingService implements DailyRankingService {
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

class _CaptureRanking extends DailyRankingController {
  _CaptureRanking(SharedPreferences preferences)
    : super(preferences, _NoNetworkRankingService());

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

Map<String, Object?> _savedState(String locale, _CaptureState state) {
  final now = DateTime.now();
  final date = dateKey(now);
  final includeDaily = state == _CaptureState.ranking;
  return {
    'language': locale,
    'onboardingCompleted': true,
    'theme': 'dark',
    'haptics': false,
    'sound': false,
    'playerName': null,
    'stats': {
      'totalGames': 42,
      'bestScore': state == _CaptureState.results ? 34 : 31,
      'totalScore': 890,
      'totalCorrect': 372,
      'totalWrong': 54,
      'longestStreak': 14,
      'dailyStreak': 6,
      'totalXp': state == _CaptureState.results ? 274 : 218,
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

GameController _game(_CaptureState state) {
  final elapsed = state == _CaptureState.gameplay
      ? const Duration(seconds: 16)
      : const Duration(seconds: 28);
  final controller = GameController(
    mode: GameMode.rush,
    date: DateTime(2026, 10, 7, 12),
    elapsed: () => elapsed,
  );
  if (state == _CaptureState.gameplay) {
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
  } else {
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
  controller.start(schedule: false);
  return controller;
}

GameSession _resultSession() {
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

Widget _screen(_CaptureState state) => switch (state) {
  _CaptureState.home => const HomeScreen(),
  _CaptureState.gameplay ||
  _CaptureState.challenges => const GameScreen(mode: GameMode.rush),
  _CaptureState.daily || _CaptureState.ranking => const DailyScreen(),
  _CaptureState.results => ResultsScreen(
    session: _resultSession(),
    award: const ProgressAward(
      earnedXp: 56,
      previousXp: 218,
      totalXp: 274,
      isNewBest: true,
      previousBest: 31,
    ),
  ),
};

String _filename(_CaptureState state) => switch (state) {
  _CaptureState.home => '01_home.png',
  _CaptureState.gameplay => '02_gameplay.png',
  _CaptureState.challenges => '03_challenges.png',
  _CaptureState.daily => '04_daily.png',
  _CaptureState.ranking => '05_ranking.png',
  _CaptureState.results => '06_results.png',
};

Future<void> _capture(
  WidgetTester tester,
  _DeviceSpec device,
  String locale,
  _CaptureState state,
) async {
  // This explicit test entrypoint never ships in the application binary.
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({
    'brain_rush_v1': jsonEncode(_savedState(locale, state)),
  });
  final preferences = await SharedPreferences.getInstance();
  final controller =
      state == _CaptureState.gameplay || state == _CaptureState.challenges
      ? _game(state)
      : null;
  final logicalWidth = device.width / device.scale;
  final logicalHeight = device.height / device.scale;

  await tester.binding.setSurfaceSize(
    Size(device.width.toDouble(), device.height.toDouble()),
  );
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    RepaintBoundary(
      key: _captureKey,
      child: ColoredBox(
        color: gameBackground,
        child: Align(
          alignment: Alignment.topLeft,
          child: Transform.scale(
            scale: device.scale,
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: logicalWidth,
              height: logicalHeight,
              child: ProviderScope(
                overrides: [
                  preferencesProvider.overrideWithValue(preferences),
                  purchaseServiceProvider.overrideWith(
                    (ref) => _CapturePurchases(),
                  ),
                  adServiceProvider.overrideWith((ref) => _CaptureAds()),
                  dailyRankingProvider.overrideWith(
                    (ref) => _CaptureRanking(preferences),
                  ),
                  if (controller != null)
                    gameFactoryProvider.overrideWithValue((mode) => controller),
                ],
                child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: appTheme(Brightness.dark),
                  locale: AppLanguages.localeFor(locale),
                  supportedLocales: AppLanguages.supportedLocales,
                  localizationsDelegates: GlobalMaterialLocalizations.delegates,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      disableAnimations: true,
                      textScaler: TextScaler.noScaling,
                    ),
                    child: child!,
                  ),
                  home: _screen(state),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await expectLater(
    find.byKey(_captureKey),
    matchesGoldenFile(
      '../../store_assets/raw/${device.platform}/$locale/${device.name}/${_filename(state)}',
    ),
  );
  await tester.pumpWidget(const SizedBox.shrink());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadCaptureFonts);
  const deviceFilter = String.fromEnvironment('STORE_DEVICE_FILTER');
  const localeFilter = String.fromEnvironment('STORE_LOCALE_FILTER');

  testWidgets('renders deterministic store captures from production widgets', (
    tester,
  ) async {
    for (final device in _devices) {
      if (deviceFilter.isNotEmpty && device.name != deviceFilter) continue;
      for (final locale in const ['en', 'ar']) {
        if (localeFilter.isNotEmpty && locale != localeFilter) continue;
        for (final state in _CaptureState.values) {
          await _capture(tester, device, locale, state);
        }
      }
    }
    addTearDown(() async {
      tester.view.resetDevicePixelRatio();
      await tester.binding.setSurfaceSize(null);
    });
  });
}
