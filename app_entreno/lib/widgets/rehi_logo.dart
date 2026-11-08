import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../store.dart';
import '../theme.dart';

/// Logo REHI (barra olímpica sobre el nombre) dibujado en código,
/// para que tome los colores de la paleta elegida.
class RehiLogo extends StatelessWidget {
  const RehiLogo({super.key, this.size = 40, this.palette});

  final double size;

  /// Paleta a usar; si es null, la paleta actual de la app.
  final AppPalette? palette;

  @override
  Widget build(BuildContext context) {
    // Escucha el color elegido para redibujarse en cuanto cambia, aunque el logo
    // se haya creado como `const` (antes solo cambiaba al reabrir la pantalla).
    final p = palette ??
        paletteById(context.select<AppStore, String>((s) => s.paletteId));
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: RehiLogoPainter(p)),
    );
  }
}

@visibleForTesting
class RehiLogoPainter extends CustomPainter {
  RehiLogoPainter(this.palette);

  final AppPalette palette;

  AppPalette get p => palette;

  @override
  void paint(Canvas canvas, Size size) {
    // Geometría en un lienzo de 200×200 (igual que assets/branding/rehi_logo.svg).
    canvas.scale(size.width / 200);
    final bg = Paint()..color = p.background;
    final white = Paint()..color = Colors.white;
    final accent = Paint()..color = p.accent;

    void rect(double x, double y, double w, double h, double r, Paint paint) =>
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r)),
          paint,
        );

    rect(0, 0, 200, 200, 44, bg);

    // Barra con discos.
    rect(50, 71, 100, 6, 3, accent);
    rect(42, 57, 11, 34, 3, white);
    rect(56, 63, 7, 22, 2, white);
    rect(137, 63, 7, 22, 2, white);
    rect(147, 57, 11, 34, 3, white);

    const t = 6.0, top = 112.0, cap = 30.0;

    // R (con el hueco recortado).
    const x = 51.0;
    final r = Path()
      ..addRect(const Rect.fromLTWH(x, top, t, cap))
      ..addRect(const Rect.fromLTWH(x, top, 16, 18))
      ..addRRect(RRect.fromRectAndRadius(
          const Rect.fromLTWH(x, top, 25, 18), const Radius.circular(9)))
      ..addPolygon(const [
        Offset(x + 10, 129),
        Offset(x + 16.5, 129),
        Offset(x + 25, 142),
        Offset(x + 18.5, 142),
      ], true);
    final hole = Path()
      ..addRRect(RRect.fromRectAndRadius(
          const Rect.fromLTWH(x + t, top + t, 25 - 2 * t, 18 - 2 * t),
          const Radius.circular(3)));
    canvas.drawPath(Path.combine(PathOperation.difference, r, hole), white);

    // E
    rect(83, top, t, cap, 0, white);
    rect(83, top, 21, t, 0, white);
    rect(83, top + 12, 18, t, 0, white);
    rect(83, top + cap - t, 21, t, 0, white);

    // H
    rect(111, top, t, cap, 0, white);
    rect(111 + 25 - t, top, t, cap, 0, white);
    rect(111, top + 12, 25, t, 0, white);

    // I
    rect(143, top, t, cap, 0, white);
  }

  @override
  bool shouldRepaint(RehiLogoPainter old) => old.palette != palette;
}
