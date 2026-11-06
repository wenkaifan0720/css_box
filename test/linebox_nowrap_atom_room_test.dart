// AN ATOMIC INLINE ON A LINE THAT NEVER WRAPS IS SHRINK-TO-FIT AGAINST ITS
// BLOCK. An inline-block of `width: auto` is min(max(min-content,
// available), max-content), the available width its containing block's
// (CSS 2.1 10.3.9, 10.3.5): the line not wrapping does not widen it. One
// that wraps its own words again (`white-space: normal` on a `nowrap` line)
// is no wider than the block where its words are longer than that. A
// store's answer cards are `inline-grid` boxes on the `nowrap` line of a
// carousel slide; `LineBox` laid the line out at its whole length with each
// card at its greatest, and handed the card that: 1423 wide in a 330 slide,
// its answer on one line (`linebox.dart`, `_hungLength`). NEGATIVE: a card
// whose words are shorter than the block is its own length; a line whose
// words alone pass the block still hangs out of it at their whole length;
// an atom whose words never wrap either is its whole length.
import 'package:css_box/css_box.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// The test font draws every glyph 14px wide at 14px.
const _style = TextStyle(fontSize: 14, height: 1.0);

const _line = ValueKey('line');
const _atom = ValueKey('atom');

/// [before], then an inline box of [atom], on a line that never wraps.
Widget _para(Widget atom, {String before = ''}) => LineBox(
  key: _line,
  child: Text.rich(
    TextSpan(
      children: [
        TextSpan(text: before),
        WidgetSpan(alignment: PlaceholderAlignment.baseline, baseline: TextBaseline.alphabetic, child: atom),
      ],
    ),
    softWrap: false,
    style: _style,
  ),
);

/// An inline-block of `white-space: normal` holding [words].
Widget _block(String words) => LineBox(
  key: _atom,
  child: Text(words, style: _style),
);

/// [box] laid out in a block [width] wide.
Widget _page(Widget box, double width) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(width: width, child: box),
  ),
);

void main() {
  testWidgets('the atom is no wider than the block, its words wrapped in it', (t) async {
    // `aaaa bbbb cccc dddd` is 266 on one line, 56 at its longest word.
    await t.pumpWidget(_page(_para(_block('aaaa bbbb cccc dddd')), 140));
    expect(t.getRect(find.byKey(_atom)).width, lessThanOrEqualTo(140));
    // Two words a line: `aaaa bbbb` is 126, so four lines are two.
    expect(t.getRect(find.byKey(_atom)).height, 28);
    expect(t.getRect(find.byKey(_line)).width, 140);
  });

  testWidgets('NEGATIVE: an atom shorter than the block, words that pass it, and an atom that never wraps', (t) async {
    // Shorter than the block: its own length, one line.
    await t.pumpWidget(_page(_para(_block('aa bb')), 140));
    expect(t.getRect(find.byKey(_atom)).width, 70);
    expect(t.getRect(find.byKey(_atom)).height, 14);
    // Words before it that alone pass the block: the line hangs out at its
    // whole length, the atom handed that length as before.
    await t.pumpWidget(_page(_para(_block('aa bb'), before: 'xxxxxxxxxxxx'), 140));
    expect(t.getRect(find.byKey(_line)).width, 140);
    expect(
      t
          .renderObject<RenderParagraph>(find.descendant(of: find.byKey(_line), matching: find.byType(RichText)).first)
          .size
          .width,
      238,
    );
    // An atom whose words never wrap either is its whole length.
    await t.pumpWidget(
      _page(_para(const Text('aaaa bbbb cccc dddd', key: _atom, softWrap: false, style: _style)), 140),
    );
    expect(t.getRect(find.byKey(_atom)).width, 266);
  });
}
