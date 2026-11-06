/// `flex-wrap: balance` (css-flexbox-2 5.2 and 9.3 step 5): which items of
/// a `FlexLine` go on which line when the lines are BALANCED.
///
/// A balanced box makes as many lines as plain wrapping would -- the
/// `flex-line-count` it states where that is more, and never more than
/// one per item -- and divides its items into that many runs, in the
/// order they are written, so the lines are as alike in length as they
/// can be: the least sum of their squared lengths, ties going to the
/// division with the most items on its earliest lines. No run of two or
/// more items is longer than the line, a run always holds one item, and an
/// item of no length stays at the end of the run before it where a
/// division allows it. A dynamic program over (lines, first item of what is
/// left), with the divide-and-conquer optimisation, all in doubles -- the
/// `balance` module of Taffy's `compute/flexbox.rs`, which is what the
/// layout engine does too.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart' show internal;

/// Score of a division that violates the line size constraint.
const double _infeasible = double.infinity;

/// An item size in px to a non-negative finite size (Taffy clamps to
/// `f32::MAX`; the value only has to stay summable).
double _toSize(double v) {
  if (v.isNaN || v < 0) return 0;
  if (v > 3.4028234663852886e38) return 3.4028234663852886e38;
  return v;
}

/// Line sizing shared by the scoring and readback phases.
class _LineSizes {
  /// Per item, the prefix sum of the item sizes through it (each item also
  /// contributes one trailing gap).
  final List<double> sums;

  /// Per item, whether its (floored) size is zero.
  final List<bool> zero;
  final double gapBetweenItems;

  /// The container's inner main size, which lines may not exceed (unless they
  /// hold a single item).
  final double limit;
  _LineSizes(this.sums, this.zero, this.gapBetweenItems, this.limit);

  int get itemCount => sums.length;

  bool isZeroItem(int index) => zero[index];

  /// The size of the line holding items `start..=end`.
  double lineSize(int start, int end) => sums[end] - (start == 0 ? 0.0 : sums[start - 1]) - gapBetweenItems;

  /// The squared size of the line holding items `start..=end`, or
  /// [_infeasible] for a line of more than one item exceeding the limit.
  double lineCost(int start, int end) {
    final size = lineSize(start, end);
    if (end > start && size > limit) return _infeasible;
    return size * size;
  }

  /// For every suffix of the items, the number of lines greedy line breaking
  /// produces for it (the entry for the empty suffix is zero). Also the
  /// fewest lines each suffix can validly be divided into.
  List<int> suffixGreedyLineCounts() {
    final n = itemCount;
    final counts = List<int>.filled(n + 1, 0);
    var lineEnd = n;
    for (var start = n - 1; start >= 0; start--) {
      while (lineEnd > start + 1 && lineSize(start, lineEnd - 1) > limit) {
        lineEnd--;
      }
      counts[start] = 1 + counts[lineEnd];
    }
    return counts;
  }

  /// For every `start`, the largest `end` such that the line `start..=end`
  /// does not exceed the limit (or `start` itself if even that overflows).
  List<int> fitEnds() {
    final n = itemCount;
    final out = <int>[];
    var fitEnd = 0;
    for (var start = 0; start < n; start++) {
      if (fitEnd < start) fitEnd = start;
      while (fitEnd + 1 < n && lineSize(start, fitEnd + 1) <= limit) {
        fitEnd++;
      }
      out.add(fitEnd);
    }
    return out;
  }
}

/// One row of the balancing dynamic program: divisions of item suffixes into
/// exactly `lines` lines.
class _Row {
  final _LineSizes sizes;
  final List<int> fitEnds;

  /// `prev[start]` is the minimum score of any valid division of items
  /// `start..` into exactly `lines - 1` lines ([_infeasible] if none).
  final List<double> prev;

  /// The line ends that precede a non-zero item, ascending, capped to
  /// [maxEnd].
  final List<int> nonzeroEnds;

  /// The largest possible end of the first line.
  final int maxEnd;
  _Row(this.sizes, this.fitEnds, this.prev, this.nonzeroEnds, this.maxEnd);
}

/// Rust's `slice::partition_point` over `list[lo..hi]`: the number of leading
/// elements for which [pred] holds.
int _partitionPoint(List<int> list, int lo, int hi, bool Function(int) pred) {
  var a = lo, b = hi;
  while (a < b) {
    final mid = a + (b - a) ~/ 2;
    if (pred(list[mid])) {
      a = mid + 1;
    } else {
      b = mid;
    }
  }
  return a - lo;
}

/// Compute `cur[start]` and `opts[optsOffset + start]` for `start` in
/// `startLo..=startHi` (Taffy `fill_row`): the minimum over valid ends of
/// `lineCost(start, end) + prev[end + 1]` and the largest end achieving it.
void _fillRow(
  _Row row,
  List<double> cur,
  List<int> opts,
  int optsOffset,
  int startLo,
  int startHi,
  int colLo,
  int colHi,
) {
  if (startLo > startHi) return;
  final start = startLo + (startHi - startLo) ~/ 2;

  // Minimise over the in-range ends preceding a non-zero item, from `start`.
  final firstCol = colLo + _partitionPoint(row.nonzeroEnds, colLo, colHi, (end) => end < start);
  var minCost = _infeasible;
  int? minCol;
  for (var col = firstCol; col < colHi; col++) {
    final end = row.nonzeroEnds[col];
    final lineCost = row.sizes.lineCost(start, end);
    // Every longer line also exceeds the limit.
    if (lineCost == _infeasible) break;
    final cost = lineCost + row.prev[end + 1];
    // `<=` keeps the largest minimising end (most items to the earliest lines).
    if (cost <= minCost) {
      minCost = cost;
      minCol = col;
    }
  }

  // Merge the single end preceding a zero item the zero-sized-item rule allows.
  int? minEnd = minCol == null ? null : row.nonzeroEnds[minCol];
  final zeroEnd = math.min(row.fitEnds[start], row.maxEnd);
  if (row.sizes.isZeroItem(zeroEnd + 1)) {
    final cost = row.sizes.lineCost(start, zeroEnd) + row.prev[zeroEnd + 1];
    if (cost < minCost || (cost == minCost && (minEnd == null || minEnd < zeroEnd))) {
      minCost = cost;
      minEnd = zeroEnd;
    }
  }

  cur[start] = minCost;
  opts[optsOffset + start] = minEnd ?? start;

  // Only the non-zero ends' minima are monotone, so only they narrow the ranges.
  if (start > startLo) {
    final ch = minCol == null ? colHi : minCol + 1;
    _fillRow(row, cur, opts, optsOffset, startLo, start - 1, colLo, ch);
  }
  if (start < startHi) {
    final cl = minCol ?? firstCol;
    _fillRow(row, cur, opts, optsOffset, start + 1, startHi, cl, colHi);
  }
}

/// The number of items on each balanced line: [itemSizes] are the items'
/// lengths along the line, margins in, [lineLimit] the line's own length and
/// [gapBetweenItems] the gap between two items on one line. There are at
/// least [minLineCount] lines, or one item on each where there are fewer
/// items than that. [itemSizes] must not be empty; every count is at least
/// one and together they are the item count (Taffy's
/// `balanced_line_item_counts`).
@internal
List<int> balancedLineItemCounts(List<double> itemSizes, double lineLimit, double gapBetweenItems, int minLineCount) {
  final itemCount = itemSizes.length;
  assert(itemCount > 0);
  final gap = _toSize(gapBetweenItems);
  final limit = lineLimit;

  final sums = <double>[];
  final zero = <bool>[];
  var sum = 0.0;
  for (final raw in itemSizes) {
    final size = _toSize(raw);
    sum += size + gap;
    sums.add(sum);
    zero.add(size == 0.0);
  }
  final sizes = _LineSizes(sums, zero, gap, limit);

  final suffixGreedy = sizes.suffixGreedyLineCounts();
  final lineCount = math.max(suffixGreedy[0], minLineCount.clamp(1, itemCount));

  if (lineCount == itemCount) {
    // One item per line is the only division.
    return List<int>.filled(itemCount, 1);
  }

  final fitEnds = sizes.fitEnds();
  final nonzeroEnds = <int>[];
  for (var end = 0; end < itemCount - 1; end++) {
    if (!sizes.isZeroItem(end + 1)) nonzeroEnds.add(end);
  }

  var prev = List<double>.generate(itemCount, (start) => sizes.lineCost(start, itemCount - 1));
  var cur = List<double>.filled(itemCount, _infeasible);
  final opts = List<int>.filled((lineCount - 1) * itemCount, 0);
  for (var lines = 2; lines <= lineCount; lines++) {
    // The remaining `lines - 1` lines need one item each.
    final maxEnd = itemCount - lines;
    // Starts whose suffix doesn't fit in `lines` lines even greedily are
    // infeasible; they form a prefix.
    var firstStart = 0;
    while (firstStart < maxEnd && suffixGreedy[firstStart] > lines) {
      cur[firstStart] = _infeasible;
      firstStart++;
    }
    final colHi = _partitionPoint(nonzeroEnds, 0, nonzeroEnds.length, (end) => end <= maxEnd);
    final row = _Row(sizes, fitEnds, prev, nonzeroEnds, maxEnd);
    _fillRow(row, cur, opts, (lines - 2) * itemCount, firstStart, maxEnd, 0, colHi);
    final tmp = prev;
    prev = cur;
    cur = tmp;
  }

  // Read the division back out, front to back.
  final itemCounts = <int>[];
  var start = 0;
  for (var lines = lineCount; lines >= 2; lines--) {
    final end = opts[(lines - 2) * itemCount + start];
    itemCounts.add(end - start + 1);
    start = end + 1;
  }
  itemCounts.add(itemCount - start);
  return itemCounts;
}
