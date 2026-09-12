import 'package:flutter/material.dart';

/// The mark drawn on a platform tile.
///
/// These are drawn rather than taken from an icon font so the set reads as one
/// family: the same stroke weight, the same corner radius, the same optical
/// size. They are deliberately not copies of the platforms' own logos, which
/// belong to those companies; each one says what kind of place the platform is
/// and lets the brand colour behind it do the recognising.
enum PlatformGlyph {
  /// Sound bars. Short video set to music.
  equaliser,

  /// A play mark inside a square frame. A reel.
  reel,

  /// A single figure. A profile, a social feed.
  person,

  /// A card with lines of text. A post.
  post,

  /// A play mark inside a circle.
  playCircle,

  /// A strip of film.
  film,

  /// A grid of dots. Everything else.
  grid,
}

/// Draws a [PlatformGlyph] at [size], in [color].
class PlatformGlyphIcon extends StatelessWidget {
  final PlatformGlyph glyph;
  final double size;
  final Color color;

  const PlatformGlyphIcon({
    super.key,
    required this.glyph,
    this.size = 28,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GlyphPainter(glyph: glyph, color: color),
      ),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  final PlatformGlyph glyph;
  final Color color;

  _GlyphPainter({required this.glyph, required this.color});

  /// Everything is drawn on a 24 by 24 grid and scaled to fit, so the shapes
  /// keep their proportions at any tile size.
  static const double _grid = 24;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / _grid;

    canvas.save();
    canvas.scale(scale);

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    switch (glyph) {
      case PlatformGlyph.equaliser:
        _equaliser(canvas, stroke);
      case PlatformGlyph.reel:
        _reel(canvas, stroke, fill);
      case PlatformGlyph.person:
        _person(canvas, stroke);
      case PlatformGlyph.post:
        _post(canvas, stroke);
      case PlatformGlyph.playCircle:
        _playCircle(canvas, stroke, fill);
      case PlatformGlyph.film:
        _film(canvas, stroke, fill);
      case PlatformGlyph.grid:
        _grid3x3(canvas, fill);
    }

    canvas.restore();
  }

  /// Four bars rising from a common baseline, tallest off centre.
  void _equaliser(Canvas canvas, Paint stroke) {
    const base = 18.5;
    const xs = [6.0, 10.0, 14.0, 18.0];
    const heights = [6.0, 12.0, 8.5, 4.0];

    final bar = Paint()
      ..color = stroke.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < xs.length; i++) {
      canvas.drawLine(
        Offset(xs[i], base),
        Offset(xs[i], base - heights[i]),
        bar,
      );
    }
  }

  /// A rounded frame with a play mark in the middle.
  void _reel(Canvas canvas, Paint stroke, Paint fill) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(4, 4, 16, 16),
        const Radius.circular(5),
      ),
      stroke,
    );

    canvas.drawPath(
      Path()
        ..moveTo(10.4, 9)
        ..lineTo(15.4, 12)
        ..lineTo(10.4, 15)
        ..close(),
      fill,
    );
  }

  /// A single figure: head and shoulders.
  ///
  /// Two overlapping figures were tried first and turned to mush at tile size,
  /// which is the size that matters.
  void _person(Canvas canvas, Paint stroke) {
    canvas.drawCircle(const Offset(12, 8.8), 3.6, stroke);

    canvas.drawPath(
      Path()
        ..moveTo(5.2, 19)
        ..arcToPoint(
          const Offset(18.8, 19),
          radius: const Radius.circular(7.4),
          clockwise: true,
        ),
      stroke,
    );
  }

  /// A card holding three lines of text.
  void _post(Canvas canvas, Paint stroke) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(3.5, 5, 17, 14),
        const Radius.circular(4),
      ),
      stroke,
    );

    final line = Paint()
      ..color = stroke.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.9
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(const Offset(7, 9.8), const Offset(17, 9.8), line);
    canvas.drawLine(const Offset(7, 12.6), const Offset(17, 12.6), line);
    canvas.drawLine(const Offset(7, 15.4), const Offset(12.5, 15.4), line);
  }

  /// A play mark inside a ring.
  void _playCircle(Canvas canvas, Paint stroke, Paint fill) {
    canvas.drawCircle(const Offset(12, 12), 8, stroke);

    canvas.drawPath(
      Path()
        ..moveTo(10.2, 8.4)
        ..lineTo(16, 12)
        ..lineTo(10.2, 15.6)
        ..close(),
      fill,
    );
  }

  /// A strip of film, sprocket holes down both edges.
  void _film(Canvas canvas, Paint stroke, Paint fill) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(3, 5, 18, 14),
        const Radius.circular(3.5),
      ),
      stroke,
    );

    for (final y in [8.2, 12.0, 15.8]) {
      for (final x in [5.8, 18.2]) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(x, y), width: 2.2, height: 2.2),
            const Radius.circular(0.7),
          ),
          fill,
        );
      }
    }
  }

  /// Nine dots.
  void _grid3x3(Canvas canvas, Paint fill) {
    for (final y in [7.0, 12.0, 17.0]) {
      for (final x in [7.0, 12.0, 17.0]) {
        canvas.drawCircle(Offset(x, y), 1.5, fill);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GlyphPainter old) =>
      old.glyph != glyph || old.color != color;
}
