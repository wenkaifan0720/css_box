// HOW THE WORK GROWS WITH THE CONTENT: each page at N, 2N and 4N, laid out
// again at a new width each run, and the time at each size over the time
// at N. Work that grows with the content alone doubles with each doubling
// (2, then 4); work that is done over the rest of the content for every
// line, or over every op for every group, grows as its square (4, then 16).
//
//   FloatText    one paragraph of N words beside a float, in a column half
//                the page wide: a line is set from what is left of the
//                paragraph, and the lines run into the hundreds.
//   InlineFlow   N words with a faded or moved inline box round every
//                tenth, laid out and painted: each such box is a group of
//                its own, painted after the rest (appendix E).
//   repaint      every word in a faded or moved box of its own, painted
//                again and not laid out: the paint alone, where a pass
//                over every op for every group would be most of it.
//
//   flutter test benchmark/scaling_benchmark.dart
//
// Times are a debug build's (flutter test runs with assertions on): read
// the ratios, not the times as frame times.
import 'package:css_box/css_box.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'bench.dart';
import 'words.dart';

const _sizes = [1000, 2000, 4000];
const _style = TextStyle(fontFamily: 'FlutterTest', fontSize: 14, color: Color(0xFF000000));

// The test font is a square one em across: at 14px, 10.5 above the
// baseline and 3.5 below it.
const _font = InlineFont(size: 14, ascent: 10.5, descent: 3.5, lineHeight: 20);
const _box = BoxDecoration(color: Color(0xFFFFF3B0));

Widget _floatText(int n) => FractionallySizedBox(
  alignment: Alignment.topLeft,
  widthFactor: 0.5,
  child: FloatFlow(
    children: [
      const FloatSlot(
        float: FloatSide.left,
        width: 120,
        height: 400,
        margin: EdgeInsets.only(right: 12),
        child: ColoredBox(color: Color(0xFFBAE6FD)),
      ),
      FloatText(TextSpan(text: sentence(n), style: _style), lineHeight: 20),
    ],
  ),
);

Widget _inlineFlow(int n) {
  final all = words(n);
  return InlineFlow(
    font: _font,
    style: _style,
    children: [
      for (var i = 0; i < all.length; i++)
        if (i % 10 == 0)
          InlineBox(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            decoration: _box,
            opacity: i % 20 == 0 ? 0.5 : 1,
            offset: i % 20 == 0 ? Offset.zero : const Offset(0, 1),
            children: [InlineText('${all[i]} ')],
          )
        else
          InlineText('${all[i]} '),
    ],
  );
}

Widget _everyWordABox(int n) {
  final all = words(n);
  return InlineFlow(
    font: _font,
    style: _style,
    children: [
      for (var i = 0; i < all.length; i++)
        InlineBox(
          opacity: i.isEven ? 0.5 : 1,
          offset: i.isEven ? Offset.zero : const Offset(0, 1),
          children: [InlineText('${all[i]} ')],
        ),
    ],
  );
}

/// The medians and their report, each over the first.
String _ratios(String name, Map<String, List<double>> times, {String unit = 'widths'}) {
  final medians = [for (final ms in times.values) stats(ms).median];
  return [
    reportAll(times, unit: unit),
    '${name.padRight(50)} ${[for (final m in medians) (m / medians.first).toStringAsFixed(2)].join(' : ')}'
        '   (time at ${_sizes.join(', ')} words over the time at ${_sizes.first})',
  ].join('\n');
}

/// The median at each of [_sizes] of [page], and each over the first.
Future<String> _sweep(WidgetTester tester, String name, Widget Function(int) page) async =>
    _ratios(name, await timePages(tester, {for (final n in _sizes) '$name, $n words': page(n)}, warmUp: 3, runs: 7));

/// [page] at each of [_sizes], laid out once and then painted again and
/// again, each paint timed alone.
Future<String> _repaints(WidgetTester tester, String name, Widget Function(int) page) async {
  tester.view.physicalSize = const Size(800, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final times = <String, List<double>>{};
  for (final n in _sizes) {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SingleChildScrollView(child: page(n)),
      ),
    );
    final flow = tester.renderObject<RenderBox>(find.byType(InlineFlow));
    final ms = times['$name, $n words'] = [];
    for (var run = 0; run < 10; run++) {
      flow.markNeedsPaint();
      final watch = Stopwatch()..start();
      await tester.pump();
      watch.stop();
      if (run >= 3) ms.add(watch.elapsedMicroseconds / 1000);
    }
  }
  return _ratios(name, times, unit: 'paints');
}

void main() {
  testWidgets('FloatText and InlineFlow at N, 2N and 4N words', (tester) async {
    final out = [
      await _sweep(tester, 'FloatText beside a float', _floatText),
      await _sweep(tester, 'InlineFlow, a faded or moved box in ten', _inlineFlow),
      await _repaints(tester, 'InlineFlow repaint, every word a box', _everyWordABox),
    ];
    // ignore: avoid_print
    print(out.join('\n'));
  });
}
