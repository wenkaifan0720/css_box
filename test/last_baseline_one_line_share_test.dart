// AN INLINE-BLOCK STANDS ON ITS LAST LINE BOX (CSS 2.1 10.8.1), which
// `LastBaseline` finds where the box has several. Two places it moves
// nothing, which the lowerer writes without it:
//
// ONE LINE IS ITS OWN LAST. A box that is one line of its own text at every
// width (`lower.dart`, `_lineSplit`'s `anyWidth`) answers that line's
// baseline as its first: laid out, `RenderLastBaseline.lastBaselineOf` moves
// a paragraph's first baseline down by its last caret, on the same line,
// and dry, `dryLastBaselineOf` moves it down by the lines its room wraps,
// none. A music store's and a price-table site's labelled inline-blocks;
// fixtures/inline-block-one-line-last-baseline is the page.
//
// A PARAGRAPH ASKS A WIDGET OFF ITS BASELINE NO BASELINE. A placeholder at
// `middle`, `top`, `bottom` or `aboveBaseline` is placed by its size alone
// (`rendering/paragraph.dart`, `_layoutChild`, laid out and dry; css_box's
// `LineBox` measures placeholders the same way), so a
// `LastBaseline` there is its child to every question that reaches it
// (`tidy.dart`, `_askedKind`). The price-table site's `middle` icons.
//
// This pins each pair of spellings to the same boxes -- the box, the
// paragraph and what follows it, laid out and dry -- at several widths.
// NEGATIVE: a box of words that wrap, standing on the baseline, stands on
// its last line, which its first is not.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:css_box/css_box.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// A box's text under the forced strut the lowerer sets a line of text in:
/// 16px Inter on 24px lines, 18 over 6 as Blink splits it.
Text _words(String text, {bool wraps = true}) => Text(
  text,
  softWrap: wraps,
  style: const TextStyle(
    fontFamily: 'Fx',
    fontSize: 16,
    height: 24 / 16,
    leadingDistribution: TextLeadingDistribution.even,
  ),
  strutStyle: const StrutStyle(
    fontFamily: 'Fx',
    fontSize: 16.5161,
    height: 24 / 16.5161,
    leading: 0,
    leadingDistribution: TextLeadingDistribution.even,
    forceStrutHeight: true,
  ),
);

/// An inline-block as the lowerer writes it: its frame round its text, in
/// a [width] where it states one.
Widget _box(Text text, {required bool last, double? width}) {
  final box = DecoratedBox(
    key: const ValueKey('box'),
    decoration: const BoxDecoration(color: Color(0xFF3060A0)),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(6, 5, 6, 3),
      child: width == null ? text : SizedBox(width: width, child: text),
    ),
  );
  return last ? LastBaseline(child: box) : box;
}

Widget _page(Widget box, double width, PlaceholderAlignment at, {bool lined = false}) {
  final text = Text.rich(
    TextSpan(
      children: [
        const TextSpan(text: 'Hear more from '),
        WidgetSpan(
          child: box,
          alignment: at,
          baseline: switch (at) {
            PlaceholderAlignment.baseline ||
            PlaceholderAlignment.aboveBaseline ||
            PlaceholderAlignment.belowBaseline => TextBaseline.alphabetic,
            _ => null,
          },
        ),
        // A mark standing its bottom on the line's baseline, which the box
        // stands its own on.
        const WidgetSpan(
          child: SizedBox(key: ValueKey('mark'), width: 2, height: 2),
          alignment: PlaceholderAlignment.aboveBaseline,
          baseline: TextBaseline.alphabetic,
        ),
        const TextSpan(text: ' every week'),
      ],
    ),
    key: const ValueKey('para'),
    style: const TextStyle(
      fontFamily: 'Fx',
      fontSize: 16,
      height: 1,
      leadingDistribution: TextLeadingDistribution.even,
    ),
    strutStyle: const StrutStyle(
      fontFamily: 'Fx',
      fontSize: 16.5161,
      height: 24 / 16.5161,
      leading: 0,
      leadingDistribution: TextLeadingDistribution.even,
      forceStrutHeight: false,
    ),
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
            lined ? LineBox(lineHeight: 24, ascent: 18, child: text) : text,
            const SizedBox(key: ValueKey('after'), height: 5),
          ],
        ),
      ),
    ),
  );
}

/// How far apart the box with a `LastBaseline` and without puts anything.
Future<double> _apart(
  WidgetTester t,
  Text Function() text,
  double width,
  PlaceholderAlignment at, {
  bool lined = false,
  double? boxWidth,
}) async {
  final got = <bool, List<double>>{};
  for (final last in [true, false]) {
    await t.pumpWidget(
      _page(
        _box(text(), last: last, width: boxWidth),
        width,
        at,
        lined: lined,
      ),
    );
    final para = t.renderObject<RenderBox>(find.byKey(const ValueKey('para')));
    final room = BoxConstraints(maxWidth: width);
    final box = t.getRect(find.byKey(const ValueKey('box')));
    final mark = t.getRect(find.byKey(const ValueKey('mark')));
    final after = t.getRect(find.byKey(const ValueKey('after')));
    got[last] = [
      box.left,
      box.top,
      box.bottom,
      mark.left,
      mark.top,
      after.top,
      para.size.height,
      _asked(() => para.getDistanceToBaseline(TextBaseline.alphabetic)) ?? -1,
      _asked(() => para.getDryLayout(room).height),
      _asked(() => para.getMinIntrinsicHeight(width)),
      _asked(() => para.getMaxIntrinsicHeight(width)),
      _asked(() => para.getDryBaseline(room, TextBaseline.alphabetic)) ?? -1,
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

const _widths = [60.0, 120.0, 200.0, 400.0];
const _off = [
  PlaceholderAlignment.middle,
  PlaceholderAlignment.top,
  PlaceholderAlignment.bottom,
  PlaceholderAlignment.aboveBaseline,
];

void main() {
  setUpAll(() async {
    final bytes = Uint8List.fromList(File('test/fonts/Inter.ttf').readAsBytesSync());
    await (FontLoader('Fx')..addFont(Future.value(ByteData.view(bytes.buffer)))).load();
  });

  testWidgets('one line of words is its own last: the box without a LastBaseline stands where it did', (t) async {
    for (final lined in [false, true]) {
      for (final width in _widths) {
        for (final text in [
          () => _words('Follow', wraps: false),
          () => _words('Read more', wraps: false),
          () => _words('Sign'),
        ]) {
          expect(
            await _apart(t, text, width, PlaceholderAlignment.baseline, lined: lined),
            lessThan(1e-6),
            reason: '${text().data} at $width${lined ? ' in a LineBox' : ''}',
          );
        }
      }
    }
  });

  testWidgets('off the baseline no baseline is read: a box of lines without a LastBaseline stands where it did', (
    t,
  ) async {
    for (final at in _off) {
      for (final lined in [false, true]) {
        for (final width in _widths) {
          expect(
            await _apart(t, () => _words('one two three four five'), width, at, lined: lined, boxWidth: 90),
            lessThan(1e-6),
            reason: '$at at $width${lined ? ' in a LineBox' : ''}',
          );
        }
      }
    }
  });

  // NEGATIVE: on the baseline, a box of words that wrap stands on its last
  // line, and without the `LastBaseline` on its first: the line's baseline,
  // and the mark on it, are a line or two apart.
  testWidgets('NEGATIVE: a box of lines on the baseline stands on its last', (t) async {
    for (final lined in [false, true]) {
      for (final width in [200.0, 400.0]) {
        expect(
          await _apart(
            t,
            () => _words('one two three four five'),
            width,
            PlaceholderAlignment.baseline,
            lined: lined,
            boxWidth: 90,
          ),
          greaterThan(20),
          reason: '$width${lined ? ' in a LineBox' : ''}',
        );
      }
    }
  });
}
