/// The colour functions of CSS `filter`, as matrices.
library;

import 'dart:math' as math;
import 'dart:ui' show ColorFilter;

/// A matrix on a colour's sRGB channels: one of the colour functions of
/// CSS `filter` (filter-effects-1 13.1), or a run of them --
/// `grayscale(1) contrast(1.2)` is
/// `ColorMatrix.grayscale(1).then(ColorMatrix.contrast(1.2))`. Row-major
/// 4x5, as [ColorFilter.matrix] takes it, with the offsets on the 0..255
/// scale.
class ColorMatrix {
  const ColorMatrix(this.values);

  final List<double> values;

  /// Towards the colour's luminance: `1` is all the way.
  factory ColorMatrix.grayscale(double amount) {
    final a = 1 - amount;
    return ColorMatrix._rgb([
      0.2126 + 0.7874 * a, 0.7152 - 0.7152 * a, 0.0722 - 0.0722 * a, //
      0.2126 - 0.2126 * a, 0.7152 + 0.2848 * a, 0.0722 - 0.0722 * a,
      0.2126 - 0.2126 * a, 0.7152 - 0.7152 * a, 0.0722 + 0.9278 * a,
    ]);
  }

  /// Towards the brown of an old photograph: `1` is all the way.
  factory ColorMatrix.sepia(double amount) {
    final a = 1 - amount;
    return ColorMatrix._rgb([
      0.393 + 0.607 * a, 0.769 - 0.769 * a, 0.189 - 0.189 * a, //
      0.349 - 0.349 * a, 0.686 + 0.314 * a, 0.168 - 0.168 * a,
      0.272 - 0.272 * a, 0.534 - 0.534 * a, 0.131 + 0.869 * a,
    ]);
  }

  /// The colour's saturation times [s]: `0` is grey, `1` is unchanged.
  factory ColorMatrix.saturate(double s) => ColorMatrix._rgb([
    0.213 + 0.787 * s, 0.715 - 0.715 * s, 0.072 - 0.072 * s, //
    0.213 - 0.213 * s, 0.715 + 0.285 * s, 0.072 - 0.072 * s,
    0.213 - 0.213 * s, 0.715 - 0.715 * s, 0.072 + 0.928 * s,
  ]);

  /// The hue turned by [degrees].
  factory ColorMatrix.hueRotate(double degrees) {
    final c = math.cos(degrees * math.pi / 180), s = math.sin(degrees * math.pi / 180);
    return ColorMatrix._rgb([
      0.213 + c * 0.787 - s * 0.213,
      0.715 - c * 0.715 - s * 0.715,
      0.072 - c * 0.072 + s * 0.928, //
      0.213 - c * 0.213 + s * 0.143,
      0.715 + c * 0.285 + s * 0.140,
      0.072 - c * 0.072 - s * 0.283,
      0.213 - c * 0.213 - s * 0.787,
      0.715 - c * 0.715 + s * 0.715,
      0.072 + c * 0.928 + s * 0.072,
    ]);
  }

  /// Each channel towards its opposite: `1` is all the way.
  factory ColorMatrix.invert(double amount) =>
      ColorMatrix._rgb([1 - 2 * amount, 0, 0, 0, 1 - 2 * amount, 0, 0, 0, 1 - 2 * amount], 255 * amount);

  /// Each channel times [b].
  factory ColorMatrix.brightness(double b) => ColorMatrix._rgb([b, 0, 0, 0, b, 0, 0, 0, b]);

  /// Each channel pushed away from the middle grey by [k].
  factory ColorMatrix.contrast(double k) => ColorMatrix._rgb([k, 0, 0, 0, k, 0, 0, 0, k], 255 * (0.5 - 0.5 * k));

  /// The alpha times [a].
  factory ColorMatrix.opacity(double a) => ColorMatrix([1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, a, 0]);

  static ColorMatrix _rgb(List<double> m, [double offset = 0]) => ColorMatrix([
    m[0], m[1], m[2], 0, offset, //
    m[3], m[4], m[5], 0, offset,
    m[6], m[7], m[8], 0, offset,
    0, 0, 0, 1, 0,
  ]);

  /// This matrix, and then [next] on what it gives.
  ColorMatrix then(ColorMatrix next) {
    final a = next.values, b = values;
    return ColorMatrix([
      for (var r = 0; r < 4; r++)
        for (var k = 0; k < 5; k++)
          a[r * 5] * b[k] +
              a[r * 5 + 1] * b[5 + k] +
              a[r * 5 + 2] * b[10 + k] +
              a[r * 5 + 3] * b[15 + k] +
              (k == 4 ? a[r * 5 + 4] : 0),
    ]);
  }

  ColorFilter toFilter() => ColorFilter.matrix(values);
}
