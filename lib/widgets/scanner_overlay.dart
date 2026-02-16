import 'package:flutter/material.dart';

class ScannerOverlay extends StatelessWidget {
  const ScannerOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ScannerOverlayPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final overlayPaint = Paint()..color = Colors.black.withValues(alpha: 0.5);

    // Define the viewfinder rectangle (top-center, where card name appears)
    final viewfinderWidth = size.width * 0.85;
    final viewfinderHeight = size.height * 0.08;
    final viewfinderLeft = (size.width - viewfinderWidth) / 2;
    final viewfinderTop = size.height * 0.15;

    final viewfinder = Rect.fromLTWH(
      viewfinderLeft,
      viewfinderTop,
      viewfinderWidth,
      viewfinderHeight,
    );

    // Draw semi-transparent overlay with a cutout for the viewfinder
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(fullRect),
        Path()..addRRect(RRect.fromRectAndRadius(viewfinder, const Radius.circular(8))),
      ),
      overlayPaint,
    );

    // Draw viewfinder border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(viewfinder, const Radius.circular(8)),
      borderPaint,
    );

    // Draw instruction text below viewfinder
    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'Point at the card name',
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (size.width - textPainter.width) / 2,
        viewfinder.bottom + 16,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
