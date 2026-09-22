import 'package:brain_rush/core/store.dart';
import 'package:brain_rush/game/models.dart';
import 'package:brain_rush/monetization/ad_policy.dart';
import 'package:brain_rush/monetization/ad_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('rewarded ads are disabled and the global rating is G', () {
    expect(AdConfig.rewardedAdsEnabled, isFalse);
    expect(AdConfig.requestConfiguration.maxAdContentRating, 'G');
    expect(
      GoogleAdService().rewardedReady,
      isFalse,
      reason: 'Disabled rewarded ads cannot be loaded or exposed to the UI.',
    );
  });
  test('interstitial starts after third normal game, then every third, with cooldown', () {
    final now = DateTime(2026, 9, 22, 12);
    final schedule = AdSchedule();
    for (var game = 1; game <= 2; game++) {
      schedule.completed(GameMode.rush);
      expect(schedule.eligible(GameMode.rush, false, now), false);
    }
    schedule.completed(GameMode.daily);
    expect(schedule.eligible(GameMode.daily, false, now), false);
    schedule.completed(GameMode.rush);
    expect(schedule.eligible(GameMode.rush, false, now), true);
    expect(schedule.eligible(GameMode.rush, true, now), false);
    schedule.shown(now);
    for (var game = 0; game < 3; game++) {
      schedule.completed(GameMode.rush);
    }
    expect(
      schedule.eligible(
        GameMode.rush,
        false,
        now.add(const Duration(seconds: 119)),
      ),
      false,
    );
    expect(
      schedule.eligible(
        GameMode.rush,
        false,
        now.add(const Duration(minutes: 2)),
      ),
      true,
    );
  });

  test(
    'legacy save loads and XP bonus changes only XP, once, across reload',
    () async {
      SharedPreferences.setMockInitialValues({
        'brain_rush_v1': '{"stats":{"totalGames":2,"bestScore":20,"totalXp":50},"language":"ar"}',
      });
      final prefs = await SharedPreferences.getInstance();
      final store = AppStore(prefs);
      expect(store.adSchedule.normalGames, 0);
      final originalBest = store.stats.bestScore;
      final originalGames = store.stats.totalGames;
      expect(await store.claimXpBonus('round-1', 40), true);
      expect(await store.claimXpBonus('round-1', 40), false);
      expect(store.stats.totalXp, 90);
      expect(store.stats.bestScore, originalBest);
      expect(store.stats.totalGames, originalGames);
      SharedPreferences.resetStatic();
      final restored = AppStore(await SharedPreferences.getInstance());
      expect(restored.claimedXpSessions, contains('round-1'));
      expect(await restored.claimXpBonus('round-1', 40), false);
      expect(restored.stats.totalXp, 90);
      store.dispose();
      restored.dispose();
    },
  );
}
