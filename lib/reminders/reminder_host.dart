import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/store.dart';
import '../screens/secondary_screens.dart';
import 'daily_reminder_service.dart';
import 'reminder_strings.dart';

/// Owns app lifecycle and navigation for the optional local reminder feature.
class ReminderHost extends ConsumerStatefulWidget {
  const ReminderHost({
    super.key,
    required this.child,
    required this.onboardingCompleted,
  });
  final Widget child;
  final bool onboardingCompleted;

  @override
  ConsumerState<ReminderHost> createState() => _ReminderHostState();
}

class _ReminderHostState extends ConsumerState<ReminderHost>
    with WidgetsBindingObserver {
  late final DailyReminderService reminders;
  bool showingOptIn = false;
  bool openingDaily = false;

  @override
  void initState() {
    super.initState();
    reminders = ref.read(dailyReminderServiceProvider);
    reminders.addListener(_onReminderChanged);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_start()));
  }

  Future<void> _start() async {
    await reminders.initialize();
    if (!mounted) return;
    _onReminderChanged();
    await _offerIfNeeded();
  }

  @override
  void didUpdateWidget(covariant ReminderHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.onboardingCompleted && widget.onboardingCompleted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _onReminderChanged();
        unawaited(_offerIfNeeded());
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(reminders.refresh());
  }

  void _onReminderChanged() {
    if (!mounted ||
        !widget.onboardingCompleted ||
        !reminders.pendingDailyNavigation ||
        openingDaily) {
      return;
    }
    openingDaily = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      openingDaily = false;
      if (!mounted ||
          !widget.onboardingCompleted ||
          !reminders.consumeDailyNavigation()) {
        return;
      }
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => const DailyScreen()));
    });
  }

  Future<void> _offerIfNeeded() async {
    if (!mounted || !widget.onboardingCompleted || showingOptIn) return;
    await reminders.initialize();
    if (!mounted ||
        !widget.onboardingCompleted ||
        !reminders.initialized ||
        !reminders.platform.supported) {
      return;
    }
    final store = ref.read(storeProvider);
    if (store.dailyReminderPromptHandled || store.dailyRemindersEnabled) return;
    showingOptIn = true;
    final copy = ReminderStrings(store.language);
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(copy.t('optInTitle')),
        content: Text(copy.t('optInBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(copy.t('notNow')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(copy.t('enable')),
          ),
        ],
      ),
    );
    if (accepted == true) {
      final enabled = await reminders.enable();
      if (!enabled && mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(copy.t('disabled'))));
      }
    } else {
      await reminders.markPromptHandled();
    }
    showingOptIn = false;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    reminders.removeListener(_onReminderChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
