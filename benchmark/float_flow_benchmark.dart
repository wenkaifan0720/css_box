// FloatFlow on a large page: 60 sections, each a float -- left and right
// in turn -- and a paragraph of 80 words whose lines shorten beside it,
// with a cleared block between sections, laid out again at a new width
// each run; beside the closest stock page, a Column of Rows that sets each
// paragraph beside its float for the whole of its height.
//
//   flutter test benchmark/float_flow_benchmark.dart
//
// Times are a debug build's (flutter test runs with assertions on): read
// them against each other, not as frame times.
import 'package:css_box/css_box.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'bench.dart';
import 'words.dart';

const _sections = 60;
const _style = TextStyle(fontFamily: 'FlutterTest', fontSize: 14, color: Color(0xFF000000));
const _picture = ColoredBox(color: Color(0xFFBAE6FD));

Widget _floats() => FloatFlow(
  children: [
    for (var s = 0; s < _sections; s++) ...[
      FloatSlot(
        float: s.isEven ? FloatSide.left : FloatSide.right,
        width: 120,
        height: 80,
        margin: s.isEven ? const EdgeInsets.only(right: 12) : const EdgeInsets.only(left: 12),
        child: _picture,
      ),
      FloatText(
        TextSpan(
          text: sentence(80, seed: s),
          style: _style,
        ),
        lineHeight: 20,
      ),
      const FloatSlot(clear: FloatClear.both, height: 16, child: SizedBox()),
    ],
  ],
);

Widget _column() => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    for (var s = 0; s < _sections; s++) ...[
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        textDirection: s.isEven ? TextDirection.ltr : TextDirection.rtl,
        children: [
          const SizedBox(width: 120, height: 80, child: _picture),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              sentence(80, seed: s),
              style: _style,
              strutStyle: const StrutStyle(fontSize: 14, height: 20 / 14, forceStrutHeight: true),
              textDirection: TextDirection.ltr,
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
    ],
  ],
);

void main() {
  testWidgets('FloatFlow: 60 floats and paragraphs, relaid at a new width', (tester) async {
    final times = await timePages(tester, {
      'FloatFlow, 60 floats, 60 paragraphs of 80 words': _floats(),
      'Column of Rows, the same (stock, no wrap under)': _column(),
    });
    // ignore: avoid_print
    print(reportAll(times));
  });
}
