/// A box that may take up LESS room than its child.
library;

import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'dry.dart';

/// [Padding], with the assertion lifted: an inset may be negative, and a
/// negative one makes this box smaller than the child inside it.
///
/// A negative inset does two things at once, and both matter. The child is
/// laid out against MORE space than this box was offered, so a child inset
/// by -16 on each side is 32 wider than its parent; and this box reports a
/// size smaller than the child's, so whatever is laid out after it starts
/// higher up, overlapping. That second half is the one no composition of
/// [Padding], [Transform] or [Align] can do -- [Transform] moves paint and
/// leaves the box where it was, and [Align]'s factors are multiplicative,
/// so neither can make a sibling move by a constant.
///
/// Insets are applied to the CONSTRAINTS, so the result stays inside what
/// this box was given: a child made wider by a negative inset still gets a
/// finite width, and this box never reports a negative size.
class Inset extends SingleChildRenderObjectWidget {
  const Inset({
    super.key,
    required this.insets,
    this.shares = EdgeInsets.zero,
    this.least,
    this.most,
    this.mostShares = EdgeInsets.zero,
    this.room = false,
    this.fits = false,
    this.ofRoom = false,
    this.keepsHeight = false,
    this.height,
    super.child,
  });

  /// Positive insets add space around the child, exactly as [Padding] does.
  /// Negative ones subtract it.
  final EdgeInsets insets;

  /// The part of each inset that is a SHARE of the width this box is
  /// offered rather than a length of its own.
  ///
  /// A percentage margin or padding is a share of the containing block's
  /// WIDTH on every side, the top and the bottom included (CSS 2.1 8.3).
  /// Where the page states that width the pass writes the number; where it
  /// does not -- a column as wide as the page, a grid area -- the share is
  /// not a number until this box is laid out, and this is where it becomes
  /// one. It is added to [insets], so `calc(50% - 195px)` is a share of
  /// `0.5` and an inset of `-195`.
  final EdgeInsets shares;

  /// The least each inset comes to, where a share and a length together
  /// could go under it. A padding is never negative (CSS 2.1 8.4): a forum's
  /// header pads `calc(-50% + 195px)`, nothing on any page wider than
  /// 390px, and a border inside the same inset stays whatever the padding
  /// comes to. Null leaves a negative inset as it is -- a margin may be one.
  final EdgeInsets? least;

  /// The most each inset comes to, where a share and a length together
  /// could go over it: `min(24px, 10%)` is the smaller of the two
  /// (css-values-4 10.2), a tenth of the block up to 24px. A cap is taken
  /// before [least], so where the two cross the floor wins -- the padding
  /// is never under nothing whatever caps it (CSS 2.1 8.4). Null leaves the
  /// share and the length to come to whatever they come to.
  final EdgeInsets? most;

  /// The part of each cap in [most] that is a SHARE of the width [shares]
  /// are of, added to it as [shares] is added to [insets]: the smaller of
  /// two shares of the same block is the one share on one side of the
  /// width where they cross and the other on the other (css-values-4
  /// 10.2), and which it is waits for the width. `padding-left: min(10%,
  /// 30% - 100px)` is `shares` 0.1 under a cap of `most` -100 and
  /// `mostShares` 0.3 -- three tenths of a 400px row less 100 is 20, under
  /// its 40, and a tenth of a 600px one is 60, under its 80
  /// (`fixtures/flex-item-pct-padding-calc`). Nothing without [most].
  final EdgeInsets mostShares;

  /// Whether the width this box is offered is a containing block's: the
  /// outermost widget of a block of the flow is offered the block's width,
  /// and a share inside it that is of THAT width reads it off here
  /// ([ofRoom]).
  final bool room;

  /// Whether this [room] is as wide as what is inside it rather than as
  /// wide as it is offered: an inline-level flex container of no stated
  /// width. The shares of it are then CYCLIC -- they count as nothing
  /// while the room's own width is worked out, and resolve against the
  /// width that comes out (css-sizing-3 5.2.1; CSS 2.1 8.4). So the room
  /// lays its child out twice: first as wide as it wants with every share
  /// of the room at nothing, then held to that width with the shares taken
  /// of it -- and what they add hangs out of the room. Chrome, an
  /// `inline-flex` round `e` at `padding: 0 10%` and `f`: the container is
  /// the two words' 15.25 wide, `e`'s padding 1.525 a side, and `f` hangs
  /// 3.05 out of the container's end (`fixtures/flex-item-pct-padding`).
  final bool fits;

  /// Whether the shares are of the width the nearest [room] above was
  /// offered rather than of this box's own. A block that does not fill its
  /// containing block -- margins between the two, a width of its own --
  /// pads by a share of the block all the same (CSS 2.1 8.4), and its own
  /// width says nothing about the block's: the forum's header is `margin: 0
  /// calc(50% - 195px); padding: 0 calc(-50% + 195px)`, 390px wide on any
  /// page and its content the page's width up to 390. A [RoomHost] above
  /// may offer the room instead -- a grid, its item's AREA. With no room
  /// above, the share is of this box's own width, as it is without this.
  final bool ofRoom;

  /// Whether the vertical insets come out of THIS box rather than out of
  /// the child's height.
  ///
  /// A box whose height is a share of its containing block is exactly that
  /// tall whatever its own margins take (CSS 2.1 10.5): the share is of the
  /// block's content box, and the margin box overflows it. The child is
  /// then offered the same height this box was, and this box reports the
  /// child plus the insets -- which its own constraints clip back to the
  /// room, so the overhang is paint, not layout. A web portal's stock ticker is a
  /// `height: 100%` row 9px inside each 54px cell of a stretched line: with
  /// the room deflated first the row came out 36 tall.
  final bool keepsHeight;

  /// A stated BORDER-BOX height, where the insets inside it are not a
  /// number until the box is laid out.
  ///
  /// A border box is never less than its padding and border (css-sizing-3
  /// 5.1), so this box is the larger of [height] and its vertical insets,
  /// and the child is handed exactly what is left over, which may be
  /// nothing. With a share on the top or the bottom which of the two wins
  /// moves with the width: a Japanese car listing's hero is `height: 710px;
  /// padding-top: 28%`, 710 on a phone and the padding's from about 2535px
  /// wide.
  final double? height;

  @override
  RenderInset createRenderObject(BuildContext context) => RenderInset(
    insets: insets,
    shares: shares,
    least: least,
    most: most,
    mostShares: mostShares,
    room: room,
    fits: fits,
    ofRoom: ofRoom,
    keepsHeight: keepsHeight,
    height: height,
  );

  @override
  void updateRenderObject(BuildContext context, RenderInset renderObject) => renderObject
    ..insets = insets
    ..shares = shares
    ..least = least
    ..most = most
    ..mostShares = mostShares
    ..room = room
    ..fits = fits
    ..ofRoom = ofRoom
    ..keepsHeight = keepsHeight
    ..height = height;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<EdgeInsets>('insets', insets));
    properties.add(DiagnosticsProperty<EdgeInsets>('shares', shares, defaultValue: EdgeInsets.zero));
    properties.add(DiagnosticsProperty<EdgeInsets?>('least', least, defaultValue: null));
    properties.add(DiagnosticsProperty<EdgeInsets?>('most', most, defaultValue: null));
    properties.add(DiagnosticsProperty<EdgeInsets>('mostShares', mostShares, defaultValue: EdgeInsets.zero));
    properties.add(FlagProperty('room', value: room, ifTrue: 'room'));
    properties.add(FlagProperty('fits', value: fits, ifTrue: 'as wide as its content'));
    properties.add(FlagProperty('ofRoom', value: ofRoom, ifTrue: 'of the room above'));
    properties.add(DoubleProperty('height', height, defaultValue: null));
  }
}

/// A box that offers what is inside one of its children a ROOM
/// ([Inset.room]) that is not the width it lays that child out at: the
/// width of a containing block the child does not fill. A grid item's
/// containing block is its grid AREA (css-grid-1 9, CSS 2.1 10.1), and an
/// item that states a width of its own is laid out at that width, not the
/// area's -- so a percentage padding of the item is a share of a width it
/// is never handed. The first host or [Inset.room] above an [Inset.ofRoom]
/// that offers one is the one it reads.
abstract interface class RoomHost {
  /// The width the boxes inside [child] take their shares of, or null
  /// where [child] is offered no room here; [dependant] is laid out again
  /// when it changes.
  double? roomOf(RenderObject child, RenderInset dependant);

  /// Stops laying [dependant] out again for a room it no longer reads.
  void forget(RenderInset dependant);
}

class RenderInset extends RenderShiftedBox with DryLastBaseline, AsksGuarded, PassesBaseline, KeptUnderHatch {
  RenderInset({
    required EdgeInsets insets,
    EdgeInsets shares = EdgeInsets.zero,
    EdgeInsets? least,
    EdgeInsets? most,
    EdgeInsets mostShares = EdgeInsets.zero,
    bool room = false,
    bool fits = false,
    bool ofRoom = false,
    bool keepsHeight = false,
    double? height,
    RenderBox? child,
  }) : _insets = insets,
       _shares = shares,
       _least = least,
       _most = most,
       _mostShares = mostShares,
       _room = room,
       _fits = fits,
       _ofRoom = ofRoom,
       _keepsHeight = keepsHeight,
       _height = height,
       super(child);

  /// See [Inset.least].
  EdgeInsets? get least => _least;
  EdgeInsets? _least;
  set least(EdgeInsets? value) {
    if (_least == value) return;
    _least = value;
    markNeedsLayout();
  }

  /// See [Inset.most].
  EdgeInsets? get most => _most;
  EdgeInsets? _most;
  set most(EdgeInsets? value) {
    if (_most == value) return;
    _most = value;
    markNeedsLayout();
  }

  /// See [Inset.mostShares].
  EdgeInsets get mostShares => _mostShares;
  EdgeInsets _mostShares;
  set mostShares(EdgeInsets value) {
    if (_mostShares == value) return;
    _mostShares = value;
    markNeedsLayout();
  }

  /// See [Inset.room].
  bool get room => _room;
  bool _room;
  set room(bool value) {
    if (_room == value) return;
    _room = value;
    markNeedsLayout();
  }

  /// See [Inset.fits].
  bool get fits => _fits;
  bool _fits;
  set fits(bool value) {
    if (_fits == value) return;
    _fits = value;
    markNeedsLayout();
  }

  /// Whether this room's own width is being worked out ([Inset.fits]),
  /// while the shares of it count as nothing.
  bool _sizing = false;

  /// See [Inset.ofRoom].
  bool get ofRoom => _ofRoom;
  bool _ofRoom;
  set ofRoom(bool value) {
    if (_ofRoom == value) return;
    _ofRoom = value;
    markNeedsLayout();
  }

  /// The width this box was last offered, kept for the boxes inside it
  /// whose shares are of it (see [Inset.room]). Set as a layout or a dry
  /// layout starts, before either asks the child anything.
  double? _offered;

  /// The boxes inside whose shares are of this box's width. They are laid
  /// out again when it changes, since their own constraints may not:
  /// the forum's header is 390 wide in a 300px block and in a 500px one, and
  /// its padding is not.
  final Set<RenderInset> _dependants = {};

  /// The [room] this box last read its width off.
  RenderInset? _roomAbove;

  /// The [RoomHost] this box last read its width off.
  RoomHost? _hostAbove;

  /// The width [shares] are of: this box's own, or the one the nearest
  /// [room] above it was offered, or a [RoomHost] above offers.
  double _basis(double width) {
    if (!_ofRoom) return width;
    touchesRoom();
    RenderObject below = this;
    for (RenderObject? p = parent; p != null; below = p, p = p.parent) {
      if (p is RenderInset && p._room) {
        if (!identical(_roomAbove, p)) {
          _roomAbove?._dependants.remove(this);
          _roomAbove = p;
          p._dependants.add(this);
        }
        _hostAbove?.forget(this);
        _hostAbove = null;
        // Nothing, while the room's width is what is being worked out: a
        // share of an infinite basis comes to nothing ([_at]).
        if (p._sizing) return double.infinity;
        return p._offered ?? width;
      }
      if (p is RoomHost) {
        final host = p as RoomHost;
        if (host.roomOf(below, this) case final room?) {
          if (!identical(_hostAbove, host)) _hostAbove?.forget(this);
          _hostAbove = host;
          _roomAbove?._dependants.remove(this);
          _roomAbove = null;
          return room;
        }
      }
    }
    return width;
  }

  /// Takes the width this box is offered, for the boxes inside whose shares
  /// are of it, and has them laid out again where it changed.
  void _offer(double width, {required bool laying}) {
    if (!_room) return;
    touchesRoom();
    final was = _offered;
    _offered = width;
    if (laying && was != width && _dependants.isNotEmpty) {
      // A box under unchanged constraints is not laid out again; told it
      // needs to be, it is -- from the callback that lets a box mark its
      // own subtree mid-layout.
      invokeLayoutCallback((_) {
        for (final d in _dependants) {
          d.markNeedsLayout();
        }
      });
    }
  }

  @override
  void detach() {
    _roomAbove?._dependants.remove(this);
    _roomAbove = null;
    _hostAbove?.forget(this);
    _hostAbove = null;
    super.detach();
  }

  EdgeInsets get insets => _insets;
  EdgeInsets _insets;
  set insets(EdgeInsets value) {
    if (_insets == value) return;
    _insets = value;
    markNeedsLayout();
  }

  EdgeInsets get shares => _shares;
  EdgeInsets _shares;
  set shares(EdgeInsets value) {
    if (_shares == value) return;
    _shares = value;
    markNeedsLayout();
  }

  /// See [Inset.keepsHeight].
  bool get keepsHeight => _keepsHeight;
  bool _keepsHeight;
  set keepsHeight(bool value) {
    if (_keepsHeight == value) return;
    _keepsHeight = value;
    markNeedsLayout();
  }

  /// See [Inset.height].
  double? get height => _height;
  double? _height;
  set height(double? value) {
    if (_height == value) return;
    _height = value;
    markNeedsLayout();
  }

  /// The insets at a given width: the lengths plus each side's share of it.
  ///
  /// Offered no width at all -- which every intrinsic and dry pass may do
  /// -- a share has nothing to be a share OF and comes to nothing, which is
  /// what a percentage against an indefinite containing block resolves to
  /// (css-sizing-3 5.2.2 leaves it out of the intrinsic contribution).
  EdgeInsets _at(double width) {
    var e = _insets;
    var w = 0.0;
    if (_shares != EdgeInsets.zero || _mostShares != EdgeInsets.zero) {
      final basis = _basis(width);
      w = basis.isFinite ? basis : 0.0;
      e = EdgeInsets.fromLTRB(
        _insets.left + _shares.left * w,
        _insets.top + _shares.top * w,
        _insets.right + _shares.right * w,
        _insets.bottom + _shares.bottom * w,
      );
    }
    if (_most case final m0?) {
      final m = m0 + _mostShares * w;
      e = EdgeInsets.fromLTRB(
        math.min(m.left, e.left),
        math.min(m.top, e.top),
        math.min(m.right, e.right),
        math.min(m.bottom, e.bottom),
      );
    }
    if (_least case final l?) {
      e = EdgeInsets.fromLTRB(
        math.max(l.left, e.left),
        math.max(l.top, e.top),
        math.max(l.right, e.right),
        math.max(l.bottom, e.bottom),
      );
    }
    return e;
  }

  /// The constraints the child is measured and laid out against. A negative
  /// inset widens them; `deflate` would assert, and clamping at zero would
  /// lose the overhang. A minimum of zero stays zero: a box that may be
  /// any size is not made to be at least as big as its own overhang -- a
  /// 1px box with `margin: -1px` is still 1px, not 3. A box that must be
  /// one size is still stretched to it, overhang and all: a block with
  /// `margin: 0 -5px 0 -10px` in a 0px-wide container is 15px wide.
  BoxConstraints _forChild(BoxConstraints c) {
    final e = _at(c.maxWidth);
    final horizontal = e.left + e.right, vertical = e.top + e.bottom;
    double loosen(double v, double by) => v.isFinite ? math.max(0.0, v - by) : v;
    double least(double min, double max, double by) =>
        min >= max ? loosen(max, by) : math.min(min > 0 ? math.max(0.0, min - by) : 0.0, loosen(max, by));
    if (_height case final h?) {
      final inner = math.max(0.0, c.constrainHeight(math.max(h, vertical)) - vertical);
      return BoxConstraints(
        minWidth: least(c.minWidth, c.maxWidth, horizontal),
        maxWidth: loosen(c.maxWidth, horizontal),
        minHeight: inner,
        maxHeight: inner,
      );
    }
    return BoxConstraints(
      minWidth: least(c.minWidth, c.maxWidth, horizontal),
      maxWidth: loosen(c.maxWidth, horizontal),
      minHeight: _keepsHeight ? c.minHeight : least(c.minHeight, c.maxHeight, vertical),
      maxHeight: _keepsHeight ? c.maxHeight : loosen(c.maxHeight, vertical),
    );
  }

  double _outer(double inner, double by) => math.max(0.0, inner + by);

  /// The size this box comes to around a child of [inner], at [e].
  Size _around(Size inner, EdgeInsets e) =>
      Size(_outer(inner.width, e.left + e.right), math.max(_outer(inner.height, e.top + e.bottom), _height ?? 0.0));

  /// [measure] with the shares of this room at nothing, where it is a
  /// room as wide as its content ([Inset.fits]).
  T _sized<T>(T Function() measure) {
    if (!_room || !_fits) return measure();
    final was = _sizing;
    _sizing = true;
    try {
      return measure();
    } finally {
      _sizing = was;
    }
  }

  @override
  double computeMinIntrinsicWidth(double height) => _sized(() {
    final e = _at(double.infinity);
    final h = _height ?? height;
    return _outer(
      guardedSize(child, () => child?.getMinIntrinsicWidth(math.max(0.0, h - e.top - e.bottom)) ?? 0.0),
      e.left + e.right,
    );
  });

  @override
  double computeMaxIntrinsicWidth(double height) => _sized(() {
    final e = _at(double.infinity);
    final h = _height ?? height;
    return _outer(
      guardedSize(child, () => child?.getMaxIntrinsicWidth(math.max(0.0, h - e.top - e.bottom)) ?? 0.0),
      e.left + e.right,
    );
  });

  /// [measure] with this [room] offering [width] to the shares of it.
  ///
  /// A height asked at a width is the height this box comes to laid out
  /// that wide, so the shares inside are taken of that width as a layout
  /// takes them: a percentage is cyclic only against a size still being
  /// worked out (css-sizing-3 5.2.1), and a block's width is known before
  /// its height. A flex row whose items stretch to the tallest -- an
  /// [IntrinsicHeight] round a [Row] -- asks each item its height at the
  /// item's width; a square of `padding-bottom: 100%` inside one came to
  /// nothing, and the row to the height of its text. Chrome, two `flex: 1`
  /// items of a 408px row 8px apart, one a block padded `0 8px 12px` whose
  /// `::after` pads `bottom: 100%`: the row is 196 tall
  /// (`test/inset_room_height_test.dart`). What a layout offered is kept
  /// for the boxes laid out after it.
  T _offering<T>(double width, T Function() measure) {
    if (!_room) return measure();
    final was = _offered;
    _offered = width;
    try {
      return measure();
    } finally {
      _offered = was;
    }
  }

  @override
  double computeMinIntrinsicHeight(double width) => _offering(width, () {
    final e = _at(width);
    if (_height case final h?) return math.max(h, e.top + e.bottom);
    return _outer(
      guardedSize(child, () => child?.getMinIntrinsicHeight(math.max(0.0, width - e.left - e.right)) ?? 0.0),
      e.top + e.bottom,
    );
  });

  @override
  double computeMaxIntrinsicHeight(double width) => _offering(width, () {
    final e = _at(width);
    if (_height case final h?) return math.max(h, e.top + e.bottom);
    return _outer(
      guardedSize(child, () => child?.getMaxIntrinsicHeight(math.max(0.0, width - e.left - e.right)) ?? 0.0),
      e.top + e.bottom,
    );
  });

  /// Whether what this box comes to hangs on the width a room above it
  /// ([ofRoom]) was offered, which no question asked of this box carries.
  ///
  /// Flutter keeps each answer a box gives by the question it was asked,
  /// and a share of a room asked twice the same question -- its height at
  /// its own width of nothing, beside the text of a row -- in two rooms of
  /// different widths would answer the first room's. Its height is worked
  /// out afresh each time instead. Its width is still kept: a line counts
  /// an item's width as the room is sized, with the shares at nothing, and
  /// adds them itself (`FlexCell.frameFraction`;
  /// `test/fit_room_share_hang_test.dart`).
  bool get _readsRoom => _ofRoom && (_shares != EdgeInsets.zero || _mostShares != EdgeInsets.zero);

  @override
  double getMinIntrinsicHeight(double width) =>
      _readsRoom ? computeMinIntrinsicHeight(width) : super.getMinIntrinsicHeight(width);

  @override
  double getMaxIntrinsicHeight(double width) =>
      _readsRoom ? computeMaxIntrinsicHeight(width) : super.getMaxIntrinsicHeight(width);

  @override
  Size getDryLayout(covariant BoxConstraints constraints) =>
      _readsRoom ? computeDryLayout(constraints) : super.getDryLayout(constraints);

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    final b = child?.getDistanceToActualBaseline(baseline);
    return b == null ? null : b + _at(constraints.maxWidth).top;
  }

  @override
  double? computeDryBaseline(covariant BoxConstraints constraints, TextBaseline baseline) {
    final c = child;
    if (c == null) return null;
    final b = dryBaselineOf(c, _forChild(constraints), baseline);
    return b == null ? null : b + _at(constraints.maxWidth).top;
  }

  @override
  double? dryLastBaseline(BoxConstraints constraints, TextBaseline baseline) {
    final c = child;
    if (c == null) return null;
    final b = dryLastBaselineOf(c, _forChild(constraints), baseline);
    return b == null ? null : b + _at(constraints.maxWidth).top;
  }

  /// The width a room as wide as its content comes to ([Inset.fits]):
  /// what [measure] gives the child under [c], with the shares of the
  /// room at nothing.
  double _fitWidth(BoxConstraints c, Size Function(BoxConstraints) measure) {
    final e = _at(c.maxWidth);
    return c.constrainWidth(_around(_sized(() => measure(_forChild(c))), e).width);
  }

  @override
  @protected
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final c = child;
    // A dry pass is the same pass for the boxes inside: they read the
    // width they are a share of from here (see [Inset.room]).
    if (_room && _fits && c != null) {
      constraints = constraints.tighten(width: _fitWidth(constraints, (k) => guardedSize(c, () => c.getDryLayout(k))));
    }
    _offer(constraints.maxWidth, laying: false);
    final e = _at(constraints.maxWidth);
    if (c == null) return constraints.constrain(_around(Size.zero, e));
    return constraints.constrain(_around(guardedSize(c, () => c.getDryLayout(_forChild(constraints))), e));
  }

  /// Has every box inside whose shares are of this room laid out again.
  void _redoDependants() {
    if (_dependants.isEmpty) return;
    invokeLayoutCallback((_) {
      for (final d in _dependants) {
        d.markNeedsLayout();
      }
    });
  }

  @override
  void performLayout() {
    var constraints = this.constraints;
    final c0 = child;
    if (_room && _fits && c0 != null) {
      // First as wide as the content wants with the shares at nothing --
      // laid out afresh, since the pass before took them of a width --
      // then held to that width with the shares taken of it.
      _redoDependants();
      final w = _fitWidth(constraints, (inner) {
        c0.layout(inner, parentUsesSize: true);
        return c0.size;
      });
      _redoDependants();
      constraints = constraints.tighten(width: w);
    }
    _offer(constraints.maxWidth, laying: true);
    final e = _at(constraints.maxWidth);
    final c = child;
    if (c == null) {
      size = constraints.constrain(_around(Size.zero, e));
      return;
    }
    c.layout(_forChild(constraints), parentUsesSize: true);
    (c.parentData! as BoxParentData).offset = Offset(e.left, e.top);
    size = this.constraints.constrain(_around(c.size, e));
  }
}
