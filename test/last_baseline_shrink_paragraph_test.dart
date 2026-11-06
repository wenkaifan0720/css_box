// A FIT-CONTENT BOX ROUND A PARAGRAPH ANSWERS THE WALK TO ITS LAST LINE AS
// THE PARAGRAPH DOES. An inline-block stands on its last line box (CSS 2.1
// 10.8.1), which css_box's `LastBaseline` finds by a walk into the box:
// laid out, `lastBaselineOf`; dry, `dryLastBaselineOf` (`dry.dart`), which
// `ShrinkWidth` answers with its child's at the width it settles on
// (`shrink.dart`, `dryLastBaseline`, `_inner`). A paragraph -- bare, in a
// padding, in a `LineBox` that sets its lines, under a frame -- breaks its
// lines at that width as it does at the room the box is offered, since a
// fit-content width (css-sizing-3 5.1) of a paragraph is the width it comes
// to by itself; so the walk finds the same last line, and the lowerer
// writes the box as the paragraph. A Japanese news site's header links: inline-blocks
// of a fit-content label, a border and padding on its left, on a line of
// larger text (`fixtures/inline-block-shrink-last-line`).
//
// This pins the two spellings to the same boxes -- the label, the line it
// stands on and what follows, laid out and dry, and the line's least and
// greatest widths -- for labels of one line and of several, at several
// widths, in a column and in a grid's `auto` column that reads the line's
// least width and stands its items on their baselines.
// NEGATIVE: round a column that stretches its words, the fit-content box is
// as wide as the words and the column alone as wide as the line.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:css_box/css_box.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// A label's words under the forced strut the lowerer sets them in: 11px
/// Inter on 13px lines.
Text _words(String text) => Text(
  text,
  key: const ValueKey('words'),
  style: const TextStyle(
    fontFamily: 'Fx',
    fontSize: 11,
    height: 13 / 11,
    leadingDistribution: TextLeadingDistribution.even,
  ),
  strutStyle: const StrutStyle(
    fontFamily: 'Fx',
    fontSize: 11,
    height: 13 / 11,
    leading: 0,
    leadingDistribution: TextLeadingDistribution.even,
    forceStrutHeight: true,
  ),
);

/// The three shapes the lowerer writes a label in: the words, the words in
/// their padding and line box, and that under a left border.
final Map<String, Widget Function(Text)> _labels = {
  'words': (words) => words,
  'padded line': (words) => Padding(
    padding: const EdgeInsets.only(left: 14),
    child: LineBox(lineHeight: 13, ascent: 10, child: words),
  ),
  'framed line': (words) => DecoratedBox(
    decoration: const BoxDecoration(
      border: Border(left: BorderSide(color: Color(0xFF111111))),
    ),
    child: Padding(
      padding: const EdgeInsets.only(left: 14),
      child: LineBox(lineHeight: 13, ascent: 10, child: words),
    ),
  ),
};

Widget _line(Widget label) => Text.rich(
  TextSpan(
    children: [
      const TextSpan(text: 'News '),
      WidgetSpan(
        child: KeyedSubtree(
          key: const ValueKey('box'),
          child: LastBaseline(child: label),
        ),
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
      ),
      // A mark standing its bottom on the line's baseline, which the label
      // stands its last line on.
      const WidgetSpan(
        child: SizedBox(key: ValueKey('mark'), width: 2, height: 2),
        alignment: PlaceholderAlignment.aboveBaseline,
        baseline: TextBaseline.alphabetic,
      ),
      const TextSpan(text: ' today'),
    ],
  ),
  key: const ValueKey('para'),
  style: const TextStyle(
    fontFamily: 'Fx',
    fontSize: 18,
    height: 28 / 18,
    leadingDistribution: TextLeadingDistribution.even,
  ),
);

Widget _page(Widget label, double width, {required bool grid}) {
  final column = Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _line(label),
      const SizedBox(key: ValueKey('after'), height: 5),
    ],
  );
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: width,
        child: grid
            ? Tracks(
                key: const ValueKey('grid'),
                columns: const [TrackSize.auto, TrackSize.flex(1)],
                spacing: 16,
                align: CellAlign.baseline,
                children: [
                  column,
                  const Text('other', key: ValueKey('other'), style: TextStyle(fontSize: 24)),
                ],
              )
            : column,
      ),
    ),
  );
}

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

/// How far apart the label in a `ShrinkWidth` and without puts anything.
Future<double> _apart(WidgetTester t, Widget Function(bool shrink) label, double width, {required bool grid}) async {
  final got = <bool, List<double>>{};
  for (final shrink in [true, false]) {
    await t.pumpWidget(_page(label(shrink), width, grid: grid));
    final para = t.renderObject<RenderBox>(find.byKey(const ValueKey('para')));
    final room = BoxConstraints(maxWidth: para.size.width);
    final rects = [
      for (final k in const ['box', 'words', 'mark', 'after', 'para']) t.getRect(find.byKey(ValueKey(k))),
      if (grid) t.getRect(find.byKey(const ValueKey('other'))),
    ];
    got[shrink] = [
      for (final r in rects) ...[r.left, r.top, r.right, r.bottom],
      _asked(() => para.getDistanceToBaseline(TextBaseline.alphabetic)) ?? -1,
      _asked(() => para.getDryLayout(room).height),
      _asked(() => para.getDryBaseline(room, TextBaseline.alphabetic)) ?? -1,
      _asked(() => para.getMinIntrinsicWidth(double.infinity)),
      _asked(() => para.getMaxIntrinsicWidth(double.infinity)),
      _asked(() => para.getMaxIntrinsicHeight(room.maxWidth)),
    ];
  }
  var worst = 0.0;
  for (var i = 0; i < got[true]!.length; i++) {
    worst = math.max(worst, (got[true]![i] - got[false]![i]).abs());
  }
  return worst;
}

const _texts = ['Help desk', 'Customer support centre and help', 'Subscriptions'];
const _widths = [60.0, 110.0, 200.0, 420.0];

void main() {
  setUpAll(() async {
    final bytes = Uint8List.fromList(File('test/fonts/Inter.ttf').readAsBytesSync());
    await (FontLoader('Fx')..addFont(Future.value(ByteData.view(bytes.buffer)))).load();
  });

  for (final MapEntry(key: name, value: shape) in _labels.entries) {
    for (final grid in [false, true]) {
      testWidgets('a fit-content $name stands where the $name does${grid ? ' in a grid' : ''}', (t) async {
        for (final text in _texts) {
          for (final width in _widths) {
            Widget label(bool shrink) {
              final inner = shape(_words(text));
              return shrink ? ShrinkWidth(child: inner) : inner;
            }

            expect(await _apart(t, label, width, grid: grid), lessThan(1e-6), reason: '$text at $width');
          }
        }
      });
    }
  }

  testWidgets('a label held narrower than its words stands on its last line either way', (t) async {
    for (final shape in _labels.values) {
      for (final width in _widths) {
        Widget label(bool shrink) {
          final inner = shape(_words('Customer support centre'));
          return ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 60),
            child: shrink ? ShrinkWidth(child: inner) : inner,
          );
        }

        expect(await _apart(t, label, width, grid: true), lessThan(1e-6), reason: '$width');
      }
    }
  });

  testWidgets('NEGATIVE: round a column that stretches its words the box is not the column', (t) async {
    Widget label(bool shrink) {
      final inner = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [_words('Help desk')]);
      return shrink ? ShrinkWidth(child: inner) : inner;
    }

    expect(await _apart(t, label, 420, grid: false), greaterThan(50));
  });
}
