// A LINE BOX ASKED ITS LEAST WIDTH ANSWERS CSS'S, AND A `Text` SKIA'S. The
// min-content of a paragraph is its widest stretch no line breaks inside
// (css-sizing-3 5.1, css-text-3 5): CJK text breaks between two ideographs
// (UAX #14 LB31, css-text-3 5.1 under `word-break: normal`) and any text at
// a zero width space -- `<wbr>`, and what the lowerer writes for
// `word-break: break-all`. `LineBox` answers that (`linebox.dart`,
// `_floor`, `_ideographicBreak`); a `Text` answers Skia's, which breaks its
// lines there but measures a paragraph of one run -- one script, one face --
// with no space in it as one word: all katakana, all Han, the words either
// side of a zero width space. A second script or a space anywhere in it,
// and Skia answers the stretch too. Where nothing asks the box its least
// width the two are one page (`linebox_room_text_test.dart`); where a box
// above asks it -- a flex line flooring an item at its min-content
// (css-flexbox-1 4.5), a grid sizing an `auto` column by its items'
// (css-grid-1 11.5) -- the page the `Text` makes is another. A Japanese news site's
// menu labels in grid cells, a news site's headlines in the items of rows
// (`fixtures/linebox-least-cjk`). Each test lays the line box and the
// `Text` the lossy pass would write out side by side and compares the keyed
// rects; NEGATIVE cases are where the line states a floor of its own,
// where nothing asks the least width, and text of two runs.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

// The test font draws every glyph 14px wide at 14px.
const _style = TextStyle(fontSize: 14, height: 1.0);
// Five katakana: 70px whole, a character a stretch.
const _kana = 'プレゼント';
// Nine Han and a comma: 126px whole, `告，` the widest stretch (no line
// starts with a comma), 28.
const _han = '刊登廣告，關於我們';
// `Hamburger<wbr>fontsiv`: CSS breaks at the zero width space (126px
// `Hamburger`), Skia measures the 224px run as one word.
const _wbr = 'Hamburger​fontsiv';
const _latin = 'aaaa bbbb cc';
// Han and katakana, the Japanese news site's `紙面ビューアー`: two runs, 14 to both.
const _two = '紙面ビューアー';
// Katakana, a space, Han: 14 to both.
const _spaced = 'プレゼント 日';

const _para = ValueKey('para');
const _other = ValueKey('other');
const _after = ValueKey('after');

Widget _text(String s, bool line) {
  final t = Text(s, key: _para, style: _style);
  return line ? LineBox(child: t) : t;
}

Widget _page(Widget box, double width) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          box,
          const SizedBox(key: _after, height: 10),
        ],
      ),
    ),
  ),
);

/// A row css_box keeps: the paragraph's item beside a rigid 60px one.
Widget _row(String s, bool line, {double? min}) => FlexLine(
  children: [
    FlexCell(min: min, child: _text(s, line)),
    const FlexCell(shrink: 0, child: SizedBox(key: _other, width: 60, height: 10)),
  ],
);

/// A grid of an `auto` column beside a flexible one.
Widget _grid(String s, bool line) => Tracks(
  columns: const [TrackSize.auto, TrackSize.flex(1)],
  children: [
    _text(s, line),
    const SizedBox(key: _other, height: 10),
  ],
);

Future<Map<Key, Rect>> _rects(WidgetTester t, Widget w) async {
  await t.pumpWidget(w);
  return {
    for (final k in const [_para, _other, _after])
      if (find.byKey(k).evaluate().isNotEmpty) k: t.getRect(find.byKey(k)),
  };
}

Future<bool> _same(WidgetTester t, Widget Function(bool line) box, double width) async {
  final css = await _rects(t, _page(box(true), width));
  final stock = await _rects(t, _page(box(false), width));
  return css.length == stock.length && css.keys.every((k) => css[k] == stock[k]);
}

void main() {
  testWidgets('the two answers: the stretch, and the whole run', (t) async {
    for (final (s, line, text) in const [
      (_kana, 14.0, 70.0),
      (_han, 28.0, 126.0),
      (_wbr, 126.0, 224.0),
      (_latin, 56.0, 56.0),
      (_two, 14.0, 14.0),
      (_spaced, 14.0, 14.0),
    ]) {
      await t.pumpWidget(_page(_text(s, true), 300));
      expect(t.renderObject<RenderBox>(find.byType(LineBox)).getMinIntrinsicWidth(double.infinity), line, reason: s);
      expect(t.renderObject<RenderBox>(find.byKey(_para)).getMinIntrinsicWidth(double.infinity), text, reason: s);
    }
  });

  testWidgets('NEGATIVE: an item a row floors at its min-content', (t) async {
    // The item shrinks to what the 60 leaves round the line box, and stops
    // at Skia's whole run round the `Text`.
    expect(await _same(t, (l) => _row(_kana, l), 100), isFalse);
    expect(await _same(t, (l) => _row(_han, l), 150), isFalse);
    expect(await _same(t, (l) => _row(_wbr, l), 250), isFalse);
    // Room for both, the floor binds nowhere.
    for (final s in const [_kana, _han, _wbr]) {
      expect(await _same(t, (l) => _row(s, l), 400), isTrue, reason: s);
    }
    // Plain words: both answer the widest word.
    expect(await _same(t, (l) => _row(_latin, l), 100), isTrue);
  });

  testWidgets('an item that states its floor is never asked', (t) async {
    for (final (s, widths) in const [
      (_kana, [100.0, 150.0, 300.0]),
      (_han, [100.0, 150.0, 300.0]),
      (_wbr, [200.0, 250.0, 400.0]),
    ]) {
      for (final w in widths) {
        expect(await _same(t, (l) => _row(s, l, min: 0), w), isTrue, reason: '$s $w');
      }
    }
  });

  testWidgets('NEGATIVE: a grid sizes an auto column by its min-content', (t) async {
    expect(await _same(t, (l) => _grid(_kana, l), 50), isFalse);
    expect(await _same(t, (l) => _grid(_han, l), 100), isFalse);
    expect(await _same(t, (l) => _grid(_wbr, l), 200), isFalse);
    // Room for the whole run: the column is its max-content either way.
    for (final s in const [_kana, _han, _wbr]) {
      expect(await _same(t, (l) => _grid(s, l), 400), isTrue, reason: s);
    }
    expect(await _same(t, (l) => _grid(_latin, l), 100), isTrue);
  });

  testWidgets('of two runs, or spaced, Skia answers the stretch too', (t) async {
    for (final s in const [_two, _spaced]) {
      for (final w in const [80.0, 100.0, 150.0]) {
        expect(await _same(t, (l) => _row(s, l), w), isTrue, reason: '$s row $w');
      }
      for (final w in const [30.0, 50.0, 100.0]) {
        expect(await _same(t, (l) => _grid(s, l), w), isTrue, reason: '$s grid $w');
      }
    }
  });

  testWidgets('a column asks its children nothing', (t) async {
    for (final (s, widths) in const [
      (_kana, [20.0, 50.0, 300.0]),
      (_han, [30.0, 100.0, 300.0]),
      (_wbr, [130.0, 200.0, 400.0]),
    ]) {
      for (final w in widths) {
        expect(await _same(t, (l) => _text(s, l), w), isTrue, reason: '$s $w');
      }
    }
  });
}
