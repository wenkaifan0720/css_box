import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

/// [d] painted round a 200x100 box at (20, 20) of a 240x140 canvas, as RGBA.
Future<Uint8List> _paint(WidgetTester tester, Decoration d) async {
  final bytes = await tester.runAsync(() async {
    final rec = ui.PictureRecorder();
    d.createBoxPainter().paint(
      Canvas(rec),
      const Offset(20, 20),
      const ImageConfiguration(size: Size(200, 100), textDirection: TextDirection.ltr),
    );
    final image = await rec.endRecording().toImage(240, 140);
    final data = await image.toByteData();
    image.dispose();
    return data!.buffer.asUint8List();
  });
  return bytes!;
}

int _alpha(Uint8List rgba, int x, int y) => rgba[(y * 240 + x) * 4 + 3];

void main() {
  mainSeam();
  const shadows = [BoxShadow(color: Color(0x40000000), offset: Offset(0, 5), blurRadius: 10)];

  testWidgets('corners as shares of the box cast the shadow of the corners they come to', (tester) async {
    // 10% of 200 across and of 100 down: the corners a fixed radius of 20
    // by 10 would be on this box.
    final shares = await _paint(
      tester,
      const OuterShadow(
        shadows: shadows,
        corners: PercentCornerBorder(all: FractionalRadius(0.1, 0.1)),
      ),
    );
    final fixed = await _paint(
      tester,
      const OuterShadow(shadows: shadows, borderRadius: BorderRadius.all(Radius.elliptical(20, 10))),
    );
    expect(shares, fixed);
  });

  testWidgets('the shadow is cut out of the outline, and shows in the corner the outline leaves', (tester) async {
    final rgba = await _paint(
      tester,
      const OuterShadow(
        shadows: shadows,
        corners: PercentCornerBorder(all: FractionalRadius(0.2, 0.2)),
      ),
    );
    // Inside the box: nothing.
    expect(_alpha(rgba, 120, 70), 0);
    // Below it, the shadow; and in the bottom-left corner the rounding
    // leaves outside the outline (40 by 20 of it), the shadow too: (10, 97)
    // of the box is outside the corner's ellipse and inside the one the
    // offset moves 5 down, blurred or not.
    expect(_alpha(rgba, 120, 124), greaterThan(0));
    expect(_alpha(rgba, 30, 117), greaterThan(0));
  });

  // fixtures/shadow-shaped-ring: an inset shadow round shares of the box
  // is cut to the padding edge the shares come to -- here 10% of 200 by
  // 100, less a 3px border: 17 by 7.
  testWidgets('an inset shadow round shares of the box: the padding edge they come to', (tester) async {
    const inset = [BoxShadow(color: Color(0x80000000), blurRadius: 6, spreadRadius: 2)];
    final shares = await _paint(
      tester,
      const InnerShadow(
        shadows: inset,
        inset: EdgeInsets.all(3),
        corners: PercentCornerBorder(all: FractionalRadius(0.1, 0.1)),
      ),
    );
    final fixed = await _paint(
      tester,
      const InnerShadow(
        shadows: inset,
        inset: EdgeInsets.all(3),
        borderRadius: BorderRadius.all(Radius.elliptical(17, 7)),
      ),
    );
    expect(shares, fixed);
    // Nothing lands on the border.
    expect(_alpha(shares, 120, 21), 0);
    expect(_alpha(shares, 120, 24), greaterThan(0));
  });

  // fixtures/shadow-shaped-translucent: a `corner-shape: bevel` box of
  // 16px corners, 100 by 60 at (30, 30), under `0 5px 10px` black and no
  // background, read off Chrome: the bevel's own shadow, cut out of it.
  testWidgets("a bevelled outline casts Chrome's shadow of the bevel, cut out of the bevel", (tester) async {
    // The test binding paints shadows unblurred unless told otherwise, and
    // the blur is what is read here.
    debugDisableShadows = false;
    final Uint8List? bytes;
    try {
      bytes = await tester.runAsync(() async {
        final rec = ui.PictureRecorder();
        const OuterShadow(
          shadows: [BoxShadow(color: Color(0xFF000000), offset: Offset(0, 5), blurRadius: 7.79423226812159)],
          shape: CornerShapeBorder(borderRadius: BorderRadius.all(Radius.circular(16)), curvature: 0),
        ).createBoxPainter().paint(
          Canvas(rec),
          const Offset(30, 30),
          const ImageConfiguration(size: Size(100, 60), textDirection: TextDirection.ltr),
        );
        final image = await rec.endRecording().toImage(160, 130);
        final data = await image.toByteData();
        image.dispose();
        return data!.buffer.asUint8List();
      });
    } finally {
      debugDisableShadows = true;
    }
    int at(int x, int y) => bytes![(y * 160 + x) * 4 + 3];
    // Straight down from the middle of the bottom edge.
    const down = [213, 197, 179, 159, 138, 117, 96, 76, 58, 42, 29, 20, 12, 7, 3, 1];
    for (var i = 0; i < down.length; i++) {
      expect(at(80, 90 + i), closeTo(down[i], 8), reason: 'y ${90 + i}');
    }
    // Up to the bevel's line from outside it, and nothing across it.
    for (final (x, y, a) in const [(44, 30, 23), (34, 40, 45), (28, 50, 66), (26, 50, 38), (58, 28, 20)]) {
      expect(at(x, y), closeTo(a, 8), reason: '($x, $y)');
    }
    for (final (x, y) in const [(46, 30), (36, 40), (30, 50), (80, 60)]) {
      expect(at(x, y), 0, reason: '($x, $y)');
    }
  });
}

/// [d] painted round a 200x30.6 box at (20, 20.5) of a 240x80 canvas, as RGBA.
Future<Uint8List> _paintAtHalf(WidgetTester tester, Decoration d) async {
  final bytes = await tester.runAsync(() async {
    final rec = ui.PictureRecorder();
    d.createBoxPainter().paint(
      Canvas(rec),
      const Offset(20, 20.5),
      const ImageConfiguration(size: Size(200, 30.6), textDirection: TextDirection.ltr),
    );
    final image = await rec.endRecording().toImage(240, 80);
    final data = await image.toByteData();
    image.dispose();
    return data!.buffer.asUint8List();
  });
  return bytes!;
}

// fixtures/shadow-hard-edge-seam: a docs site's contents links are a `-2px 0 0`
// rule at their left on no background, at a fraction of a pixel down.
void mainSeam() {
  int alpha(Uint8List rgba, int x, int y) => rgba[(y * 240 + x) * 4 + 3];

  testWidgets('a shadow with no blur shows only outside the box, with no seam along an edge it shares', (tester) async {
    final rgba = await _paintAtHalf(
      tester,
      const OuterShadow(
        shadows: [BoxShadow(color: Color(0xFFC3C7CB), offset: Offset(-2, 0))],
      ),
    );
    // The rule: the 2px left of the box, down its height.
    expect(alpha(rgba, 18, 35), 255);
    expect(alpha(rgba, 19, 35), 255);
    // Inside the box, on the rows its top and bottom edges cut through
    // (20.5 and 51.1): nothing, as anywhere inside it.
    for (final y in [20, 35, 51]) {
      expect(alpha(rgba, 120, y), 0, reason: 'row $y');
    }
    // Above and below it: nothing either.
    expect(alpha(rgba, 120, 19), 0);
    expect(alpha(rgba, 120, 52), 0);
  });

  testWidgets('NEGATIVE: a blurred shadow is still cut out by the clip, and reaches past the edge', (tester) async {
    debugDisableShadows = false;
    try {
      final rgba = await _paintAtHalf(
        tester,
        const OuterShadow(
          shadows: [BoxShadow(color: Color(0xFF000000), offset: Offset(-2, 0), blurRadius: 4)],
        ),
      );
      expect(alpha(rgba, 120, 35), 0);
      expect(alpha(rgba, 120, 19), greaterThan(0));
    } finally {
      debugDisableShadows = true;
    }
  });
}
