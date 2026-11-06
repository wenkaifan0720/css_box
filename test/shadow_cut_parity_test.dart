// THE SHADOW CUT IS THE SAME ON EVERY RENDERER. An outer `box-shadow`
// falls only outside its box, and an `inset` one only inside the padding
// edge (css-backgrounds-3 7.1.1), so a box with no background is not in
// its own shade. shadow.dart cuts the outline out of the shadow's reach
// with an even-odd path, and on the web it does so for EVERY shadow:
// `Path.combine(PathOperation.difference, ...)` cut no hole on Flutter's web
// renderer (3.47), and a recipe app's tab underlines -- an `inset 0 -2px 0`
// shadow -- drew as solid blocks.
//
// Each test reads pixels well inside one region (the box, the shadow, past
// its reach), never on an edge where renderers anti-alias differently, so
// the file runs unchanged on the VM and in a browser:
//
//   flutter test test/shadow_cut_parity_test.dart
//   flutter test --platform chrome test/shadow_cut_parity_test.dart
//
// tool/test_range.sh runs both on each Flutter of the tested range.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:css_box/css_box.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _red = Color(0xFFFF0000);

/// The box: 100x60 at (20, 20) of a 160x120 canvas.
const _box = Rect.fromLTWH(20, 20, 100, 60);

/// [d] painted round [_box], as RGBA bytes: its shadows blurred as an app's
/// are, where flutter_test draws every shadow unblurred unless told not to.
Future<Uint8List> _paint(WidgetTester tester, Decoration d) async {
  final bytes = await tester.runAsync(() async {
    final rec = ui.PictureRecorder();
    final was = debugDisableShadows;
    debugDisableShadows = false;
    try {
      d.createBoxPainter().paint(
        Canvas(rec),
        _box.topLeft,
        ImageConfiguration(size: _box.size, textDirection: TextDirection.ltr),
      );
    } finally {
      debugDisableShadows = was;
    }
    final image = await rec.endRecording().toImage(160, 120);
    final data = await image.toByteData();
    image.dispose();
    return data!.buffer.asUint8List();
  });
  return bytes!;
}

int _alpha(Uint8List rgba, int x, int y) => rgba[(y * 160 + x) * 4 + 3];

int _red8(Uint8List rgba, int x, int y) => rgba[(y * 160 + x) * 4];

void main() {
  testWidgets('an outer shadow with no blur falls outside the box and not inside it', (tester) async {
    final px = await _paint(
      tester,
      const OuterShadow(
        shadows: [BoxShadow(color: _red, offset: Offset(6, 6))],
      ),
    );
    // The shadow is the box moved to (26, 26)..(126, 86), less the box.
    expect(_alpha(px, 70, 50), 0, reason: 'inside the box');
    expect(_alpha(px, 30, 30), 0, reason: 'inside the box, where the shadow also is');
    expect((_alpha(px, 123, 50), _red8(px, 123, 50)), (255, 255), reason: 'right of the box');
    expect((_alpha(px, 70, 83), _red8(px, 70, 83)), (255, 255), reason: 'below the box');
    expect(_alpha(px, 10, 10), 0, reason: 'past the reach');
    expect(_alpha(px, 140, 100), 0, reason: 'past the reach');
  });

  testWidgets('a blurred outer shadow is cut out of the box and reaches past its edge', (tester) async {
    final px = await _paint(
      tester,
      const OuterShadow(
        shadows: [BoxShadow(color: _red, offset: Offset(0, 4), blurRadius: 6)],
      ),
    );
    expect(_alpha(px, 70, 50), 0, reason: 'inside the box');
    expect(_alpha(px, 70, 77), 0, reason: 'inside the box, over the thickest of the shadow');
    expect(_alpha(px, 70, 84), greaterThan(0), reason: 'below the box');
    expect(_alpha(px, 123, 50), greaterThan(0), reason: 'right of the box');
  });

  testWidgets('a spread shadow round rounded corners: outside the corners, not inside them', (tester) async {
    final px = await _paint(
      tester,
      const OuterShadow(
        shadows: [BoxShadow(color: _red, spreadRadius: 6)],
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    );
    expect(_alpha(px, 70, 50), 0, reason: 'inside the box');
    expect(_alpha(px, 36, 36), 0, reason: 'inside a rounded corner');
    expect(_alpha(px, 70, 17), 255, reason: 'above the box, within the spread');
    expect(_alpha(px, 123, 50), 255, reason: 'right of the box, within the spread');
    // The corner arcs share a centre, (36, 36): the box's is 16 round it,
    // the spread's 22.
    expect(_alpha(px, 22, 22), 255, reason: 'in the corner the box leaves, inside the spread');
    expect(_alpha(px, 15, 15), 0, reason: 'in the corner the spread leaves');
  });

  testWidgets('a shadow cast of a shape is cut out of the shape', (tester) async {
    final px = await _paint(
      tester,
      const OuterShadow(
        shadows: [BoxShadow(color: _red, offset: Offset(0, 8))],
        shape: StadiumBorder(),
      ),
    );
    expect(_alpha(px, 70, 50), 0, reason: 'inside the stadium');
    expect(_alpha(px, 70, 85), 255, reason: 'below the stadium');
    expect(_alpha(px, 70, 15), 0, reason: 'above the stadium: the shadow is cast down');
  });

  testWidgets("an inset shadow is a band inside the padding edge, the rest of the box clear", (tester) async {
    // `inset 0 -2px 0`: the hole the light comes through is the box moved
    // up by 2, so a 2px band along the bottom is in shadow.
    final px = await _paint(
      tester,
      const InnerShadow(
        shadows: [BoxShadow(color: _red, offset: Offset(0, -2))],
      ),
    );
    expect((_alpha(px, 70, 79), _red8(px, 70, 79)), (255, 255), reason: 'the band along the bottom');
    expect(_alpha(px, 70, 50), 0, reason: 'the middle of the box');
    expect(_alpha(px, 70, 21), 0, reason: 'the top of the box');
    expect(_alpha(px, 70, 85), 0, reason: 'below the box: an inset shadow stays inside');
  });

  testWidgets('an inset shadow inside a border: the band is inside the padding edge', (tester) async {
    final px = await _paint(
      tester,
      const InnerShadow(
        shadows: [BoxShadow(color: _red, offset: Offset(0, -3))],
        inset: EdgeInsets.all(4),
      ),
    );
    // The padding edge is (24, 24)..(116, 76); the band is its bottom 3px.
    expect(_alpha(px, 70, 74), 255, reason: 'the band');
    expect(_alpha(px, 70, 78), 0, reason: 'the border, under the padding edge');
    expect(_alpha(px, 70, 50), 0, reason: 'the middle of the box');
  });

  testWidgets("NEGATIVE: a BoxDecoration's boxShadow shades the inside of a box with no background", (tester) async {
    final px = await _paint(
      tester,
      const BoxDecoration(
        boxShadow: [BoxShadow(color: _red, offset: Offset(6, 6))],
      ),
    );
    expect(_alpha(px, 70, 50), 255, reason: 'the stock shadow is painted under the whole box');
    expect(_alpha(px, 123, 50), 255);
  });
}
