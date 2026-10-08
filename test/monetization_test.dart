import 'package:brain_rush/core/store.dart';
import 'package:brain_rush/game/models.dart';
import 'package:brain_rush/monetization/ad_policy.dart';
import 'package:brain_rush/monetization/ad_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Daily rewarded ads use test IDs and the global rating stays G', () {
    expect(AdConfig.rewardedAdsEnabled, isTrue);
    expect(AdConfig.requestConfiguration.maxAdContentRating, 'G');
    expect(
      AdConfig.rewardedFor(TargetPlatform.android, testAds: true),
      'ca-app-pub-3940256099942544/5224354917',
    );
    expect(
      AdConfig.rewardedFor(TargetPlatform.iOS, testAds: true),
      'ca-app-pub-3940256099942544/1712485313',
    );
    expect(
      AdConfig.rewardedFor(TargetPlatform.android, testAds: false),
      isEmpty,
    );
    expect(AdConfig.rewardedFor(TargetPlatform.iOS, testAds: false), isEmpty);
    expect(
      GoogleAdService().rewardedReady,
      isFalse,
      reason: 'A rewarded ad is unavailable until it has loaded.',
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
    'normal completions and first-ad eligibility persist across reload',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = AppStore(prefs);
      final now = DateTime(2026, 9, 29);
      for (final mode in [
        GameMode.rush,
        GameMode.daily,
        GameMode.rush,
        GameMode.rush,
      ]) {
        await store.record(
          GameSession(
            id: 'completion-${store.stats.totalGames}',
            mode: mode,
            startedAt: now,
            endedAt: now,
            score: 4,
            bestStreak: 0,
            results: const [],
          ),
        );
      }
      final restored = AppStore(prefs);
      expect(restored.adSchedule.normalGames, 3);
      expect(restored.adSchedule.lastShownAt, isNull);
      expect(restored.adSchedule.eligible(GameMode.rush, false, now), isTrue);
      expect(restored.adSchedule.eligible(GameMode.daily, false, now), isFalse);
      store.dispose();
      restored.dispose();
    },
  );
  test('policy reports the reason for every suppression gate', () {
    final now = DateTime(2026, 9, 29);
    final schedule = AdSchedule();
    expect(
      schedule.blockedReason(GameMode.rush, true, now),
      'Remove Ads owned',
    );
    expect(
      schedule.blockedReason(GameMode.daily, false, now),
      'Daily Challenge is ad-free',
    );
    expect(
      schedule.blockedReason(GameMode.rush, false, now),
      'first two normal games',
    );
    schedule.normalGames = 3;
    expect(schedule.blockedReason(GameMode.rush, false, now), isNull);
    schedule.shown(now);
    expect(
      schedule.blockedReason(GameMode.rush, false, now),
      'normal-game interval not reached',
    );
    schedule.normalGames = 6;
    expect(
      schedule.blockedReason(GameMode.rush, false, now),
      'two-minute cooldown',
    );
    expect(
      schedule.blockedReason(
        GameMode.rush,
        false,
        now.add(const Duration(minutes: 2)),
      ),
      isNull,
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
