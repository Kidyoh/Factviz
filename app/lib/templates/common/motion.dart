import 'package:flutter/widgets.dart';

/// True when the user asked the OS to reduce motion.
bool reduceMotionOf(BuildContext context) => MediaQuery.disableAnimationsOf(context);

/// Global switch for never-ending ambient motion (starfield, orbiting logo,
/// glowing search border). Tests turn it off so frames can settle.
bool ambientMotionEnabled = true;

/// Whether ambient, looping decoration may animate here.
bool ambientMotionOf(BuildContext context) => ambientMotionEnabled && !reduceMotionOf(context);

/// Drives a template's intro animation.
///
/// Starts on first build, or jumps straight to the end when the user prefers
/// reduced motion. Replays are done by giving the template a new key, which
/// recreates this state from scratch.
mixin EntranceAnimation<W extends StatefulWidget> on State<W>, TickerProvider {
  late final AnimationController entrance = AnimationController(vsync: this, duration: entranceDuration);

  Duration get entranceDuration;

  bool _started = false;

  bool get reduceMotion => reduceMotionOf(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (reduceMotion) {
      entrance.value = 1;
    } else {
      entrance.forward();
    }
  }

  @override
  void dispose() {
    entrance.dispose();
    super.dispose();
  }
}
