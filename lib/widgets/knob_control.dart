import 'dart:math';
import 'package:flutter/material.dart';
import 'package:metronomo_standalone/constants/app_colors.dart';

class KnobControl extends StatefulWidget {
  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd; 
  final double min;
  final double max;
  final String label;
  final Color? labelColor;
  final VoidCallback? onTap;
  final bool zeroAtCenter; // true for Pan (0 is top), false for Volume (0 is 7:30)
  final double size; // Native layout size

  const KnobControl({
    super.key,
    required this.value,
    required this.onChanged,
    this.onChangeEnd,
    this.min = -1.0,
    this.max = 1.0,
    this.label = "PAN",
    this.labelColor,
    this.onTap,
    this.zeroAtCenter = true, 
    this.size = 40.0,
  });

  @override
  State<KnobControl> createState() => _KnobControlState();
}

class _KnobControlState extends State<KnobControl> {
  static const double _maxAngle = 2.35; // ~135 degrees from center
  
  // Local drag state — decouples visual from TrackModel rebuild cascade
  double? _dragValue;
  bool _isDragging = false;

  double get _effectiveValue => _isDragging ? (_dragValue ?? widget.value) : widget.value;

  void _handlePanUpdate(DragUpdateDetails details) {
    // Increased sensitivity (x3) for better Desktop/Windows UX
    double sensitivity = 0.015 * (widget.max - widget.min); 
    if (sensitivity == 0) sensitivity = 0.01;
    
    double delta = (details.delta.dx - details.delta.dy) * sensitivity;
    double currentVal = _isDragging ? (_dragValue ?? widget.value) : widget.value;
    double newValue = (currentVal + delta).clamp(widget.min, widget.max);
    
    _dragValue = newValue;
    _isDragging = true;
    setState(() {}); // Instant local visual update
    widget.onChanged(newValue); // Update audio engine
  }

  void _handlePanEnd(DragEndDetails details) {
    final finalVal = _dragValue ?? widget.value;
    _isDragging = false;
    _dragValue = null;
    if (widget.onChangeEnd != null) {
      widget.onChangeEnd!(finalVal);
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveVal = _effectiveValue;
    double range = widget.max - widget.min;
    double angle = 0.0;
    
    if (range > 0) {
      if (widget.zeroAtCenter) {
        double normalized = (effectiveVal - widget.min) / range;
        normalized = (normalized * 2) - 1;
        angle = normalized * _maxAngle;
      } else {
        double normalized = (effectiveVal - widget.min) / range;
        angle = -_maxAngle + (normalized * (_maxAngle * 2));
      }
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: _handlePanUpdate,
      onPanEnd: _handlePanEnd,
      onDoubleTap: () {
        double resetValue = widget.zeroAtCenter ? (widget.min + widget.max) / 2 : widget.min;
        widget.onChanged(resetValue);
        if (widget.onChangeEnd != null) widget.onChangeEnd!(resetValue);
      },
      onTap: () {
        if (widget.onTap != null) {
          widget.onTap!();
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomPaint(
            size: Size(widget.size, widget.size), 
            painter: KnobPainter(
              angle: angle, 
              color: widget.labelColor ?? AppColors.accentCyan(context),
              isCenterZero: widget.zeroAtCenter,
              surfaceHighlightColor: AppColors.surfaceHighlight(context),
              borderColor: AppColors.border(context),
              textSecondaryColor: AppColors.textSecondary(context),
            ),
          ),
          SizedBox(height: widget.size * 0.15),
          Text(
            widget.label, 
            style: TextStyle(
              fontSize: 10, 
              fontWeight: FontWeight.w700, 
              fontFamily: 'monospace',
              letterSpacing: 0.5,
              color: widget.labelColor ?? AppColors.textSecondary(context),
            )
          ),
        ],
      ),
    );
  }
}

class KnobPainter extends CustomPainter {
  final double angle;
  final Color color;
  final bool isCenterZero;
  final Color surfaceHighlightColor;
  final Color borderColor;
  final Color textSecondaryColor;

  KnobPainter({
     required this.angle,
     required this.color,
     required this.isCenterZero,
     required this.surfaceHighlightColor,
     required this.borderColor,
     required this.textSecondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;

    // 1. Simple Dark Base (Less Star Wars)
    final paintBase = Paint()
      ..color = surfaceHighlightColor.withOpacity(0.8)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, paintBase);

    // 2. Subtle Border
    final paintBorder = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius, paintBorder);
    
    // 3. Optional Center Dot for Center-Zero knobs
    if (isCenterZero) {
        final paintDot = Paint()..color = textSecondaryColor.withOpacity(0.3);
        canvas.drawCircle(center.translate(0, -radius + 4), 1.5, paintDot);
    }
    
    // 4. Indicator Line
    // The marker is drawn pointing UP (0, -y).
    // So if angle is 0, we want it to stay pointing UP (12 o'clock).
    double drawAngle = angle;
    
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(drawAngle);
    
    // Solid, simple line
    final markerStart = Offset(0, -radius * 0.3);
    final markerEnd = Offset(0, -radius + 2);
    
    final paintIndicator = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(markerStart, markerEnd, paintIndicator);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant KnobPainter oldDelegate) {
    return oldDelegate.angle != angle || oldDelegate.color != color || oldDelegate.isCenterZero != isCenterZero;
  }
}
