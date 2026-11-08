// Renders HabitFlow's placeholder brand assets to assets/brand/.
//
//   flutter test tool/brand/render_brand_assets_test.dart
//
// Not part of the normal test run (it lives outside test/). Replace the
// generated PNGs with final artwork at any time, then re-run
// `dart run flutter_launcher_icons` and `dart run flutter_native_splash:create`.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _teal = Color(0xFF2E7D6B);
const _tealDark = Color(0xFF1F5E50);
const _white = Color(0xFFFFFFFF);

/// The mark: a white check inside a progress ring.
/// [ringRadius] and [stroke] are fractions of the canvas width.
void _paintMark(
  Canvas canvas,
  Offset center,
  double size, {
  double ringRadius = 0.30,
  double stroke = 0.065,
}) {
  final r = size * ringRadius;
  final w = size * stroke;
  final track = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..color = _white.withValues(alpha: 0.30);
  final progress = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..color = _white;
  final rect = Rect.fromCircle(center: center, radius: r);
  canvas
    ..drawCircle(center, r, track)
    ..drawArc(rect, -math.pi / 2, math.pi * 1.5, false, progress);

  final check = Path()
    ..moveTo(center.dx - r * 0.42, center.dy + r * 0.02)
    ..lineTo(center.dx - r * 0.10, center.dy + r * 0.34)
    ..lineTo(center.dx + r * 0.46, center.dy - r * 0.30);
  canvas.drawPath(
    check,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 1.15
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = _white,
  );
}

Future<void> _render(
  String path,
  int width,
  int height,
  void Function(Canvas canvas, Size size) paint,
) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  paint(canvas, Size(width.toDouble(), height.toDouble()));
  final image = await recorder.endRecording().toImage(width, height);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes!.buffer.asUint8List());
}

void _fillBackground(Canvas canvas, Size size) {
  canvas.drawRect(
    Offset.zero & size,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_teal, _tealDark],
      ).createShader(Offset.zero & size),
  );
}

ui.Paragraph _text(
  String text,
  double fontSize,
  FontWeight weight,
  double width,
) {
  final builder =
      ui.ParagraphBuilder(
          ui.ParagraphStyle(fontFamily: 'Roboto', fontWeight: weight),
        )
        ..pushStyle(ui.TextStyle(color: _white, fontSize: fontSize))
        ..addText(text);
  return builder.build()..layout(ui.ParagraphConstraints(width: width));
}

Future<void> _loadRoboto() async {
  final fonts =
      Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.path;
  final loader = FontLoader('Roboto');
  for (final f in ['roboto-bold.ttf', 'roboto-regular.ttf']) {
    final file = File('$fonts/bin/cache/artifacts/material_fonts/$f');
    if (file.existsSync()) {
      loader.addFont(
        Future.value(ByteData.sublistView(file.readAsBytesSync())),
      );
    }
  }
  await loader.load();
}

void main() {
  testWidgets('render brand assets', (tester) async {
    await tester.runAsync(() async {
      await _loadRoboto();

      // Full icon (legacy launcher, Play Store icon source).
      await _render('assets/brand/icon.png', 1024, 1024, (c, s) {
        _fillBackground(c, s);
        _paintMark(c, s.center(Offset.zero), s.width);
      });

      // Adaptive icon foreground: transparent. flutter_launcher_icons adds a
      // 16% inset, which brings the mark inside the 66% safe zone.
      await _render('assets/brand/icon_foreground.png', 1024, 1024, (c, s) {
        _paintMark(c, s.center(Offset.zero), s.width);
      });

      // Play Store listing icon: 512 × 512.
      await _render('assets/brand/play_store_icon_512.png', 512, 512, (c, s) {
        _fillBackground(c, s);
        _paintMark(c, s.center(Offset.zero), s.width);
      });

      // Play Store feature graphic: 1024 × 500.
      await _render('assets/brand/feature_graphic_1024x500.png', 1024, 500, (
        c,
        s,
      ) {
        _fillBackground(c, s);
        _paintMark(c, const Offset(230, 250), 500, ringRadius: 0.30);
        c
          ..drawParagraph(
            _text('HabitFlow', 84, FontWeight.bold, 560),
            const Offset(430, 150),
          )
          ..drawParagraph(
            _text(
              'Build habits without the guilt.',
              36,
              FontWeight.normal,
              560,
            ),
            const Offset(432, 268),
          );
      });
    });

    for (final f in [
      'icon.png',
      'icon_foreground.png',
      'play_store_icon_512.png',
      'feature_graphic_1024x500.png',
    ]) {
      expect(File('assets/brand/$f').existsSync(), isTrue, reason: f);
    }
  });
}
