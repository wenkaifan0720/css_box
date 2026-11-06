// A LINE ASKED ITS HEIGHT ASKS AN `ALIGN` ON ITS BASELINE NOTHING THAT
// THROWS, ON EVERY FLUTTER. A line box asked a size before layout -- an
// intrinsic height, a dry layout, a dry baseline -- asks each box on its
// baseline where it stands, and a stack answers that by asking every child
// it holds, the ones it places too. Flutter's `RenderPositionedBox` -- an
// `Align`, a `Center` -- answers no dry baseline of its own: asked one
// outside Flutter's `debugCheckingIntrinsics` hatch it throws "The
// RenderPositionedBox class does not implement computeDryBaseline" in a
// debug build, on every Flutter. A rental site's desktop inbox stands its
// host's round picture on a line's baseline, a stack whose placed badge is
// an `Align`, and the line, asked its height by the row round it, threw at
// 1440 in a debug build of 3.38, and every layout under it after. The
// line's questions go under the hatch where they reach such a box
// (`guardedWhereProxiesAssert`, `dry.dart`); in release the `Align` answers
// no baseline, and under the hatch it answers the same.
//
// NEGATIVE: a `Padding` answers its child's dry baseline, the line stands
// the box on it, and the hatch stays shut (Flutter keeps what it measures)
// -- on 3.38 and on 3.41 to 3.47 alike, where Flutter's proxies assert
// over a child that answers no baseline (flutter#189711) and the walk fears
// each proxy it cannot see through. The proxy that writes the hatch down
// here answers its child's baseline as css_box's own proxies do
// ([ChildDryBaseline]), which the walk passes through on every Flutter: as
// a proxy nobody knows, it alone opened the hatch on 3.47.
import 'package:css_box/css_box.dart';
import 'package:css_box/src/dry.dart' show ChildDryBaseline;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// A proxy that writes down, each time it is measured dry, whether it was
/// measured under the hatch, and answers its child's dry baseline as
/// css_box's own proxies do.
class _Hatch extends SingleChildRenderObjectWidget {
  const _Hatch(this.log, {super.child});

  final List<bool> log;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderHatch(log);
}

class _RenderHatch extends RenderProxyBox with ChildDryBaseline {
  _RenderHatch(this.log);

  final List<bool> log;

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    log.add(RenderObject.debugCheckingIntrinsics);
    return super.computeDryLayout(constraints);
  }
}

/// A 52px round picture on the line's baseline, with [badge] in the stack
/// round it: placed on its bottom edge ([placed]), as the inbox places its
/// badge, or the stack's own child.
Widget _line(List<bool> log, Widget badge, {bool placed = true}) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: 300,
      child: IntrinsicHeight(
        child: LineBox(
          lineHeight: 20,
          ascent: 15,
          child: Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: '​'),
                WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: _Hatch(
                    log,
                    child: Stack(
                      clipBehavior: Clip.none,
                      fit: StackFit.passthrough,
                      children: [
                        const SizedBox(width: 52, height: 52),
                        if (placed) Positioned(left: 4, right: -4, bottom: -2, child: badge) else badge,
                      ],
                    ),
                  ),
                ),
              ],
            ),
            style: const TextStyle(fontSize: 14, height: 1),
            strutStyle: const StrutStyle(fontSize: 14, height: 20 / 14),
          ),
        ),
      ),
    ),
  ),
);

const _icon = SizedBox(width: 20, height: 20);

/// The line [t] pumped: asked its height before layout as it was laid out,
/// its dry size and baseline, and how each question measured the box on
/// its baseline, asked again at another width.
Future<RenderBox> _pumped(WidgetTester t, List<bool> log, Widget badge, {bool placed = true}) async {
  await t.pumpWidget(_line(log, badge, placed: placed));
  expect(t.takeException(), isNull);
  final line = t.renderObject<RenderBox>(find.byType(LineBox));
  expect(line.getMaxIntrinsicHeight(300), line.size.height);
  expect(line.getMinIntrinsicHeight(300), line.size.height);
  expect(line.getDryLayout(const BoxConstraints.tightFor(width: 300)), line.size);
  line.getDryBaseline(const BoxConstraints(maxWidth: 300), TextBaseline.alphabetic);
  log.clear();
  line.getMaxIntrinsicHeight(250);
  line.getDryLayout(const BoxConstraints.tightFor(width: 250));
  line.getDryBaseline(const BoxConstraints(maxWidth: 250), TextBaseline.alphabetic);
  expect(t.takeException(), isNull);
  expect(log, isNotEmpty);
  return line;
}

void main() {
  testWidgets('a placed Align on the baseline: the line asked its height throws nothing', (t) async {
    final log = <bool>[];
    final line = await _pumped(t, log, const Align(alignment: Alignment.topRight, heightFactor: 1, child: _icon));
    // No baseline in the stack: the picture stands on its bottom edge, on
    // the strut's 5px of descent.
    expect(line.size.height, 57);
    expect(log, everyElement(isTrue));
  });

  testWidgets('a Center the stack holds: the line asked its height throws nothing', (t) async {
    final log = <bool>[];
    final line = await _pumped(t, log, const Center(child: _icon), placed: false);
    expect(line.size.height, 57);
    expect(log, everyElement(isTrue));
  });

  testWidgets('NEGATIVE: a placed Padding answers its baseline, and the hatch stays shut', (t) async {
    final log = <bool>[];
    final line = await _pumped(
      t,
      log,
      const Padding(
        padding: EdgeInsets.only(top: 3),
        child: Text('Ag', style: TextStyle(fontSize: 14)),
      ),
    );
    // The picture stands on the text's baseline, low in the stack.
    final stack = t.renderObject<RenderBox>(find.byType(Stack));
    final b = stack.getDryBaseline(stack.constraints, TextBaseline.alphabetic)!;
    expect(b, greaterThan(40));
    expect(b, lessThan(52));
    expect(line.size.height, moreOrLessEquals(b + 5, epsilon: 0.01));
    expect(log, everyElement(isFalse));
  });
}
