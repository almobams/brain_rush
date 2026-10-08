import 'dart:convert';

import 'package:brain_rush/core/store.dart';
import 'package:brain_rush/game/models.dart';
import 'package:brain_rush/localization/languages.dart';
import 'package:brain_rush/localization/strings.dart';
import 'package:brain_rush/main.dart';
import 'package:brain_rush/screens/home_screen.dart';
import 'package:brain_rush/screens/onboarding_screen.dart';
import 'package:brain_rush/screens/secondary_screens.dart';
import 'package:brain_rush/widgets/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'fresh install selects and previews language, saves Unicode name, and skips repeat onboarding',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [preferencesProvider.overrideWithValue(prefs)],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const BrainRushApp(),
        ),
      );
      await tester.pump();
      expect(find.byType(OnboardingScreen), findsOneWidget);
      final next = find.widgetWithText(GamePrimaryButton, 'CONTINUE');
      expect(tester.widget<GamePrimaryButton>(next).onPressed, isNull);
      await tester.ensureVisible(find.byKey(const Key('language_es')));
      await tester.tap(find.byKey(const Key('language_es')));
      await tester.pump();
      expect(container.read(storeProvider).language, 'es');
      expect(find.text('Elige tu idioma'), findsOneWidget);
      await tester.ensureVisible(
        find.widgetWithText(GamePrimaryButton, 'CONTINUAR'),
      );
      await tester.tap(find.widgetWithText(GamePrimaryButton, 'CONTINUAR'));
      await tester.pump();
      expect(find.byType(PlayerNameEditor), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('playerNameField')),
        '  محمد 山田  ',
      );
      await tester.ensureVisible(
        find.widgetWithText(GamePrimaryButton, 'CONTINUAR'),
      );
      await tester.tap(find.widgetWithText(GamePrimaryButton, 'CONTINUAR'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(container.read(storeProvider).playerName, 'محمد 山田');
      expect(find.textContaining('محمد 山田'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      container.dispose();

      SharedPreferences.resetStatic();
      final restored = ProviderContainer(
        overrides: [
          preferencesProvider.overrideWithValue(
            await SharedPreferences.getInstance(),
          ),
        ],
      );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: restored,
          child: const BrainRushApp(),
        ),
      );
      await tester.pump();
      expect(restored.read(storeProvider).onboardingCompleted, isTrue);
      expect(restored.read(storeProvider).language, 'es');
      expect(restored.read(storeProvider).playerName, 'محمد 山田');
      expect(find.byType(HomeScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      restored.dispose();
    },
  );

  testWidgets('name may be skipped and whitespace-only Continue is rejected', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [preferencesProvider.overrideWithValue(prefs)],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const BrainRushApp(),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('language_en')));
    await tester.pump();
    await tester.tap(find.widgetWithText(GamePrimaryButton, 'CONTINUE'));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('playerNameField')), '   ');
    await tester.tap(find.widgetWithText(GamePrimaryButton, 'CONTINUE'));
    await tester.pump();
    expect(find.text('Enter a name or choose Skip.'), findsOneWidget);
    await tester.tap(find.text('SKIP'));
    await tester.pump();
    expect(container.read(storeProvider).playerName, isNull);
    expect(container.read(storeProvider).onboardingCompleted, isTrue);
    expect(find.byType(HomeScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  testWidgets('a long Unicode name is limited without breaking onboarding', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [preferencesProvider.overrideWithValue(prefs)],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const BrainRushApp(),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('language_en')));
    await tester.pump();
    await tester.tap(find.widgetWithText(GamePrimaryButton, 'CONTINUE'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('playerNameField')),
      'محمد山田李عبداللهمحمد山田李عبداللهمحمد山田李',
    );
    await tester.pump();
    expect(find.text('محمد山田李عبداللهمحمد山田李عبداللهمحمد山田李'), findsNothing);
    expect(tester.takeException(), isNull);
    expect(
      await container.read(storeProvider).setPlayerName('a' * 21),
      isFalse,
    );
    expect(container.read(storeProvider).playerName, isNull);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  test(
    'legacy save keeps language and progress and bypasses onboarding',
    () async {
      final stats = PlayerStats()
        ..bestScore = 42
        ..totalXp = 123;
      SharedPreferences.setMockInitialValues({
        'brain_rush_v1': jsonEncode({
          'stats': stats.toJson(),
          'language': 'ar',
        }),
      });
      final store = AppStore(await SharedPreferences.getInstance());
      expect(store.onboardingCompleted, isTrue);
      expect(store.language, 'ar');
      expect(store.stats.bestScore, 42);
      expect(store.stats.totalXp, 123);
      expect(store.playerName, isNull);
      store.dispose();
    },
  );

  testWidgets('Settings changes language and name without resetting progress', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [preferencesProvider.overrideWithValue(prefs)],
    );
    final store = container.read(storeProvider);
    store.onboardingCompleted = true;
    store.stats.bestScore = 42;
    store.stats.totalXp = 123;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const BrainRushApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    Navigator.of(tester.element(find.byType(HomeScreen)))
        .push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(SettingsScreen), findsOneWidget);
    await tester.tap(find.widgetWithText(ListTile, 'English'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(LanguageSelectionScreen), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('language_fr')));
    await tester.tap(find.byKey(const Key('language_fr')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(store.language, 'fr');
    Navigator.of(tester.element(find.byType(LanguageSelectionScreen))).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(
      find.widgetWithText(ListTile, Strings('fr').t('playerName')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byKey(const Key('playerNameField')), 'Zoë 李');
    await tester.tap(
      find.widgetWithText(GamePrimaryButton, Strings('fr').t('saveName')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(PlayerNameSettingsScreen), findsNothing);
    expect(store.playerName, 'Zoë 李');
    expect(store.stats.bestScore, 42);
    expect(store.stats.totalXp, 123);
    await tester.tap(
      find.widgetWithText(ListTile, Strings('fr').t('playerName')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.ensureVisible(find.text(Strings('fr').t('clearName')));
    await tester.tap(find.text(Strings('fr').t('clearName')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(store.playerName, isNull);
    expect(store.stats.bestScore, 42);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  test(
    'all 18 locales have complete strings, with no Hebrew and correct RTL',
    () {
      expect(AppLanguages.all.length, 18);
      expect(
        AppLanguages.all.any((language) => language.code == 'he'),
        isFalse,
      );
      expect(
        Strings.catalogs.keys.toSet(),
        AppLanguages.all.map((language) => language.code).toSet(),
      );
      for (final language in AppLanguages.all) {
        expect(
          Strings.catalogs[language.code]!.keys.toSet(),
          Strings.en.keys.toSet(),
          reason: language.code,
        );
        expect(Strings(language.code).t('start'), isNot('start'));
      }
      for (final code in ['ar', 'ur', 'fa']) {
        expect(AppLanguages.isRtl(code), isTrue);
      }
      for (final code in ['en', 'es', 'zh_Hans', 'zh_Hant', 'bn']) {
        expect(AppLanguages.isRtl(code), isFalse);
      }
      expect(
        AppLanguages.codeFor(
          const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
        ),
        'zh_Hant',
      );
    },
  );
}
