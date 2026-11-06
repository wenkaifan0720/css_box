/// The breaks a paragraph set `text-wrap: pretty` is laid out on.
library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'balance.dart';

/// A block whose last line is not left holding one short word
/// (`text-wrap: pretty`, css-text-4 8.2).
///
/// Blink breaks the paragraph greedily and then, where the last line holds
/// ONE word narrower than a THIRD of the room, re-breaks the last FOUR
/// lines: of every set of breaks over them that takes the same number of
/// lines and leaves at least two words on the last, the one whose OTHER
/// lines leave the least room over, summed as squares -- the last line is
/// free. A widow wider than a third, or a last line of two words however
/// short, is left alone, and so are the lines before the last four. That
/// is read off a real Chrome over 1,535 paragraphs (`text-wrap-pretty-
/// breaks` fixture, `harness/test/pretty_test.dart`): every one-word last
/// line under a third moved and no other did, 1,529 to the set this names
/// and the rest to one scoring within a pixel of it. (Minimising the
/// squares WITHOUT the two-word floor leaves every paragraph greedy, since
/// a greedy line already leaves the least room over on its own.)
///
/// Like [Balance], the line count never changes: the block is exactly as
/// tall as the greedy one, nothing around it moves, and its greatest width
/// is the greedy one. A pricing page's plan cards, a clothing store's product
/// copy and a framework site's feature blurbs are set this way, and each held a
/// widow the browser had pulled a word down to.
class Pretty extends SingleChildRenderObjectWidget {
  const Pretty({super.key, super.child});

  @override
  RenderPretty createRenderObject(BuildContext context) => RenderPretty();
}

/// The render object behind [Pretty].
class RenderPretty extends RenderBalance {
  RenderPretty({super.child});

  /// Blink re-breaks the last four lines, however many there are.
  static const int tail = 4;

  @override
  int get lineCap => 1 << 20;

  /// Every paragraph a forced break ends is made pretty on its own.
  @override
  bool get everyParagraph => true;

  @override
  List<int>? cuts(List<(int, int)> opp, double Function(int) x, double room, int lines, {double? firstRoom}) =>
      prettyCuts(opp, x, room, lines, firstRoom: firstRoom);

  /// [cuts] as [Pretty] takes them, for a box that sets its own lines. A
  /// FIRST LINE OF A ROOM OF ITS OWN (`text-indent`) is broken greedily in
  /// that room and scored against it where the tail reaches it: 61 of 61
  /// Chrome paragraphs hung by -6 to -24px agree
  /// (`fixtures/indent-hanging-pretty`).
  static List<int>? prettyCuts(
    List<(int, int)> opp,
    double Function(int) x,
    double room,
    int lines, {
    double? firstRoom,
  }) {
    double width(int i, int j) => x(opp[j - 1].$1) - x(i == 0 ? 0 : opp[i - 1].$2);
    double roomOf(int line) => line == 0 ? firstRoom ?? room : room;
    // The greedy break: each line takes what fits, and one unbreakable
    // stretch hangs out where nothing does.
    final greedy = <int>[];
    var start = 0;
    while (start < opp.length) {
      var j = start + 1;
      while (j < opp.length && width(start, j + 1) <= roomOf(greedy.length)) {
        j++;
      }
      greedy.add(j);
      start = j;
    }
    final n = greedy.length;
    // The same count Skia found, or the block would change height.
    if (n < 2 || n != lines) return null;
    // The trigger: one word on the last line, under a third of the room.
    final lastStart = greedy[n - 2];
    if (opp.length - lastStart != 1 || width(lastStart, opp.length) >= roomOf(n - 1) / 3) return null;
    // The tail: the last four lines, re-broken over the same count.
    final k = math.min(tail, n);
    final from0 = n == k ? 0 : greedy[n - k - 1];
    const huge = double.infinity;
    final f = List.generate(k + 1, (_) => List<double>.filled(opp.length + 1, huge));
    final prev = List.generate(k + 1, (_) => List<int>.filled(opp.length + 1, -1));
    f[0][from0] = 0;
    for (var line = 1; line <= k; line++) {
      final last = line == k;
      for (var j = from0 + line; j <= opp.length; j++) {
        if (last != (j == opp.length)) continue;
        for (var i = from0 + line - 1; i < j; i++) {
          if (f[line - 1][i] == huge) continue;
          // The last line holds two words at least; it costs nothing.
          if (last && j - i < 2) continue;
          final w = width(i, j), r = roomOf(n - k + line - 1);
          if (w > r && j - i > 1) continue;
          final hyphen = !last && opp[j - 1].$1 == opp[j - 1].$2;
          final over = r - w;
          final cost = f[line - 1][i] + (last ? 0 : over * over + (hyphen ? room * room / 400 : 0));
          if (cost < f[line][j]) {
            f[line][j] = cost;
            prev[line][j] = i;
          }
        }
      }
    }
    if (f[k][opp.length] == huge) return null;
    final cuts = <int>[];
    var j = opp.length;
    for (var line = k; line > 0; line--) {
      cuts.add(j);
      j = prev[line][j];
    }
    for (var h = n - k - 1; h >= 0; h--) {
      cuts.add(greedy[h]);
    }
    cuts.add(0);
    return cuts;
  }
}
