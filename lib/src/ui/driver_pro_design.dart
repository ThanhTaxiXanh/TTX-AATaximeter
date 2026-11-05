import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import '../core/taximeter_engine.dart';

/// TTX Driver Pro presentation system. No billing or GPS logic lives here.
abstract final class DriverProColors {
  static const background = Color(0xFF06101F);
  static const backgroundDeep = Color(0xFF030C19);
  static const panel = Color(0xFF0B1B30);
  static const panelRaised = Color(0xFF102743);
  static const border = Color(0xFF1B4B6C);
  static const cyan = Color(0xFF00D8FC);
  static const blue = Color(0xFF0078F4);
  static const green = Color(0xFF00E669);
  static const amber = Color(0xFFFFC107);
  static const red = Color(0xFFFF383E);
  static const muted = Color(0xFF9EB6CA);
}

class DriverProPanel extends StatelessWidget {
  const DriverProPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.highlight = false,
    this.borderColor,
    this.background,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool highlight;
  final Color? borderColor, background;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          background ?? DriverProColors.panelRaised,
          background ?? DriverProColors.panel,
        ],
      ),
      border: Border.all(
        color: borderColor ??
            (highlight ? DriverProColors.cyan : DriverProColors.border),
        width: highlight ? 1.3 : 0.85,
      ),
      borderRadius: BorderRadius.circular(17),
      boxShadow: [
        if (highlight)
          const BoxShadow(
            color: Color(0x2700CFFF), blurRadius: 18, spreadRadius: 0,
          ),
      ],
    ),
    child: child,
  );
}

class DriverProBrand extends StatelessWidget {
  const DriverProBrand({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'TTX Driver Pro',
    child: FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text.rich(TextSpan(children: [
        TextSpan(
          text: 'TTX ',
          style: TextStyle(
            color: Colors.white,
            fontSize: compact ? 18 : 21,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            letterSpacing: 0.5,
          ),
        ),
        TextSpan(
          text: 'DRIVER ',
          style: TextStyle(
            color: const Color(0xFFE9F7FF),
            fontSize: compact ? 14 : 16,
            fontWeight: FontWeight.w800,
            fontStyle: FontStyle.italic,
          ),
        ),
        TextSpan(
          text: 'PRO',
          style: TextStyle(
            color: DriverProColors.cyan,
            fontSize: compact ? 14 : 16,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
          ),
        ),
      ])),
    ),
  );
}

class DriverProStatusBanner extends StatelessWidget {
  const DriverProStatusBanner({
    super.key, required this.status,
    this.requiresManualResume = false,
  });

  final MeterStatus status;
  final bool requiresManualResume;

  @override
  Widget build(BuildContext context) {
    final bool finished = status == MeterStatus.finished;
    final bool running = status == MeterStatus.running &&
        !requiresManualResume;
    final bool paused = status == MeterStatus.paused ||
        requiresManualResume;
    final String label = requiresManualResume
        ? 'CHỜ TIẾP TỤC'
        : finished ? 'HOÀN THÀNH'
        : paused ? 'TẠM DỪNG'
        : running ? 'ĐANG CHẠY' : 'SẴN SÀNG';
    final Color color = finished || (!paused && !running)
        ? DriverProColors.green
        : paused ? DriverProColors.amber : DriverProColors.amber;
    final IconData symbol = finished ? Icons.check_circle_rounded
        : running ? Icons.local_taxi_rounded
        : paused ? Icons.pause_circle_filled_rounded : Icons.circle;

    return Semantics(
      label: 'Trạng thái chuyến: $label',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(symbol, size: 20, color: color),
          const SizedBox(width: 8),
          Flexible(
            child: Text(label,
              textAlign: TextAlign.center,
              softWrap: true,
              style: TextStyle(color: color,
                fontSize: 18, fontWeight: FontWeight.w900,
                letterSpacing: 0.8)),
          ),
        ],
      ),
    );
  }
}

class DriverProFareCard extends StatelessWidget {
  const DriverProFareCard({
    super.key,
    required this.amount,
    required this.status,
  });

  final String amount;
  final MeterStatus status;

  @override
  Widget build(BuildContext context) {
    final active = status == MeterStatus.running ||
        status == MeterStatus.paused;
    final color = status == MeterStatus.finished
        ? DriverProColors.green : DriverProColors.amber;
    final label = status == MeterStatus.finished
        ? 'Tổng tiền chuyến'
        : active ? 'Tiền cước tạm tính' : 'Tiền cước';
    return Container(
      key: const Key('driver-pro-fare-card'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 11),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            active ? const Color(0xFF422A08)
                : status == MeterStatus.finished
                    ? const Color(0xFF093C24)
                    : DriverProColors.panelRaised,
            DriverProColors.backgroundDeep,
          ],
        ),
        border: Border.all(
          color: active || status == MeterStatus.finished
              ? color : DriverProColors.border,
          width: 1.4,
        ),
        borderRadius: BorderRadius.circular(17),
        boxShadow: active || status == MeterStatus.finished
            ? [BoxShadow(
                color: color.withValues(alpha: 0.18),
                blurRadius: 15, spreadRadius: 1,
              )] : null,
      ),
      child: Column(children: [
        Text(label, style: const TextStyle(
          color: Color(0xFFE5EFF7), fontWeight: FontWeight.w700,
          fontSize: 13)),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            amount,
            key: const Key('live-fare-total'),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: active ? 41 : 37,
              height: 1.05,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ]),
    );
  }
}

class DriverProMetricCard extends StatelessWidget {
  const DriverProMetricCard({
    super.key, required this.label,
    required this.value, required this.icon,
    this.accent = DriverProColors.cyan,
  });
  final String label, value;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) => DriverProPanel(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 7),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: accent, size: 19),
      const SizedBox(height: 4),
      Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 11,
          color: DriverProColors.muted)),
      const SizedBox(height: 4),
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(value, maxLines: 1,
          style: const TextStyle(fontWeight: FontWeight.w800,
            fontSize: 16, color: Colors.white,
            fontFeatures: [FontFeature.tabularFigures()])),
      ),
    ]),
  );
}

/// Clear secondary action on the idle screen, directly below fare profile.
class DriverProQuoteCard extends StatelessWidget {
  const DriverProQuoteCard({super.key, required this.onPressed});

  /// Disabled until trip storage has finished loading.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onPressed != null,
    label: 'Báo giá chuyến đi, ước tính cước hoặc giá trọn gói',
    child: InkWell(
      key: const Key('driver-pro-quote-card'),
      onTap: onPressed,
      borderRadius: BorderRadius.circular(17),
      child: DriverProPanel(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 14),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF07364E),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.calculate_outlined,
              color: DriverProColors.cyan, size: 23),
          ),
          const SizedBox(width: 11),
          const Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Báo giá chuyến đi',
                style: TextStyle(
                  color: Colors.white, fontSize: 15,
                  fontWeight: FontWeight.w800)),
              SizedBox(height: 3),
              Text('Ước tính cước / giá trọn gói',
                style: TextStyle(
                  color: DriverProColors.muted, fontSize: 12)),
            ],
          )),
          const Icon(Icons.chevron_right_rounded,
            color: DriverProColors.cyan, size: 25),
        ]),
      ),
    ),
  );
}

class DriverProAction extends StatelessWidget {
  const DriverProAction({
    super.key, required this.label, required this.icon,
    required this.color, required this.onPressed,
    this.darkText = false,
  });
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;
  final bool darkText;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 55,
    child: FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: color,
        disabledBackgroundColor: DriverProColors.panelRaised,
        foregroundColor: darkText ? const Color(0xFF08111B) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(17)),
        elevation: 2,
        shadowColor: color.withValues(alpha: 0.45),
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 21),
      label: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(label, maxLines: 1,
          style: const TextStyle(
            fontWeight: FontWeight.w900, fontSize: 17)),
      ),
    ),
  );
}
