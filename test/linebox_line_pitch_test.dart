import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:css_box/css_box.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// The test font sets every letter as a square one em across, 0.75em over
// the baseline. At [fs] a line's glyph is a square [fs] across standing
// 0.75 fs over the baseline, and a CSS line of [lh] splits its leading
// evenly round it: the square's top is (lh - fs) / 2 down the line. Skia
// sets a glyph on a whole pixel, so a square's first row of ink is within
// a pixel of where its line puts it -- and where the lines climb, the
// error grows a line at a time past that.
const _black = Color(0xFF000000);
const _white = Color(0xFFFFFFFF);
const _w = 40;

Widget _para(int lines, double lh, {double fs = 20, bool box = false}) {
  final words = [for (var i = 0; i < lines; i++) 'A'].join('\n');
  final strut = StrutStyle(
    fontFamily: 'FlutterTest',
    fontSize: fs,
    height: lh / fs,
    forceStrutHeight: true,
    leadingDistribution: ui.TextLeadingDistribution.even,
  );
  final style = TextStyle(fontFamily: 'FlutterTest', fontSize: fs, height: 1, color: _black);
  final text = box
      ? Text.rich(
          TextSpan(
            children: [
              const WidgetSpan(child: SizedBox(width: 4, height: 4)),
              TextSpan(text: words),
            ],
          ),
          style: style,
          strutStyle: strut,
        )
      : Text(words, style: style, strutStyle: strut);
  return Directionality(
    textDirection: TextDirection.ltr,
    child: RepaintBoundary(
      key: const Key('shot'),
      child: ColoredBox(
        color: _white,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: _w.toDouble(),
            child: LineBox(lineHeight: lh, ascent: 0.75 * fs + (lh - fs) / 2, child: text),
          ),
        ),
      ),
    ),
  );
}

Future<(Uint8List, int)> _shot(WidgetTester tester) async {
  final ro = tester.renderObject<RenderRepaintBoundary>(find.byKey(const Key('shot')));
  return (await tester.runAsync(() async {
    final img = await ro.toImage();
    return ((await img.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List(), img.height);
  }))!;
}

/// The first pixel row of each glyph square down the column at [x].
List<int> _tops(Uint8List px, int h, {required int x}) {
  final out = <int>[];
  var inside = false;
  for (var y = 0; y < h; y++) {
    final ink = 1 - px[(y * _w + x) * 4] / 255;
    if (ink > 0.5 && !inside) out.add(y);
    inside = ink > 0.5;
  }
  return out;
}

Future<void> _view(WidgetTester tester, double height) async {
  tester.view.physicalSize = Size(_w.toDouble(), height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  group('every line at the pitch CSS gives it', () {
    // Before: Skia's whole-pixel lines, put back for the first line and the
    // height only.
    // p1: 28.4375px lines of 20px text, drawn 28: the 30th line 12.9px high.
    // p2: 23.09375px lines of 16px text, drawn 23: 0.09375 a line, 2.3px
    //     high by the 30th.
    // p3: 16.5px lines of 10px text, drawn 17: half a pixel a line, 14.3px
    //     low by the 30th.
    for (final (name, lh, fs) in [('p1', 28.4375, 20.0), ('p2', 23.09375, 16.0), ('p3', 16.5, 10.0)]) {
      testWidgets('$name: thirty lines of $lh stand each at k x $lh', (tester) async {
        await _view(tester, 900);
        await tester.pumpWidget(_para(30, lh, fs: fs));
        expect(tester.getSize(find.byType(LineBox)).height, closeTo(30 * lh, 1e-6));
        final (px, h) = await _shot(tester);
        final tops = _tops(px, h, x: (fs / 2).round());
        expect(tops, hasLength(30));
        for (var k = 0; k < 30; k++) {
          expect(tops[k], closeTo(k * lh + (lh - fs) / 2, 0.999), reason: 'line $k of $lh');
        }
      });
    }

    // NEGATIVE n1: whole-pixel lines are Skia's own pitch, painted once.
    testWidgets('n1: thirty lines of 28 stand each at k x 28', (tester) async {
      await _view(tester, 900);
      await tester.pumpWidget(_para(30, 28));
      final (px, h) = await _shot(tester);
      final tops = _tops(px, h, x: 10);
      expect(tops, hasLength(30));
      for (var k = 0; k < 30; k++) {
        expect(tops[k], k * 28 + 4, reason: 'line $k');
      }
    });

    // NEGATIVE n2: a paragraph with a box on a line is painted once, where
    // Skia put its lines.
    testWidgets('n2: a box on the first line leaves the lines at Skia\'s pitch', (tester) async {
      await _view(tester, 900);
      await tester.pumpWidget(_para(30, 28.4375, box: true));
      final (px, h) = await _shot(tester);
      final tops = _tops(px, h, x: 10);
      expect(tops, hasLength(30));
      for (var k = 1; k < 30; k++) {
        expect(tops[k] - tops[0], k * 28, reason: 'line $k');
      }
    });

    // NEGATIVE n3: one line is where the box puts it, painted once.
    testWidgets('n3: one line of 28.4375 stands on its ascent', (tester) async {
      await _view(tester, 60);
      await tester.pumpWidget(_para(1, 28.4375));
      final (px, h) = await _shot(tester);
      final tops = _tops(px, h, x: 10);
      expect(tops, hasLength(1));
      expect(tops[0], closeTo((28.4375 - 20) / 2, 0.999));
    });
  });
}
