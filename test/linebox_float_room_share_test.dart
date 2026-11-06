// A LINE BOX IN A FLOAT, OR IN A CONTEXT OF ITS OWN BESIDE FLOATS OF A
// WIDTH, IS ITS PARAGRAPH WHERE THE WIDEST WORD FITS WHAT THE FLOATS LEAVE.
// The line box widens its paragraph only to keep a word whole that is
// wider than its room (`linebox.dart`, `_room`; `overflow-wrap: normal`,
// css-text-3 5.5). A float flow lays a float out at the width it states, a
// length or a share of the flow's, clamped, or with none at its
// shrink-to-fit width, never under its child's min-content (CSS 2.1
// 10.3.5; `float_flow.dart`, `leaf`, `ask`); held to its width, it lays a
// box that is a context of its own and states no width in the room beside
// the floats where it stands, less its margins (9.5; `bfcSlot`) -- never
// less than the flow's width less every float before it. The stock pass
// writes the paragraph there where its widest word fits that (`lossy.dart`,
// `_floatRoomL`): a Japanese news site's headlines `overflow: hidden` beside a 96px
// picture floated right 16px off them, a price-table site's footer columns
// floated a quarter of its width each, a sports shop's header links floated of no
// width. This pins the two spellings to the same boxes -- the paragraph,
// the float beside it and a box after both -- at widths where the word
// fits, and for the float of no width at every width, the flow narrower
// than the word too (fixtures/float-room-bfc p1-p4). NEGATIVE: beside the
// picture in a flow too narrow for the word (n4), and in a float of no
// width capped under it, the line box keeps it whole and the paragraph
// breaks it.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:css_box/css_box.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

TextStyle _fx(double size, [double? lh]) => TextStyle(
  fontFamily: 'Fx',
  fontSize: size,
  height: lh == null ? null : lh / size,
  leadingDistribution: TextLeadingDistribution.even,
);

const _words = 'Explore incomprehensible AI Plays for every team';

/// The paragraph as css_box lays it out ([told]), in a line box that keeps
/// its words whole, or as the stock pass writes it.
Widget _spelled({required bool told}) {
  final text = Text(_words, key: const ValueKey('a'), style: _fx(16, 24));
  return told ? LineBox(child: text) : text;
}

/// The Japanese news site's picture: 96px floated right, 16px off what is beside it.
Widget _picture() => const FloatSlot(
  float: FloatSide.right,
  bfc: true,
  width: 96,
  height: 64,
  margin: EdgeInsets.only(left: 16),
  child: SizedBox(key: ValueKey('float'), width: 96, height: 64),
);

typedef _Flow = ({String name, List<double> widths, List<Widget> Function(Widget) kids});

/// The flow in [width], the paragraph where [f] puts it and a block after.
Widget _page(_Flow f, double width, {required bool told}) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: width,
      child: FloatFlow(
        children: [
          ...f.kids(_spelled(told: told)),
          const FloatSlot(
            clear: FloatClear.both,
            child: SizedBox(key: ValueKey('after'), height: 5),
          ),
        ],
      ),
    ),
  ),
);

/// How far apart the two spellings put anything, and what is furthest
/// apart.
Future<(double, String)> _apart(WidgetTester t, _Flow f, double width) async {
  final got = <bool, Map<String, double>>{};
  for (final told in [true, false]) {
    await t.pumpWidget(_page(f, width, told: told));
    expect(t.takeException(), isNull, reason: '${f.name} at $width');
    got[told] = {
      for (final k in ['a', 'float', 'after']) ...{
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

  final exact = <_Flow>[
    // p1: the Japanese news site, a context of its own beside the picture.
    (
      name: 'a context of its own beside a float of a width',
      widths: const [280, 320, 400, 600, 900],
      kids: (w) => [_picture(), FloatSlot(bfc: true, child: w)],
    ),
    // p2: the price-table site, columns floated a quarter of the flow each.
    (
      name: 'a float a quarter of the flow',
      widths: const [600, 700, 900, 1200],
      kids: (w) => [
        FloatSlot(float: FloatSide.left, bfc: true, widthFraction: 0.25, minWidth: 10, child: w),
        const FloatSlot(
          float: FloatSide.left,
          bfc: true,
          widthFraction: 0.25,
          minWidth: 10,
          child: SizedBox(key: ValueKey('float'), height: 30),
        ),
      ],
    ),
    // p3: a float of a length, beside the picture.
    (
      name: 'a float of a length',
      widths: const [320, 400, 600, 900],
      kids: (w) => [_picture(), FloatSlot(float: FloatSide.left, width: 160, child: w)],
    ),
    // p4: the sports shop, a float of no width, shrink-to-fit, the picture after it --
    // in a flow narrower than the word too, where the float overflows it.
    (
      name: 'a float of no width',
      widths: const [60, 120, 200, 320, 500, 900],
      kids: (w) => [FloatSlot(float: FloatSide.left, child: w), _picture()],
    ),
  ];

  for (final f in exact) {
    testWidgets('where the word fits what the floats leave, the paragraph is the line box (${f.name})', (t) async {
      for (final width in f.widths) {
        final (d, at) = await _apart(t, f, width);
        expect(d, lessThan(1e-3), reason: '${f.name} at $width, $at');
      }
    });
  }

  testWidgets('NEGATIVE: beside the picture in a flow too narrow for the word, the line box keeps it whole (n4)', (
    t,
  ) async {
    var worst = 0.0;
    for (final width in const [180.0, 200.0, 220.0]) {
      worst = math.max(worst, (await _apart(t, exact.first, width)).$1);
    }
    expect(worst, greaterThan(10));
  });

  testWidgets('NEGATIVE: in a float of no width capped under the word, the line box keeps it whole', (t) async {
    final _Flow capped = (
      name: 'a float of no width capped',
      widths: const <double>[],
      kids: (w) => [FloatSlot(float: FloatSide.left, maxWidth: 60, child: w), _picture()],
    );
    var worst = 0.0;
    for (final width in const [200.0, 320.0, 900.0]) {
      worst = math.max(worst, (await _apart(t, capped, width)).$1);
    }
    expect(worst, greaterThan(10));
  });
}
