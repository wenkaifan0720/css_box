// A LINE OF WHOLE PIXELS NEEDS NO LINE BOX ROUND A BOX PAST THE STRUT (CSS
// 2.1 10.8): the line box is the larger reach over the baseline of the
// strut's and each atomic inline's margin box, over the larger under it.
// Skia works a line out the same way where the strut is a minimum
// (`forceStrutHeight: false`) -- the larger ascent and the larger descent
// of the strut, the runs and the placeholders -- and rounds only the sum
// (`InternalLineMetrics::height`); so where the strut's split, every
// placeholder's reach and the line height are whole numbers, and every run
// is fitted inside the strut, the paragraph's lines are CSS's without a
// `LineBox` told them. A music store's and a price-table site's padded inline-block
// buttons on 20px and 24px lines; the lowerer (`lower.dart`, `_wholeLines`)
// writes those paragraphs as the bare `Text.rich`, and
// fixtures/inline-block-past-strut-whole is the page. A FRAMED inline box
// is a box of its own line's reach (`RenderInlineFrame` is its child's
// height and baseline): a docs site's `<code>` chips, whose line the lowerer forces
// to the union of the strut and the chip's run (`_frameUnits`). This pins the two
// spellings to the same boxes -- every placeholder, the paragraph and what
// follows it, laid out and dry -- at widths that wrap the words round the
// boxes onto one line to five.
// NEGATIVE: a box whose reach has a fraction (padded 8.5px over it, a
// line of 32.5), and a line height that is one (28.5px): Skia rounds the
// line round them, and the lowerer keeps the `LineBox` told the line's
// height.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:css_box/css_box.dart';
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

/// The strut as the lowerer writes it (`_strut`): at the size whose even
/// split is Blink's.
StrutStyle _strut(double size, double lh, {bool force = false}) {
  final up = _blinkUp(size, lh);
  final at = _up4((up - (lh - up)) / (_asc - _desc));
  return StrutStyle(
    fontFamily: 'Fx',
    fontSize: at,
    height: lh / at,
    leading: 0,
    leadingDistribution: TextLeadingDistribution.even,
    forceStrutHeight: force,
  );
}

/// A run fitted inside the strut (`_fitted`).
TextStyle _fitted(double size, double lh) {
  final up = _blinkUp(size, lh), down = lh - up;
  final skew = (_asc - _desc) * size;
  final box = (math.min(2 * up - skew, 2 * down + skew) * 100).floorToDouble() / 100;
  return TextStyle(
    fontFamily: 'Fx',
    fontSize: size,
    height: box / size,
    leadingDistribution: TextLeadingDistribution.even,
  );
}

/// An inline-block of one line of its own text, padded, as the lowerer
/// writes it: its line under a forced strut.
Widget _chip(String key, double size, double lh, double pad, {String text = 'map()', double? bottom}) => Padding(
  key: ValueKey(key),
  padding: EdgeInsets.fromLTRB(4, pad, 4, bottom ?? pad),
  child: Text(
    text,
    softWrap: false,
    style: TextStyle(
      fontFamily: 'Fx',
      fontSize: size,
      height: lh / size,
      leadingDistribution: TextLeadingDistribution.even,
    ),
    strutStyle: _strut(size, lh, force: true),
  ),
);

/// An inline-flex round one line of its own text, padded, as the lowerer
/// writes it (`_flexSplit`): its anonymous item placed at the start of its
/// one line, which is as tall as the item.
Widget _flexChip(String key, double size, double lh, double pad, {String text = 'map()'}) => Padding(
  key: ValueKey(key),
  padding: EdgeInsets.fromLTRB(4, pad, 4, pad),
  child: AlignBox(
    alignment: Alignment.centerLeft,
    widthFactor: 1,
    heightFactor: 1,
    overflowHeight: true,
    child: LineBox(
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Fx',
          fontSize: size,
          height: lh / size,
          leadingDistribution: TextLeadingDistribution.even,
        ),
        strutStyle: _strut(size, lh, force: true),
      ),
    ),
  ),
);

/// An inline box framed round a run past the strut, as the lowerer writes
/// it (`frameSpan`): its own line forced to the union of the strut and the
/// run, [up] over the baseline and [down] under it, which the frame is as
/// tall as (`RenderInlineFrame`).
WidgetSpan _framed(String key, double up, double down, String text) {
  final at = _up4((up - down) / (_asc - _desc));
  return WidgetSpan(
    alignment: PlaceholderAlignment.baseline,
    baseline: TextBaseline.alphabetic,
    child: InlineFrame(
      key: ValueKey(key),
      decoration: const BoxDecoration(color: Color(0xFFE5E7EB)),
      insets: const EdgeInsets.fromLTRB(4, 2, 4, 2),
      ascent: 15,
      descent: 5,
      child: IntrinsicWidth(
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: text,
                style: const TextStyle(
                  fontFamily: 'Fx',
                  fontSize: 15,
                  height: 1,
                  leadingDistribution: TextLeadingDistribution.even,
                ),
              ),
            ],
          ),
          softWrap: false,
          style: const TextStyle(
            fontFamily: 'Fx',
            fontSize: 16,
            height: 1,
            leadingDistribution: TextLeadingDistribution.even,
          ),
          strutStyle: StrutStyle(
            fontFamily: 'Fx',
            fontSize: at,
            height: (up + down) / at,
            leading: 0,
            leadingDistribution: TextLeadingDistribution.even,
            forceStrutHeight: true,
          ),
        ),
      ),
    ),
  );
}

WidgetSpan _atom(Widget w) =>
    WidgetSpan(child: w, alignment: PlaceholderAlignment.baseline, baseline: TextBaseline.alphabetic);

/// A picture with no baseline, standing on its bottom edge.
WidgetSpan _picture(String key, double height) => WidgetSpan(
  child: SizedBox(key: ValueKey(key), width: 30, height: height),
  alignment: PlaceholderAlignment.aboveBaseline,
  baseline: TextBaseline.alphabetic,
);

typedef _Para = ({String name, double size, double lh, List<InlineSpan> spans, List<String> keys});

_Para _para(String name, double size, double lh, List<InlineSpan> Function(TextStyle run) spans, List<String> keys) =>
    (name: name, size: size, lh: lh, spans: spans(_fitted(size, lh)), keys: keys);

/// The paragraph the lowerer writes, bare or in the `LineBox` it was told.
Widget _page(_Para p, double width, {required bool told}) {
  final text = Text.rich(
    TextSpan(children: p.spans),
    key: const ValueKey('para'),
    style: TextStyle(fontFamily: 'Fx', fontSize: p.size, height: 1, leadingDistribution: TextLeadingDistribution.even),
    strutStyle: _strut(p.size, p.lh),
  );
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            told
                ? LineBox(
                    key: const ValueKey('box'),
                    keepWords: false,
                    lineHeight: p.lh,
                    ascent: _blinkUp(p.size, p.lh),
                    child: text,
                  )
                : KeyedSubtree(key: const ValueKey('box'), child: text),
            const SizedBox(key: ValueKey('after'), height: 5),
          ],
        ),
      ),
    ),
  );
}

/// How far apart the two spellings put anything, laid out and dry.
Future<double> _apart(WidgetTester t, _Para p, double width) async {
  final got = <bool, List<double>>{};
  for (final told in [true, false]) {
    await t.pumpWidget(_page(p, width, told: told));
    final box = t.renderObject<RenderBox>(find.byKey(const ValueKey('box')));
    final room = BoxConstraints(maxWidth: width);
    got[told] = [
      for (final k in [...p.keys, 'after']) ...[
        t.getRect(find.byKey(ValueKey(k))).left,
        t.getRect(find.byKey(ValueKey(k))).top,
        t.getRect(find.byKey(ValueKey(k))).bottom,
      ],
      box.size.height,
      _asked(() => box.getDistanceToBaseline(TextBaseline.alphabetic)) ?? -1,
      _asked(() => box.getDryLayout(room).height),
      _asked(() => box.getMinIntrinsicHeight(width)),
      _asked(() => box.getDryBaseline(room, TextBaseline.alphabetic)) ?? -1,
    ];
  }
  var worst = 0.0;
  for (var i = 0; i < got[true]!.length; i++) {
    worst = math.max(worst, (got[true]![i] - got[false]![i]).abs());
  }
  return worst;
}

/// [ask] of a box laid out, or dry, as a box above it would ask it. The
/// framework asserts a box is not asked its laid-out baseline outside a
/// layout, and checks a dry baseline twice; css_box's own `dryBaselineOf`
/// asks under the same escape hatch.
T _asked<T>(T Function() ask) {
  final was = RenderObject.debugCheckingIntrinsics;
  RenderObject.debugCheckingIntrinsics = true;
  try {
    return ask();
  } finally {
    RenderObject.debugCheckingIntrinsics = was;
  }
}

const _widths = [70.0, 110.0, 160.0, 230.0, 400.0, 900.0];

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

  final whole = <(String, _Para Function())>[
    // a docs site's chip, padded 8px: 21 over the baseline and 11 under, on a 16px
    // line of 28 (20 over 8).
    (
      'chip padded past both sides',
      () => _para(
        'chip padded past both sides',
        16,
        28,
        (run) => [
          TextSpan(text: 'Call ', style: run),
          _atom(_chip('a', 13, 16, 8)),
          TextSpan(text: ' on the array, then reduce it to one value', style: run),
        ],
        ['a'],
      ),
    ),
    // The music store's button: a 15px/20px label padded 3px on a 13px/20px line.
    (
      'button past the top',
      () => _para(
        'button past the top',
        13,
        20,
        (run) => [
          TextSpan(text: 'Hear more from the artist ', style: run),
          _atom(_chip('a', 15, 20, 3, text: 'Follow')),
          TextSpan(text: ' every week', style: run),
        ],
        ['a'],
      ),
    ),
    // An inline-flex round one word, padded 8px like a docs site's chip.
    (
      'inline-flex padded past both sides',
      () => _para(
        'inline-flex padded past both sides',
        16,
        28,
        (run) => [
          TextSpan(text: 'Call ', style: run),
          _atom(_flexChip('a', 13, 16, 8)),
          TextSpan(text: ' on the array, then reduce it to one value', style: run),
        ],
        ['a'],
      ),
    ),
    // A picture standing past the strut, and a chip under it.
    (
      'picture and chip',
      () => _para(
        'picture and chip',
        15,
        24,
        (run) => [
          TextSpan(text: 'Bitcoin ', style: run),
          _picture('a', 26),
          TextSpan(text: ' and Ethereum ', style: run),
          _atom(_chip('b', 12, 18, 6, text: 'BTC')),
          TextSpan(text: ' trade up today on the market', style: run),
        ],
        ['a', 'b'],
      ),
    ),
    // a docs site's `<code>` chips: inline boxes framed round a run of a line 20
    // over 9 in prose of 20 over 8 (`lower.dart`, `_frameUnits`).
    (
      'framed runs past the strut',
      () => _para(
        'framed runs past the strut',
        16,
        28,
        (run) => [
          TextSpan(text: 'Call ', style: run),
          _framed('a', 20, 9, 'map()'),
          TextSpan(text: ' on the array, then ', style: run),
          _framed('b', 20, 9, 'reduce()'),
          TextSpan(text: ' it to one value at the end of the chain', style: run),
        ],
        ['a', 'b'],
      ),
    ),
    // Boxes alone on their lines, no word of the paragraph's own.
    (
      'boxes alone',
      () => _para(
        'boxes alone',
        16,
        24,
        (run) => [
          const TextSpan(text: '\u200B'),
          _atom(_chip('a', 14, 20, 9, text: 'Sign up')),
          const TextSpan(text: ' '),
          _atom(_chip('b', 14, 20, 5, text: 'Log in')),
        ],
        ['a', 'b'],
      ),
    ),
  ];

  for (final (name, make) in whole) {
    testWidgets('every term whole: the bare paragraph is the line box ($name)', (t) async {
      final p = make();
      for (final width in _widths) {
        expect(await _apart(t, p, width), lessThan(1e-3), reason: '${p.name} at $width');
      }
    });
  }

  // NEGATIVE: padded 8.5px over and 8px under, the chip reaches 21.5 over
  // the baseline and 11 under it, a line of 32.5 that Skia rounds to 33;
  // and a 28.5px line, which Skia rounds every line of.
  testWidgets('NEGATIVE: a reach or a line height with a fraction is not the bare paragraph', (t) async {
    final fraction = _para(
      'chip padded by a fraction',
      16,
      28,
      (run) => [
        TextSpan(text: 'Call ', style: run),
        _atom(_chip('a', 13, 16, 8.5, bottom: 8)),
        TextSpan(text: ' on the array, then reduce it to one value', style: run),
      ],
      ['a'],
    );
    var worst = 0.0;
    for (final width in _widths) {
      worst = math.max(worst, await _apart(t, fraction, width));
    }
    expect(worst, greaterThan(0.25));
    final line = _para(
      'line of a fraction',
      16,
      28.5,
      (run) => [
        TextSpan(text: 'Call ', style: run),
        _atom(_chip('a', 13, 16, 8)),
        TextSpan(text: ' on the array, then reduce it to one value', style: run),
      ],
      ['a'],
    );
    worst = 0.0;
    for (final width in _widths) {
      worst = math.max(worst, await _apart(t, line, width));
    }
    expect(worst, greaterThan(0.25));
  });
}
