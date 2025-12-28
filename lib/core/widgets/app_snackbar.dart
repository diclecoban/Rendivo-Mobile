import 'dart:async';

import 'package:flutter/material.dart';

class AppSnackbar {
  AppSnackbar._();

  static OverlayEntry? _entry;
  static Timer? _timer;

  static void show(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    _timer?.cancel();
    _entry?.remove();

    final overlay = Overlay.of(context);
    if (overlay == null) return;

    final overlayEntry = OverlayEntry(
      builder: (ctx) {
        final padding = MediaQuery.of(ctx).padding.top + 12;
        return Positioned(
          top: padding,
          left: 16,
          right: 16,
          child: _AppSnackbarBody(message: message),
        );
      },
    );

    overlay.insert(overlayEntry);
    _entry = overlayEntry;

    _timer = Timer(duration, () {
      if (_entry == overlayEntry) {
        overlayEntry.remove();
        _entry = null;
      }
      _timer = null;
    });
  }
}

class _AppSnackbarBody extends StatefulWidget {
  final String message;

  const _AppSnackbarBody({required this.message});

  @override
  State<_AppSnackbarBody> createState() => _AppSnackbarBodyState();
}

class _AppSnackbarBodyState extends State<_AppSnackbarBody>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    final curve = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnimation =
        Tween(begin: const Offset(0, -0.2), end: Offset.zero).animate(curve);
    _fadeAnimation = Tween(begin: 0.0, end: 1.0).animate(curve);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFE5F2),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              widget.message,
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
