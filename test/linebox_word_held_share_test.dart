// A WORD WIDER THAN ITS LINE HANGS OUT OF IT WHOLE (`overflow-wrap:
// normal`, css-text-3 5.5), alone on its line and at its start (css-text-3
// 7.1), the words after it on the next (CSS 2.1 9.4.2). css_box's `LineBox`
// keeps it whole by laying the WHOLE paragraph out at its width, and the
// other words fill fewer lines than CSS's: a Japanese news site's headline beside its
// picture, 4 lines for Chrome's 6 (fixtures/float-room-bfc n4). The lowerer
// writes the word in a `WidgetSpan` on the baseline round a `Text` that
// never wraps (`tidy.dart`, `_heldOver`); Skia breaks before a box that
// does not fit and never inside one.
//
// This pins that spelling to CSS's lines, measured as Skia sets them
// (fixtures/linebox-word-held p1, p2): every word's box, the paragraph's
// height, its least and greatest widths and its height asked, at rooms from
// the widest bare word up past the whole line, left, centred and right.
// NEGATIVE: the line box itself, whose lines are fewer (n1), and a word a
// line breaks inside, `well-known` (UAX #14 HY), which a box would not (n2).
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:css_box/css_box.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

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

/// The paragraph [words] as the lowerer writes it, each of [held] in a box
/// of its own (keyed here to find it; the key lays nothing out).
Widget _held(List<String> words, Set<String> held, TextAlign align, {Key? key}) {
  final spans = <InlineSpan>[];
  final run = StringBuffer();
  void flush() {
    if (run.isNotEmpty) spans.add(TextSpan(text: '$run'));
    run.clear();
  }

  for (final (i, w) in words.indexed) {
    if (i > 0) run.write(' ');
    if (!held.contains(w)) {
      run.write(w);
      continue;
    }
    flush();
    spans.add(
      WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: Text(
          w,
          key: ValueKey('held $i'),
          softWrap: false,
          overflow: TextOverflow.visible,
          textScaler: TextScaler.noScaling,
          style: _style,
          strutStyle: _strut,
        ),
      ),
    );
  }
  flush();
  return Text.rich(
    TextSpan(children: spans),
    key: key,
    textAlign: align,
    style: _style,
    strutStyle: _strut,
  );
}

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
/// the paragraph's alignment, one under another.
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

/// Every word's glyph box, global, in the order [words] has them.
List<Rect> _boxes(RenderParagraph p, List<String> words, Set<String> held, WidgetTester t) {
  final out = <Rect>[];
  var at = 0;
  for (final (i, w) in words.indexed) {
    if (held.contains(w)) {
      final inner = t.renderObject<RenderParagraph>(
        find.descendant(of: find.byKey(ValueKey('held $i')), matching: find.byType(RichText)),
      );
      out.add(_union(inner, 0, w.length));
      at += 1;
    } else {
      out.add(_union(p, at, at + w.length));
      at += w.length;
    }
    at += 1; // the space
  }
  return out;
}

Rect _union(RenderParagraph p, int from, int to) {
  final boxes = p.getBoxesForSelection(TextSelection(baseOffset: from, extentOffset: to));
  var r = boxes.first.toRect();
  for (final b in boxes.skip(1)) {
    r = r.expandToInclude(b.toRect());
  }
  return r.shift(p.localToGlobal(Offset.zero));
}

/// How far apart the lowerer's paragraph and CSS's lines are in [room]:
/// every word's box, the paragraph's height, and its answers asked.
Future<(double, String)> _apart(
  WidgetTester t,
  List<String> words,
  Set<String> held,
  double room,
  TextAlign align,
) async {
  const key = ValueKey('paragraph');
  await t.pumpWidget(_host(room, _held(words, held, align, key: key)));
  final para = t.renderObject<RenderParagraph>(
    find.descendant(of: find.byKey(key), matching: find.byType(RichText)).first,
  );
  final got = _boxes(para, words, held, t);
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
  check(most - _width(words.join(' ')), 'most $most');
  return worst;
}

void main() {
  setUpAll(() async {
    final bytes = Uint8List.fromList(File('test/fonts/Inter.ttf').readAsBytesSync());
    await (FontLoader('Fx')..addFont(Future.value(ByteData.view(bytes.buffer)))).load();
  });

  const headline = ['Explore', 'incomprehensible', 'AI', 'Plays', 'for', 'every', 'team'];
  const two = ['An', 'incomprehensible', 'unbelievable', 'thing', 'was', 'here'];
  final cases = <String, (List<String>, Set<String>)>{
    "the Japanese news site's headline, one word set apart (p1)": (headline, {'incomprehensible'}),
    'two words set apart side by side (p2)': (two, {'incomprehensible', 'unbelievable'}),
  };
  for (final MapEntry(key: name, value: (words, held)) in cases.entries) {
    testWidgets(
      'a paragraph with each word wider than its least room in a box of its own is set as CSS sets it: $name',
      (t) async {
        // From the widest of the words left bare -- the least room they are
        // set apart for -- to past the whole line.
        final floor = words.where((w) => !held.contains(w)).map(_width).reduce(math.max);
        var worst = (0.0, '');
        for (final align in [TextAlign.start, TextAlign.center, TextAlign.right]) {
          for (final room in [floor, 68.0, 100.0, 140.0, 151.0, 152.0, 200.0, 260.0, 300.0, 440.0, 600.0]) {
            if (room < floor) continue;
            final d = await _apart(t, words, held, room, align);
            if (d.$1 > worst.$1) worst = (d.$1, '$align at $room: ${d.$2}');
          }
        }
        expect(worst.$1, lessThan(1e-3), reason: worst.$2);
      },
    );
  }

  testWidgets('NEGATIVE: the line box keeps the word whole by widening every line (n1)', (t) async {
    // At 68 CSS sets 6 lines; the line box lays the paragraph out at 151.34
    // and sets 4.
    await t.pumpWidget(
      _host(
        68,
        LineBox(
          child: Text(headline.join(' '), style: _style, strutStyle: _strut),
        ),
      ),
    );
    expect(t.getSize(find.byType(LineBox)).height, 4 * _lh);
    expect(_cssLines(headline, 68).length, 6);
    await t.pumpWidget(_host(68, _held(headline, {'incomprehensible'}, TextAlign.start, key: const ValueKey('p'))));
    expect(t.getSize(find.byKey(const ValueKey('p'))).height, 6 * _lh);
  });

  testWidgets('NEGATIVE: a word a line breaks inside is no box (n2)', (t) async {
    // `well-known` breaks after its hyphen (UAX #14 HY), as Skia breaks it
    // bare: in a box it stays whole and hangs out of a line it would have
    // shared.
    const words = ['a', 'well-known', 'word'];
    final room = _width('well-') + 1;
    await t.pumpWidget(
      _host(room, Text(words.join(' '), key: const ValueKey('bare'), style: _style, strutStyle: _strut)),
    );
    final bare = t.getSize(find.byKey(const ValueKey('bare'))).height;
    await t.pumpWidget(_host(room, _held(words, {'well-known'}, TextAlign.start, key: const ValueKey('held'))));
    final held = t.getSize(find.byKey(const ValueKey('held'))).height;
    expect(bare, isNot(held));
  });
}
