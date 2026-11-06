// A NEGATIVE MARGIN ON A BOX AT ITS STATIC POSITION MOVES ITS PIN. An
// absolutely positioned box whose top is `auto` stands where the flow would
// have put it (CSS 2.1 10.6.4), which css_box writes as a `SpotShift`
// pinned at 0 in a `Positioned`, moving its child to the mark the flow left
// (`spot.dart`). The shift lays its child out at the constraints the stack
// hands it, is its child's size, and stands the child at the mark's place
// in the stack -- read off the mark alone where it aligns nothing on that
// axis (`RenderSpotShift`, `performLayout`, `_spotAt`). So an `Inset` of a
// negative top round the box, which only moves it (`inset.dart`), is the
// pin moved up under the shift, and the lowerer
// writes it so. A docs site's
// menus, `position: absolute; margin-top: -1px` under their buttons with no
// `top` (`fixtures/abs-static-neg-margin`). This pins the two spellings to
// the same boxes -- the menu, its words, the button, the stack and what
// follows it, and the stack's baseline -- at widths the words wrap at: a
// negative top, a negative bottom beside it (which no pin reads), a menu
// pinned at both ends, a positive side padded inside, a shift across that
// moves nothing on the axis of the margin.
// NEGATIVE: a shift that aligns the box down stands it by its size, which
// the `Inset` reports less its sides; and one that ends the box across at
// the mark stands it by its width.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

const _keys = [ValueKey('stack'), ValueKey('button'), ValueKey('menu'), ValueKey('words'), ValueKey('after')];

/// a docs site's menu: a bordered list of words.
const Widget _menu = DecoratedBox(
  key: ValueKey('menu'),
  decoration: BoxDecoration(border: Border.fromBorderSide(BorderSide(color: Color(0xFF888888)))),
  child: Padding(
    padding: EdgeInsets.all(1),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [Text('Guides and references for the web', key: ValueKey('words'))],
    ),
  ),
);

/// A nav item [width] wide: its button, the mark the flow leaves under it,
/// and [menu] -- the positioned child -- over them; something after it.
Widget _page(double width, Widget menu, {SpotMark mark = const SpotMark(id: 0)}) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: width,
      child: SpotScope(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              key: const ValueKey('stack'),
              clipBehavior: Clip.none,
              fit: StackFit.passthrough,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(
                      key: ValueKey('button'),
                      height: 40,
                      child: Align(alignment: Alignment.bottomLeft, child: Text('References')),
                    ),
                    mark,
                  ],
                ),
                menu,
              ],
            ),
            const SizedBox(key: ValueKey('after'), height: 10),
          ],
        ),
      ),
    ),
  ),
);

/// [ask] of a box laid out, as a box above it would ask it.
T _asked<T>(T Function() ask) {
  final was = RenderObject.debugCheckingIntrinsics;
  RenderObject.debugCheckingIntrinsics = true;
  try {
    return ask();
  } finally {
    RenderObject.debugCheckingIntrinsics = was;
  }
}

Future<List<double>> _measure(WidgetTester t, Widget w) async {
  await t.pumpWidget(w);
  final stack = t.renderObject<RenderBox>(find.byKey(const ValueKey('stack')));
  return [
    for (final k in _keys)
      ...() {
        final r = t.getRect(find.byKey(k));
        return [r.left, r.top, r.right, r.bottom];
      }(),
    _asked(() => stack.getDistanceToBaseline(TextBaseline.alphabetic)) ?? -1,
  ];
}

/// The cases: the kept spelling, and the pins moved.
final Map<String, (Widget, Widget)> _cases = {
  'a negative top': (
    const Positioned(
      left: 0,
      top: 0,
      right: 0,
      child: SpotShift(
        id: 0,
        child: Inset(insets: EdgeInsets.only(top: -1), child: _menu),
      ),
    ),
    const Positioned(left: 0, top: -1, right: 0, child: SpotShift(id: 0, child: _menu)),
  ),
  'a negative top and bottom': (
    const Positioned(
      left: 0,
      top: 0,
      right: 0,
      child: SpotShift(
        id: 0,
        child: Inset(insets: EdgeInsets.only(top: -1, bottom: -10), child: _menu),
      ),
    ),
    const Positioned(left: 0, top: -1, right: 0, child: SpotShift(id: 0, child: _menu)),
  ),
  'pinned at both ends': (
    const Positioned(
      left: 0,
      top: 0,
      right: 0,
      height: 400,
      child: SpotShift(
        id: 0,
        child: Inset(insets: EdgeInsets.only(top: -1), child: _menu),
      ),
    ),
    const Positioned(left: 0, top: -1, right: 0, height: 401, child: SpotShift(id: 0, child: _menu)),
  ),
  'a positive side padded inside': (
    const Positioned(
      left: 0,
      top: 0,
      right: 0,
      child: SpotShift(
        id: 0,
        child: Inset(insets: EdgeInsets.only(left: 8, top: -1), child: _menu),
      ),
    ),
    const Positioned(
      left: 0,
      top: -1,
      right: 0,
      child: SpotShift(
        id: 0,
        child: Padding(padding: EdgeInsets.only(left: 8), child: _menu),
      ),
    ),
  ),
  'shifted across too': (
    const Positioned(
      left: 0,
      top: 0,
      child: SpotShift(
        id: 0,
        across: true,
        child: Inset(insets: EdgeInsets.only(top: -1), child: _menu),
      ),
    ),
    const Positioned(left: 0, top: -1, child: SpotShift(id: 0, across: true, child: _menu)),
  ),
};

void main() {
  for (final MapEntry(key: name, value: (kept, moved)) in _cases.entries) {
    testWidgets('the pin moved is the margin under the shift: $name', (t) async {
      for (final width in const [400.0, 200.0, 120.0, 60.0]) {
        final a = await _measure(t, _page(width, kept));
        final b = await _measure(t, _page(width, moved));
        expect(b, a, reason: '$width');
      }
    });
  }

  testWidgets('NEGATIVE: a shift that aligns the box down stands it by the size the Inset reports', (t) async {
    const kept = Positioned(
      left: 0,
      top: 0,
      right: 0,
      child: SpotShift(
        id: 0,
        alignY: 1,
        child: Inset(insets: EdgeInsets.only(top: -1), child: _menu),
      ),
    );
    const moved = Positioned(left: 0, top: -1, right: 0, child: SpotShift(id: 0, alignY: 1, child: _menu));
    await t.pumpWidget(_page(200, kept));
    final a = t.getRect(find.byKey(const ValueKey('menu')));
    await t.pumpWidget(_page(200, moved));
    expect(t.getRect(find.byKey(const ValueKey('menu'))).top, isNot(a.top));
  });

  testWidgets('NEGATIVE: a shift that ends the box across at the mark stands it by its width', (t) async {
    const kept = Positioned(
      left: 0,
      top: 0,
      child: SpotShift(
        id: 0,
        across: true,
        child: Inset(insets: EdgeInsets.only(left: -6), child: _menu),
      ),
    );
    const moved = Positioned(left: -6, top: 0, child: SpotShift(id: 0, across: true, child: _menu));
    const end = SpotMark(id: 0, along: 1, end: true);
    await t.pumpWidget(_page(200, kept, mark: end));
    final a = t.getRect(find.byKey(const ValueKey('menu')));
    await t.pumpWidget(_page(200, moved, mark: end));
    expect(t.getRect(find.byKey(const ValueKey('menu'))).left, isNot(a.left));
  });
}
