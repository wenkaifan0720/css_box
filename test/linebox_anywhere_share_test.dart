// A LINE THAT MAY BREAK A WORD ANYWHERE IS AS NARROW AS ITS WIDEST GRAPHEME.
// `overflow-wrap: anywhere` breaks a word too long for its line between
// any two of its grapheme clusters, and the soft wrap opportunities it
// brings count toward the min-content size (css-text-3 5.5) -- where
// `break-word`'s do not. A fit-content box is min(max(min-content, room),
// max-content) (css-sizing-3 5.1), so in a room wider than one letter it
// is the room, and the word breaks inside it. A product site's footer links in a
// 60px column of `align-items: flex-start` (`fixtures/shrink-line-text`
// n2): Chrome sets `Cookie Preferences` 60 x 72, three lines, `Preferences`
// broken, and the link under it 72 down.
//
// p1: the box round a line box that breaks anywhere ([LineBox.anywhere])
// is Chrome's 60 x 72, and the box under it 72 down; the line box's least
// is its widest grapheme as the run shaped it, plain and tracked, and a
// widget on the line at its own least where that is wider.
// NEGATIVE (n1): a line box that breaks a word only where it overflows
// (`break-word`, the line box as the lowering wrote it before) is the
// paragraph's least, `Preferences`, 91.5 x 48 -- which is Chrome's for
// `break-word`; a text that never wraps is its whole line, anywhere or not.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:css_box/css_box.dart';
import 'package:css_box/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _style = TextStyle(fontFamily: 'Fx', fontSize: 16, leadingDistribution: TextLeadingDistribution.even);
const _tracked = TextStyle(
  fontFamily: 'Fx',
  fontSize: 16,
  letterSpacing: 0.8,
  leadingDistribution: TextLeadingDistribution.even,
);
const _strut = StrutStyle(
  fontFamily: 'Fx',
  fontSize: 16,
  height: 24 / 16,
  leading: 0,
  leadingDistribution: TextLeadingDistribution.even,
  forceStrutHeight: true,
);
const _link = ValueKey('link'), _next = ValueKey('next');

/// The widest grapheme of [text] in [style], each where the run shaped it.
double _widestGrapheme(String text, TextStyle style) {
  final p = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
  )..layout();
  var widest = 0.0;
  for (var i = 0; i < text.length; i++) {
    if (text[i] == ' ') continue;
    for (final b in p.getBoxesForSelection(TextSelection(baseOffset: i, extentOffset: i + 1))) {
      widest = math.max(widest, b.right - b.left);
    }
  }
  p.dispose();
  return widest;
}

/// The link [line] in a 60px column with `align-items: flex-start`, a
/// fit-content box that spills its least past the room, and a box after.
Widget _column(Widget line) => Directionality(
  textDirection: TextDirection.ltr,
  child: Align(
    alignment: Alignment.topLeft,
    child: SizedBox(
      width: 60,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShrinkWidth(
            spill: true,
            atHeight: true,
            child: KeyedSubtree(key: _link, child: line),
          ),
          const SizedBox(key: _next, width: 60, height: 48),
        ],
      ),
    ),
  ),
);

Future<(Size, double)> _laid(WidgetTester t, Widget line) async {
  await t.pumpWidget(_column(line));
  final link = t.renderObject<RenderBox>(find.byKey(_link));
  final next = t.renderObject<RenderBox>(find.byKey(_next));
  return (link.size, next.localToGlobal(Offset.zero).dy - link.localToGlobal(Offset.zero).dy);
}

void main() {
  setUpAll(() async {
    final bytes = Uint8List.fromList(File('test/fonts/Inter.ttf').readAsBytesSync());
    await (FontLoader('Fx')..addFont(Future.value(ByteData.view(bytes.buffer)))).load();
  });

  const text = 'Cookie Preferences';
  testWidgets('a line box that breaks anywhere is as narrow as its widest grapheme (p1)', (t) async {
    final (size, below) = await _laid(
      t,
      const LineBox(
        keepWords: false,
        anywhere: true,
        child: Text(text, style: _style, strutStyle: _strut),
      ),
    );
    expect(size, const Size(60, 72));
    expect(below, 72);
    // Its least, plain and tracked; and a widget wider than any letter.
    for (final style in [_style, _tracked]) {
      await t.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: LineBox(keepWords: false, anywhere: true, child: Text(text, style: style)),
          ),
        ),
      );
      final least = t.renderObject<RenderLineBox>(find.byType(LineBox)).getMinIntrinsicWidth(double.infinity);
      expect(least, closeTo(_widestGrapheme(text, style), 1e-3), reason: '${style.letterSpacing}');
      expect(least, lessThan(20));
    }
    await t.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: LineBox(
            keepWords: false,
            anywhere: true,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: 'Font '),
                  WidgetSpan(child: SizedBox(width: 40, height: 10)),
                ],
              ),
              style: _style,
            ),
          ),
        ),
      ),
    );
    expect(t.renderObject<RenderLineBox>(find.byType(LineBox)).getMinIntrinsicWidth(double.infinity), 40);
  });

  testWidgets('NEGATIVE: a word broken only where it overflows, and a line that never wraps (n1)', (t) async {
    final most = (TextPainter(
      text: const TextSpan(text: 'Preferences', style: _style),
      textDirection: TextDirection.ltr,
    )..layout()).maxIntrinsicWidth;
    final (size, below) = await _laid(
      t,
      const LineBox(
        keepWords: false,
        child: Text(text, style: _style, strutStyle: _strut),
      ),
    );
    expect(size.width, closeTo(most, 1e-3));
    expect(size.width, closeTo(91.546875, 0.01));
    expect(size.height, 48);
    expect(below, 48);
    await t.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: LineBox(keepWords: false, anywhere: true, child: Text(text, softWrap: false, style: _style)),
        ),
      ),
    );
    final whole = (TextPainter(
      text: const TextSpan(text: text, style: _style),
      textDirection: TextDirection.ltr,
    )..layout()).maxIntrinsicWidth;
    expect(
      t.renderObject<RenderLineBox>(find.byType(LineBox)).getMinIntrinsicWidth(double.infinity),
      closeTo(whole, 1e-3),
    );
  });
}
