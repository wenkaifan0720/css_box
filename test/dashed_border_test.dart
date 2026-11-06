import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

/// [b] painted round a [w]x[h] box at (0, 0), as RGBA.
Future<Uint8List> _paint(WidgetTester tester, BoxBorder b, int w, int h, {Color? color}) async {
  final bytes = await tester.runAsync(() async {
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    if (color == null) {
      b.paint(canvas, Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()));
    } else {
      BoxDecoration(
        color: color,
        border: b,
      ).createBoxPainter().paint(canvas, Offset.zero, ImageConfiguration(size: Size(w.toDouble(), h.toDouble())));
    }
    final image = await rec.endRecording().toImage(w, h);
    final data = await image.toByteData();
    image.dispose();
    return data!.buffer.asUint8List();
  });
  return bytes!;
}

/// Runs of painted (`D`) and clear (`.`) pixels along row [y].
String _runs(Uint8List rgba, int w, int y) {
  final out = <String>[];
  var cur = rgba[y * w * 4 + 3] > 127;
  var n = 0;
  for (var x = 0; x < w; x++) {
    final d = rgba[(y * w + x) * 4 + 3] > 127;
    if (d == cur) {
      n++;
    } else {
      out.add('${cur ? 'D' : '.'}$n');
      cur = d;
      n = 1;
    }
  }
  out.add('${cur ? 'D' : '.'}$n');
  return out.join(' ');
}

void main() {
  test("the gap nearest the dash's own that puts a dash at both ends (Chrome's counts)", () {
    // [length, width, dashes Chrome draws] from probes of a top border.
    for (final (length, width, count) in const [
      (37.0, 1.0, 8),
      (100.0, 1.0, 20),
      (37.0, 2.0, 4),
      (100.0, 2.0, 10),
      (37.0, 3.0, 5),
      (100.0, 3.0, 11),
      (37.0, 4.0, 4),
      (100.0, 4.0, 9),
      (14.0, 3.0, 2),
    ]) {
      final dash = width * (width >= 3 ? 2 : 3);
      final gap = DashedBorder.gapFor(length, dash, width * (width >= 3 ? 1 : 2));
      expect((length + gap) / (dash + gap), closeTo(count, 1e-9), reason: '$length at $width');
    }
  });

  testWidgets("a 2px dashed box: Chrome's dashes on every side, one at each corner", (tester) async {
    const side = BorderSide(color: Color(0xFF000000), width: 2);
    final rgba = await _paint(tester, const DashedBorder(top: side, right: side, bottom: side, left: side), 100, 40);
    expect(_runs(rgba, 100, 1), 'D6 .4 D6 .5 D6 .4 D6 .5 D6 .4 D6 .5 D6 .4 D6 .5 D6 .4 D6');
    expect(_runs(rgba, 100, 38), 'D6 .4 D6 .5 D6 .4 D6 .5 D6 .4 D6 .5 D6 .4 D6 .5 D6 .4 D6');
  });

  testWidgets('a side no longer than two dashes is solid, and a clear side paints nothing', (tester) async {
    final rgba = await _paint(
      tester,
      const DashedBorder(
        bottom: BorderSide(color: Color(0xFF000000), width: 2),
        top: BorderSide(color: Color(0x00000000), width: 2),
      ),
      10,
      10,
    );
    expect(_runs(rgba, 10, 9), 'D10');
    expect(_runs(rgba, 10, 0), '.10');
  });

  testWidgets("the box's colour shows between the dashes, out to the border box's edge", (tester) async {
    // A decoration pulls its colour in by half an opaque solid side of a
    // `Border`; Chrome paints the background under the whole border.
    const side = BorderSide(color: Color(0xFF000000), width: 2);
    final rgba = await _paint(tester, const DashedBorder(top: side), 100, 40, color: const Color(0xFFFF0000));
    for (final x in const [7, 8]) {
      final i = x * 4;
      expect(rgba.sublist(i, i + 4), [255, 0, 0, 255], reason: 'the gap at $x on the top row');
    }
  });

  /// Runs down column [x], as [_runs] reads a row.
  String columnRuns(Uint8List rgba, int w, int h, int x) {
    final out = <String>[];
    bool at(int y) => rgba[(y * w + x) * 4 + 3] > 127;
    var cur = at(0);
    var n = 0;
    for (var y = 0; y < h; y++) {
      if (at(y) == cur) {
        n++;
      } else {
        out.add('${cur ? 'D' : '.'}$n');
        cur = at(y);
        n = 1;
      }
    }
    out.add('${cur ? 'D' : '.'}$n');
    return out.join(' ');
  }

  testWidgets("a 2px dotted box: Chrome's dots, a whole one at each end", (tester) async {
    // Read off Chrome (border-dashed p5): a side of 4n pixels loses a
    // pixel from the gap after its first dot and before its last.
    const side = BorderSide(color: Color(0xFF000000), width: 2);
    final rgba = await _paint(tester, const DashedBorder.fromBorderSide(side, dotted: true), 100, 40);
    expect(
      columnRuns(rgba, 100, 40, 0),
      [
        'D2',
        '.1',
        for (var i = 0; i < 8; i++) ...['D2', '.2'],
        'D2',
        '.1',
        'D2',
      ].join(' '),
    );
    expect(
      _runs(rgba, 100, 0),
      [
        'D2',
        '.1',
        for (var i = 0; i < 23; i++) ...['D2', '.2'],
        'D2',
        '.1',
        'D2',
      ].join(' '),
    );
  });

  testWidgets('a dotted side an odd number of dots long needs no end dots of its own', (tester) async {
    const side = BorderSide(color: Color(0xFF000000), width: 2);
    final rgba = await _paint(tester, const DashedBorder(top: side, dotted: true), 102, 10);
    expect(
      _runs(rgba, 102, 0),
      [
        for (var i = 0; i < 25; i++) ...['D2', '.2'],
        'D2',
      ].join(' '),
    );
  });

  testWidgets("dotted past 3px: Chrome's round dots, the ends a half dot in", (tester) async {
    // Read off Chrome: a round dot a width across on each end of a side,
    // its centre half a width in, and the rest spaced evenly between at
    // the gap nearest the width.
    const four = BorderSide(color: Color(0xFF000000), width: 4);
    var rgba = await _paint(tester, const DashedBorder.fromBorderSide(four, dotted: true), 100, 40);
    expect(
      _runs(rgba, 100, 2),
      [
        for (var i = 0; i < 12; i++) ...['D4', '.4'],
        'D4',
      ].join(' '),
    );
    expect(columnRuns(rgba, 100, 40, 2), 'D4 .3 D4 .4 D3 .4 D3 .4 D4 .3 D4');
    const six = BorderSide(color: Color(0xFF000000), width: 6);
    rgba = await _paint(tester, const DashedBorder.fromBorderSide(six, dotted: true), 60, 30);
    expect(_runs(rgba, 60, 3), 'D6 .5 D6 .5 D6 .4 D6 .5 D6 .5 D6');
    expect(columnRuns(rgba, 60, 30, 3), 'D6 .6 D6 .6 D6');
  });

  testWidgets('a dashed side with room for two and no more gets the pair, scaled', (tester) async {
    // 2px dashes are 6 on a 4 gap: 14px holds two at 6 / 14 * 14.
    const side = BorderSide(color: Color(0xFF000000), width: 2);
    final rgba = await _paint(tester, const DashedBorder(top: side), 16, 10);
    expect(_runs(rgba, 16, 0), 'D6 .4 D6');
  });

  group('round rounded corners', () {
    /// [b] painted round a [w]x[h] box with corners [r], as RGBA.
    Future<Uint8List> paintRound(WidgetTester tester, BoxBorder b, int w, int h, double r) async {
      final bytes = await tester.runAsync(() async {
        final rec = ui.PictureRecorder();
        b.paint(Canvas(rec), Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), borderRadius: BorderRadius.circular(r));
        final image = await rec.endRecording().toImage(w, h);
        final data = await image.toByteData();
        image.dispose();
        return data!.buffer.asUint8List();
      });
      return bytes!;
    }

    /// Runs along row [y] from [x0] to [x1].
    String runs(Uint8List rgba, int w, int y, int x0, int x1) {
      final out = <String>[];
      bool at(int x) => rgba[(y * w + x) * 4 + 3] > 127;
      var cur = at(x0);
      var n = 0;
      for (var x = x0; x < x1; x++) {
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

    testWidgets("a 1px border's path is its outer edge, measured as Skia measures it", (tester) async {
      // Read off Chrome 151: `1px dashed`, `border-radius: 11.6px`, a
      // 1001x401 border box -- the left edge, the end of the path, where
      // a length a pixel out drifts the dashes by one.
      const side = BorderSide(color: Color(0xFF000000), width: 1);
      final rgba = await paintRound(tester, const DashedBorder.fromBorderSide(side), 1001, 401, 11.6);
      final col = <String>[];
      bool at(int y) => rgba[(y * 1001) * 4 + 3] > 127;
      var cur = at(14);
      var n = 0;
      for (var y = 14; y < 388; y++) {
        if (at(y) == cur) {
          n++;
        } else {
          col.add('${cur ? 'D' : '.'}$n');
          cur = at(y);
          n = 1;
        }
      }
      col.add('${cur ? 'D' : '.'}$n');
      expect(
        col.join(' '),
        [
          '.2',
          for (var i = 0; i < 74; i++) ...['D3', '.2'],
          'D2',
        ].join(' '),
      );
    });

    testWidgets("corners that are shares of the box: the ellipse they come to, dashed round", (tester) async {
      // Read off Chrome 151: `2px dashed; border-radius: 50%` on a 300x54
      // border box -- the corners 150 by 27, read off the box at paint.
      final bytes = await tester.runAsync(() async {
        final rec = ui.PictureRecorder();
        const DashedBorder.fromBorderSide(
          BorderSide(color: Color(0xFF000000), width: 2),
          corners: PercentCornerBorder(all: FractionalRadius(0.5, 0.5)),
        ).paint(Canvas(rec), const Rect.fromLTWH(0, 0, 300, 54));
        final image = await rec.endRecording().toImage(300, 54);
        final data = await image.toByteData();
        image.dispose();
        return data!.buffer.asUint8List();
      });
      final rgba = bytes!;
      expect(runs(rgba, 300, 0, 0, 300), '.121 D4 .5 D5 .5 D5 .4 D7 .4 D5 .5 D5 .125');
      expect(runs(rgba, 300, 1, 0, 300), '.102 D3 .4 D6 .5 D6 .4 D6 .3 D6 .4 D7 .4 D6 .4 D6 .4 D6 .4 D6 .104');
      expect(runs(rgba, 300, 53, 0, 300), '.125 D6 .4 D6 .4 D5 .4 D6 .4 D6 .4 D5 .121');
      expect(runs(rgba, 300, 27, 0, 300), 'D2 .296 D2');
    });

    test('a closed path owes no dash at an end', () {
      // A SaaS landing page's 20px ring: 59 whole pixels round, 12 dashes 1.917 apart.
      expect(DashedBorder.closedGapFor(59, 3, 2), closeTo(1.9167, 1e-4));
      // Read off Chrome: 558px round a 2px border, 56 dashes of 6.
      expect(DashedBorder.closedGapFor(558, 6, 4), closeTo(3.9643, 1e-4));
      expect(DashedBorder.closedGapFor(550, 8, 4), closeTo(3.9565, 1e-4));
    });

    testWidgets("the path down the border's middle, dashed from the top edge's left end", (tester) async {
      // Read off Chrome 151 (`border: 2px dashed; border-radius: 30px` on
      // a 200x100 content box): the top edge from the end of its corner.
      const side = BorderSide(color: Color(0xFF000000), width: 2);
      var rgba = await paintRound(tester, const DashedBorder.fromBorderSide(side), 204, 104, 30);
      final top = [
        for (var i = 0; i < 9; i++) ...['D6', '.4'],
        'D6',
        '.3',
        for (var i = 0; i < 4; i++) ...['D6', '.4'],
        'D5',
      ];
      expect(runs(rgba, 204, 0, 30, 174), top.join(' '));
      expect(runs(rgba, 204, 1, 30, 174), top.join(' '));
      // `1px`, 12px corners on 300x120: dashes of 3 two apart.
      const thin = BorderSide(color: Color(0xFF000000), width: 1);
      rgba = await paintRound(tester, const DashedBorder.fromBorderSide(thin), 302, 122, 12);
      expect(
        runs(rgba, 302, 0, 12, 290),
        [
          for (var i = 0; i < 55; i++) ...['D3', '.2'],
          'D3',
        ].join(' '),
      );
      // `4px`, 40px corners: dashes of 8 four apart.
      const wide = BorderSide(color: Color(0xFF000000), width: 4);
      rgba = await paintRound(tester, const DashedBorder.fromBorderSide(wide), 208, 108, 40);
      expect(
        runs(rgba, 208, 1, 40, 164),
        [
          for (var i = 0; i < 10; i++) ...['D8', '.4'],
          'D4',
        ].join(' '),
      );
    });

    testWidgets('a corner no rounder than the border keeps the straight sides, clipped to the curve', (tester) async {
      // A vehicle listing: `3px dotted`, 3px corners -- the inner edge is square.
      const side = BorderSide(color: Color(0xFF000000), width: 3);
      final rgba = await paintRound(tester, const DashedBorder.fromBorderSide(side, dotted: true), 126, 46, 3);
      final square = await _paint(tester, const DashedBorder.fromBorderSide(side, dotted: true), 126, 46);
      expect(runs(rgba, 126, 1, 3, 123), runs(square, 126, 1, 3, 123));
      // The outer corner is cut away.
      expect(rgba[3], lessThan(128));
      expect(square[3], greaterThan(127));
    });

    testWidgets('one corner round: the two sides beside it the ring\'s dashes, the other two the line\'s', (
      tester,
    ) async {
      // Read off Chrome 151 (fixtures/border-dashed-rounded d12): `1px
      // dashed` black, `border-radius: 16px 0 0 0` on a 160x60 border box,
      // how much of each pixel along the four edges is ink. The top and the
      // left bend, dashed round the whole rounded rectangle from the top
      // edge's left end and cut on their diagonals; the right and the
      // bottom do not, dashed along each side end to end.
      final bytes = await tester.runAsync(() async {
        final rec = ui.PictureRecorder();
        const DashedBorder.fromBorderSide(BorderSide(color: Color(0xFF000000), width: 1)).paint(
          Canvas(rec),
          const Rect.fromLTWH(0, 0, 160, 60),
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(16)),
        );
        final image = await rec.endRecording().toImage(160, 60);
        final data = await image.toByteData();
        image.dispose();
        return data!.buffer.asUint8List();
      });
      final rgba = bytes!;
      int ink(int x, int y) => rgba[(y * 160 + x) * 4 + 3];
      final chrome = {
        'top': [
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          78,
          163,
          27,
          0,
          221,
          255,
          255,
          255,
          0,
          0,
          255,
          255,
          255,
          0,
          0,
          244,
          255,
          255,
          10,
          0,
          238,
          255,
          255,
          16,
          0,
          232,
          255,
          255,
          22,
          0,
          226,
          255,
          255,
          28,
          0,
          220,
          255,
          255,
          34,
          0,
          214,
          255,
          255,
          40,
          0,
          208,
          255,
          255,
          46,
          0,
          202,
          255,
          255,
          52,
          0,
          196,
          255,
          255,
          58,
          0,
          190,
          255,
          255,
          64,
          0,
          184,
          255,
          255,
          70,
          0,
          178,
          255,
          255,
          76,
          0,
          172,
          255,
          255,
          82,
          0,
          166,
          255,
          255,
          88,
          0,
          160,
          255,
          255,
          94,
          0,
          154,
          255,
          255,
          100,
          0,
          148,
          255,
          255,
          106,
          0,
          142,
          255,
          255,
          112,
          0,
          136,
          255,
          255,
          118,
          0,
          130,
          255,
          255,
          124,
          0,
          125,
          255,
          255,
          129,
          0,
          119,
          255,
          255,
          135,
          0,
          113,
          255,
          255,
          141,
          0,
          107,
          255,
          255,
          147,
          0,
          101,
          255,
          255,
          153,
          0,
          95,
          255,
          255,
          159,
          0,
          89,
          255,
          255,
          255,
        ],
        'right': [
          255,
          255,
          255,
          0,
          0,
          211,
          255,
          255,
          43,
          0,
          163,
          255,
          255,
          91,
          0,
          119,
          255,
          255,
          135,
          0,
          71,
          255,
          255,
          183,
          0,
          23,
          255,
          255,
          231,
          0,
          0,
          235,
          255,
          255,
          19,
          0,
          187,
          255,
          255,
          67,
          0,
          139,
          255,
          255,
          115,
          0,
          95,
          255,
          255,
          159,
          0,
          47,
          255,
          255,
          207,
          0,
          0,
          255,
          255,
          255,
        ],
        'bottom': [
          255,
          255,
          255,
          0,
          0,
          239,
          255,
          255,
          15,
          0,
          223,
          255,
          255,
          31,
          0,
          207,
          255,
          255,
          47,
          0,
          191,
          255,
          255,
          63,
          0,
          175,
          255,
          255,
          79,
          0,
          159,
          255,
          255,
          95,
          0,
          143,
          255,
          255,
          111,
          0,
          123,
          255,
          255,
          131,
          0,
          107,
          255,
          255,
          147,
          0,
          91,
          255,
          255,
          163,
          0,
          75,
          255,
          255,
          179,
          0,
          59,
          255,
          255,
          195,
          0,
          43,
          255,
          255,
          211,
          0,
          27,
          255,
          255,
          227,
          0,
          11,
          255,
          255,
          243,
          0,
          0,
          247,
          255,
          255,
          7,
          0,
          231,
          255,
          255,
          23,
          0,
          215,
          255,
          255,
          39,
          0,
          199,
          255,
          255,
          55,
          0,
          183,
          255,
          255,
          71,
          0,
          167,
          255,
          255,
          87,
          0,
          151,
          255,
          255,
          103,
          0,
          135,
          255,
          255,
          119,
          0,
          115,
          255,
          255,
          139,
          0,
          99,
          255,
          255,
          155,
          0,
          83,
          255,
          255,
          171,
          0,
          67,
          255,
          255,
          187,
          0,
          51,
          255,
          255,
          203,
          0,
          35,
          255,
          255,
          219,
          0,
          19,
          255,
          255,
          235,
          0,
          0,
          255,
          255,
          255,
        ],
        'left': [
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          0,
          15,
          80,
          24,
          0,
          169,
          248,
          255,
          0,
          0,
          192,
          255,
          255,
          64,
          0,
          192,
          255,
          255,
          64,
          0,
          192,
          255,
          255,
          64,
          0,
          192,
          255,
          255,
          64,
          0,
          192,
          255,
          255,
          64,
          0,
          192,
          255,
          255,
          64,
          0,
          192,
          255,
          255,
          64,
          0,
          192,
          255,
          255,
          64,
          0,
          255,
        ],
      };
      final ours = {
        'top': [for (var x = 0; x < 160; x++) ink(x, 0)],
        'right': [for (var y = 0; y < 60; y++) ink(159, y)],
        'bottom': [for (var x = 0; x < 160; x++) ink(x, 59)],
        'left': [for (var y = 0; y < 60; y++) ink(0, y)],
      };
      for (final side in chrome.keys) {
        final a = chrome[side]!, b = ours[side]!;
        final off = [for (var i = 0; i < a.length; i++) (a[i] - b[i]).abs()].reduce(math.max);
        expect(off, lessThanOrEqualTo(16), reason: '$side: $b');
      }
    });
  });
}
