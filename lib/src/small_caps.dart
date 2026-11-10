/// Small capitals a face does not have, made up as a browser makes them.
library;

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// `font-variant: small-caps` (and `petite-caps`, `all-small-caps`,
/// `all-petite-caps`) in a face that has no small capitals of its own
/// (css-fonts-4 6.4, `font-synthesis-small-caps: auto`). A face turns the
/// OpenType `smcp` or `pcap` feature on where it has the glyphs; one that
/// has none draws the text as written, and a browser makes the capitals
/// up instead: each letter that changes when uppercased is drawn as its
/// capital in the same face at a smaller size, and everything else at the
/// text's own size. Under the `all-` values ([all]) the capitals, digits,
/// spaces and punctuation are drawn at the smaller size too, so the whole
/// run is small capitals. Blink makes the smaller face at 0.7 of the size,
/// rounded to a whole pixel -- 11 for 16px text -- which is the [size] to
/// give.
///
/// The span is a [TextSpan] whose [text] stays the string the page holds:
/// `SmallCapsSpan(text: 'oct 31, 2026', size: 11)` draws `OCT` at 11 and
/// ` 31, 2026` at the paragraph's size, and reads back as `oct 31, 2026`
/// wherever the paragraph's text is read (selection, semantics). The
/// capitals stand on the paragraph's baseline, and a [TextStyle.height]
/// multiplier carries over to them, so a smaller run reaches no further up
/// or down than the text round it. A letter whose capital is more than one
/// character (`ß`) is drawn as written, so the text the paragraph lays out
/// is as long as [text].
class SmallCapsSpan extends TextSpan {
  const SmallCapsSpan({
    required String super.text,
    required this.size,
    this.all = false,
    super.style,
    super.recognizer,
    super.mouseCursor,
    super.onEnter,
    super.onExit,
    super.semanticsLabel,
    super.locale,
    super.spellOut,
  });

  /// The size the small capitals are drawn at.
  final double size;

  /// Whether the whole run is small capitals (`all-small-caps`,
  /// `all-petite-caps`), not only the letters uppercasing changes.
  final bool all;

  /// [text] as the runs it is drawn in: each stretch of letters that
  /// uppercasing changes, uppercased and small, and each of the rest as
  /// written -- under [all], every character uppercased and small.
  List<(String, bool)> get runs {
    final out = <(String, bool)>[];
    final run = StringBuffer();
    bool? shrunk;
    for (final r in text!.runes) {
      final ch = String.fromCharCode(r);
      final up = ch.toUpperCase();
      final same = up.length == ch.length;
      final shrink = all || same && up != ch;
      if (shrunk != null && shrunk != shrink) {
        out.add((run.toString(), shrunk));
        run.clear();
      }
      shrunk = shrink;
      run.write(same ? up : ch);
    }
    if (run.isNotEmpty) out.add((run.toString(), shrunk!));
    return out;
  }

  @override
  void build(
    ui.ParagraphBuilder builder, {
    TextScaler textScaler = TextScaler.noScaling,
    List<PlaceholderDimensions>? dimensions,
  }) {
    final hasStyle = style != null;
    if (hasStyle) builder.pushStyle(style!.getTextStyle(textScaler: textScaler));
    final small = TextStyle(fontSize: size).getTextStyle(textScaler: textScaler);
    for (final (t, shrunk) in runs) {
      if (shrunk) builder.pushStyle(small);
      builder.addText(t);
      if (shrunk) builder.pop();
    }
    if (hasStyle) builder.pop();
  }

  @override
  RenderComparison compareTo(InlineSpan other) {
    final result = super.compareTo(other);
    if (result == RenderComparison.layout || other is! SmallCapsSpan) return result;
    return other.size == size && other.all == all ? result : RenderComparison.layout;
  }

  @override
  bool operator ==(Object other) => other is SmallCapsSpan && other.size == size && other.all == all && super == other;

  @override
  int get hashCode => Object.hash(super.hashCode, size, all);

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(DoubleProperty('size', size))
      ..add(FlagProperty('all', value: all, ifTrue: 'all'));
  }
}
