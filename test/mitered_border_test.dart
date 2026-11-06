import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

BorderSide _side(int c, double w) => BorderSide(color: Color(c), width: w);

void main() {
  // Chrome's picture of the same two boxes matched to 0.08/255.
  testWidgets('a rounded border of several colours, or of one over clear sides, is mitred on the diagonals', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(200, 100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    Widget box(double l, MiteredBorder border, double r) => Positioned(
      left: l,
      top: 10,
      width: 40,
      height: 40,
      child: DecoratedBox(
        decoration: BoxDecoration(border: border, borderRadius: BorderRadius.circular(r)),
      ),
    );
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: ColoredBox(
          color: const Color(0xFFE9E4DA),
          child: Stack(
            textDirection: TextDirection.ltr,
            children: [
              // A news site's spinner: dark on top, light on the other sides.
              box(
                10,
                MiteredBorder(
                  top: _side(0xFF4D4D4D, 3),
                  right: _side(0xFFFEFEFE, 3),
                  bottom: _side(0xFFFEFEFE, 3),
                  left: _side(0xFFFEFEFE, 3),
                ),
                20,
              ),
              // One colour over three clear sides: an arc of even thickness.
              box(
                70,
                MiteredBorder(top: _side(0xFF1D4ED8, 4), right: _side(0, 4), bottom: _side(0, 4), left: _side(0, 4)),
                20,
              ),
            ],
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    late final ByteData bytes;
    late final int width;
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      width = image.width;
      bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    });
    int at(double x, double y) {
      final i = (y.floor() * width + x.floor()) * 4;
      return (bytes.getUint8(i) << 16) | (bytes.getUint8(i + 1) << 8) | bytes.getUint8(i + 2);
    }

    // The spinner's ring runs 17..20 from its centre at (30, 30).
    expect(at(30, 11.5), 0x4D4D4D, reason: 'top');
    expect(at(11.5, 30), 0xFEFEFE, reason: 'left');
    expect(at(20.75, 13.98), 0x4D4D4D, reason: '60 degrees up: the top side');
    expect(at(13.98, 20.75), 0xFEFEFE, reason: '30 degrees up: the left side');
    // The arc: its top is drawn at full thickness, its clear sides are not.
    expect(at(90, 12), 0x1D4ED8, reason: 'arc top');
    expect(at(72, 30), 0xE9E4DA, reason: 'arc left side is clear');
    expect(at(80.5, 21.5), 0xE9E4DA, reason: 'arc past 45 degrees is the clear side');
  });

  testWidgets('sides of one colour and different widths are one ring, with no seam down the corners', (tester) async {
    /// The alpha of every pixel of [b] painted round a 40x20 box.
    Future<List<int>> alphas(BoxBorder b) async {
      final bytes = await tester.runAsync(() async {
        final rec = ui.PictureRecorder();
        b.paint(Canvas(rec), const Rect.fromLTWH(0, 0, 40, 20));
        final image = await rec.endRecording().toImage(40, 20);
        final data = await image.toByteData();
        image.dispose();
        return data!.buffer.asUint8List();
      });
      return [for (var i = 3; i < bytes!.length; i += 4) bytes[i]];
    }

    // Read off Chrome (fixtures/border-thin-double b8): a border 3px on top
    // and 2px round the rest is solid through its corners.
    const ink = Color(0xFF457B9D);
    final ring = await alphas(
      MiteredBorder(
        top: _side(0xFF457B9D, 3),
        right: _side(0xFF457B9D, 2),
        bottom: _side(0xFF457B9D, 2),
        left: _side(0xFF457B9D, 2),
      ),
    );
    int at(List<int> a, int x, int y) => a[y * 40 + x];
    for (final (x, y) in const [(0, 0), (1, 0), (1, 1), (0, 2), (39, 0), (38, 2), (0, 19), (39, 19)]) {
      expect(at(ring, x, y), 255, reason: '($x, $y)');
    }
    expect(at(ring, 2, 3), 0, reason: 'inside');
    // Flutter's own `Border` draws the top and the left each by itself.
    final sides = await alphas(
      const Border(
        top: BorderSide(color: ink, width: 3),
        right: BorderSide(color: ink, width: 2),
        bottom: BorderSide(color: ink, width: 2),
        left: BorderSide(color: ink, width: 2),
      ),
    );
    expect(
      [
        for (final (x, y) in const [(0, 0), (1, 1), (0, 2)]) at(sides, x, y),
      ].any((a) => a < 255),
      isTrue,
      reason: 'a seam down the diagonal',
    );
    // Moved in by `strokeAlign`, each side by its own: the inner line of a
    // double border, 6px in on top and 4px round the rest.
    final inner = await alphas(
      MiteredBorder(
        top: BorderSide(color: ink, width: 3, strokeAlign: -5),
        right: BorderSide(color: ink, width: 2, strokeAlign: -5),
        bottom: BorderSide(color: ink, width: 2, strokeAlign: -5),
        left: BorderSide(color: ink, width: 2, strokeAlign: -5),
      ),
    );
    expect([for (var y = 0; y < 10; y++) at(inner, 20, y)], [0, 0, 0, 0, 0, 0, 255, 255, 255, 0]);
    expect([for (var x = 0; x < 8; x++) at(inner, x, 10)], [0, 0, 0, 0, 255, 255, 0, 0]);
    // A pill (fixtures/border-thin-double b9): the box's corners scaled
    // back to half its height first, as Blink scales them, and then each
    // curve inside the sides beside it less -- 7 across and 7 down under
    // the 3px top, 8 and 8 over the 2px bottom.
    Future<List<int>> painted(void Function(Canvas c) draw) async {
      final bytes = await tester.runAsync(() async {
        final rec = ui.PictureRecorder();
        draw(Canvas(rec));
        final image = await rec.endRecording().toImage(40, 20);
        final data = await image.toByteData();
        image.dispose();
        return data!.buffer.asUint8List();
      });
      return [for (var i = 3; i < bytes!.length; i += 4) bytes[i]];
    }

    const rect = Rect.fromLTWH(0, 0, 40, 20);
    final pill = await painted(
      (c) => MiteredBorder(
        top: _side(0xFF457B9D, 3),
        right: _side(0xFF457B9D, 2),
        bottom: _side(0xFF457B9D, 2),
        left: _side(0xFF457B9D, 2),
      ).paint(c, rect, borderRadius: BorderRadius.circular(999)),
    );
    final blink = await painted(
      (c) => c.drawDRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(10)),
        RRect.fromLTRBAndCorners(
          2,
          3,
          38,
          18,
          topLeft: const Radius.elliptical(8, 7),
          topRight: const Radius.elliptical(8, 7),
          bottomRight: const Radius.circular(8),
          bottomLeft: const Radius.circular(8),
        ),
        Paint()..color = ink,
      ),
    );
    expect(pill, blink);
  });
}
