// A STATED WIDTH ANSWERS ITS LAST LINE DRY AS IT DOES LAID OUT. An
// inline-block stands on its last line box (CSS 2.1 10.8.1); the line box
// it is on is the strut's box united with it (10.8), which the lowerer
// writes as a baseline row of the strut and a `LastBaseline` round the
// atom (or the atom as a placeholder on the block's own lines). With a
// `width`, the atom is a `SizedBox` -- Flutter's own `RenderConstrainedBox`
// -- or css_box's `FixedWidth`, and `dryLastBaselineOf` (`dry.dart`) has to
// ask its child at the box's OWN offer (its constraints enforced, its width
// tight), not at the one it was handed: there the words come to one long
// line, the child is not the box's size, and the walk answered the box's
// FIRST line.
//
// Flutter keeps a box's dry baseline and its laid-out one in one cache,
// keyed by constraints, so an ancestor that measures dry first -- a
// `FlexLine` sizing a growing cell -- hands that first line to the row's
// own layout: the strut hung from it and the row came out one line short.
// A design-awards site's two-line heading of a `width: 360px` inline-block did
// that, and the section under it stood 2px high
// (`fixtures/inline-block-stated-width-last-line`).
// NEGATIVEs: one line (first = last) stands where it did; a `SizedBox`
// with no child answers none; a stated width wide enough for one line; a
// label centred in a button of a least size, which the walk past the box
// would put at its top, stands where it is laid out (`lastNotAboveFirst`).
import 'package:css_box/css_box.dart';
import 'package:css_box/rendering.dart' show dryBaselineOf, dryLastBaselineOf;
import 'package:css_box/src/baseline.dart' show RenderLastBaseline;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const style = TextStyle(fontSize: 10, height: 2);
  const strut = StrutStyle(fontSize: 10, height: 2, forceStrutHeight: true);
  const alpha = TextBaseline.alphabetic;

  // A FlexLine that measures its growing cell dry before it lays it out,
  // round a baseline row of a 24-tall strut (baseline 18) and the atom.
  Widget measuredFirst(Key k, Widget atom) => Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: 200,
        child: FlexLine(
          children: [
            FlexCell(
              mainSizeFraction: 1,
              child: OverflowBox(
                minHeight: 0,
                maxHeight: double.infinity,
                fit: OverflowBoxFit.deferToChild,
                alignment: Alignment.topLeft,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: alpha,
                  children: [
                    const SizedBox(
                      height: 24,
                      child: Baseline(baseline: 18, baselineType: alpha, child: Text('')),
                    ),
                    LastBaseline(key: k, child: atom),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  RenderBox atomOf(WidgetTester t, Key k) => t.renderObject<RenderLastBaseline>(find.byKey(k)).child!;

  testWidgets('three lines in a stated width stand on the third, under a parent that measures first', (t) async {
    final k = GlobalKey();
    await t.pumpWidget(
      measuredFirst(
        k,
        const SizedBox(
          width: 60,
          child: Text('one two six', style: style, strutStyle: strut),
        ),
      ),
    );
    // Three lines at 60: the last baseline is 55 down (the face's 15 and
    // two 20px lines), under the strut's 18 -- the atom stands at the top
    // and the strut 37 down.
    expect(t.getTopLeft(find.byKey(k)).dy, 0);
    expect(t.getSize(find.byType(Row)).height, 60 + 24 - 18 - 5);
    final sized = atomOf(t, k);
    const c = BoxConstraints(maxWidth: 200);
    expect(dryLastBaselineOf(sized, c, alpha)! - dryBaselineOf(sized, c, alpha)!, 40);
    expect(dryLastBaselineOf(sized, c, alpha), _laidOut(t, k));
  });

  testWidgets('a ConstrainedBox with a max width answers its child at that width', (t) async {
    final k = GlobalKey();
    await t.pumpWidget(
      measuredFirst(
        k,
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 60),
          child: const Text('one two six', style: style, strutStyle: strut),
        ),
      ),
    );
    expect(t.getTopLeft(find.byKey(k)).dy, 0);
    final box = atomOf(t, k);
    expect(dryLastBaselineOf(box, const BoxConstraints(maxWidth: 200), alpha), _laidOut(t, k));
  });

  testWidgets('css_box FixedWidth, the stated width a placeholder is written as, answers the same', (t) async {
    final k = GlobalKey();
    await t.pumpWidget(
      measuredFirst(
        k,
        const FixedWidth(
          width: 60,
          child: Text('one two six', style: style, strutStyle: strut),
        ),
      ),
    );
    expect(t.getTopLeft(find.byKey(k)).dy, 0);
    final box = atomOf(t, k);
    const c = BoxConstraints(maxWidth: 200);
    expect(dryLastBaselineOf(box, c, alpha)! - dryBaselineOf(box, c, alpha)!, 40);
    expect(dryLastBaselineOf(box, c, alpha), _laidOut(t, k));
  });

  testWidgets('NEGATIVE: one line in a stated width stands on it', (t) async {
    final k = GlobalKey();
    await t.pumpWidget(
      measuredFirst(
        k,
        const SizedBox(
          width: 60,
          child: Text('one', style: style, strutStyle: strut),
        ),
      ),
    );
    // 15 down, over the strut's 18: it stands 3 down.
    expect(t.getTopLeft(find.byKey(k)).dy, 3);
    final sized = atomOf(t, k);
    const c = BoxConstraints(maxWidth: 200);
    expect(dryLastBaselineOf(sized, c, alpha), dryBaselineOf(sized, c, alpha));
  });

  testWidgets('NEGATIVE: a stated width wide enough for the words is one line', (t) async {
    final k = GlobalKey();
    await t.pumpWidget(
      measuredFirst(
        k,
        const SizedBox(
          width: 180,
          child: Text('one two six', style: style, strutStyle: strut),
        ),
      ),
    );
    expect(t.getTopLeft(find.byKey(k)).dy, 3);
  });

  testWidgets('NEGATIVE: a SizedBox with no child answers none', (t) async {
    final k = GlobalKey();
    await t.pumpWidget(measuredFirst(k, const SizedBox(width: 60, height: 30)));
    expect(dryLastBaselineOf(atomOf(t, k), const BoxConstraints(maxWidth: 200), alpha), isNull);
  });

  // A button of a least height round its label, centred in it as a stated
  // size lowers it: past the button's own offer the label's box comes to
  // the button's size too, and a walk that took it for one at its top
  // answered a last line above the first.
  Widget button(BoxConstraints least, {double pad = 4}) => ConstrainedBox(
    constraints: least,
    child: Padding(
      padding: EdgeInsets.all(pad),
      child: OverflowBox(
        minWidth: 0,
        minHeight: 0,
        fit: OverflowBoxFit.deferToChild,
        child: OverflowBox(
          maxHeight: double.infinity,
          fit: OverflowBoxFit.deferToChild,
          child: const Text('Go', style: style, strutStyle: strut),
        ),
      ),
    ),
  );

  for (final (name, least) in [
    ('a least height', const BoxConstraints(minHeight: 40)),
    ('a least height and width', const BoxConstraints(minWidth: 90, minHeight: 40, maxHeight: 40)),
  ]) {
    testWidgets('NEGATIVE: a label centred in a button of $name stands where it is laid out', (t) async {
      final k = GlobalKey();
      await t.pumpWidget(measuredFirst(k, button(least)));
      final box = atomOf(t, k);
      const c = BoxConstraints(maxWidth: 200);
      // The label's line, 20 tall, is centred in the 32 inside the padding:
      // 4 + 6 + its 15.
      expect(_laidOut(t, k), 25);
      expect(dryLastBaselineOf(box, c, alpha), 25);
    });
  }
}

/// The laid-out last baseline of the atom under [k], asked fresh: under the
/// `debugCheckingIntrinsics` guard css_box asks across (`dry.dart`,
/// `dryBaselineOf`), which goes past Flutter's baseline cache -- the cache
/// that hands a dry answer on to the layout.
double? _laidOut(WidgetTester t, Key k) {
  final box = t.renderObject<RenderLastBaseline>(find.byKey(k));
  final was = RenderObject.debugCheckingIntrinsics;
  RenderObject.debugCheckingIntrinsics = true;
  try {
    return box.getDistanceToBaseline(TextBaseline.alphabetic, onlyReal: true);
  } finally {
    RenderObject.debugCheckingIntrinsics = was;
  }
}
