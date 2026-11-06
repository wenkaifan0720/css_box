// STOCK WRAPPERS STRAIGHT ROUND EACH OTHER, AND THE ONE THE TIDY FOLDS THEM
// TO. The held-out apps say a box in two or three wrappers where
// one says it: a music store's menu items a `ConstrainedBox(minHeight: 53)` round
// a `SizedBox(height: 32)`, a Japanese news site's ranking lists a `Padding(left: 30)`
// round a `Padding(vertical: 6)`, a price-table site's table controls an
// `IntrinsicWidth` round an `IntrinsicWidth`, a product site's rows of a negative
// margin a `SizedBox(height: 22)` inside an `OverflowBox` of 22, and every
// capped block that fills its width a `SizedBox(width: double.infinity)`
// under the cap's `ConstraintsTransformBox`. Each pair here is laid out side
// by side with its fold, under constraints tight, loose, open, floored and
// unbounded each way, and every question a parent may ask is asked of both:
// the size and where the child lands, the baseline laid out and dry, the dry
// layout, and the four intrinsic lengths at extents from 0 to endless. The
// answers must be the same doubles, bit for bit.
//
// NEGATIVE, for each fold, the pair the tidy leaves as written, shown to
// answer differently: an endless least (`SizedBox(width: double.infinity)`
// under a `maxWidth`), an axis two paddings both pad (`(c + 15) + 15` is not
// `c + 30` for a child 7.501964685792951 wide), two alignments that differ
// on an axis neither factors, an overflow box with no box above to answer
// its length, a cap's transform tight even unbounded, and two kinds of
// intrinsic box.
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// A leaf that answers like a paragraph: narrower is taller, its intrinsic
/// widths shrink with the height it is offered, its baseline is most of its
/// height, and every length is a double with bits below the pixel.
class _Probe extends LeafRenderObjectWidget {
  const _Probe({this.width = 113.37});
  final double width;
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderProbe(width);
}

class _RenderProbe extends RenderBox {
  _RenderProbe(this.natural);
  final double natural;

  static double _down(double w) => w.isFinite ? 15.3 + 900.7 / (w + 9.1) : 15.3;
  @override
  double computeMinIntrinsicWidth(double height) => height.isFinite ? 20.1 + 1000.3 / (height + 10.7) : 20.1;
  @override
  double computeMaxIntrinsicWidth(double height) => computeMinIntrinsicWidth(height) + 37.3;
  @override
  double computeMinIntrinsicHeight(double width) => _down(width);
  @override
  double computeMaxIntrinsicHeight(double width) => _down(width) + 11.7;

  Size _sized(BoxConstraints c) {
    final w = c.constrainWidth(natural);
    return Size(w, c.constrainHeight(_down(w)));
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) => _sized(constraints);
  @override
  double? computeDryBaseline(BoxConstraints constraints, TextBaseline baseline) => _sized(constraints).height * 0.8137;
  // Its height as laid out, kept: a baseline asked from further up may not
  // read `size`.
  double _height = 0;
  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) => _height * 0.8137;
  @override
  void performLayout() {
    size = _sized(constraints);
    _height = size.height;
  }
}

/// Hands its child exactly [inner] and asks it everything, as its parent.
class _Host extends SingleChildRenderObjectWidget {
  const _Host(this.inner, this.out, {super.child});
  final BoxConstraints inner;
  final List<Object?> out;
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderHost(inner, out);
}

class _RenderHost extends RenderProxyBox {
  _RenderHost(this.inner, this.out);
  final BoxConstraints inner;
  final List<Object?> out;

  static const _extents = [0.0, 7.5, 36.0, 52.9, 300.0, 1000.0, double.infinity];
  static const _asked = [
    BoxConstraints.tightFor(width: 300, height: 200),
    BoxConstraints(maxWidth: 300, maxHeight: 200),
    BoxConstraints(minWidth: 50, maxWidth: 400, minHeight: 10, maxHeight: 600),
    BoxConstraints(maxWidth: 123.45),
    BoxConstraints(minWidth: 75, maxWidth: 900, minHeight: 40),
    BoxConstraints(minWidth: 701, maxWidth: 900, maxHeight: 30),
    BoxConstraints.tightFor(width: 33.3),
    BoxConstraints.tightFor(width: 0, height: 0),
  ];

  Object? _try(Object? Function() f) {
    try {
      return f();
    } catch (e) {
      return 'throws';
    }
  }

  @override
  void performLayout() {
    final c = child!;
    c.layout(inner, parentUsesSize: true);
    out
      ..add(c.size)
      ..add(c.getDistanceToBaseline(TextBaseline.alphabetic, onlyReal: true));
    RenderObject? probe;
    void find(RenderObject r) {
      if (r is _RenderProbe) {
        probe = r;
      } else {
        r.visitChildren(find);
      }
    }

    find(c);
    if (probe case final p?) out.add(MatrixUtils.transformPoint(p.getTransformTo(c), Offset.zero));
    for (final e in _extents) {
      out.addAll([
        c.getMinIntrinsicWidth(e),
        c.getMaxIntrinsicWidth(e),
        c.getMinIntrinsicHeight(e),
        c.getMaxIntrinsicHeight(e),
      ]);
    }
    for (final a in _asked) {
      out
        ..add(c.getDryLayout(a))
        ..add(_try(() => c.getDryBaseline(a, TextBaseline.alphabetic)));
    }
    size = constraints.biggest;
  }

  @override
  void paint(PaintingContext context, Offset offset) {}
}

/// Constraints the pair is laid out under; the unbounded ones only for
/// pairs with no endless side to fill.
const _bounded = [
  BoxConstraints.tightFor(width: 300, height: 200),
  BoxConstraints(maxWidth: 300, maxHeight: 200),
  BoxConstraints(minWidth: 50, maxWidth: 400, minHeight: 10, maxHeight: 600),
  BoxConstraints(minWidth: 701, maxWidth: 900, minHeight: 0, maxHeight: 30),
  BoxConstraints.tightFor(width: 33.3, height: 17.77),
  BoxConstraints(maxWidth: 4.5, maxHeight: 2.25),
];
const _open = [
  BoxConstraints(),
  BoxConstraints(maxWidth: 123.45),
  BoxConstraints(minWidth: 75, minHeight: 40),
  BoxConstraints(maxHeight: 61.3),
];

Future<List<Object?>> _answers(WidgetTester t, Widget w, {bool open = true}) async {
  final out = <Object?>[];
  for (final c in [..._bounded, if (open) ..._open]) {
    await t.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: _Host(c, out, child: w),
      ),
    );
    // A fresh tree per constraint: nothing cached from the last one.
    await t.pumpWidget(const SizedBox.shrink());
  }
  return out;
}

/// The pair and its fold must answer the same; [differ] says they must not.
void _side(String name, Widget pair, Widget fold, {bool open = true, bool differ = false}) {
  testWidgets(name, (t) async {
    final a = await _answers(t, pair, open: open);
    final b = await _answers(t, fold, open: open);
    expect(a.length, b.length);
    if (differ) {
      expect(b, isNot(a));
    } else {
      expect(b, a);
    }
  });
}

void main() {
  group('boxes of constraints', () {
    _side(
      "a music store's min-height round a height",
      ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 53),
        child: SizedBox(height: 32, child: const _Probe()),
      ),
      const SizedBox(height: 53, child: _Probe()),
    );
    _side(
      'a max width round a height',
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: SizedBox(height: 36, child: const _Probe()),
      ),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700, minHeight: 36, maxHeight: 36),
        child: const _Probe(),
      ),
    );
    _side(
      'constraints said twice',
      ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 180),
        child: ConstrainedBox(constraints: const BoxConstraints(minWidth: 180), child: const _Probe()),
      ),
      ConstrainedBox(constraints: const BoxConstraints(minWidth: 180), child: const _Probe()),
    );
    _side(
      'a shrink box held open',
      ConstrainedBox(constraints: const BoxConstraints(minWidth: 1), child: const SizedBox.shrink()),
      const SizedBox(width: 1, height: 0),
    );
    _side(
      'a side said twice',
      const SizedBox(width: 120.5, height: 33.3, child: SizedBox(height: 33.3, child: _Probe())),
      const SizedBox(width: 120.5, height: 33.3, child: _Probe()),
    );
    _side(
      'an endless side said twice',
      const SizedBox(
        width: double.infinity,
        child: SizedBox(width: double.infinity, child: _Probe()),
      ),
      const SizedBox(width: double.infinity, child: _Probe()),
      open: false,
    );
    _side(
      'a width round a range down',
      SizedBox(
        width: 4,
        child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 2, maxHeight: 9), child: const _Probe()),
      ),
      ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 4, maxWidth: 4, minHeight: 2, maxHeight: 9),
        child: const _Probe(),
      ),
    );
    _side(
      'a chain of three',
      ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 24),
        child: SizedBox(
          height: 24,
          child: ConstrainedBox(constraints: const BoxConstraints.tightFor(width: 40), child: const _Probe()),
        ),
      ),
      const SizedBox(width: 40, height: 24, child: _Probe()),
    );
    _side(
      'ranges clamped into ranges',
      ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 50, maxWidth: 90),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 20, maxWidth: 140, minHeight: 7.25, maxHeight: 61.3),
          child: const _Probe(),
        ),
      ),
      ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 50, maxWidth: 90, minHeight: 7.25, maxHeight: 61.3),
        child: const _Probe(),
      ),
    );
    // NEGATIVE: the endless least answers its child's intrinsic width
    // unclamped by it; the one box of `b.enforce(a)` is tight at 480.
    _side(
      "a product site's max width round an endless width",
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SizedBox(width: double.infinity, child: const _Probe()),
      ),
      ConstrainedBox(constraints: const BoxConstraints.tightFor(width: 480), child: const _Probe()),
      open: false,
      differ: true,
    );
  });

  group('paddings', () {
    _side(
      "a Japanese news site's left round a vertical",
      const Padding(
        padding: EdgeInsets.only(left: 30),
        child: Padding(padding: EdgeInsets.symmetric(vertical: 6), child: _Probe()),
      ),
      const Padding(padding: EdgeInsets.only(left: 30, top: 6, bottom: 6), child: _Probe()),
    );
    _side(
      'a top round a horizontal',
      const Padding(
        padding: EdgeInsets.only(top: 1),
        child: Padding(padding: EdgeInsets.symmetric(horizontal: 1), child: _Probe()),
      ),
      const Padding(padding: EdgeInsets.only(left: 1, top: 1, right: 1), child: _Probe()),
    );
    _side(
      'insets below the pixel',
      const Padding(
        padding: EdgeInsets.only(left: 13.5969, right: 0.4031),
        child: Padding(padding: EdgeInsets.symmetric(vertical: 16.7969), child: _Probe(width: 7.501964685792951)),
      ),
      const Padding(
        padding: EdgeInsets.fromLTRB(13.5969, 16.7969, 0.4031, 16.7969),
        child: _Probe(width: 7.501964685792951),
      ),
    );
    // NEGATIVE: an axis both pad rounds twice where the sum rounds once.
    _side(
      'an axis both pad',
      const Padding(
        padding: EdgeInsets.only(right: 15),
        child: Padding(padding: EdgeInsets.only(right: 15), child: _Probe(width: 7.501964685792951)),
      ),
      const Padding(padding: EdgeInsets.only(right: 30), child: _Probe(width: 7.501964685792951)),
      differ: true,
    );
  });

  group('aligns', () {
    _side(
      'an Align of a factor 1 round another',
      const Align(
        alignment: Alignment.topCenter,
        heightFactor: 1,
        child: Align(alignment: Alignment.topCenter, heightFactor: 1, child: _Probe()),
      ),
      const Align(alignment: Alignment.topCenter, heightFactor: 1, child: _Probe()),
    );
    _side(
      'the inner set down at 0 whatever its alignment on the factored axis',
      const Align(
        alignment: Alignment.topCenter,
        heightFactor: 1,
        child: Align(alignment: Alignment.bottomCenter, heightFactor: 1, child: _Probe()),
      ),
      const Align(alignment: Alignment.topCenter, heightFactor: 1, child: _Probe()),
    );
    _side(
      'both factored',
      const Align(
        widthFactor: 1,
        heightFactor: 1,
        child: Align(alignment: Alignment.bottomRight, widthFactor: 1, heightFactor: 1, child: _Probe()),
      ),
      const Align(widthFactor: 1, heightFactor: 1, child: _Probe()),
    );
    _side(
      'directional, the same start',
      const Align(
        alignment: AlignmentDirectional.centerStart,
        heightFactor: 1,
        child: Align(alignment: AlignmentDirectional.bottomStart, heightFactor: 1, child: _Probe()),
      ),
      const Align(alignment: AlignmentDirectional.centerStart, heightFactor: 1, child: _Probe()),
    );
    // NEGATIVE: alignments that differ across, where neither factors.
    _side(
      'alignments that differ across',
      const Align(
        alignment: Alignment.topLeft,
        heightFactor: 1,
        child: Align(alignment: Alignment.topCenter, heightFactor: 1, child: _Probe()),
      ),
      const Align(alignment: Alignment.topLeft, heightFactor: 1, child: _Probe()),
      differ: true,
    );
  });

  group('a box inside an overflow box of its length', () {
    _side(
      "another product site's row of a negative margin along",
      const SizedBox(
        height: 18,
        child: OverflowBox(
          minHeight: 22,
          maxHeight: 22,
          fit: OverflowBoxFit.deferToChild,
          alignment: Alignment.bottomLeft,
          child: SizedBox(height: 22, child: _Probe()),
        ),
      ),
      const SizedBox(
        height: 18,
        child: OverflowBox(
          minHeight: 22,
          maxHeight: 22,
          fit: OverflowBoxFit.deferToChild,
          alignment: Alignment.bottomLeft,
          child: _Probe(),
        ),
      ),
    );
    _side(
      'across, the overflow box at its most, the height kept',
      const SizedBox(
        width: 18,
        child: OverflowBox(minWidth: 22, maxWidth: 22, child: SizedBox(width: 22, height: 5, child: _Probe())),
      ),
      const SizedBox(
        width: 18,
        child: OverflowBox(minWidth: 22, maxWidth: 22, child: SizedBox(height: 5, child: _Probe())),
      ),
      open: false,
    );
    // NEGATIVE: with no box above to answer the length, the inner box
    // answers 22 where the child answers its own.
    _side(
      'no box above',
      const OverflowBox(
        minHeight: 22,
        maxHeight: 22,
        fit: OverflowBoxFit.deferToChild,
        child: SizedBox(height: 22, child: _Probe()),
      ),
      const OverflowBox(minHeight: 22, maxHeight: 22, fit: OverflowBoxFit.deferToChild, child: _Probe()),
      differ: true,
    );
  });

  group("a cap's transform round a box that fills it", () {
    BoxConstraints cap(BoxConstraints offered) =>
        offered.hasBoundedWidth ? const BoxConstraints(maxWidth: 440).enforce(offered) : offered;
    BoxConstraints fills(BoxConstraints offered) =>
        BoxConstraints.tightFor(width: offered.hasBoundedWidth ? 440 : double.infinity).enforce(offered);
    _side(
      'the transform box alone',
      ConstraintsTransformBox(
        alignment: Alignment.topLeft,
        constraintsTransform: cap,
        child: const SizedBox(width: double.infinity, child: _Probe()),
      ),
      ConstraintsTransformBox(alignment: Alignment.topLeft, constraintsTransform: fills, child: const _Probe()),
      open: false,
    );
    _side(
      "that product site's quote, a capped block centred",
      Align(
        alignment: Alignment.topCenter,
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: ConstraintsTransformBox(
            alignment: Alignment.topLeft,
            constraintsTransform: cap,
            child: const SizedBox(width: double.infinity, child: _Probe()),
          ),
        ),
      ),
      Align(
        alignment: Alignment.topCenter,
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: ConstraintsTransformBox(
            alignment: Alignment.topLeft,
            constraintsTransform: fills,
            child: const _Probe(),
          ),
        ),
      ),
    );
    // NEGATIVE: tight at the cap even unbounded, the transform box asks its
    // child's height at 440 where the pair asks it at no bound.
    _side(
      'tight at the cap even unbounded',
      ConstraintsTransformBox(
        alignment: Alignment.topLeft,
        constraintsTransform: cap,
        child: const SizedBox(width: double.infinity, child: _Probe()),
      ),
      ConstraintsTransformBox(
        alignment: Alignment.topLeft,
        constraintsTransform: (offered) => const BoxConstraints.tightFor(width: 440).enforce(offered),
        child: const _Probe(),
      ),
      open: false,
      differ: true,
    );
  });

  group('intrinsic boxes', () {
    _side(
      "a price-table site's IntrinsicWidth round an IntrinsicWidth",
      const IntrinsicWidth(child: IntrinsicWidth(child: _Probe())),
      const IntrinsicWidth(child: _Probe()),
    );
    _side(
      'IntrinsicHeight round an IntrinsicHeight',
      const IntrinsicHeight(child: IntrinsicHeight(child: _Probe())),
      const IntrinsicHeight(child: _Probe()),
    );
    // NEGATIVE: the two kinds.
    _side(
      'IntrinsicWidth round an IntrinsicHeight',
      const IntrinsicWidth(child: IntrinsicHeight(child: _Probe())),
      const IntrinsicWidth(child: _Probe()),
      differ: true,
    );
  });
}
