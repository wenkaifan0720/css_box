// A LINE BOX IN ROOM NO WORD OVERFLOWS IS ITS PARAGRAPH. `LineBox` keeps a
// word wider than its line whole (`overflow-wrap: normal`, css-text-3 5.5)
// by laying its paragraph out at the paragraph's least width where its room
// is narrower (`linebox.dart`, `_room`); where the room is never narrower,
// the paragraph is laid out in the room it was handed, as a `Text` is. The
// lossy pass (`tidy.dart`, `_roomTo`, `_wordsFit`) takes the box out where
// it proves the room at least the widest word through the boxes above it;
// each test here pins one of those boxes: the line box and the `Text` the
// lowerer writes instead, laid out side by side under it, at several widths,
// with the keyed rects compared -- and NEGATIVE cases where the room is
// under a word, the box widens its paragraph, and the stock spelling is not
// the same page.
import 'package:flutter/rendering.dart' show OverflowBoxFit;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

// The test font draws every glyph 14px wide at 14px: `aaaaaaaa` is 112px.
const _style = TextStyle(fontSize: 14, height: 1.0);
const _para = ValueKey('para');
const _after = ValueKey('after');

/// [box] round a paragraph -- in a `LineBox` where [line] -- in a column of
/// [width], with a box under it that moves with the paragraph's height.
Widget _page(Widget Function(Widget) box, String text, {required double width, required bool line}) {
  final para = Text(text, key: _para, style: _style);
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

Future<Map<Key, Rect>> _rects(WidgetTester t, Widget w) async {
  await t.pumpWidget(w);
  return {
    for (final k in const [_para, _after]) k: t.getRect(find.byKey(k)),
  };
}

/// Whether [box] lays the paragraph [text] out the same with the line box
/// and without it, in a column [width] wide.
Future<bool> _same(WidgetTester t, Widget Function(Widget) box, String text, double width) async {
  final css = await _rects(t, _page(box, text, width: width, line: true));
  final stock = await _rects(t, _page(box, text, width: width, line: false));
  return css.keys.every((k) => css[k] == stock[k]);
}

// `aaaaaaaa` is the widest word: 112px.
const _words = 'aaaaaaaa bb cccc dd eeeeee';

void main() {
  testWidgets('a box that offers no bound across offers none whatever it is offered', (t) async {
    // An `OverflowBox` of no ceiling across in a column narrower than the
    // widest word -- and round an `IntrinsicWidth`, a price-table site's
    // `min-width: max-content` labels.
    Widget unbounded(Widget c) => OverflowBox(
      maxWidth: double.infinity,
      fit: OverflowBoxFit.deferToChild,
      alignment: Alignment.topLeft,
      child: c,
    );
    Widget past(Widget c) => unbounded(IntrinsicWidth(child: c));
    // ... and a child a row does not flex, in a row as long as it (a
    // longer one is a row that overflows).
    Widget rigid(Widget c) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [c]);
    for (final (box, widths) in [
      (unbounded, const [50.0, 200.0, 420.0]),
      (past, const [50.0, 200.0, 420.0]),
      (rigid, const [364.0, 420.0]),
    ]) {
      for (final w in widths) {
        expect(await _same(t, box, _words, w), isTrue, reason: '$w');
      }
    }
    // NEGATIVE: an `IntrinsicHeight` above asks the child its height at its
    // own width, under the widest word.
    expect(await _same(t, (c) => IntrinsicHeight(child: unbounded(c)), _words, 50), isFalse);
  });

  testWidgets('balanced and pretty lines hand the line box the room they are handed', (t) async {
    for (final box in <Widget Function(Widget)>[(c) => Pretty(child: c), (c) => Balance(child: c)]) {
      for (final w in const [112.0, 130.0, 200.0, 420.0]) {
        expect(await _same(t, box, _words, w), isTrue, reason: '$w');
      }
      // NEGATIVE: under the widest word the line box keeps it whole and the
      // `Text` breaks it.
      expect(await _same(t, box, _words, 70), isFalse);
    }
  });
}
