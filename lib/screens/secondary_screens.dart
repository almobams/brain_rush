import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/store.dart';
import '../game/models.dart';
import '../game/progression.dart';
import '../localization/strings.dart';
import '../theme/app_theme.dart';
import '../widgets/components.dart';
import '../widgets/effects.dart';
import 'game_screen.dart';

class DailyScreen extends ConsumerWidget {
  const DailyScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeProvider);
    final now = DateTime.now();
    final result = store.daily[dateKey(now)];
    final text = Theme.of(context).textTheme;
    return RushScaffold(
      title: context.tr('daily'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 24),
            const BrainEmblem(size: 170),
            const SizedBox(height: 24),
            Text(
              MaterialLocalizations.of(context).formatMediumDate(now),
              textAlign: TextAlign.center,
              style: text.headlineMedium,
            ),
            const SizedBox(height: 12),
            Text(
              context.tr('dailyDetail'),
              textAlign: TextAlign.center,
              style: text.bodyLarge,
            ),
            const SizedBox(height: 28),
            BrainCard(
              accent: violet,
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  children: [
                    Text(context.tr('todayBest')),
                    const SizedBox(height: 14),
                    if (result != null)
                      AnimatedScore(result.score, large: true)
                    else
                      const Icon(
                        Icons.hourglass_empty_rounded,
                        size: 48,
                        color: violet,
                      ),
                    if (result == null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          context.tr('notPlayed'),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            GamePrimaryButton(
              label: context.tr(result == null ? 'playDaily' : 'replayDaily'),
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(
                  builder: (_) => const GameScreen(mode: GameMode.daily),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.tr('replayNote'),
              textAlign: TextAlign.center,
              style: text.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeProvider), stats = store.stats;
    final values = <(String, String, IconData)>[
      ('totalGames', '${stats.totalGames}', Icons.sports_esports_outlined),
      ('best', '${stats.bestScore}', Icons.emoji_events_outlined),
      (
        'average',
        stats.averageScore.toStringAsFixed(1),
        Icons.insights_rounded,
      ),
      ('accuracy', '${stats.accuracy.round()}%', Icons.track_changes_rounded),
      ('correctCount', '${stats.totalCorrect}', Icons.check_circle_outline),
      ('wrongCount', '${stats.totalWrong}', Icons.cancel_outlined),
      (
        'longest',
        '${stats.longestStreak}',
        Icons.local_fire_department_outlined,
      ),
      (
        'dailyStreak',
        '${store.currentDailyStreak}',
        Icons.calendar_today_outlined,
      ),
      (
        'level',
        '${const XpPolicy().levelFor(stats.totalXp)}',
        Icons.bolt_rounded,
      ),
      ('totalXp', '${stats.totalXp}', Icons.auto_awesome_rounded),
    ];
    return RushScaffold(
      title: context.tr('statistics'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('statsSubtitle'),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            for (var i = 0; i < values.length; i += 2)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var j = 0; j < 2; j++) ...[
                      if (j > 0) const SizedBox(width: 12),
                      Expanded(
                        child: StatCard(
                          label: context.tr(values[i + j].$1),
                          value: values[i + j].$2,
                          icon: values[i + j].$3,
                          color: (i + j).isEven ? mint : violet,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});
  void info(BuildContext context, String title, String body) =>
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(context.tr(title)),
          content: Text(context.tr(body)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.tr('close')),
            ),
          ],
        ),
      );
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeProvider);
    return RushScaffold(
      title: context.tr('settings'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(context.tr('language')),
            BrainCard(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  for (final code in ['en', 'ar'])
                    ListTile(
                      title: Text(
                        context.tr(code == 'en' ? 'english' : 'arabic'),
                      ),
                      trailing: store.language == code
                          ? Icon(
                              Icons.check_circle_rounded,
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : null,
                      onTap: () {
                        store.language = code;
                        store.save();
                      },
                    ),
                ],
              ),
            ),
            SectionHeader(context.tr('theme')),
            BrainCard(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  for (final mode in ThemeMode.values)
                    ListTile(
                      title: Text(context.tr(mode.name)),
                      leading: Icon(
                        mode == ThemeMode.dark
                            ? Icons.dark_mode_outlined
                            : mode == ThemeMode.light
                            ? Icons.light_mode_outlined
                            : Icons.brightness_auto_outlined,
                      ),
                      trailing: store.themeMode == mode
                          ? Icon(
                              Icons.check_circle_rounded,
                              color: Theme.of(context).colorScheme.primary,
                            )
                          : null,
                      onTap: () {
                        store.themeMode = mode;
                        store.save();
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            BrainCard(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  SwitchListTile(
                    title: Text(context.tr('sound')),
                    subtitle: Text(context.tr('soundHint')),
                    value: store.sound,
                    onChanged: (value) {
                      store.sound = value;
                      store.save();
                    },
                  ),
                  SwitchListTile(
                    title: Text(context.tr('haptics')),
                    value: store.haptics,
                    onChanged: (value) {
                      store.haptics = value;
                      store.save();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            for (final entry in [
              ('privacy', 'privacyBody'),
              ('terms', 'termsBody'),
              ('restore', 'placeholder'),
            ])
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                title: Text(context.tr(entry.$1)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => info(context, entry.$1, entry.$2),
              ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                context.tr('version'),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
