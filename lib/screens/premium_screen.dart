import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../localization/strings.dart';
import '../monetization/purchase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/components.dart';

Future<void> restorePurchasesWithFeedback(
  BuildContext context,
  PurchaseService purchases,
) async {
  final result = await purchases.restore();
  if (!context.mounted) return;
  final key = switch (result) {
    RestoreResult.restored => 'purchaseRestored',
    RestoreResult.none => 'noPurchases',
    RestoreResult.unavailable => 'storeUnavailable',
  };
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(context.tr(key))));
}

class PremiumScreen extends ConsumerWidget {
  const PremiumScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final purchases = ref.watch(purchaseServiceProvider);
    final text = Theme.of(context).textTheme;
    return RushScaffold(
      title: context.tr('removeAds'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Icon(Icons.auto_awesome_rounded, color: violet, size: 72),
            const SizedBox(height: 20),
            Text(
              context.tr('removeAds'),
              style: text.headlineLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            BrainCard(
              accent: violet,
              child: Column(
                children: [
                  for (final key in [
                    'noInterstitials',
                    'noForcedAds',
                    'supportRush',
                  ])
                    ListTile(
                      leading: const Icon(
                        Icons.check_circle_outline_rounded,
                        color: mint,
                      ),
                      title: Text(context.tr(key)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Text(context.tr('oneTimePurchase'), style: text.titleMedium),
            const SizedBox(height: 8),
            Text(
              purchases.owned
                  ? context.tr('owned')
                  : purchases.loading
                  ? context.tr('loadingPurchase')
                  : purchases.price ?? context.tr('purchaseUnavailable'),
              style: text.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            if (!purchases.owned)
              GamePrimaryButton(
                label: context.tr('removeAds'),
                onPressed: purchases.price == null || purchases.pending
                    ? null
                    : purchases.buy,
              ),
            if (purchases.pending)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(context.tr('purchasePending')),
              ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => restorePurchasesWithFeedback(context, purchases),
              child: Text(context.tr('restore')),
            ),
          ],
        ),
      ),
    );
  }
}
