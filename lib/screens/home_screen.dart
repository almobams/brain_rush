import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/store.dart';
import '../game/models.dart';
import '../localization/strings.dart';
import '../theme/app_theme.dart';
import '../widgets/components.dart';
import '../widgets/effects.dart';
import 'game_screen.dart';
import 'secondary_screens.dart';

void openScreen(BuildContext context, Widget screen) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeProvider);
    final text = Theme.of(context).textTheme;
    final compact = MediaQuery.sizeOf(context).height < 700;
    final today = store.daily[dateKey(DateTime.now())];
    final startButton = Pulse(
      child: GamePrimaryButton(
        label: context.tr('start'),
        onPressed: () =>
            openScreen(context, const GameScreen(mode: GameMode.rush)),
      ),
    );
    return RushScaffold(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, compact ? 8 : 20, 24, 24),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: mint,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.tr('eyebrow'),
                    style: text.labelSmall?.copyWith(letterSpacing: 1.7),
                  ),
                ),
                IconButton(
                  tooltip: context.tr('settings'),
                  onPressed: () => openScreen(context, const SettingsScreen()),
                  icon: const Icon(Icons.tune_rounded),
                ),
              ],
            ),
            SizedBox(height: compact ? 0 : 8),
            BrainEmblem(size: compact ? 100 : 150),
            SizedBox(height: compact ? 0 : 8),
            Text(
              context.tr('sixty'),
              style: text.titleLarge?.copyWith(
                letterSpacing: store.language == 'ar' ? 0 : 5,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              context.tr('brand'),
              textAlign: TextAlign.center,
              style: text.displaySmall?.copyWith(
                fontSize: compact ? 38 : 46,
                letterSpacing: store.language == 'ar' ? 0 : -2,
              ),
            ),
            SizedBox(height: compact ? 12 : 18),
            LevelProgress(totalXp: store.stats.totalXp),
            SizedBox(height: compact ? 12 : 18),
            startButton,
            const SizedBox(height: 6),
            Text(context.tr('sixty'), style: text.labelSmall),
            SizedBox(height: compact ? 14 : 24),
            BrainCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              accent: violet,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.bolt_rounded, color: violet),
                title: Text(context.tr('daily'), style: text.titleMedium),
                subtitle: Text(
                  today == null
                      ? context.tr('dailyBadge')
                      : '${context.tr('completed')} · ${context.tr('todayBest')}: ${today.score}',
                  maxLines: 2,
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => openScreen(context, const DailyScreen()),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    label: context.tr('best'),
                    value: '${store.stats.bestScore}',
                    icon: Icons.emoji_events_outlined,
                    color: mint,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    label: context.tr('dailyStreak'),
                    value: Strings.of(context)
                        .dayCount(store.currentDailyStreak),
                    icon: Icons.local_fire_department_outlined,
                    color: streakAmber,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () =>
                        openScreen(context, const StatisticsScreen()),
                    icon: const Icon(Icons.bar_chart_rounded),
                    label: Text(context.tr('statistics')),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () =>
                        openScreen(context, const SettingsScreen()),
                    icon: const Icon(Icons.settings_outlined),
                    label: Text(context.tr('settings')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            BrainCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded, color: violet),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.tr('premium'), style: text.titleMedium),
                        Text(
                          context.tr('premiumDetail'),
                          style: text.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.tr('soon'),
                    style: text.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            if (store.saveFailed)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(context.tr('saveError')),
              ),
          ],
        ),
      ),
    );
  }
}
