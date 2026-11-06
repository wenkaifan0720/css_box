// A LINEBOX ASKS ITS PARAGRAPH UNDER THE HATCH ONLY WHERE FLUTTER'S
// PROXIES ASSERT (flutter#189711, 3.41 to 3.47). Under
// `debugCheckingIntrinsics` Flutter keeps nothing it measures, and a box's
// dry and laid-out baselines share one cache: a line measured under the
// hatch and then laid out stands a span on the span's laid-out baseline,
// where a release build stands it on the dry one it kept. Asked through the
// hatch on every Flutter, a caption set in a column beside an inline
// picture -- a box the walk cannot vouch for -- came out 1.5px higher in a
// debug build of 3.38 than in release. On every Flutter but 3.41 to 3.47 a
// debug build now sets the line as release does.
import 'package:css_box/css_box.dart';
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

/// A 30 by 20 box that no walk of css_box's knows, whose baseline is [dry]
/// asked dry and [laid] laid out. [hatch] gets, for each question about its
/// size or baseline, whether it was asked under the hatch.
class _Odd extends LeafRenderObjectWidget {
  const _Odd({required this.dry, required this.laid, required this.hatch});

  final double dry, laid;
  final List<bool> hatch;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderOdd(dry, laid, hatch);
}

class _RenderOdd extends RenderBox {
  _RenderOdd(this.dry, this.laid, this.hatch);

  final double dry, laid;
  final List<bool> hatch;

  static const _size = Size(30, 20);

  double _asked(double v) {
    hatch.add(RenderObject.debugCheckingIntrinsics);
    return v;
  }

  @override
  double computeMinIntrinsicWidth(double height) => _asked(_size.width);

  @override
  double computeMaxIntrinsicWidth(double height) => _asked(_size.width);

  @override
  double computeMinIntrinsicHeight(double width) => _asked(_size.height);

  @override
  double computeMaxIntrinsicHeight(double width) => _asked(_size.height);

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    _asked(0);
    return constraints.constrain(_size);
  }

  @override
  double? computeDryBaseline(covariant BoxConstraints constraints, TextBaseline baseline) => _asked(dry);

  @override
  void performLayout() => size = constraints.constrain(_size);

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) => laid;
}

Widget _line(Widget span) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: 200,
      child: LineBox(
        child: Text.rich(
          TextSpan(
            // Text taller above its baseline than the box, so the box's top
            // moves with the baseline it stands on.
            style: const TextStyle(fontSize: 40),
            children: [
              const TextSpan(text: 'a'),
              WidgetSpan(alignment: PlaceholderAlignment.baseline, baseline: TextBaseline.alphabetic, child: span),
            ],
          ),
        ),
      ),
    ),
  ),
);

/// Where the box of [span] stands once its line was asked its size dry --
/// as the box round a line asks before it lays the line out at the same
/// room -- and laid out again; with [hatch], that question asked under the
/// hatch.
Future<double> _top(WidgetTester tester, _Odd span, {bool hatch = false}) async {
  // A new box each time, not the last one updated.
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(_line(span));
  final odd = tester.renderObject<RenderBox>(find.byType(_Odd));
  final line = tester.renderObject<RenderBox>(find.byType(LineBox));
  odd.markNeedsLayout();
  span.hatch.clear();
  final was = RenderObject.debugCheckingIntrinsics;
  RenderObject.debugCheckingIntrinsics = hatch;
  try {
    line.getDryLayout(line.constraints);
  } finally {
    RenderObject.debugCheckingIntrinsics = was;
  }
  await tester.pump();
  expect(tester.takeException(), isNull);
  return odd.localToGlobal(Offset.zero).dy;
}

void main() {
  testWidgets('a LineBox measures its paragraph with the hatch shut, but on Flutter '
      '3.41 to 3.47', (tester) async {
    final hatch = <bool>[];
    await _top(tester, _Odd(dry: 10, laid: 10, hatch: hatch));
    expect(hatch, isNotEmpty, reason: 'the span was measured dry');
    if (_proxiesAssert) {
      // A proxy over a box that may answer no baseline asserts here, and
      // the walk cannot vouch for this one: every question is guarded.
      expect(hatch, everyElement(isTrue));
    } else {
      // The line's size is measured as a release build measures it, and
      // what that keeps is kept. (Its baseline is asked under the hatch
      // after, by `dryBaselineOf`, which keeps nothing and changes
      // nothing kept.)
      expect(hatch.first, isFalse);
    }
  });

  testWidgets('a span whose dry and laid-out baselines differ stands where a release '
      'build stands it, but on Flutter 3.41 to 3.47', (tester) async {
    final asDry = await _top(tester, _Odd(dry: 10, laid: 10, hatch: <bool>[]));
    final asLaid = await _top(tester, _Odd(dry: 14, laid: 14, hatch: <bool>[]));
    expect(asDry - asLaid, 4, reason: 'a baseline 4 lower stands 4 higher');
    final odd = await _top(tester, _Odd(dry: 10, laid: 14, hatch: <bool>[]));
    // A release build keeps the dry baseline the line's size was measured
    // with, and lays the span out on it. Where the question is asked under
    // the hatch, nothing is kept, and the laid-out one is read.
    expect(odd, _proxiesAssert ? asLaid : asDry);
  });

  testWidgets('NEGATIVE: the same line measured under the hatch stands the span on its '
      'laid-out baseline', (tester) async {
    final asLaid = await _top(tester, _Odd(dry: 14, laid: 14, hatch: <bool>[]));
    final odd = await _top(tester, _Odd(dry: 10, laid: 14, hatch: <bool>[]), hatch: true);
    expect(odd, asLaid);
  });
}
