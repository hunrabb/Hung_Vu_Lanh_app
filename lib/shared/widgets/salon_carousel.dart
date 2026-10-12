import 'dart:async';

import 'package:flutter/material.dart';

/// Rotates visible banners, pauses in the background and respects reduced motion.
class SalonCarousel extends StatefulWidget {
  const SalonCarousel({super.key, required this.children, this.height = 280});
  final List<Widget> children;
  final double height;

  @override
  State<SalonCarousel> createState() => _SalonCarouselState();
}

class _SalonCarouselState extends State<SalonCarousel>
    with WidgetsBindingObserver {
  final _pages = PageController();
  Timer? _timer;
  int _index = 0;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _schedule();
  }

  @override
  void didUpdateWidget(covariant SalonCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_index >= widget.children.length) {
      _index = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pages.hasClients) _pages.jumpToPage(0);
      });
    }
    _schedule();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    if (!mounted ||
        !_foreground ||
        widget.children.length < 2 ||
        !TickerMode.valuesOf(context).enabled ||
        MediaQuery.disableAnimationsOf(context)) {
      return;
    }
    _timer = Timer(const Duration(seconds: 3), () async {
      if (!mounted || !_pages.hasClients) return;
      await _pages.animateToPage(
        (_index + 1) % widget.children.length,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
      if (mounted) _schedule();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.children.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        SizedBox(
          height: widget.height,
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollStartNotification) _timer?.cancel();
              if (notification is ScrollEndNotification) _schedule();
              return false;
            },
            child: PageView(
              controller: _pages,
              onPageChanged: (index) => setState(() => _index = index),
              children: widget.children,
            ),
          ),
        ),
        if (widget.children.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var index = 0; index < widget.children.length; index++)
                Semantics(
                  button: true,
                  selected: index == _index,
                  label: 'Banner ${index + 1} trên ${widget.children.length}',
                  child: InkResponse(
                    radius: 24,
                    onTap: () {
                      _timer?.cancel();
                      _pages.animateToPage(
                        index,
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeOutCubic,
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 14,
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        height: 5,
                        width: index == _index ? 24 : 7,
                        decoration: BoxDecoration(
                          color: index == _index
                              ? const Color(0xFF8B6C45)
                              : const Color(0xFFDDD1BF),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
