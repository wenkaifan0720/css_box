// EVERY BOX ANSWERS AT LEAST THE HEIGHT IT LAYS OUT AT. A box asked its
// max intrinsic height at the width it was laid out at, under a parent that
// hands it no height and lets it take the width it wants, answers no less
// than the height it laid out at: an `IntrinsicHeight` or a row measured by
// its items hands it the answer back as its height, and a short one is a
// column that overflows (what the w2f sweep finds at the text scales: a
// pricing page's label line, `linebox_forced_strut_reach_test.dart`; a
// stated width in less room, `fixed_width_narrow_room_asked_test.dart`).
// Each box of css_box's that answers an intrinsic height, round six kinds
// of content, at three widths and three text scales.
// Not here: a box handed a TIGHT width it would not take, which an intrinsic
// question cannot tell from a loose one (`ShrinkWidth` answers at the width
// it shrinks to); and a stock `ConstrainedBox` cap round a `FractionalHeight`,
// which the share reads as its room (the lowering puts the cap on the share).
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

const _t = TextStyle(fontSize: 14, height: 1.0);
const _forced = StrutStyle(fontSize: 13.9224, height: 25.6 / 13.9224, leading: 0, forceStrutHeight: true);

final _children = <String, Widget Function()>{
  'words': () => const Text('aaa bb cccc dd eee ffff gg', style: _t),
  'line': () => const LineBox(lineHeight: 20, child: Text('aaa bb cccc dd eee ffff gg', style: _t)),
  'ratio': () => const AspectRatio(aspectRatio: 2, child: ColoredBox(color: Color(0xFF000000))),
  'fixed': () => const SizedBox(width: 50, height: 30),
  'badge': () => const Text.rich(
    TextSpan(children: [
      TextSpan(text: '​'),
      WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: SizedBox(height: 20, child: Text('ab', style: _t, softWrap: false)),
      ),
    ]),
    style: _t,
    softWrap: false,
    textScaler: TextScaler.noScaling,
  ),
  'forced badge': () => const LineBox(
    keepWords: false,
    lineHeight: 25.59375,
    ascent: 18,
    child: Text.rich(
      TextSpan(children: [
        TextSpan(text: '\u200B', style: TextStyle(letterSpacing: 0)),
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: SizedBox(
            height: 25.59375,
            child: Text('ab', softWrap: false, style: TextStyle(fontSize: 16, height: 1.6), strutStyle: _forced),
          ),
        ),
      ]),
      style: TextStyle(fontSize: 16, height: 1),
      strutStyle: _forced,
      softWrap: false,
      textScaler: TextScaler.noScaling,
    ),
  ),
  'tiles': () => const Wrap(children: [
    SizedBox(width: 40, height: 10),
    SizedBox(width: 40, height: 10),
    SizedBox(width: 40, height: 10),
    SizedBox(width: 40, height: 10),
  ]),
};

final _boxes = <String, Widget Function(Widget)>{
  'AlignBox': (c) => AlignBox(alignment: Alignment.topLeft, child: c),
  'AlignBox h1': (c) => AlignBox(alignment: Alignment.topLeft, heightFactor: 1, child: c),
  'MinContentWidth': (c) => MinContentWidth(child: c),
  'FixedWidth 80': (c) => FixedWidth(width: 80, child: c),
  'Compressible 100': (c) => Compressible(natural: 100, child: c),
  'BlockEllipsis': (c) => BlockEllipsis(child: c),
  'ClampedBlock': (c) => ClampedBlock(child: c),
  'FractionalWidth .5': (c) => FractionalWidth(factor: 0.5, child: c),
  'FractionalConstraints max 1': (c) => FractionalConstraints(maxFactor: 1, child: c),
  'FractionalConstraints max 1 compressible': (c) => FractionalConstraints(maxFactor: 1, compressible: true, child: c),
  'FractionalHeight 1': (c) => FractionalHeight(factor: 1, child: c),
  'FractionalHeight 1 max 24': (c) => FractionalHeight(factor: 1, max: 24, child: c),
  'FractionalHeight 1 min 24': (c) => FractionalHeight(factor: 1, min: 24, child: c),
  'FractionalMinHeight 1': (c) => FractionalMinHeight(factor: 1, child: c),
  'LooseHeight': (c) => LooseHeight(child: c),
  'FloorBox 30': (c) => FloorBox(floor: 30, margin: 0, child: c),
  'Inset 4': (c) => Inset(insets: const EdgeInsets.all(4), child: c),
  'RatioBox 2': (c) => RatioBox(aspectRatio: 2, child: c),
  'ShrinkWidth': (c) => ShrinkWidth(child: c),
  'ShrinkWidth spill': (c) => ShrinkWidth(spill: true, child: c),
  'ShrinkWidth spill atHeight': (c) => ShrinkWidth(spill: true, atHeight: true, child: c),
  'ShrinkWidth room .5': (c) => ShrinkWidth(roomFactor: 0.5, child: c),
  'LineBox 20': (c) => LineBox(lineHeight: 20, child: c),
  'GapWrap': (c) => GapWrap(spacing: 4, runSpacing: 4, children: [c, const SizedBox(width: 30, height: 10)]),
  'FlexLine row': (c) => FlexLine(children: [FlexCell(child: c), const SizedBox(width: 30, height: 10)]),
  'FlexLine row start': (c) => FlexLine(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [FlexCell(child: c), const SizedBox(width: 30, height: 10)],
  ),
  'FlexLine row baseline': (c) => FlexLine(
    crossAxisAlignment: CrossAxisAlignment.baseline,
    children: [FlexCell(child: c), const SizedBox(width: 30, height: 10, child: Text('x', style: TextStyle(fontSize: 6)))],
  ),
  'FlexLine wrap': (c) => FlexLine(
    wrap: true,
    spacing: 4,
    runSpacing: 4,
    children: [FlexCell(child: c), const SizedBox(width: 30, height: 10)],
  ),
  'FlexLine column': (c) => FlexLine(direction: Axis.vertical, children: [FlexCell(child: c), const SizedBox(height: 10)]),
  'MultiColumn 2': (c) => MultiColumn(count: 2, gap: 8, children: [c, const SizedBox(height: 10)]),
};

void main() {
  testWidgets('every box answers at least what it lays out', (t) async {
    final short = <String>[], threw = <String>[];
    const k = ValueKey('box');
    for (final b in _boxes.entries) {
      for (final c in _children.entries) {
        for (final scale in const [1.0, 1.3, 2.0]) {
          for (final width in const [40.0, 120.0, 400.0]) {
            await t.pumpWidget(MediaQuery(
              data: MediaQueryData(size: const Size(800, 600), textScaler: TextScaler.linear(scale)),
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: width,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [KeyedSubtree(key: k, child: b.value(c.value()))],
                    ),
                  ),
                ),
              ),
            ));
            final what = '${b.key} | ${c.key} | x$scale | w$width';
            final e = t.takeException();
            if (e != null) {
              threw.add('$what: ${e.toString().split('\n').first}');
              continue;
            }
            final box = t.renderObject<RenderBox>(find.byKey(k));
            final laid = box.size;
            final asked = box.getMaxIntrinsicHeight(laid.width);
            if (asked < laid.height - 0.01) {
              short.add('$what: laid ${laid.width}x${laid.height}, asked $asked');
            }
          }
        }
      }
    }
    expect(threw, isEmpty, reason: threw.join('\n'));
    expect(short, isEmpty, reason: short.join('\n'));
  });
}
