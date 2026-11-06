// AN ATOMIC INLINE ALONE ON ITS LINE, ON ITS BASELINE, IS A ROW OF THE
// STRUT AND IT ON THEIR BASELINES -- ASKED ITS HEIGHT TOO, where the
// inline's intrinsic height is its dry height. The line box is the larger
// ascent over the baseline of the strut's and the box's, over the larger
// descent under it (CSS 2.1 10.8): css_box's line box works that out of a
// dry layout of the inline at the line's width (`linebox.dart`,
// `_boxesOnly`), and a stock `Row` on its baselines works the same sum out
// of each child's dry baseline and its INTRINSIC height at its share
// (Flutter 3.38.5 `rendering/flex.dart`, `_getIntrinsicSize`, INTRINSIC
// CROSS SIZE, `_computeSizes`). The stock pass writes that row
// (`lossy.dart`, `_atomAloneL`) where the two heights of the inline are
// one (`_dryHighL`), and so are its two baselines (`_dryBaseHeldL`): a
// card of a stated picture over words that wrap, a music store's 44px button
// let out of its width (`OverflowBox`, which asks its child's height at
// the width it was asked at and lays it out dry under the constraints it
// was offered), a docs site's inline-block chip standing on its last line, its
// words on a forced strut; and on a line that never wraps and keeps no word
// whole, a price-table site's `$1.23M` in an `IntrinsicWidth`, whose least
// width is its greatest. This pins the two spellings to the same boxes --
// the inline, the line, what is laid out after them, the line's
// intrinsic heights, widths and dry layout -- under an `IntrinsicHeight`
// that asks the line its height, at widths that wrap the inline's words
// onto one line to ten (fixtures/inline-block-alone-measured p1-p4).
// NEGATIVE: a `SizedBox` of a width alone round words that wrap, which
// asks their height at the width IT was asked at and lays them out at its
// own (n1); a line that never wraps asked its least width, round words
// that break (n3); the
// walk for a last baseline into a column of two lines, which a row
// answers with the lower one (n4); and a chip on its last line whose words
// wrap on a strut that is a minimum, which answers its first line's
// baseline dry and its last laid out (n5). A line that never wraps and
// keeps its words whole was n2, laying its inline out at its greatest
// width; it lays it out shrink-to-fit in its room now, as CSS does (CSS
// 2.1 10.3.9; `linebox.dart`, `_hungLength`), and as the row does: the two
// spellings are one there too (n2, below).
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

typedef _Line = ({
  String name,
  double size,
  double lh,
  double? up,
  bool keepWords,
  bool nowrap,
  bool end,
  Widget Function() atom,
});

/// The line as css_box lays it out ([told]), or as the stock pass writes
/// it: a row of the strut -- a box of the line's height standing on its
/// ascent -- and the inline, on their baselines, at the line's end where
/// it is set there.
Widget _spelled(_Line l, {required bool told}) {
  final up = l.up ?? _blinkUp(l.size, l.lh);
  if (!told) {
    return Row(
      key: const ValueKey('box'),
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: l.end ? MainAxisAlignment.end : MainAxisAlignment.start,
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
    keepWords: l.keepWords,
    lineHeight: l.lh,
    ascent: up,
    child: Text.rich(
      TextSpan(
        children: [
          const TextSpan(text: '​'),
          WidgetSpan(child: l.atom(), alignment: PlaceholderAlignment.baseline, baseline: TextBaseline.alphabetic),
        ],
      ),
      textAlign: l.end ? TextAlign.end : TextAlign.start,
      softWrap: !l.nowrap,
      style: _fx(l.size),
      strutStyle: _strut(l.size, l.lh),
    ),
  );
}

/// The line in a grid that asks each item its height -- a row stretched
/// to what an `IntrinsicHeight` asks it -- with a box beside it and one
/// after, in [width].
Widget _page(_Line l, double width, {required bool told}) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _spelled(l, told: told)),
                const SizedBox(key: ValueKey('side'), width: 10),
              ],
            ),
          ),
          const SizedBox(key: ValueKey('after'), height: 5),
        ],
      ),
    ),
  ),
);

/// [ask] of a box laid out, or dry, as a box above it would ask it.
T _asked<T>(T Function() ask) {
  final was = RenderObject.debugCheckingIntrinsics;
  RenderObject.debugCheckingIntrinsics = true;
  try {
    return ask();
  } finally {
    RenderObject.debugCheckingIntrinsics = was;
  }
}

/// How far apart the two spellings put anything, laid out and asked, and
/// what is furthest apart.
Future<(double, String)> _apart(WidgetTester t, _Line l, double width) async {
  final got = <bool, Map<String, double>>{};
  for (final told in [true, false]) {
    await t.pumpWidget(_page(l, width, told: told));
    expect(t.takeException(), isNull, reason: '${l.name} at $width');
    final box = t.renderObject<RenderBox>(find.byKey(const ValueKey('box')));
    got[told] = {
      for (final k in ['a', 'box', 'side', 'after']) ...{
        '$k.left': t.getRect(find.byKey(ValueKey(k))).left,
        '$k.top': t.getRect(find.byKey(ValueKey(k))).top,
        '$k.right': t.getRect(find.byKey(ValueKey(k))).right,
        '$k.bottom': t.getRect(find.byKey(ValueKey(k))).bottom,
      },
      'baseline': _asked(() => box.getDistanceToBaseline(TextBaseline.alphabetic)) ?? -1,
      for (final w in [40.0, width - 10, width * 3, double.infinity]) ...{
        'min height at $w': _asked(() => box.getMinIntrinsicHeight(w)),
        'max height at $w': _asked(() => box.getMaxIntrinsicHeight(w)),
        if (w.isFinite) ...{
          'dry width at $w': _asked(() => box.getDryLayout(BoxConstraints(maxWidth: w)).width),
          'dry height at $w': _asked(() => box.getDryLayout(BoxConstraints(maxWidth: w)).height),
          'tight dry height at $w': _asked(() => box.getDryLayout(BoxConstraints.tightFor(width: w)).height),
          'dry baseline at $w':
              _asked(() => box.getDryBaseline(BoxConstraints(maxWidth: w), TextBaseline.alphabetic)) ?? -1,
        },
      },
      'min width': _asked(() => box.getMinIntrinsicWidth(double.infinity)),
      'max width': _asked(() => box.getMaxIntrinsicWidth(double.infinity)),
    };
  }
  var worst = (0.0, '');
  for (final k in got[true]!.keys) {
    final d = (got[true]![k]! - got[false]![k]!).abs();
    if (d > worst.$1) worst = (d, '$k: ${got[true]![k]} told, ${got[false]![k]} stock');
  }
  return worst;
}

/// a docs site's chip: a padded box on its last line round words that wrap, on a
/// forced strut or one that is a minimum.
Widget _chip({required bool forced}) => LastBaseline(
  key: const ValueKey('a'),
  child: Padding(
    padding: const EdgeInsets.only(left: 2),
    child: DecoratedBox(
      decoration: const BoxDecoration(color: Color(0xFFE5E7EB)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          'Creating new objects in the page',
          style: _fx(16, 24),
          strutStyle: forced ? _forced(16, 24) : null,
        ),
      ),
    ),
  ),
);

const _widths = [60.0, 90.0, 130.0, 200.0, 320.0, 700.0];

_Line _line(
  String name,
  double size,
  double lh,
  Widget Function() atom, {
  double? up,
  bool keepWords = true,
  bool nowrap = false,
  bool end = false,
}) => (name: name, size: size, lh: lh, up: up, keepWords: keepWords, nowrap: nowrap, end: end, atom: atom);

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

  final exact = <_Line>[
    // p1: a card -- a picture of a stated height over words that wrap --
    // alone on a 23px line of 13px text (a news site's story cards).
    _line(
      'card of words that wrap',
      13,
      23,
      () => Padding(
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
    // p2: the music store's `Download`, a 44px button let out of its width, alone
    // on a 22px line of 14px text.
    _line(
      'button of a stated height let out of its width',
      14,
      22,
      () => OverflowBox(
        key: const ValueKey('a'),
        minWidth: 0,
        maxWidth: double.infinity,
        fit: OverflowBoxFit.deferToChild,
        alignment: Alignment.topLeft,
        child: SizedBox(
          height: 44,
          child: DecoratedBox(
            decoration: const BoxDecoration(color: Color(0xFF1DA0C3)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 33, vertical: 1),
              child: Text('Download', softWrap: false, style: _fx(14, 21)),
            ),
          ),
        ),
      ),
    ),
    // p2': a docs site's chip, an inline-block that stands on its last line, its
    // words wrapping on a forced strut, alone on a 24px line of 16px text.
    _line('inline-block on its last line, of words that wrap', 16, 24, () => _chip(forced: true)),
    // p3: the price-table site's `$1.23M`, an `IntrinsicWidth` of one word let
    // out of its width, alone at the end of a 22.5px line that never wraps
    // and keeps no word whole.
    _line(
      'one word at the end of a line that never wraps',
      14,
      22.5,
      up: 16,
      keepWords: false,
      nowrap: true,
      end: true,
      () => OverflowBox(
        key: const ValueKey('a'),
        minWidth: 0,
        maxWidth: double.infinity,
        fit: OverflowBoxFit.deferToChild,
        alignment: Alignment.topLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IntrinsicWidth(
              child: Text(r'$1.23M', textAlign: TextAlign.end, softWrap: false, style: _fx(14, 21)),
            ),
          ],
        ),
      ),
    ),
  ];

  for (final l in exact) {
    testWidgets('asked its height, the row is the line box (${l.name})', (t) async {
      for (final width in _widths) {
        final (d, at) = await _apart(t, l, width);
        expect(d, lessThan(1e-3), reason: '${l.name} at $width, $at');
      }
    });
  }

  testWidgets(
    'a line that never wraps and keeps its words whole lays its inline out in its room, as the row does (n2)',
    (t) async {
      // Shrink-to-fit against the line's block (CSS 2.1 10.3.9): not its
      // greatest width, which it was laid out at before `_hungLength`.
      for (final width in _widths) {
        final (d, at) = await _apart(
          t,
          _line(
            'a line that keeps its words whole',
            13,
            23,
            nowrap: true,
            () => Text('Watch the full story', key: const ValueKey('a'), style: _fx(13, 18)),
          ),
          width,
        );
        expect(d, lessThan(1e-3), reason: 'at $width, $at');
      }
    },
  );

  testWidgets('NEGATIVE: an inline whose height or baseline asked is not its dry one is not the row\'s (n1, n3, n5)', (
    t,
  ) async {
    Future<double> worst(_Line l) async {
      var out = 0.0;
      for (final width in _widths) {
        out = math.max(out, (await _apart(t, l, width)).$1);
      }
      return out;
    }

    // n1: a box of a width alone round words that wrap.
    expect(
      await worst(
        _line(
          'a width alone round words that wrap',
          13,
          23,
          () => SizedBox(
            key: const ValueKey('a'),
            width: 120,
            child: Text('Watch the full story tonight on the late news', style: _fx(13, 18)),
          ),
        ),
      ),
      greaterThan(10),
    );
    // n3: a line that never wraps answers its least width with its
    // greatest; a row with its inline's least, two words wide.
    expect(
      await worst(
        _line(
          'a line that never wraps round two words',
          20,
          30,
          keepWords: false,
          nowrap: true,
          () => Text('\u{1F525} bStocks', key: const ValueKey('a'), softWrap: false, style: _fx(20)),
        ),
      ),
      greaterThan(10),
    );
    // n5: a box on its last line whose words wrap on a strut that is a
    // minimum answers its first line's baseline dry, its last laid out.
    expect(
      await worst(_line('a chip of words on a strut that is a minimum', 16, 24, () => _chip(forced: false))),
      greaterThan(10),
    );
  });

  testWidgets('the walk for a last baseline finds the line\'s in both, but past a column of two lines (n4)', (t) async {
    // The walk as a box on its last line starts it: `RenderLastBaseline`
    // asked its baseline (`lastBaselineOf`).
    Future<double> walked(Widget Function() atom, {required bool told}) async {
      final l = _line('walked', 16, 24, atom);
      await t.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 300,
              child: LastBaseline(
                key: const ValueKey('walk'),
                child: _spelled(l, told: told),
              ),
            ),
          ),
        ),
      );
      return _asked(
        () => t
            .renderObject<RenderBox>(find.byKey(const ValueKey('walk')))
            .getDistanceToBaseline(TextBaseline.alphabetic),
      )!;
    }

    Widget column() => Column(
      key: const ValueKey('a'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Watch', style: _fx(16, 24)),
        Text('now', style: _fx(16, 24)),
      ],
    );
    // On its last line, the inline answers the walk's number as its own.
    final last = await walked(() => LastBaseline(child: column()), told: true);
    expect(await walked(() => LastBaseline(child: column()), told: false), moreOrLessEquals(last, epsilon: 1e-3));
    // NEGATIVE: on its first line, the row's walk steps into it and finds
    // its second line, 24px under the line box's.
    final first = await walked(column, told: true);
    expect(await walked(column, told: false), moreOrLessEquals(first + 24, epsilon: 1e-3));
  });
}
