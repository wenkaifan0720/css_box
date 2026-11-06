// A SIZE A BOX OF CSS_BOX'S ASKS WHAT IT HOLDS ASSERTS NOWHERE, ON EVERY
// FLUTTER. A size asks a baseline wherever a box below lines what it holds
// up on one: a row on `CrossAxisAlignment.baseline` measured dry asks each
// item where it stands, a paragraph each span's box on the baseline. From
// Flutter 3.41 to 3.47 a proxy over a box that answers no baseline answers
// that by asking `RenderBox.computeDryBaseline`, which asserts in debug
// (flutter#189711). A marketplace's service page holds its round icon
// button in a `ShrinkWidth` that measures what it holds in its own layout:
// a decorated, clipped `IntrinsicWidth` box round a row on its baseline,
// which holds an empty label and a `Semantics` over the decorated button
// -- and every test that pumped the page threw "The RenderDecoratedBox
// class does not implement computeDryBaseline". Each size css_box asks goes
// through `guardedSize` (`dry.dart`), which there opens the hatch only
// where the size can reach such a proxy; on every other Flutter it asks as
// it always has.
//
// NEGATIVE: the same button in a row on its centre line asks no baseline,
// and the hatch stays shut (Flutter keeps what it measures).
import 'package:css_box/css_box.dart';
import 'package:css_box/rendering.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Whether this Flutter's proxies assert over a child that answers no dry
/// baseline (flutter#189711, 3.41 to 3.47).
final bool _proxiesAssert = () {
  try {
    RenderProxyBox().getDryBaseline(const BoxConstraints(), TextBaseline.alphabetic);
    return false;
  } on FlutterError {
    return true;
  }
}();

/// A proxy that writes down, each time it is measured dry, whether it was
/// measured under the hatch.
class _Hatch extends SingleChildRenderObjectWidget {
  const _Hatch(this.log, {super.child});

  final List<bool> log;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderHatch(log);
}

class _RenderHatch extends RenderProxyBox {
  _RenderHatch(this.log);

  final List<bool> log;

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    log.add(RenderObject.debugCheckingIntrinsics);
    return super.computeDryLayout(constraints);
  }
}

/// Its child as tall as its content, whatever the slot's height, measured
/// dry as it is laid out: the `SpillHeight` a page lowered to widgets
/// writes round a block whose content hangs out of it.
class _SpillHeight extends SingleChildRenderObjectWidget {
  const _SpillHeight({super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderSpillHeight();
}

class _RenderSpillHeight extends RenderConstrainedOverflowBox {
  _RenderSpillHeight()
    : super(alignment: Alignment.topLeft, minHeight: 0, maxHeight: double.infinity, fit: OverflowBoxFit.deferToChild);

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) => constraints.constrain(
    child!.getDryLayout(
      BoxConstraints(minWidth: constraints.minWidth, maxWidth: constraints.maxWidth, maxHeight: double.infinity),
    ),
  );
}

/// The button: a `Semantics` over a 40px decorated box -- a proxy over a
/// stack, which answers no baseline.
Widget _button() => Semantics(
  label: 'menu',
  child: MouseRegion(
    child: GestureDetector(
      onTap: () {},
      child: const SizedBox(
        width: 40,
        height: 40,
        child: DecoratedBox(
          decoration: BoxDecoration(color: Color(0xFFFFFFFF)),
          child: Stack(
            clipBehavior: Clip.none,
            fit: StackFit.passthrough,
            children: [
              SizedBox(width: 40, height: 40),
              Padding(padding: EdgeInsets.all(13), child: SizedBox(width: 14, height: 14)),
            ],
          ),
        ),
      ),
    ),
  ),
);

/// The service page's corner: the button in a row beside an empty label,
/// on the row's baseline ([baseline]) or its centre line, in a clipped
/// round box that shrinks to fit its slot.
Widget _corner(List<bool> log, {required bool baseline}) => Directionality(
  textDirection: TextDirection.ltr,
  child: Stack(
    children: [
      const SizedBox(width: 390, height: 400),
      Positioned(
        left: -16,
        right: 16,
        bottom: 16,
        child: Align(
          alignment: Alignment.topRight,
          heightFactor: 1,
          child: ShrinkWidth(
            roomFactor: 1,
            roomOffset: -16,
            spillAlign: 1,
            child: DecoratedBox(
              decoration: const BoxDecoration(color: Color(0xFF222222)),
              child: ClipOval(
                child: ClipRect(
                  child: IntrinsicWidth(
                    child: _SpillHeight(
                      child: _Hatch(
                        log,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: baseline ? CrossAxisAlignment.baseline : CrossAxisAlignment.center,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            const SizedBox(
                              width: 0,
                              height: 20,
                              child: Baseline(baseline: 15, baselineType: TextBaseline.alphabetic, child: Text('')),
                            ),
                            Flexible(child: _button()),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  ),
);

/// `Ag` and a 10px decorated box with no baseline, standing on the
/// baseline.
Widget _paragraph() => const Text.rich(
  TextSpan(
    children: [
      TextSpan(text: 'Ag'),
      WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: DecoratedBox(
          decoration: BoxDecoration(color: Color(0xFF3060A0)),
          child: SizedBox(width: 10, height: 10),
        ),
      ),
    ],
  ),
);

/// A row on its baseline holding a `Semantics` over a 10px decorated box.
Widget _row({Key? key}) => Row(
  key: key,
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.baseline,
  textBaseline: TextBaseline.alphabetic,
  children: [
    const Text('Ag'),
    Semantics(
      label: 'dot',
      child: const DecoratedBox(
        decoration: BoxDecoration(color: Color(0xFF3060A0)),
        child: SizedBox(width: 10, height: 10),
      ),
    ),
  ],
);

Widget _page(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(width: 300, child: child),
  ),
);

/// [child] in a box that shrinks to fit a share of its room, measured dry
/// through the probe that writes to [log].
Widget _shrunk(List<bool> log, Widget child) => _page(
  Align(
    alignment: Alignment.topLeft,
    child: ShrinkWidth(roomFactor: 1, child: _Hatch(log, child: child)),
  ),
);

void main() {
  testWidgets('a round button on a row\'s baseline, in a box that shrinks to fit, lays out', (t) async {
    final log = <bool>[];
    await t.pumpWidget(_corner(log, baseline: true));
    expect(t.takeException(), isNull);
    final box = t.renderObject<RenderBox>(find.byType(ShrinkWidth));
    expect(box.size, const Size(40, 40));
    // Measured by the shrink, under the hatch where a proxy asserts, and as
    // it always was everywhere else.
    expect(log, isNotEmpty);
    expect(log, everyElement(_proxiesAssert));
  });

  testWidgets('NEGATIVE: the button on the row\'s centre line keeps the hatch shut', (t) async {
    final log = <bool>[];
    await t.pumpWidget(_corner(log, baseline: false));
    expect(t.takeException(), isNull);
    expect(t.renderObject<RenderBox>(find.byType(ShrinkWidth)).size, const Size(40, 40));
    expect(log, isNotEmpty);
    expect(log, everyElement(isFalse));
  });

  // THE HATCH OPENS ONLY OVER WHAT A SIZE CAN REACH AND MAY ASSERT. Under
  // it Flutter caches nothing it measures, and a walk that feared every
  // inline-block it could not prove stood on a line, and every child a
  // stack places, relaid a marketplace's settings page thirty times as
  // slowly in a debug build of 3.47. These two hold no such box.
  testWidgets('NEGATIVE: a button inline on the baseline, its icon on its edge, keeps the hatch shut', (t) async {
    final log = <bool>[];
    await t.pumpWidget(
      _shrunk(
        log,
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'Ag'),
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: Semantics(
                  label: 'go',
                  child: const DecoratedBox(
                    decoration: BoxDecoration(color: Color(0xFF3060A0)),
                    child: Stack(
                      children: [
                        IgnoreBaseline(child: SizedBox(width: 10, height: 10)),
                        EdgeBaseline(child: SizedBox(width: 24, height: 24)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    expect(t.takeException(), isNull);
    expect(log, isNotEmpty);
    expect(log, everyElement(isFalse));
  });

  testWidgets('NEGATIVE: a stack measured asks the child it places nothing, and keeps the hatch shut', (t) async {
    final log = <bool>[];
    await t.pumpWidget(
      _shrunk(
        log,
        Stack(
          children: [
            const SizedBox(width: 40, height: 20),
            Positioned(left: 0, top: 0, child: _row()),
          ],
        ),
      ),
    );
    expect(t.takeException(), isNull);
    expect(log, isNotEmpty);
    expect(log, everyElement(isFalse));
  });

  testWidgets('a paragraph standing a decorated box on its baseline, in a box that measures it, lays out', (t) async {
    for (final box in <Widget>[
      ShrinkWidth(roomFactor: 1, child: _paragraph()),
      ShrinkWidth(child: _paragraph()),
      MinContentWidth(child: _paragraph()),
    ]) {
      await t.pumpWidget(_page(Align(alignment: Alignment.topLeft, child: box)));
      expect(t.takeException(), isNull, reason: '${box.runtimeType}');
    }
  });

  testWidgets('asked its height by a stock IntrinsicHeight, a FixedWidth over such a paragraph answers', (t) async {
    await t.pumpWidget(_page(IntrinsicHeight(child: FixedWidth(width: 100, child: _paragraph()))));
    expect(t.takeException(), isNull);
  });

  testWidgets('a flex line measures an item that is a row on its baseline over a Semantics', (t) async {
    await t.pumpWidget(_page(FlexLine(children: [FlexCell(child: _row())])));
    expect(t.takeException(), isNull);
  });

  testWidgets('a grid measures an item that is a row on its baseline over a Semantics', (t) async {
    await t.pumpWidget(_page(Tracks(columns: const [TrackSize.auto], children: [_row()])));
    expect(t.takeException(), isNull);
  });

  // AN IGNOREBASELINE ASKED ITS SIZE ASKS WHAT IT HOLDS. A row on its
  // baseline measured dry asks each item its size and where it stands; an
  // `IgnoreBaseline` item answers no baseline, but its size is its child's,
  // and there a row of its own on its baseline asks the `Semantics` in it.
  testWidgets('a row asked its baseline follows an IgnoreBaseline item with its size', (t) async {
    const outer = ValueKey('outer');
    await t.pumpWidget(
      _page(
        Align(
          alignment: Alignment.topLeft,
          child: Row(
            key: outer,
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Text('Ag'),
              IgnoreBaseline(child: _row()),
            ],
          ),
        ),
      ),
    );
    expect(t.takeException(), isNull);
    final row = t.renderObject<RenderBox>(find.byKey(outer));
    final b = dryBaselineOf(row, const BoxConstraints(maxWidth: 300), TextBaseline.alphabetic);
    expect(t.takeException(), isNull);
    expect(b, isNotNull);
  });
}
