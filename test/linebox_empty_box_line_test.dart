import 'dart:io';
import 'dart:typed_data';

import 'package:css_box/css_box.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// A LINE HOLDING NOTHING BUT A BOX OF NO SIZE IS STILL A LINE. An atomic
// inline is in-flow content, so a line it stands on alone is a line box as
// tall as its strut (CSS 2.1 9.4.2, 10.8). A docs site's headings end in a 0x0
// `inline-block` link: where the words and their space fill the line, the
// link wraps and Chrome's heading is two lines tall. Skia draws that line
// and gives the 0x0 placeholder no box, so the line box read one
// (fixtures/inline-block-empty-wraps-alone p1).
void main() {
  setUpAll(() async {
    final bytes = Uint8List.fromList(await File('test/fonts/Inter.ttf').readAsBytes());
    await (FontLoader('Fx')..addFont(Future.value(ByteData.view(bytes.buffer)))).load();
  });

  const style = TextStyle(fontFamily: 'Fx', fontSize: 28, height: 1, leadingDistribution: TextLeadingDistribution.even);
  const strut = StrutStyle(
    fontFamily: 'Fx',
    fontSize: 28,
    height: 40 / 28,
    leading: 0,
    leadingDistribution: TextLeadingDistribution.even,
  );
  const words = 'Conditional rendering ';

  double width(String s) {
    final p = TextPainter(
      text: TextSpan(text: s, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final w = p.width;
    p.dispose();
    return w;
  }

  Widget line(List<InlineSpan> spans) => LineBox(
    keepWords: false,
    lineHeight: 40,
    ascent: 31,
    child: Text.rich(
      TextSpan(children: spans),
      style: style,
      strutStyle: strut,
    ),
  );

  WidgetSpan box(double w, double h) => WidgetSpan(
    child: SizedBox(width: w, height: h),
    alignment: PlaceholderAlignment.baseline,
    baseline: TextBaseline.alphabetic,
  );

  Future<RenderBox> lay(WidgetTester tester, double room, List<InlineSpan> spans) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: room, child: line(spans)),
        ),
      ),
    );
    return tester.renderObject<RenderBox>(find.byType(LineBox));
  }

  testWidgets('a 0x0 box that wraps onto a line of its own is a line, laid out and asked', (tester) async {
    final room = width(words.trimRight()) + 1;
    expect(room, lessThan(width(words)));
    final r = await lay(tester, room, [const TextSpan(text: words), box(0, 0)]);
    expect(r.size.height, 80);
    expect(r.getMinIntrinsicHeight(room), 80);
    expect(r.getDryLayout(BoxConstraints(maxWidth: room)).height, 80);
  });

  testWidgets('two of them wrap onto the one line', (tester) async {
    final room = width(words.trimRight()) + 1;
    final r = await lay(tester, room, [const TextSpan(text: words), box(0, 0), box(0, 0)]);
    expect(r.size.height, 80);
  });

  testWidgets('NEGATIVE: where the words and their space fit, the box is on their line', (tester) async {
    final r = await lay(tester, width(words) + 2, [const TextSpan(text: words), box(0, 0)]);
    expect(r.size.height, 40);
  });

  testWidgets('NEGATIVE: a 0x0 box that STARTS the line is on it', (tester) async {
    final r = await lay(tester, width(words.trimRight()) + 1, [box(0, 0), const TextSpan(text: words)]);
    expect(r.size.height, 40);
  });

  testWidgets('NEGATIVE: a box of no width but some height was already counted', (tester) async {
    final r = await lay(tester, width(words.trimRight()) + 1, [const TextSpan(text: words), box(0, 20)]);
    expect(r.size.height, 80);
  });
}
