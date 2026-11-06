import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

/// A tile of one colour: every pixel of a copy is ink, and between the
/// copies there is none.
const _ink = LinearGradient(colors: [Color(0xFF1D3557), Color(0xFF1D3557)]);

/// [d] painted round a [w]x20 box at (10, 10) of a (w + 20)x40 canvas, as RGBA.
Future<Uint8List> _paint(WidgetTester tester, Decoration d, double w) async {
  final bytes = await tester.runAsync(() async {
    final rec = ui.PictureRecorder();
    d.createBoxPainter().paint(
      Canvas(rec),
      const Offset(10, 10),
      ImageConfiguration(size: Size(w, 20), textDirection: TextDirection.ltr),
    );
    final image = await rec.endRecording().toImage(w.ceil() + 20, 40);
    final data = await image.toByteData();
    image.dispose();
    return data!.buffer.asUint8List();
  });
  return bytes!;
}

int _alpha(Uint8List rgba, int stride, int x, int y) => rgba[(y * stride + x) * 4 + 3];

void main() {
  // css-backgrounds-3 3.4, `space`: as many whole copies as fit, the first
  // and the last against the edges and the room left over shared between
  // them -- in Blink's 1/64 px (`GetSpaceBetweenImageTiles`).
  test('space lays as many whole copies as fit, first and last against the edges', () {
    // 400px of 124px copies (`calc(30% + 4px)`): three, 14px apart.
    expect(GradientBand.copies(0, 400, 0, 124, repeat: false, space: true), [0, 138, 276]);
    // The room left over truncated to a 1/64 px per gap: 90px of 4px
    // copies is 22, 6/64 px apart.
    final down = GradientBand.copies(0, 90, 0, 4, repeat: false, space: true);
    expect(down.length, 22);
    expect(down[1], 4 + 6 / 64);
    expect(down.last, 21 * (4 + 6 / 64));
    // Fewer than two fit: the one tile where the position put it.
    expect(GradientBand.copies(0, 15, 3, 8.5, repeat: false, space: true), [3]);
    // No space is `repeat` from the tile, both ways over the box, or once.
    expect(GradientBand.copies(0, 100, 10, 25, repeat: true, space: false), [-15, 10, 35, 60, 85]);
    expect(GradientBand.copies(0, 100, 10, 25, repeat: false, space: false), [10]);
  });

  testWidgets('a spaced tile of a share and a length is counted at the size the box is painted at', (tester) async {
    const band = GradientBand(gradient: _ink, width: 4, widthFactor: 0.3, spaceX: true, x: 0.5);
    // 100px: copies of 34, two of them, at 0 and 66.
    var rgba = await _paint(tester, band, 100);
    const stride = 120;
    for (final (x, a) in [(10, 255), (43, 255), (44, 0), (75, 0), (76, 255), (109, 255), (110, 0)]) {
      expect(_alpha(rgba, stride, x, 20), a, reason: 'at $x of 100');
    }
    // 200px: copies of 64, three, 4px apart -- at 0, 68 and 136.
    rgba = await _paint(tester, band, 200);
    for (final (x, a) in [
      (73, 255),
      (74, 0),
      (77, 0),
      (78, 255),
      (141, 255),
      (142, 0),
      (145, 0),
      (146, 255),
      (209, 255),
    ]) {
      expect(_alpha(rgba, 220, x, 20), a, reason: 'at $x of 200');
    }
    // 15px: one copy of 8.5, placed as `no-repeat` places it -- in the middle.
    rgba = await _paint(tester, band, 15);
    expect(_alpha(rgba, 35, 12, 20), 0);
    expect(_alpha(rgba, 35, 17, 20), 255);
    expect(_alpha(rgba, 35, 22, 20), 0);
  });
}
