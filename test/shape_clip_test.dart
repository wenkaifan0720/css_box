import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:css_box/css_box.dart';

void main() {
  test('a percentage radius is a share of the diagonal over root two, centred in the box', () {
    // 200x100: sqrt((40000 + 10000) / 2) = 158.1; half of it is 79.06.
    final path = const CircleClip(radiusShare: 0.5).getClip(const Size(200, 100));
    expect(path.getBounds().width, closeTo(158.11, 0.01));
    expect(path.getBounds().center.dx, closeTo(100, 1e-3));
    expect(path.getBounds().center.dy, closeTo(50, 1e-3));
    // It runs past the short sides and stops short of the long ones.
    expect(path.contains(const Offset(100, 2)), isTrue);
    expect(path.contains(const Offset(10, 50)), isFalse);
  });

  test('a radius and a centre in px', () {
    final path = const CircleClip(radius: 24, center: ClipPoint(x: 30, y: 40)).getClip(const Size(300, 100));
    expect(path.getBounds(), const Rect.fromLTWH(6, 16, 48, 48));
  });

  test('a radius to the side a keyword names is how far the centre is from it', () {
    // At 30% 40% of 200x100: 60 from the left, 140 from the right, 40
    // from the top and 60 from the bottom.
    const at = ClipPoint(xShare: 0.3, yShare: 0.4);
    final near = const CircleClip(center: at, extent: OvalExtent.closestSide).getClip(const Size(200, 100));
    expect(near.getBounds(), const Rect.fromLTWH(20, 0, 80, 80));
    final far = const CircleClip(center: at, extent: OvalExtent.farthestSide).getClip(const Size(200, 100));
    expect(far.getBounds(), const Rect.fromLTWH(-80, -100, 280, 280));
    // On a box narrow enough the left side is the nearer: 30 of 100 wide.
    final narrow = const CircleClip(center: at, extent: OvalExtent.closestSide).getClip(const Size(100, 100));
    expect(narrow.getBounds(), const Rect.fromLTWH(0, 10, 60, 60));
  });

  test('a polygon through points of lengths and shares', () {
    const tri = PolygonClip([ClipPoint(), ClipPoint(yShare: 1), ClipPoint(xShare: 1)]);
    final path = tri.getClip(const Size(20, 40));
    expect(path.contains(const Offset(2, 2)), isTrue);
    expect(path.contains(const Offset(18, 38)), isFalse);
    const cut = PolygonClip([
      ClipPoint(),
      ClipPoint(xShare: 1),
      ClipPoint(xShare: 1, y: -24, yShare: 1),
      ClipPoint(y: -24, yShare: 1),
    ]);
    expect(cut.getClip(const Size(100, 100)).getBounds(), const Rect.fromLTWH(0, 0, 100, 76));
  });

  test('a ring between the border box and the content box, its inner corners brought in', () {
    const ring = RingClip(borderRadius: BorderRadius.all(Radius.circular(16)), inner: EdgeInsets.all(2));
    final path = ring.getClip(const Size(120, 60));
    // On the ring, and in the hole.
    expect(path.contains(const Offset(60, 1)), isTrue);
    expect(path.contains(const Offset(60, 30)), isFalse);
    // Outside the outer corner's round.
    expect(path.contains(const Offset(1, 1)), isFalse);
    // (5, 5) is inside the outer corner's 16px round and outside the inner
    // one's 14px: on the ring.
    expect(path.contains(const Offset(5, 5)), isTrue);
  });

  test('an ellipse: each radius a keyword along its own axis, or a length and a share of that axis', () {
    // ellipse(closest-side farthest-side at 30% 40%) on 200x100: 60 from
    // the left and 140 from the right across, 40 from the top and 60 from
    // the bottom down.
    const at = ClipPoint(xShare: 0.3, yShare: 0.4);
    final keyed = const EllipseClip(
      center: at,
      extentX: OvalExtent.closestSide,
      extentY: OvalExtent.farthestSide,
    ).getClip(const Size(200, 100));
    expect(keyed.getBounds(), const Rect.fromLTWH(0, -20, 120, 120));
    // No radius stated is closest-side both ways, round the middle.
    final plain = const EllipseClip(
      extentX: OvalExtent.closestSide,
      extentY: OvalExtent.closestSide,
    ).getClip(const Size(200, 100));
    expect(plain.getBounds(), const Rect.fromLTWH(0, 0, 200, 100));
    // 40% of the width across and 30% of the height and 5px down.
    final shares = const EllipseClip(radiusXShare: 0.4, radiusY: 5, radiusYShare: 0.3).getClip(const Size(200, 100));
    expect(shares.getBounds(), const Rect.fromLTWH(20, 15, 160, 70));
    expect(shares.contains(const Offset(100, 50)), isTrue);
    expect(shares.contains(const Offset(22, 17)), isFalse);
  });

  test('a rounded inset of shares: the rectangle the box leaves, its own corners, scaled back to fit', () {
    // inset(10% round 8px) on 300x100: 30 in across, 10 down.
    const clip = RoundInsetClip(share: EdgeInsets.all(0.1), borderRadius: BorderRadius.all(Radius.circular(8)));
    final r = clip.getClip(const Size(300, 100));
    expect(r.outerRect, const Rect.fromLTRB(30, 10, 270, 90));
    expect(r.tlRadius, const Radius.circular(8));
    // Corners that pass the side they share are scaled back together:
    // 60px corners on an 80px tall rectangle meet at 40.
    const big = RoundInsetClip(share: EdgeInsets.all(0.1), borderRadius: BorderRadius.all(Radius.circular(60)));
    final b = big.getClip(const Size(300, 100));
    expect(b.tlRadius.x, closeTo(40, 1e-9));
    expect(b.blRadius.y, closeTo(40, 1e-9));
    // Insets that pass each other leave nothing, never less.
    const gone = RoundInsetClip(share: EdgeInsets.all(0.6), px: EdgeInsets.only(left: 2));
    expect(gone.getClip(const Size(100, 100)).outerRect.width, 0);
    expect(clip.shouldReclip(big), isTrue);
  });

  // Share corners of the reference box, as Blink sizes them
  // (`BasicShapeInset::GetPath`).
  test('an inset\'s share corners are of the box, not of the rectangle the insets leave', () {
    // `inset(10% round 10%)` on 300x100: the 240x80 rectangle 30 in and
    // 10 down, corners 30 across and 10 down.
    final r = const RoundInsetClip(
      share: EdgeInsets.all(0.1),
      borderRadiusShare: BorderRadius.all(Radius.circular(0.1)),
    ).getClip(const Size(300, 100));
    expect(r.outerRect, const Rect.fromLTRB(30, 10, 270, 90));
    expect(r.tlRadius, const Radius.elliptical(30, 10));
    expect(r.brRadius, const Radius.elliptical(30, 10));
    // A length and a share on one corner add; corners that together pass
    // their side are scaled back against the rectangle.
    final big = const RoundInsetClip(
      px: EdgeInsets.all(10),
      borderRadius: BorderRadius.only(topLeft: Radius.circular(20)),
      borderRadiusShare: BorderRadius.only(topLeft: Radius.circular(0.5), topRight: Radius.circular(0.5)),
    ).getClip(const Size(100, 60));
    // The top: 20 + 50 and 50 over a side of 80 -- scaled by 80 / 120.
    expect(big.tlRadius.x, closeTo(70 * 80 / 120, 1e-9));
    expect(big.trRadius.x, closeTo(50 * 80 / 120, 1e-9));
  });

  test('the padding box: the border cut off, no hole', () {
    const pad = RingClip(outer: EdgeInsets.all(6));
    final path = pad.getClip(const Size(100, 50));
    expect(path.getBounds(), const Rect.fromLTWH(6, 6, 88, 38));
  });
}
