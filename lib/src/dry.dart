import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show internal;
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart' show Ticker, TickerCallback, TickerProvider;

/// A child's dry baseline, or null where it has none.
///
/// `getDryBaseline` ASSERTS in debug for a render object that does not
/// implement `computeDryBaseline` -- Flutter's own `RenderPositionedBox`
/// is one, and an `Align` is what a page lowered to widgets is full of.
/// `debugCheckingIntrinsics` is the framework's OWN escape hatch: under it
/// `debugCannotComputeDryLayout` answers instead of throwing, and null is
/// the release answer anyway -- no baseline of its own, synthesise one
/// from the box. Catching the throw instead leaves the child's
/// `_computingThisDryBaseline` flag set for good, and every later `size`
/// access on it asserts.
///
/// AND THE HATCH IS OPENED ONLY WHERE THE QUESTION CAN REACH ONE. Under
/// `debugCheckingIntrinsics` Flutter keeps no intrinsic, dry layout or
/// dry baseline at all, so everything a question measures is measured
/// again each time it is asked, and every box under it that asks in turn
/// multiplies that: a price-table site's network tabs -- 245 chips in a flex
/// line, an inline-block alone on its line, two `IntrinsicWidth`s round
/// it -- laid out in 17s at 390 in debug, against 2s with the hatch shut
/// where nothing asserts, and its width sweep held the build queue for
/// most of a day. So the hatch is opened only where something the question
/// can reach ([_answersUnguarded]) may answer by asserting; a question
/// asked under it already is asked as it is. Release builds never open
/// it.
double? dryBaselineOf(RenderBox child, BoxConstraints constraints, TextBaseline baseline) =>
    // Asked a baseline alone, an `IgnoreBaseline` answers none and asks
    // nothing ([_answersUnguarded]).
    child is RenderIgnoreBaseline
    ? child.getDryBaseline(constraints, baseline)
    : _hatched(child, true, () => child.getDryBaseline(constraints, baseline));

/// What [ask] answers, asked of [child] as [dryBaselineOf] asks a dry
/// baseline: under the hatch where the question may reach a box that
/// answers by asserting, as it is everywhere else.
///
/// A SIZE ASKED OF A PARAGRAPH ASKS A BASELINE. A paragraph asks each
/// span's box that stands on the baseline its dry baseline whatever it is
/// asked -- its intrinsic widths and heights, its dry layout
/// (`RenderInlineChildrenContainerDefaults.layoutInlineChildren`) -- so a
/// box that measures the paragraph it holds asks those boxes theirs. From
/// Flutter 3.41 to 3.47 a proxy over a box with no baseline asserts there
/// (flutter#189711): a line that never wraps, laid out, asked its
/// paragraph its width and threw over an empty box on its baseline.
@internal
T guardedAsk<T>(RenderBox child, T Function() ask) => _hatched(child, true, ask);

/// What [ask] answers, asked of [child] through [guardedAsk] where Flutter's
/// proxies assert over a child that answers no dry baseline (flutter#189711,
/// 3.41 to 3.47); on every other Flutter under the hatch only where the
/// question reaches an `Align` asked a dry baseline or another box that
/// answers nothing dry ([_answersNoDry]) -- a `LayoutBuilder`, whatever it
/// is asked -- and as it is everywhere else.
///
/// For a question that can reach an assert through that bug, or through
/// an `Align` -- a size asked of a paragraph, which asks each span's box on
/// the baseline its baseline. Under the hatch Flutter keeps nothing, and a
/// box's dry and laid-out baselines share one cache, so a line measured
/// under it and then laid out stands a span on its laid-out baseline where
/// a release build stands it on the dry one it kept: asked through the
/// hatch on every Flutter, a caption set in a column beside an inline
/// picture -- a box the walk cannot vouch for -- came out 1.5px higher in a
/// debug build of 3.38 than in release.
///
/// AN `ALIGN` ASSERTS ON EVERY FLUTTER. Flutter's `RenderPositionedBox`
/// -- an `Align`, a `Center` -- answers no dry baseline of its own, and
/// asked one outside the hatch throws "The RenderPositionedBox class does
/// not implement computeDryBaseline"; a stack asks one of every child it
/// holds, the ones it places too. A rental site's desktop inbox stands its
/// host's round picture on a line's baseline, a stack whose placed badge
/// is an `Align`, and the line, asked its height by the row round it,
/// threw at 1440 in a debug build of 3.38, and every layout under it after
/// (`test/linebox_align_span_dry_test.dart`). So there the walk looks for
/// that box alone, and for the others that answer nothing dry
/// ([_answersUnguarded], `alignsOnly`): a box it cannot vouch for is asked
/// as it always was. In release the `Align` answers none, and under the
/// hatch it answers the same.
///
/// NEGATIVE: a `Padding` answers its child's dry baseline and the hatch
/// stays shut.
@internal
T guardedWhereProxiesAssert<T>(RenderBox child, T Function() ask) =>
    _proxyAsksBox ? guardedAsk(child, ask) : _hatched(child, true, ask, alignsOnly: true);

/// What [ask] answers -- a size of [box]'s, a dry layout or an intrinsic
/// width or height, asked by a box of css_box's that measures what it holds
/// -- asked under the hatch where Flutter's proxies assert over a child
/// that answers no dry baseline (flutter#189711, 3.41 to 3.47) and the size
/// may reach one, and as it is everywhere else and on every other Flutter.
///
/// A SIZE ASKS A BASELINE WHERE A BOX BELOW LINES WHAT IT HOLDS UP ON
/// ONE: a flex on `CrossAxisAlignment.baseline` asks each item its dry
/// baseline to measure itself dry, a paragraph each span's box on the
/// baseline, a `Baseline` its child. On 3.41 to 3.47 a proxy over a box
/// that answers none asserts there, however far down the size was asked
/// from. A marketplace's service page holds its round icon button in a
/// `ShrinkWidth` that measures what it holds: a decorated, clipped,
/// `IntrinsicWidth` box round a row on its baseline, which holds an empty
/// label and a `Semantics` over the decorated button -- a proxy over a
/// stack that answers no baseline -- and every test that pumped the page
/// threw "The RenderDecoratedBox class does not implement
/// computeDryBaseline" from the shrink's own layout
/// (`test/size_asked_dry_baseline_test.dart`).
///
/// The walk starts as a SIZE: the box asked is asked no baseline, so a
/// proxy right under it is passed whatever it holds, and the hatch opens
/// only where a box that asks a baseline stands over one that may assert.
/// A size went under the hatch nowhere before, so A WALK THAT STARTS AS A
/// SIZE FEARS THAT PROXY ALONE: a box nobody here knows is asked as it
/// always was, and what it holds is followed as asked a baseline. Under
/// the hatch Flutter keeps nothing it measures: on 2026-10-15 a walk that
/// followed every child a stack places, and feared every inline-block it
/// could not prove stood on a line, relaid that marketplace's settings
/// page thirty times as slowly in a debug build of 3.47.
///
/// NEGATIVE: the same button in a row on its centre line keeps the hatch
/// shut, and so do an inline button whose icon stands on its edge and a
/// row a stack places; Flutter keeps what it measured.
///
/// ON EVERY OTHER FLUTTER A SIZE IS GUARDED WHERE IT REACHES A BOX THAT
/// ANSWERS NOTHING DRY ([_answersNoDry]): a `LayoutBuilder`, whatever it is
/// asked, and a box with no dry baseline of its own asked one. The walk
/// looks for those alone ([guardedWhereProxiesAssert]'s walk), and the
/// hatch stays shut everywhere else, as it was. In release nothing is
/// guarded.
@internal
T guardedSize<T>(RenderBox? box, T Function() ask) =>
    box == null ? ask() : _hatched(box, false, ask, alignsOnly: !_proxyAsksBox);

/// What [ask] answers, asked of [box] -- a dry baseline ([baseline]), or a
/// size alone -- under Flutter's `debugCheckingIntrinsics` hatch where the
/// question may reach a box that answers by asserting
/// ([_answersUnguarded]), and as it is everywhere else. A question asked
/// under the hatch already is asked as it is, and release builds never
/// open it.
///
/// A box that measures what it holds asks through here, and so does every
/// box of css_box's under it that measures in turn, each walking what it
/// holds again. Keeping what the walks passed while the outermost question
/// was out relaid a marketplace's pages no faster in a debug build of 3.47
/// (2026-10-15), so no walk is kept; what css_box's boxes answer under the
/// hatch is ([underHatch]).
///
/// [alignsOnly] opens it only where the question reaches an `Align` asked a
/// dry baseline ([guardedWhereProxiesAssert]).
T _hatched<T>(RenderBox box, bool baseline, T Function() ask, {bool alignsOnly = false}) {
  var debug = false;
  assert(() {
    debug = true;
    return true;
  }());
  if (!debug ||
      RenderObject.debugCheckingIntrinsics ||
      _answersUnguarded(box, baseline: baseline, alignsOnly: alignsOnly)) {
    return ask();
  }
  return underHatch(ask);
}

/// What [ask] answers under Flutter's `debugCheckingIntrinsics` hatch,
/// opened here and shut when it is answered, with every box of css_box's
/// keeping what it answers until then ([KeptUnderHatch]). Opened only in
/// a debug build, and only where it is shut: a question asked under it
/// already is asked as it is ([_hatched], and a line box's question after
/// its layout).
///
/// UNDER THE HATCH FLUTTER KEEPS NOTHING it measures, so a question is
/// worked out again each time it is asked, and so is each one it asks in
/// turn: a line box measuring an inline-block asks it its size and its
/// baseline, the paragraph inside asks them again, and each line box in
/// the inline-block does the same of what it holds, so every level of
/// lines multiplies the work under it -- a square under six lines, each
/// the inline-block on the next one's line, was measured 728 times
/// (`test/hatch_keeps_answers_test.dart`). A price-table site's phone home
/// page -- its rows a table of line boxes round inline-blocks of line
/// boxes -- laid out in 3.0s at 320 in a debug build of 3.38; keeping
/// what each box of css_box's answered while the hatch is open, 1.2s, the
/// same layout to the pixel at every width of its sweep.
///
/// What is kept is what Flutter keeps outside the hatch -- a dry size, a
/// dry baseline, an intrinsic width or height, by what is asked -- and
/// nothing is kept past the question: a box's answers are only worth
/// keeping while nothing they were worked out of can change, and nothing
/// under the hatch is laid out. Nor is an answer worked out while a box
/// read or offered a room's width or height ([touchesRoom]): what a room
/// was offered is left by the question asked before, not this one.
@internal
T underHatch<T>(T Function() ask) {
  RenderObject.debugCheckingIntrinsics = true;
  _kept = <Object, Object?>{};
  try {
    return ask();
  } finally {
    RenderObject.debugCheckingIntrinsics = false;
    _kept = null;
  }
}

/// What css_box's boxes answered while [underHatch] is open, by box and
/// question; null while it is shut, and in a release build always.
Map<Object, Object?>? _kept;

/// How many times a box has read or offered a room's width or height
/// ([touchesRoom]).
int _roomTouches = 0;

/// A box reads the width or height a room above it was offered, or offers
/// one to the boxes inside -- what a pass leaves for the boxes it asks
/// after, so what they answer depends on more than the question. No
/// answer worked out while one does is kept under the hatch
/// ([KeptUnderHatch]): a share of a room laid out twice at two widths
/// answers each width once the room offers it
/// (`test/hatch_keeps_answers_test.dart`).
@internal
void touchesRoom() => _roomTouches++;

/// A box of css_box's that keeps the questions Flutter keeps -- its dry
/// size, its dry baseline, its intrinsic widths and heights -- while
/// css_box holds the hatch open, where Flutter keeps none ([underHatch]).
/// Outside it, and in a release build, each is asked as Flutter asks it.
@internal
mixin KeptUnderHatch on RenderBox {
  R _keep<R>(Object question, R Function() ask) {
    final kept = _kept;
    if (kept == null) return ask();
    if (kept.containsKey(question)) return kept[question] as R;
    final touches = _roomTouches;
    final answer = ask();
    if (_roomTouches == touches) kept[question] = answer;
    return answer;
  }

  @override
  Size getDryLayout(covariant BoxConstraints constraints) =>
      _keep((this, 0, constraints), () => super.getDryLayout(constraints));

  @override
  double? getDryBaseline(covariant BoxConstraints constraints, TextBaseline baseline) =>
      _keep((this, 1, constraints, baseline), () => super.getDryBaseline(constraints, baseline));

  @override
  double getMinIntrinsicWidth(double height) => _keep((this, 2, height), () => super.getMinIntrinsicWidth(height));

  @override
  double getMaxIntrinsicWidth(double height) => _keep((this, 3, height), () => super.getMaxIntrinsicWidth(height));

  @override
  double getMinIntrinsicHeight(double width) => _keep((this, 4, width), () => super.getMinIntrinsicHeight(width));

  @override
  double getMaxIntrinsicHeight(double width) => _keep((this, 5, width), () => super.getMaxIntrinsicHeight(width));
}

/// A box of css_box's that asks what it holds for a dry baseline only
/// through [dryBaselineOf] and [dryLastBaselineOf], each of which opens
/// the hatch for its own question where that question needs it -- or asks
/// nothing of what it holds at all. Asked one itself, it asserts nowhere.
mixin AsksGuarded on RenderBox {}

/// Whether a question asked of [box] -- a dry baseline, or a size alone
/// ([baseline]) -- reaches nothing that answers by asserting.
///
/// Followed down as Flutter's own boxes pass a question on, each box with
/// what may be asked of it: a dry baseline, or a dry size or an intrinsic
/// one alone. A proxy, a padding or another of the shifted boxes that
/// answer for their child, a stack, a wrap, a list body, a table and the
/// box Flutter wraps round a span's child to scale it with the text ask
/// what they hold what they are asked -- a stack asked a size asks the
/// children it places nothing. A flex asks a baseline of what it
/// holds where it is asked one or lines its items up on theirs; a
/// paragraph and a text field ask one of each span's box that stands on
/// the baseline, whatever they are asked, and a `Baseline` of what it
/// holds; an `IgnoreBaseline` asked one asks nothing. A box of
/// css_box's that guards its own questions ([AsksGuarded]) asks what it
/// holds sizes alone, so what it holds is followed with a size. An
/// `Align`, a picture or a leaf sized by its parent ([_sizedLeaf]) answers
/// a size, never a baseline. Anything else
/// -- a box nobody here knows -- may assert, and the question is asked
/// under the hatch, as every one was before; in a walk that starts as a
/// size it is asked as it always was, and what it holds is followed as
/// asked a baseline ([guardedSize]).
///
/// [baseline] is what [box] itself is asked: a dry baseline, which
/// [dryBaselineOf] and [guardedAsk] ask, or a size alone, which
/// [guardedSize] asks. A box reached with a baseline is asked its size
/// as well -- a row on its baseline measures each item and asks where it
/// stands, and so does a paragraph of each span's box on the baseline.
///
/// On Flutter 3.41 to 3.47 a proxy over a child that answers none asserts
/// too (flutter#189711), so there a proxy that may be asked a baseline is
/// passed only where what it holds surely answers one ([_answersOne]) or
/// where it asks its child itself and never `RenderBox` (a sized box, an
/// `IntrinsicWidth`, an `IntrinsicHeight`); and an `IgnoreBaseline`
/// reached with a baseline is followed with the size it is asked beside
/// it, which there may reach such a proxy: an item of a row on its
/// baseline, round a row of its own on its baseline over a `Semantics`
/// over a decorated empty box, threw when the outer row was asked its
/// baseline (`test/size_asked_dry_baseline_test.dart`). On every other
/// Flutter the walk passes it, as it always has.
///
/// There too NOT EVERY QUESTION GOES UNDER THE HATCH, because under it
/// Flutter keeps nothing, and a box's dry and laid-out baselines share one
/// cache: a line that measured its inline-block chip dry and then laid it
/// out read the chip's dry baseline, its first line's, on every other
/// Flutter and in every release build, and its laid-out one, its last
/// line's, in a debug build of 3.47 alone -- 216px apart at 60 wide
/// (`test/linebox_atom_alone_measured_share_test.dart`, n5).
///
/// [alignsOnly] answers false only where the question reaches an `Align`
/// asked a dry baseline, which asserts on every Flutter, or another box
/// that answers nothing dry ([_answersNoDry]): a box nobody here knows is
/// asked as it always was, and what it holds is not followed
/// ([guardedWhereProxiesAssert]) -- but for a scroll view, a rotated box and
/// an animated size asked a size, which hand it on to what they hold as a
/// proxy does ([_handsSizeOn]).
///
/// IN EVERY WALK A BOX THAT ANSWERS NOTHING DRY ([_answersNoDry]) opens the
/// hatch: asked outside it, it asserts on every Flutter, whatever else the
/// walk vouches for.
bool _answersUnguarded(RenderBox box, {bool baseline = true, bool alignsOnly = false}) {
  final sized = !baseline;
  final todo = <(RenderObject, bool)>[(box, baseline)];
  while (todo.isNotEmpty) {
    final (o, baseline) = todo.removeLast();
    if (_answersNoDry(o, baseline: baseline)) return false;
    // Whether what [o] holds may be asked a baseline.
    final bool asks;
    if (o is AsksGuarded) {
      asks = false;
    } else if (o is RenderIgnoreBaseline) {
      if (baseline && !_proxyAsksBox) continue;
      asks = false;
    } else if (o is RenderParagraph || o is RenderEditable) {
      // A span's box is asked a baseline where it stands on one, whatever
      // the text is asked; a text field's painters are asked nothing.
      final spans = o as ContainerRenderObjectMixin<RenderBox, TextParentData>;
      for (var c = spans.firstChild; c != null; c = spans.childAfter(c)) {
        todo.add((c, (c.parentData! as TextParentData).span?.alignment == PlaceholderAlignment.baseline));
      }
      continue;
    } else if (o is RenderBaseline) {
      asks = true;
    } else if (o is RenderFlex) {
      asks = baseline || o.crossAxisAlignment == CrossAxisAlignment.baseline;
    } else if (o is RenderProxyBoxMixin ||
        o is RenderStack ||
        o is RenderWrap ||
        o is RenderListBody ||
        o is RenderTable ||
        o is RenderPadding ||
        o is RenderConstrainedOverflowBox ||
        o is RenderConstraintsTransformBox ||
        o is RenderSizedOverflowBox ||
        o is RenderFractionallySizedOverflowBox ||
        o is RenderCustomSingleChildLayoutBox ||
        // Flutter's own, private.
        o.runtimeType.toString() == '_RenderScaledInlineWidget') {
      if (baseline &&
          _proxyAsksBox &&
          o is RenderProxyBoxMixin &&
          o is! ChildDryBaseline &&
          o is! RenderConstrainedBox &&
          o is! RenderIntrinsicWidth &&
          o is! RenderIntrinsicHeight &&
          !_answersOne(o.child, spanned: _spanned(o))) {
        return false;
      }
      asks = baseline;
    } else if (!baseline && (o is RenderPositionedBox || o is RenderImage || _sizedLeaf(o))) {
      asks = false;
    } else if (alignsOnly) {
      if (baseline && o is RenderPositionedBox) return false;
      if (baseline || !_handsSizeOn(o)) continue;
      asks = false;
    } else if (sized) {
      asks = true;
    } else {
      return false;
    }
    if (o is RenderStack && !baseline) {
      // A stack measures the children it does not place, and asks the
      // ones it places nothing until it is asked a baseline.
      for (var c = o.firstChild; c != null; c = o.childAfter(c)) {
        if (!(c.parentData! as StackParentData).isPositioned) todo.add((c, false));
      }
      continue;
    }
    o.visitChildren((c) => todo.add((c, asks)));
  }
  return true;
}

/// Whether [o], asked a dry baseline ([baseline]) or a size, answers by
/// asserting outside the hatch -- and under it, with what a release build
/// answers.
///
/// A BOX THAT RUNS ITS OWN LAYOUT CALLBACK ANSWERS NOTHING DRY, whatever it
/// is asked: a `LayoutBuilder` builds what it holds when it is laid out, and
/// asked a dry size, a dry baseline or an intrinsic one it throws "The
/// _RenderLayoutBuilder class does not support dry layout" on every
/// Flutter. Release builds answer for it a zero size and no baseline. A
/// page lowered to widgets puts one where a box is placed at a share of its
/// stack's height; a membership site's article cards stand such a stack on
/// a line's baseline, and the line, asked its size by the flex line round
/// it, threw at its first layout -- the page drew nothing at either width
/// (`test/linebox_layout_builder_span_dry_test.dart`).
///
/// A BOX WITH NO DRY BASELINE OF ITS OWN ASKED ONE: `RenderBox`'s own
/// answer asserts. Flutter 3.38.5 and 3.47.6 give none to a picture, a
/// flow, a custom multi-child layout, a rotated box, a scroll view and
/// every viewport, a texture, a platform view, an error box and the
/// performance overlay; 3.38.5 to an `Align` and an animated size too
/// ([_alignAsks], [_animatedSizeAsks]). Asked a size a shrink-wrapping
/// viewport asserts too. A box of anyone else's is not known here, and is
/// asked as it always was.
bool _answersNoDry(RenderObject o, {required bool baseline}) =>
    o is RenderObjectWithLayoutCallbackMixin ||
    (baseline
        ? o is RenderImage ||
              o is RenderFlow ||
              o is RenderCustomMultiChildLayoutBox ||
              o is RenderRotatedBox ||
              o is RenderViewportBase ||
              o is RenderListWheelViewport ||
              o is TextureBox ||
              o is PlatformViewRenderBox ||
              o is RenderDarwinPlatformView ||
              o is RenderErrorBox ||
              o is RenderPerformanceOverlay ||
              (o is RenderPositionedBox && _alignAsks) ||
              (o is RenderAnimatedSize && _animatedSizeAsks) ||
              // Flutter's own, private: a `SingleChildScrollView`'s.
              o.runtimeType.toString() == '_RenderSingleChildViewport'
        : o is RenderShrinkWrappingViewport);

/// Whether [o], asked a dry size or an intrinsic one, asks what it holds
/// the same and nothing else, as a proxy does, though the walk knows it
/// for none: a `SingleChildScrollView`'s viewport, a rotated box, an
/// animated size.
bool _handsSizeOn(RenderObject o) =>
    o is RenderRotatedBox || o is RenderAnimatedSize || o.runtimeType.toString() == '_RenderSingleChildViewport';

/// Whether an `Align` asked a dry baseline asks `RenderBox.computeDryBaseline`,
/// which asserts outside the hatch: through Flutter 3.38, not on 3.47.6.
/// Asked once in debug of one with no child, as [_proxyAsksBox] is.
final bool _alignAsks = _asksBoxBaseline(RenderPositionedBox.new);

/// Whether an animated size asked a dry baseline asserts, as an `Align`
/// does ([_alignAsks]).
final bool _animatedSizeAsks = _asksBoxBaseline(
  () => RenderAnimatedSize(vsync: const _NoTicks(), duration: Duration.zero),
);

/// Whether a box [make] makes, with no child, asserts when asked a dry
/// baseline outside the hatch. False in release.
bool _asksBoxBaseline(RenderBox Function() make) {
  var asks = false;
  assert(() {
    final box = make();
    try {
      box.getDryBaseline(const BoxConstraints(), TextBaseline.alphabetic);
    } on FlutterError {
      asks = true;
    } finally {
      box.dispose();
    }
    return true;
  }());
  return asks;
}

/// The ticker an animated size asked one question needs, which never runs.
class _NoTicks implements TickerProvider {
  const _NoTicks();

  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);
}

/// Whether [o] is a box sized by its parent that holds nothing: asked a
/// size, it answers from its constraints alone and asks nothing.
///
/// ITS SIZE IS ITS DRY LAYOUT. A box sized by its parent is laid out by
/// `performResize`, which asks its own `computeDryLayout`, so one that has
/// been laid out answers a dry size without asserting, and an intrinsic
/// one by `RenderBox`'s own answer; with nothing under it, nothing else is
/// asked. A picture drawn from a vector file is one, and every inline icon
/// a page draws so is a span's box holding one: read as a box nobody here
/// knows, each walk that reached one opened the hatch over its whole
/// paragraph, and a price table's 245 network chips -- an inline-block
/// alone on its line round an inline picture, each -- laid its page out
/// in 50 to 100s at phone widths in a debug build of 3.47, against 6 to
/// 9s with the walk passing the picture
/// (`test/dry_baseline_kept_test.dart`). NEGATIVE: a leaf that lays
/// itself out (`performLayout`) may answer a dry size by asserting, and
/// is asked under the hatch, as before.
bool _sizedLeaf(RenderObject o) {
  // `sizedByParent` is @protected, and only a subclass may read it; this
  // walk reads it from outside on purpose, as layout itself does, and no
  // public getter says it (Flutter 3.47's analyzer flags the read).
  // ignore: invalid_use_of_protected_member
  if (o is! RenderBox || !o.sizedByParent) return false;
  var holds = false;
  o.visitChildren((_) => holds = true);
  return !holds;
}

/// Whether [box], asked a dry baseline, surely answers one: a paragraph,
/// which always does, under boxes that each answer what the box they hold
/// answers -- Flutter's proxies that keep their child's baseline, a
/// padding, a sized box, an overflow box, the box Flutter scales a span's
/// child in, a proxy that answers its child's on every Flutter
/// ([ChildDryBaseline]) -- or a flex, a wrap, a stack or a box of css_box's
/// that says so ([PassesBaseline]) holding one, each of which answers the
/// baseline of an item that has one. Anything else may answer none.
///
/// A PROXY OF CSS_BOX'S IS PASSED THROUGH. Where Flutter's proxies assert
/// over a child that answers no baseline (flutter#189711, 3.41 to 3.47) the
/// walk fears each proxy it cannot see through, and one of css_box's own
/// -- a sticky box, a fixed layer -- answers its child's baseline and asks
/// nothing else: read as one that may answer none, it put the paragraph
/// under the hatch on those Flutters alone, and a line measured there kept
/// nothing it measured where 3.38 keeps it shut
/// (`test/linebox_align_span_dry_test.dart`, NEGATIVE).
///
/// An inline-block is a span's box under the `Semantics` Flutter tags it
/// with, so every walk that reaches a paragraph asks this of what each
/// inline-block on the baseline holds: an item of a blurred card, a box
/// that measures its content, a row of a label and an icon, a button.
/// Read as answering none, each put its whole paragraph under the hatch.
/// Where [box] is asked what the paragraph asks ([spanned], [_spanned]) it
/// is asked with no bound on its height, and laid out so: what stands on
/// its edge ([PassesBaseline.standsOnEdge]) has an edge to stand on there,
/// or throws when it is laid out. A box that measures what it holds asks
/// it in another room, and is followed by the walk on its own.
bool _answersOne(RenderObject? box, {bool spanned = false}) {
  for (var o = box; o != null;) {
    if (o is RenderParagraph) return true;
    if (spanned && o is PassesBaseline && o.standsOnEdge) return true;
    if (o is RenderFlex ||
        o is RenderWrap ||
        (o is RenderStack && o is! RenderIndexedStack) ||
        (o is PassesBaseline && o.passes)) {
      var one = false;
      o.visitChildren((c) => one = one || _answersOne(c, spanned: spanned));
      return one;
    }
    if (_handsOn(o) ||
        o is ChildDryBaseline ||
        o is RenderIntrinsicWidth ||
        o is RenderIntrinsicHeight ||
        o is RenderConstrainedOverflowBox) {
      o = (o as RenderObjectWithChildMixin<RenderBox>).child;
      continue;
    }
    return false;
  }
  return false;
}

/// Whether [o] is one of Flutter's boxes that, asked a dry layout or a dry
/// baseline, ask what they hold the same in the room they lay it out in,
/// ask it nothing else, and answer the baseline it answers: its proxies
/// with no layout of their own, a padding, a sized box, the box Flutter
/// scales a span's child in.
bool _handsOn(RenderObject o) =>
    o is RenderSemanticsAnnotations ||
    o is RenderDecoratedBox ||
    o is RenderRepaintBoundary ||
    o is RenderOpacity ||
    o is RenderMouseRegion ||
    o is RenderPointerListener ||
    o is RenderSemanticsGestureHandler ||
    o is RenderIgnorePointer ||
    o is RenderAbsorbPointer ||
    o is RenderClipRect ||
    o is RenderClipRRect ||
    o is RenderClipOval ||
    o is RenderClipPath ||
    o is RenderBackdropFilter ||
    o is RenderTransform ||
    o is RenderPadding ||
    o is RenderConstrainedBox ||
    // Flutter's own, private.
    o.runtimeType.toString() == '_RenderScaledInlineWidget' ||
    o.runtimeType.toString() == '_RenderColoredBox';

/// Whether [box] is the box a span on a paragraph's baseline holds, or one
/// under it through boxes that hand on what they are asked ([_handsOn]):
/// asked what the paragraph asks, in the room it lays the span out in.
bool _spanned(RenderObject box) {
  for (var o = box; ;) {
    final up = o.parent;
    if (up is RenderParagraph) {
      return (o.parentData! as TextParentData).span?.alignment == PlaceholderAlignment.baseline;
    }
    if (up == null || !_handsOn(up)) return false;
    o = up;
  }
}

/// A box of css_box's that answers a dry baseline wherever a box it holds
/// answers one ([passes]), so the walk passes it too: a `LastBaseline`
/// answers its child's last line; an `Inset`, a `ShrinkWidth`, a
/// `FractionalWidth`, a `Balance`, a `LineBox`, a table's cell and an
/// `EdgeBaseline` their child's, where they place it; and a `FlexLine` its
/// first item's, synthesized where the item has none.
@internal
mixin PassesBaseline on RenderBox {
  /// Whether, as it is set, the box answers a dry baseline wherever a box
  /// it holds answers one. An `EdgeBaseline` that stands on its edge
  /// alone answers its height, which is none where the height has no
  /// bound.
  bool get passes => true;

  /// Whether the box answers a dry baseline whatever it holds where its
  /// height has a bound: an `EdgeBaseline` stands on its bottom edge where
  /// what it holds answers none.
  bool get standsOnEdge => false;
}

/// Whether a proxy asked a dry baseline its child does not answer asks
/// `RenderBox.computeDryBaseline` instead, which asserts outside the hatch
/// (flutter#189711, 3.41 to 3.47). Asked once in debug, of a plain proxy
/// with no child -- a `ConstrainedBox` there answers for itself and never
/// asserts -- so what the throw leaves set is left on that box alone.
final bool _proxyAsksBox = () {
  var asks = false;
  assert(() {
    try {
      RenderProxyBox().getDryBaseline(const BoxConstraints(), TextBaseline.alphabetic);
    } on FlutterError {
      asks = true;
    }
    return true;
  }());
  return asks;
}();

/// A proxy whose dry baseline is its child's, and none where the child has
/// none.
///
/// That is what `RenderProxyBoxMixin` answers through Flutter 3.38 and
/// again from 3.48. From 3.41 to 3.47 it asks `RenderBox.computeDryBaseline`
/// where the child answers none, which asserts in debug (flutter#189711):
/// an `IgnoreBaseline`, a picture or an empty box under one of css_box's
/// proxies throws wherever a row or a paragraph asks across it. Every
/// proxy of css_box's that does not answer for itself answers this way.
mixin ChildDryBaseline on RenderProxyBoxMixin<RenderBox> {
  @override
  double? computeDryBaseline(covariant BoxConstraints constraints, TextBaseline baseline) =>
      child?.getDryBaseline(constraints, baseline);
}

/// A container that answers ONE baseline, whichever is asked of it.
///
/// A flex container's baseline is its first line's, taken from an item
/// (css-flexbox-1 8.5), and it holds no line box of its own -- so an
/// inline-block around one has no in-flow last line to stand on and
/// stands on the number the container gives. Walked into for a lower
/// line, a news site's other story shape -- an `inline-block` around a
/// `flex-direction: column` pulled up 4px -- stood on its SECOND line and
/// its row came out 40 tall where the page draws 44.
mixin OneBaseline on RenderBox {}

/// A box that can say where its LAST line's baseline is without being laid
/// out.
///
/// [dryLastBaselineOf] works the answer out from the outside -- a box's
/// height less what hangs under its last child's last baseline -- which
/// only holds where the child's bottom edge is the box's. A box with an
/// edge of its own under the line answers for itself instead.
mixin DryLastBaseline on RenderBox {
  /// This box's last baseline, from its top, at [constraints].
  double? dryLastBaseline(BoxConstraints constraints, TextBaseline baseline);
}

/// The lowest baseline of an in-flow line in [box], from its top, asked of
/// a box that has not been laid out.
///
/// A flex line asks each item where its baseline is BEFORE it lays
/// anything out (css-flexbox-1 8.5), and a paragraph asks the same of a
/// placeholder it is measuring -- and Flutter answers an intrinsic height
/// the same way. Answered with the FIRST baseline -- which is what a proxy
/// forwards -- an inline-block hangs its whole column from its first line,
/// and the line it stands on comes out one leading too tall: forty of
/// a news site's story links did that, 3px each.
///
/// A paragraph keeps its lines to itself and a dry pass has no caret to
/// put at the end of them; under a FORCED strut, which is how a line of
/// lowered text is set, every line puts its baseline the same distance
/// down, so the last one's is the first one's plus every line above it.
///
/// Anywhere else the answer has to come from the box itself: a box knows
/// what it offers its child and where it puts it, and nothing outside it
/// does. [DryLastBaseline] is that answer, and a box that comes to exactly
/// its child's size at the same constraints needs no answer of its own --
/// it has no edge under the line and hands the offer straight down. Where
/// neither holds, the FIRST baseline is what the box already reports and
/// is the only number that is certainly not invented.
double? dryLastBaselineOf(RenderBox box, BoxConstraints constraints, TextBaseline baseline) {
  // An `IgnoreBaseline` answers none, dry as laid out
  // ([RenderLastBaseline.lastBaselineOf]).
  if (box is RenderIgnoreBaseline) return null;
  if (box is DryLastBaseline) return box.dryLastBaseline(constraints, baseline);
  // A flex or grid container gives ONE baseline, its first item's
  // (css-flexbox-1 8.5, css-grid-1 11.8), and holds no line box of its own
  // for a lower line to be found in.
  if (box is OneBaseline) return dryBaselineOf(box, constraints, baseline);
  if (box is RenderParagraph) return _lastLine(box, constraints, baseline);
  // Flutter's own padding, which cannot carry the mixin: its bottom edge
  // hangs under the last line.
  if (box is RenderPadding) {
    final c = box.child;
    if (c == null) return null;
    final e = box.padding.resolve(box.textDirection);
    final b = dryLastBaselineOf(c, constraints.deflate(e), baseline);
    return b == null ? null : b + e.top;
  }
  // Flutter's own SizedBox and ConstrainedBox, which cannot carry the mixin
  // either: they offer their child their own constraints ENFORCED, put it
  // at their top and come to its size, so their last line is the child's,
  // asked at that offer. Asked at the offer it was handed instead, a stated
  // width the words wrap in (an `inline-block` with a `width`) comes to one
  // long line, is not the box's size, and the box answered its FIRST line:
  // a two-line heading hung its strut from its first, and the section under
  // it stood 2px high (`fixtures/inline-block-stated-width-last-line`).
  // What the walk finds down there is checked against the box's first line
  // ([lastNotAboveFirst]).
  if (box is RenderConstrainedBox) {
    final c = box.child;
    if (c == null) return null;
    return lastNotAboveFirst(
      dryLastBaselineOf(c, box.additionalConstraints.enforce(constraints), baseline),
      () => dryBaselineOf(box, constraints, baseline),
    );
  }
  RenderBox? last;
  box.visitChildren((c) {
    if (c is! RenderBox) return;
    final data = c.parentData;
    if (data is StackParentData && data.isPositioned) return;
    last = c;
  });
  final kid = last;
  if (kid == null) return dryBaselineOf(box, constraints, baseline);
  if (guardedSize(box, () => kid.getDryLayout(constraints) == box.getDryLayout(constraints))) {
    return dryLastBaselineOf(kid, constraints, baseline);
  }
  // A BLOCK COLUMN, which is what a block flow is lowered to. The last
  // child's bottom edge IS the column's, so its last line is the column's
  // last line, that much above the bottom -- and the column offers it the
  // width it came to itself, which is the one thing a dry pass has to know
  // to ask it anything. Stacked any other way (a spacer under the last
  // child, an alignment that leaves room below it) there is no telling,
  // and the FIRST baseline is what the box already reports.
  if (box is RenderFlex &&
      box.direction == Axis.vertical &&
      box.mainAxisSize == MainAxisSize.min &&
      box.mainAxisAlignment == MainAxisAlignment.start) {
    final size = guardedSize(box, () => box.getDryLayout(constraints));
    final inner = BoxConstraints(
      minWidth: box.crossAxisAlignment == CrossAxisAlignment.stretch ? size.width : 0.0,
      maxWidth: size.width,
    );
    final b = dryLastBaselineOf(kid, inner, baseline);
    if (b != null) return b + size.height - guardedSize(kid, () => kid.getDryLayout(inner)).height;
  }
  return dryBaselineOf(box, constraints, baseline);
}

/// [last], a last baseline a walk found under a box, where it is not above
/// the box's [first] baseline; else the first.
///
/// A box's last line is never above its first, and a walk that answers one
/// above it has lost an offset on the way down: past a box of a stated size
/// it reaches what the box holds at the box's own offer, and there a box that
/// offers what it holds less than it was offered and centres it -- a label
/// centred in a `min-height` button, an overflow box round it -- comes to the
/// same size as what it holds, and is passed as if it put it at its top. A
/// button's label stood 2.5px high in its line, and a centred button's
/// 10.5px. The first baseline is the box's own answer, as before.
@internal
double? lastNotAboveFirst(double? last, double? Function() first) {
  if (last == null) return first();
  final f = first();
  return f != null && last < f ? f : last;
}

/// Where [box]'s last line puts its baseline, from its top.
///
/// ONE LINE IS MEASURED, NOT DERIVED. Every line of a forced strut puts its
/// baseline the same distance down, so the last line's is the first line's
/// plus the height of every line above it -- and the height of ONE line is
/// what the paragraph comes to with all the room in the world, which is
/// Skia's own number. Worked out instead as the strut's `fontSize *
/// height`, it came out a pixel short on a news site's faces and took every
/// line under it with it.
///
/// A line only holds still if nothing on it is taller than the strut: a
/// placeholder makes the line it stands on as tall as itself, and then the
/// first baseline is the answer, the same one a proxy would have forwarded.
///
/// A HARD BREAK MAKES A LINE LIKE ANY OTHER. A `<br>` ends a line box
/// (CSS 2.1 9.2.4, 10.8) and the next one is the strut's height like every
/// line under a forced strut -- an empty one too -- so the room in the
/// world is not ONE line but one per hard break and one more: each break
/// Skia must take (UAX #14 LB4, LB5) starts a line however wide the room.
/// Answered with the first baseline instead, the answer did not stay dry:
/// Flutter keeps a box's dry and laid-out baselines in ONE cache, keyed by
/// the constraints, so a flex line that measured its item first handed
/// the same number to the row that then laid it out. A newspaper's desktop
/// footer is a `display: inline-block` paragraph of two sentences a
/// `<br>` apart in a flex row: it stood on its first line, 6px under the
/// row's strut, and the row came out 40 tall where Chrome's is 35
/// (`fixtures/inline-block-break-last-baseline`). NEGATIVE: lines a width
/// wraps are not counted here -- the room in the world has none.
double? _lastLine(RenderParagraph box, BoxConstraints constraints, TextBaseline baseline) {
  final first = dryBaselineOf(box, constraints, baseline);
  if (first == null) return null;
  var placeheld = false;
  box.text.visitChildren((s) {
    if (s is PlaceholderSpan) placeheld = true;
    return !placeheld;
  });
  if (placeheld) {
    // A PLACEHOLDER'S LINE IS LAID OUT, NOT DERIVED. A box on a line makes
    // it as tall as it asks, so the lines cannot be counted off the
    // strut; the paragraph is laid out on a painter of its own with every
    // box at its dry size ([onDryPainter]), as a line box asked dry does
    // (`linebox.dart`), and the last line's baseline is read off it --
    // the first's plus how far below it Skia set the last. Answered with
    // the first baseline instead, a news site's two-line bylines, ending
    // in a comments link of their own, stood on their first line in a row
    // a card's `IntrinsicHeight` measured: Flutter keeps a box's dry and
    // laid-out baselines in one cache, so the row laid out stood on the
    // same number, and every card came out 2.4px short of the strut's
    // descent under the last line (CSS 2.1 10.8.1: an inline-block's
    // baseline is its last line's). WHATEVER THE STRUT: laid out, the
    // lines are the painter's whether it forces them or not, and the
    // bylines' strut does not (their words are in three sizes).
    // NEGATIVE: one line, whose last is its first; a box that answers no
    // dry size or baseline -- the first, as before.
    final down = onDryPainter(box, constraints, (painter) {
      final lines = painter.computeLineMetrics();
      return lines.length < 2 ? 0.0 : lines.last.baseline - lines.first.baseline;
    });
    return first + (down ?? 0.0);
  }
  if (box.strutStyle?.forceStrutHeight != true) return first;
  final (h, all) = guardedSize(box, () {
    return (box.getDryLayout(constraints.widthConstraints()).height, box.getDryLayout(const BoxConstraints()).height);
  });
  final lines = _hardBreak.allMatches(box.text.toPlainText(includeSemanticsLabels: false)).length + 1;
  final one = all / lines;
  if (one <= 0 || one > h) return first;
  return first + h - one;
}

/// The mandatory breaks of UAX #14 (LB4, LB5): BK, CR, LF and NL, a CR LF
/// pair one break.
final _hardBreak = RegExp('\r\n|[\n\r\u000B\u000C\u0085\u2028\u2029]');

/// What [read] reads off [box]'s text laid out at [constraints] on a
/// painter of its own, every box on its lines at its dry size and, where it
/// stands on the baseline, its dry baseline -- as the paragraph lays its
/// boxes out (`layoutInlineChildren`): each in the width of the line. Null
/// where a box is missing or answers no baseline it is stood on.
///
/// A paragraph laid out is asked no question it was not laid out for;
/// this is how a box asked BEFORE layout -- an intrinsic height, a dry
/// layout, a dry baseline -- reads the lines the paragraph will set.
///
/// Each span's box is asked as the paragraph would ask it, through
/// [guardedWhereProxiesAssert]: a stack on the baseline whose placed badge
/// is an `Align` asserts there on every Flutter.
@internal
R? onDryPainter<R>(RenderParagraph box, BoxConstraints constraints, R Function(TextPainter painter) read) =>
    guardedWhereProxiesAssert(box, () => _onDryPainter(box, constraints, read));

R? _onDryPainter<R>(RenderParagraph box, BoxConstraints constraints, R Function(TextPainter painter) read) {
  final spans = <PlaceholderSpan>[];
  box.text.visitChildren((span) {
    if (span is PlaceholderSpan) spans.add(span);
    return true;
  });
  final room = BoxConstraints(maxWidth: constraints.maxWidth);
  final dims = <PlaceholderDimensions>[];
  var child = box.firstChild;
  for (final span in spans) {
    if (child == null) return null;
    double? offset;
    if (span.alignment == ui.PlaceholderAlignment.baseline) {
      offset = child.getDryBaseline(room, span.baseline ?? TextBaseline.alphabetic);
      if (offset == null) return null;
    }
    dims.add(
      PlaceholderDimensions(
        size: child.getDryLayout(room),
        alignment: span.alignment,
        baseline: span.baseline,
        baselineOffset: offset,
      ),
    );
    child = box.childAfter(child);
  }
  if (child != null) return null;
  final painter = TextPainter(
    text: box.text,
    textAlign: box.textAlign,
    textDirection: box.textDirection,
    textScaler: box.textScaler,
    maxLines: box.maxLines,
    ellipsis: box.overflow == TextOverflow.ellipsis ? '\u2026' : null,
    locale: box.locale,
    strutStyle: box.strutStyle,
    textWidthBasis: box.textWidthBasis,
    textHeightBehavior: box.textHeightBehavior,
  )..setPlaceholderDimensions(dims);
  try {
    final wraps = box.softWrap || box.overflow == TextOverflow.ellipsis;
    painter.layout(minWidth: constraints.minWidth, maxWidth: wraps ? constraints.maxWidth : double.infinity);
    return read(painter);
  } finally {
    painter.dispose();
  }
}
