// A CAP OF A LENGTH, ASKED A HEIGHT, IS ASKED IT AT THE CAPPED WIDTH (CSS
// 2.1 10.4, css-sizing-3 5.2): `max-width` clamps the width the box is laid
// out at, and its content -- a ratio's height, lines of words -- is as tall
// as it is at that width. A product site's hero, a `max-width: 1114px` 16:9 video
// in a 1376 track measured by an `IntrinsicHeight`, answered 774 where it is
// 626.6; a music store's results, an auto-fill grid under `max-width: 1656px`,
// counted five columns for four. A `ConstrainedBox` asks its child's height
// at the width IT is asked (`RenderConstrainedBox.computeMaxIntrinsicHeight`),
// so the lowerer (`lossy.dart`, `_capAskedL`) writes css_box's
// `FractionalConstraints(maxFactor: 0, maxOffset: m)` inside it, which
// clamps the question's width as it clamps the layout's (`_inner`), and
// fixtures/cap-width-measured-height is the page.
//
// ONCE THE PAGE IS SETTLED that box is written as Flutter's own
// `ConstraintsTransformBox` (`tidy.dart`, `_capTransformed`), whose
// transform `(offered) => offered.hasBoundedWidth ? BoxConstraints(maxWidth: m)
// .enforce(offered) : offered` is `_inner` for every constraint: bounded, the cap made
// to obey what is offered -- the least width offered, the most no more than
// the cap and no less than that least, the height as it came -- and
// unbounded, what is offered. `RenderConstraintsTransformBox` asks its
// child's heights at the transform of `BoxConstraints(maxWidth: w)` --
// the capped `w`, and no width at no width, as `_inner` does --, its widths
// at the height as it came, lays its child out and measures it dry under
// the transform, is the constrained size of its child (the child is never
// wider nor narrower than what it is handed, so the alignment moves it by
// nothing), and answers a dry baseline as its child's plus the alignment's
// share of the difference: nothing at the top. This pins the two to the
// same boxes laid out, measured and asked every question at caps that bind,
// do not, and at no width.
//
// NEGATIVE: the transform without its bound -- `BoxConstraints(maxWidth: m)
// .enforce`, a tear-off -- asks a height at the cap where nothing offers a
// width, and an `IntrinsicHeight` laid out at no width stood the box a line
// taller than css_box's; centred, a child that cannot measure itself dry
// under css_box's guard (which answers it `Size.zero`) moves its baseline
// half the room down; and asked a dry baseline with no guard, the stock box
// lets a child that cannot answer one throw where css_box's guards it -- the
// lowerer writes it only where every dry baseline that reaches it comes
// through a css_box guard.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

const _box = ValueKey('box'),
    _cssBox = ValueKey('css box'),
    _content = ValueKey('content'),
    _beside = ValueKey('beside'),
    _after = ValueKey('after');
const _keys = [_box, _content, _beside, _after];

/// The transform the lowerer writes, and the one without its bound.
BoxConstraints Function(BoxConstraints) _cap(double m) =>
    (offered) => offered.hasBoundedWidth ? BoxConstraints(maxWidth: m).enforce(offered) : offered;

enum _Spelling { css, stock, unbounded, centred }

Widget _capped(_Spelling s, double m, Widget child, {Key key = _box}) => switch (s) {
  _Spelling.css => FractionalConstraints(key: key, maxFactor: 0, maxOffset: m, child: child),
  _Spelling.stock => ConstraintsTransformBox(
    key: key,
    alignment: Alignment.topLeft,
    constraintsTransform: _cap(m),
    child: child,
  ),
  _Spelling.unbounded => ConstraintsTransformBox(
    key: key,
    alignment: Alignment.topLeft,
    constraintsTransform: BoxConstraints(maxWidth: m).enforce,
    child: child,
  ),
  _Spelling.centred => ConstraintsTransformBox(key: key, constraintsTransform: _cap(m), child: child),
};

/// The pair the page writes: the stock cap, and the box that asks at it.
Widget _pair(_Spelling s, double m, Widget child) => ConstrainedBox(
  constraints: BoxConstraints(maxWidth: m),
  child: _capped(s, m, child),
);

const _video = SizedBox(
  width: double.infinity,
  child: AspectRatio(
    aspectRatio: 16 / 9,
    child: ColoredBox(key: _content, color: Color(0xFF99AABB)),
  ),
);
const _words = SizedBox(
  width: double.infinity,
  child: Text('a heading of some words that wraps at the cap', key: _content),
);

Widget _page(Widget w) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(alignment: Alignment.topLeft, child: w),
);

/// The product site's hero: the cap centred in the first of two items of a
/// stretched row an `IntrinsicHeight` measures, a block after it.
Widget _measured(_Spelling s, double width, double m, Widget content) => _page(
  SizedBox(
    width: width,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Align(alignment: Alignment.topCenter, heightFactor: 1, child: _pair(s, m, content)),
              ),
              const Expanded(
                child: ColoredBox(key: _beside, color: Color(0xFFBB99AA), child: SizedBox(height: 10)),
              ),
            ],
          ),
        ),
        const SizedBox(key: _after, height: 20),
      ],
    ),
  ),
);

/// The music store's results: the cap in a css_box grid's item, which the grid
/// measures for its row.
Widget _gridded(_Spelling s, double width, double m, Widget content) => _page(
  SizedBox(
    width: width,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Tracks(
          columns: const [TrackSize.flex(2), TrackSize.flex(1)],
          spacing: 16,
          children: [
            Align(alignment: Alignment.topCenter, heightFactor: 1, child: _pair(s, m, content)),
            const ColoredBox(key: _beside, color: Color(0xFFBB99AA), child: SizedBox(height: 10)),
          ],
        ),
        const SizedBox(key: _after, height: 20),
      ],
    ),
  ),
);

/// An `IntrinsicHeight` laid out at no width, which asks its child's
/// height at none: the cap then lays the words out at the cap.
Widget _unbounded(_Spelling s, double m) => _page(
  OverflowBox(
    maxWidth: double.infinity,
    alignment: Alignment.topLeft,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IntrinsicHeight(child: _pair(s, m, const Text('a heading of some words that wraps at the cap', key: _content))),
        const SizedBox(key: _after, width: 10, height: 20),
      ],
    ),
  ),
);

/// A view wide enough for the widest page: the test's own 800 x 600 would
/// hold a 2400 row to 800.
void _wide(WidgetTester t) {
  t.view.physicalSize = const Size(3200, 2400);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

Future<Map<Key, Rect>> _rects(WidgetTester t, Widget w) async {
  _wide(t);
  await t.pumpWidget(w);
  return {
    for (final k in _keys)
      if (find.byKey(k).evaluate().isNotEmpty) k: t.getRect(find.byKey(k)),
  };
}

/// A box with a baseline that cannot measure itself dry: asked its dry
/// layout under css_box's guard, it answers `Size.zero`.
class _BaselineOnly extends LeafRenderObjectWidget {
  const _BaselineOnly();
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderBaselineOnly();
}

class _RenderBaselineOnly extends RenderBox {
  @override
  double? computeDryBaseline(covariant BoxConstraints constraints, TextBaseline baseline) => 12;
  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) => 12;
  @override
  void performLayout() => size = constraints.constrain(const Size(50, 20));
}

/// A box with a baseline laid out and no answer for one dry: it does not
/// implement `computeDryBaseline`, so Flutter's own asserts when asked.
class _NoDryBaseline extends LeafRenderObjectWidget {
  const _NoDryBaseline();
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderNoDryBaseline();
}

class _RenderNoDryBaseline extends RenderBox {
  @override
  Size computeDryLayout(covariant BoxConstraints constraints) => constraints.constrain(const Size(50, 20));
  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) => 12;
  @override
  void performLayout() => size = constraints.constrain(const Size(50, 20));
}

/// [ask] of a render box under css_box's guard (`dry.dart`, `dryBaselineOf`:
/// `debugCheckingIntrinsics` while the question is out).
T _guarded<T>(T Function() ask) {
  final was = RenderObject.debugCheckingIntrinsics;
  RenderObject.debugCheckingIntrinsics = true;
  try {
    return ask();
  } finally {
    RenderObject.debugCheckingIntrinsics = was;
  }
}

void main() {
  const m = 1114.0;
  for (final width in const [600.0, 1376.0, 2400.0]) {
    for (final (name, content) in const [('a ratio', _video), ('words', _words)]) {
      testWidgets('measured by an IntrinsicHeight, $name under the cap, in $width', (t) async {
        final css = await _rects(t, _measured(_Spelling.css, width, m, content));
        final stock = await _rects(t, _measured(_Spelling.stock, width, m, content));
        expect(stock, css);
        // Past the cap the ratio is the cap's: 1114 x 626.6, and the block
        // after it under it.
        if (content == _video && width / 2 > m) {
          expect(css[_content]!.size, const Size(m, m * 9 / 16));
          expect(css[_after]!.top, m * 9 / 16);
        }
      });
      testWidgets('measured by a css_box grid, $name under the cap, in $width', (t) async {
        final css = await _rects(t, _gridded(_Spelling.css, width, m, content));
        final stock = await _rects(t, _gridded(_Spelling.stock, width, m, content));
        expect(stock, css);
      });
    }
  }

  testWidgets('measured at no width, the height is the uncapped one in both', (t) async {
    final css = await _rects(t, _unbounded(_Spelling.css, 200));
    final stock = await _rects(t, _unbounded(_Spelling.stock, 200));
    expect(stock, css);
  });

  testWidgets('NEGATIVE: the transform with no bound asks a height at the cap where nothing offers a width', (t) async {
    final css = await _rects(t, _unbounded(_Spelling.css, 200));
    final torn = await _rects(t, _unbounded(_Spelling.unbounded, 200));
    expect(torn[_box]!.height, greaterThan(css[_box]!.height));
    expect(torn[_after]!.top, greaterThan(css[_after]!.top));
  });

  // Every question, asked the two boxes alone, side by side in one tree:
  // what a parent may ask.
  testWidgets('every question a parent asks is answered the same', (t) async {
    _wide(t);
    for (final child in [_video, _words, const Text('one two three four five six seven', key: _content)]) {
      await t.pumpWidget(
        _page(
          SizedBox(
            width: 3000,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _capped(_Spelling.css, 300, child, key: _cssBox),
                _capped(_Spelling.stock, 300, child),
              ],
            ),
          ),
        ),
      );
      final css = t.renderObject<RenderBox>(find.byKey(_cssBox)), stock = t.renderObject<RenderBox>(find.byKey(_box));
      expect(stock.size, css.size);
      for (final w in const [0.0, 120.0, 300.0, 900.0, double.infinity]) {
        if (child != _video || w.isFinite) {
          expect(stock.getMinIntrinsicHeight(w), css.getMinIntrinsicHeight(w), reason: 'least height at $w');
          expect(stock.getMaxIntrinsicHeight(w), css.getMaxIntrinsicHeight(w), reason: 'most height at $w');
        }
      }
      for (final h in const [0.0, 50.0, double.infinity]) {
        expect(stock.getMinIntrinsicWidth(h), css.getMinIntrinsicWidth(h), reason: 'least width at $h');
        expect(stock.getMaxIntrinsicWidth(h), css.getMaxIntrinsicWidth(h), reason: 'most width at $h');
      }
      for (final c in const [
        BoxConstraints(maxWidth: 200),
        BoxConstraints(maxWidth: 2000),
        BoxConstraints(minWidth: 250, maxWidth: 2000, maxHeight: 400),
        BoxConstraints(minWidth: 500, maxWidth: 2000),
        BoxConstraints.tightFor(width: 800),
        BoxConstraints.tightFor(width: 800, height: 90),
        BoxConstraints(minHeight: 30, maxWidth: 260),
      ]) {
        expect(stock.getDryLayout(c), css.getDryLayout(c), reason: 'dry at $c');
        for (final b in TextBaseline.values) {
          expect(
            _guarded(() => stock.getDryBaseline(c, b)),
            _guarded(() => css.getDryBaseline(c, b)),
            reason: 'dry baseline at $c',
          );
        }
      }
    }
  });

  testWidgets('laid out at caps that bind and do not, tight and loose, the same boxes', (t) async {
    for (final c in const [
      BoxConstraints(maxWidth: 200),
      BoxConstraints(maxWidth: 2000),
      BoxConstraints(minWidth: 500, maxWidth: 2000),
      BoxConstraints.tightFor(width: 800, height: 90),
      BoxConstraints(minHeight: 30, maxWidth: 260),
    ]) {
      Future<Map<Key, Rect>> at(_Spelling s) =>
          _rects(t, _page(ConstrainedBox(constraints: c, child: _capped(s, 300, _words))));
      expect(await at(_Spelling.stock), await at(_Spelling.css), reason: '$c');
    }
  });

  testWidgets('NEGATIVE: centred, a child that cannot measure itself dry moves the baseline half the room down', (
    t,
  ) async {
    final boxes = <_Spelling, RenderBox>{};
    for (final s in [_Spelling.css, _Spelling.stock, _Spelling.centred]) {
      await t.pumpWidget(_page(_capped(s, 300, const _BaselineOnly())));
      boxes[s] = t.renderObject<RenderBox>(find.byKey(_box));
      const c = BoxConstraints.tightFor(width: 200, height: 100);
      final b = _guarded(() => boxes[s]!.getDryBaseline(c, TextBaseline.alphabetic));
      expect(b, s == _Spelling.centred ? 62 : 12, reason: '$s');
    }
  });

  // What cannot answer is a box with no `computeDryBaseline` at all. An
  // `Align` was one through Flutter 3.38 (`RenderPositionedBox`); from 3.41
  // it answers its child's, and a paragraph answers its own.
  testWidgets('NEGATIVE: asked a dry baseline with no guard, the stock box lets what cannot answer throw', (t) async {
    const c = BoxConstraints(maxWidth: 500);
    const child = _NoDryBaseline();
    await t.pumpWidget(_page(_capped(_Spelling.css, 300, child)));
    expect(t.renderObject<RenderBox>(find.byKey(_box)).getDryBaseline(c, TextBaseline.alphabetic), isNull);
    await t.pumpWidget(_page(_capped(_Spelling.stock, 300, child)));
    expect(
      () => t.renderObject<RenderBox>(find.byKey(_box)).getDryBaseline(c, TextBaseline.alphabetic),
      throwsA(isA<FlutterError>()),
    );
  });
}
