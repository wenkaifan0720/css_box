// What the benchmarks share: a page laid out again at a new width each
// time, timed, beside the stock widgets' page of the same content.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// [count] widths a page is laid out at, from [from] a pixel apart: a new
/// one each time, so that no layout and no dry layout is answered from a
/// cache of the one before.
Iterable<double> widths(int count, {double from = 600}) sync* {
  for (var i = 0; i < count; i++) {
    yield from + i;
  }
}

/// Each of [pages] laid out at [runs] widths, each run timed from the width
/// changing to the frame being drawn: build (only the box that states the
/// width rebuilds), layout and paint. Milliseconds, by page.
///
/// Every page is first laid out at [warmUp] other widths, all of them
/// before any is timed, so that no page is timed while the code it runs is
/// still being compiled.
Future<Map<String, List<double>>> timePages(
  WidgetTester tester,
  Map<String, Widget> pages, {
  int warmUp = 10,
  int runs = 30,
}) async {
  tester.view.physicalSize = const Size(2000, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  // The page as a document is: as tall as it needs, scrolled over, and
  // laid out whole however little of it is in the window.
  Widget at(Widget page, double width) => Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: width,
        child: SingleChildScrollView(child: page),
      ),
    ),
  );
  for (final page in pages.values) {
    for (final width in widths(warmUp, from: 400)) {
      await tester.pumpWidget(at(page, width));
    }
  }
  final out = <String, List<double>>{};
  for (final MapEntry(key: name, value: page) in pages.entries) {
    final ms = out[name] = [];
    for (final width in widths(runs)) {
      final watch = Stopwatch()..start();
      await tester.pumpWidget(at(page, width));
      watch.stop();
      ms.add(watch.elapsedMicroseconds / 1000);
    }
  }
  expect(tester.takeException(), isNull);
  return out;
}

/// The report of [timePages]: one line a page. [unit] is what each time
/// was taken over.
String reportAll(Map<String, List<double>> times, {String unit = 'widths'}) =>
    [for (final MapEntry(key: name, value: ms) in times.entries) report(name, ms, unit: unit)].join('\n');

/// The median and the 90th percentile of [ms].
({double median, double p90}) stats(List<double> ms) {
  final s = [...ms]..sort();
  double at(double q) => s[((s.length - 1) * q).round()];
  return (median: at(.5), p90: at(.9));
}

/// One line of the report: what was laid out, and how long it took.
String report(String name, List<double> ms, {String unit = 'widths'}) {
  final (:median, :p90) = stats(ms);
  return '${name.padRight(50)} median ${median.toStringAsFixed(2).padLeft(8)} ms'
      '   p90 ${p90.toStringAsFixed(2).padLeft(8)} ms   (${ms.length} $unit)';
}
