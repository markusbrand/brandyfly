import 'package:flutter/material.dart';

import '../../services/airspace_service.dart';

/// Top HUD warning banner displaying real-time airspace proximity alerts,
/// airspace details, and horizontal/vertical clearance metrics.
class AirspaceWarningBannerHUD extends StatefulWidget {
  const AirspaceWarningBannerHUD({
    super.key,
    required this.proximity,
    this.onDismiss,
  });

  final AirspaceProximityState proximity;
  final VoidCallback? onDismiss;

  @override
  State<AirspaceWarningBannerHUD> createState() =>
      _AirspaceWarningBannerHUDState();
}

class _AirspaceWarningBannerHUDState extends State<AirspaceWarningBannerHUD>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _pulseAnimation;
  bool _isDismissedForSession = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
    if (widget.proximity.alertLevel == AirspaceAlertLevel.violation) {
      _animController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant AirspaceWarningBannerHUD oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.proximity.alertLevel != widget.proximity.alertLevel) {
      // Re-surface banner on escalation
      if (widget.proximity.alertLevel.severity >
          oldWidget.proximity.alertLevel.severity) {
        _isDismissedForSession = false;
      }
      if (widget.proximity.alertLevel == AirspaceAlertLevel.violation) {
        if (!_animController.isAnimating) {
          _animController.repeat(reverse: true);
        }
      } else {
        _animController.stop();
        _animController.reset();
      }
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prox = widget.proximity;
    if (prox.alertLevel == AirspaceAlertLevel.clear || _isDismissedForSession) {
      return const SizedBox.shrink();
    }

    final isViolation = prox.alertLevel == AirspaceAlertLevel.violation;
    final isWarning = prox.alertLevel == AirspaceAlertLevel.warning;

    final bannerColor = isViolation
        ? const Color(0xFFDC2626) // Vivid red
        : isWarning
            ? const Color(0xFFEA580C) // Warning orange
            : const Color(0xFFD97706); // Advisory amber

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final scale = isViolation ? _pulseAnimation.value : 1.0;
        return Transform.scale(
          scale: scale,
          child: child,
        );
      },
      child: Material(
        elevation: 8.0,
        borderRadius: BorderRadius.circular(8.0),
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: bannerColor.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(
              color: isViolation ? Colors.white : Colors.white24,
              width: isViolation ? 2.0 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: bannerColor.withValues(alpha: 0.4),
                blurRadius: 12.0,
                spreadRadius: 1.0,
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: Row(
            children: [
              Icon(
                isViolation
                    ? Icons.dangerous
                    : isWarning
                        ? Icons.warning_amber
                        : Icons.info_outline,
                color: Colors.white,
                size: 26,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          prox.alertLevel.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                          ),
                        ),
                        if (prox.airspaceClass.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              prox.airspaceClass,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      prox.airspaceName.isEmpty
                          ? 'Controlled Airspace'
                          : prox.airspaceName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatClearance(prox),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                tooltip: 'Dismiss Airspace Alert',
                onPressed: () {
                  setState(() {
                    _isDismissedForSession = true;
                  });
                  widget.onDismiss?.call();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatClearance(AirspaceProximityState prox) {
    if (prox.alertLevel == AirspaceAlertLevel.violation) {
      return 'INSIDE AIRSPACE BOUNDS';
    }

    final hStr = prox.isInsideHorizontal
        ? 'Inside'
        : '${prox.horizontalSeparationM.toStringAsFixed(0)}m';
    final vStr = prox.isInsideVertical
        ? 'Inside'
        : '${prox.verticalSeparationM.toStringAsFixed(0)}m';

    return 'H: $hStr | V: $vStr | 3D: ${prox.total3dDistanceM.toStringAsFixed(0)}m';
  }
}
