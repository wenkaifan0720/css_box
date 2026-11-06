// UNDER THE HATCH EACH BOX OF CSS_BOX'S WORKS A QUESTION OUT ONCE. Flutter
// keeps every dry size, dry baseline and intrinsic it measures -- except
// under its `debugCheckingIntrinsics` hatch, which css_box opens in a
// debug build where a question may reach a box that asserts, and where a
// line box asks what it holds after its layout. Under it a line box asks
// each inline-block on it its size and its baseline, the paragraph inside
// asks them again, and each line box inside the inline-block does the same
// of what it holds: every level of lines multiplied the work under it, and
// a price-table site's phone home page -- rows of line boxes round
// inline-blocks of line boxes -- laid out in 3s in a debug build of 3.38.
// Each box of css_box's now keeps what it answers until the hatch shuts
// (`underHatch`, `KeptUnderHatch`, `dry.dart`).
//
// NEGATIVE: an answer worked out while a box reads the width a room above
// it was offered is not kept: a share of a room asked at two widths under
// one hatch answers each width.
import 'package:css_box/css_box.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// A 10px square standing on its baseline 8px down, which counts the
/// times it is measured dry.
class _Counted extends LeafRenderObjectWidget {
  const _Counted(this.count);

  final List<int> count;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderCounted(count);
}

class _RenderCounted extends RenderBox {
  _RenderCounted(this.count);

  final List<int> count;

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    count[0]++;
    return constraints.constrain(const Size(10, 10));
  }

  @override
  double? computeDryBaseline(covariant BoxConstraints constraints, TextBaseline baseline) {
    count[0]++;
    return 8;
  }

  @override
  double computeMinIntrinsicWidth(double height) => 10;

  @override
  double computeMaxIntrinsicWidth(double height) => 10;

  @override
  double computeMinIntrinsicHeight(double width) => 10;

  @override
  double computeMaxIntrinsicHeight(double width) => 10;

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) => 8;

  @override
  void performLayout() => size = constraints.constrain(const Size(10, 10));
}

/// A line box holding [inline] alone, an inline-block on its baseline.
Widget _line(Widget inline) => LineBox(
  lineHeight: 20,
  ascent: 15,
  child: Text.rich(
    TextSpan(
      children: [
        const TextSpan(text: '​'),
        WidgetSpan(alignment: PlaceholderAlignment.baseline, baseline: TextBaseline.alphabetic, child: inline),
      ],
    ),
    style: const TextStyle(fontSize: 14, height: 1),
    strutStyle: const StrutStyle(fontSize: 14, height: 20 / 14),
  ),
);

/// [depth] line boxes, each the inline-block on the line of the one round
/// it, round a square.
Widget _nest(int depth, List<int> count) {
  Widget w = _Counted(count);
  for (var i = 0; i < depth; i++) {
    w = _line(w);
  }
  return w;
}

/// A box that, asked its dry size, asks [child] its dry size 300 wide and
/// then 200 wide, writing down the heights under the hatch.
class _AsksTwice extends SingleChildRenderObjectWidget {
  const _AsksTwice(this.log, {super.child});

  final List<double> log;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderAsksTwice(log);
}

class _RenderAsksTwice extends RenderProxyBox {
  _RenderAsksTwice(this.log);

  final List<double> log;

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final c = child!;
    final wide = c.getDryLayout(const BoxConstraints(maxWidth: 300)).height;
    final narrow = c.getDryLayout(const BoxConstraints(maxWidth: 200)).height;
    if (RenderObject.debugCheckingIntrinsics) log.addAll([wide, narrow]);
    return super.computeDryLayout(constraints);
  }
}

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: 300, child: child),
    ),
  ),
);

void main() {
  for (final depth in [4, 6]) {
    testWidgets('$depth lines one inside the next measure the square a few times each', (tester) async {
      final count = [0];
      await _pump(tester, _nest(depth, count));
      expect(tester.takeException(), isNull);
      // Every line is the strut's 20px: the square stands 8px up from its
      // bottom inside the strut's 15 + 5.
      expect(tester.getSize(find.byType(LineBox).first).height, 20);
      // Measured under each line's hatch a few times per line: 20 times
      // under 4 lines and 32 under 6, where each level once tripled it --
      // 80 and 728.
      expect(count[0], lessThanOrEqualTo(6 * depth));
    });
  }

  testWidgets('NEGATIVE: a share of a room asked at two widths under one hatch answers each width', (tester) async {
    final log = <double>[];
    await _pump(
      tester,
      _line(
        _AsksTwice(
          log,
          child: Inset(
            insets: EdgeInsets.zero,
            room: true,
            child: SizedBox(
              width: 50,
              child: LastBaseline(
                child: Inset(insets: EdgeInsets.zero, shares: const EdgeInsets.only(bottom: 0.1), ofRoom: true),
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    // `padding-bottom: 10%` of the room: 30 at 300 wide, 20 at 200.
    expect(log, isNotEmpty);
    for (var i = 0; i < log.length; i += 2) {
      expect(log.sublist(i, i + 2), [30, 20]);
    }
  });
}
