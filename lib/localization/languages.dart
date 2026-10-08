import 'package:flutter/widgets.dart';

class AppLanguage {
  const AppLanguage(this.code, this.nativeName, this.locale);
  final String code;
  final String nativeName;
  final Locale locale;
}

class AppLanguages {
  const AppLanguages._();

  static const all = <AppLanguage>[
    AppLanguage('en', 'English', Locale('en')),
    AppLanguage('ar', 'العربية', Locale('ar')),
    AppLanguage('es', 'Español', Locale('es')),
    AppLanguage('pt_BR', 'Português (Brasil)', Locale('pt', 'BR')),
    AppLanguage('fr', 'Français', Locale('fr')),
    AppLanguage('de', 'Deutsch', Locale('de')),
    AppLanguage('it', 'Italiano', Locale('it')),
    AppLanguage('tr', 'Türkçe', Locale('tr')),
    AppLanguage('ru', 'Русский', Locale('ru')),
    AppLanguage('id', 'Bahasa Indonesia', Locale('id')),
    AppLanguage('hi', 'हिन्दी', Locale('hi')),
    AppLanguage('ja', '日本語', Locale('ja')),
    AppLanguage('ko', '한국어', Locale('ko')),
    AppLanguage(
      'zh_Hans',
      '简体中文',
      Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
    ),
    AppLanguage(
      'zh_Hant',
      '繁體中文',
      Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
    ),
    AppLanguage('ur', 'اردو', Locale('ur')),
    AppLanguage('fa', 'فارسی', Locale('fa')),
    AppLanguage('bn', 'বাংলা', Locale('bn')),
  ];

  static final supportedLocales = all
      .map((language) => language.locale)
      .toList(growable: false);
  static bool contains(String code) =>
      all.any((language) => language.code == code);
  static Locale localeFor(String code) => all
      .firstWhere((language) => language.code == code, orElse: () => all.first)
      .locale;
  static String codeFor(Locale locale) {
    if (locale.languageCode == 'pt') return 'pt_BR';
    if (locale.languageCode == 'zh') {
      return locale.scriptCode == 'Hant' ||
              (locale.scriptCode == null &&
                  ['TW', 'HK', 'MO'].contains(locale.countryCode))
          ? 'zh_Hant'
          : 'zh_Hans';
    }
    return contains(locale.languageCode) ? locale.languageCode : 'en';
  }

  static bool isRtl(String code) => const {'ar', 'ur', 'fa'}.contains(code);
}
