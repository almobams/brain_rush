import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/store.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';
import 'localization/strings.dart';
import 'monetization/ad_service.dart';
import 'monetization/purchase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final preferences = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [preferencesProvider.overrideWithValue(preferences)],
      child: const BrainRushApp(initializeMonetization: true),
    ),
  );
}

class BrainRushApp extends ConsumerStatefulWidget {
  const BrainRushApp({super.key, this.initializeMonetization = false});
  final bool initializeMonetization;
  @override
  ConsumerState<BrainRushApp> createState() => _BrainRushAppState();
}

class _BrainRushAppState extends ConsumerState<BrainRushApp> {
  @override
  void initState() {
    super.initState();
    if (!widget.initializeMonetization) return;
    // Neither the store nor consent may delay the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(purchaseServiceProvider).initialize();
      ref.read(adServiceProvider).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(storeProvider);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => context.tr('app'),
      theme: appTheme(Brightness.light),
      darkTheme: appTheme(Brightness.dark),
      themeMode: store.themeMode,
      locale: Locale(store.language),
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const HomeScreen(),
    );
  }
}
