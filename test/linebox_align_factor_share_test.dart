// A LINE BOX UNDER AN `Align` OF A WIDTH FACTOR OF ONE, IN A BOX AS WIDE AS
// ITS CONTENT, IS ITS PARAGRAPH WHERE ITS WIDEST WORD FITS THE ROOM. The line
// box widens its paragraph only to keep a word whole that is wider than its
// room (`linebox.dart`, `_room`; `overflow-wrap: normal`, css-text-3 5.5).
// An `Align` lays its child out loose in the width it is handed, whatever
// its factor, and answers its child's intrinsic widths times the factor
// (`RenderPositionedBox`, `computeMaxIntrinsicWidth`): with a factor of one
// or more, a box that shrinks to its content (`IntrinsicWidth`) hands it at
// least its child's max-content, or the room -- so the walk reads on
// through it (`tidy.dart`, `_keepsContent`). A product site's customer quotes are
// cards of 432px centred in a column as wide as its content; the product site's
// menu labels stand in an `Align` of factor one in a column that shrinks to
// them, in a row's flexible item. This pins the two spellings to the same
// boxes -- the paragraph and a box after it -- at widths where the word
// fits (fixtures/align-fit-content-room p1, p2). NEGATIVE: an `Align` of a
// factor under one, which a box that shrinks to its content holds to that
// share of the child's max-content, narrower than the word (n1).
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

typedef _Shape = ({String name, Widget Function(Widget) hold});

/// [s] round the paragraph in [width], a box after it.
Widget _page(_Shape s, double width, {required bool told}) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          s.hold(_spelled(told: told)),
          _after,
        ],
      ),
    ),
  ),
);

/// How far apart the two spellings put anything, and what is furthest
/// apart.
Future<(double, String)> _apart(WidgetTester t, _Shape s, double width) async {
  final got = <bool, Map<String, double>>{};
  for (final told in [true, false]) {
    await t.pumpWidget(_page(s, width, told: told));
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

  final exact = <_Shape>[
    // p1: the product site's quotes, a 432px card centred in a column as wide as its
    // content.
    (
      name: 'a card of a length centred in a column as wide as its content',
      hold: (w) => Align(
        alignment: Alignment.topLeft,
        child: IntrinsicWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.topCenter,
                widthFactor: 1,
                child: SizedBox(width: 432, child: w),
              ),
            ],
          ),
        ),
      ),
    ),
    // p2: the product site's menu labels, at the start of a column that shrinks to
    // them, in a row's flexible item.
    (
      name: 'a label in a box that shrinks to it, in a flexible item',
      hold: (w) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: IntrinsicWidth(
              child: Align(
                alignment: Alignment.centerLeft,
                widthFactor: 1,
                heightFactor: 1,
                child: OverflowBox(
                  maxHeight: double.infinity,
                  fit: OverflowBoxFit.deferToChild,
                  alignment: Alignment.centerLeft,
                  child: w,
                ),
              ),
            ),
          ),
          const SizedBox(width: 40, height: 10),
        ],
      ),
    ),
  ];

  for (final s in exact) {
    testWidgets('where the word fits the room, the paragraph is the line box (${s.name})', (t) async {
      for (final width in const [200.0, 320.0, 500.0, 900.0]) {
        final (d, at) = await _apart(t, s, width);
        expect(d, lessThan(1e-3), reason: '${s.name} at $width, $at');
      }
    });
  }

  testWidgets('NEGATIVE: an Align of a factor under one, held to that share of its child (n1)', (t) async {
    final _Shape s = (
      name: 'a quarter',
      hold: (w) => Align(
        alignment: Alignment.topLeft,
        child: IntrinsicWidth(
          child: Align(alignment: Alignment.topLeft, widthFactor: 0.25, child: w),
        ),
      ),
    );
    var worst = 0.0;
    for (final width in const [320.0, 500.0, 900.0]) {
      worst = math.max(worst, (await _apart(t, s, width)).$1);
    }
    expect(worst, greaterThan(10));
  });
}
