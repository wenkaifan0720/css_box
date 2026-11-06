// TWO SHARES OR MORE ASKED ONLY THEIR MOST WIDTH ARE A ROW OF THEM. Under a
// max-content constraint an `fr` is the largest of each item's max-content
// past the gutters it covers over its factors, and of each share's base
// over its factor (css-grid-1 11.7.1), so the grid is the narrowest that
// gives every item its max-content in its area -- which is how a `Row` of
// `Expanded`s answers it (`RenderFlex._getIntrinsicSize`: the largest
// child's most per factor, times the factors), and a column of such rows
// answers with its widest. Asked its most height at a width, each lays its
// rows out at it. a docs site's card grid, `1fr 1fr 1fr` round a heading
// over links, and a docs site's footer, `repeat(5, minmax(0, 1fr))`, asked
// only their most widths and heights in a box of `width: max-content`,
// kept the grid (`lossy_grid.dart`; `fixtures/grid-shares-most-asked`).
//
// This pins the grid in an `IntrinsicWidth`, and in a shrink-to-fit box
// that asks its least width and never reads it, to the rows the lowerer
// writes for it, in rooms wider than its most (and narrower, where the
// shares have no floor), and the two answer the same most width and most
// heights. NEGATIVE: their least widths differ
// (the grid's is its columns' leasts side by side, the `Row`'s its widest
// item per factor times the factors); a share under one whole, or on a
// floor of a length, makes the grid's most another than the `Row`'s.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

const _keys = [ValueKey('grid'), ValueKey('a'), ValueKey('b'), ValueKey('c'), ValueKey('d'), ValueKey('e')];

/// [grid] in a room [width] wide, in an `IntrinsicWidth` -- or, [shrinks],
/// a shrink-to-fit box that asks its least width and never reads it.
Widget _page(double width, Widget grid, {bool shrinks = false}) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: width),
      child: shrinks ? ShrinkWidth(child: grid) : IntrinsicWidth(child: grid),
    ),
  ),
);

Future<Map<Key, Rect>> _rects(WidgetTester t, Widget w) async {
  await t.pumpWidget(w);
  return {
    for (final k in _keys)
      if (find.byKey(k).evaluate().isNotEmpty) k: t.getRect(find.byKey(k)),
  };
}

/// A box of a width and a height of its own, stretched across its area.
Widget _box(String key, double width, double height) => SizedBox(key: ValueKey(key), width: width, height: height);

// The cards: 80, 40 and a word, 42 wide at the test font's 14px.
List<Widget> _cards() => [_box('a', 80, 20), _box('b', 40, 30), const Text('CSS', key: ValueKey('c'))];

Widget _kept(List<TrackSize> columns, List<Widget> items, {double spacing = 16, double runSpacing = 0}) =>
    Tracks(key: const ValueKey('grid'), columns: columns, spacing: spacing, runSpacing: runSpacing, children: items);

Widget _row(List<Widget> kids, {double spacing = 16, Key? key}) => IntrinsicHeight(
  key: key,
  child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: spacing, children: kids),
);

/// [kept] and [written] lay out alike in rooms of [widths], and answer the
/// same most width, and the same most heights at it and narrower. A bare
/// `1fr` is floored at its items' least in a room under its most, which the
/// `Row` loses -- what the lowerer reads of words against the room
/// (`_wordsOverSharesL`), not this.
Future<void> _same(WidgetTester t, Widget kept, Widget written, {List<double> widths = const [1000, 300]}) async {
  for (final shrinks in const [false, true]) {
    for (final width in widths) {
      expect(
        await _rects(t, _page(width, written, shrinks: shrinks)),
        await _rects(t, _page(width, kept, shrinks: shrinks)),
        reason: '$width, shrinks: $shrinks',
      );
    }
  }
  await t.pumpWidget(_page(1000, kept));
  final k = t.renderObject<RenderBox>(find.byKey(const ValueKey('grid')));
  final most = k.getMaxIntrinsicWidth(double.infinity);
  final heights = [
    for (final w in [most, most / 2, 150.0]) k.getMaxIntrinsicHeight(w),
  ];
  await t.pumpWidget(_page(1000, written));
  final w = t.renderObject<RenderBox>(find.byKey(const ValueKey('grid')));
  expect(w.getMaxIntrinsicWidth(double.infinity), most);
  expect([
    for (final x in [most, most / 2, 150.0]) w.getMaxIntrinsicHeight(x),
  ], heights);
}

void main() {
  testWidgets('three shares are a row of them: each the widest item', (t) async {
    final kept = _kept(const [
      TrackSize.repeat(3, [TrackSize.flex(1)]),
    ], _cards());
    final written = _row([for (final x in _cards()) Expanded(child: x)], key: const ValueKey('grid'));
    await _same(t, kept, written);
    await t.pumpWidget(_page(1000, kept));
    expect(t.getRect(find.byKey(const ValueKey('grid'))).width, 3 * 80 + 2 * 16);
  });

  testWidgets('shares of no floor over two rows are a column of rows of them, the last row\'s holes spacers', (
    t,
  ) async {
    const columns = [
      TrackSize.repeat(5, [TrackSize.between(TrackSize.fixed(0), TrackSize.flex(1))]),
    ];
    List<Widget> items() => [
      ..._cards(),
      _box('d', 20, 10),
      _box('e', 110, 10),
      const SizedBox(width: 30),
      const SizedBox(width: 50),
    ];
    final kept = _kept(columns, items(), spacing: 48, runSpacing: 32);
    final x = items();
    final written = Column(
      key: const ValueKey('grid'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 32,
      children: [
        _row([for (final i in x.take(5)) Expanded(child: i)], spacing: 48),
        _row([
          Expanded(child: x[5]),
          Expanded(child: x[6]),
          const Spacer(),
          const Spacer(),
          const Spacer(),
        ], spacing: 48),
      ],
    );
    // No floor: in a room under its most too.
    await _same(t, kept, written, widths: const [1000, 400]);
  });

  testWidgets('shares of two factors are a row of them by factor', (t) async {
    final kept = _kept(
      const [TrackSize.flex(2), TrackSize.flex(1)],
      [_box('a', 80, 20), _box('b', 60, 30)],
      spacing: 10,
    );
    final written = _row(
      [Expanded(flex: 2, child: _box('a', 80, 20)), Expanded(child: _box('b', 60, 30))],
      spacing: 10,
      key: const ValueKey('grid'),
    );
    await _same(t, kept, written);
    await t.pumpWidget(_page(1000, kept));
    // 60 per factor, b's: 180 and the gutter.
    expect(t.getRect(find.byKey(const ValueKey('grid'))).width, 190);
  });

  testWidgets('NEGATIVE: the least widths differ', (t) async {
    await t.pumpWidget(
      _page(
        1000,
        _kept(const [
          TrackSize.repeat(3, [TrackSize.flex(1)]),
        ], _cards()),
      ),
    );
    final k = t.renderObject<RenderBox>(find.byKey(const ValueKey('grid')));
    expect(k.getMinIntrinsicWidth(double.infinity), 80 + 40 + 42 + 2 * 16);
    await t.pumpWidget(_page(1000, _row([for (final x in _cards()) Expanded(child: x)], key: const ValueKey('grid'))));
    final w = t.renderObject<RenderBox>(find.byKey(const ValueKey('grid')));
    expect(w.getMinIntrinsicWidth(double.infinity), 3 * 80 + 2 * 16);
  });

  for (final (name, columns) in const [
    ('a share under one whole', [TrackSize.flex(0.5), TrackSize.flex(0.5)]),
    (
      'a share on a floor of a length',
      [
        TrackSize.repeat(2, [TrackSize.between(TrackSize.fixed(120), TrackSize.flex(1))]),
      ],
    ),
  ]) {
    testWidgets('NEGATIVE: $name makes the grid\'s most another than the row\'s', (t) async {
      await t.pumpWidget(_page(1000, _kept(columns, [_box('a', 80, 20), _box('b', 40, 30)])));
      final k = t.getRect(find.byKey(const ValueKey('grid'))).width;
      await t.pumpWidget(
        _page(
          1000,
          _row([Expanded(child: _box('a', 80, 20)), Expanded(child: _box('b', 40, 30))], key: const ValueKey('grid')),
        ),
      );
      final w = t.getRect(find.byKey(const ValueKey('grid'))).width;
      expect(w, 2 * 80 + 16);
      expect(k, isNot(w));
    });
  }
}
