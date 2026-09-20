// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
// This file is only reachable on web via the conditional import in main.dart.
import 'dart:html' as html;

/// Listens for the 'flutter-swipe-back' event dispatched by the guard script
/// in web/index.html (fired when an iOS edge-swipe hits the initial document
/// history entry) and forwards it to the app as an in-app back intent.
void initSwipeBackHandler(void Function() onSwipeBack) {
  html.window.addEventListener('flutter-swipe-back', (_) => onSwipeBack());
}
