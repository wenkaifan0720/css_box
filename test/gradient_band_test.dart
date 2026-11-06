import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

const _gradient = LinearGradient(colors: [Color(0xFFFF0000), Color(0xFF0000FF)]);

/// [d] painted round a 100x60 box at (20, 20) of a 140x100 canvas, as RGBA.
Future<Uint8List> _paint(WidgetTester tester, Decoration d) async {
  final bytes = await tester.runAsync(() async {
    final rec = ui.PictureRecorder();
    d.createBoxPainter().paint(
      Canvas(rec),
      const Offset(20, 20),
      const ImageConfiguration(size: Size(100, 60), textDirection: TextDirection.ltr),
    );
    final image = await rec.endRecording().toImage(140, 100);
    final data = await image.toByteData();
    image.dispose();
    return data!.buffer.asUint8List();
  });
  return bytes!;
}

int _alpha(Uint8List rgba, int x, int y) => rgba[(y * 140 + x) * 4 + 3];

void main() {
  const box = Rect.fromLTWH(0, 0, 100, 120);

  test('a tile as a share of the box is that share of it, put in the room left over', () {
    // `background-size: 200% 100%; background-position: 100% 0`: twice the
    // box, its right edge on the box's.
    expect(
      const GradientBand(gradient: _gradient, widthFactor: 2, x: 1).bandOf(box),
      const Rect.fromLTWH(-100, 0, 200, 120),
    );
    // `250% 100%` at 98%.
    expect(const GradientBand(gradient: _gradient, widthFactor: 2.5, x: 0.98).bandOf(box).left, closeTo(-147, 1e-9));
  });

  test('a share and a length, and a length it is moved by (a weather site)', () {
    // `background-size: 100% calc(100% - 64px); background-position: 0 32px`.
    expect(
      const GradientBand(gradient: _gradient, height: -64, heightFactor: 1, dy: 32).bandOf(box),
      const Rect.fromLTWH(0, 32, 100, 56),
    );
    // A share that comes to less than nothing is nothing.
    expect(const GradientBand(gradient: _gradient, height: -200, heightFactor: 1).bandOf(box).height, 0);
  });

  testWidgets('a tile larger than the box is painted only where the box is', (tester) async {
    final rgba = await _paint(tester, const GradientBand(gradient: _gradient, widthFactor: 2, heightFactor: 2, x: 0.5));
    expect(_alpha(rgba, 70, 50), 255);
    expect(_alpha(rgba, 10, 50), 0);
    expect(_alpha(rgba, 130, 50), 0);
    expect(_alpha(rgba, 70, 90), 0);
  });

  testWidgets('a share smaller than the box is repeated across it', (tester) async {
    const stripe = LinearGradient(
      colors: [Color(0xFF000000), Color(0xFF000000), Color(0x00000000), Color(0x00000000)],
      stops: [0, 0.5, 0.5, 1],
    );
    final rgba = await _paint(tester, const GradientBand(gradient: stripe, widthFactor: 0.25, repeatX: true));
    // Four tiles of 25px, each dark over its first half.
    for (final x in [25, 50, 75, 100]) {
      expect(_alpha(rgba, x, 50), 255, reason: 'at $x');
      expect(_alpha(rgba, x + 15, 50), 0, reason: 'at ${x + 15}');
    }
  });

  // A dome: `border-radius: 50% 100% 0 0` round the 100x60 box, a clear
  // border of 4px on the top and the sides, the fill cut to the padding box
  // -- each radius less the border beside it, 46 across and 56 down.
  const solid = LinearGradient(colors: [Color(0xFF000000), Color(0xFF000000)]);
  const dome = PercentCornerBorder(topLeft: FractionalRadius(0.5, 1), topRight: FractionalRadius(0.5, 1));
  const inset = EdgeInsets.fromLTRB(4, 4, 4, 0);

  testWidgets('corners that are shares of the box cut the band inside the border, read at its size', (tester) async {
    final rgba = await _paint(
      tester,
      const GradientBand(gradient: solid, inset: inset, clipInset: true, corners: dome),
    );
    expect(_alpha(rgba, 70, 26), 255, reason: 'under the top of the dome');
    expect(_alpha(rgba, 70, 21), 0, reason: 'the clear border over it');
    expect(_alpha(rgba, 26, 26), 0, reason: 'outside the curve, inside the padding box');
    expect(_alpha(rgba, 26, 78), 255, reason: 'the square corner at the foot');
    expect(_alpha(rgba, 21, 78), 0, reason: 'the clear border at the side');
    // Cut to the outline itself where the page does not clip it inside:
    // the tile repeated out under the border.
    final whole = await _paint(
      tester,
      const GradientBand(gradient: solid, inset: inset, repeatX: true, repeatY: true, corners: dome),
    );
    expect(_alpha(whole, 70, 21), 255, reason: 'under the clear border');
    expect(_alpha(whole, 22, 22), 0, reason: 'outside the curve');
    expect(
      const GradientBand(
        gradient: solid,
        corners: dome,
      ).getClipPath(const Rect.fromLTWH(0, 0, 100, 60), TextDirection.ltr).contains(const Offset(3, 3)),
      isFalse,
    );
  });

  testWidgets('NEGATIVE: with no corners the padding box is cut square', (tester) async {
    final rgba = await _paint(tester, const GradientBand(gradient: solid, inset: inset, clipInset: true));
    expect(_alpha(rgba, 26, 26), 255);
    expect(_alpha(rgba, 70, 21), 0);
  });
}
