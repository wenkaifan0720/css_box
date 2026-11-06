// A ROW THAT IS A SHARE OF NOTHING, `0fr`, IS NOTHING TALL ROUND ITEMS THAT
// CLIP. A flexible track is the larger of its base size and its factor
// times the size of an `fr` (css-grid-1 11.7) -- nothing at a factor of 0,
// whatever the grid's height -- and its base size is its items' least
// (`<flex>` alone is `minmax(auto, <flex>)`, 7.2.4; 11.5): nothing for an
// item that clips, a scroll container, whose automatic minimum is nothing
// (6.6). A banking site's pricing questions are `grid-template-rows: 0fr` round an
// answer of `overflow: hidden` that opens to `1fr`. The lowerer
// (`lossy_grid.dart`, `_gridAtL`) writes such a row as a row of a length of
// 0: a `SizedBox` of no height, its item stretched into it and its content
// hung out of it and clipped. This pins the two spellings to the same boxes
// down a stretched column, under a question, held to a height, beside a
// second column and measured, at two widths -- and to the same answers to
// its least and most heights at three widths and to its most width, where
// the row of 0fr answers nothing as the `SizedBox` of no height does
// (`fixtures/grid-row-zero-share`).
// NEGATIVE: an item that does not clip (its least height is its content's),
// one with a margin down, and one that stands at the top of the row (its
// own height, which hangs out of the row) are not nothing tall; the least
// width of an item that clips is none, where the `ClipRect` answers with its
// content's. The lowerer keeps css_box's grid for them. (In a row of content
// it answers its heights as the `ClipRect` does.)
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

ValueKey<String> _k(String name) => ValueKey(name);

const _keys = ['grid', 'clip', 'answer', 'question', 'side', 'after'];

/// The answer as the lowering writes an `overflow: hidden` block: its
/// content laid out at its own height and clipped to the box.
Widget _answer(String key) => ClipRect(
  key: _k('clip$key'),
  child: OverflowBox(
    minHeight: 0,
    maxHeight: double.infinity,
    fit: OverflowBoxFit.deferToChild,
    alignment: Alignment.topLeft,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Text('Our business checking and savings accounts are free for everyone.', key: _k('answer$key')),
      ],
    ),
  ),
);

TrackCell _cell(String key, {bool clips = true, EdgeInsets margin = EdgeInsets.zero, CellAlign? align}) =>
    TrackCell(clips: clips, margin: margin, align: align, child: _answer(key));

Widget _page(double width, Widget grid, {bool loose = false}) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: loose ? CrossAxisAlignment.start : CrossAxisAlignment.stretch,
        children: [
          grid,
          SizedBox(key: _k('after'), height: 20),
        ],
      ),
    ),
  ),
);

Future<Map<String, Rect>> _rects(WidgetTester t, Widget w) async {
  await t.pumpWidget(w);
  return {
    for (final k in _keys)
      for (final e
          in find
              .byWidgetPredicate((x) => x.key is ValueKey<String> && (x.key! as ValueKey<String>).value.startsWith(k))
              .evaluate())
        (e.widget.key! as ValueKey<String>).value: t.getRect(find.byKey(e.widget.key!)),
  };
}

/// The answers of the box keyed `grid` to its least and most heights at
/// three widths, and to its most width.
Future<List<double>> _answers(WidgetTester t, Widget w) async {
  await t.pumpWidget(w);
  final box = t.renderObject<RenderBox>(find.byKey(_k('grid')));
  return [
    box.getMaxIntrinsicWidth(double.infinity),
    for (final width in const [600.0, 240.0, 80.0]) ...[
      box.getMinIntrinsicHeight(width),
      box.getMaxIntrinsicHeight(width),
    ],
  ];
}

/// Each case: the css_box grid and the stock spelling the lowerer writes.
final _cases = <String, (Widget Function(), Widget Function())>{
  'one row': (
    () => Tracks(key: _k('grid'), rows: const [TrackSize.flex(0)], children: [_cell('')]),
    () => SizedBox(key: _k('grid'), height: 0, child: _answer('')),
  ),
  'under a question': (
    () => Tracks(
      key: _k('grid'),
      rows: const [TrackSize.auto, TrackSize.flex(0)],
      runSpacing: 6,
      children: [
        Text('What does it cost?', key: _k('question')),
        _cell(''),
      ],
    ),
    () => Column(
      key: _k('grid'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 6,
      children: [
        Text('What does it cost?', key: _k('question')),
        SizedBox(height: 0, child: _answer('')),
      ],
    ),
  ),
  'held to a height': (
    () => SizedBox(
      height: 90,
      child: Tracks(key: _k('grid'), rows: const [TrackSize.flex(0)], children: [_cell('')]),
    ),
    () => SizedBox(
      height: 90,
      child: Column(
        key: _k('grid'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [SizedBox(height: 0, child: _answer(''))],
      ),
    ),
  ),
  'beside a second column': (
    () => Tracks(
      key: _k('grid'),
      columns: const [TrackSize.flex(1), TrackSize.flex(1)],
      rows: const [TrackSize.auto, TrackSize.flex(0)],
      spacing: 10,
      children: [
        Text('What does it cost?', key: _k('question')),
        SizedBox(key: _k('side'), height: 40),
        _cell('1'),
        _cell('2'),
      ],
    ),
    () => Column(
      key: _k('grid'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 10,
            children: [
              Expanded(child: Text('What does it cost?', key: _k('question'))),
              Expanded(child: SizedBox(key: _k('side'), height: 40)),
            ],
          ),
        ),
        SizedBox(
          height: 0,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 10,
            children: [
              Expanded(child: _answer('1')),
              Expanded(child: _answer('2')),
            ],
          ),
        ),
      ],
    ),
  ),
};

void main() {
  for (final width in const [600.0, 240.0]) {
    for (final MapEntry(key: name, value: (grid, stock)) in _cases.entries) {
      testWidgets('a row of 0fr round items that clip is nothing tall: $name, $width wide', (t) async {
        final css = await _rects(t, _page(width, grid()));
        final out = await _rects(t, _page(width, stock()));
        expect(out, css);
        // The answer is laid out whole, hung out of a box of no height.
        expect(css['clip${name == 'beside a second column' ? '1' : ''}']!.height, 0);
        expect(css['answer${name == 'beside a second column' ? '1' : ''}']!.height, greaterThan(0));
      });
    }
    // Offered no width the grid is as wide as its content: the lowerer
    // measures it with an `IntrinsicWidth`.
    testWidgets('a row of 0fr measured: $width wide', (t) async {
      final css = await _rects(
        t,
        _page(width, Tracks(key: _k('grid'), rows: const [TrackSize.flex(0)], children: [_cell('')]), loose: true),
      );
      final out = await _rects(
        t,
        _page(
          width,
          IntrinsicWidth(
            key: _k('grid'),
            child: SizedBox(height: 0, child: _answer('')),
          ),
          loose: true,
        ),
      );
      expect(out, css);
    });
  }

  // Asked its heights and its most width, as a grid round it asks it.
  for (final name in const ['one row', 'under a question']) {
    testWidgets('a row of 0fr round items that clip answers its heights and its most width as written: $name', (
      t,
    ) async {
      final (grid, stock) = _cases[name]!;
      final css = await _answers(t, _page(600, grid()));
      final out = await _answers(t, _page(600, stock()));
      expect(out, css);
      // The row of 0fr alone is nothing tall to every question.
      if (name == 'one row') expect(css.skip(1), everyElement(0));
    });
  }

  testWidgets('NEGATIVE: the least width of an item that clips is none, where the ClipRect answers its content\'s', (
    t,
  ) async {
    final (grid, stock) = _cases['one row']!;
    await t.pumpWidget(_page(600, grid()));
    final css = t.renderObject<RenderBox>(find.byKey(_k('grid'))).getMinIntrinsicWidth(double.infinity);
    await t.pumpWidget(_page(600, stock()));
    final out = t.renderObject<RenderBox>(find.byKey(_k('grid'))).getMinIntrinsicWidth(double.infinity);
    expect(css, 0);
    expect(out, greaterThan(0));
  });

  // In a row of content an item that clips answers its heights with its
  // content's, as the `ClipRect` does: css_box answers its least height
  // with its rows laid out.
  testWidgets('in a row of content an item that clips answers its heights as the ClipRect does', (t) async {
    final css = await _answers(
      t,
      _page(
        600,
        Tracks(
          key: _k('grid'),
          rows: const [TrackSize.auto, TrackSize.auto],
          runSpacing: 6,
          children: [
            Text('What does it cost?', key: _k('question')),
            _cell(''),
          ],
        ),
      ),
    );
    final out = await _answers(
      t,
      _page(
        600,
        Column(
          key: _k('grid'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 6,
          children: [
            Text('What does it cost?', key: _k('question')),
            _answer(''),
          ],
        ),
      ),
    );
    expect(out, css);
    expect(css[1], greaterThan(0));
  });

  for (final (name, cell) in [
    ('an item that does not clip', _cell('', clips: false)),
    ('an item with a margin down', _cell('', margin: const EdgeInsets.only(top: 8))),
    ('an item at the top of its row', _cell('', align: CellAlign.start)),
  ]) {
    testWidgets('NEGATIVE: $name is not nothing tall', (t) async {
      final css = await _rects(
        t,
        _page(600, Tracks(key: _k('grid'), rows: const [TrackSize.flex(0)], children: [cell])),
      );
      final out = await _rects(t, _page(600, SizedBox(key: _k('grid'), height: 0, child: _answer(''))));
      expect(out, isNot(css));
    });
  }
}
