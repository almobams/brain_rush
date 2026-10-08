import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../localization/strings.dart';
import '../widgets/components.dart';
import 'support_links.dart';

class HelpSupportSection extends StatefulWidget {
  const HelpSupportSection({super.key, required this.language});

  final String language;

  @override
  State<HelpSupportSection> createState() => _HelpSupportSectionState();
}

class _HelpSupportSectionState extends State<HelpSupportSection> {
  late final Future<PackageInfo> _packageInfo = PackageInfo.fromPlatform();

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openLegal(Uri url) async {
    try {
      if (await launchUrl(url, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      // A missing browser is handled with the same visible feedback.
    }
    if (mounted) _showMessage(context.tr('legalUnavailable'));
  }

  Future<void> _contactSupport() async {
    try {
      final info = await _packageInfo;
      String platform;
      String os;
      String? device;
      if (!kIsWeb && Platform.isAndroid) {
        final android = await DeviceInfoPlugin().androidInfo;
        platform = 'Android';
        os = 'Android ${android.version.release}';
        device = '${android.manufacturer} ${android.model}'.trim();
      } else if (!kIsWeb && Platform.isIOS) {
        final ios = await DeviceInfoPlugin().iosInfo;
        platform = 'iOS';
        os = '${ios.systemName} ${ios.systemVersion}';
        device = ios.utsname.machine;
      } else {
        platform = kIsWeb ? 'Web' : Platform.operatingSystem;
        os = platform;
      }
      final uri = SupportLinks.mailto(
        language: widget.language,
        appName: info.appName,
        version: info.version,
        build: info.buildNumber,
        platform: platform,
        os: os,
        device: device,
      );
      if (await launchUrl(uri)) return;
    } catch (_) {
      // Package, device, and mail clients can all be unavailable.
    }
    try {
      await Clipboard.setData(const ClipboardData(text: SupportLinks.email));
    } catch (_) {
      // The address remains visible in the message if clipboard access fails.
    }
    if (mounted) {
      _showMessage(
        context
            .tr('supportUnavailable')
            .replaceAll('{email}', SupportLinks.email),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SectionHeader(context.tr('helpSupport')),
      BrainCard(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            ListTile(
              key: const Key('contactSupport'),
              leading: const Icon(Icons.email_outlined),
              title: Text(context.tr('contactSupport')),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _contactSupport,
            ),
            ListTile(
              key: const Key('privacyPolicy'),
              leading: const Icon(Icons.privacy_tip_outlined),
              title: Text(context.tr('privacy')),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _openLegal(SupportLinks.privacy(widget.language)),
            ),
            ListTile(
              key: const Key('termsConditions'),
              leading: const Icon(Icons.description_outlined),
              title: Text(context.tr('terms')),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _openLegal(SupportLinks.terms(widget.language)),
            ),
            FutureBuilder<PackageInfo>(
              future: _packageInfo,
              builder: (context, snapshot) {
                final info = snapshot.data;
                if (info == null) return const SizedBox.shrink();
                return ListTile(
                  key: const Key('appVersion'),
                  leading: const Icon(Icons.info_outline_rounded),
                  title: const Text('Brain Rush'),
                  subtitle: Text(
                    context
                        .tr('appVersion')
                        .replaceAll('{version}', info.version)
                        .replaceAll('{build}', info.buildNumber),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    ],
  );
}
