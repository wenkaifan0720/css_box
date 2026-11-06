// IndentedText releases the TextPainters it makes when it is done with them:
// a measurement's (dry layout, dry baseline, intrinsic sizes) once it is
// read, a layout's when the next layout replaces it, the greedy lines a
// balanced block re-breaks, the whole-text painter when the text changes,
// and the last layout's when the box is disposed. Counted by Flutter's own
// allocation events, which every TextPainter reports in a debug build.
import 'package:css_box/css_box.dart';
import 'package:css_box/rendering.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The TextPainters made and not yet disposed while [body] runs.
final live = <Object>{};

void track(ObjectEvent e) {
  if (e.object is! TextPainter) return;
  if (e is ObjectCreated) live.add(e.object);
  if (e is ObjectDisposed) live.remove(e.object);
}

const words = 'a hanging first line and the words after it, set in the box';

Widget host(double width, Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(width: width, child: child),
  ),
);

void main() {
  setUp(() {
    live.clear();
    FlutterMemoryAllocations.instance.addListener(track);
  });
  tearDown(() => FlutterMemoryAllocations.instance.removeListener(track));

  testWidgets('measurements release their painters and the box releases its own when it goes', (t) async {
    expect(kFlutterMemoryAllocationsEnabled, isTrue);
    await t.pumpWidget(host(120, IndentedText(words, indent: -20, style: const TextStyle(fontSize: 10))));
    final r = t.renderObject<RenderIndentedText>(find.byType(IndentedText));
    // The whole text on one line is measured once and kept, for the
    // intrinsic widths.
    r.getMaxIntrinsicWidth(double.infinity);
    final laidOut = live.length;
    expect(laidOut, greaterThan(0));
    for (var w = 60.0; w < 200; w += 10) {
      r.getDryLayout(BoxConstraints(maxWidth: w));
      r.getDryBaseline(BoxConstraints(maxWidth: w), TextBaseline.alphabetic);
      r.getMinIntrinsicHeight(w);
    }
    expect(live.length, laidOut);
    for (var w = 60.0; w < 200; w += 10) {
      await t.pumpWidget(host(w, IndentedText(words, indent: -20, style: const TextStyle(fontSize: 10))));
    }
    await t.pumpWidget(host(120, IndentedText(words, indent: -20, style: const TextStyle(fontSize: 10))));
    expect(live.length, laidOut);
    await t.pumpWidget(const SizedBox());
    expect(live, isEmpty);
  });

  testWidgets('a balanced block releases the greedy lines it re-breaks', (t) async {
    Widget text(double w) =>
        host(w, IndentedText(words, indent: -20, balance: true, style: const TextStyle(fontSize: 10)));
    await t.pumpWidget(text(120));
    final laidOut = live.length;
    for (var w = 60.0; w < 200; w += 10) {
      await t.pumpWidget(text(w));
    }
    await t.pumpWidget(text(120));
    expect(live.length, laidOut);
    await t.pumpWidget(const SizedBox());
    expect(live, isEmpty);
  });

  testWidgets('a new text releases the painter the old one was measured with', (t) async {
    Widget text(String s) => host(400, IndentedText(s, indent: 8, style: const TextStyle(fontSize: 10)));
    await t.pumpWidget(Center(child: IntrinsicWidth(child: text('one'))));
    final laidOut = live.length;
    await t.pumpWidget(Center(child: IntrinsicWidth(child: text('two words'))));
    await t.pumpWidget(Center(child: IntrinsicWidth(child: text('three words now'))));
    expect(live.length, laidOut);
    await t.pumpWidget(const SizedBox());
    expect(live, isEmpty);
  });

  testWidgets('NEGATIVE: the box still paints, and its rest is the same, after the painters it replaced are gone', (
    t,
  ) async {
    await t.pumpWidget(host(120, IndentedText(words, indent: -20, style: const TextStyle(fontSize: 10))));
    final before = t.renderObject<RenderIndentedText>(find.byType(IndentedText)).restText;
    final size = t.getSize(find.byType(IndentedText));
    await t.pumpWidget(host(80, IndentedText(words, indent: -20, style: const TextStyle(fontSize: 10))));
    await t.pumpWidget(host(120, IndentedText(words, indent: -20, style: const TextStyle(fontSize: 10))));
    final r = t.renderObject<RenderIndentedText>(find.byType(IndentedText));
    expect(r.restText, before);
    expect(t.getSize(find.byType(IndentedText)), size);
    r.getDryLayout(const BoxConstraints(maxWidth: 80));
    await t.pump();
    expect(t.takeException(), isNull);
  });
}
