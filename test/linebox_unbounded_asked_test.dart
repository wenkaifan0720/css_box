// A BOX THAT OFFERS NO BOUND ACROSS IS ASKED AT THE WIDTH IT HAS. An
// `OverflowBox` of no ceiling across lays its child out with no bound
// (`RenderConstrainedOverflowBox._getInnerConstraints`), and so does a
// `Spill` across (`spill.dart`, `_inner`) -- but both answer an intrinsic
// height with the child's at the width THEY are asked at (`RenderShiftedBox`,
// `RenderProxyBox`), and an `OverflowBox` that defers to its child answers
// a dry layout with the child's under the constraints IT is offered
// (`computeDryLayout`). A `LineBox` asked at a width under its widest word
// answers at that word (`linebox.dart`, `_width`, `_room`), a `Text` at the
// width: where an `IntrinsicHeight` or a dry layout reaches the box from
// above, the two pages differ wherever the box's own room is under the
// word, though the line is laid out with no bound at all. The lossy pass
// (`tidy.dart`, `_roomAtOnce`, `_leastRoom`) reads the room such a question
// is asked at -- the box's own -- and frees the line box only where that
// fits the word. A product site's agent log, `Thinking.` in a `Flexible` of no
// ceiling beside an icon in a row an `IntrinsicWidth` holds
// (`fixtures/linebox-unbounded-asked`). Each test
// lays the line box and the `Text` out side by side and compares the keyed
// rects, at several widths; NEGATIVE cases are the rooms under the word.
import 'package:flutter/rendering.dart' show OverflowBoxFit;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

// The test font draws every glyph 14px wide at 14px: `aaaaaaaa` is 112px.
const _style = TextStyle(fontSize: 14, height: 1.0);
const _words = 'aaaaaaaa bb cccc dd eeeeee';
const _para = ValueKey('para');
const _after = ValueKey('after');

Widget _page(Widget Function(Widget) box, {required double width, required bool line}) {
  final para = Text(_words, key: _para, style: _style);
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            box(line ? LineBox(child: para) : para),
            const SizedBox(key: _after, height: 10),
          ],
        ),
      ),
    ),
  );
}

/// Where the paragraph's lines stand -- its top left corner and the width
/// they are broken at -- and the box below it. A paragraph handed a tight
/// height is that tall whatever its lines (`RenderParagraph`), where the
/// line box lays it out at its own and is the height itself; the lines
/// are drawn the same from the top either way.
Future<List<Object>> _rects(WidgetTester t, Widget w) async {
  await t.pumpWidget(w);
  final para = t.getRect(find.byKey(_para));
  return [para.topLeft, para.width, t.getRect(find.byKey(_after))];
}

Future<bool> _same(WidgetTester t, Widget Function(Widget) box, double width) async {
  final css = await _rects(t, _page(box, width: width, line: true));
  final stock = await _rects(t, _page(box, width: width, line: false));
  return [for (var i = 0; i < css.length; i++) css[i] == stock[i]].every((v) => v);
}

Widget _unbounded(Widget c) =>
    OverflowBox(maxWidth: double.infinity, fit: OverflowBoxFit.deferToChild, alignment: Alignment.topLeft, child: c);

void main() {
  testWidgets('asked its height, an OverflowBox asks at its own width', (t) async {
    Widget asked(Widget c) => IntrinsicHeight(child: _unbounded(c));
    // A price-table site's spelling of `min-width: max-content` past a tight
    // width: the same box round an `IntrinsicWidth`, which asks its child's
    // height at the width it is asked at too.
    Widget past(Widget c) => IntrinsicHeight(child: _unbounded(IntrinsicWidth(child: c)));
    // ... in a row the `IntrinsicHeight` stretches.
    Widget row(Widget c) => IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [Expanded(child: _unbounded(c))],
      ),
    );
    for (final box in [asked, past, row]) {
      // NEGATIVE: the box's room under the widest word.
      expect(await _same(t, box, 50), isFalse);
      // The room at the word or wider.
      for (final w in const [112.0, 200.0, 420.0]) {
        expect(await _same(t, box, w), isTrue, reason: '$w');
      }
    }
  });

  testWidgets('asked its height, a Spill across asks at its own width', (t) async {
    Widget asked(Widget c) => IntrinsicHeight(
      child: Spill(axis: Axis.horizontal, child: c),
    );
    expect(await _same(t, asked, 50), isFalse);
    for (final w in const [112.0, 200.0, 420.0]) {
      expect(await _same(t, asked, w), isTrue, reason: '$w');
    }
  });

  testWidgets('asked a dry layout, an OverflowBox that defers to its child asks at its own width', (t) async {
    // A wrap answers its intrinsic height with a dry layout of its
    // children (`RenderWrap.computeMaxIntrinsicHeight`).
    Widget dry(Widget c) => IntrinsicHeight(child: Wrap(children: [_unbounded(c)]));
    expect(await _same(t, dry, 50), isFalse);
    for (final w in const [112.0, 200.0, 420.0]) {
      expect(await _same(t, dry, w), isTrue, reason: '$w');
    }
  });

  testWidgets('asked nothing, it lays the line out with no bound at all', (t) async {
    for (final w in const [50.0, 200.0]) {
      expect(await _same(t, _unbounded, w), isTrue, reason: '$w');
      expect(
        await _same(t, (c) => Spill(axis: Axis.horizontal, child: c), w),
        isTrue,
        reason: '$w',
      );
    }
  });
}
