import 'package:brain_rush/support/support_links.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legal links use the existing hosted site and selected language', () {
    expect(
      SupportLinks.privacy('ar').toString(),
      'https://brain-rush-almobairik.web.app/privacy/ar/',
    );
    expect(
      SupportLinks.privacy('en').toString(),
      'https://brain-rush-almobairik.web.app/privacy/',
    );
    expect(
      SupportLinks.terms('ar').toString(),
      'https://brain-rush-almobairik.web.app/terms/ar/',
    );
    expect(
      SupportLinks.terms('en').toString(),
      'https://brain-rush-almobairik.web.app/terms/',
    );
    expect(SupportLinks.terms('fr'), SupportLinks.terms('en'));
  });

  test(
    'English support mail includes current app information and encodes it',
    () {
    final uri = SupportLinks.mailto(
      language: 'en',
      appName: 'Brain Rush',
        version: '1.2.0',
        build: '8',
        platform: 'Android',
        os: 'Android 16',
        device: 'Samsung SM-S938B',
      );
      expect(uri.scheme, 'mailto');
      expect(uri.path, 'almobams1@gmail.com');
      expect(uri.queryParameters['subject'], 'Brain Rush Support');
      final body = uri.queryParameters['body']!;
      expect(body, contains('App: Brain Rush'));
      expect(body, contains('Version: 1.2.0'));
      expect(body, contains('Build: 8'));
      expect(body, contains('Platform: Android'));
      expect(body, contains('OS: Android 16'));
      expect(body, contains('Device: Samsung SM-S938B'));
      expect(body, contains('Language: English'));
      expect(body, isNot(contains('installation_id')));
      expect(body, isNot(contains('ranking')));
      expect(uri.toString(), contains('%0A'));
      expect(uri.toString(), contains('%20'));
    },
  );

  test('Arabic support mail has localized subject, body and language', () {
    final uri = SupportLinks.mailto(
      language: 'ar',
      appName: 'Brain Rush',
      version: '1.2.0',
      build: '8',
      platform: 'iOS',
      os: 'iOS 19',
    );
    expect(uri.queryParameters['subject'], 'دعم Brain Rush');
    expect(uri.queryParameters['body'], contains('الإصدار: 1.2.0'));
    expect(uri.queryParameters['body'], contains('اللغة: العربية'));
    expect(uri.toString(), contains('%D8'));
  });
}
