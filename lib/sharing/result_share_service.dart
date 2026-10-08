import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../game/models.dart';
import '../localization/languages.dart';
import '../localization/strings.dart';
import 'result_share_card.dart';
import 'result_share_data.dart';
import 'share_links.dart';

final resultShareServiceProvider = Provider<ResultShareService>(
  (ref) => ResultShareService(),
);

abstract class ShareGateway {
  Future<void> share(
    Uint8List png,
    String caption,
    Rect origin,
    String fileName,
  );
}

class NativeShareGateway implements ShareGateway {
  @override
  Future<void> share(
    Uint8List png,
    String caption,
    Rect origin,
    String fileName,
  ) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(png, mimeType: 'image/png')],
        fileNameOverrides: [fileName],
        text: caption,
        sharePositionOrigin: origin,
      ),
    );
  }
}

class ResultShareService {
  ResultShareService({ShareGateway? gateway})
    : gateway = gateway ?? NativeShareGateway();
  final ShareGateway gateway;

  String caption(ResultShareData data, String language, {String? url}) {
    final strings = Strings(language);
    final template = data.mode == GameMode.rush
        ? strings.t('shareRushCaption')
        : data.rank == null
        ? strings.t('shareDailyNoRankCaption')
        : strings.t('shareDailyCaption');
    final message = template
        .replaceAll('{score}', '${data.score}')
        .replaceAll('{rank}', '${data.rank ?? ''}');
    return url == null || url.isEmpty || message.contains(url)
        ? message
        : '$message\n$url';
  }

  Future<Uint8List> capture(BuildContext context, ResultShareData data) async {
    final overlay = Overlay.of(context, rootOverlay: true);
    final boundaryKey = GlobalKey();
    final language = AppLanguages.codeFor(Localizations.localeOf(context));
    final entry = OverlayEntry(
      builder: (overlayContext) => Positioned.fill(
        child: IgnorePointer(
          child: Material(
            color: Colors.black.withValues(alpha: .72),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: RepaintBoundary(
                    key: boundaryKey,
                    child: ResultShareCard(data: data, language: language),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final boundary = boundaryKey.currentContext?.findRenderObject();
      if (boundary is! RenderRepaintBoundary) {
        throw StateError('Result share card was not rendered');
      }
      final image = await boundary.toImage(pixelRatio: 3);
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        if (bytes == null) throw StateError('Result share image was empty');
        return bytes.buffer.asUint8List();
      } finally {
        image.dispose();
      }
    } finally {
      entry.remove();
      entry.dispose();
    }
  }

  Future<void> share(BuildContext context, ResultShareData data) async {
    final box = context.findRenderObject();
    final origin = box is RenderBox && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : Offset.zero & MediaQuery.sizeOf(context);
    final language = AppLanguages.codeFor(Localizations.localeOf(context));
    final png = await capture(context, data);
    await gateway.share(
      png,
      caption(data, language, url: ShareLinks.shareUrl),
      origin,
      data.mode == GameMode.daily
          ? 'brain-rush-daily.png'
          : 'brain-rush-rush.png',
    );
  }
}
