import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';
import 'package:css_box/src/dry.dart';

/// A box 40 by 20 that writes down each time it is measured dry.
class _Measured extends LeafRenderObjectWidget {
  const _Measured(this.log);
  final List<String> log;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderMeasured(log);
}

/// A proxy with no child, so a dry baseline question passes it as it passes
/// any of Flutter's proxies.
class _RenderMeasured extends RenderProxyBox {
  _RenderMeasured(this.log);
  final List<String> log;

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    log.add('measured');
    return constraints.constrain(const Size(40, 20));
  }

  @override
  void performLayout() => size = constraints.constrain(const Size(40, 20));
}

/// A picture of [_Leaf]'s: a box with no child, sized by its parent or laid
/// out by itself ([byParent]), that writes down each time it is measured
/// dry -- as a picture drawn from a vector file is.
class _Leaf extends LeafRenderObjectWidget {
  const _Leaf(this.log, {required this.byParent});
  final List<String> log;
  final bool byParent;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderLeaf(log, byParent);
}

class _RenderLeaf extends RenderBox {
  _RenderLeaf(this.log, this.byParent);
  final List<String> log;
  final bool byParent;

  @override
  bool get sizedByParent => byParent;

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    log.add('measured');
    return constraints.smallest;
  }

  @override
  void performLayout() {
    if (!byParent) size = constraints.smallest;
  }
}

/// A paragraph that writes down each time it is measured dry. (Not each
/// time it is asked its baseline dry: a debug build asks every box that
/// again, past what it kept, to check the answer.)
class _MeasuredText extends LeafRenderObjectWidget {
  const _MeasuredText(this.log);
  final List<String> log;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderMeasuredText(log);
}

class _RenderMeasuredText extends RenderParagraph {
  _RenderMeasuredText(this.log) : super(const TextSpan(text: 'x'), textDirection: TextDirection.ltr);
  final List<String> log;

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    log.add('measured');
    return super.computeDryLayout(constraints);
  }
}

/// Whether this Flutter's proxies assert over a child that answers no dry
/// baseline (flutter#189711, 3.41 to 3.47): there a question that asks
/// [_RenderMeasured] -- a proxy with no child -- for a baseline is asked
/// under the hatch, and nothing it measures is kept.
final bool _keepsNothing = () {
  try {
    RenderProxyBox().getDryBaseline(const BoxConstraints(), TextBaseline.alphabetic);
    return false;
  } on FlutterError {
    return true;
  }
}();

/// That a question that asks [_RenderMeasured] its baseline, asked again,
/// measured nothing [log] did not hold after the first ([once] entries) --
/// where Flutter keeps what it measured. Where its proxies assert over a
/// child that answers none, that question is asked under the hatch, and the
/// second measures again.
void _kept(List<String> log, int once, {String? reason}) {
  if (_keepsNothing) {
    expect(log.length, greaterThan(once), reason: 'under the hatch nothing is kept');
  } else {
    expect(log, hasLength(once), reason: reason);
  }
}

Widget _ltr(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: Center(child: child),
);

void main() {
  // THE HATCH IS OPENED ONLY WHERE THE QUESTION CAN REACH ONE. Under it
  // Flutter keeps nothing it measures, and every box under a question that
  // asks in turn measured everything under it again: a price-table site's 245
  // network chips laid out in 24s in debug.
  testWidgets('a dry baseline asked through boxes that all answer one keeps what it measured', (tester) async {
    final log = <String>[];
    await tester.pumpWidget(
      _ltr(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(padding: const EdgeInsets.all(4), child: _Measured(log)),
            const Text('a'),
          ],
        ),
      ),
    );
    final row = tester.renderObject<RenderBox>(find.byType(Row));
    const room = BoxConstraints(maxWidth: 300);
    log.clear();
    dryBaselineOf(row, room, TextBaseline.alphabetic);
    expect(log, isNotEmpty);
    final once = log.length;
    dryBaselineOf(row, room, TextBaseline.alphabetic);
    _kept(log, once, reason: 'asked again, Flutter has the measure already');
  });

  testWidgets('NEGATIVE: one asked through an Align is asked under the hatch, and nothing throws', (tester) async {
    final log = <String>[];
    await tester.pumpWidget(
      _ltr(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(4),
              child: Align(child: _Measured(log)),
            ),
            const Text('a'),
          ],
        ),
      ),
    );
    final row = tester.renderObject<RenderBox>(find.byType(Row));
    const room = BoxConstraints(maxWidth: 300);
    log.clear();
    expect(dryBaselineOf(row, room, TextBaseline.alphabetic), isNotNull);
    final once = log.length;
    dryBaselineOf(row, room, TextBaseline.alphabetic);
    // An Align answers no dry baseline but by asserting: under the hatch
    // Flutter keeps nothing, and measures the box again.
    expect(log.length, greaterThan(once));
    expect(tester.takeException(), isNull);
  });

  testWidgets("a span on the baseline is followed through Flutter's own wrappers round it", (tester) async {
    final log = <String>[];
    await tester.pumpWidget(
      _ltr(
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'a'),
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: _Measured(log),
              ),
            ],
          ),
        ),
      ),
    );
    final paragraph = tester.renderObject<RenderParagraph>(find.byType(RichText));
    const room = BoxConstraints(maxWidth: 300);
    log.clear();
    dryBaselineOf(paragraph, room, TextBaseline.alphabetic);
    final once = log.length;
    expect(once, greaterThan(0));
    dryBaselineOf(paragraph, room, TextBaseline.alphabetic);
    _kept(log, once);
  });

  // A PARAGRAPH ALWAYS ANSWERS A BASELINE, and so does every box over it
  // that answers its child's -- the proxy Flutter puts round a span, a
  // padding, a `LastBaseline` -- so nothing there asserts, on 3.41 to 3.47
  // either (flutter#189711 is a proxy over a child that answers none), and
  // the question is asked unguarded, as release builds ask it: under the
  // hatch nothing is kept, and a line that measured its inline-block dry
  // read the chip's laid-out baseline in debug where every release build
  // reads the dry one it kept.
  testWidgets('a span on the baseline over a paragraph keeps what it measured, on every Flutter', (tester) async {
    final log = <String>[];
    await tester.pumpWidget(
      _ltr(
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'a'),
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: LastBaseline(child: _MeasuredText(log)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final paragraph = tester.renderObject<RenderParagraph>(find.byType(RichText));
    const room = BoxConstraints(maxWidth: 300);
    log.clear();
    expect(dryBaselineOf(paragraph, room, TextBaseline.alphabetic), isNotNull);
    final once = log.length;
    expect(once, greaterThan(0));
    dryBaselineOf(paragraph, room, TextBaseline.alphabetic);
    expect(log, hasLength(once), reason: 'asked again, Flutter has the measure already');
    expect(tester.takeException(), isNull);
  });

  Future<List<String>> askSpanTwice(WidgetTester tester, PlaceholderAlignment alignment) async {
    final log = <String>[];
    await tester.pumpWidget(
      _ltr(
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'a'),
              WidgetSpan(
                alignment: alignment,
                baseline: TextBaseline.alphabetic,
                child: Align(child: _Measured(log)),
              ),
            ],
          ),
        ),
      ),
    );
    final paragraph = tester.renderObject<RenderParagraph>(find.byType(RichText));
    log.clear();
    expect(dryBaselineOf(paragraph, const BoxConstraints(maxWidth: 300), TextBaseline.alphabetic), isNotNull);
    log.add('again');
    dryBaselineOf(paragraph, const BoxConstraints(maxWidth: 300), TextBaseline.alphabetic);
    expect(tester.takeException(), isNull);
    return log;
  }

  testWidgets('a span above the baseline is asked its size alone, and an Align in it keeps what it measured', (
    tester,
  ) async {
    final log = await askSpanTwice(tester, PlaceholderAlignment.aboveBaseline);
    expect(log.last, 'again');
  });

  testWidgets('NEGATIVE: an Align in a span on the baseline is asked under the hatch, and nothing throws', (
    tester,
  ) async {
    final log = await askSpanTwice(tester, PlaceholderAlignment.baseline);
    expect(log.indexOf('again'), lessThan(log.length - 1));
  });

  // A LEAF SIZED BY ITS PARENT ANSWERS A SIZE AND ASKS NOTHING: its size is
  // its dry layout, and nothing is under it. An inline icon -- a picture
  // drawn from a vector file, 16 by 16, in a span above the baseline -- read
  // as a box nobody here knows put its paragraph under the hatch, and a
  // price table's 245 chips, each one of those inside an inline-block alone
  // on its line, laid its page out in 50 to 100s in a debug build of 3.47.
  Future<List<String>> askIconTwice(WidgetTester tester, {required bool byParent}) async {
    final log = <String>[];
    await tester.pumpWidget(
      _ltr(
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'a'),
              WidgetSpan(
                alignment: PlaceholderAlignment.aboveBaseline,
                baseline: TextBaseline.alphabetic,
                child: DecoratedBox(
                  decoration: const BoxDecoration(),
                  child: SizedBox(width: 16, height: 16, child: _Leaf(log, byParent: byParent)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final paragraph = tester.renderObject<RenderParagraph>(find.byType(RichText));
    log.clear();
    expect(dryBaselineOf(paragraph, const BoxConstraints(maxWidth: 300), TextBaseline.alphabetic), isNotNull);
    expect(log, isNotEmpty);
    log.add('again');
    dryBaselineOf(paragraph, const BoxConstraints(maxWidth: 300), TextBaseline.alphabetic);
    expect(tester.takeException(), isNull);
    return log;
  }

  testWidgets('a leaf sized by its parent in a span above the baseline keeps what it measured', (tester) async {
    final log = await askIconTwice(tester, byParent: true);
    expect(log.last, 'again', reason: 'asked again, Flutter has the measure already');
  });

  testWidgets('NEGATIVE: a leaf that lays itself out there is asked under the hatch, and nothing throws', (
    tester,
  ) async {
    final log = await askIconTwice(tester, byParent: false);
    expect(log.indexOf('again'), lessThan(log.length - 1), reason: 'under the hatch nothing is kept');
  });

  testWidgets('what a guarded box measures of what it holds is followed too', (tester) async {
    // `EdgeBaseline(only: true)` asks its child no baseline -- but measures
    // it, and an `Align` answers a size.
    final log = <String>[];
    await tester.pumpWidget(_ltr(EdgeBaseline(only: true, child: Align(child: _Measured(log)))));
    final edge = tester.renderObject<RenderBox>(find.byType(EdgeBaseline));
    const room = BoxConstraints(maxWidth: 300);
    log.clear();
    expect(dryBaselineOf(edge, room, TextBaseline.alphabetic), 20);
    final once = log.length;
    dryBaselineOf(edge, room, TextBaseline.alphabetic);
    expect(log, hasLength(once));
  });

  testWidgets('NEGATIVE: a row on baselines a guarded box measures puts the question under the hatch', (tester) async {
    // A stock `Row` lined up on baselines measures its items by asking each
    // one its baseline, and an `Align` among them answers by asserting --
    // where the guarded box over it is asked a baseline unguarded too.
    await tester.pumpWidget(
      _ltr(
        const EdgeBaseline(
          only: true,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Align(child: SizedBox(width: 10, height: 10)),
              Text('a'),
            ],
          ),
        ),
      ),
    );
    final edge = tester.renderObject<RenderBox>(find.byType(EdgeBaseline));
    expect(dryBaselineOf(edge, const BoxConstraints(maxWidth: 300), TextBaseline.alphabetic), isNotNull);
    expect(tester.takeException(), isNull);
  });
}
