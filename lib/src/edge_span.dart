/// An inline box's margin, border and padding on a line, as text.
library;

import 'package:flutter/painting.dart';

/// [width] of room an inline box's edge takes on a line, as a span that
/// breaks where CSS breaks round it. A placeholder does not: Skia breaks
/// before and after every `WidgetSpan`, where Blink breaks a line only where
/// its TEXT may break (UAX #14) and the edge goes with the word it touches.
///
/// The room is TRACKING, on characters with no advance and no height of
/// their own (a size of a hundredth of a pixel):
///
/// - by default two no-break spaces, the second tracked by [width]. A
///   no-break space glues to the word before it and the word after it and
///   still lets a line break after a space; the first is untracked because
///   Skia puts half a character's tracking in front of a line that starts
///   on it, and this one may.
/// - [hangs]: one space, tracked by [width], for an edge of a box that
///   holds nothing, where nothing but such boxes follow it to the
///   paragraph's end. Chrome never breaks before one -- where the text fits
///   and the edge does not, the line keeps both and the edge overflows
///   (measured in Chrome 151), where a box's end edge after its last word
///   takes the word down -- and Skia hangs a trailing space past the line's
///   end the same way. It
///   counts in the paragraph's max-content width, as the edge does, and not
///   in the width `text-align` places, which is why a line centred or set
///   to the right keeps a placeholder instead.
InlineSpan edgeSpan(double width, {bool hangs = false}) => hangs
    ? TextSpan(
        text: ' ',
        style: TextStyle(fontSize: _none, letterSpacing: width),
      )
    : TextSpan(
        style: const TextStyle(fontSize: _none),
        children: [
          const TextSpan(text: ' ', style: TextStyle(letterSpacing: 0)),
          TextSpan(
            text: ' ',
            style: TextStyle(letterSpacing: width),
          ),
        ],
      );

/// [width] of room `text-indent` takes in front of a block's first line
/// (css-text-3 8.1): the two no-break spaces [edgeSpan] sets, for the same
/// two reasons -- they glue the indent to the first word as CSS does, and
/// the first is untracked because Skia puts half a character's tracking in
/// front of a line that starts on it. [width] is positive: Skia counts
/// negative tracking at a line's start as room but draws the first glyph
/// at the edge all the same, so a hanging line would run off its end.
InlineSpan indentSpan(double width) => edgeSpan(width);

const double _none = 0.01;
