// A [FlexLine] lays a line out the way CSS does, and the cases here are the
// ones no `Row` of `Flexible`s can be written for: two items shrinking in
// proportion to their own sizes, an item that stops at its longest word, a
// percentage basis, auto margins, a baseline, a line that overflows and is
// still centred.
import 'dart:math' as math;

import 'package:css_box/css_box.dart';
import 'package:css_box/rendering.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// A child that behaves like a paragraph: as wide as all its words where
/// there is room ([max]), never narrower than its longest ([min]), and one
/// line deeper every time the room halves.
class Words extends LeafRenderObjectWidget {
  const Words({super.key, required this.min, required this.max, this.line = 10});

  final double min, max, line;

  @override
  RenderObject createRenderObject(BuildContext context) => RenderWords(min, max, line);

  @override
  void updateRenderObject(BuildContext context, RenderWords renderObject) {
    renderObject
      ..min = min
      ..max = max
      ..line = line
      ..markNeedsLayout();
  }
}

class RenderWords extends RenderBox {
  RenderWords(this.min, this.max, this.line);

  double min, max, line;

  double _width(double offered) => math.max(min, math.min(max, offered));
  double _height(double width) => line * (width <= 0 ? 1 : (max / math.max(width, min)).ceil());

  @override
  double computeMinIntrinsicWidth(double height) => min;
  @override
  double computeMaxIntrinsicWidth(double height) => max;
  @override
  double computeMinIntrinsicHeight(double width) => _height(_width(width));
  @override
  double computeMaxIntrinsicHeight(double width) => _height(_width(width));

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final width = constraints.hasTightWidth ? constraints.maxWidth : _width(constraints.maxWidth);
    return constraints.constrain(Size(width, _height(width)));
  }

  @override
  double? computeDryBaseline(BoxConstraints constraints, TextBaseline baseline) =>
      getDryLayout(constraints).height * 0.8;

  @override
  void performLayout() => size = computeDryLayout(constraints);

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) => size.height * 0.8;
}

/// A child that says when it is painted, and that answers a hit test
/// anywhere inside its box.
class Mark extends LeafRenderObjectWidget {
  const Mark(this.name, this.log, {super.key, this.box = const Size(20, 20)});

  final String name;
  final List<String> log;
  final Size box;

  @override
  RenderObject createRenderObject(BuildContext context) => RenderMark(name, log, box);

  @override
  void updateRenderObject(BuildContext context, RenderMark renderObject) {
    renderObject
      ..name = name
      ..box = box
      ..markNeedsLayout();
  }
}

class RenderMark extends RenderBox {
  RenderMark(this.name, this.log, this.box);

  String name;
  final List<String> log;
  Size box;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.constrain(box);

  @override
  void performLayout() => size = computeDryLayout(constraints);

  @override
  double computeMinIntrinsicWidth(double height) => box.width;

  @override
  double computeMaxIntrinsicWidth(double height) => box.width;

  @override
  double computeMinIntrinsicHeight(double width) => box.height;

  @override
  double computeMaxIntrinsicHeight(double width) => box.height;

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  void paint(PaintingContext context, Offset offset) => log.add(name);
}

/// [child] in a slot [width] by [height], at the top left of the screen.
Future<void> pump(WidgetTester tester, Widget child, {double? width = 300, double? height = 50}) => tester.pumpWidget(
  Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: width, height: height, child: child),
    ),
  ),
);

Size sizeOf(WidgetTester tester, String key) => tester.getSize(find.byKey(ValueKey(key)));
Offset topLeftOf(WidgetTester tester, String key) => tester.getTopLeft(find.byKey(ValueKey(key)));

Widget box(String key, {double? width, double height = 10}) =>
    SizedBox(key: ValueKey(key), width: width, height: height);

void main() {
  testWidgets('z is the order the items are painted in, and it moves nothing', (tester) async {
    final log = <String>[];
    Future<void> line(List<Widget> children) async {
      log.clear();
      await pump(tester, FlexLine(crossAxisAlignment: CrossAxisAlignment.start, children: children));
      await tester.pump();
    }

    // With no `z` anywhere the items paint the way they are written, which
    // is what CSS asks for (css-flexbox-1 5.4).
    await line([Mark('a', log, key: const ValueKey('a')), Mark('b', log, key: const ValueKey('b'))]);
    expect(log, ['a', 'b']);
    // An order lifts an item over the ones written after it, and ties keep
    // the written order.
    await line([
      FlexCell(z: 2, child: Mark('a', log, key: const ValueKey('a'))),
      Mark('b', log, key: const ValueKey('b')),
      FlexCell(z: 1, child: Mark('c', log, key: const ValueKey('c'))),
    ]);
    expect(log, ['b', 'c', 'a']);
    // A negative one drops below them all.
    await line([
      Mark('a', log, key: const ValueKey('a')),
      FlexCell(z: -1, child: Mark('b', log, key: const ValueKey('b'))),
    ]);
    expect(log, ['b', 'a']);
    // And no box moves: b is still the second item along the line.
    expect(topLeftOf(tester, 'a'), Offset.zero);
    expect(topLeftOf(tester, 'b'), const Offset(20, 0));
    // What is painted over the rest is what a hit test finds first. The
    // two overlap over 10px, where the lifted one wins.
    await line([
      Mark('a', log, key: const ValueKey('a')),
      FlexCell(
        z: 3,
        margin: const EdgeInsets.only(left: -10),
        child: Mark('b', log, key: const ValueKey('b')),
      ),
    ]);
    final result = BoxHitTestResult();
    tester.renderObject<RenderBox>(find.byType(FlexLine)).hitTest(result, position: const Offset(15, 5));
    expect(result.path.map((e) => e.target).whereType<RenderMark>().first.name, 'b');
  });

  testWidgets('two items that can give, give in proportion to their sizes', (tester) async {
    // css-flexbox-1 9.7: 300 and 100 in a 300 line overflow by 100, and the
    // shrink is shared by `shrink x base size` -- 3:1 -- so they end at 225
    // and 75. Two `Flexible`s take at most 150 each, whatever flex factors
    // they are written with, because a `Flexible` cannot start from a size.
    await pump(
      tester,
      FlexLine(
        children: [
          FlexCell(basis: 300, child: box('a')),
          FlexCell(basis: 100, child: box('b')),
        ],
      ),
    );
    expect(sizeOf(tester, 'a').width, 225);
    expect(sizeOf(tester, 'b').width, 75);
    expect(topLeftOf(tester, 'b').dx, 225);
  });

  testWidgets('an item stops shrinking at its longest word', (tester) async {
    // css-flexbox-1 4.5: the automatic minimum. A 50px line round a 100px
    // word leaves the word 100 wide and overflows; `min: 0` gives the floor
    // up and the line crushes it to 50.
    await pump(
      tester,
      FlexLine(
        children: [FlexCell(child: Words(key: const ValueKey('w'), min: 100, max: 100))],
      ),
      width: 50,
    );
    expect(sizeOf(tester, 'w').width, 100);

    await pump(
      tester,
      FlexLine(
        children: [FlexCell(min: 0, child: Words(key: const ValueKey('w'), min: 100, max: 100))],
      ),
      width: 50,
    );
    expect(sizeOf(tester, 'w').width, 50);
  });

  testWidgets('a floor each, and the line takes what is left from both', (tester) async {
    // Two paragraphs, 200 and 100 of words, in 240: the overflow of 60 is
    // shared 2:1, so 160 and 80 -- and the second's longest word is 90, so
    // it freezes there and the first gives up the other 10 (9.7 step 4e).
    await pump(
      tester,
      FlexLine(
        children: [
          FlexCell(child: Words(key: const ValueKey('a'), min: 40, max: 200)),
          FlexCell(child: Words(key: const ValueKey('b'), min: 90, max: 100)),
        ],
      ),
      width: 240,
    );
    expect(sizeOf(tester, 'a').width, 150);
    expect(sizeOf(tester, 'b').width, 90);
  });

  testWidgets('a basis as a share of the line is the share of the line', (tester) async {
    await pump(
      tester,
      FlexLine(
        children: [
          FlexCell(basisFraction: 0.25, shrink: 0, child: box('a')),
          FlexCell(basisFraction: 0.5, shrink: 0, child: box('b')),
        ],
      ),
      width: 200,
    );
    expect(sizeOf(tester, 'a').width, 50);
    expect(sizeOf(tester, 'b').width, 100);
  });

  testWidgets('the room left over goes to grow, and to auto margins first', (tester) async {
    await pump(
      tester,
      FlexLine(
        children: [
          FlexCell(basis: 0, grow: 1, child: box('a')),
          FlexCell(basis: 0, grow: 3, child: box('b')),
        ],
      ),
      width: 400,
    );
    expect(sizeOf(tester, 'a').width, 100);
    expect(sizeOf(tester, 'b').width, 300);

    // `margin-left: auto; margin-right: auto` centres the item and leaves
    // `justify-content` nothing to place.
    await pump(
      tester,
      FlexLine(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FlexCell(mainSize: 100, shrink: 0, autoMargin: const AutoEdges.symmetric(horizontal: true), child: box('c')),
        ],
      ),
    );
    expect(topLeftOf(tester, 'c').dx, 100);

    // One auto edge takes all of it.
    await pump(
      tester,
      FlexLine(
        children: [FlexCell(mainSize: 100, shrink: 0, autoMargin: const AutoEdges(left: true), child: box('d'))],
      ),
    );
    expect(topLeftOf(tester, 'd').dx, 200);
  });

  testWidgets('an item past its line with auto margins across stands at the start of it', (tester) async {
    // css-flexbox-1 9.6 step 13: the auto margins take only room there is;
    // past the line, the one at the writing mode's start is zero.
    Future<void> column(AutoEdges auto, {TextDirection dir = TextDirection.ltr}) => pump(
      tester,
      FlexLine(
        direction: Axis.vertical,
        textDirection: dir,
        children: [FlexCell(crossSize: 400, autoMargin: auto, child: box('a'))],
      ),
    );
    await column(const AutoEdges(left: true, right: true));
    expect(topLeftOf(tester, 'a').dx, 0);
    await column(const AutoEdges(left: true));
    expect(topLeftOf(tester, 'a').dx, 0);
    // A right-to-left column starts at its right: the item's right edge.
    await column(const AutoEdges(left: true, right: true), dir: TextDirection.rtl);
    expect(topLeftOf(tester, 'a').dx, -100);
    // NEGATIVE: one that fits is centred.
    await pump(
      tester,
      FlexLine(
        direction: Axis.vertical,
        children: [FlexCell(crossSize: 100, autoMargin: const AutoEdges(left: true, right: true), child: box('b'))],
      ),
    );
    expect(topLeftOf(tester, 'b').dx, 100);
  });

  testWidgets('a line that overflows is still centred, and hangs out of both ends', (tester) async {
    // css-align-3 5.3 only falls back for the distribution keywords:
    // `center` with negative free space centres anyway, which is why a
    // centred line that can overflow is no `Row`.
    await pump(
      tester,
      FlexLine(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [FlexCell(mainSize: 120, shrink: 0, child: box('a'))],
      ),
      width: 100,
    );
    expect(topLeftOf(tester, 'a').dx, -10);

    // `space-between` falls back to the start.
    await pump(
      tester,
      FlexLine(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          FlexCell(mainSize: 120, shrink: 0, child: box('b')),
          FlexCell(mainSize: 20, shrink: 0, child: box('c')),
        ],
      ),
      width: 100,
    );
    expect(topLeftOf(tester, 'b').dx, 0);
    expect(topLeftOf(tester, 'c').dx, 120);
  });

  testWidgets('the items line up on a baseline, and the line is as deep as that makes it', (tester) async {
    // A box with no text of its own has its baseline at its bottom edge
    // (css-flexbox-1 8.5), so a 10-deep box under a 20-deep one sits 10
    // down.
    await pump(
      tester,
      FlexLine(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        children: [
          FlexCell(child: box('a', width: 10, height: 20)),
          FlexCell(child: box('b', width: 10, height: 10)),
        ],
      ),
      height: null,
    );
    expect(topLeftOf(tester, 'a').dy, 0);
    expect(topLeftOf(tester, 'b').dy, 10);
    expect(tester.getSize(find.byType(FlexLine)).height, 20);

    // Two paragraphs whose baselines are four fifths down: the shallower one
    // drops by the difference, and the line is as deep as the deeper one.
    await pump(
      tester,
      FlexLine(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        children: [
          FlexCell(child: Words(key: const ValueKey('c'), min: 20, max: 20, line: 30)),
          FlexCell(child: Words(key: const ValueKey('d'), min: 20, max: 20, line: 10)),
        ],
      ),
      height: null,
    );
    expect(topLeftOf(tester, 'd').dy, 16);
    // The line is as deep as the deeper paragraph: 24 above the baseline
    // and 6 below it, where the shallow one needs 8 and 2.
    expect(tester.getSize(find.byType(FlexLine)).height, 30);
  });

  testWidgets('an item is as deep as the line unless it says otherwise', (tester) async {
    await pump(
      tester,
      FlexLine(
        children: [
          FlexCell(mainSize: 10, child: box('a', height: 5)),
          FlexCell(mainSize: 10, crossSize: 12, child: box('b', height: 5)),
          FlexCell(mainSize: 10, align: CrossAxisAlignment.center, child: box('c', height: 8)),
        ],
      ),
    );
    expect(sizeOf(tester, 'a').height, 50);
    expect(sizeOf(tester, 'b').height, 12);
    expect(sizeOf(tester, 'c').height, 8);
    expect(topLeftOf(tester, 'c').dy, 21);
  });

  testWidgets('a line with no length of its own is as long as its content, and no longer than the room', (
    tester,
  ) async {
    // fit-content (css-sizing-3 5.2.2): the content where it fits, the room
    // where it does not, and never less than the items' floors.
    await pump(
      tester,
      Align(
        alignment: Alignment.topLeft,
        child: FlexLine(
          children: [
            FlexCell(child: box('a', width: 60, height: 10)),
            FlexCell(child: box('b', width: 40, height: 10)),
          ],
        ),
      ),
    );
    expect(tester.getSize(find.byType(FlexLine)).width, 100);

    await pump(
      tester,
      Align(
        alignment: Alignment.topLeft,
        child: FlexLine(
          children: [
            FlexCell(child: Words(key: const ValueKey('c'), min: 80, max: 400)),
            FlexCell(child: Words(key: const ValueKey('d'), min: 80, max: 400)),
          ],
        ),
      ),
    );
    // 800 of words in 300: the line takes the room, both items their share.
    expect(tester.getSize(find.byType(FlexLine)).width, 300);
    expect(sizeOf(tester, 'c').width, 150);
  });

  testWidgets('a gap is room between the items and length of the line', (tester) async {
    await pump(
      tester,
      Align(
        alignment: Alignment.topLeft,
        child: FlexLine(
          spacing: 10,
          children: [
            FlexCell(child: box('a', width: 60, height: 10)),
            FlexCell(child: box('b', width: 40, height: 10)),
          ],
        ),
      ),
    );
    expect(tester.getSize(find.byType(FlexLine)).width, 110);
    expect(topLeftOf(tester, 'b').dx, 70);
  });

  testWidgets('a reversed line runs the other way and its margins do not', (tester) async {
    // `flex-direction: row-reverse` turns the MAIN AXIS round: the first
    // child is the rightmost, and `justify-content: flex-start` -- which
    // names the start of that axis -- packs against the right edge. Each
    // item keeps the margins written on its own left and right, so `a`'s
    // 8px left margin sits between it and `b`, on its left as ever.
    await pump(
      tester,
      FlexLine(
        reverse: true,
        children: [
          FlexCell(margin: const EdgeInsets.only(left: 8), child: box('a', width: 40)),
          FlexCell(child: box('b', width: 60)),
        ],
      ),
    );
    expect(topLeftOf(tester, 'a').dx, 260);
    expect(topLeftOf(tester, 'b').dx, 192);

    // `flex-end` is then the LEFT edge, and the two swap which end they
    // are packed at.
    await pump(
      tester,
      FlexLine(
        reverse: true,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FlexCell(child: box('a', width: 40)),
          FlexCell(child: box('b', width: 60)),
        ],
      ),
    );
    expect(topLeftOf(tester, 'b').dx, 0);
    expect(topLeftOf(tester, 'a').dx, 60);

    // The room spread between the items is its own mirror: the same gap
    // wherever the line runs.
    await pump(
      tester,
      FlexLine(
        reverse: true,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          FlexCell(child: box('a', width: 40)),
          FlexCell(child: box('b', width: 60)),
        ],
      ),
    );
    expect(topLeftOf(tester, 'a').dx, 260);
    expect(topLeftOf(tester, 'b').dx, 0);

    // ...AND WITH NO ROOM TO SPREAD it packs at the flex start, the right,
    // and runs out of the left: Chrome does not make that fallback safe
    // (`fixtures/flex-reverse-hang` r6).
    await pump(
      tester,
      FlexLine(
        reverse: true,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          FlexCell(shrink: 0, mainSize: 150, child: box('a', width: 150)),
          FlexCell(shrink: 0, mainSize: 120, child: box('b', width: 120)),
        ],
      ),
      width: 200,
    );
    expect(topLeftOf(tester, 'a').dx, 50);
    expect(topLeftOf(tester, 'b').dx, -70);

    // A COLUMN REVERSES DOWNWARDS: the first child is at the bottom.
    await pump(
      tester,
      FlexLine(
        direction: Axis.vertical,
        reverse: true,
        children: [
          FlexCell(child: box('a', width: 10, height: 20)),
          FlexCell(child: box('b', width: 10, height: 30)),
        ],
      ),
      height: 100,
    );
    expect(topLeftOf(tester, 'a').dy, 80);
    expect(topLeftOf(tester, 'b').dy, 50);
    // AND ITS BASELINE COMES FROM THE ITEM AT ITS NEAR EDGE -- the last
    // one written, which a reversed column draws at the top. `a` is
    // 90 down the box and `b`, empty, ends 40 down; a `Row` lining the
    // two up on a baseline drops the paragraph beside it to 40 and not to
    // `a`'s own bottom (`fixtures/baseline-groups` row 3).
    await pump(
      tester,
      Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          SizedBox(
            height: 90,
            child: FlexLine(
              direction: Axis.vertical,
              reverse: true,
              children: [
                FlexCell(child: box('a', width: 10, height: 50)),
                FlexCell(child: box('b', width: 10, height: 40)),
              ],
            ),
          ),
          const Words(key: ValueKey('c'), min: 10, max: 10, line: 20),
        ],
      ),
      height: null,
    );
    expect(tester.takeException(), isNull);
    expect(topLeftOf(tester, 'a').dy, 40);
    expect(topLeftOf(tester, 'b').dy, 0);
    expect(topLeftOf(tester, 'c').dy, 24);
  });

  testWidgets('a cap on the box is a cap on the room its items are laid out in', (tester) async {
    // `max-width` on a flex container caps the box, and the box IS the
    // room: three items that would each like 100 are offered 800, capped
    // at 240, and shrink into the cap exactly as they would into a slot
    // that size.
    await pump(
      tester,
      FlexLine(
        maxExtent: 240,
        children: [
          FlexCell(child: Words(key: const ValueKey('a'), min: 0, max: 100)),
          FlexCell(child: Words(key: const ValueKey('b'), min: 0, max: 100)),
          FlexCell(child: Words(key: const ValueKey('c'), min: 0, max: 100)),
        ],
      ),
      width: null,
    );
    expect(tester.getSize(find.byType(FlexLine)).width, 240);
    expect(sizeOf(tester, 'a').width, 80);
    expect(topLeftOf(tester, 'c').dx, 160);

    // A cap that never binds says nothing: the two are what they asked
    // for and the line is as long as they are.
    await pump(
      tester,
      FlexLine(
        maxExtent: 900,
        children: [
          FlexCell(child: Words(key: const ValueKey('a'), min: 0, max: 100)),
          FlexCell(child: Words(key: const ValueKey('b'), min: 0, max: 100)),
        ],
      ),
      width: null,
    );
    expect(sizeOf(tester, 'a').width, 100);
    expect(tester.getSize(find.byType(FlexLine)).width, 200);

    // AND THE LINE BREAKS AGAINST THE CAP, not against the room it was
    // offered: two of the three fit in 240, and the third starts a line.
    await pump(
      tester,
      FlexLine(
        maxExtent: 240,
        wrap: true,
        children: [
          FlexCell(shrink: 0, basis: 100, child: box('a')),
          FlexCell(shrink: 0, basis: 100, child: box('b')),
          FlexCell(shrink: 0, basis: 100, child: box('c')),
        ],
      ),
      width: null,
      height: null,
    );
    expect(topLeftOf(tester, 'b').dy, 0);
    expect(topLeftOf(tester, 'c').dy, 10);

    // A FLOOR THE LINE IS HELD TO WINS OVER IT, as CSS's does.
    await pump(
      tester,
      ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 260),
        child: FlexLine(maxExtent: 200, children: [FlexCell(basis: 100, child: box('a'))]),
      ),
      width: null,
    );
    expect(tester.getSize(find.byType(FlexLine)).width, 260);
  });

  testWidgets('what the line answers when it is measured', (tester) async {
    // A parent that asks how wide the line wants to be gets the sum of its
    // items' max-content sizes, gaps included; how narrow, the sum of their
    // min-content sizes (css-flexbox-1 9.9.1 for a single line).
    await pump(
      tester,
      Align(
        alignment: Alignment.topLeft,
        child: IntrinsicWidth(
          child: FlexLine(
            spacing: 4,
            children: [
              FlexCell(child: Words(key: const ValueKey('a'), min: 20, max: 60)),
              FlexCell(child: Words(key: const ValueKey('b'), min: 10, max: 40)),
            ],
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(FlexLine)).width, 104);

    // Down a column the line is as deep as its items stacked. Loose, it is
    // as wide as its widest item, and the narrower one stretches to that;
    // held to a width, it is that wide and both stretch to it.
    Widget column() => FlexLine(
      direction: Axis.vertical,
      spacing: 4,
      children: [
        FlexCell(child: box('c', width: 30, height: 20)),
        FlexCell(child: box('d', width: 50, height: 10)),
      ],
    );
    await pump(tester, Align(alignment: Alignment.topLeft, child: column()), height: null);
    expect(tester.getSize(find.byType(FlexLine)), const Size(50, 34));
    expect(sizeOf(tester, 'c').width, 50);
    await pump(tester, column(), height: null);
    expect(tester.getSize(find.byType(FlexLine)), const Size(300, 34));
    expect(sizeOf(tester, 'c').width, 300);
    expect(sizeOf(tester, 'd').width, 300);

    // ACROSS a column the min-content width is the widest longest word and
    // the max-content width the widest item; along a row, the depth at a
    // width is the depth of the items wrapped in that width.
    await pump(
      tester,
      FlexLine(
        direction: Axis.vertical,
        children: [
          FlexCell(child: Words(min: 40, max: 829)),
          FlexCell(child: Words(min: 60, max: 200)),
        ],
      ),
      height: null,
    );
    final down = tester.renderObject<RenderFlexLine>(find.byType(FlexLine));
    expect(down.getMinIntrinsicWidth(double.infinity), 60);
    expect(down.getMaxIntrinsicWidth(double.infinity), 829);
    await pump(tester, FlexLine(children: [FlexCell(child: Words(min: 50, max: 300))]));
    final along = tester.renderObject<RenderFlexLine>(find.byType(FlexLine));
    expect(along.getMaxIntrinsicHeight(100), 30);
    expect(along.getMaxIntrinsicHeight(double.infinity), 10);
  });

  testWidgets('an item across a column wraps in the room the column has', (tester) async {
    // A centred sentence 829 wide in a column 358 wide is FIT-CONTENT
    // there: 358 wide, three lines deep, flush with the column -- not 829
    // wide and hanging 235 out of each side.
    Widget sentence() => FlexLine(
      direction: Axis.vertical,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [FlexCell(child: Words(key: const ValueKey('w'), min: 40, max: 829, line: 33))],
    );
    await pump(tester, sentence(), width: 358, height: null);
    expect(sizeOf(tester, 'w'), const Size(358, 99));
    expect(topLeftOf(tester, 'w').dx, 0);

    // And a box that shrinks to fit the column asks its min-content width,
    // which is the longest word, so it settles on the room: 358.
    await pump(
      tester,
      Align(
        alignment: Alignment.topLeft,
        child: ShrinkWidth(child: sentence()),
      ),
      width: 358,
      height: null,
    );
    expect(tester.getSize(find.byType(FlexLine)).width, 358);
    expect(sizeOf(tester, 'w'), const Size(358, 99));
  });

  testWidgets('a column asked its width never lays an item out in no width at all', (tester) async {
    // A `Stack` of positioned children only is as big as it is offered,
    // and throws when that is unbounded. Asked its min- or max-content
    // width, a column asks its items theirs -- never a dry layout with no
    // width, which is how a first cut of this line took a browser vendor down.
    await pump(
      tester,
      Align(
        alignment: Alignment.topLeft,
        child: IntrinsicWidth(
          child: FlexLine(
            direction: Axis.vertical,
            children: [
              SizedBox(
                height: 20,
                child: Stack(children: [Positioned(left: 0, top: 0, child: box('p', width: 10))]),
              ),
              box('q', width: 40),
            ],
          ),
        ),
      ),
      height: null,
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(FlexLine)), const Size(40, 30));
  });

  testWidgets('a line of boxes with no text still has a baseline', (tester) async {
    // A line's baseline is its first item's (css-flexbox-1 8.5), and an item
    // with no text has one at its bottom edge -- so the line inside the
    // 60-deep item stands on the 30-deep box at its top, and the 20-deep box
    // beside it drops 10 to meet it.
    await pump(
      tester,
      FlexLine(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        children: [
          FlexCell(
            crossSize: 60,
            child: FlexLine(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [FlexCell(child: box('a', width: 10, height: 30))],
            ),
          ),
          FlexCell(child: box('b', width: 10, height: 20)),
        ],
      ),
      height: null,
    );
    expect(topLeftOf(tester, 'a').dy, 0);
    expect(topLeftOf(tester, 'b').dy, 10);
    expect(tester.getSize(find.byType(FlexLine).first).height, 60);

    // Down a column the baseline is the first item's too: the 20-deep box
    // sits 10 down to meet the bottom of the column's first box, 30 down.
    await pump(
      tester,
      FlexLine(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        children: [
          FlexCell(
            child: FlexLine(
              direction: Axis.vertical,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FlexCell(child: box('c', width: 10, height: 30)),
                FlexCell(child: box('d', width: 10, height: 30)),
              ],
            ),
          ),
          FlexCell(child: box('e', width: 10, height: 20)),
        ],
      ),
      height: null,
    );
    expect(topLeftOf(tester, 'c').dy, 0);
    expect(topLeftOf(tester, 'e').dy, 10);

    // An item that clips keeps its baseline inside itself: the line in the
    // 10-deep clipped item has its box hang 40 down, but the item stands on
    // its own bottom edge, 10 down, so the 20-deep box sets the baseline
    // and the clipped item drops 10.
    await pump(
      tester,
      FlexLine(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        children: [
          FlexCell(
            clips: true,
            crossSize: 10,
            child: FlexLine(
              key: const ValueKey('f'),
              children: [FlexCell(crossSize: 40, child: box('g', width: 10, height: 40))],
            ),
          ),
          FlexCell(child: box('h', width: 10, height: 20)),
        ],
      ),
      height: null,
    );
    expect(topLeftOf(tester, 'f').dy, 10);
    expect(topLeftOf(tester, 'h').dy, 0);
  });

  testWidgets('the box laying a line out can ask where its baseline is', (tester) async {
    // A `Row` lines the line up on its baseline once it has laid it out --
    // as a paragraph does a line inside its text -- and the line answers
    // from where it placed its first item: the bottom of the 30-deep box.
    // The 20-deep paragraph beside it, its baseline 16 down, drops 14 to
    // meet it.
    await pump(
      tester,
      Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          FlexLine(children: [FlexCell(child: box('a', width: 10, height: 30))]),
          const Words(key: ValueKey('b'), min: 10, max: 10, line: 20),
        ],
      ),
      height: null,
    );
    expect(tester.takeException(), isNull);
    expect(topLeftOf(tester, 'a').dy, 0);
    expect(topLeftOf(tester, 'b').dy, 14);
  });

  testWidgets('spread out with no room to spread, the items start where the line starts', (tester) async {
    // One item: `space-around` centres it (css-align-3 5.3).
    await pump(tester, FlexLine(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [box('a', width: 100)]));
    expect(topLeftOf(tester, 'a').dx, 100);

    // One item longer than the line: the fallback is a SAFE centre, so it
    // starts at the start and hangs out of the end only.
    await pump(tester, FlexLine(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [box('b', width: 400)]));
    expect(topLeftOf(tester, 'b').dx, 0);

    // A plain `center` is not safe: it hangs out of both ends.
    await pump(tester, FlexLine(mainAxisAlignment: MainAxisAlignment.center, children: [box('c', width: 400)]));
    expect(topLeftOf(tester, 'c').dx, -50);
  });

  testWidgets('a share is of a length the line has', (tester) async {
    // Along a line 300 long: half of it, and a quarter of it plus 10 (a
    // `calc()`).
    await pump(
      tester,
      FlexLine(
        children: [
          FlexCell(mainSizeFraction: 0.5, child: box('a')),
          FlexCell(basis: 10, basisFraction: 0.25, shrink: 0, child: box('b')),
        ],
      ),
    );
    expect(sizeOf(tester, 'a').width, 150);
    expect(sizeOf(tester, 'b').width, 85);

    // A cap as a share: a third of 300.
    await pump(tester, FlexLine(children: [FlexCell(grow: 1, maxFraction: 0.25, child: box('c'))]));
    expect(sizeOf(tester, 'c').width, 75);

    // Across a line given no depth a share is no length -- and no `auto`
    // either, so the item keeps its own depth where a stretch would have
    // made it 40.
    await pump(
      tester,
      FlexLine(
        children: [
          FlexCell(crossSizeFraction: 0.5, child: box('d', width: 10, height: 10)),
          box('e', width: 10, height: 40),
        ],
      ),
      height: null,
    );
    expect(sizeOf(tester, 'd').height, 10);
    expect(sizeOf(tester, 'e').height, 40);

    // Given a depth of 50, the share is 25.
    await pump(tester, FlexLine(children: [FlexCell(crossSizeFraction: 0.5, child: box('f', width: 10, height: 10))]));
    expect(sizeOf(tester, 'f').height, 25);
  });

  testWidgets('a row whose length its content settles reads its shares against that length', (tester) async {
    // In a slot that leaves the row its content's width, the cap of a
    // quarter is first no cap: the paragraph contributes its 100, the box
    // its 200, and the row is 300. Then the quarter is of 300 (css-sizing-3
    // 5.2.1): the paragraph is held to 75 and the row stays 300 -- it is
    // what the share is OF, and is not measured again.
    await pump(
      tester,
      Align(
        alignment: Alignment.topLeft,
        child: FlexLine(
          children: [
            FlexCell(grow: 1, maxFraction: 0.25, child: Words(key: const ValueKey('a'), min: 20, max: 100)),
            FlexCell(shrink: 0, child: box('b', width: 200)),
          ],
        ),
      ),
      width: 1000,
      height: null,
    );
    expect(sizeOf(tester, 'a').width, 75);
    expect(sizeOf(tester, 'b').width, 200);
    expect(tester.getSize(find.byType(FlexLine)).width, 300);
  });

  testWidgets('an item that clips has no floor and no content to count', (tester) async {
    await pump(
      tester,
      FlexLine(
        children: [
          FlexCell(clips: true, child: Words(key: const ValueKey('a'), min: 100, max: 200)),
          FlexCell(child: box('b', width: 200, height: 10)),
        ],
      ),
      width: 300,
    );
    // 200 + 200 in 300: the clipped item's floor is nothing, the box's is
    // its own size, so the clipped one gives up all 100.
    expect(sizeOf(tester, 'a').width, 100);
    expect(sizeOf(tester, 'b').width, 200);
  });

  testWidgets('a cap stops an item and its siblings take the rest', (tester) async {
    await pump(
      tester,
      FlexLine(
        children: [
          FlexCell(basis: 0, grow: 1, max: 100, child: box('a')),
          FlexCell(basis: 0, grow: 1, child: box('b')),
        ],
      ),
      width: 400,
    );
    expect(sizeOf(tester, 'a').width, 100);
    expect(sizeOf(tester, 'b').width, 300);
  });

  testWidgets('the line shrinks an item by its content box, not by its padding', (tester) async {
    // css-flexbox-1 9.7: the scaled shrink factor is the item's INNER base
    // size. Two items 200 wide in 300, one of them 100 of padding: the
    // overflow of 100 is shared 200:100, so 133.3 and 166.7 -- and neither
    // goes below its frame.
    await pump(
      tester,
      FlexLine(
        children: [
          FlexCell(mainSize: 200, min: 0, child: box('a', width: 200)),
          FlexCell(
            mainSize: 200,
            min: 0,
            frame: const EdgeInsets.symmetric(horizontal: 50),
            child: box('b', width: 200),
          ),
        ],
      ),
      width: 300,
    );
    expect(sizeOf(tester, 'a').width, closeTo(133.33, 0.01));
    expect(sizeOf(tester, 'b').width, closeTo(166.67, 0.01));
  });

  testWidgets('an item is measured at the width its own maximum holds it to', (tester) async {
    // css-flexbox-1 9.2 step 3 measures the base size at the CLAMPED cross
    // size. Down a column 400 wide, an item that asks for all of it but
    // states `crossMax: 200` is laid out 200 wide, so its paragraph is
    // measured in 200 too: 100 of words in 200 is two 10px lines, not one.
    // Measured in the line's whole 400 the line came out a line short of
    // what it then drew (a docs site's intro section, 374 against 398).
    await pump(
      tester,
      FlexLine(
        key: const ValueKey('line'),
        direction: Axis.vertical,
        children: [
          FlexCell(crossSizeFraction: 1, crossMax: 200, child: const Words(key: ValueKey('words'), min: 50, max: 400)),
        ],
      ),
      width: 400,
      height: null,
    );
    expect(sizeOf(tester, 'words'), const Size(200, 20));
    expect(sizeOf(tester, 'line').height, 20);
  });

  testWidgets('an item centred by its margins is measured at the width its own maximum holds it to', (tester) async {
    // The same down a column for an item the line does not stretch, which
    // comes to its content's width in the room (fit-content) and is then
    // held by its cap: 300 of words in a column 400 wide, `max-width: 50%`,
    // is 200 wide and two 10px lines. Measured at the 300 its words came
    // to, it was one line deep and the item after it stood 10 high over
    // its second line (a music store's footer links, `max-width: 80%; margin: 0
    // auto`, 120 where Chrome's are 166).
    Widget column({double? capFraction}) => FlexLine(
      key: const ValueKey('line'),
      direction: Axis.vertical,
      children: [
        FlexCell(
          crossMaxFraction: capFraction,
          autoMargin: const AutoEdges(left: true, right: true),
          child: const Words(key: ValueKey('words'), min: 50, max: 300),
        ),
        FlexCell(child: box('after', width: 10)),
      ],
    );
    await pump(tester, column(capFraction: 0.5), width: 400, height: null);
    expect(sizeOf(tester, 'words'), const Size(200, 20));
    expect(topLeftOf(tester, 'after').dy, 20);
    // NEGATIVE: with no cap it is its content's 300, one line.
    await pump(tester, column(), width: 400, height: null);
    expect(sizeOf(tester, 'words'), const Size(300, 10));
    expect(topLeftOf(tester, 'after').dy, 10);
  });

  testWidgets('a column asked its height at a width holds its items to their shares of that width', (tester) async {
    // `getMaxIntrinsicHeight(400)` is the column's height AT 400, so an
    // item's `max-width: 50%` is 200 of it: two lines of words and the box
    // after them, 30. Asked with the width loose, the share was of nothing
    // and the words one 300 line: 20, where the column then drew 30
    // (the music store's footer under an `IntrinsicHeight`, 46 short).
    Widget column() => FlexLine(
      direction: Axis.vertical,
      children: [
        FlexCell(
          crossMaxFraction: 0.5,
          autoMargin: const AutoEdges(left: true, right: true),
          child: const Words(min: 50, max: 300),
        ),
        FlexCell(child: box('after', width: 10)),
      ],
    );
    await pump(
      tester,
      IntrinsicHeight(
        child: SizedBox(key: const ValueKey('held'), child: column()),
      ),
      width: 400,
      height: null,
    );
    expect(sizeOf(tester, 'held').height, 30);
    expect(topLeftOf(tester, 'after').dy, 20);
  });

  testWidgets('a row asked its height at a width holds its items to their shares of that width', (tester) async {
    // `getMaxIntrinsicHeight(400)` of a row is its height AT 400 too, where
    // its items state shares of it: a `width: 100%` picture of 2/1 is 400
    // wide and 200 deep, and the box after the `IntrinsicHeight` starts at
    // 200. Asked with the width loose, the row was its content's width --
    // the picture's, nothing -- the share nothing of it, and the answer 0.
    await pump(
      tester,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IntrinsicHeight(
            child: SizedBox(
              key: const ValueKey('held'),
              child: FlexLine(
                children: [
                  FlexCell(mainSizeFraction: 1, child: AspectRatio(key: const ValueKey('picture'), aspectRatio: 2)),
                ],
              ),
            ),
          ),
          box('after', width: 10),
        ],
      ),
      width: 400,
      height: null,
    );
    expect(sizeOf(tester, 'held').height, 200);
    expect(sizeOf(tester, 'picture'), const Size(400, 200));
    expect(topLeftOf(tester, 'after').dy, 200);

    // NEGATIVE: a row whose items state no share stays loose. Under an
    // `IntrinsicHeight` that is handed no width, the row is its content's
    // width: a 50 label 10 deep and, stretched beside it, a growing 2/1
    // picture 20 wide with no room to grow into -- 70 by 10, what it is
    // asked and what it draws. Held to the 400 it was offered, the picture
    // would have grown to 350 and the answer been 175, a height the row it
    // holds never comes to.
    await pump(
      tester,
      Align(
        alignment: Alignment.topLeft,
        child: IntrinsicHeight(
          child: SizedBox(
            key: const ValueKey('held'),
            child: FlexLine(
              children: [
                FlexCell(grow: 1, child: AspectRatio(key: const ValueKey('picture'), aspectRatio: 2)),
                FlexCell(child: box('label', width: 50)),
              ],
            ),
          ),
        ),
      ),
      width: 400,
      height: null,
    );
    expect(sizeOf(tester, 'held'), const Size(70, 10));
    expect(sizeOf(tester, 'picture'), const Size(20, 10));
  });

  testWidgets('a keyword beside a share is the basis where the share is of no length', (tester) async {
    // css-flexbox-1 7.2.3: `flex-basis: 100%` of a column whose length is
    // not a length is `content` -- here nothing -- not the item's own 24.
    // The column above asks the wrap how long it is (24: the empty item and
    // the 24px one), lays it out at 24, and there the share is 24, so the
    // second item starts a second line (`fixtures/flex-column-indefinite-main`
    // case 2).
    Widget wrap({FlexKeyword? keyword}) => FlexLine(
      direction: Axis.vertical,
      children: [
        FlexCell(
          crossSize: 300,
          child: FlexLine(
            key: const ValueKey('wrap'),
            direction: Axis.vertical,
            wrap: true,
            children: [
              FlexCell(shrink: 0, basisFraction: 1, basisKeyword: keyword, mainSize: 24, child: box('a', height: 0)),
              FlexCell(mainSize: 24, child: box('b', height: 0)),
            ],
          ),
        ),
      ],
    );
    await pump(tester, wrap(keyword: FlexKeyword.content), width: 300, height: 200);
    expect(sizeOf(tester, 'wrap'), const Size(300, 24));
    expect(sizeOf(tester, 'a'), const Size(150, 24));
    expect(topLeftOf(tester, 'b'), const Offset(150, 0));
    // A share alone falls back to the item's own length while it is
    // measured: the wrap asks for 48, and the share is all of that.
    await pump(tester, wrap(), width: 300, height: 200);
    expect(sizeOf(tester, 'wrap'), const Size(300, 48));
    expect(sizeOf(tester, 'a'), const Size(150, 48));
  });

  testWidgets('an item the line does not stretch is held by its own floor and cap across it', (tester) async {
    // css-flexbox-1 9.4 step 7: the item is laid out as a block at its
    // length, and the block's own `max-height` holds it however deep its
    // content is. A bookshop's picture: `max-height: 100%` of a cover
    // 220 deep, round an image 225 deep (`fixtures/flex-ratio-depth-share`
    // c1) -- 220, at the foot of the line.
    await pump(
      tester,
      FlexLine(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [FlexCell(mainSizeFraction: 1, crossMaxFraction: 1, child: box('img', height: 225))],
      ),
      width: 144,
      height: 220,
    );
    expect(sizeOf(tester, 'img'), const Size(144, 220));
    expect(topLeftOf(tester, 'img'), Offset.zero);
    // A cap and a floor in pixels, in a line nothing holds.
    await pump(
      tester,
      FlexLine(
        key: const ValueKey('line'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FlexCell(crossMax: 30, child: box('a', width: 50, height: 40)),
          FlexCell(crossMin: 30, child: box('b', width: 50, height: 10)),
        ],
      ),
      height: null,
    );
    expect(sizeOf(tester, 'a'), const Size(50, 30));
    expect(sizeOf(tester, 'b'), const Size(50, 30));
    expect(sizeOf(tester, 'line').height, 30);
    // A share of a depth the line was not handed is no cap at all: the
    // picture keeps its 225.
    await pump(
      tester,
      FlexLine(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [FlexCell(mainSizeFraction: 1, crossMaxFraction: 1, child: box('img', height: 225))],
      ),
      width: 144,
      height: null,
    );
    expect(sizeOf(tester, 'img'), const Size(144, 225));
  });

  group('a percentage margin the item holds inside itself', () {
    // `width: 120px; margin-left: 5%` round a word 40 wide, beside a box
    // that does not shrink: the line is told a box of `calc(120px + 5%)`,
    // the margin's share of it as frame (`fixtures/flex-item-pct-margin-
    // room` n1).
    Widget line({Key? key, double beside = 100}) => FlexLine(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FlexCell(
          mainSize: 120,
          mainSizeFraction: 0.05,
          frameFraction: const EdgeInsets.only(left: 0.05),
          marginFraction: const EdgeInsets.only(left: 0.05),
          child: const Inset(
            insets: EdgeInsets.zero,
            shares: EdgeInsets.only(left: 0.05),
            ofRoom: true,
            child: Words(key: ValueKey('a'), min: 40, max: 60),
          ),
        ),
        FlexCell(
          shrink: 0,
          mainSize: beside,
          child: box('b', width: beside),
        ),
      ],
    );

    testWidgets('comes to nothing where the line is measured, and the pixels stand', (tester) async {
      // A float round the row: the margin is cyclic and resolves against
      // zero (css-sizing-3 5.2.1), and the item contributes its own 120 --
      // not the word, as a share of nothing made of the whole size.
      await pump(tester, Center(child: line(key: const ValueKey('line'))), width: null, height: null);
      final r = tester.renderObject<RenderBox>(find.byKey(const ValueKey('line')));
      expect(r.getMaxIntrinsicWidth(double.infinity), 220);
      expect(r.getMinIntrinsicWidth(double.infinity), 220);
    });

    testWidgets('where the line is offered a length, the item gives way down to its word and the share', (
      tester,
    ) async {
      // 300 wide beside 250: the share is 15, the line 135 + 250 and 85
      // too long -- past what the item can give, which stops at 15 + 40.
      await pump(tester, Inset(insets: EdgeInsets.zero, room: true, child: line(beside: 250)), height: null);
      expect(sizeOf(tester, 'a').width, 40);
      expect(topLeftOf(tester, 'a').dx, 15);
      expect(topLeftOf(tester, 'b').dx, 55);
    });
  });

  group('a ratio', () {
    testWidgets('is of the box inside a percentage margin the item holds', (tester) async {
      // A marketplace's "See all" card: a centring column 200 wide, an item
      // `width: 35%; margin-top: 15.74%; aspect-ratio: 1`. The item is 70
      // square and the margin 31.48 above it; the line sees 101.48 down.
      await pump(
        tester,
        Inset(
          insets: EdgeInsets.zero,
          room: true,
          child: FlexLine(
            key: const ValueKey('line'),
            direction: Axis.vertical,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              FlexCell(
                crossSizeFraction: 0.35,
                ratio: 1,
                frameFraction: const EdgeInsets.only(top: 0.1574),
                marginFraction: const EdgeInsets.only(top: 0.1574),
                child: Inset(
                  insets: EdgeInsets.zero,
                  shares: const EdgeInsets.only(top: 0.1574),
                  ofRoom: true,
                  child: box('a', height: 0),
                ),
              ),
              FlexCell(child: box('b', height: 10)),
            ],
          ),
        ),
        width: 200,
        height: null,
      );
      expect(sizeOf(tester, 'a'), const Size(70, 70));
      expect(topLeftOf(tester, 'a').dy, closeTo(31.48, 1e-6));
      expect(topLeftOf(tester, 'b').dy, closeTo(101.48, 1e-6));
    });

    testWidgets('says the depth from the length the line gave the item', (tester) async {
      await pump(
        tester,
        FlexLine(
          key: const ValueKey('line'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [FlexCell(shrink: 0, mainSize: 144, ratio: 0.6445, child: box('img', height: 10))],
        ),
        height: null,
      );
      expect(sizeOf(tester, 'img').height, closeTo(223.43, 0.01));
      expect(sizeOf(tester, 'line').height, closeTo(223.43, 0.01));
    });

    testWidgets('and its own cap holds that depth, without giving back the length', (tester) async {
      // The bookshop's book covers: 144 wide at 0.6445 is 223.4 deep, and
      // `max-height: 220px` leaves them 144 by 220 -- not 141.8 by 220.
      await pump(
        tester,
        FlexLine(
          key: const ValueKey('line'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [FlexCell(shrink: 0, mainSize: 144, ratio: 0.6445, crossMax: 220, child: box('img', height: 10))],
        ),
        height: null,
      );
      expect(sizeOf(tester, 'img'), const Size(144, 220));
    });

    testWidgets('and its own cap holds the floor its content sets', (tester) async {
      // css-sizing-4 4.3: the automatic minimum a ratio box takes from its
      // content is "capped by its maximum size". The bookshop's covers
      // hold a picture that would be 225 deep at 144 wide, and `max-height:
      // 220px` keeps them 220 (`fixtures/flex-ratio-depth-share` c1).
      await pump(
        tester,
        FlexLine(
          key: const ValueKey('line'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [FlexCell(shrink: 0, mainSize: 144, ratio: 0.6445, crossMax: 220, child: box('img', height: 225))],
        ),
        height: null,
      );
      expect(sizeOf(tester, 'img'), const Size(144, 220));
      // With no cap the content is the floor: 225, past the ratio's 223.4.
      await pump(
        tester,
        FlexLine(
          key: const ValueKey('line'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [FlexCell(shrink: 0, mainSize: 144, ratio: 0.6445, child: box('img', height: 225))],
        ),
        height: null,
      );
      expect(sizeOf(tester, 'img'), const Size(144, 225));
      // A floor the item WRITES still beats its cap.
      await pump(
        tester,
        FlexLine(
          key: const ValueKey('line'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FlexCell(
              shrink: 0,
              mainSize: 144,
              ratio: 0.6445,
              crossMin: 230,
              crossMax: 220,
              child: box('img', height: 10),
            ),
          ],
        ),
        height: null,
      );
      expect(sizeOf(tester, 'img'), const Size(144, 230));
    });

    testWidgets('turns a depth the line knows into the length along it', (tester) async {
      // Stretched to a 120-deep line, an item at 2.0 asks for 240 along it
      // and never measures its child.
      await pump(
        tester,
        FlexLine(
          key: const ValueKey('line'),
          children: [FlexCell(shrink: 0, ratio: 2, child: box('img', height: 10))],
        ),
        width: 600,
        height: 120,
      );
      expect(sizeOf(tester, 'img'), const Size(240, 120));
    });

    testWidgets('is the floor the line shrinks an item to, not its content', (tester) async {
      // §4.5: the automatic minimum is the SMALLER of the content and what
      // the item asked for, and a transferred size is what it asked for.
      await pump(
        tester,
        FlexLine(
          key: const ValueKey('line'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FlexCell(ratio: 0.5, child: const Words(key: ValueKey('a'), min: 80, max: 400)),
            FlexCell(shrink: 0, mainSize: 200, child: box('b', height: 10)),
          ],
        ),
        width: 300,
        height: null,
      );
      // 400 deep at 0.5 is 200 along the line; shrunk into the 100 left, it
      // stops at its content's 80.
      expect(sizeOf(tester, 'a').width, 100);
    });

    testWidgets('the STRETCH is a floor along the line too, and stops the shrink', (tester) async {
      // css-flexbox-1 9.8: a stretched item on a single line the box was
      // given a depth for has a definite cross size, so 4.5's transferred
      // size suggestion is that depth through the ratio -- the automatic
      // minimum, which is what keeps the item from giving the room back.
      await pump(
        tester,
        FlexLine(
          key: const ValueKey('line'),
          children: [FlexCell(ratio: 2, child: box('a', height: 0))],
        ),
        width: 100,
        height: 100,
      );
      expect(sizeOf(tester, 'a'), const Size(200, 100));
    });

    testWidgets('and a floor the page wrote takes the automatic one\'s place', (tester) async {
      // `min-width: 0` is not `auto`: there is nothing to transfer, the
      // item gives the whole line back, and the stretch still holds it to
      // the line's depth.
      await pump(
        tester,
        FlexLine(
          key: const ValueKey('line'),
          children: [FlexCell(ratio: 2, min: 0, child: box('a', height: 0))],
        ),
        width: 100,
        height: 100,
      );
      expect(sizeOf(tester, 'a'), const Size(100, 100));
    });

    testWidgets('a depth the item STATES is a floor along the line too, and it hangs out of a short line', (
      tester,
    ) async {
      // fixtures/flex-hang-rigid: the bookshop's cover frame is `height:
      // 100%; aspect-ratio: 1` of a 105.3 line, centred in a card 38.7
      // wide. A ratio box with a definite depth is that depth through the
      // ratio as its min-content length, whatever it holds -- an empty
      // frame as much as one round a cover -- so it keeps 105.3 and hangs
      // 33.3 off each side.
      Future<void> frame(FlexCell cell) => pump(
        tester,
        FlexLine(
          key: const ValueKey('line'),
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [cell],
        ),
        width: 38.7,
        height: 105.3,
      );
      await frame(FlexCell(crossSize: 105.3, crossMax: 218, ratio: 1, child: box('a', height: 0)));
      expect(
        tester.getRect(find.byKey(const ValueKey('a'))),
        rectMoreOrLessEquals(const Rect.fromLTWH(-33.3, 0, 105.3, 105.3)),
      );
      // Its content a share of its depth (`crossMin: 0`: nothing grows it across), the same.
      await frame(FlexCell(crossSize: 105.3, crossMin: 0, ratio: 1, child: box('a', height: 0)));
      expect(sizeOf(tester, 'a'), const Size(105.3, 105.3));
      // NEGATIVE: `min-width: 0` writes the floor, and the frame shrinks to its line (g6).
      await frame(FlexCell(crossSize: 105.3, min: 0, ratio: 1, child: box('a', height: 0)));
      expect(sizeOf(tester, 'a'), const Size(38.7, 105.3));
      // NEGATIVE: one that clips has no automatic minimum at all.
      await frame(FlexCell(crossSize: 105.3, clips: true, ratio: 1, child: box('a', height: 0)));
      expect(sizeOf(tester, 'a'), const Size(38.7, 105.3));
    });

    testWidgets('and the item\'s own cap holds the stretched floor down', (tester) async {
      // 4.5 clamps every reading of the automatic minimum by the cap along
      // the line: 100 deep at 2 transfers 200, and a `max-width: 40px`
      // item is 40.
      await pump(
        tester,
        FlexLine(
          key: const ValueKey('line'),
          children: [FlexCell(ratio: 2, max: 40, child: box('a', height: 0))],
        ),
        width: 100,
        height: 100,
      );
      expect(sizeOf(tester, 'a'), const Size(40, 100));
    });

    testWidgets('across the line is a floor along it, where the item states no length', (tester) async {
      // css-sizing-4 5.1: an empty `aspect-ratio: 2` item the line does not
      // stretch has nothing to be 60 wide FROM except its own
      // `min-height: 30px`, transferred.
      await pump(
        tester,
        FlexLine(
          key: const ValueKey('line'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FlexCell(ratio: 2, crossMin: 30, child: box('a', height: 0)),
            FlexCell(shrink: 0, mainSize: 20, child: box('b', height: 8)),
          ],
        ),
        width: 260,
        height: 100,
      );
      expect(sizeOf(tester, 'a'), const Size(60, 30));
      expect(topLeftOf(tester, 'b').dx, 60);
    });

    testWidgets('across the line is one floor more, not one instead', (tester) async {
      // `min-width` is still `auto` with a `min-height` transferred beside
      // it, and the content still answers: a 100-deep item whose content
      // is 200 long at that depth does not shrink to the 100 of room the
      // line has, though its transferred floor is only 80.
      await pump(
        tester,
        FlexLine(
          key: const ValueKey('line'),
          children: [
            FlexCell(
              crossMin: 40,
              ratio: 2,
              child: ConstrainedBox(
                key: const ValueKey('a'),
                constraints: const BoxConstraints(minWidth: 80, minHeight: 40),
                child: const AspectRatio(aspectRatio: 2, child: SizedBox.expand()),
              ),
            ),
          ],
        ),
        width: 100,
        height: 100,
      );
      expect(sizeOf(tester, 'a'), const Size(200, 100));
    });

    testWidgets('never asks the line for more room than the item may take', (tester) async {
      // A clipping item contributes its base size and measures nothing, but
      // a cap is still a cap: at 0.8 a 300-wide column item wants 375 and
      // `max-height: 364px` holds the LINE to 364 as well as the item.
      await pump(
        tester,
        FlexLine(
          key: const ValueKey('line'),
          direction: Axis.vertical,
          children: [
            FlexCell(crossSizeFraction: 1, min: 0, max: 364, ratio: 0.8, clips: true, child: box('a', height: 10)),
          ],
        ),
        width: 300,
        height: null,
      );
      expect(sizeOf(tester, 'a'), const Size(300, 364));
      expect(sizeOf(tester, 'line'), const Size(300, 364));
    });

    testWidgets('down a column says the length from the width the line holds it to', (tester) async {
      await pump(
        tester,
        FlexLine(
          key: const ValueKey('line'),
          direction: Axis.vertical,
          children: [FlexCell(shrink: 0, ratio: 2, child: box('img', height: 10))],
        ),
        width: 300,
        height: null,
      );
      expect(sizeOf(tester, 'img'), const Size(300, 150));
    });
  });

  group('a line that wraps', () {
    testWidgets('gives the box outside it the FIRST line\'s baseline', (tester) async {
      // css-flexbox-1 8.5: a flex container's first baseline comes from
      // its FIRST flex line, so an `align-self: baseline` down on the
      // second line is none of the outer line's business. Taffy's
      // flex_align_baseline_child_multiline_no_override_on_secondline: a
      // 50x60 box and a 50x25 wrapping box on one baseline; the wrapping
      // box's first line is 20 deep, so it hangs 60 - 20 = 40 down.
      await pump(
        tester,
        FlexLine(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          children: [
            FlexCell(mainSize: 50, crossSize: 60, child: box('tall', height: 60)),
            FlexCell(
              mainSize: 50,
              crossSize: 25,
              child: FlexLine(
                key: const ValueKey('inner'),
                wrap: true,
                children: [
                  FlexCell(mainSize: 25, crossSize: 20, child: box('a', height: 20)),
                  FlexCell(mainSize: 25, crossSize: 10, child: box('b')),
                  FlexCell(mainSize: 25, crossSize: 20, child: box('c', height: 20)),
                  FlexCell(mainSize: 25, crossSize: 10, align: CrossAxisAlignment.baseline, child: box('d')),
                ],
              ),
            ),
          ],
        ),
        width: 100,
        height: null,
      );
      expect(topLeftOf(tester, 'tall').dy, 0);
      expect(topLeftOf(tester, 'inner').dy, 40);
      expect(topLeftOf(tester, 'a').dy, 40);
      expect(topLeftOf(tester, 'c').dy, 60);
      expect(topLeftOf(tester, 'd').dy, 60);
    });

    testWidgets('breaks where the next item would not fit, and flexes each line on its own', (tester) async {
      // Three 120-wide items in 300: two on the first line, one on the
      // second. The two that share a line shrink into it; the one alone
      // does not.
      await pump(
        tester,
        FlexLine(
          key: const ValueKey('line'),
          wrap: true,
          children: [
            FlexCell(basis: 120, child: box('a', height: 10)),
            FlexCell(basis: 120, child: box('b', height: 10)),
            FlexCell(basis: 120, child: box('c', height: 10)),
          ],
        ),
        width: 300,
        height: null,
      );
      expect(sizeOf(tester, 'a').width, 120);
      expect(topLeftOf(tester, 'b').dx, 120);
      expect(topLeftOf(tester, 'c'), const Offset(0, 10));
      expect(sizeOf(tester, 'line').height, 20);
    });

    testWidgets('counts the hypothetical size, not what the line shrank it to', (tester) async {
      // css-flexbox-1 9.3 step 5 breaks on the size the item ASKED for.
      // Two items of 200 do not fit 300 together, though both would shrink
      // to 150.
      await pump(
        tester,
        FlexLine(
          key: const ValueKey('line'),
          wrap: true,
          children: [
            FlexCell(basis: 200, child: box('a', height: 10)),
            FlexCell(basis: 200, child: box('b', height: 10)),
          ],
        ),
        width: 300,
        height: null,
      );
      expect(sizeOf(tester, 'a').width, 200);
      expect(topLeftOf(tester, 'b'), const Offset(0, 10));
    });

    testWidgets('keeps an item that fits nowhere on a line of its own', (tester) async {
      await pump(
        tester,
        FlexLine(
          key: const ValueKey('line'),
          wrap: true,
          children: [
            FlexCell(shrink: 0, mainSize: 400, child: box('a', height: 10)),
            FlexCell(shrink: 0, mainSize: 80, child: box('b', height: 10)),
          ],
        ),
        width: 300,
        height: null,
      );
      expect(sizeOf(tester, 'a').width, 400);
      expect(topLeftOf(tester, 'b'), const Offset(0, 10));
    });

    testWidgets('fits five fifths on one line, in layout units', (tester) async {
      // 20% of 464 is 92.80000000000001 as a double and five of them
      // 464.00000000000006; Blink's 1/64 px units hold 92.796875 and five
      // fit (fixtures/flex-wrap-fifths w1 is the same at 928).
      await pump(
        tester,
        FlexLine(
          key: const ValueKey('line'),
          wrap: true,
          children: [
            for (final k in 'abcde'.split('')) FlexCell(shrink: 0, basisFraction: 0.2, child: box(k, height: 10)),
          ],
        ),
        width: 464,
        height: null,
      );
      expect(topLeftOf(tester, 'e').dy, 0);
      expect(sizeOf(tester, 'line').height, 10);
    });

    testWidgets('still wraps five fifths a quarter pixel too long', (tester) async {
      // fixtures/flex-wrap-fifths n1: 5 x 93.046875 is 465.23 of 464.
      await pump(
        tester,
        FlexLine(
          key: const ValueKey('line'),
          wrap: true,
          children: [
            for (final k in 'abcde'.split(''))
              FlexCell(shrink: 0, basis: 0.25, basisFraction: 0.2, child: box(k, height: 10)),
          ],
        ),
        width: 464,
        height: null,
      );
      expect(topLeftOf(tester, 'd').dy, 0);
      expect(topLeftOf(tester, 'e'), const Offset(0, 10));
    });

    testWidgets('puts a gap between the lines and none above or below', (tester) async {
      await pump(
        tester,
        FlexLine(
          key: const ValueKey('line'),
          wrap: true,
          spacing: 10,
          runSpacing: 16,
          children: [
            FlexCell(shrink: 0, mainSize: 160, child: box('a', height: 10)),
            FlexCell(shrink: 0, mainSize: 160, child: box('b', height: 12)),
          ],
        ),
        width: 300,
        height: null,
      );
      expect(topLeftOf(tester, 'b'), const Offset(0, 26));
      expect(sizeOf(tester, 'line').height, 38);
    });

    testWidgets('shares the room left over among the lines, as align-content does', (tester) async {
      // `align-content: stretch` is CSS's default: two lines in a 100-deep
      // box are 50 each, and a stretched item is as deep as its line.
      await pump(
        tester,
        FlexLine(
          key: const ValueKey('line'),
          wrap: true,
          children: [
            FlexCell(shrink: 0, mainSize: 200, child: box('a', height: 10)),
            FlexCell(shrink: 0, mainSize: 200, child: box('b', height: 10)),
          ],
        ),
        width: 300,
        height: 100,
      );
      expect(sizeOf(tester, 'a').height, 50);
      expect(topLeftOf(tester, 'b'), const Offset(0, 50));
    });

    testWidgets('is multi-line whatever it came to, so one line is not the box', (tester) async {
      // `flex-wrap` is what makes a box multi-line, not the number of lines
      // it came to (css-flexbox-1 8.4). A column of five 10-deep items in
      // 100 is ONE line 50 wide, and `align-content: end` puts it at the
      // right end -- where a box that does not wrap would have stretched it
      // to the whole 100.
      await pump(
        tester,
        FlexLine(
          key: const ValueKey('line'),
          direction: Axis.vertical,
          wrap: true,
          alignContent: WrapAlignment.end,
          children: [
            for (var i = 0; i < 5; i++) FlexCell(shrink: 0, mainSize: 10, crossSize: 50, child: box('$i', height: 10)),
          ],
        ),
        width: 100,
        height: 100,
      );
      expect(sizeOf(tester, '0').width, 50);
      expect(topLeftOf(tester, '0').dx, 50);
      // And its line keeps the depth its items gave it even where that is
      // MORE than the box: a 150-deep item in a box of 100 hangs out of it,
      // where a single-line box would have held it to 100.
      await pump(
        tester,
        FlexLine(
          key: const ValueKey('line'),
          wrap: true,
          children: [FlexCell(shrink: 0, mainSize: 100, child: box('a', height: 150))],
        ),
        width: 150,
        height: 100,
      );
      expect(sizeOf(tester, 'a').height, 150);
    });

    testWidgets('packs the lines where align-content says, at the depth they came to', (tester) async {
      // Anything but `normal`/`stretch` leaves the lines the depth their
      // items gave them (10 each) and puts the 80 left over round them, the
      // way `justify-content` puts the room along a line round its items
      // (css-flexbox-1 9.6 step 15, css-align-3 5.3).
      const where = {
        WrapAlignment.start: (0.0, 10.0),
        WrapAlignment.end: (80.0, 90.0),
        WrapAlignment.center: (40.0, 50.0),
        WrapAlignment.spaceBetween: (0.0, 90.0),
        WrapAlignment.spaceAround: (20.0, 70.0),
      };
      for (final MapEntry(key: how, value: (a, b)) in where.entries) {
        await pump(
          tester,
          FlexLine(
            key: const ValueKey('line'),
            wrap: true,
            alignContent: how,
            children: [
              FlexCell(shrink: 0, mainSize: 200, child: box('a', height: 10)),
              FlexCell(shrink: 0, mainSize: 200, child: box('b', height: 10)),
            ],
          ),
          width: 300,
          height: 100,
        );
        expect(sizeOf(tester, 'a').height, 10, reason: '$how');
        expect(topLeftOf(tester, 'a').dy, a, reason: '$how');
        expect(topLeftOf(tester, 'b').dy, b, reason: '$how');
      }
      // Room that is not there is never taken back: two lines of 60 in a
      // box of 100 hang out of it, half above and half below at `center`.
      await pump(
        tester,
        FlexLine(
          key: const ValueKey('line'),
          wrap: true,
          alignContent: WrapAlignment.center,
          children: [
            FlexCell(shrink: 0, mainSize: 200, child: box('a', height: 60)),
            FlexCell(shrink: 0, mainSize: 200, child: box('b', height: 60)),
          ],
        ),
        width: 300,
        height: 100,
      );
      expect(topLeftOf(tester, 'a').dy, -10);
      expect(topLeftOf(tester, 'b').dy, 50);
    });

    testWidgets('is as wide as its widest item when nothing else says how wide', (tester) async {
      // A wrapping line never has to hold two items side by side, so the
      // least room it needs is its widest item's, not all of them added up.
      await pump(
        tester,
        FlexLine(
          key: const ValueKey('line'),
          wrap: true,
          children: [
            FlexCell(shrink: 0, mainSize: 120, child: box('a', height: 10)),
            FlexCell(shrink: 0, mainSize: 80, child: box('b', height: 10)),
          ],
        ),
        width: 300,
        height: null,
      );
      final line = tester.renderObject<RenderBox>(find.byKey(const ValueKey('line')));
      expect(line.getMinIntrinsicWidth(double.infinity), 120);
      // All of them on one line is still what it WANTS to be.
      expect(line.getMaxIntrinsicWidth(double.infinity), 200);
    });
  });

  group('a compressible picture', () {
    // `width: 400px; max-width: 100%` on a picture in a flex `<a>`, the panel
    // round it in a row that has to shrink (fixtures/flex-shrink-picture-
    // length-capped): its share is of nothing when the line is asked its
    // least length (css-sizing-3 5.2.2), and its automatic minimum -- 120,
    // under the same cap -- with it.
    Widget pictures({required bool compressible}) => FlexLine(
      key: const ValueKey('line'),
      children: [
        FlexCell(
          mainSize: 400,
          min: 120,
          minCapFraction: 1,
          maxFraction: 1,
          compressible: compressible,
          child: box('pic', height: 120),
        ),
      ],
    );

    testWidgets('gives up all its length to the least the line needs', (tester) async {
      await pump(tester, pictures(compressible: true), width: 300, height: null);
      final line = tester.renderObject<RenderBox>(find.byKey(const ValueKey('line')));
      expect(line.getMinIntrinsicWidth(double.infinity), 0);
      // What it wants is still its 400.
      expect(line.getMaxIntrinsicWidth(double.infinity), 400);
    });

    testWidgets('and a row shrinks the box it is in past it', (tester) async {
      // Its 400 is the panel's basis; a 300 row of a 300 item beside it
      // shrinks both by their bases: the panel to 300 - 300 * 400 / 700.
      await pump(
        tester,
        FlexLine(
          children: [
            FlexCell(mainSize: 300, child: box('links')),
            ShrinkWidth(key: const ValueKey('panel'), child: pictures(compressible: true)),
          ],
        ),
        width: 300,
        height: null,
      );
      expect(sizeOf(tester, 'panel').width, closeTo(400 - 400 * 400 / 700, 1e-9));
      expect(sizeOf(tester, 'pic').width, closeTo(400 - 400 * 400 / 700, 1e-9));
    });

    testWidgets('NEGATIVE: a box that is no picture floors the line at its length', (tester) async {
      await pump(tester, pictures(compressible: false), width: 300, height: null);
      final line = tester.renderObject<RenderBox>(find.byKey(const ValueKey('line')));
      expect(line.getMinIntrinsicWidth(double.infinity), 400);
    });

    testWidgets('NEGATIVE: laid out, the picture is its length under its cap', (tester) async {
      await pump(tester, pictures(compressible: true), width: 300, height: null);
      expect(sizeOf(tester, 'pic').width, 300);
      await pump(tester, pictures(compressible: true), width: 500, height: null);
      expect(sizeOf(tester, 'pic').width, 400);
    });
  });

  group('a relative shift', () {
    testWidgets('is a share of the line\'s width, and the room stays where it was', (tester) async {
      // `position: relative; left: 50%` on an item of a 300px row moves its
      // drawing 150px (CSS 2.1 9.4.3) and nothing after it.
      await pump(
        tester,
        FlexLine(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FlexCell(shiftLeftFraction: 0.5, child: box('a', width: 40)),
            box('b', width: 40),
          ],
        ),
      );
      expect(topLeftOf(tester, 'a'), const Offset(150, 0));
      expect(topLeftOf(tester, 'b'), const Offset(40, 0));
    });

    testWidgets('down is a share of a height the line was handed, and nothing of one it was not', (tester) async {
      // `top: 50%` in a line held 50 deep is 25 down; in a line as deep as
      // its content the height is not definite and the offset is `auto`
      // (css-position-3 3.1).
      Widget line() => FlexLine(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [FlexCell(shiftTopFraction: 0.5, child: box('a', width: 40, height: 20))],
      );
      await pump(tester, line());
      expect(topLeftOf(tester, 'a'), const Offset(0, 25));
      await pump(tester, line(), height: null);
      expect(topLeftOf(tester, 'a'), Offset.zero);
    });
  });

  group('a percentage frame', () {
    testWidgets('is a share of the line\'s width, and the line shrinks the content box', (tester) async {
      // Two 200 bases in 300: 150 each where neither is framed. With half
      // the line's width (150) as the first one's padding, its content box
      // is 50 and the second's 200, so the 100 of overflow is shared 1:4
      // (css-flexbox-1 9.7): 180 and 120.
      await pump(
        tester,
        FlexLine(
          children: [
            FlexCell(basis: 200, frameFraction: const EdgeInsets.only(left: 0.5), child: box('a')),
            FlexCell(basis: 200, child: box('b')),
          ],
        ),
      );
      expect(sizeOf(tester, 'a').width, 180);
      expect(sizeOf(tester, 'b').width, 120);
    });

    testWidgets('is nothing while the line is working its width out', (tester) async {
      // Asked its width, the line has none to take a share of: the share is
      // cyclic and resolves against zero (css-sizing-3 5.2.1).
      await pump(
        tester,
        FlexLine(
          key: const ValueKey('line'),
          children: [FlexCell(frameFraction: const EdgeInsets.only(left: 0.5), child: box('a', width: 40))],
        ),
      );
      final line = tester.renderObject<RenderBox>(find.byKey(const ValueKey('line')));
      expect(line.getMaxIntrinsicWidth(double.infinity), 40);
    });
  });

  group('a keyword', () {
    Widget words({double min = 40, double max = 200}) => Words(key: const ValueKey('w'), min: min, max: max);

    testWidgets('as a basis is what the child measures at', (tester) async {
      Future<double> basis(FlexKeyword k, {double? width = 300, EdgeInsets margin = EdgeInsets.zero}) async {
        await pump(
          tester,
          FlexLine(
            children: [FlexCell(shrink: 0, basisKeyword: k, margin: margin, child: words())],
          ),
          width: width,
        );
        return sizeOf(tester, 'w').width;
      }

      expect(await basis(FlexKeyword.minContent), 40);
      expect(await basis(FlexKeyword.maxContent), 200);
      // `fit-content` is the content in the room there is: 200 in 300, the
      // room in 100, never under the longest word.
      expect(await basis(FlexKeyword.fitContent), 200);
      expect(await basis(FlexKeyword.fitContent, width: 100), 100);
      expect(await basis(FlexKeyword.fitContent, width: 30), 40);
      // `stretch` is the line's whole length less the margins.
      expect(await basis(FlexKeyword.stretch, margin: const EdgeInsets.only(left: 20)), 280);
    });

    testWidgets('as a basis leaves the item\'s own length out of the question', (tester) async {
      // `flex-basis: content` on a `width: 50px` item starts it from its
      // content, 200, where `auto` would retrieve the 50.
      await pump(
        tester,
        FlexLine(
          children: [FlexCell(shrink: 0, mainSize: 50, basisKeyword: FlexKeyword.content, child: words())],
        ),
      );
      expect(sizeOf(tester, 'w').width, 200);
    });

    testWidgets('that needs a length the line was not handed is the content', (tester) async {
      // A line asked its width has no length for `fit-content` or `stretch`
      // to read, and they answer with the content.
      await pump(
        tester,
        FlexLine(
          key: const ValueKey('line'),
          children: [FlexCell(basisKeyword: FlexKeyword.stretch, child: words())],
        ),
      );
      final line = tester.renderObject<RenderBox>(find.byKey(const ValueKey('line')));
      expect(line.getMaxIntrinsicWidth(double.infinity), 200);
    });

    testWidgets('as a minimum or a maximum is the child\'s measurement', (tester) async {
      // `max-width: min-content` holds a growing item at its longest word
      // and hands the rest to its sibling; `min-width: max-content` keeps an
      // item whole in a line too short for it.
      await pump(
        tester,
        FlexLine(
          children: [
            FlexCell(basis: 0, grow: 1, maxKeyword: FlexKeyword.minContent, child: words(min: 60, max: 100)),
            FlexCell(basis: 0, grow: 1, child: box('b')),
          ],
        ),
        width: 240,
      );
      expect(sizeOf(tester, 'w').width, 60);
      expect(sizeOf(tester, 'b').width, 180);

      await pump(
        tester,
        FlexLine(
          children: [FlexCell(minKeyword: FlexKeyword.maxContent, child: words())],
        ),
        width: 100,
      );
      expect(sizeOf(tester, 'w').width, 200);
    });

    testWidgets('fit-content or stretch as a minimum reads the line\'s length, and beats a cap', (tester) async {
      // A product site's "Get started for free": `width: 100%; max-width: 200px;
      // min-width: fit-content` round a line of 220 -- its max-content in
      // the room, past the cap (css-sizing-3 5.1, css-flexbox-1 7.2.3).
      Future<double> width(FlexKeyword k, double room) async {
        await pump(
          tester,
          FlexLine(
            wrap: true,
            children: [FlexCell(mainSizeFraction: 1, max: 200, minKeyword: k, child: words(min: 60, max: 220))],
          ),
          width: room,
        );
        return sizeOf(tester, 'w').width;
      }

      expect(await width(FlexKeyword.fitContent, 400), 220);
      expect(await width(FlexKeyword.stretch, 400), 400);
      // NEGATIVE: in less room than its line, fit-content is the room.
      expect(await width(FlexKeyword.fitContent, 150), 150);
      // And as a maximum, a share of the whole line is held to its content.
      await pump(
        tester,
        FlexLine(
          children: [
            FlexCell(mainSizeFraction: 1, maxKeyword: FlexKeyword.fitContent, child: words(min: 60, max: 220)),
          ],
        ),
        width: 400,
      );
      expect(sizeOf(tester, 'w').width, 220);
    });
  });

  group('a percentage gap', () {
    testWidgets('is a share of the length the line was handed, and nothing of one it was not', (tester) async {
      // `column-gap: 10%` in a 300px row is 30; asked its width, the row
      // has none and the gap is cyclic -- zero (css-align-3 8.3).
      await pump(
        tester,
        FlexLine(
          key: const ValueKey('line'),
          spacingFraction: 0.1,
          children: [box('a', width: 40), box('b', width: 40)],
        ),
      );
      expect(topLeftOf(tester, 'b').dx, 70);
      final line = tester.renderObject<RenderBox>(find.byKey(const ValueKey('line')));
      expect(line.getMaxIntrinsicWidth(double.infinity), 80);
    });

    testWidgets('along a row whose content settles its width is a share of that width', (tester) async {
      // The row is the 80 its two items come to, the gap nothing while that
      // is worked out -- and then 10% of the 80 it came to, which the two
      // items overflow by (css-align-3 8.3).
      await pump(
        tester,
        FlexLine(spacingFraction: 0.1, children: [box('a', width: 40), box('b', width: 40)]),
        width: null,
      );
      expect(topLeftOf(tester, 'b').dx, 48);
    });
  });

  group('lines from the far side', () {
    testWidgets('stack up from the bottom, and `start` is each line\'s bottom edge', (tester) async {
      // `flex-wrap: wrap-reverse` in a box 100 wide and 100 deep: a (60) is
      // a line of its own, b (60 by 20) and c (30) the next. `align-content:
      // flex-start` packs the lines at the bottom, the first one written
      // lowest, and `align-items: flex-start` puts c at the bottom of its
      // line (css-flexbox-1 5.2).
      Widget line({WrapAlignment? content}) => FlexLine(
        wrap: true,
        reverseLines: true,
        crossAxisAlignment: CrossAxisAlignment.start,
        alignContent: content,
        children: [box('a', width: 60), box('b', width: 60, height: 20), box('c', width: 30)],
      );
      await pump(tester, line(content: WrapAlignment.start), width: 100, height: 100);
      expect(topLeftOf(tester, 'a'), const Offset(0, 90));
      expect(topLeftOf(tester, 'b'), const Offset(0, 70));
      expect(topLeftOf(tester, 'c'), const Offset(60, 80));
      // `stretch` shares the 70 left over between the two lines, 35 each,
      // and each item still sits at its line's bottom edge.
      await pump(tester, line(), width: 100, height: 100);
      expect(topLeftOf(tester, 'a'), const Offset(0, 90));
      expect(topLeftOf(tester, 'b'), const Offset(0, 35));
      expect(topLeftOf(tester, 'c'), const Offset(60, 45));
    });

    testWidgets('pack a baseline group down against the line\'s bottom edge', (tester) async {
      // A 10-deep word (baseline 8) and a 30-deep box (baseline its bottom)
      // share a baseline in a line 50 deep, which c makes. Packed down, the
      // word -- 2 below its baseline, the furthest -- touches the bottom:
      // it is 40 down and the box 18.
      await pump(
        tester,
        FlexLine(
          wrap: true,
          reverseLines: true,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          children: [
            const Words(key: ValueKey('w'), min: 40, max: 40),
            box('b', width: 20, height: 30),
            FlexCell(align: CrossAxisAlignment.start, child: box('c', width: 20, height: 50)),
          ],
        ),
      );
      expect(topLeftOf(tester, 'w').dy, 40);
      expect(topLeftOf(tester, 'b').dy, 18);
      expect(topLeftOf(tester, 'c').dy, 0);
    });
  });

  group('right to left', () {
    testWidgets('a row runs from its right edge, and a reversed one from its left', (tester) async {
      Future<void> row({bool reverse = false, MainAxisAlignment main = MainAxisAlignment.start}) => pump(
        tester,
        FlexLine(
          textDirection: TextDirection.rtl,
          reverse: reverse,
          mainAxisAlignment: main,
          children: [box('a', width: 40), box('b', width: 60)],
        ),
      );
      await row();
      expect(topLeftOf(tester, 'a').dx, 260);
      expect(topLeftOf(tester, 'b').dx, 200);
      // `flex-end` is the left edge.
      await row(main: MainAxisAlignment.end);
      expect(topLeftOf(tester, 'b').dx, 0);
      expect(topLeftOf(tester, 'a').dx, 60);
      await row(reverse: true);
      expect(topLeftOf(tester, 'a').dx, 0);
      expect(topLeftOf(tester, 'b').dx, 40);
    });

    testWidgets('a column puts `start` at its right edge, and stacks its lines from there', (tester) async {
      await pump(
        tester,
        FlexLine(
          direction: Axis.vertical,
          textDirection: TextDirection.rtl,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [box('a', width: 40), box('b', width: 60)],
        ),
      );
      expect(topLeftOf(tester, 'a'), const Offset(260, 0));
      expect(topLeftOf(tester, 'b'), const Offset(240, 10));
      // A stretched item that states a width cannot stretch, and is
      // aligned as `start` is.
      await pump(
        tester,
        FlexLine(
          direction: Axis.vertical,
          textDirection: TextDirection.rtl,
          children: [
            FlexCell(crossSize: 60, child: box('a', width: 60)),
            box('b'),
          ],
        ),
      );
      expect(topLeftOf(tester, 'a'), const Offset(240, 0));
      expect(sizeOf(tester, 'b').width, 300);
      // Two lines of one 40-wide item each in a column 50 deep: the first
      // line at the right edge, the second beside it to the left.
      await pump(
        tester,
        FlexLine(
          direction: Axis.vertical,
          wrap: true,
          textDirection: TextDirection.rtl,
          alignContent: WrapAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [box('a', width: 40, height: 30), box('b', width: 40, height: 30)],
        ),
      );
      expect(topLeftOf(tester, 'a'), const Offset(260, 0));
      expect(topLeftOf(tester, 'b'), const Offset(220, 0));
    });
  });

  group('a safe alignment', () {
    testWidgets('along the line holds while the items fit, and starts them where they do not', (tester) async {
      Future<void> row(double width, {bool safe = true, TextDirection dir = TextDirection.ltr}) => pump(
        tester,
        FlexLine(
          mainAxisAlignment: MainAxisAlignment.end,
          safeMainAxis: safe,
          textDirection: dir,
          children: [FlexCell(shrink: 0, child: box('a', width: width))],
        ),
        width: 100,
      );
      await row(60);
      expect(topLeftOf(tester, 'a').dx, 40);
      await row(160);
      expect(topLeftOf(tester, 'a').dx, 0);
      await row(160, safe: false);
      expect(topLeftOf(tester, 'a').dx, -60);
      // Right to left the start of the axis is the right edge.
      await row(160, dir: TextDirection.rtl);
      expect(topLeftOf(tester, 'a').dx, -60);
    });

    testWidgets('across the line puts an item deeper than its line at the start', (tester) async {
      await pump(
        tester,
        FlexLine(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FlexCell(align: CrossAxisAlignment.end, safe: true, child: box('a', width: 20, height: 200)),
            FlexCell(align: CrossAxisAlignment.end, child: box('b', width: 20, height: 200)),
            FlexCell(align: CrossAxisAlignment.end, safe: true, child: box('c', width: 20, height: 20)),
          ],
        ),
      );
      expect(topLeftOf(tester, 'a').dy, 0);
      expect(topLeftOf(tester, 'b').dy, -150);
      expect(topLeftOf(tester, 'c').dy, 30);
      // A column's cross axis starts at its right edge under `rtl`: a
      // 400-wide item in 300 hangs out of the left.
      await pump(
        tester,
        FlexLine(
          direction: Axis.vertical,
          textDirection: TextDirection.rtl,
          crossAxisAlignment: CrossAxisAlignment.center,
          safeCrossAxis: true,
          children: [box('a', width: 400)],
        ),
      );
      expect(topLeftOf(tester, 'a').dx, -100);
    });
  });

  group('a balanced wrap', () {
    testWidgets('divides its items so the lines are alike, not as they come', (tester) async {
      // css-flexbox-2 5.2: 100, 100, 100 and 50 in 300. Plain wrapping puts
      // three on the first line and 50 alone on the second; balanced, the
      // same two lines are 200 and 150 -- the least sum of squares.
      Widget line({bool balance = true}) => FlexLine(
        key: const ValueKey('line'),
        wrap: true,
        balance: balance,
        children: [box('a', width: 100), box('b', width: 100), box('c', width: 100), box('d', width: 50)],
      );
      await pump(tester, line(balance: false), width: 300, height: null);
      expect(topLeftOf(tester, 'c'), const Offset(200, 0));
      expect(topLeftOf(tester, 'd'), const Offset(0, 10));
      await pump(tester, line(), width: 300, height: null);
      expect(topLeftOf(tester, 'c'), const Offset(0, 10));
      expect(topLeftOf(tester, 'd'), const Offset(100, 10));
      expect(sizeOf(tester, 'line').height, 20);
    });

    testWidgets('makes its line count where that is more, and no more lines than items', (tester) async {
      // Five 60s fit 300 on one line; `flex-line-count: 3` makes three, two
      // items on each of the first two -- the ties go to the earliest
      // lines. Nine lines of three items are three lines of one.
      await pump(
        tester,
        FlexLine(
          wrap: true,
          balance: true,
          lineCount: 3,
          children: [
            for (final k in ['a', 'b', 'c', 'd', 'e']) box(k, width: 60),
          ],
        ),
        width: 300,
        height: null,
      );
      expect(topLeftOf(tester, 'b'), const Offset(60, 0));
      expect(topLeftOf(tester, 'c'), const Offset(0, 10));
      expect(topLeftOf(tester, 'd'), const Offset(60, 10));
      expect(topLeftOf(tester, 'e'), const Offset(0, 20));
      await pump(
        tester,
        FlexLine(
          wrap: true,
          balance: true,
          lineCount: 9,
          children: [
            for (final k in ['a', 'b', 'c']) box(k, width: 60),
          ],
        ),
        width: 300,
        height: null,
      );
      expect(topLeftOf(tester, 'b'), const Offset(0, 10));
      expect(topLeftOf(tester, 'c'), const Offset(0, 20));
    });

    testWidgets('keeps an item of no length at the end of the line before it', (tester) async {
      await pump(
        tester,
        FlexLine(
          wrap: true,
          balance: true,
          lineCount: 2,
          children: [box('a', width: 150), box('z', width: 0), box('b', width: 150)],
        ),
        width: 300,
        height: null,
      );
      expect(topLeftOf(tester, 'z'), const Offset(150, 0));
      expect(topLeftOf(tester, 'b'), const Offset(0, 10));
    });

    testWidgets('down a column with no height, is as tall as its tallest line', (tester) async {
      // Nothing stops the lines, so the count is the line count's: three
      // 30-deep items over two lines, two and one, and the column is the
      // 60 of the first. The second line starts past the first's 120 and
      // the 10 between them.
      await pump(
        tester,
        FlexLine(
          key: const ValueKey('line'),
          direction: Axis.vertical,
          wrap: true,
          balance: true,
          lineCount: 2,
          runSpacing: 10,
          crossAxisAlignment: CrossAxisAlignment.start,
          alignContent: WrapAlignment.start,
          children: [
            for (final k in ['a', 'b', 'c']) box(k, width: 120, height: 30),
          ],
        ),
        width: 300,
        height: null,
      );
      expect(sizeOf(tester, 'line').height, 60);
      expect(topLeftOf(tester, 'b'), const Offset(0, 30));
      expect(topLeftOf(tester, 'c'), const Offset(130, 0));
    });

    testWidgets('is as long as its longest balanced line, asked its max-content length', (tester) async {
      // Three 50s and a 10 gap over two lines: 110 and 50, so the box
      // wants 110 and not the 170 of all three.
      await pump(
        tester,
        FlexLine(
          key: const ValueKey('line'),
          wrap: true,
          balance: true,
          lineCount: 2,
          spacing: 10,
          children: [
            for (final k in ['a', 'b', 'c']) box(k, width: 50),
          ],
        ),
      );
      final line = tester.renderObject<RenderBox>(find.byKey(const ValueKey('line')));
      expect(line.getMaxIntrinsicWidth(double.infinity), 110);
      expect(line.getMinIntrinsicWidth(double.infinity), 50);
    });

    testWidgets('shares the room across the box among its line count', (tester) async {
      // css-flexbox-2 6.1: a column 220 wide of two lines 20 apart gives
      // each line 100, and a paragraph 100 to 200 wide wraps at 100 -- two
      // lines of 30 -- so the second column starts at 120.
      Future<void> column({double width = 220, double gap = 20, double? crossSize, bool balance = true}) => pump(
        tester,
        FlexLine(
          direction: Axis.vertical,
          wrap: true,
          balance: balance,
          lineCount: 2,
          runSpacing: gap,
          crossAxisAlignment: CrossAxisAlignment.start,
          alignContent: WrapAlignment.start,
          children: [
            FlexCell(
              crossSize: crossSize,
              child: const Words(key: ValueKey('w'), min: 100, max: 200, line: 30),
            ),
            box('b', width: 40, height: 50),
          ],
        ),
        width: width,
        height: 120,
      );
      await column();
      expect(sizeOf(tester, 'w'), const Size(100, 60));
      expect(topLeftOf(tester, 'b'), const Offset(120, 0));
      // A width the item states is the width it is measured at.
      await column(crossSize: 160);
      expect(sizeOf(tester, 'w'), const Size(160, 60));
      expect(topLeftOf(tester, 'b'), const Offset(180, 0));
      // Gaps wider than the box leave nothing to share: the room is not
      // divided and the paragraph stands on one line, 200 wide.
      await column(width: 300, gap: 340);
      expect(sizeOf(tester, 'w'), const Size(200, 30));
      expect(topLeftOf(tester, 'b'), const Offset(540, 0));
      // A box that wraps without balancing shares nothing: the paragraph
      // has the whole 220, and the two items fit one line of the 120.
      await column(balance: false);
      expect(sizeOf(tester, 'w'), const Size(200, 30));
      expect(topLeftOf(tester, 'b'), const Offset(0, 30));
    });

    testWidgets('leaves a share of the box\'s depth a share of the whole of it', (tester) async {
      // A row 120 deep of two lines: `height: 50%` is 60, as it is where
      // nothing is shared, and a ratio of 1 makes it 60 wide.
      await pump(
        tester,
        FlexLine(
          wrap: true,
          balance: true,
          lineCount: 2,
          runSpacing: 20,
          crossAxisAlignment: CrossAxisAlignment.start,
          alignContent: WrapAlignment.start,
          children: [
            FlexCell(crossSizeFraction: 0.5, ratio: 1, child: box('a', height: 60)),
            FlexCell(crossSizeFraction: 0.5, ratio: 1, child: box('b', height: 60)),
          ],
        ),
        width: 240,
        height: 120,
      );
      expect(sizeOf(tester, 'a'), const Size(60, 60));
      expect(topLeftOf(tester, 'b'), const Offset(0, 80));
    });
  });

  group('a basis between a floor and a ceiling of its own', () {
    // `flex: 1 1 min(400px, 100%)` beside a 300 item in a wrapping 800 row
    // with a 32 gap: the basis is 400, whatever the content asks, so the
    // two share a line and the first grows into the 68 left. (`max(400px,
    // 50%)` the same way: 400 over the 400 half.)
    testWidgets('min() and max(): the smaller, or the larger, of a length and a share is the basis', (tester) async {
      for (final cell in [
        FlexCell(grow: 1, basis: 400, basisCapFraction: 1, min: 0, child: box('a', width: 700)),
        FlexCell(grow: 1, basisFraction: 0.5, basisFloor: 400, min: 0, child: box('a', width: 700)),
      ]) {
        await pump(
          tester,
          FlexLine(
            wrap: true,
            spacing: 32,
            children: [
              cell,
              FlexCell(mainSize: 300, child: box('b')),
            ],
          ),
          width: 800,
          height: null,
        );
        expect(sizeOf(tester, 'a').width, 468);
        expect(topLeftOf(tester, 'b'), const Offset(500, 0));
      }
    });

    testWidgets('NEGATIVE: the content as the basis wraps the second item under the first', (tester) async {
      await pump(
        tester,
        FlexLine(
          wrap: true,
          spacing: 32,
          children: [
            FlexCell(grow: 1, min: 0, child: box('a', width: 700)),
            FlexCell(mainSize: 300, child: box('b')),
          ],
        ),
        width: 800,
        height: null,
      );
      expect(topLeftOf(tester, 'b'), const Offset(0, 10));
    });

    testWidgets('min(): and the line where the line is the shorter', (tester) async {
      await pump(
        tester,
        FlexLine(children: [FlexCell(shrink: 0, basis: 400, basisCapFraction: 1, child: box('a'))]),
        width: 300,
      );
      expect(sizeOf(tester, 'a').width, 300);
    });

    testWidgets('clamp(): the floor and the ceiling each bind where they cross the share', (tester) async {
      for (final (room, want) in const [(300.0, 150.0), (600.0, 200.0), (100.0, 100.0)]) {
        await pump(
          tester,
          FlexLine(
            children: [FlexCell(shrink: 0, basisFraction: 0.5, basisFloor: 100, basisCap: 200, child: box('a'))],
          ),
          width: room,
        );
        expect(sizeOf(tester, 'a').width, want, reason: 'at $room');
      }
    });

    testWidgets('NEGATIVE: a bound that is a share of no length makes the basis the content', (tester) async {
      await pump(
        tester,
        FlexLine(
          key: const ValueKey('line'),
          children: [FlexCell(basis: 400, basisCapFraction: 1, child: box('a', width: 50))],
        ),
      );
      final line = tester.renderObject<RenderBox>(find.byKey(const ValueKey('line')));
      expect(line.getMaxIntrinsicWidth(double.infinity), 50);
    });
  });
}
