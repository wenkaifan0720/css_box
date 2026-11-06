/// A page that is a different page on each side of a breakpoint.
///
/// A stylesheet's media queries change a page at window widths -- a nav
/// that is a menu button below 768 and a row of links from 768 on -- and a
/// page drawn from one window's rules is that window's page only. So where
/// the pages of two bands differ, the code picks by the window's width, and
/// only there: `padding: context.band({0: EdgeInsets.all(12), 768:
/// EdgeInsets.all(24)})`, `if (context.widthFrom(768)) links`. A band is
/// keyed by its least width, so `{0: a, 768: b}` is `a` in a window
/// narrower than 768 and `b` in one 768 wide or wider, as `(min-width:
/// 768px)` is.
///
/// Each reads the window off `MediaQuery`, so a widget that asks is built
/// again when the window changes size.
library;

import 'package:flutter/widgets.dart';

/// The band a window's width is in, asked of a [BuildContext].
extension WidthBands on BuildContext {
  /// The value for the band the window's width is in: [values] keyed by
  /// each band's least width, in ascending order. A window narrower than
  /// the first key takes the first value.
  T band<T>(Map<double, T> values) {
    final width = MediaQuery.sizeOf(this).width;
    late T out;
    var first = true;
    for (final MapEntry(:key, :value) in values.entries) {
      if (!first && width < key) break;
      out = value;
      first = false;
    }
    if (first) throw ArgumentError.value(values, 'values', 'no band');
    return out;
  }

  /// Whether the window is [width] wide or wider.
  bool widthFrom(double width) => MediaQuery.sizeOf(this).width >= width;

  /// Whether the window is narrower than [width].
  bool widthBelow(double width) => MediaQuery.sizeOf(this).width < width;

  /// [content] as the band the window is in holds it: each of [wrappers],
  /// keyed as for [band], builds the widget round it. A card whose padding
  /// changes at 768 is one card in two frames, not two cards. A wrapper
  /// names the type it takes (`(Widget c) => Padding(..., child: c)`): the
  /// map is typed before the content is.
  W wrap<C, W>(C content, Map<double, W Function(C content)> wrappers) => band(wrappers)(content);
}
