import 'package:flutter/material.dart';

/// Glowing, right-to-left scrolling headline for the phone dashboard.
/// Animation is automatically paused when Flutter's TickerMode is disabled.
class LedMarqueeTitle extends StatefulWidget {
  const LedMarqueeTitle({
    super.key,
    this.message = 'Chúc quý khách thượng lộ bình an',
    this.compact = false,
  });

  final String message;
  final bool compact;

  @override
  State<LedMarqueeTitle> createState() => _LedMarqueeTitleState();
}

class _LedMarqueeTitleState extends State<LedMarqueeTitle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 10),
  )..repeat();

  static const TextStyle _ledStyle = TextStyle(
    fontFamily: 'monospace',
    fontSize: 19,
    fontWeight: FontWeight.w900,
    letterSpacing: 0.8,
    color: Color(0xFFFF5757),
    shadows: [
      Shadow(color: Color(0xFFFF2929), blurRadius: 5),
      Shadow(color: Color(0x88FF2020), blurRadius: 12),
    ],
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: widget.message,
    child: ExcludeSemantics(child: LayoutBuilder(
      builder: (context, constraints) {
        final style = widget.compact
            ? _ledStyle.copyWith(
                fontSize: 12,
                color: const Color(0xFF82AEC7),
                letterSpacing: 0.4,
                shadows: const [])
            : _ledStyle;
        final painter = TextPainter(
          text: TextSpan(text: widget.message, style: style),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 1,
        )..layout();
        final textWidth = painter.width;
        painter.dispose();
        final width = constraints.maxWidth;
        return SizedBox(
          height: widget.compact ? 20 : 34,
          child: ClipRect(child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final left = width -
                  _controller.value * (width + textWidth + 24);
              return Stack(clipBehavior: Clip.none, children: [
                Positioned(
                  left: left,
                  top: 0,
                  bottom: 0,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: child,
                  ),
                ),
              ]);
            },
            child: Text(
              widget.message,
              maxLines: 1,
              softWrap: false,
              style: style,
              key: const Key('led-marquee-text'),
            ),
          )),
        );
      },
    )),
  );
}
