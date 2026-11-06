// InlineFlow on a large page: 2,000 words, an inline box with padding and
// a background round every 25th to 30th word and an atomic inline every
// 100th, laid out again at a new width each run -- beside Flutter's
// Text.rich of the same words (the boxes as styled spans, the atoms as
// WidgetSpans), and InlineFlow and Text over the words alone.
//
//   flutter test benchmark/inline_flow_benchmark.dart
//
// Times are a debug build's (flutter test runs with assertions on): read
// them against each other, not as frame times.
import 'package:css_box/css_box.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'bench.dart';
import 'words.dart';

const _words = 2000;
const _style = TextStyle(fontFamily: 'FlutterTest', fontSize: 14, color: Color(0xFF000000));

// The test font is a square one em across: at 14px, 10.5 above the
// baseline and 3.5 below it.
const _font = InlineFont(size: 14, ascent: 10.5, descent: 3.5, lineHeight: 20);
const _box = BoxDecoration(color: Color(0xFFFFF3B0));
const _atom = SizedBox(width: 14, height: 14, child: ColoredBox(color: Color(0xFF0EA5E9)));

Widget _flow({required bool boxes}) {
  final all = words(_words);
  final children = <InlineNode>[];
  for (var i = 0; i < all.length; i++) {
    if (boxes && i % 100 == 99) children.add(const InlineAtom(child: _atom));
    if (boxes && i % 25 == 0) {
      children.add(
        InlineBox(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          decoration: _box,
          children: [InlineText('${all[i]} ${all[(i + 1) % all.length]}')],
        ),
      );
      children.add(const InlineText(' '));
      i++;
      continue;
    }
    children.add(InlineText('${all[i]} '));
  }
  return InlineFlow(font: _font, style: _style, children: children);
}

Widget _text({required bool boxes}) {
  final all = words(_words);
  final spans = <InlineSpan>[];
  for (var i = 0; i < all.length; i++) {
    if (boxes && i % 100 == 99) {
      spans.add(
        const WidgetSpan(alignment: PlaceholderAlignment.baseline, baseline: TextBaseline.alphabetic, child: _atom),
      );
    }
    if (boxes && i % 25 == 0) {
      spans.add(
        TextSpan(
          text: '${all[i]} ${all[(i + 1) % all.length]}',
          style: const TextStyle(backgroundColor: Color(0xFFFFF3B0)),
        ),
      );
      spans.add(const TextSpan(text: ' '));
      i++;
      continue;
    }
    spans.add(TextSpan(text: '${all[i]} '));
  }
  return Text.rich(TextSpan(children: spans), style: _style);
}

void main() {
  testWidgets('InlineFlow: 2,000 words, relaid at a new width', (tester) async {
    final times = await timePages(tester, {
      'InlineFlow, 2,000 words, 80 boxes, 20 atoms': _flow(boxes: true),
      'Text.rich, the same (stock)': _text(boxes: true),
      'InlineFlow, 2,000 words alone': _flow(boxes: false),
      'Text.rich, 2,000 words alone (stock)': _text(boxes: false),
    });
    // ignore: avoid_print
    print(reportAll(times));
  });
}
