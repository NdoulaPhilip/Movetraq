import 'package:flutter/material.dart';

class DisplayPreferences extends ChangeNotifier {
  bool _reduceMotion = false;
  bool _largerText = false;
  String? _userId;
  bool get reduceMotion => _reduceMotion;
  bool get largerText => _largerText;
  void resetForUser(String? userId) {
    if (_userId == userId) return;
    _userId = userId;
    _reduceMotion = false;
    _largerText = false;
    notifyListeners();
  }

  void applyServer(String userId, Map<String, dynamic> values) {
    if (_userId != userId) return;
    final display = values['display_preferences'];
    final accessibility = values['accessibility_preferences'];
    _reduceMotion = display is Map && display['reduce_motion'] == true;
    _largerText = (display is Map && display['larger_text'] == true) ||
        (accessibility is Map && accessibility['larger_text'] == true);
    notifyListeners();
  }

  MediaQueryData mediaQuery(MediaQueryData system) => system.copyWith(
      disableAnimations: system.disableAnimations || reduceMotion,
      textScaler: largerText
          ? system.textScaler.clamp(minScaleFactor: 1.15)
          : system.textScaler);
}

class NoMotionTransitions extends PageTransitionsBuilder {
  const NoMotionTransitions();
  @override
  Widget buildTransitions<T>(
          PageRoute<T> route,
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
          Widget child) =>
      child;
}
