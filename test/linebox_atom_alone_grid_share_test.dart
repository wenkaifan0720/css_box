// AN ATOMIC INLINE ALONE ON ITS LINE, ON ITS BASELINE, IS A ROW OF THE
// STRUT AND IT WHERE NO WALK FOR A LAST BASELINE ASKED DRY COMES DOWN TO
// THE LINE. css_box's line box answers that walk (`dryLastBaselineOf`,
// `dry.dart`) off its paragraph's last line (`linebox.dart`,
// `dryLastBaseline`), and a stock `Row` with the walk's own fallback, its
// first baseline -- two numbers for an inline whose box is not a whole
// number of pixels. Only `RenderLastBaseline` asked its baseline dry starts
// the walk (`baseline.dart`; an inline-block's baseline is its last line
// box's, CSS 2.1 10.8.1), and it steps into the LAST child of a box of
// several: a line with a line after it, or one in a grid with nothing round
// it that stands on its last line, is never asked it. The stock pass writes
// the row there (`lossy.dart`, `_atomAloneL`, `_dryLastMissesL`): a product site's
// and the product site's buttons, a music store's `Download` and a docs site's chips,
// inline-blocks alone on their lines in a grid's cells. This pins the two
// spellings to the same boxes -- the inline, the line, what is beside it on
// a flex line that stands its items on their baselines, which asks each
// item its baseline dry before it lays anything out (css-flexbox-1 8.5,
// `flex_line.dart`), and what is laid out after them -- with a line after
// the inline's in a column and a cell after its cell in a grid, at widths
// that wrap the words of the inline onto one line to ten
// (fixtures/inline-block-alone-grid p1, p2). NEGATIVE: the column's last
// line, which the walk comes down to, stands the boxes on the flex line a
// fraction of a pixel apart (n1).
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:css_box/css_box.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Inter's ascent and descent, a share of the em.
late double _asc, _desc;

double _up4(double v) => (v * 1e4).roundToDouble() / 1e4;

/// Blink's split of a [lh] line of Inter at [size]: the ascent and descent
/// rounded, the half of the leading above the baseline floored.
double _blinkUp(double size, double lh) {
  final a = (_asc * size).roundToDouble(), d = (_desc * size).roundToDouble();
  return a + ((lh - a - d) / 2).floorToDouble();
}

/// The strut as the lowerer writes it round a line of widgets: at the size
/// whose even split is Blink's, a minimum (`forceStrutHeight: false`).
StrutStyle _strut(double size, double lh) {
  final up = _blinkUp(size, lh);
  final at = _up4((up - (lh - up)) / (_asc - _desc));
  return StrutStyle(
    fontFamily: 'Fx',
    fontSize: at,
    height: lh / at,
    leading: 0,
    leadingDistribution: TextLeadingDistribution.even,
  );
}

/// The strut the lowerer sets a paragraph of text on: every line [lh].
StrutStyle _forced(double size, double lh) => StrutStyle(
  fontFamily: 'Fx',
  fontSize: size,
  height: lh / size,
  leading: 0,
  leadingDistribution: TextLeadingDistribution.even,
  forceStrutHeight: true,
);

TextStyle _fx(double size, [double? lh]) => TextStyle(
  fontFamily: 'Fx',
  fontSize: size,
  height: lh == null ? null : lh / size,
  leadingDistribution: TextLeadingDistribution.even,
);

typedef _Atom = ({String name, double size, double lh, Widget Function() atom});

/// The line as css_box lays it out ([told]), or as the stock pass writes
/// it: a row of the strut -- a box of the line's height standing on its
/// ascent -- and the inline, on their baselines.
Widget _spelled(_Atom l, {required bool told}) {
  final up = _blinkUp(l.size, l.lh);
  if (!told) {
    return Row(
      key: const ValueKey('box'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        SizedBox(
          width: 0,
          height: l.lh,
          child: Baseline(baseline: up, baselineType: TextBaseline.alphabetic, child: const Text('')),
        ),
        Flexible(child: l.atom()),
      ],
    );
  }
  return LineBox(
    key: const ValueKey('box'),
    lineHeight: l.lh,
    ascent: up,
    child: Text.rich(
      TextSpan(
        children: [
          const TextSpan(text: '\u200B'),
          WidgetSpan(child: l.atom(), alignment: PlaceholderAlignment.baseline, baseline: TextBaseline.alphabetic),
        ],
      ),
      style: _fx(l.size),
      strutStyle: _strut(l.size, l.lh),
    ),
  );
}

Widget _later() =>
    Text('Updated two hours ago', key: const ValueKey('later'), style: _fx(16, 24), strutStyle: _forced(16, 24));

/// Where the line stands under the box that stands on its last line.
enum _Shape {
  /// A column with a line after the inline's (p1).
  lineAfter,

  /// A grid with a cell after the inline's cell, the inline's line the last
  /// in it (p2).
  cellAfter,

  /// NEGATIVE: the column's last line (n1).
  lastLine,
}

Widget _held(_Atom l, _Shape shape, {required bool told}) => switch (shape) {
  _Shape.lineAfter => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _spelled(l, told: told),
      _later(),
    ],
  ),
  _Shape.cellAfter => Tracks(
    columns: const [TrackSize.flex(1), TrackSize.flex(1)],
    spacing: 8,
    children: [
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Above', style: _fx(16, 24), strutStyle: _forced(16, 24)),
          _spelled(l, told: told),
        ],
      ),
      _later(),
    ],
  ),
  _Shape.lastLine => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _later(),
      _spelled(l, told: told),
    ],
  ),
};

/// The line under an inline-block that stands on its last line, an item
/// of a flex line on its baselines beside one of text, with a box after
/// the line, in [width].
Widget _page(_Atom l, _Shape shape, double width, {required bool told}) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FlexLine(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            children: [
              FlexCell(
                child: Text('Beside', key: const ValueKey('beside'), style: _fx(16, 24), strutStyle: _forced(16, 24)),
              ),
              FlexCell(
                grow: 1,
                child: LastBaseline(
                  key: const ValueKey('lb'),
                  child: _held(l, shape, told: told),
                ),
              ),
            ],
          ),
          const SizedBox(key: ValueKey('after'), height: 5),
        ],
      ),
    ),
  ),
);

/// How far apart the two spellings put anything, and what is furthest
/// apart.
Future<(double, String)> _apart(WidgetTester t, _Atom l, _Shape shape, double width) async {
  final got = <bool, Map<String, double>>{};
  for (final told in [true, false]) {
    await t.pumpWidget(_page(l, shape, width, told: told));
    expect(t.takeException(), isNull, reason: '${l.name} ${shape.name} at $width');
    got[told] = {
      for (final k in ['a', 'box', 'beside', 'lb', 'later', 'after']) ...{
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

const _widths = [60.0, 90.0, 130.0, 200.0, 320.0, 700.0];

void main() {
  setUpAll(() async {
    final bytes = Uint8List.fromList(File('test/fonts/Inter.ttf').readAsBytesSync());
    await (FontLoader('Fx')..addFont(Future.value(ByteData.view(bytes.buffer)))).load();
    final tp = TextPainter(
      text: const TextSpan(
        text: 'x',
        style: TextStyle(fontFamily: 'Fx', fontSize: 1000),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final m = tp.computeLineMetrics().first;
    _asc = m.ascent / 1000;
    _desc = m.descent / 1000;
    tp.dispose();
  });

  final atoms = <_Atom>[
    // A card -- a picture of a stated height over words that wrap -- alone
    // on a 23px line of 13px text (a news site's story cards).
    (
      name: 'card of words that wrap',
      size: 13,
      lh: 23,
      atom: () => Padding(
        key: const ValueKey('a'),
        padding: const EdgeInsets.all(4),
        child: Column(
          children: [
            const SizedBox(width: 40, height: 40),
            Text('Watch the full story tonight on the late news', style: _fx(13, 18)),
          ],
        ),
      ),
    ),
    // The music store's `Download`, a 44px button let out of its width, alone on a
    // 22px line of 14px text.
    (
      name: 'button of a stated height let out of its width',
      size: 14,
      lh: 22,
      atom: () => OverflowBox(
        key: const ValueKey('a'),
        minWidth: 0,
        maxWidth: double.infinity,
        fit: OverflowBoxFit.deferToChild,
        alignment: Alignment.topLeft,
        child: SizedBox(
          height: 44,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 33, vertical: 1),
            child: Text('Download', softWrap: false, style: _fx(14, 21)),
          ),
        ),
      ),
    ),
    // A chip padded a fraction of a pixel, alone on a 22.75px line of 15px
    // text: the line box answers the walk for its last baseline dry a
    // quarter of a pixel over the row's (n1).
    (
      name: 'chip padded a fraction of a pixel',
      size: 15,
      lh: 22.75,
      atom: () => Padding(
        key: const ValueKey('a'),
        padding: const EdgeInsets.only(top: 0.45, bottom: 2),
        child: Text('Hello there', style: _fx(15, 19.7)),
      ),
    ),
  ];

  for (final l in atoms) {
    for (final shape in [_Shape.lineAfter, _Shape.cellAfter]) {
      testWidgets('past the walk for a last baseline, the row is the line box (${l.name}, ${shape.name})', (t) async {
        for (final width in _widths) {
          final (d, at) = await _apart(t, l, shape, width);
          expect(d, lessThan(1e-3), reason: '${l.name} ${shape.name} at $width, $at');
        }
      });
    }
  }

  testWidgets(
    'NEGATIVE: the last line of a box on its last line, which the walk comes down to, is not the row\'s (n1)',
    (t) async {
      var worst = 0.0;
      for (final width in _widths) {
        worst = math.max(worst, (await _apart(t, atoms.last, _Shape.lastLine, width)).$1);
      }
      expect(worst, greaterThan(0.03));
    },
  );
}
