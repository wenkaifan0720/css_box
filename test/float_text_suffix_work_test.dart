// A FLOATTEXT PARAGRAPH IS SET IN WORK THAT GROWS AS ITS LENGTH, SPACED OR
// RIGHT TO LEFT TOO. Each line was set from all the rest of the paragraph
// where its words were right to left, held a right-to-left letter or a
// bidi control, or had a letter or word spacing in them, and a long one in
// a narrow column grew as the square of its length: 2,000 words of `word`
// in 120 pixels gave one-line painters 5,013,000 code units against
// 315,750 for 500, 15.9 times the work for 4 times the words (the css_box
// 0.1.0 review's probe, which this reproduces). Counted as that probe
// counts it -- the code units of every one-line painter made while the
// paragraph is laid out -- and of every painter, whatever its lines: the
// paragraph of all the rest a line is read off ([RenderFloatText]) is one.
import 'package:css_box/css_box.dart';
import 'package:css_box/rendering.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The code units handed to one-line painters, and to every painter,
/// while a paragraph of [n] words of [word] is laid out in 120 pixels.
Future<(int, int)> _work(
  WidgetTester t,
  int n, {
  String word = 'word',
  TextStyle style = const TextStyle(),
  TextDirection direction = TextDirection.ltr,
}) async {
  var oneLine = 0, all = 0;
  void track(ObjectEvent e) {
    if (e is ObjectCreated && e.object is TextPainter) {
      final p = e.object as TextPainter;
      final units = p.text!.toPlainText(includeSemanticsLabels: false).length;
      all += units;
      if (p.maxLines == 1) oneLine += units;
    }
  }

  FlutterMemoryAllocations.instance.addListener(track);
  try {
    await t.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 120,
            child: FloatText(
              TextSpan(text: List.filled(n, word).join(' ')),
              key: UniqueKey(),
              style: const TextStyle(fontSize: 10).merge(style),
              textDirection: direction,
            ),
          ),
        ),
      ),
    );
    expect(t.takeException(), isNull);
  } finally {
    FlutterMemoryAllocations.instance.removeListener(track);
  }
  return (oneLine, all);
}

/// `shalom`, four Hebrew letters.
final _hebrew = String.fromCharCodes(const [0x05E9, 0x05DC, 0x05D5, 0x05DD]);

final _modes = <String, Future<(int, int)> Function(WidgetTester, int)>{
  'plain': (t, n) => _work(t, n),
  'letter spacing': (t, n) => _work(t, n, style: const TextStyle(letterSpacing: 1)),
  'word spacing': (t, n) => _work(t, n, style: const TextStyle(wordSpacing: 3)),
  'right to left': (t, n) => _work(t, n, direction: TextDirection.rtl),
  'hebrew words': (t, n) => _work(t, n, word: _hebrew),
  'hebrew words, right to left': (t, n) => _work(t, n, word: _hebrew, direction: TextDirection.rtl),
  'words in an isolate': (t, n) => _work(t, n, word: String.fromCharCodes(const [0x2067, 0x61, 0x62, 0x2069])),
};

void main() {
  tearDown(() => RenderFloatText.debugWholeRest = false);

  for (final MapEntry(key: mode, value: work) in _modes.entries) {
    testWidgets('$mode: four times the words is about four times the work', (t) async {
      final counts = [
        for (final n in const [500, 1000, 2000]) await work(t, n),
      ];
      final oneLine = counts.last.$1 / counts.first.$1, all = counts.last.$2 / counts.first.$2;
      final said = '$mode: code units for 500/1000/2000 words, one-line painters and every painter: $counts';
      expect(oneLine, lessThan(5), reason: said);
      expect(all, lessThan(5), reason: said);
    });
  }

  testWidgets('NEGATIVE: set from all the rest at every line, as before, the work grows as the square', (t) async {
    // The count reads the work: the old way it is the review's numbers.
    RenderFloatText.debugWholeRest = true;
    for (final mode in const ['letter spacing', 'right to left']) {
      final counts = [
        for (final n in const [500, 2000]) await _modes[mode]!(t, n),
      ];
      expect(counts.map((c) => c.$1), [315750, 5013000], reason: mode);
    }
  });
}
