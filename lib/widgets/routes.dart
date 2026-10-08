import 'package:flutter/material.dart';

/// Soft fade with a slight rise, used for every screen change.
Route<T> softRoute<T>(Widget page, {int milliseconds = 380}) {
  return PageRouteBuilder<T>(
    transitionDuration: Duration(milliseconds: milliseconds),
    reverseTransitionDuration: Duration(milliseconds: milliseconds - 80),
    pageBuilder: (context, animation, secondary) => page,
    transitionsBuilder: (context, animation, secondary, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.97, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}
