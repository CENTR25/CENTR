// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
// Only reachable on web via the conditional import in install_prompt_bridge.dart.
import 'dart:html' as html;
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Web bridge for the "Agregar a Inicio" (PWA install) prompt.
///
/// Chrome/Android fires `beforeinstallprompt` once, usually BEFORE Flutter has
/// booted, so web/index.html captures it into `window.__a2hsDeferred` and fires
/// `a2hs-ready`; this class reads that stash. iOS Safari has no such event and
/// no programmatic install, so the UI shows manual instructions there.
class InstallPromptBridge {
  static const _storageKey = 'prgs-install-dismissed';

  void Function()? _onChange;
  html.EventListener? _readyListener;
  html.EventListener? _installedListener;
  bool _installed = false;

  bool get isSupported => true;

  bool get isStandalone {
    if (_installed) return true;
    final mq = html.window.matchMedia('(display-mode: standalone)').matches;
    // iOS Safari exposes navigator.standalone instead of the media query.
    final nav = globalContext['navigator'];
    final ios = nav.isA<JSObject>() ? (nav as JSObject)['standalone'] : null;
    return mq || (ios.isA<JSBoolean>() && (ios as JSBoolean).toDart);
  }

  bool get isIosSafari {
    final ua = html.window.navigator.userAgent;
    final lower = ua.toLowerCase();
    // iPadOS 13+ reports as a Mac; tell it apart by touch support.
    final iPadOs = lower.contains('macintosh') &&
        (html.window.navigator.maxTouchPoints ?? 0) > 1;
    final ios = RegExp(r'iphone|ipad|ipod').hasMatch(lower) || iPadOs;
    final webkit = lower.contains('webkit') &&
        !RegExp(r'crios|fxios|edgios').hasMatch(lower);
    return ios && webkit;
  }

  bool get canPromptNative => globalContext['__a2hsDeferred'].isA<JSObject>();

  bool get wasDismissed {
    try {
      return html.window.localStorage[_storageKey] == '1';
    } catch (_) {
      return false; // private mode / blocked storage
    }
  }

  void rememberDismissed() {
    try {
      html.window.localStorage[_storageKey] = '1';
    } catch (_) {}
  }

  void listen(void Function() onChange) {
    _onChange = onChange;
    _readyListener = (_) => _onChange?.call();
    _installedListener = (_) {
      _installed = true;
      _onChange?.call();
    };
    html.window.addEventListener('a2hs-ready', _readyListener);
    html.window.addEventListener('appinstalled', _installedListener);
  }

  /// Shows Chrome's native install dialog. The deferred event is single-use.
  Future<void> promptNative() async {
    final deferred = globalContext['__a2hsDeferred'];
    if (!deferred.isA<JSObject>()) return;
    globalContext['__a2hsDeferred'] = null;
    try {
      final res = (deferred as JSObject).callMethod('prompt'.toJS);
      if (res.isA<JSPromise>()) await (res as JSPromise).toDart;
    } catch (_) {}
  }

  void dispose() {
    if (_readyListener != null) {
      html.window.removeEventListener('a2hs-ready', _readyListener);
    }
    if (_installedListener != null) {
      html.window.removeEventListener('appinstalled', _installedListener);
    }
    _onChange = null;
  }
}
