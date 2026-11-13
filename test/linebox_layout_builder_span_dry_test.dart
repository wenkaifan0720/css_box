// A LINE ASKED ITS SIZE ASKS A `LAYOUTBUILDER` UNDER ITS SPANS NOTHING THAT
// THROWS, ON EVERY FLUTTER. A line box asked a size before layout -- an
// intrinsic height, a dry layout, a dry baseline -- asks its paragraph,
// which asks each span's box its dry size, and its dry baseline where it
// stands on the baseline; a stack asked a baseline asks every child it
// holds, the ones it places too. Flutter's `LayoutBuilder` builds what it
// holds when it is laid out, and asked any of those outside Flutter's
// `debugCheckingIntrinsics` hatch it throws "The _RenderLayoutBuilder class
// does not support dry layout" in a debug build, on every Flutter. A page
// lowered to widgets puts one where a box is placed at a share of its
// stack's height (`top: 33.3333%`); a membership site's article cards stand
// such a stack on a line's baseline, and the line, asked its size by the
// flex line round it, threw at its first layout in a debug build of 3.38:
// the page drew nothing at either width. The line's questions go under the
// hatch where they reach a box that answers nothing dry (`_answersNoDry`,
// `dry.dart`): there the `LayoutBuilder` answers what a release build
// answers -- no size, no baseline -- and is built at its layout as before.
// So does a picture placed on the baseline, which answers no dry baseline
// of its own. A box of css_box's that measures what it holds asks it the
// same way: a ratio's width, a column's.
//
// NEGATIVE: the same stack with the boxes the `LayoutBuilder` would build
// standing in its place keeps the hatch shut (Flutter keeps what it
// measures) -- on 3.41 to 3.47 only where it answers a baseline, words
// beside its dot: there the `Semantics` Flutter tags a span's box with asks
// `RenderBox` over a stack that answers none (flutter#189711), and the
// hatch opens for that, at the head as well.
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

const _picture = Key('picture');
const _dot = Key('dot');

/// What the page's `LayoutBuilder` builds: a dot a third of the way down
/// the room it is laid out in, and [words] beside it where asked.
Widget _third(double height, {bool words = false}) => Stack(
  clipBehavior: Clip.none,
  children: [
    Positioned(
      top: height * 0.333333,
      left: 0,
      width: 8,
      height: 8,
      child: const SizedBox(key: _dot),
    ),
    if (words) const Text('w'),
  ],
);

/// Whether this Flutter's proxies ask `RenderBox.computeDryBaseline` where
/// what they hold answers no dry baseline, which asserts outside the hatch
/// (flutter#189711, 3.41 to 3.47), asked as `dry.dart` asks it. A span's box
/// stands under the `Semantics` Flutter tags it with, so there a stack that
/// answers no baseline opens the hatch whatever it holds, at the head too.
final bool _proxyAsksBox = () {
  var asks = false;
  try {
    RenderProxyBox().getDryBaseline(const BoxConstraints(), TextBaseline.alphabetic);
  } on FlutterError {
    asks = true;
  }
  return asks;
}();

/// A 52px picture on the line's baseline ([alignment]), with [over] in the
/// stack round it: placed over the whole picture ([placed]), as the page
/// places its `LayoutBuilder`, or the stack's own child.
Widget _line(
  List<bool> log,
  Widget over, {
  bool placed = true,
  PlaceholderAlignment alignment = PlaceholderAlignment.baseline,
}) => Directionality(
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
                  alignment: alignment,
                  baseline: TextBaseline.alphabetic,
                  child: _Hatch(
                    log,
                    child: Stack(
                      key: _picture,
                      clipBehavior: Clip.none,
                      fit: StackFit.passthrough,
                      children: [
                        const SizedBox(width: 52, height: 52),
                        if (placed) Positioned.fill(child: over) else over,
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

/// The line [t] pumped: asked its height before layout as it was laid out,
/// its dry size and baseline, and how each question measured the box on
/// its baseline, asked again at another width.
Future<RenderBox> _pumped(
  WidgetTester t,
  List<bool> log,
  Widget over, {
  bool placed = true,
  PlaceholderAlignment alignment = PlaceholderAlignment.baseline,
}) async {
  await t.pumpWidget(_line(log, over, placed: placed, alignment: alignment));
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

/// Where the dot the `LayoutBuilder` built stands in the picture.
Offset _dotIn(WidgetTester t) => t.getTopLeft(find.byKey(_dot)) - t.getTopLeft(find.byKey(_picture));

void main() {
  testWidgets('a placed LayoutBuilder on the baseline: the line asked its size throws nothing', (t) async {
    final log = <bool>[];
    final line = await _pumped(t, log, LayoutBuilder(builder: (context, room) => _third(room.maxHeight)));
    // No baseline in the stack, dry or laid out: the picture stands on its
    // bottom edge, on the strut's 5px of descent.
    expect(line.size.height, 57);
    expect(log, everyElement(isTrue));
    // Built at its layout, in the room the stack placed it in.
    expect(_dotIn(t).dy, moreOrLessEquals(52 * 0.333333, epsilon: 0.01));
  });

  testWidgets('a LayoutBuilder the stack holds, asked its size off the baseline: throws nothing', (t) async {
    final log = <bool>[];
    final line = await _pumped(
      t,
      log,
      LayoutBuilder(builder: (context, room) => const SizedBox(width: 20, height: 20)),
      placed: false,
      alignment: PlaceholderAlignment.middle,
    );
    // Dry, it answers no size, and the picture is its own 52px.
    expect(line.size.height, greaterThanOrEqualTo(52));
    expect(log, everyElement(isTrue));
  });

  testWidgets('a placed picture on the baseline, which has no dry baseline: throws nothing', (t) async {
    final log = <bool>[];
    final line = await _pumped(t, log, const RawImage(width: 52, height: 52));
    expect(line.size.height, 57);
    expect(log, everyElement(isTrue));
  });

  testWidgets('NEGATIVE: what the LayoutBuilder builds, standing in its place, keeps the hatch shut', (t) async {
    final log = <bool>[];
    final line = await _pumped(t, log, _third(52));
    expect(line.size.height, 57);
    // Where the span's `Semantics` asks `RenderBox` over a stack with no
    // baseline (3.41 to 3.47), the hatch opens for that, as at the head.
    expect(log, everyElement(_proxyAsksBox ? isTrue : isFalse));
    expect(_dotIn(t).dy, moreOrLessEquals(52 * 0.333333, epsilon: 0.01));
  });

  testWidgets('NEGATIVE: with words beside the dot, which answer a baseline: shut on every Flutter', (t) async {
    final log = <bool>[];
    await _pumped(t, log, _third(52, words: true));
    expect(log, everyElement(isFalse));
    expect(_dotIn(t).dy, moreOrLessEquals(52 * 0.333333, epsilon: 0.01));
  });

  testWidgets("a ratio's and a column's widths asked of a LayoutBuilder throw nothing", (t) async {
    Widget built(BuildContext context, BoxConstraints room) => const SizedBox(width: 20, height: 20);
    await t.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 300,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RatioBox(aspectRatio: 2, child: LayoutBuilder(builder: built)),
                MultiColumn(
                  count: 2,
                  children: [
                    LayoutBuilder(builder: built),
                    LayoutBuilder(builder: built),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    expect(t.takeException(), isNull);
    final ratio = t.renderObject<RenderBox>(find.byType(RatioBox));
    final columns = t.renderObject<RenderBox>(find.byType(MultiColumn));
    // What a release build answers: the LayoutBuilder has no width before
    // it is laid out.
    expect(ratio.getMinIntrinsicWidth(double.infinity), 0);
    expect(ratio.getMaxIntrinsicWidth(double.infinity), 0);
    expect(columns.getMinIntrinsicWidth(double.infinity), 0);
    expect(columns.getMaxIntrinsicWidth(double.infinity), 0);
    expect(columns.getMaxIntrinsicHeight(300), 0);
    expect(columns.getDryLayout(const BoxConstraints(maxWidth: 300)).height, 0);
    expect(t.takeException(), isNull);
  });
}
