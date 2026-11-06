/// The blank half of a fullwidth punctuation glyph, cut where two meet.
library;

import 'package:flutter/foundation.dart' show internal;
import 'package:flutter/painting.dart';

/// `text-spacing-trim: normal` (css-text-4 8.3), which Chrome applies to
/// every line it lays out. A fullwidth Japanese or Chinese punctuation
/// glyph is an em square with its ink in one half -- an opening bracket's
/// on the right, a closing one's or a comma's on the left -- and where two
/// meet, the blank halves between them are cut to one: `、「` closes up,
/// `」。` closes up, `「『` closes up, and a bracket against a kana keeps
/// its blank. Chrome cuts by the font's `chws` feature where the font has
/// one and by its glyph bounds where it has not; Skia cuts nothing, and
/// a Japanese car listing's paragraphs drifted half an em further right at every
/// bracket. The font's `halt` feature (half-width alternates, which
/// Hiragino Sans and Noto Sans JP carry) set on JUST the glyph whose blank
/// is cut draws the same line: the second glyph of the pair where it is an
/// opening bracket, else the first -- one half is left between them
/// whichever halves they are, which is what Chrome measures (a `「` after
/// `、` is 9.5 wide at 19px; the `」` before `。` is).
///
/// The span [Text.rich] takes in the place of [text]; a text with no such
/// pair is one plain span.
TextSpan han(String text, {TextStyle? style}) {
  final n = text.length;
  final cut = List<bool>.filled(n, false);
  var any = false;
  for (var i = 1; i < n; i++) {
    final a = text.codeUnitAt(i - 1), b = text.codeUnitAt(i);
    if (_opens(b) && (_opens(a) || _closes(a))) {
      cut[i] = true;
      any = true;
    } else if (_closes(b) && _closes(a)) {
      cut[i - 1] = true;
      any = true;
    }
  }
  if (!any) return TextSpan(text: text, style: style);
  final halt = style?.fontFeatures == null
      ? _halt
      : TextStyle(fontFeatures: [...style!.fontFeatures!, const FontFeature('halt')]);
  final parts = <TextSpan>[];
  var from = 0;
  for (var i = 1; i <= n; i++) {
    if (i == n || cut[i] != cut[from]) {
      parts.add(TextSpan(text: text.substring(from, i), style: cut[from] ? halt : null));
      from = i;
    }
  }
  return TextSpan(style: style, children: parts);
}

const TextStyle _halt = TextStyle(fontFeatures: [FontFeature('halt')]);

/// Fullwidth opening brackets (JLREQ cl-01): 〈《「『【〔〖〘〚〝（［｛｟｢.
bool _opens(int c) => switch (c) {
  0x3008 || 0x300A || 0x300C || 0x300E || 0x3010 || 0x3014 || 0x3016 || 0x3018 || 0x301A || 0x301D => true,
  0xFF08 || 0xFF3B || 0xFF5B || 0xFF5F || 0xFF62 => true,
  _ => false,
};

/// Whether [c] is a fullwidth closing glyph whose blank half a line may
/// give up where it ends the line (see `InlineFlow`).
@internal
bool hanCloses(int c) => _closes(c);

/// Fullwidth closing brackets, commas and full stops (cl-02, cl-06, cl-07):
/// 〉》」』】〕〗〙〛〞〟）］｝｠｣ and 、。，．
bool _closes(int c) => switch (c) {
  0x3001 || 0x3002 || 0x3009 || 0x300B || 0x300D || 0x300F || 0x3011 || 0x3015 || 0x3017 || 0x3019 => true,
  0x301B || 0x301E || 0x301F || 0xFF09 || 0xFF0C || 0xFF0E || 0xFF3D || 0xFF5D || 0xFF60 || 0xFF63 => true,
  _ => false,
};
