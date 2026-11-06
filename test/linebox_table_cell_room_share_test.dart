// A LINE THAT NEVER WRAPS ROUND AN ATOMIC INLINE ALONE, IN A CELL OF A
// TABLE LAID OUT AUTOMATICALLY, IS A ROW OF THE STRUT AND IT ON THEIR
// BASELINES -- WHETHER IT KEEPS ITS WORDS WHOLE OR NOT. A table laid out
// automatically gives every column at least the min-content of each cell
// in it (CSS 2.1 17.5.2.2, css-tables-3 3.9.3): css_box's `RenderTableBox`
// floors each column at its cells' least width and only ever adds to it,
// at any width it is offered, laid out or dry (`table.dart`, `_measure`,
// `_widths`, `_distribute`), and lays each cell out tight at its column.
// A line box round a paragraph that never wraps answers its least width
// with its line's (`linebox.dart`, `_floor`), and keeping its words whole
// floors the room it lays the paragraph out in -- and the width it counts
// a height at -- at that same width (`_room`, `_width`): in a cell no
// narrower than its content the floor is never under the room, and the
// line box hands its constraints on as one that keeps nothing whole does.
// That one is a row of the strut and the inline (`lossy.dart`,
// `_atomAloneL`; `linebox_atom_alone_measured_share_test` p3), where the
// inline's least width is its greatest (`_oneWideL`): the table asks
// every cell its least width, which the line box answers with its line's
// and the row with the inline's. A price-table site's price table: a coin's
// supply, a 140px column of `20.07M BTC` over a bar, let out of its width,
// and its price, alone on `nowrap` lines in cells of a table that shrinks
// to its content (fixtures/table-auto-cell-room p1, p2) -- and a box of
// a width round words, whose lines show the room the line lays it out
// in. This pins the two spellings to the same boxes -- every inline,
// every cell's words, the table and what is laid out after it, and what
// the table answers asked
// its widths, its heights, its dry layout and its baseline -- held to a
// width and let shrink, measured by an `IntrinsicHeight` and an
// `IntrinsicWidth`, at widths under the table's least to past its most,
// in css_box's table and in the stock `Table` of intrinsic columns the
// lossy pass may write for it (`RenderTable`, `_computeColumnWidths`: a
// column of `IntrinsicColumnWidth` is never shrunk under its cells' least).
// NEGATIVE: `table-layout: fixed`, whose columns read no cell's content
// and may be narrower than the line (n1); an inline of two words, whose
// least the row answers with the wider word (n2); a cap inside the cell,
// under which the line's room is the cap (n3); and css_box's walk for a
// table's last baseline, dry, which asks the last cell its dry layout at
// the TABLE's constraints, under its content where they are tight (n4).
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:css_box/css_box.dart';
import 'package:css_box/rendering.dart' show dryLastBaselineOf;
import 'package:flutter/rendering.dart';
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

/// The strut as the lowerer writes it round a line of widgets: at the size
/// whose even split is Blink's, a minimum (`forceStrutHeight: false`).
StrutStyle _strut(double size, double lh) {
  final up = _blinkUp(size, lh);
  final at = _up4((up - (lh - up)) / (_asc - _desc));
  return StrutStyle(
    fontFamily: 'Fx',
    fontSize: at,
    height: lh / at,
    leading: 0,
    leadingDistribution: TextLeadingDistribution.even,
  );
}

TextStyle _fx(double size, [double? lh]) => TextStyle(
  fontFamily: 'Fx',
  fontSize: size,
  height: lh == null ? null : lh / size,
  leadingDistribution: TextLeadingDistribution.even,
);

/// An inline for the cell at row [r], column [k], keyed by both.
typedef _Atom = Widget Function(int r, int k);

/// The supply: a 140px column of words over a bar, let out of its width
/// ([out]) as the price-table site's is, or not.
_Atom _supply({bool out = true}) => (r, k) {
  final box = Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        key: ValueKey('a$r$k'),
        width: 140,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          spacing: 4,
          children: [
            Text(r == 0 ? '20.07M BTC' : '120.68M ETH', textAlign: TextAlign.end, style: _fx(14, 21)),
            const SizedBox(
              height: 6,
              child: FractionallySizedBox(widthFactor: 0.9561, child: ColoredBox(color: Color(0xFFEFF2F5))),
            ),
          ],
        ),
      ),
    ],
  );
  if (!out) return box;
  return OverflowBox(
    minWidth: 0,
    maxWidth: double.infinity,
    fit: OverflowBoxFit.deferToChild,
    alignment: Alignment.topLeft,
    child: box,
  );
};

/// The price: one word in a box as wide as it, let out of its width.
_Atom _price() =>
    (r, k) => OverflowBox(
      minWidth: 0,
      maxWidth: double.infinity,
      fit: OverflowBoxFit.deferToChild,
      alignment: Alignment.topLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IntrinsicWidth(
            key: ValueKey('a$r$k'),
            child: Text(
              r == 0 ? r'$78,017.71' : r'$2,434.78',
              textAlign: TextAlign.end,
              softWrap: false,
              style: _fx(14, 21),
            ),
          ),
        ],
      ),
    );

/// A box of 140 round words, which wrap where it is squeezed: what the
/// room the line lays it out in shows.
_Atom _squeezed() =>
    (r, k) => SizedBox(
      key: ValueKey('a$r$k'),
      width: 140,
      child: Text(r == 0 ? '20.07M BTC' : '120.68M ETH', style: _fx(14, 21)),
    );

/// The line round [atom] as css_box lays it out ([told]), keeping its
/// words whole as the lowerer writes it, or as the stock pass writes it:
/// a row of the strut -- a box of the line's height standing on its
/// ascent -- and the inline, on their baselines, at the line's end where
/// the line is set there.
Widget _line(Widget atom, {required bool told, required bool end}) {
  if (!told) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: end ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        const SizedBox(
          width: 0,
          height: 22.5,
          child: Baseline(baseline: 16, baselineType: TextBaseline.alphabetic, child: Text('')),
        ),
        Flexible(child: atom),
      ],
    );
  }
  return LineBox(
    lineHeight: 22.5,
    ascent: 16,
    child: Text.rich(
      TextSpan(
        children: [
          const TextSpan(text: '​'),
          WidgetSpan(child: atom, alignment: PlaceholderAlignment.baseline, baseline: TextBaseline.alphabetic),
        ],
      ),
      textAlign: end ? TextAlign.end : TextAlign.left,
      softWrap: false,
      style: _fx(14),
      strutStyle: _strut(13, 22.5),
    ),
  );
}

/// What a cell holds round its content, as the lowerer writes it: a rule
/// under it, the cell's padding, the shift that moves it down its row
/// ([shift]: css_box's table only) and the box that lets it out of its
/// height.
Widget _cell(Widget content, {bool shift = true}) {
  final open = OverflowBox(
    minHeight: 0,
    maxHeight: double.infinity,
    fit: OverflowBoxFit.deferToChild,
    alignment: Alignment.topLeft,
    child: content,
  );
  return DecoratedBox(
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Color(0xFFEFF2F5))),
    ),
    child: Padding(
      padding: const EdgeInsets.only(left: 10, top: 4, right: 10, bottom: 5),
      child: shift ? TableShift(child: open) : open,
    ),
  );
}

/// A table's cells: a coin's name in words that wrap, then a line round
/// each of [atoms], two rows of them; [cap] puts a cap of that width round
/// each line.
List<Widget> _cells(List<_Atom> atoms, {required bool told, bool shift = true, double? cap}) => [
  for (var r = 0; r < 2; r++) ...[
    _cell(
      Text(r == 0 ? 'Bitcoin price today' : 'Ethereum price', key: ValueKey('w$r'), style: _fx(14, 22.5)),
      shift: shift,
    ),
    for (var k = 0; k < atoms.length; k++)
      _cell(
        cap == null
            ? _line(atoms[k](r, k), told: told, end: k > 0)
            : ConstrainedBox(
                constraints: BoxConstraints(maxWidth: cap),
                child: _line(atoms[k](r, k), told: told, end: k > 0),
              ),
        shift: shift,
      ),
  ],
];

/// css_box's table of [atoms], laid out automatically or [fixed] at [width].
Widget _tableBox(List<_Atom> atoms, {required bool told, bool fixed = false, double? width, double? cap}) {
  final cells = _cells(atoms, told: told, cap: cap);
  final columns = atoms.length + 1;
  return TableBox(
    key: const ValueKey('t'),
    fixed: fixed,
    width: width,
    children: [
      for (var i = 0; i < cells.length; i++)
        TableSlot(row: i ~/ columns, column: i % columns, align: TableAlign.middle, child: cells[i]),
    ],
  );
}

/// The stock `Table` of intrinsic columns of the same cells.
Widget _stockTable(List<_Atom> atoms, {required bool told}) {
  final cells = _cells(atoms, told: told, shift: false);
  final columns = atoms.length + 1;
  return Table(
    key: const ValueKey('t'),
    defaultColumnWidth: const IntrinsicColumnWidth(),
    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
    children: [for (var r = 0; r < 2; r++) TableRow(children: cells.sublist(r * columns, (r + 1) * columns))],
  );
}

/// The ways a table is placed: held to the width, let shrink to its
/// content in it, measured by an `IntrinsicHeight` beside a box, or by an
/// `IntrinsicWidth`.
enum _Place { held, shrunk, measured, fitted }

Widget _page(Widget table, double width, _Place place) {
  final Widget body = switch (place) {
    _Place.held => table,
    _Place.shrunk => Align(alignment: Alignment.topLeft, child: table),
    _Place.measured => IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: table),
          const SizedBox(key: ValueKey('side'), width: 10),
        ],
      ),
    ),
    _Place.fitted => Align(
      alignment: Alignment.topLeft,
      child: IntrinsicWidth(child: table),
    ),
  };
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            body,
            const SizedBox(key: ValueKey('after'), height: 5),
          ],
        ),
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

/// How far apart the two spellings of the lines put anything, laid out and
/// asked, and what is furthest apart. Where they are [same], neither may
/// overflow; a NEGATIVE's row may, which is the difference it shows.
Future<(double, String)> _apart(
  WidgetTester t,
  Widget Function(bool told) table,
  int atoms,
  double width,
  _Place place, {
  bool same = true,
}) async {
  final got = <bool, Map<String, double>>{};
  for (final told in [true, false]) {
    await t.pumpWidget(_page(table(told), width, place));
    final error = t.takeException();
    if (same) expect(error, isNull, reason: '$place at $width');
    final box = t.renderObject<RenderBox>(find.byKey(const ValueKey('t')));
    final keys = [
      't',
      'after',
      if (place == _Place.measured) 'side',
      for (var r = 0; r < 2; r++) ...['w$r', for (var k = 0; k < atoms; k++) 'a$r$k'],
    ];
    got[told] = {
      for (final k in keys) ...{
        '$k.left': t.getRect(find.byKey(ValueKey(k))).left,
        '$k.top': t.getRect(find.byKey(ValueKey(k))).top,
        '$k.right': t.getRect(find.byKey(ValueKey(k))).right,
        '$k.bottom': t.getRect(find.byKey(ValueKey(k))).bottom,
      },
      'baseline': _asked(() => box.getDistanceToBaseline(TextBaseline.alphabetic)) ?? -1,
      'min width': _asked(() => box.getMinIntrinsicWidth(double.infinity)),
      'max width': _asked(() => box.getMaxIntrinsicWidth(double.infinity)),
      for (final w in [40.0, width / 2, width, width * 2]) ...{
        'min height at $w': _asked(() => box.getMinIntrinsicHeight(w)),
        'max height at $w': _asked(() => box.getMaxIntrinsicHeight(w)),
        'dry width at $w': _asked(() => box.getDryLayout(BoxConstraints(maxWidth: w)).width),
        'dry height at $w': _asked(() => box.getDryLayout(BoxConstraints(maxWidth: w)).height),
        'tight dry height at $w': _asked(() => box.getDryLayout(BoxConstraints.tightFor(width: w)).height),
      },
    };
  }
  var worst = (0.0, '');
  for (final k in got[true]!.keys) {
    final d = (got[true]![k]! - got[false]![k]!).abs();
    if (d > worst.$1) worst = (d, '$k: ${got[true]![k]} told, ${got[false]![k]} stock');
  }
  return worst;
}

const _widths = [60.0, 200.0, 330.0, 480.0, 900.0];

Future<double> _worst(WidgetTester t, Widget Function(bool told) table, int atoms, {bool same = true}) async {
  var out = 0.0;
  for (final place in _Place.values) {
    for (final width in _widths) {
      out = math.max(out, (await _apart(t, table, atoms, width, place, same: same)).$1);
    }
  }
  return out;
}

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

  // p1: the supply let out of its width, and the price; p2: the supply
  // held to its width.
  final cases = <String, List<_Atom>>{
    'a column of words over a bar, let out of its width, and a price (p1)': [_supply(), _price()],
    'a column of words over a bar (p2)': [_supply(out: false)],
    'a box of a width round words that wrap where it is squeezed (p2)': [_squeezed()],
  };
  for (final MapEntry(key: name, value: atoms) in cases.entries) {
    testWidgets('in a cell of css_box\'s table laid out automatically, the row is the line box: $name', (t) async {
      for (final place in _Place.values) {
        for (final width in _widths) {
          final (d, at) = await _apart(t, (told) => _tableBox(atoms, told: told), atoms.length, width, place);
          expect(d, lessThan(1e-3), reason: '$name, $place at $width: $at');
        }
      }
    });
    testWidgets('in a cell of a stock Table of intrinsic columns, the row is the line box: $name', (t) async {
      for (final place in _Place.values) {
        for (final width in _widths) {
          final (d, at) = await _apart(t, (told) => _stockTable(atoms, told: told), atoms.length, width, place);
          expect(d, lessThan(1e-3), reason: '$name, $place at $width: $at');
        }
      }
    });
  }

  testWidgets(
    'NEGATIVE: a fixed table, an inline of two words, a cap in the cell: the line box keeps its own (n1, n2, n3)',
    (t) async {
      // n1: `table-layout: fixed` shares 240 over three columns, 80 each, and
      // the line box floors its 60 of room at the box's 140, where the row
      // squeezes the box into it and its words into lines.
      expect(
        await _worst(
          t,
          (told) => _tableBox([_squeezed(), _price()], told: told, fixed: true, width: 240),
          2,
          same: false,
        ),
        greaterThan(10),
      );
      // n2: a coin's name and symbol, two words on a line that never wraps:
      // the line box answers its least width with the line, the row with
      // the wider word, and the table takes that for the column's least.
      _Atom name() =>
          (r, k) => Text(
            r == 0 ? 'Bitcoin BTC' : 'Ethereum ETH',
            key: ValueKey('a$r$k'),
            softWrap: false,
            style: _fx(14, 21),
          );
      expect(await _worst(t, (told) => _tableBox([name()], told: told), 1, same: false), greaterThan(10));
      // n3: a cap of 60 round the line: the cell's least is the cap.
      expect(await _worst(t, (told) => _tableBox([_squeezed()], told: told, cap: 60), 1, same: false), greaterThan(10));
    },
  );

  testWidgets(
    'NEGATIVE: the walk for a table\'s last baseline, dry, asks its last cell at the table\'s constraints (n4)',
    (t) async {
      // One cell, so that the cell's dry size can be the table's, round a
      // box of 140 whose words wrap where it is squeezed: tight at a width
      // under the cell's least, the table comes to that width and its row's
      // height, which the line box's cell does too -- the walk steps into it
      // and finds the line's baseline -- and the row's, its box squeezed and
      // its words in two lines, does not: the walk stops at the table, which
      // answers none.
      final answers = <bool, double?>{};
      for (final told in [true, false]) {
        await t.pumpWidget(
          _page(
            TableBox(
              key: const ValueKey('t'),
              children: [
                TableSlot(
                  row: 0,
                  column: 0,
                  align: TableAlign.middle,
                  child: _cell(_line(_squeezed()(0, 0), told: told, end: true)),
                ),
              ],
            ),
            400,
            _Place.shrunk,
          ),
        );
        final box = t.renderObject<RenderBox>(find.byKey(const ValueKey('t')));
        answers[told] = _asked(
          () => dryLastBaselineOf(box, BoxConstraints.tightFor(width: 60), TextBaseline.alphabetic),
        );
      }
      expect(answers[true], isNotNull);
      expect(answers[false], isNull);
    },
  );
}
