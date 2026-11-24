/// Non-web stub: there is no "Add to Home Screen" flow on android/ios builds.
class InstallPromptBridge {
  InstallPromptBridge();

  bool get isSupported => false;
  bool get isStandalone => true;
  bool get isIosSafari => false;
  bool get canPromptNative => false;
  bool get wasDismissed => true;

  void listen(void Function() onChange) {}
  Future<void> promptNative() async {}
  void rememberDismissed() {}
  void dispose() {}
}
