import '../localization/languages.dart';
import '../localization/strings.dart';
import '../sharing/share_links.dart';

class SupportLinks {
  const SupportLinks._();

  static const email = 'almobams1@gmail.com';
  static final Uri _site = Uri.parse(ShareLinks.brainRushLandingUrl);

  static Uri privacy(String language) => _site.replace(
    path: language == 'ar' ? '/privacy/ar/' : '/privacy/',
    query: null,
  );

  static Uri terms(String language) => _site.replace(
    path: language == 'ar' ? '/terms/ar/' : '/terms/',
    query: null,
  );

  static String emailBody({
    required String language,
    required String appName,
    required String version,
    required String build,
    required String platform,
    required String os,
    String? device,
  }) {
    final copy = Strings(language);
    final languageName = AppLanguages.all
        .firstWhere(
          (item) => item.code == language,
          orElse: () => AppLanguages.all.first,
        )
        .nativeName;
    return [
      copy.t('supportGreeting'),
      '',
      copy.t('supportPrompt'),
      '',
      '',
      '--------------------',
      copy.t('supportInfo'),
      '${copy.t('supportApp')}: $appName',
      '${copy.t('supportVersion')}: $version',
      '${copy.t('supportBuild')}: $build',
      '${copy.t('supportPlatform')}: $platform',
      '${copy.t('supportOs')}: $os',
      if (device != null && device.trim().isNotEmpty)
        '${copy.t('supportDevice')}: $device',
      '${copy.t('supportLanguage')}: $languageName',
    ].join('\n');
  }

  static Uri mailto({
    required String language,
    required String appName,
    required String version,
    required String build,
    required String platform,
    required String os,
    String? device,
  }) {
    final subject = Strings(language).t('supportSubject');
    final body = emailBody(
      language: language,
      appName: appName,
      version: version,
      build: build,
      platform: platform,
      os: os,
      device: device,
    );
    return Uri(
      scheme: 'mailto',
      path: email,
      query:
          'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(body)}',
    );
  }
}
