// A WORD WIDER THAN ITS LINE HANGS OUT OF IT WHOLE (`overflow-wrap:
// normal`, css-text-3 5.5), alone on its line and at its start (css-text-3
// 7.1), the words after it on the next (CSS 2.1 9.4.2); Skia breaks it
// between its letters. The app sets such a paragraph through one helper,
// `wholeWords`: EVERY word of letters and digits alone, and
// every number of digit groups a comma or a full stop joins, in a box of
// its own, a `Text` on the baseline that never wraps, and the spaces and
// any other word (`v1.2`) the paragraph's. The sentence stays one string,
// the page's, and the page code calls the helper with it.
//
// This pins the helper, copied here verbatim (an engine test holds the two
// copies equal), to CSS's lines, measured as Skia sets them: every word's
// box, the paragraph's height, its least and greatest widths and its height
// asked, at rooms from the widest word left bare up past the whole line,
// left, centred and right. A web portal's finance headline under its picture (p1),
// a news site's language heading in a panel no wider than its inset, every word
// past a room of nothing (p2: `fixtures/linebox-word-held` p3),
// a Japanese news site's headline beside its picture (p3: `fixtures/float-room-bfc`
// n4), and a date past an 80px column, `20260315`, which no line breaks
// inside (UAX #14 LB25) and the line box set with `at noon` on one line
// for CSS's two (p4: `fixtures/linebox-word-whole` n1), and the same date
// as `20,260,315`, which no line breaks inside either (LB13 and LB25 round
// each comma: p5, `fixtures/linebox-word-number` n1). NEGATIVE: a word
// with any other character in it (`v1.2.30`, which no line breaks inside
// either) stays the paragraph's, and Skia breaks it where CSS would hang
// it -- the lowerer boxes no paragraph with such a word past its room
// (n1); the line box, whose lines are fewer (n2).
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:css_box/css_box.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------- the app's helper, verbatim

/// A WORD WIDER THAN ITS LINE HANGS OUT OF IT WHOLE (`overflow-wrap:
/// normal`, css-text-3 5.5): alone on its line, the words after it on the
/// next. Skia breaks such a word between its letters, and never breaks a
/// box: it starts a new line before one that does not fit, as CSS does
/// before a word. So [text] is set with each word of letters and digits
/// alone (`Tesla`, `75k`), and each number of digit groups a comma or a
/// full stop joins (`20,260,315`), in a box of its own -- a `Text` on the
/// baseline that never wraps, in the paragraph's [style] and [strutStyle]
/// -- and the spaces and every other word (`v1.2`) the paragraph's own. A
/// word that fits sets in its box as it would bare: no line breaks inside
/// such a word (UAX #14 LB23, LB25, LB28; LB13 and LB25 round the
/// separator), and the paragraphs set so kern none of their words against
/// a space.
List<InlineSpan> wholeWords(String text, {required TextStyle style, required StrutStyle strutStyle}) {
  final spans = <InlineSpan>[];
  var run = '';
  for (final (i, word) in text.split(' ').indexed) {
    if (i > 0) run += ' ';
    if (!_alnum.hasMatch(word)) {
      run += word;
      continue;
    }
    if (run.isNotEmpty) spans.add(TextSpan(text: run));
    run = '';
    spans.add(
      WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: Text(
          word,
          softWrap: false,
          overflow: TextOverflow.visible,
          textScaler: TextScaler.noScaling,
          style: style,
          strutStyle: strutStyle,
        ),
      ),
    );
  }
  if (run.isNotEmpty) spans.add(TextSpan(text: run));
  return spans;
}

final _alnum = RegExp(r'^(?:[A-Za-z0-9]+|[0-9]+(?:[,.][0-9]+)+)$');

// ------------------------------------------------------------- the test

/// The Japanese news site's headline, as the lowerer writes its style and strut: 18px
/// Inter on a 21px line.
const _style = TextStyle(fontFamily: 'Fx', fontSize: 18, leadingDistribution: TextLeadingDistribution.even);
const _strut = StrutStyle(
  fontFamily: 'Fx',
  fontSize: 17.8685,
  height: 21 / 17.8685,
  leading: 0,
  leadingDistribution: TextLeadingDistribution.even,
  forceStrutHeight: true,
);
const _lh = 21.0;

/// The paragraph as the page code writes it.
Widget _whole(String text, TextAlign align, {Key? key}) => Text.rich(
  TextSpan(
    children: wholeWords(text, style: _style, strutStyle: _strut),
  ),
  key: key,
  textAlign: align,
  style: _style,
  strutStyle: _strut,
);

double _width(String s) {
  final p = TextPainter(
    text: TextSpan(text: s, style: _style),
    strutStyle: _strut,
    textDirection: TextDirection.ltr,
  )..layout();
  final w = p.width;
  p.dispose();
  return w;
}

/// CSS's lines of [words] in [room]: each line every word that fits after
/// the ones before it, the first whatever its width; the space a line
/// ends at hangs (css-text-3 4.1.3).
List<List<String>> _cssLines(List<String> words, double room) {
  final lines = <List<String>>[];
  for (final w in words) {
    if (lines.isNotEmpty && _width([...lines.last, w].join(' ')) <= room) {
      lines.last.add(w);
    } else {
      lines.add([w]);
    }
  }
  return lines;
}

/// The same lines laid out one by one, each a line that never wraps at
/// the paragraph's alignment -- one too long for the room starts at its
/// start (css-text-3 7.1) -- one under another.
Widget _css(List<List<String>> lines, TextAlign align) => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    for (final (i, l) in lines.indexed)
      SizedBox(
        height: _lh,
        child: Text(
          l.join(' '),
          key: ValueKey('line $i'),
          softWrap: false,
          overflow: TextOverflow.visible,
          textAlign: align,
          style: _style,
          strutStyle: _strut,
        ),
      ),
  ],
);

Widget _host(double room, Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(width: room, child: child),
  ),
);

Rect _union(RenderParagraph p, int from, int to) {
  final boxes = p.getBoxesForSelection(TextSelection(baseOffset: from, extentOffset: to));
  var r = boxes.first.toRect();
  for (final b in boxes.skip(1)) {
    r = r.expandToInclude(b.toRect());
  }
  return r.shift(p.localToGlobal(Offset.zero));
}

/// How far apart the page's paragraph and CSS's lines are in [room]:
/// every word's box, the paragraph's height, and its answers asked.
Future<(double, String)> _apart(WidgetTester t, String text, double room, TextAlign align) async {
  final words = text.split(' ');
  const key = ValueKey('paragraph');
  await t.pumpWidget(_host(room, _whole(text, align, key: key)));
  // The paragraph's own, then each box's in order.
  final paragraphs = find
      .descendant(of: find.byKey(key), matching: find.byType(RichText))
      .evaluate()
      .map((e) => e.renderObject! as RenderParagraph)
      .toList();
  final para = paragraphs.first;
  final got = <Rect>[];
  var at = 0, box = 1;
  for (final w in words) {
    if (_alnum.hasMatch(w)) {
      got.add(_union(paragraphs[box++], 0, w.length));
      at += 1;
    } else {
      got.add(_union(para, at, at + w.length));
      at += w.length;
    }
    at += 1; // the space
  }
  final size = para.size;
  final least = para.getMinIntrinsicWidth(double.infinity), most = para.getMaxIntrinsicWidth(double.infinity);
  final tall = para.getMinIntrinsicHeight(room), dry = para.getDryLayout(BoxConstraints(maxWidth: room));

  final lines = _cssLines(words, room);
  await t.pumpWidget(_host(room, _css(lines, align)));
  final want = <Rect>[];
  for (final (i, l) in lines.indexed) {
    final p = t.renderObject<RenderParagraph>(
      find.descendant(of: find.byKey(ValueKey('line $i')), matching: find.byType(RichText)),
    );
    var at = 0;
    for (final w in l) {
      want.add(_union(p, at, at + w.length));
      at += w.length + 1;
    }
  }
  var worst = (0.0, '');
  void check(double d, String what) {
    if (d.abs() > worst.$1) worst = (d.abs(), what);
  }

  for (final (i, w) in words.indexed) {
    check(got[i].left - want[i].left, '$w left: ${got[i]} vs ${want[i]}');
    check(got[i].right - want[i].right, '$w right');
    check(got[i].top - want[i].top, '$w top');
  }
  check(size.height - lines.length * _lh, 'height ${size.height} for ${lines.length} lines');
  check(tall - lines.length * _lh, 'height asked $tall');
  check(dry.height - size.height, 'dry height ${dry.height}');
  check(least - words.map(_width).reduce(math.max), 'least $least');
  check(most - _width(text), 'most $most');
  return worst;
}

void main() {
  setUpAll(() async {
    final bytes = Uint8List.fromList(File('test/fonts/Inter.ttf').readAsBytesSync());
    await (FontLoader('Fx')..addFont(Future.value(ByteData.view(bytes.buffer)))).load();
  });

  const cases = {
    "the web portal's headline: a number and `75k` in boxes too (p1)":
        'Guy Spends Years Tracking Cost Of Charging Tesla Model 3 For 75k Miles Versus Filling Up Gas Cars',
    "the news site's language heading, every word past its room (p2)": 'Read the News In your own language',
    "the Japanese news site's headline (p3)": 'Explore incomprehensible AI Plays for every team',
    'a date past its room (p4)': 'Updated 20260315 at noon',
    'a number of digit groups past its room (p5)': 'Updated 20,260,315 at noon',
  };
  for (final MapEntry(key: name, value: text) in cases.entries) {
    testWidgets('a paragraph set through `wholeWords` is set as CSS sets it: $name', (t) async {
      // A window wider than the widest room, the web portal's whole line among them.
      t.view
        ..physicalSize = const Size(1200, 900)
        ..devicePixelRatio = 1;
      addTearDown(t.view.reset);
      // Every word here is letters and digits or digit groups, so from a
      // room of nothing, where every word hangs, to past the whole line.
      var worst = (0.0, '');
      for (final align in [TextAlign.left, TextAlign.center, TextAlign.right]) {
        for (final room in [0.0, 1.0, 12.0, 30.0, 68.0, 100.0, 151.0, 200.0, 320.0, 440.0, 900.0]) {
          final d = await _apart(t, text, room, align);
          if (d.$1 > worst.$1) worst = (d.$1, '$align at $room: ${d.$2}');
        }
      }
      expect(worst.$1, lessThan(1e-3), reason: worst.$2);
    });
  }

  testWidgets('NEGATIVE: a word not of letters and digits stays the paragraph\'s, and Skia breaks it where CSS hangs '
      'it (n1)', (t) async {
    // `v1.2.30` past its room: CSS hangs it whole on a line of its own
    // (UAX #14 LB23, LB13, LB25), Skia breaks it between its characters
    // and sets more lines than CSS.
    const text = 'Updated v1.2.30 at noon';
    final room = _width('v1.2.30') - 10;
    final d = await _apart(t, text, room, TextAlign.left);
    expect(d.$1, greaterThan(1), reason: d.$2);
  });

  testWidgets('NEGATIVE: the line box keeps the word whole by widening every line (n2)', (t) async {
    // At 68 CSS sets the Japanese news site's headline in 6 lines; the line box lays the
    // paragraph out at 151.34 and sets 4.
    const text = 'Explore incomprehensible AI Plays for every team';
    await t.pumpWidget(
      _host(
        68,
        LineBox(
          child: Text(text, style: _style, strutStyle: _strut),
        ),
      ),
    );
    expect(t.getSize(find.byType(LineBox)).height, 4 * _lh);
    await t.pumpWidget(_host(68, _whole(text, TextAlign.left, key: const ValueKey('p'))));
    expect(t.getSize(find.byKey(const ValueKey('p'))).height, 6 * _lh);
  });
}
