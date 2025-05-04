import 'package:flutter/material.dart';
import 'dart:math' as math;

class TrafficChart extends StatelessWidget {
  final List<int> dataPoints;
  final Color color;
  final double height;
  final bool isDark;
  final String label;
  final String currentValue;

  const TrafficChart({
    Key? key,
    required this.dataPoints,
    required this.color,
    this.height = 60,
    required this.isDark,
    required this.label,
    required this.currentValue,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? Colors.black12 : Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey[400] : Colors.grey[700],
                ),
              ),
              Text(
                currentValue,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: CustomPaint(
              size: Size.infinite,
              painter: _ChartPainter(
                dataPoints: dataPoints,
                color: color,
                isDark: isDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  final List<int> dataPoints;
  final Color color;
  final bool isDark;

  _ChartPainter({
    required this.dataPoints,
    required this.color,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (dataPoints.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = color.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    final maxValue = dataPoints.reduce(math.max).toDouble();
    final minValue = 0.0; // یا می‌توانید از dataPoints.reduce(math.min) استفاده کنید

    final xStep = size.width / (dataPoints.length - 1);
    final yScale = maxValue > minValue ? size.height / (maxValue - minValue) : 0.0;

    final path = Path();
    final fillPath = Path();

    // شروع مسیر از نقطه اول
    final firstPoint = Offset(
      0,
      size.height - ((dataPoints[0] - minValue) * yScale),
    );
    path.moveTo(firstPoint.dx, firstPoint.dy);
    fillPath.moveTo(0, size.height);
    fillPath.lineTo(firstPoint.dx, firstPoint.dy);

    // رسم خط برای هر نقطه داده
    for (int i = 1; i < dataPoints.length; i++) {
      final x = xStep * i;
      final y = size.height - ((dataPoints[i] - minValue) * yScale);
      
      // اضافه کردن نقطه به مسیر
      path.lineTo(x, y);
      fillPath.lineTo(x, y);
    }

    // تکمیل مسیر پر شده
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    // رسم مسیر پر شده و خط
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    // رسم نقاط روی نمودار
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (int i = 0; i < dataPoints.length; i++) {
      final x = xStep * i;
      final y = size.height - ((dataPoints[i] - minValue) * yScale);
      canvas.drawCircle(Offset(x, y), 2.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ChartPainter oldDelegate) {
    return oldDelegate.dataPoints != dataPoints || 
           oldDelegate.color != color ||
           oldDelegate.isDark != isDark;
  }
}