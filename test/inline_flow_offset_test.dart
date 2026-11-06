// InlineBox.offset: `position: relative` on an inline box (CSS 2.1
// 9.4.3). The box and all in it are painted off where the lines put them,
// the lines keeping its room; moved, it is a positioned box and paints
// after the flow's other pieces (appendix E, step 8). Measured in Chrome
// (fixtures/inline-flow-relative): a padded label moved 14px on is painted
// over the word after it, which keeps its place, and its rectangle is
// reported where it is painted.
import 'package:css_box/css_box.dart';
import 'package:css_box/rendering.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

InlineFont font(double size, double lineHeight) => InlineFont(
  size: size,
  ascent: (size * 0.8).roundToDouble(),
  descent: (size * 0.2).roundToDouble(),
  lineHeight: lineHeight,
  xHeight: size * 0.8,
);

Future<RenderInlineFlow> lay(WidgetTester tester, double width, List<InlineNode> kids, {Key? boundary}) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: RepaintBoundary(
          key: boundary,
          child: ColoredBox(
            color: const Color(0xFFFFFFFF),
            child: SizedBox(
              width: width,
              child: InlineFlow(
                font: font(16, 20),
                style: const TextStyle(fontSize: 16, color: Color(0xFF000000)),
                children: kids,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  return tester.renderObject<RenderInlineFlow>(find.byType(InlineFlow));
}

void main() {
  const red = BoxDecoration(color: Color(0xFFFF0000));

  testWidgets('a moved box is reported where it is painted, the lines keeping its room', (tester) async {
    const outer = ValueKey('outer'), inner = ValueKey('inner');
    List<InlineNode> kids(Offset a, Offset b) => [
      const InlineText('a '),
      InlineBox(
        key: outer,
        offset: a,
        children: [
          const InlineText('bb '),
          InlineBox(
            key: inner,
            offset: b,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            children: const [InlineText('c')],
          ),
        ],
      ),
      const InlineText(' dd'),
    ];
    var r = await lay(tester, 400, kids(Offset.zero, Offset.zero));
    final still = r.boxRects;
    final text = r.pieces;
    r = await lay(tester, 400, kids(const Offset(2, 2), const Offset(4, -3)));
    // The offsets add: the inner box moves by its own and the outer's.
    expect(r.boxRects[outer], still[outer]!.shift(const Offset(2, 2)));
    expect(r.boxRects[inner], still[inner]!.shift(const Offset(6, -1)));
    // Nothing else moves: the text is set where it was, the room kept.
    expect([for (final p in r.pieces) (p.text, p.x, p.baseline)], [for (final p in text) (p.text, p.x, p.baseline)]);
    const lone = InlineBox(offset: Offset(0, 3), children: [InlineText('e')]);
    r = await lay(tester, 400, const [InlineText('a '), lone]);
    expect(r.fragmentsOf(lone).single.top, r.lineBaselines.single - 13 + 3);
  });

  testWidgets('a moved box paints after the flow, over the word it is moved onto (appendix E, step 8)', (tester) async {
    // `a ` is 0..32, the empty box padded 8 a side 32..48, ` cc` 48..96:
    // moved 24 on, the box is painted 56..72, over the first `c` (64..80).
    final key = GlobalKey();
    await lay(tester, 200, const [
      InlineText('a '),
      InlineBox(offset: Offset(24, 0), padding: EdgeInsets.symmetric(horizontal: 8), decoration: red),
      InlineText(' cc'),
    ], boundary: key);
    expect(tester.layers.whereType<OpacityLayer>(), isEmpty, reason: 'a moved box is no layer');
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final data = await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData();
      final w = image.width;
      image.dispose();
      return (bytes!, w);
    });
    (int, int, int) rgb(int x, int y) {
      final i = (y * data!.$2 + x) * 4;
      return (data.$1.getUint8(i), data.$1.getUint8(i + 1), data.$1.getUint8(i + 2));
    }

    expect(rgb(40, 10), (255, 255, 255), reason: 'where the lines put it: nothing');
    expect(rgb(60, 10), (255, 0, 0), reason: 'moved, over the space');
    expect(rgb(68, 10), (255, 0, 0), reason: 'over the `c`, painted after it');
    expect(rgb(76, 10), (0, 0, 0), reason: 'the rest of the `c`, where it was');
  });

  testWidgets('an atomic inline moves with the box round it, where it is hit', (tester) async {
    const chip = ValueKey('chip');
    List<InlineNode> kids(Offset at) => [
      const InlineText('a '),
      InlineBox(
        offset: at,
        children: const [
          InlineAtom(
            child: ColoredBox(key: chip, color: Color(0xFF0000FF), child: SizedBox(width: 20, height: 10)),
          ),
        ],
      ),
    ];
    await lay(tester, 200, kids(Offset.zero));
    final still = tester.getTopLeft(find.byKey(chip));
    await lay(tester, 200, kids(const Offset(5, 7)));
    expect(tester.getTopLeft(find.byKey(chip)), still + const Offset(5, 7));
    final atom = tester.renderObject(find.byKey(chip));
    bool hits(Offset at) => tester.hitTestOnBinding(at).path.any((e) => identical(e.target, atom));
    // (Inside the flow: no box is hit outside its parent's size.)
    expect(hits(still + const Offset(5, 7) + const Offset(18, 1)), isTrue);
    expect(hits(still + const Offset(1, 1)), isFalse);
  });

  // InlineBox.offsetShare: `left: 10%` on a relative inline is a share of
  // its containing block's width -- the content box of the block its lines
  // are in (CSS 2.1 10.1, 9.3.2), which is the width the flow is laid out
  // at (fixtures/inline-flow-relative n1: 32px on in a 320px paragraph).
  testWidgets('a share of the flow\'s width moves the box across by that much of it, at every width', (tester) async {
    const k = ValueKey('k');
    List<InlineNode> kids(double share, [Offset by = Offset.zero]) => [
      const InlineText('a '),
      InlineBox(key: k, offset: by, offsetShare: share, children: const [InlineText('b')]),
      const InlineText(' c'),
    ];
    var r = await lay(tester, 320, kids(0));
    final still = r.boxRects[k]!;
    final text = r.pieces;
    r = await lay(tester, 320, kids(0.1));
    expect(r.boxRects[k], still.shift(const Offset(32, 0)));
    expect([for (final p in r.pieces) (p.text, p.x, p.baseline)], [for (final p in text) (p.text, p.x, p.baseline)]);
    // `right: 10%` the other way, and the length of a `calc()` beside it.
    r = await lay(tester, 320, kids(-0.1, const Offset(4, 2)));
    expect(r.boxRects[k], still.shift(const Offset(-28, 2)));
    // Laid out at another width, the share is of that one.
    r = await lay(tester, 200, kids(0.1));
    expect(r.boxRects[k]!.left, closeTo(still.left + 20, 1e-9));
    // A moved box: painted after the flow, as one moved by a length is.
    final key = GlobalKey();
    await lay(tester, 240, const [
      InlineText('a '),
      InlineBox(offsetShare: 0.1, padding: EdgeInsets.symmetric(horizontal: 8), decoration: red),
      InlineText(' cc'),
    ], boundary: key);
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final data = await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData();
      final w = image.width;
      image.dispose();
      return (bytes!, w);
    });
    (int, int, int) rgb(int x, int y) {
      final i = (y * data!.$2 + x) * 4;
      return (data.$1.getUint8(i), data.$1.getUint8(i + 1), data.$1.getUint8(i + 2));
    }

    // `a ` is 0..32, the box 32..48 moved 24 on to 56..72, over the first
    // `c` (64..80).
    expect(rgb(40, 10), (255, 255, 255), reason: 'where the lines put it: nothing');
    expect(rgb(68, 10), (255, 0, 0), reason: 'over the `c`, painted after it');
    expect(rgb(76, 10), (0, 0, 0), reason: 'the rest of the `c`, where it was');
  });

  testWidgets('a moved box that fades is one layer, moved', (tester) async {
    const k = ValueKey('k');
    final r = await lay(tester, 200, const [
      InlineText('a '),
      InlineBox(key: k, offset: Offset(0, 3), opacity: 0.5, decoration: red, children: [InlineText('b')]),
    ]);
    expect([for (final l in tester.layers.whereType<OpacityLayer>()) l.alpha], [128]);
    expect(r.boxRects[k]!.top, r.lineBaselines.single - 13 + 3);
  });
}
