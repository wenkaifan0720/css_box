import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

void main() {
  test('a share is of the width across and of the height down', () {
    const shape = PercentCornerBorder(all: FractionalRadius(0.05, 0.05));
    final r = shape.outer(const Rect.fromLTWH(0, 0, 200, 100));
    expect(r.tlRadiusX, 10);
    expect(r.tlRadiusY, 5);
    // The same shape on another box is another pair of numbers.
    final s = shape.outer(const Rect.fromLTWH(0, 0, 80, 300));
    expect(s.brRadiusX, 4);
    expect(s.brRadiusY, 15);
  });

  test('a length on top of the share, and the corners each their own', () {
    const shape = PercentCornerBorder(
      topLeft: FractionalRadius(0, 0, dx: 12, dy: 12),
      topRight: FractionalRadius(0.08, 0.08),
    );
    final r = shape.outer(const Rect.fromLTWH(0, 0, 100, 50));
    expect((r.tlRadiusX, r.tlRadiusY), (12, 12));
    expect((r.trRadiusX, r.trRadiusY), (8, 4));
    expect((r.brRadiusX, r.blRadiusX), (0, 0));
  });

  test('a clamp holds the sum between its bounds, and less than nothing is nothing (a right-to-left news site)', () {
    const shape = PercentCornerBorder(all: FractionalRadius(-9999, 0, dx: 14358600, dy: 3, minX: 0, maxX: 3));
    final narrow = shape.outer(const Rect.fromLTWH(0, 0, 1200, 40));
    expect((narrow.tlRadiusX, narrow.tlRadiusY), (3, 3));
    final wide = shape.outer(const Rect.fromLTWH(0, 0, 1500, 40));
    expect((wide.tlRadiusX, wide.tlRadiusY), (0, 0));
    final under = const PercentCornerBorder(
      all: FractionalRadius(0.1, 0.1, dx: -20, dy: -20),
    ).outer(const Rect.fromLTWH(0, 0, 100, 100));
    expect(under.tlRadiusX, 0);
  });

  test('a most that is a share of the box: round below a width, square past it (the right-to-left news site)', () {
    const shape = PercentCornerBorder(all: FractionalRadius(-9999, 0.5, dx: 3859610, minX: 0, maxXShare: 0.5));
    final button = shape.outer(const Rect.fromLTWH(0, 0, 64, 64));
    expect((button.tlRadiusX, button.tlRadiusY), (32, 32));
    final wide = shape.outer(const Rect.fromLTWH(0, 0, 400, 64));
    expect((wide.tlRadiusX, wide.tlRadiusY), (0, 0));
  });

  test('shares that pass their side are scaled back until they meet (css-backgrounds-3 5.1)', () {
    // 80% 20%: top-left and bottom-right 80%, the others 20% -- 100% of
    // each side, so nothing is scaled; 90% 30% is 120%, scaled by 1/1.2.
    const shape = PercentCornerBorder(
      topLeft: FractionalRadius(0.9, 0.9),
      topRight: FractionalRadius(0.3, 0.3),
      bottomRight: FractionalRadius(0.9, 0.9),
      bottomLeft: FractionalRadius(0.3, 0.3),
    );
    final r = shape.outer(const Rect.fromLTWH(0, 0, 120, 60));
    expect(r.tlRadiusX, closeTo(90, 1e-9));
    expect(r.trRadiusX, closeTo(30, 1e-9));
    expect(r.tlRadiusY, closeTo(45, 1e-9));
  });

  test('the inner edge is the border width in, each radius that much smaller and none below zero', () {
    const shape = PercentCornerBorder(side: BorderSide(width: 4), all: FractionalRadius(0.1, 0.1));
    final inner = shape.getInnerPath(const Rect.fromLTWH(0, 0, 200, 60)).getBounds();
    expect(inner, const Rect.fromLTRB(4, 4, 196, 56));
    final o = shape.outer(const Rect.fromLTWH(0, 0, 200, 60)).deflate(4);
    expect((o.tlRadiusX, o.tlRadiusY), (16, 2));
    final thin = const PercentCornerBorder(
      side: BorderSide(width: 8),
      all: FractionalRadius(0.05, 0.05),
    ).outer(const Rect.fromLTWH(0, 0, 100, 100)).deflate(8);
    expect(thin.tlRadiusX, 0);
  });

  test(
    'sides of different widths: the ring to the padding edge, each radius less the sides beside it (a SaaS landing page)',
    () {
      // A SaaS landing page's avatar ring: `border-top: 1px` round `50%` corners of a
      // 200x100 box -- the padding edge 1px down, its top corners 100 across
      // and 49 down, its bottom ones the outline's 100 and 50.
      const shape = PercentCornerBorder(
        side: BorderSide(color: Color(0xFFFFFFFF)),
        widths: EdgeInsets.only(top: 1),
        all: FractionalRadius(0.5, 0.5),
      );
      const box = Rect.fromLTWH(0, 0, 200, 100);
      expect(shape.dimensions, const EdgeInsets.only(top: 1));
      final inner = shape.getInnerPath(box);
      expect(inner.getBounds(), const Rect.fromLTRB(0, 1, 200, 100));
      final outer = shape.getOuterPath(box);
      // The crescent is along the top: at the middle it is the 1px.
      expect(outer.contains(const Offset(100, 0.5)) && !inner.contains(const Offset(100, 0.5)), isTrue);
      expect(inner.contains(const Offset(100, 1.5)), isTrue);
      // Down the sides it thins to nothing: at mid-height both edges meet.
      expect(inner.contains(const Offset(0.5, 50.5)), isTrue);
      // And the bottom is no border at all.
      expect(inner.contains(const Offset(100, 99.5)), isTrue);
      // Kept through a copy and a scale.
      expect(shape.copyWith(side: const BorderSide()).widths, const EdgeInsets.only(top: 1));
    },
  );

  test('scaled keeps its shares', () {
    const shape = PercentCornerBorder(side: BorderSide(width: 2), all: FractionalRadius(0.1, 0.2));
    final scaled = shape.scale(2) as PercentCornerBorder;
    expect(scaled.side.width, 4);
    expect(scaled.topLeft, const FractionalRadius(0.1, 0.2));
  });

  test('the padding edge clip resolves the shares on the border box and takes the border off', () {
    // 20% of a 110x70 border box round a 100x60 padding box in a frame of
    // 4 left, 6 right, 2 top and 8 bottom: 22 and 14, less the frame.
    const clip = PaddingEdgeClip(PercentCornerBorder(all: FractionalRadius(0.2, 0.2)), EdgeInsets.fromLTRB(4, 2, 6, 8));
    final path = clip.getClip(const Size(100, 60));
    expect(path.getBounds(), const Rect.fromLTWH(0, 0, 100, 60));
    // The top-left corner is 18 across and 12 down: the point 1px in from
    // both edges is outside it, and one on the diagonal well in is inside.
    expect(path.contains(const Offset(1, 1)), isFalse);
    expect(path.contains(const Offset(9, 9)), isTrue);
    // The bottom-right is 16 across and 6 down: 1px in from the bottom
    // at 4px from the right is outside; the same 7px up is inside.
    expect(path.contains(const Offset(96, 59)), isFalse);
    expect(path.contains(const Offset(96, 52)), isTrue);
  });

  test('a corner the border is wider than is square at the padding edge', () {
    // The right-to-left news site's: 3px across and down on a narrow box, a 1px frame: 2px.
    // A 4px frame takes the whole corner: square.
    const shares = PercentCornerBorder(all: FractionalRadius(-9999, 0, dx: 3859610, dy: 3, minX: 0, maxX: 3));
    const thin = PaddingEdgeClip(shares, EdgeInsets.all(1));
    const thick = PaddingEdgeClip(shares, EdgeInsets.all(4));
    expect(thin.getClip(const Size(80, 24)).contains(const Offset(0.2, 0.2)), isFalse);
    expect(thick.getClip(const Size(80, 24)).contains(const Offset(0.2, 0.2)), isTrue);
    // Wider than the threshold the corners are square at any frame.
    expect(thin.getClip(const Size(400, 24)).contains(const Offset(0.2, 0.2)), isTrue);
  });

  // fixtures/percent-corner-shape: an outline round `border-radius: 10%`
  // of a 200x60 box, read off Chrome. The ring is filled between the
  // border edge moved out by the offset and that moved out by the width,
  // each radius grown by as much: (20, 6) inside and (22, 8) outside at no
  // offset -- elliptical corners, whose edges a stroke would not trace.
  testWidgets(
    "an outline round shares of the box: Chrome's ring, grown (or shrunk) from the radii the box's size gives",
    (tester) async {
      Future<List<String>> rows(double offset, int from) async {
        final bytes = await tester.runAsync(() async {
          final rec = ui.PictureRecorder();
          OutlineRing(
            color: const Color(0xFF000000),
            width: 2,
            offset: offset,
            corners: const PercentCornerBorder(all: FractionalRadius(0.1, 0.1)),
          ).createBoxPainter().paint(Canvas(rec), const Offset(10, 10), const ImageConfiguration(size: Size(200, 60)));
          final image = await rec.endRecording().toImage(240, 100);
          final data = await image.toByteData();
          image.dispose();
          return data!.buffer.asUint8List();
        });
        String runs(int y) {
          final out = <String>[];
          bool at(int x) => bytes![(y * 240 + x) * 4 + 3] > 127;
          var cur = at(2), n = 0;
          for (var x = 2; x < 50; x++) {
            if (at(x) == cur) {
              n++;
            } else {
              out.add('${cur ? 'D' : '.'}$n');
              cur = at(x);
              n = 1;
            }
          }
          out.add('${cur ? 'D' : '.'}$n');
          return out.join(' ');
        }

        return [for (var y = 10 + from; y < 20 + from; y++) runs(y)];
      }

      expect(await rows(0, -2), [
        '.20 D28', '.15 D33', '.12 D8 .28', '.10 D5 .33', '.8 D4 .36', //
        '.7 D3 .38', '.6 D3 .39', '.6 D2 .40', '.6 D2 .40', '.6 D2 .40',
      ]);
      expect(await rows(3, -5), [
        '.21 D27', '.15 D33', '.12 D9 .27', '.10 D5 .33', '.8 D4 .36', //
        '.7 D3 .38', '.5 D3 .40', '.4 D3 .41', '.4 D2 .42', '.3 D2 .43',
      ]);
      // Pulled in, each radius shrinks by as much: (19, 5) inside and
      // (21, 7) outside at `-1px`; at `-2px` the outer edge is the border
      // edge.
      expect(await rows(-1, 0), [
        '.15 D33', '.12 D7 .29', '.10 D5 .33', '.8 D4 .36', '.7 D3 .38', //
        '.7 D2 .39', '.7 D2 .39', '.7 D2 .39', '.7 D2 .39', '.7 D2 .39',
      ]);
      expect(await rows(-2, 0), [
        '.20 D28', '.15 D33', '.12 D8 .28', '.10 D4 .34', '.9 D2 .37', //
        '.8 D2 .38', '.8 D2 .38', '.8 D2 .38', '.8 D2 .38', '.8 D2 .38',
      ]);
    },
  );

  // Pulled in past its own width the ring is inside the box: Chrome's
  // `outline: 4px; outline-offset: -9px` round `border-radius: 10%` of a
  // 300x80 box is pixel for pixel a 4px border 5px in round (25, 3)
  // corners, square inside -- the ring filled between the box less 5 and
  // less 9, each radius less as much and none below nothing.
  testWidgets('an outline pulled in past its own width is the same ring, inside the box', (tester) async {
    Future<List<int>> alphas(void Function(Canvas c) draw) async {
      final bytes = await tester.runAsync(() async {
        final rec = ui.PictureRecorder();
        draw(Canvas(rec));
        final image = await rec.endRecording().toImage(320, 100);
        final data = await image.toByteData();
        image.dispose();
        return data!.buffer.asUint8List();
      });
      return [for (var i = 3; i < bytes!.length; i += 4) bytes[i]];
    }

    const box = Rect.fromLTWH(10, 10, 300, 80);
    final ring = await alphas(
      (c) => const OutlineRing(
        color: Color(0xFF000000),
        width: 4,
        offset: -9,
        borderRadius: BorderRadius.all(Radius.elliptical(30, 8)),
      ).createBoxPainter().paint(c, box.topLeft, ImageConfiguration(size: box.size)),
    );
    final chrome = await alphas(
      (c) => c.drawDRRect(
        RRect.fromRectAndRadius(box.deflate(5), const Radius.elliptical(25, 3)),
        RRect.fromRectXY(box.deflate(9), 0, 0),
        Paint()..color = const Color(0xFF000000),
      ),
    );
    expect(ring, chrome);
    expect(ring[19 * 320 + 19], 0, reason: 'the inner corner is square: the hole reaches into it');
    expect(ring[18 * 320 + 18], 255, reason: 'the ring');
    // The same by shares of the box.
    final shares = await alphas(
      (c) => const OutlineRing(
        color: Color(0xFF000000),
        width: 4,
        offset: -9,
        corners: PercentCornerBorder(all: FractionalRadius(0.1, 0.1)),
      ).createBoxPainter().paint(c, box.topLeft, ImageConfiguration(size: box.size)),
    );
    expect(shares, chrome);
  });
}
