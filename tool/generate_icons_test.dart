import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Generate original Brain Rush launcher artwork', () async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawColor(const ui.Color(0xFF080F20), ui.BlendMode.src);
    final p = ui.Paint()
      ..color = const ui.Color(0xFF33345B)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 5;
    canvas.drawCircle(const ui.Offset(512, 512), 400, p);
    canvas.drawCircle(const ui.Offset(512, 512), 340, p);
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
        const ui.Rect.fromLTWH(240, 240, 544, 544),
        const ui.Radius.circular(145),
      ),
      ui.Paint()
        ..shader = ui.Gradient.linear(
          const ui.Offset(260, 260),
          const ui.Offset(790, 790),
          [const ui.Color(0xFFB3A0FF), const ui.Color(0xFF6655C2)],
        ),
    );
    final bolt = ui.Path()
      ..moveTo(552, 315)
      ..lineTo(388, 540)
      ..lineTo(490, 540)
      ..lineTo(457, 709)
      ..lineTo(645, 464)
      ..lineTo(536, 464)
      ..close();
    canvas.drawPath(bolt, ui.Paint()..color = const ui.Color(0xFFF6F1FF));
    canvas.drawCircle(
      const ui.Offset(889, 645),
      23,
      ui.Paint()..color = const ui.Color(0xFF9CF5D2),
    );
    canvas.drawCircle(
      const ui.Offset(340, 150),
      15,
      ui.Paint()..color = const ui.Color(0xFFB3A0FF),
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(1024, 1024);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('tool/launcher.png').writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
    picture.dispose();
  });
}
