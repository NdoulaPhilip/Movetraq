import 'package:flutter/material.dart';

class NoBackWrapper extends StatelessWidget {
  final Widget child;
  const NoBackWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
      },
      child: child,
    );
  }
}
