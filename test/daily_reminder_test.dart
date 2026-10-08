import 'dart:io';

import 'package:brain_rush/core/store.dart';
import 'package:brain_rush/game/models.dart';
import 'package:brain_rush/localization/languages.dart';
import 'package:brain_rush/main.dart';
import 'package:brain_rush/reminders/daily_reminder_service.dart';
import 'package:brain_rush/reminders/reminder_strings.dart';
import 'package:brain_rush/screens/secondary_screens.dart';
import 'package:brain_rush/sharing/result_share_service.dart';
import 'package:brain_rush/sharing/result_share_data.dart';
import 'package:brain_rush/sharing/share_links.dart';
import 'package:brain_rush/game/progression.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeReminderPlatform implements ReminderPlatform {
  @override
  bool supported = true;
  bool granted = false;
  bool requestResult = true;
  int requests = 0;
  int initializations = 0;
  String zone = 'Asia/Riyadh';
  String? initialPayload;
  bool failSchedule = false;
  final Map<int, ScheduledDailyReminder> pending = {};
  final List<int> canceled = [];
  void Function(String?)? onTap;

  @override
  Future<void> initialize(void Function(String?) callback) async {
    initializations++;
    onTap = callback;
  }

  @override
  Future<String?> launchPayload() async => initialPayload;
  @override
  Future<bool> permissionGranted() async => granted;
  @override
  Future<bool> requestPermission() async {
    requests++;
    granted = requestResult;
    return granted;
  }

  @override
  Future<String> configureLocalTimeZone() async => zone;
  @override
  Future<Set<int>> pendingIds() async => pending.keys.toSet();
  @override
  Future<void> schedule(ScheduledDailyReminder reminder) async {
    if (failSchedule) throw StateError('Scheduling failed');
    pending[reminder.id] = reminder;
  }

  @override
  Future<void> cancel(int id) async {
    canceled.add(id);
    pending.remove(id);
  }
}

GameSession completed(DateTime when, GameMode mode) => GameSession(
  id: '${when.microsecondsSinceEpoch}-${mode.name}',
  mode: mode,
  startedAt: when,
  endedAt: when.add(const Duration(seconds: 60)),
  score: 10,
  bestStreak: 0,
  results: const [],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'disabled schedules nothing; opt-in creates 30 dated reminders before 1 PM',
    () async {
      final store = AppStore(await SharedPreferences.getInstance());
      final platform = FakeReminderPlatform();
      final clock = DateTime(2026, 10, 4, 10);
      final service = DailyReminderService(
        store: store,
        platform: platform,
        now: () => clock,
      );
      await service.initialize();
      expect(platform.pending, isEmpty);
      expect(platform.requests, 0);
      expect(await service.enable(), isTrue);
      expect(platform.requests, 1);
      expect(platform.pending.length, 30);
      final todayId = DailyReminderIds.forDate(clock);
      expect(todayId, 120261004);
      expect(platform.pending[todayId]?.date.hour, 0);
      expect(platform.pending[todayId]?.payload, 'daily_challenge:2026-10-04');
      expect(platform.pending[todayId]?.body, contains('Daily Challenge'));
      expect(platform.pending.values.map((item) => item.id).toSet().length, 30);
      expect(DailyReminderIds.owns(todayId), isTrue);
      expect(DailyReminderIds.owns(42), isFalse);
      service.dispose();
      store.dispose();
    },
  );

  test('first Daily completion cancels today; Rush and later attempts do not alter tomorrow', () async {
    final store = AppStore(await SharedPreferences.getInstance());
    final platform = FakeReminderPlatform()..granted = true;
    final clock = DateTime(2026, 10, 4, 10);
    final service = DailyReminderService(
      store: store,
      platform: platform,
      now: () => clock,
    );
    await service.initialize();
    await service.enable();
    final todayId = DailyReminderIds.forDate(clock);
    final tomorrowId = DailyReminderIds.forDate(DateTime(2026, 10, 5));
    // Starting and abandoning a Daily game does not record a completed attempt.
    expect(store.dailyStatus(clock).attemptsUsed, 0);
    expect(platform.pending.containsKey(todayId), isTrue);
    await store.record(completed(clock, GameMode.rush));
    expect(platform.pending.containsKey(todayId), isTrue);
    expect(platform.canceled, isNot(contains(todayId)));
    await store.record(completed(clock, GameMode.daily));
    await service.refresh();
    expect(platform.pending.containsKey(todayId), isFalse);
    expect(platform.pending.containsKey(tomorrowId), isTrue);
    expect(platform.pending.length, 30);
    final cancellations = platform.canceled.where((id) => id == todayId).length;
    await store.record(
      completed(clock.add(const Duration(minutes: 2)), GameMode.daily),
    );
    await store.record(
      completed(clock.add(const Duration(minutes: 4)), GameMode.daily),
    );
    expect(
      platform.canceled.where((id) => id == todayId).length,
      cancellations,
    );
    expect(platform.pending.containsKey(tomorrowId), isTrue);
    service.dispose();
    store.dispose();
  });

  test(
    'after 1 PM today is omitted and a later completion preserves tomorrow',
    () async {
      final store = AppStore(await SharedPreferences.getInstance());
      final platform = FakeReminderPlatform()..granted = true;
      final clock = DateTime(2026, 10, 4, 16);
      final service = DailyReminderService(
        store: store,
        platform: platform,
        now: () => clock,
      );
      await service.initialize();
      await service.enable();
      expect(platform.pending.length, 30);
      expect(
        platform.pending.containsKey(DailyReminderIds.forDate(clock)),
        isFalse,
      );
      final tomorrowId = DailyReminderIds.forDate(DateTime(2026, 10, 5));
      await store.record(completed(clock, GameMode.daily));
      await service.refresh();
      expect(platform.pending.containsKey(tomorrowId), isTrue);
      service.dispose();
      store.dispose();
    },
  );

  test(
    'locale, name, timezone, and later resume refresh pending copy',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final store = AppStore(prefs);
      final platform = FakeReminderPlatform()..granted = true;
      var clock = DateTime(2026, 10, 4, 10);
      final service = DailyReminderService(
        store: store,
        platform: platform,
        now: () => clock,
      );
      await service.initialize();
      await service.enable();
      final firstId = DailyReminderIds.forDate(clock);
      expect(
        platform.pending[firstId]?.body,
        'Your Daily Challenge is waiting 🧠',
      );
      await store.setPlayerName('محمد');
      await store.setLanguage('ar');
      await service.refresh();
      expect(platform.pending[firstId]?.body, startsWith('محمد،'));
      expect(platform.pending[firstId]?.language, 'ar');
      platform.zone = 'Europe/Berlin';
      clock = DateTime(2026, 11, 14, 9);
      await service.refresh();
      expect(service.currentTimeZone, 'Europe/Berlin');
      expect(platform.pending.length, 30);
      expect(platform.pending.containsKey(firstId), isFalse);
      expect(
        platform.pending.containsKey(DailyReminderIds.forDate(clock)),
        isTrue,
      );
      expect(platform.requests, 0);
      service.dispose();
      store.dispose();
    },
  );

  test('denied or revoked permission leaves the preference off and cancels reminders', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = AppStore(prefs);
    final platform = FakeReminderPlatform()..requestResult = false;
    final service = DailyReminderService(
      store: store,
      platform: platform,
      now: () => DateTime(2026, 10, 4, 10),
    );
    await service.initialize();
    expect(await service.enable(), isFalse);
    expect(store.dailyRemindersEnabled, isFalse);
    expect(store.dailyReminderPromptHandled, isTrue);
    expect(platform.pending, isEmpty);
    platform.granted = true;
    await service.enable();
    expect(store.dailyRemindersEnabled, isTrue);
    platform.granted = false;
    await service.refresh();
    expect(store.dailyRemindersEnabled, isFalse);
    expect(platform.pending, isEmpty);
    service.dispose();
    store.dispose();
  });

  test('scheduling failure reverts the preference and leaves no reminders', () async {
    final store = AppStore(await SharedPreferences.getInstance());
    final platform = FakeReminderPlatform()
      ..granted = true
      ..failSchedule = true;
    final service = DailyReminderService(
      store: store,
      platform: platform,
      now: () => DateTime(2026, 10, 4, 10),
    );
    expect(await service.enable(), isFalse);
    expect(store.dailyRemindersEnabled, isFalse);
    expect(platform.pending, isEmpty);
    expect(service.lastError, isA<StateError>());
    service.dispose();
    store.dispose();
  });

  test(
    'preference persists, startup refills, and disable cancels only owned IDs',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final first = AppStore(prefs);
      final platform = FakeReminderPlatform()..granted = true;
      final service = DailyReminderService(
        store: first,
        platform: platform,
        now: () => DateTime(2026, 10, 4, 10),
      );
      await service.initialize();
      await service.enable();
      platform.pending[42] = ScheduledDailyReminder(
        id: 42,
        date: nullDate,
        title: 'Other',
        body: 'Other',
        payload: 'other',
        language: 'en',
      );
      service.dispose();
      first.dispose();
      SharedPreferences.resetStatic();
      final restored = AppStore(await SharedPreferences.getInstance());
      expect(restored.dailyRemindersEnabled, isTrue);
      expect(restored.dailyReminderPromptHandled, isTrue);
      final second = DailyReminderService(
        store: restored,
        platform: platform,
        now: () => DateTime(2026, 10, 10, 9),
      );
      await second.initialize();
      expect(platform.pending.length, 31);
      expect(platform.pending.containsKey(42), isTrue);
      await second.disable();
      expect(restored.dailyRemindersEnabled, isFalse);
      expect(platform.pending.keys, [42]);
      second.dispose();
      restored.dispose();
    },
  );

  test('18 languages have complete notification copy and no Hebrew', () {
    final expected = ReminderStrings.all['en']!.keys.toSet();
    expect(
      ReminderStrings.all.keys.toSet(),
      AppLanguages.all.map((e) => e.code).toSet(),
    );
    expect(ReminderStrings.all.containsKey('he'), isFalse);
    for (final entry in ReminderStrings.all.entries) {
      expect(entry.value.keys.toSet(), expected, reason: entry.key);
      expect(
        entry.value.values.every((value) => value.trim().isNotEmpty),
        isTrue,
      );
      expect(entry.value['notificationBodyNamed'], contains('{name}'));
    }
    expect(AppLanguages.isRtl('ar'), isTrue);
    expect(AppLanguages.isRtl('ur'), isTrue);
    expect(AppLanguages.isRtl('fa'), isTrue);
  });

  test('tap payload targets Daily without private data', () async {
    final store = AppStore(await SharedPreferences.getInstance());
    final platform = FakeReminderPlatform()
      ..granted = true
      ..initialPayload = 'daily_challenge:2026-10-04';
    final service = DailyReminderService(
      store: store,
      platform: platform,
      now: () => DateTime(2026, 10, 4, 10),
    );
    await service.initialize();
    expect(service.consumeDailyNavigation(), isTrue);
    expect(service.consumeDailyNavigation(), isFalse);
    platform.onTap?.call('other:2026-10-04');
    expect(service.pendingDailyNavigation, isFalse);
    platform.onTap?.call('daily_challenge:2026-10-05');
    expect(service.pendingDailyNavigation, isTrue);
    service.dispose();
    store.dispose();
  });

  testWidgets(
    'small-screen opt-in offers a choice without auto-requesting OS permission',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final prefs = await SharedPreferences.getInstance();
      final store = AppStore(prefs);
      store.onboardingCompleted = true;
      store.language = 'de';
      final platform = FakeReminderPlatform();
      final service = DailyReminderService(
        store: store,
        platform: platform,
        now: () => DateTime(2026, 10, 4, 10),
      );
      final scoped = ProviderContainer(
        overrides: [
          preferencesProvider.overrideWithValue(prefs),
        dailyReminderServiceProvider.overrideWith((ref) => service),
        storeProvider.overrideWith((ref) => store),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: scoped,
          child: const BrainRushApp(initializeReminders: true),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Verpass die heutige Aufgabe nicht'), findsOneWidget);
      expect(platform.requests, 0);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Jetzt nicht'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(store.dailyReminderPromptHandled, isTrue);
      expect(platform.requests, 0);
      await tester.pumpWidget(const SizedBox());
      scoped.dispose();
    },
  );

  testWidgets('notification launch opens Daily Challenge after app initialization', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final store = AppStore(prefs)
      ..onboardingCompleted = true
      ..dailyReminderPromptHandled = true;
    final platform = FakeReminderPlatform()
      ..initialPayload = 'daily_challenge:2026-10-04';
    final service = DailyReminderService(store: store, platform: platform);
    final scoped = ProviderContainer(
      overrides: [
        preferencesProvider.overrideWithValue(prefs),
        storeProvider.overrideWith((ref) => store),
        dailyReminderServiceProvider.overrideWith((ref) => service),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: scoped,
        child: const BrainRushApp(initializeReminders: true),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(find.byType(DailyScreen), findsOneWidget);
    expect(service.pendingDailyNavigation, isFalse);
    expect(platform.requests, 0);
    await tester.pumpWidget(const SizedBox());
    scoped.dispose();
  });

  test(
    'static Hosting page and central link configuration remain store-agnostic',
    () {
      final home = File('hosting/public/index.html').readAsStringSync();
      final go = File('hosting/public/go/index.html').readAsStringSync();
      final config = File('hosting/public/store-links.js').readAsStringSync();
      final script = File('hosting/public/go/app.js').readAsStringSync();
      final english = File('hosting/public/privacy/index.html')
          .readAsStringSync();
      final arabic = File('hosting/public/privacy/ar/index.html')
          .readAsStringSync();
      expect(home, contains('app-home.png'));
      expect(
        File('hosting/public/assets/app-home.png').lengthSync(),
        greaterThan(10000),
      );
      expect(go, contains('Coming'));
      expect(config, contains("APP_STORE_URL: ''"));
      expect(config, contains("PLAY_STORE_URL: ''"));
      expect(script, contains('window.location.replace'));
      expect(english, contains('almobams1@gmail.com'));
      expect(arabic, contains('almobams1@gmail.com'));
      expect(
        ShareLinks.shareUrl,
        'https://brain-rush-almobairik.web.app/go/',
      );
      final rush = ResultShareData.rush(
        session: completed(DateTime(2026, 10, 4), GameMode.rush),
        award: const ProgressAward(
          earnedXp: 0,
          previousXp: 0,
          totalXp: 0,
          isNewBest: false,
          previousBest: 0,
        ),
        personalBest: 10,
      );
      final daily = ResultShareData.daily(
        result: DailyChallengeResult(
          '2026-10-04',
          10,
          0,
          0,
          true,
          attemptsUsed: 1,
        ),
      );
      final link = ShareLinks.shareUrl!;
      final sharing = ResultShareService();
      expect(sharing.caption(rush, 'en', url: link).split(link).length, 2);
      expect(sharing.caption(daily, 'ar', url: link).split(link).length, 2);
      expect(sharing.caption(rush, 'en', url: link), endsWith(link));
      expect(sharing.caption(daily, 'ar', url: link), endsWith(link));
    },
  );
}

final nullDate = DateTime(2026, 10, 4);
