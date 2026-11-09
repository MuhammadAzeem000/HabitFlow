import 'package:flutter/material.dart';

/// App-wide messenger, so snackbars can be dismissed from outside a screen.
final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Dismisses any visible snackbar when a new page opens.
///
/// Without this, an "Undo" snackbar from one screen stays visible on the
/// next, where its button can be tapped by accident (found in device
/// testing: it sat exactly where the challenge screen's main button is).
class SnackBarRouteObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute) {
      scaffoldMessengerKey.currentState?.hideCurrentSnackBar();
    }
  }
}
