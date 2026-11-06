import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

/// [g] painted over a 100x60 box at (20, 20) of a 140x100 canvas, as RGBA.
Future<Uint8List> _paint(WidgetTester tester, Gradient g) async {
  final bytes = await tester.runAsync(() async {
    final rec = ui.PictureRecorder();
    BoxDecoration(gradient: g).createBoxPainter().paint(
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

int _at(Uint8List rgba, int x, int y, int channel) => rgba[(y * 140 + x) * 4 + channel];

const _red = Color(0xFFFF0000), _blue = Color(0xFF0000FF);

void main() {
  testWidgets('a stop in px is along the ray, the ending shape\'s horizontal radius (a weather site)', (tester) async {
    // `radial-gradient(at 100% 100%, black, transparent 8px)`: a farthest-corner
    // ellipse from the bottom-right corner, 141px across and 85px up.
    final rgba = await _paint(
      tester,
      const LengthStopsRadialGradient(
        colors: [Color(0xFF000000), Color(0x00000000)],
        stops: [0, 0],
        lengths: [0, 8],
        transform: GradientOval(xShare: 1, yShare: 1),
      ),
    );
    expect(_at(rgba, 119, 79, 3), greaterThan(150));
    expect(_at(rgba, 107, 79, 3), 0);
    // 6px up is past 8px along the ray: the ellipse is flatter than a circle.
    expect(_at(rgba, 119, 73, 3), 0);
    expect(_at(rgba, 119, 76, 3), inInclusiveRange(1, 150));
  });

  testWidgets('a stop past the ending shape carries the gradient on past it', (tester) async {
    // `radial-gradient(circle 10px, red, blue 20px)`: red to blue over twice
    // the circle, not blue from its edge on.
    final rgba = await _paint(
      tester,
      const LengthStopsRadialGradient(
        colors: [_red, _blue],
        stops: [0, 0],
        lengths: [0, 20],
        transform: GradientOval(circle: true, rx: 10),
      ),
    );
    expect(_at(rgba, 70, 50, 0), greaterThan(230));
    expect(_at(rgba, 85, 50, 0), inInclusiveRange(40, 90));
    expect(_at(rgba, 95, 50, 0), 0);
    expect(_at(rgba, 95, 50, 2), 255);
  });

  testWidgets('a stop before the centre is cut at it', (tester) async {
    // `radial-gradient(circle 10px, red -10px, blue 10px)`: half way at the centre.
    final rgba = await _paint(
      tester,
      const LengthStopsRadialGradient(
        colors: [_red, _blue],
        stops: [0, 0],
        lengths: [-10, 10],
        transform: GradientOval(circle: true, rx: 10),
      ),
    );
    expect(_at(rgba, 70, 50, 0), inInclusiveRange(110, 145));
    expect(_at(rgba, 70, 50, 2), inInclusiveRange(110, 145));
  });

  test('two with the same stops are equal, and not with other lengths', () {
    const a = LengthStopsRadialGradient(
      colors: [_red, _blue],
      stops: [0, 0],
      lengths: [0, 8],
      transform: GradientOval(),
    );
    const b = LengthStopsRadialGradient(
      colors: [_red, _blue],
      stops: [0, 0],
      lengths: [0, 8],
      transform: GradientOval(),
    );
    const c = LengthStopsRadialGradient(
      colors: [_red, _blue],
      stops: [0, 0],
      lengths: [0, 9],
      transform: GradientOval(),
    );
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a == c, isFalse);
  });

  test('the ray is the ending shape\'s horizontal radius', () {
    const box = Rect.fromLTWH(0, 0, 100, 60);
    expect(const GradientOval(xShare: 1, yShare: 1).ray(box), closeTo(100 * 1.41421356, 1e-6));
    expect(const GradientOval(extent: OvalExtent.closestSide).ray(box), 50);
    expect(const GradientOval(circle: true, rx: 10).ray(box), 10);
  });

  testWidgets('a repeating radial is the unit circle scaled to one period, tiled', (tester) async {
    // `repeating-radial-gradient(circle, red 0 5px, blue 5px 10px)` from
    // the middle of the box, (70, 50): red rings then blue, 5px each.
    final circle = await _paint(
      tester,
      const RadialGradient(
        colors: [_red, _red, _blue, _blue],
        stops: [0, 0.5, 0.5, 1],
        transform: GradientOval(circle: true, period: 10),
        tileMode: TileMode.repeated,
      ),
    );
    for (final (d, red) in const [(2, true), (7, false), (12, true), (17, false), (32, true)]) {
      expect(_at(circle, 70 + d, 50, 0), red ? greaterThan(230) : lessThan(25), reason: 'across $d');
    }
    // An ellipse keeps its shape: the rings are closer down (60 of the box)
    // than across (100), 6px a period down to 10 across.
    final ellipse = await _paint(
      tester,
      const RadialGradient(
        colors: [_red, _red, _blue, _blue],
        stops: [0, 0.5, 0.5, 1],
        transform: GradientOval(period: 10),
        tileMode: TileMode.repeated,
      ),
    );
    for (final (d, red) in const [(1, true), (4, false), (7, true), (10, false)]) {
      expect(_at(ellipse, 70, 50 + d, 0), red ? greaterThan(230) : lessThan(25), reason: 'down $d');
    }
    expect(_at(ellipse, 77, 50, 0), lessThan(25));
  });
}
