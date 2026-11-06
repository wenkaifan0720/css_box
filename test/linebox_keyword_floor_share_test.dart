// A LINE BOX UNDER A FLOOR AT ITS CONTENT'S MIN-CONTENT IS ITS PARAGRAPH
// WHERE ITS WIDEST WORD FITS THE ROOM. The line box widens its paragraph
// only to keep a word whole that is wider than its room (`linebox.dart`,
// `_room`; `overflow-wrap: normal`, css-text-3 5.5). `min-width:
// min-content` is a floor a box's width is never under (CSS 2.1 10.4,
// css-sizing-3 5.1): css_box's `KeywordClamp` with a floor and no ceiling
// raises the least width it hands its child to that floor, and its most
// with it where the floor is above it -- never under the most it was
// handed (`clamp.dart`, `_bounded`: `if (hi < lo) hi = lo`) -- and, a
// `RenderProxyBox`, answers its child's intrinsics. So the walk reads on
// through it (`tidy.dart`, `_roomTo`, `_keepsContent`). A sports shop's footer
// columns are `min-width: min-content`, a heading in each. This pins the
// two spellings to the same boxes -- the paragraph and a box after it --
// at every width, where the floor holds the paragraph to its widest word
// too (fixtures/keyword-floor-room p1). NEGATIVE: a box of a length under
// the floor, narrower than the word, which the floor of its own length
// leaves as it is (n1).
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:css_box/css_box.dart';
import 'package:flutter/rendering.dart' show OverflowBoxFit;
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

TextStyle _fx(double size, [double? lh]) => TextStyle(
  fontFamily: 'Fx',
  fontSize: size,
  height: lh == null ? null : lh / size,
  leadingDistribution: TextLeadingDistribution.even,
);

const _words = 'Purpose-built for incomprehensible planning';

/// The paragraph as css_box lays it out ([told]), in a line box that keeps
/// its words whole, or as the stock pass writes it.
Widget _spelled({required bool told}) {
  final text = Text(_words, key: const ValueKey('a'), style: _fx(16, 24));
  return told ? LineBox(child: text) : text;
}

const _after = SizedBox(key: ValueKey('after'), height: 5);

/// [hold] round the paragraph in [width], a box after it.
Widget _page(Widget Function(Widget) hold, double width, {required bool told}) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          hold(_spelled(told: told)),
          _after,
        ],
      ),
    ),
  ),
);

/// How far apart the two spellings put anything, and what is furthest
/// apart.
Future<(double, String)> _apart(WidgetTester t, Widget Function(Widget) hold, double width) async {
  final got = <bool, Map<String, double>>{};
  for (final told in [true, false]) {
    await t.pumpWidget(_page(hold, width, told: told));
    t.takeException();
    got[told] = {
      for (final k in ['a', 'after']) ...{
        '$k.left': t.getRect(find.byKey(ValueKey(k))).left,
        '$k.top': t.getRect(find.byKey(ValueKey(k))).top,
        '$k.right': t.getRect(find.byKey(ValueKey(k))).right,
        '$k.bottom': t.getRect(find.byKey(ValueKey(k))).bottom,
      },
    };
  }
  var worst = (0.0, '');
  for (final k in got[true]!.keys) {
    final d = (got[true]![k]! - got[false]![k]!).abs();
    if (d > worst.$1) worst = (d, '$k: ${got[true]![k]} told, ${got[false]![k]} stock');
  }
  return worst;
}

void main() {
  setUpAll(() async {
    final bytes = Uint8List.fromList(File('test/fonts/Inter.ttf').readAsBytesSync());
    await (FontLoader('Fx')..addFont(Future.value(ByteData.view(bytes.buffer)))).load();
  });

  // p1: the sports shop's footer column, `min-width: min-content`, its heading at the
  // top of a box of no height of its own -- in a page narrower than the
  // word too.
  Widget footer(Widget w) => KeywordClamp(
    floor: ContentWidth.min,
    child: OverflowBox(
      minHeight: 0,
      maxHeight: double.infinity,
      fit: OverflowBoxFit.deferToChild,
      alignment: Alignment.topLeft,
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [w]),
    ),
  );
  // ... and in a box as wide as its content.
  Widget fit(Widget w) => Align(
    alignment: Alignment.topLeft,
    child: IntrinsicWidth(child: footer(w)),
  );

  for (final (name, hold) in [('a floor at the min-content', footer), ('in a box as wide as its content', fit)]) {
    testWidgets('the paragraph is the line box ($name)', (t) async {
      for (final width in const [60.0, 100.0, 200.0, 320.0, 500.0, 900.0]) {
        final (d, at) = await _apart(t, hold, width);
        expect(d, lessThan(1e-3), reason: '$name at $width, $at');
      }
    });
  }

  testWidgets('NEGATIVE: a box of a length under the floor, narrower than the word (n1)', (t) async {
    var worst = 0.0;
    for (final width in const [200.0, 320.0, 900.0]) {
      worst = math.max(
        worst,
        (await _apart(
          t,
          // Loose, as a block at the start of its line is: held to
          // the page's width the box would be that wide.
          (w) => Align(
            alignment: Alignment.topLeft,
            child: KeywordClamp(
              floor: ContentWidth.min,
              child: SizedBox(width: 60, child: w),
            ),
          ),
          width,
        )).$1,
      );
    }
    expect(worst, greaterThan(10));
  });
}
