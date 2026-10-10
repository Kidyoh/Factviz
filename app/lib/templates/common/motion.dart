import 'package:flutter/widgets.dart';

/// True when the user asked the OS to reduce motion.
bool reduceMotionOf(BuildContext context) => MediaQuery.disableAnimationsOf(context);

/// Global switch for looping decorative motion (the loader animation). Tests
/// turn it off so frames can settle.
bool ambientMotionEnabled = true;

/// Whether looping decoration may animate here.
bool ambientMotionOf(BuildContext context) => ambientMotionEnabled && !reduceMotionOf(context);
