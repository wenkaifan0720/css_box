import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

/// [m] on an sRGB colour of 0..255 channels.
List<double> _apply(ColorMatrix m, List<double> rgba) => [
  for (var r = 0; r < 4; r++)
    m.values[r * 5] * rgba[0] +
        m.values[r * 5 + 1] * rgba[1] +
        m.values[r * 5 + 2] * rgba[2] +
        m.values[r * 5 + 3] * rgba[3] +
        m.values[r * 5 + 4],
];

void main() {
  test('grayscale(1) is the luminance, and grayscale(0) the colour', () {
    final grey = _apply(ColorMatrix.grayscale(1), [255, 0, 0, 255]);
    expect(grey[0], closeTo(0.2126 * 255, 1e-9));
    expect(grey[1], closeTo(0.2126 * 255, 1e-9));
    expect(grey[3], 255);
    expect(_apply(ColorMatrix.grayscale(0), [10, 20, 30, 255]), [10, 20, 30, 255]);
  });

  test('invert(1) turns each channel over, and keeps the alpha', () {
    expect(_apply(ColorMatrix.invert(1), [255, 0, 100, 128]), [0, 255, 155, 128]);
  });

  test('a run of functions is applied in the order written', () {
    // brightness(0.5) then contrast(2): 200 -> 100 -> 2 * 100 - 127.5.
    final m = ColorMatrix.brightness(0.5).then(ColorMatrix.contrast(2));
    expect(_apply(m, [200, 200, 200, 255])[0], closeTo(72.5, 1e-9));
    // And the other way round: 200 -> 272.5 -> 136.25.
    final n = ColorMatrix.contrast(2).then(ColorMatrix.brightness(0.5));
    expect(_apply(n, [200, 200, 200, 255])[0], closeTo(136.25, 1e-9));
  });

  test('opacity scales the alpha alone', () {
    expect(_apply(ColorMatrix.opacity(0.5), [10, 20, 30, 200]), [10, 20, 30, 100]);
  });
}
