// A LINE IN A ROOM AS WIDE AS ITS CONTENT PASSES IT BY THE SHARES ITS ITEMS
// TAKE OF IT. An inline-level flex container of no width of its own is as
// wide as its content with every percentage of it at nothing, and the
// percentages then resolve against that width (css-sizing-3 5.2.1; CSS 2.1
// 8.4; `Inset.fits`): an item padded by a tenth of the line on each side
// is a fifth of the line wider than the line counted it, and nothing on a
// line of items that cannot shrink gives that back (css-flexbox-1 4.5,
// 9.7). Chrome: an `inline-flex` round `e` at `padding: 0 10%` and `f` is
// 15.25 wide and `f` hangs 3.05 out of its end
// (`fixtures/flex-item-pct-padding` b13). css_box's line lets the items
// hang; a `Row` held to the room puts them in the same places and paints
// its band over the end. The lowerer
// writes the row hung from its start:
//   Inset(room: true, fits: true, child: IntrinsicHeight(
//       child: OverflowBox(fit: OverflowBoxFit.deferToChild, minWidth: 0,
//           maxWidth: double.infinity, alignment: Alignment.centerLeft,
//           child: Row(mainAxisSize: MainAxisSize.min, ...))))
// and the lossy pass (`lossy_flex.dart`, the line the main pass leaves for
// its baseline) the same with the `IntrinsicHeight` inside the box
// -- `deferToChild`, so that the room measures the row's own width with
// the shares at nothing, and is that wide when they are taken. This pins it
// to css_box's line for shares on either side and both, and words of
// several widths.
// NEGATIVE: the row unhung reports what passes its end; an item of words
// that may wrap is shrunk by the line to give the share back, where a row
// that flexes nothing does not (so the lowerer hangs only such a row); in
// a container of a width of its own the line fits, and the hang changes
// nothing.
import 'package:css_box/css_box.dart';
import 'package:flutter/rendering.dart' show OverflowBoxFit;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// The test font draws every glyph 14px wide; a line is 18 tall.
const _style = TextStyle(fontSize: 14, height: 18 / 14);
const _keys = [ValueKey('room'), ValueKey('a'), ValueKey('b')];

Widget _page(Widget w) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(alignment: Alignment.topLeft, child: w),
);

Widget _a(String words, EdgeInsets share) => ColoredBox(
  key: const ValueKey('a'),
  color: const Color(0xFF00F5D4),
  child: Inset(
    insets: EdgeInsets.zero,
    shares: share,
    ofRoom: true,
    child: LineBox(child: Text(words, style: _style)),
  ),
);
Widget _b(String words) => ColoredBox(
  key: const ValueKey('b'),
  color: const Color(0xFFFF9F1C),
  child: LineBox(child: Text(words, style: _style)),
);

// The container: as wide as its content (`fits`), or 120 of its own.
Widget _room(Widget line, {bool fits = true}) => ColoredBox(
  key: const ValueKey('room'),
  color: const Color(0xFF9B5DE5),
  child: fits
      ? Inset(insets: EdgeInsets.zero, room: true, fits: true, child: line)
      : SizedBox(
          width: 120,
          child: Inset(insets: EdgeInsets.zero, room: true, child: line),
        ),
);

Widget _line(String a, String b, EdgeInsets share) => FlexLine(
  children: [
    FlexCell(frame: EdgeInsets.zero, frameFraction: share, child: _a(a, share)),
    FlexCell(child: _b(b)),
  ],
);

// The main pass measures the row's depth round the box it hangs in; the
// lossy pass, which hangs the line the main pass left for its baseline,
// measures it inside, with the slot's floor kept
// (`OverflowBox(maxWidth: double.infinity, fit: OverflowBoxFit.deferToChild,
// alignment: AlignmentDirectional.centerStart, child: IntrinsicHeight(...))`).
Widget _row(String a, String b, EdgeInsets share, {bool hung = true, bool lossy = false}) {
  final row = Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [_a(a, share), _b(b)],
  );
  if (!hung) return IntrinsicHeight(child: row);
  if (lossy) {
    return OverflowBox(
      maxWidth: double.infinity,
      fit: OverflowBoxFit.deferToChild,
      alignment: AlignmentDirectional.centerStart,
      child: IntrinsicHeight(child: row),
    );
  }
  return IntrinsicHeight(
    child: OverflowBox(
      fit: OverflowBoxFit.deferToChild,
      minWidth: 0,
      maxWidth: double.infinity,
      alignment: Alignment.centerLeft,
      child: row,
    ),
  );
}

Future<Map<Key, Rect>> _rects(WidgetTester t, Widget w) async {
  await t.pumpWidget(_page(w));
  return {for (final k in _keys) k: t.getRect(find.byKey(k))};
}

void main() {
  const shares = [EdgeInsets.symmetric(horizontal: 0.1), EdgeInsets.only(left: 0.06), EdgeInsets.only(right: 0.25)];
  for (final share in shares) {
    for (final (a, b) in const [('e', 'f'), ('copper', 'stint'), ('quartz', 'tern')]) {
      testWidgets('a row in a room as wide as its content, "$a" framed by $share, hung, stands where the line does', (
        t,
      ) async {
        final line = await _rects(t, _room(_line(a, b, share)));
        final hung = await _rects(t, _room(_row(a, b, share)));
        final lossy = await _rects(t, _room(_row(a, b, share, lossy: true)));
        expect(t.takeException(), isNull);
        expect(hung, line);
        expect(lossy, line);
        // The room is the words' width; the items pass it by the share.
        final words = (a.length + b.length) * 14.0;
        expect(hung[const ValueKey('room')]!.width, words);
        expect(hung[const ValueKey('b')]!.right, closeTo(words * (1 + share.horizontal), 1e-9));
      });
    }
  }

  testWidgets('NEGATIVE: the row unhung reports what passes its end', (t) async {
    await t.pumpWidget(_page(_room(_row('e', 'f', shares.first, hung: false))));
    expect(t.takeException(), isA<FlutterError>());
  });

  testWidgets(
    'NEGATIVE: an item of words that may wrap gives the share back, which a row that flexes nothing does not',
    (t) async {
      // The line shrinks the item down to its longest word (9.7) and the
      // words wrap; the lowerer hangs only a line that flexes nothing.
      final line = await _rects(t, _room(_line('quartz dunlin', 'tern', shares.first)));
      final hung = await _rects(t, _room(_row('quartz dunlin', 'tern', shares.first)));
      expect(line[const ValueKey('b')]!.right, closeTo(line[const ValueKey('room')]!.right, 1e-6));
      expect(hung[const ValueKey('b')]!.right, greaterThan(hung[const ValueKey('room')]!.right));
    },
  );

  testWidgets('NEGATIVE: in a container of a width of its own the line fits, hung or not', (t) async {
    final line = await _rects(t, _room(_line('e', 'f', shares.first), fits: false));
    final plain = await _rects(t, _room(_row('e', 'f', shares.first, hung: false), fits: false));
    final hung = await _rects(t, _room(_row('e', 'f', shares.first), fits: false));
    expect(t.takeException(), isNull);
    expect(plain, line);
    expect(hung, line);
  });
}
