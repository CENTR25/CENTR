import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

int _nextExerciseGifViewId = 0;

class ExerciseGifView extends StatefulWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget Function(BuildContext context, String url)? placeholder;
  final Widget Function(BuildContext context, String url, Object error)?
  errorWidget;

  const ExerciseGifView({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
  });

  @override
  State<ExerciseGifView> createState() => _ExerciseGifViewState();
}

class _ExerciseGifViewState extends State<ExerciseGifView> {
  late String _viewType;
  bool _isLoaded = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _registerImage(widget.url);
  }

  @override
  void didUpdateWidget(covariant ExerciseGifView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _registerImage(widget.url);
    }
  }

  void _registerImage(String url) {
    _isLoaded = false;
    _hasError = false;
    _viewType = 'exercise-gif-${_nextExerciseGifViewId++}';

    final image = html.ImageElement()
      ..alt = 'GIF del ejercicio'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.display = 'block'
      ..style.objectFit = _cssObjectFit(widget.fit);

    image.onLoad.listen((_) {
      if (mounted) setState(() => _isLoaded = true);
    });
    image.onError.listen((_) {
      if (mounted) setState(() => _hasError = true);
    });

    // Do not set crossOrigin: the browser can display a cross-origin GIF in
    // a native <img> without CORS headers as long as Flutter does not read
    // the decoded pixels. This avoids the CORS limitation of Flutter Web's
    // image codec for this public media CDN.
    image.src = url;

    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => image,
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError && widget.errorWidget != null) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: widget.errorWidget!(context, widget.url, 'GIF load failed'),
      );
    }

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (!_isLoaded)
            widget.placeholder?.call(context, widget.url) ??
                const SizedBox.shrink(),
          HtmlElementView(viewType: _viewType),
        ],
      ),
    );
  }
}

String _cssObjectFit(BoxFit fit) {
  switch (fit) {
    case BoxFit.contain:
      return 'contain';
    case BoxFit.cover:
      return 'cover';
    case BoxFit.fill:
      return 'fill';
    case BoxFit.none:
      return 'none';
    case BoxFit.scaleDown:
      return 'scale-down';
    case BoxFit.fitWidth:
    case BoxFit.fitHeight:
      return 'contain';
  }
}
