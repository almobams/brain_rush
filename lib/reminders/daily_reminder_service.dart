import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../core/store.dart';
import '../game/models.dart';
import 'reminder_strings.dart';

final dailyReminderServiceProvider =
    ChangeNotifierProvider<DailyReminderService>(
      (ref) => DailyReminderService(
        store: ref.watch(storeProvider),
        platform: FlutterReminderPlatform(),
      ),
    );

/// The IDs 100000000 + YYYYMMDD are reserved for Daily reminders.
/// They fit in a signed 32-bit integer, even in year 9999.
class DailyReminderIds {
  const DailyReminderIds._();
  static const first = 100000000;
  static const last = 199999999;
  static int forDate(DateTime date) =>
      first + date.year * 10000 + date.month * 100 + date.day;
  static bool owns(int id) => id >= first && id <= last;
}

class ScheduledDailyReminder {
  const ScheduledDailyReminder({
    required this.id,
    required this.date,
    required this.title,
    required this.body,
    required this.payload,
    required this.language,
  });
  final int id;
  final DateTime date;
  final String title;
  final String body;
  final String payload;
  final String language;
}

abstract class ReminderPlatform {
  bool get supported;
  Future<void> initialize(void Function(String?) onTap);
  Future<String?> launchPayload();
  Future<bool> permissionGranted();
  Future<bool> requestPermission();
  Future<String> configureLocalTimeZone();
  Future<Set<int>> pendingIds();
  Future<void> schedule(ScheduledDailyReminder reminder);
  Future<void> cancel(int id);
}

class FlutterReminderPlatform implements ReminderPlatform {
  FlutterReminderPlatform({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();
  final FlutterLocalNotificationsPlugin _plugin;
  tz.Location? _location;
  static bool _zonesLoaded = false;

  @override
  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  @override
  Future<void> initialize(void Function(String?) onTap) async {
    if (!supported) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_daily_reminder'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
          defaultPresentBadge: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) => onTap(response.payload),
    );
  }

  @override
  Future<String?> launchPayload() async {
    if (!supported) return null;
    final details = await _plugin.getNotificationAppLaunchDetails();
    return details?.didNotificationLaunchApp == true
        ? details?.notificationResponse?.payload
        : null;
  }

  @override
  Future<bool> permissionGranted() async {
    if (!supported) return false;
    if (defaultTargetPlatform == TargetPlatform.android) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.areNotificationsEnabled() ==
          true;
    }
    return await _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.checkPermissions()
            .then((value) => value?.isEnabled) ==
        true;
  }

  @override
  Future<bool> requestPermission() async {
    if (!supported) return false;
    if (defaultTargetPlatform == TargetPlatform.android) {
      final granted = await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      return granted == true || await permissionGranted();
    }
    final granted = await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, sound: true, badge: false);
    return granted == true;
  }

  @override
  Future<String> configureLocalTimeZone() async {
    if (!_zonesLoaded) {
      tz_data.initializeTimeZones();
      _zonesLoaded = true;
    }
    final name = (await FlutterTimezone.getLocalTimezone()).identifier;
    _location = tz.getLocation(name);
    tz.setLocalLocation(_location!);
    return name;
  }

  @override
  Future<Set<int>> pendingIds() async =>
      (await _plugin.pendingNotificationRequests())
          .map((request) => request.id)
          .toSet();

  @override
  Future<void> schedule(ScheduledDailyReminder reminder) async {
    final location = _location;
    if (location == null) throw StateError('Local timezone was not configured');
    final strings = ReminderStrings(reminder.language);
    await _plugin.zonedSchedule(
      id: reminder.id,
      scheduledDate: tz.TZDateTime(
        location,
        reminder.date.year,
        reminder.date.month,
        reminder.date.day,
        13,
      ),
      title: reminder.title,
      body: reminder.body,
      payload: reminder.payload,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'brain_rush_daily_challenge',
          strings.t('channelName'),
          channelDescription: strings.t('channelDescription'),
          icon: 'ic_daily_reminder',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          channelShowBadge: false,
        ),
        iOS: const DarwinNotificationDetails(presentBadge: false),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);
}

class DailyReminderService extends ChangeNotifier {
  DailyReminderService({
    required this.store,
    required this.platform,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now {
    _lastLanguage = store.language;
    _lastName = store.playerName;
    _lastDay = dateKey(this.now());
    _lastAttempts = store.dailyStatus(this.now()).attemptsUsed;
    store.addListener(_onStoreChanged);
  }

  final AppStore store;
  final ReminderPlatform platform;
  final DateTime Function() now;
  static const horizon = 30;
  static const payloadPrefix = 'daily_challenge';
  bool initialized = false;
  bool pendingDailyNavigation = false;
  Object? lastError;
  String? currentTimeZone;
  Future<void> _serial = Future.value();
  Future<void>? _initializing;
  late String _lastLanguage;
  String? _lastName;
  late String _lastDay;
  late int _lastAttempts;
  bool _disposed = false;

  bool get enabled => store.dailyRemindersEnabled && platform.supported;
  static bool isDailyPayload(String? payload) =>
      payload == payloadPrefix ||
      (payload?.startsWith('$payloadPrefix:') ?? false);

  void _onTap(String? payload) {
    if (!isDailyPayload(payload)) return;
    pendingDailyNavigation = true;
    if (!_disposed) notifyListeners();
  }

  bool consumeDailyNavigation() {
    if (!pendingDailyNavigation) return false;
    pendingDailyNavigation = false;
    return true;
  }

  Future<void> initialize() => _initializing ??= _initialize();

  Future<void> _initialize() async {
    if (!platform.supported) return;
    try {
      await platform.initialize(_onTap);
      initialized = true;
      _onTap(await platform.launchPayload());
      await refresh();
    } catch (error) {
      lastError = error;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> markPromptHandled() async {
    if (store.dailyReminderPromptHandled) return;
    store.dailyReminderPromptHandled = true;
    await store.save();
  }

  Future<bool> enable() async {
    await initialize();
    if (!initialized || !platform.supported) return false;
    try {
      final permitted =
          await platform.permissionGranted() ||
          await platform.requestPermission();
      await markPromptHandled();
      if (!permitted) {
        store.dailyRemindersEnabled = false;
        await store.save();
        await cancelAll();
        return false;
      }
      store.dailyRemindersEnabled = true;
      await store.save();
      await refresh();
      if (lastError != null) {
        store.dailyRemindersEnabled = false;
        await store.save();
        await cancelAll();
        return false;
      }
      return enabled;
    } catch (error) {
      lastError = error;
      store.dailyRemindersEnabled = false;
      await store.save();
      await cancelAll();
      return false;
    }
  }

  Future<void> disable() async {
    store.dailyRemindersEnabled = false;
    await store.save();
    await cancelAll();
  }

  Future<void> _enqueue(Future<void> Function() action) {
    final next = _serial.then((_) => action());
    _serial = next.catchError((Object error) {
      lastError = error;
      if (!_disposed) notifyListeners();
    });
    return _serial;
  }

  Future<void> refresh() => _enqueue(_refreshNow);

  Future<void> _refreshNow() async {
    if (!initialized || !platform.supported) return;
    if (!store.dailyRemindersEnabled) {
      await _cancelAllNow();
      return;
    }
    if (!await platform.permissionGranted()) {
      store.dailyRemindersEnabled = false;
      await store.save();
      await _cancelAllNow();
      return;
    }
    currentTimeZone = await platform.configureLocalTimeZone();
    await _cancelAllNow();
    final current = now();
    final today = DateTime(current.year, current.month, current.day);
    final strings = ReminderStrings(store.language);
    var scheduled = 0;
    for (var offset = 0; scheduled < horizon && offset <= horizon; offset++) {
      final date = DateTime(today.year, today.month, today.day + offset);
      final atOne = DateTime(date.year, date.month, date.day, 13);
      if (!atOne.isAfter(current)) continue;
      if (offset == 0 && store.dailyStatus(date).attemptsUsed > 0) continue;
      await platform.schedule(
        ScheduledDailyReminder(
          id: DailyReminderIds.forDate(date),
          date: date,
          title: strings.t('notificationTitle'),
          body: strings.notificationBody(store.playerName),
          payload: '$payloadPrefix:${dateKey(date)}',
          language: store.language,
        ),
      );
      scheduled++;
    }
    lastError = null;
    if (!_disposed) notifyListeners();
  }

  Future<void> cancelToday() => _enqueue(() async {
    if (!initialized || !platform.supported) return;
    await platform.cancel(DailyReminderIds.forDate(now()));
  });

  Future<void> cancelAll() => _enqueue(_cancelAllNow);

  Future<void> _cancelAllNow() async {
    if (!initialized || !platform.supported) return;
    for (final id in await platform.pendingIds()) {
      if (DailyReminderIds.owns(id)) await platform.cancel(id);
    }
  }

  void _onStoreChanged() {
    final today = now();
    final day = dateKey(today);
    final attempts = store.dailyStatus(today).attemptsUsed;
    final contentChanged =
        store.language != _lastLanguage || store.playerName != _lastName;
    final firstCompleted =
        day == _lastDay && _lastAttempts == 0 && attempts > 0;
    _lastLanguage = store.language;
    _lastName = store.playerName;
    _lastDay = day;
    _lastAttempts = attempts;
    if (!initialized || !enabled) return;
    if (firstCompleted) {
      unawaited(cancelToday());
    } else if (contentChanged) {
      unawaited(refresh());
    }
  }

  @override
  void dispose() {
    _disposed = true;
    store.removeListener(_onStoreChanged);
    super.dispose();
  }
}
