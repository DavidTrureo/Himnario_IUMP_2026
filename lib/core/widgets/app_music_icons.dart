import 'package:flutter/material.dart';

/// Icono de Diapasón Acústico Real (Tuning Fork)
/// Diseñado con las proporciones exactas de un diapasón de acero real:
/// horquillas cilíndricas largas y delgadas, curva en U estrecha, mango estilizado y bola base.
class TuningForkIcon extends StatelessWidget {
  final double size;
  final Color color;
  final bool showSoundwaves;

  const TuningForkIcon({
    super.key,
    this.size = 22,
    required this.color,
    this.showSoundwaves = false,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _TuningForkPainter(
        color: color,
        showSoundwaves: showSoundwaves,
      ),
    );
  }
}

class _TuningForkPainter extends CustomPainter {
  final Color color;
  final bool showSoundwaves;

  _TuningForkPainter({
    required this.color,
    required this.showSoundwaves,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Grosor delgado y fino de acero inoxidable real
    final strokeWidth = w * 0.065;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // 1. Mango vertical inferior estilizado (Handle stem)
    canvas.drawLine(
      Offset(w * 0.50, h * 0.61),
      Offset(w * 0.50, h * 0.83),
      paint..strokeWidth = strokeWidth * 1.15,
    );

    // 2. Esfera/Bola metálica base del mango (Base Knob)
    canvas.drawCircle(
      Offset(w * 0.50, h * 0.88),
      w * 0.075,
      fillPaint,
    );

    // 3. Brazos/Horquillas cilíndricas muy largas, esbeltas y estrictamente paralelas
    final path = Path();
    // Brazo izquierdo (largo y delgado)
    path.moveTo(w * 0.38, h * 0.06);
    path.lineTo(w * 0.38, h * 0.52);
    // Curva en U semicircular estrecha en la unión
    path.quadraticBezierTo(
      w * 0.50, h * 0.64,
      w * 0.62, h * 0.52,
    );
    // Brazo derecho (largo y delgado)
    path.lineTo(w * 0.62, h * 0.06);
    canvas.drawPath(path, paint..strokeWidth = strokeWidth);

    // 4. Extremos planos/redondeados metálicos superiores en las puntas de los brazos
    canvas.drawCircle(Offset(w * 0.38, h * 0.06), strokeWidth * 0.45, fillPaint);
    canvas.drawCircle(Offset(w * 0.62, h * 0.06), strokeWidth * 0.45, fillPaint);

    // 5. Ondas acústicas sutiles alrededor si showSoundwaves es verdadero
    if (showSoundwaves) {
      final wavePaint = Paint()
        ..color = color.withValues(alpha: 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth * 0.65
        ..strokeCap = StrokeCap.round;

      // Onda izquierda
      final waveLeft = Path();
      waveLeft.addArc(
        Rect.fromCircle(center: Offset(w * 0.18, h * 0.22), radius: w * 0.11),
        -1.0, 2.0,
      );
      canvas.drawPath(waveLeft, wavePaint);

      // Onda derecha
      final waveRight = Path();
      waveRight.addArc(
        Rect.fromCircle(center: Offset(w * 0.82, h * 0.22), radius: w * 0.11),
        2.14, 2.0,
      );
      canvas.drawPath(waveRight, wavePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TuningForkPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.showSoundwaves != showSoundwaves;
  }
}

/// Icono del Metrónomo Mecánico de Madera Real
/// Basado en la estructura física real: gabinete piramidal de madera, base frontal,
/// cavidad oscura con escala de latón y péndulo metálico inclinado con pesa trapezoidal.
class TraditionalMetronomeIcon extends StatelessWidget {
  final double size;
  final Color color;

  const TraditionalMetronomeIcon({
    super.key,
    this.size = 22,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _MetronomePainter(color: color),
    );
  }
}

class _MetronomePainter extends CustomPainter {
  final Color color;
  _MetronomePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final strokeWidth = w * 0.07;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // 1. Cuerpo piramidal de madera (Torre superior e interior)
    final pyramidPath = Path();
    pyramidPath.moveTo(w * 0.44, h * 0.08);
    pyramidPath.lineTo(w * 0.56, h * 0.08);
    pyramidPath.lineTo(w * 0.82, h * 0.84);
    pyramidPath.lineTo(w * 0.18, h * 0.84);
    pyramidPath.close();
    canvas.drawPath(pyramidPath, paint);

    // 2. Gabinete/Base frontal de madera (Panel inferior sólido como en la foto)
    final frontBase = Path();
    frontBase.moveTo(w * 0.23, h * 0.58);
    frontBase.lineTo(w * 0.77, h * 0.58);
    frontBase.lineTo(w * 0.84, h * 0.85);
    frontBase.lineTo(w * 0.16, h * 0.85);
    frontBase.close();
    canvas.drawPath(
      frontBase,
      Paint()
        ..color = color.withValues(alpha: 0.22)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(frontBase, paint);

    // 3. Escala central graduada de latón / tempo
    canvas.drawLine(
      Offset(w * 0.50, h * 0.14),
      Offset(w * 0.50, h * 0.57),
      Paint()
        ..color = color.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth * 0.65,
    );

    // 4. Varilla metálica del péndulo inclinada hacia la izquierda (como en la foto real)
    canvas.drawLine(
      Offset(w * 0.48, h * 0.70),
      Offset(w * 0.24, h * 0.14),
      paint..strokeWidth = strokeWidth * 0.9,
    );

    // 5. Pesa invertida trapezoidal deslizante montada en la varilla (como en la foto real)
    final weightPath = Path();
    weightPath.moveTo(w * 0.24, h * 0.28);
    weightPath.lineTo(w * 0.36, h * 0.24);
    weightPath.lineTo(w * 0.38, h * 0.36);
    weightPath.lineTo(w * 0.26, h * 0.40);
    weightPath.close();
    canvas.drawPath(weightPath, fillPaint);

    // 6. Patas esféricas de madera en la base (como en la foto real)
    canvas.drawCircle(Offset(w * 0.22, h * 0.90), w * 0.04, fillPaint);
    canvas.drawCircle(Offset(w * 0.78, h * 0.90), w * 0.04, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _MetronomePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
