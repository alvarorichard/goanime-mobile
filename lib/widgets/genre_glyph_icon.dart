import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Innovative glyph tokens designed specially for GoAnime.
/// Each glyph is rendered procedurally through vector math so they feel
/// custom-made and brand-specific instead of relying on stock icon fonts.
enum GenreGlyph {
  season,
  top,
  action,
  adventure,
  comedy,
  drama,
  fantasy,
  horror,
  mystery,
  romance,
  sciFi,
  sliceOfLife,
  sports,
  supernatural,
}

class GenreGlyphIcon extends StatelessWidget {
  const GenreGlyphIcon({
    super.key,
    required this.glyph,
    this.size = 28,
    this.color = Colors.white,
    this.accent,
  });

  final GenreGlyph glyph;
  final double size;
  final Color color;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final accentColor = accent ?? Color.lerp(color, Colors.white, 0.35)!;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GenreGlyphPainter(
          glyph: glyph,
          color: color,
          accent: accentColor,
        ),
      ),
    );
  }
}

class _GenreGlyphPainter extends CustomPainter {
  const _GenreGlyphPainter({
    required this.glyph,
    required this.color,
    required this.accent,
  });

  final GenreGlyph glyph;
  final Color color;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final stroke = Paint()
      ..color = accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.08
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    switch (glyph) {
      case GenreGlyph.season:
        _paintSeason(canvas, size, fill, stroke);
        break;
      case GenreGlyph.top:
        _paintTop(canvas, size, fill, stroke);
        break;
      case GenreGlyph.action:
        _paintAction(canvas, size, fill, stroke);
        break;
      case GenreGlyph.adventure:
        _paintAdventure(canvas, size, fill, stroke);
        break;
      case GenreGlyph.comedy:
        _paintComedy(canvas, size, fill, stroke);
        break;
      case GenreGlyph.drama:
        _paintDrama(canvas, size, fill, stroke);
        break;
      case GenreGlyph.fantasy:
        _paintFantasy(canvas, size, fill, stroke);
        break;
      case GenreGlyph.horror:
        _paintHorror(canvas, size, fill, stroke);
        break;
      case GenreGlyph.mystery:
        _paintMystery(canvas, size, fill, stroke);
        break;
      case GenreGlyph.romance:
        _paintRomance(canvas, size, fill, stroke);
        break;
      case GenreGlyph.sciFi:
        _paintSciFi(canvas, size, fill, stroke);
        break;
      case GenreGlyph.sliceOfLife:
        _paintSliceOfLife(canvas, size, fill, stroke);
        break;
      case GenreGlyph.sports:
        _paintSports(canvas, size, fill, stroke);
        break;
      case GenreGlyph.supernatural:
        _paintSupernatural(canvas, size, fill, stroke);
        break;
    }
  }

  void _paintSeason(Canvas canvas, Size size, Paint fill, Paint stroke) {
    final center = Offset(size.width / 2, size.height / 2);
    final outer = Path()
      ..moveTo(center.dx, center.dy - size.height * 0.42)
      ..quadraticBezierTo(
        center.dx + size.width * 0.38,
        center.dy - size.height * 0.32,
        center.dx + size.width * 0.36,
        center.dy,
      )
      ..quadraticBezierTo(
        center.dx + size.width * 0.4,
        center.dy + size.height * 0.34,
        center.dx,
        center.dy + size.height * 0.44,
      )
      ..quadraticBezierTo(
        center.dx - size.width * 0.4,
        center.dy + size.height * 0.32,
        center.dx - size.width * 0.36,
        center.dy,
      )
      ..quadraticBezierTo(
        center.dx - size.width * 0.38,
        center.dy - size.height * 0.32,
        center.dx,
        center.dy - size.height * 0.42,
      )
      ..close();
    canvas.drawPath(outer, fill);

    final inner = Path()
      ..addOval(Rect.fromCircle(center: center, radius: size.width * 0.18));
    canvas.drawPath(
      inner,
      Paint()
        ..shader =
            RadialGradient(
              colors: [accent.withValues(alpha: 0.75), Colors.transparent],
            ).createShader(
              Rect.fromCircle(center: center, radius: size.width * 0.32),
            )
        ..isAntiAlias = true,
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: size.width * 0.36),
      math.pi * 0.1,
      math.pi * 1.8,
      false,
      stroke,
    );
  }

  void _paintTop(Canvas canvas, Size size, Paint fill, Paint stroke) {
    final base = Path()
      ..moveTo(size.width * 0.1, size.height * 0.7)
      ..lineTo(size.width * 0.25, size.height * 0.35)
      ..lineTo(size.width * 0.4, size.height * 0.65)
      ..lineTo(size.width * 0.5, size.height * 0.25)
      ..lineTo(size.width * 0.6, size.height * 0.65)
      ..lineTo(size.width * 0.75, size.height * 0.35)
      ..lineTo(size.width * 0.9, size.height * 0.7)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.92,
        size.width * 0.1,
        size.height * 0.7,
      )
      ..close();
    canvas.drawPath(base, fill);

    final rays = Path()
      ..moveTo(size.width * 0.2, size.height * 0.3)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.05,
        size.width * 0.8,
        size.height * 0.3,
      );
    canvas.drawPath(rays, stroke);

    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.28),
      size.width * 0.08,
      Paint()
        ..color = accent.withValues(alpha: 0.6)
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );
  }

  void _paintAction(Canvas canvas, Size size, Paint fill, Paint stroke) {
    final bolt = Path()
      ..moveTo(size.width * 0.18, size.height * 0.12)
      ..lineTo(size.width * 0.66, size.height * 0.04)
      ..lineTo(size.width * 0.45, size.height * 0.46)
      ..lineTo(size.width * 0.84, size.height * 0.36)
      ..lineTo(size.width * 0.32, size.height * 0.96)
      ..lineTo(size.width * 0.52, size.height * 0.52)
      ..lineTo(size.width * 0.16, size.height * 0.58)
      ..close();
    canvas.drawPath(bolt, fill);

    final pulse = Path()
      ..moveTo(size.width * 0.12, size.height * 0.28)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.05,
        size.width * 0.88,
        size.height * 0.34,
      );
    canvas.drawPath(pulse, stroke);

    canvas.drawCircle(
      Offset(size.width * 0.54, size.height * 0.48),
      size.width * 0.12,
      Paint()
        ..shader =
            RadialGradient(
              colors: [accent.withValues(alpha: 0.6), Colors.transparent],
            ).createShader(
              Rect.fromCircle(
                center: Offset(size.width * 0.54, size.height * 0.48),
                radius: size.width * 0.2,
              ),
            ),
    );
  }

  void _paintAdventure(Canvas canvas, Size size, Paint fill, Paint stroke) {
    final center = Offset(size.width / 2, size.height / 2);
    final polygon = Path();
    const points = 6;
    final radius = size.width * 0.42;
    for (int i = 0; i < points; i++) {
      final angle = (math.pi / 2) + (i * 2 * math.pi / points);
      final point = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      if (i == 0) {
        polygon.moveTo(point.dx, point.dy);
      } else {
        polygon.lineTo(point.dx, point.dy);
      }
    }
    polygon.close();
    canvas.drawPath(polygon, fill);

    final arrow = Path()
      ..moveTo(center.dx, center.dy - radius * 0.9)
      ..quadraticBezierTo(
        center.dx + radius * 0.6,
        center.dy,
        center.dx,
        center.dy + radius * 0.9,
      )
      ..quadraticBezierTo(
        center.dx - radius * 0.6,
        center.dy,
        center.dx,
        center.dy - radius * 0.9,
      );
    canvas.drawPath(arrow, stroke);

    final needle = Path()
      ..moveTo(center.dx, center.dy - radius * 0.9)
      ..lineTo(center.dx + radius * 0.12, center.dy - radius * 0.35)
      ..lineTo(center.dx, center.dy - radius * 0.5)
      ..lineTo(center.dx - radius * 0.12, center.dy - radius * 0.35)
      ..close();
    canvas.drawPath(
      needle,
      Paint()
        ..color = accent.withValues(alpha: 0.65)
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );
  }

  void _paintComedy(Canvas canvas, Size size, Paint fill, Paint stroke) {
    final mask = Path()
      ..moveTo(size.width * 0.14, size.height * 0.18)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.05,
        size.width * 0.86,
        size.height * 0.18,
      )
      ..quadraticBezierTo(
        size.width * 0.9,
        size.height * 0.62,
        size.width * 0.5,
        size.height * 0.86,
      )
      ..quadraticBezierTo(
        size.width * 0.1,
        size.height * 0.62,
        size.width * 0.14,
        size.height * 0.18,
      )
      ..close();
    canvas.drawPath(mask, fill);

    final smile = Path()
      ..moveTo(size.width * 0.28, size.height * 0.6)
      ..cubicTo(
        size.width * 0.38,
        size.height * 0.72,
        size.width * 0.62,
        size.height * 0.72,
        size.width * 0.72,
        size.height * 0.6,
      );
    canvas.drawPath(smile, stroke);

    final leftEye = Path()
      ..moveTo(size.width * 0.32, size.height * 0.4)
      ..quadraticBezierTo(
        size.width * 0.42,
        size.height * 0.34,
        size.width * 0.32,
        size.height * 0.32,
      );
    final rightEye = Path()
      ..moveTo(size.width * 0.68, size.height * 0.4)
      ..quadraticBezierTo(
        size.width * 0.58,
        size.height * 0.34,
        size.width * 0.68,
        size.height * 0.32,
      );
    canvas.drawPath(leftEye, stroke);
    canvas.drawPath(rightEye, stroke);

    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.27),
      size.width * 0.07,
      Paint()
        ..color = accent.withValues(alpha: 0.5)
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );
  }

  void _paintDrama(Canvas canvas, Size size, Paint fill, Paint stroke) {
    final drape = Path()
      ..moveTo(0, size.height * 0.22)
      ..quadraticBezierTo(
        size.width * 0.25,
        0,
        size.width * 0.5,
        size.height * 0.18,
      )
      ..quadraticBezierTo(size.width * 0.75, 0, size.width, size.height * 0.22)
      ..lineTo(size.width, size.height * 0.78)
      ..quadraticBezierTo(
        size.width * 0.75,
        size.height * 0.64,
        size.width * 0.5,
        size.height * 0.78,
      )
      ..quadraticBezierTo(
        size.width * 0.25,
        size.height * 0.64,
        0,
        size.height * 0.78,
      )
      ..close();
    canvas.drawPath(drape, fill);

    final folds = Path()
      ..moveTo(size.width * 0.2, size.height * 0.2)
      ..quadraticBezierTo(
        size.width * 0.3,
        size.height * 0.45,
        size.width * 0.2,
        size.height * 0.7,
      )
      ..moveTo(size.width * 0.5, size.height * 0.18)
      ..quadraticBezierTo(
        size.width * 0.6,
        size.height * 0.45,
        size.width * 0.5,
        size.height * 0.72,
      )
      ..moveTo(size.width * 0.8, size.height * 0.2)
      ..quadraticBezierTo(
        size.width * 0.7,
        size.height * 0.45,
        size.width * 0.8,
        size.height * 0.7,
      );
    canvas.drawPath(folds, stroke);
  }

  void _paintFantasy(Canvas canvas, Size size, Paint fill, Paint stroke) {
    final crystal = Path()
      ..moveTo(size.width * 0.5, size.height * 0.04)
      ..lineTo(size.width * 0.76, size.height * 0.28)
      ..lineTo(size.width * 0.62, size.height * 0.92)
      ..lineTo(size.width * 0.38, size.height * 0.92)
      ..lineTo(size.width * 0.24, size.height * 0.28)
      ..close();
    canvas.drawPath(crystal, fill);

    final facets = Path()
      ..moveTo(size.width * 0.5, size.height * 0.04)
      ..lineTo(size.width * 0.5, size.height * 0.92)
      ..moveTo(size.width * 0.38, size.height * 0.92)
      ..lineTo(size.width * 0.62, size.height * 0.28)
      ..moveTo(size.width * 0.62, size.height * 0.92)
      ..lineTo(size.width * 0.38, size.height * 0.28);
    canvas.drawPath(facets, stroke);

    final orbit = Path()
      ..addOval(
        Rect.fromCircle(
          center: Offset(size.width * 0.5, size.height * 0.52),
          radius: size.width * 0.42,
        ),
      );
    canvas.drawPath(
      orbit,
      Paint()
        ..color = accent.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.05
        ..isAntiAlias = true,
    );
  }

  void _paintHorror(Canvas canvas, Size size, Paint fill, Paint stroke) {
    final slashPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = size.width * 0.14
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.6)
      ..isAntiAlias = true;

    for (int i = 0; i < 3; i++) {
      final shift = i * size.width * 0.18;
      canvas.drawLine(
        Offset(size.width * 0.18 + shift, size.height * 0.12),
        Offset(size.width * 0.08 + shift, size.height * 0.88),
        slashPaint,
      );
    }

    final drip = Path()
      ..moveTo(size.width * 0.7, size.height * 0.32)
      ..quadraticBezierTo(
        size.width * 0.9,
        size.height * 0.52,
        size.width * 0.72,
        size.height * 0.82,
      )
      ..quadraticBezierTo(
        size.width * 0.6,
        size.height * 0.65,
        size.width * 0.58,
        size.height * 0.48,
      )
      ..close();
    canvas.drawPath(
      drip,
      Paint()
        ..color = accent.withValues(alpha: 0.45)
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );
  }

  void _paintMystery(Canvas canvas, Size size, Paint fill, Paint stroke) {
    final spiral = Path();
    final center = Offset(size.width / 2, size.height / 2);
    final turns = 2.5;
    final maxRadius = size.width * 0.4;
    const steps = 80;
    for (int i = 0; i <= steps; i++) {
      final t = i / steps;
      final angle = turns * 2 * math.pi * t;
      final radius = maxRadius * t;
      final point = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      if (i == 0) {
        spiral.moveTo(point.dx, point.dy);
      } else {
        spiral.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(spiral, stroke);

    canvas.drawCircle(
      Offset(center.dx + maxRadius * 0.65, center.dy - maxRadius * 0.3),
      size.width * 0.08,
      fill,
    );

    final trail = Path()
      ..moveTo(center.dx + maxRadius * 0.1, center.dy + maxRadius * 0.65)
      ..quadraticBezierTo(
        center.dx,
        size.height,
        center.dx - maxRadius * 0.4,
        size.height,
      );
    canvas.drawPath(trail, stroke);
  }

  void _paintRomance(Canvas canvas, Size size, Paint fill, Paint stroke) {
    final heart = Path()
      ..moveTo(size.width * 0.5, size.height * 0.24)
      ..cubicTo(
        size.width * 0.9,
        size.height * 0.0,
        size.width * 1.0,
        size.height * 0.5,
        size.width * 0.5,
        size.height * 0.86,
      )
      ..cubicTo(
        size.width * 0.0,
        size.height * 0.5,
        size.width * 0.1,
        size.height * 0.0,
        size.width * 0.5,
        size.height * 0.24,
      )
      ..close();
    canvas.drawPath(heart, fill);

    final pulse = Path()
      ..moveTo(size.width * 0.18, size.height * 0.46)
      ..quadraticBezierTo(
        size.width * 0.38,
        size.height * 0.62,
        size.width * 0.5,
        size.height * 0.46,
      )
      ..quadraticBezierTo(
        size.width * 0.62,
        size.height * 0.3,
        size.width * 0.82,
        size.height * 0.46,
      );
    canvas.drawPath(pulse, stroke);

    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.46),
      size.width * 0.09,
      Paint()
        ..color = accent.withValues(alpha: 0.55)
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );
  }

  void _paintSciFi(Canvas canvas, Size size, Paint fill, Paint stroke) {
    final nucleus = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(nucleus, size.width * 0.18, fill);

    for (int i = 0; i < 3; i++) {
      final rotation = i * (math.pi / 3.0);
      canvas.save();
      canvas.translate(nucleus.dx, nucleus.dy);
      canvas.rotate(rotation);
      final orbit = Path()
        ..addOval(
          Rect.fromCircle(center: Offset.zero, radius: size.width * 0.46),
        );
      canvas.drawPath(orbit, stroke);
      canvas.restore();
    }

    canvas.drawCircle(
      Offset(nucleus.dx + size.width * 0.38, nucleus.dy - size.height * 0.22),
      size.width * 0.07,
      Paint()
        ..color = accent.withValues(alpha: 0.5)
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );
  }

  void _paintSliceOfLife(Canvas canvas, Size size, Paint fill, Paint stroke) {
    final base = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.1,
        size.height * 0.18,
        size.width * 0.8,
        size.height * 0.6,
      ),
      Radius.circular(size.width * 0.18),
    );
    canvas.drawRRect(base, fill);

    final layers = Path()
      ..moveTo(size.width * 0.2, size.height * 0.4)
      ..quadraticBezierTo(
        size.width * 0.4,
        size.height * 0.32,
        size.width * 0.65,
        size.height * 0.4,
      )
      ..quadraticBezierTo(
        size.width * 0.78,
        size.height * 0.45,
        size.width * 0.8,
        size.height * 0.6,
      )
      ..moveTo(size.width * 0.2, size.height * 0.52)
      ..quadraticBezierTo(
        size.width * 0.45,
        size.height * 0.6,
        size.width * 0.75,
        size.height * 0.52,
      )
      ..moveTo(size.width * 0.32, size.height * 0.7)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.82,
        size.width * 0.68,
        size.height * 0.7,
      );
    canvas.drawPath(layers, stroke);
  }

  void _paintSports(Canvas canvas, Size size, Paint fill, Paint stroke) {
    canvas.drawOval(
      Rect.fromLTWH(
        size.width * 0.12,
        size.height * 0.14,
        size.width * 0.76,
        size.height * 0.72,
      ),
      fill,
    );

    final seams = Path()
      ..moveTo(size.width * 0.18, size.height * 0.32)
      ..cubicTo(
        size.width * 0.38,
        size.height * 0.14,
        size.width * 0.62,
        size.height * 0.14,
        size.width * 0.82,
        size.height * 0.32,
      )
      ..moveTo(size.width * 0.18, size.height * 0.68)
      ..cubicTo(
        size.width * 0.38,
        size.height * 0.86,
        size.width * 0.62,
        size.height * 0.86,
        size.width * 0.82,
        size.height * 0.68,
      );
    canvas.drawPath(seams, stroke);

    canvas.drawCircle(
      Offset(size.width * 0.32, size.height * 0.5),
      size.width * 0.07,
      Paint()
        ..color = accent.withValues(alpha: 0.5)
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );
    canvas.drawCircle(
      Offset(size.width * 0.68, size.height * 0.5),
      size.width * 0.07,
      Paint()
        ..color = accent.withValues(alpha: 0.35)
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );
  }

  void _paintSupernatural(Canvas canvas, Size size, Paint fill, Paint stroke) {
    final center = Offset(size.width / 2, size.height * 0.4);
    canvas.drawCircle(center, size.width * 0.22, fill);

    final aura = Path()
      ..addOval(
        Rect.fromCircle(
          center: center.translate(0, size.height * 0.18),
          radius: size.width * 0.46,
        ),
      );
    canvas.drawPath(aura, stroke);

    final runes = Path()
      ..moveTo(center.dx - size.width * 0.3, center.dy + size.height * 0.18)
      ..lineTo(center.dx - size.width * 0.18, center.dy + size.height * 0.05)
      ..moveTo(center.dx + size.width * 0.3, center.dy + size.height * 0.18)
      ..lineTo(center.dx + size.width * 0.18, center.dy + size.height * 0.05)
      ..moveTo(center.dx, center.dy + size.height * 0.32)
      ..lineTo(center.dx, center.dy + size.height * 0.08);
    canvas.drawPath(runes, stroke);

    canvas.drawCircle(
      center.translate(0, size.height * 0.34),
      size.width * 0.09,
      Paint()
        ..color = accent.withValues(alpha: 0.4)
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(covariant _GenreGlyphPainter oldDelegate) {
    return oldDelegate.glyph != glyph ||
        oldDelegate.color != color ||
        oldDelegate.accent != accent;
  }
}
