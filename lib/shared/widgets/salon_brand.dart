import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/salon_assets.dart';

/// Offline salon photography and a shared warm identity.
class SalonBrandBanner extends StatelessWidget {
  const SalonBrandBanner({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: EdgeInsets.all(compact ? 18 : 22),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF302B25), Color(0xFF514437)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(26),
      border: Border.all(color: const Color(0xFF70604B)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x1830251F),
          blurRadius: 24,
          offset: Offset(0, 10),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.content_cut_rounded, size: 15, color: Color(0xFFE5CAA1)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'BARBERSHOP & SPA',
                style: TextStyle(
                  color: Color(0xFFE5CAA1),
                  fontSize: 10,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) => Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      compact
                          ? 'Chăm chút diện mạo.\nThư thái mỗi ngày.'
                          : 'Tóc đẹp.\nTâm trí thư thái.',
                      style: TextStyle(
                        color: const Color(0xFFFFF7E9),
                        fontSize: constraints.maxWidth > 500
                            ? 32
                            : (compact ? 22 : 27),
                        height: 1.25,
                        letterSpacing: -0.7,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'CẮT TÓC  /  CHĂM SÓC  /  THƯ GIÃN',
                      style: TextStyle(
                        color: Color(0xFFC7B9A6),
                        fontSize: 8,
                        letterSpacing: 1.1,
                        height: 1.7,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: (constraints.maxWidth * 0.4).clamp(
                  60.0,
                  compact ? 170.0 : 126.0,
                ),
                child: AspectRatio(
                  aspectRatio: 0.95,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.asset(
                      SalonAssets.interior,
                      fit: BoxFit.cover,
                      alignment: const Alignment(0.7, 0),
                      semanticLabel: 'Không gian salon · Ảnh minh họa',
                      errorBuilder: (_, error, stack) => const SalonArtwork(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class SalonNavIcon extends StatelessWidget {
  const SalonNavIcon({super.key, required this.icon});
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFFEFE5D7),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Icon(icon, color: AppTheme.primary, size: 23),
  );
}

class SalonArtwork extends StatelessWidget {
  const SalonArtwork({super.key});
  @override
  Widget build(BuildContext context) =>
      ExcludeSemantics(child: CustomPaint(painter: const _SalonPainter()));
}

class _SalonPainter extends CustomPainter {
  const _SalonPainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 180, size.height / 190);
    final paint = Paint()..isAntiAlias = true;
    void rect(
      double x,
      double y,
      double w,
      double h,
      double radius,
      Color color,
    ) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, w, h),
          Radius.circular(radius),
        ),
        paint
          ..color = color
          ..style = PaintingStyle.fill,
      );
    }

    void line(Offset from, Offset to, Color color, double width) {
      canvas.drawLine(
        from,
        to,
        paint
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round,
      );
    }

    const brass = Color(0xFFBFA47B),
        leather = Color(0xFF86664C),
        cream = Color(0xFFEBDAC0);
    // Arched brass mirror and its reflected light.
    final arch = RRect.fromRectAndCorners(
      const Rect.fromLTWH(34, 5, 104, 130),
      topLeft: const Radius.circular(52),
      topRight: const Radius.circular(52),
      bottomLeft: const Radius.circular(5),
      bottomRight: const Radius.circular(5),
    );
    canvas.drawRRect(
      arch,
      paint
        ..style = PaintingStyle.fill
        ..color = brass,
    );
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        const Rect.fromLTWH(39, 10, 94, 119),
        topLeft: const Radius.circular(47),
        topRight: const Radius.circular(47),
      ),
      paint
        ..shader = const LinearGradient(
          colors: [Color(0xFF9BABA0), Color(0xFFD8D9C8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(const Rect.fromLTWH(39, 10, 94, 119)),
    );
    paint.shader = null;
    line(
      const Offset(51, 72),
      const Offset(85, 35),
      const Color(0x55FFFFFF),
      2,
    );
    line(
      const Offset(52, 84),
      const Offset(94, 38),
      const Color(0x33FFFFFF),
      7,
    );
    rect(22, 122, 128, 7, 2, brass);
    // Barber chair, folded towel, hydraulic pedestal and footrest.
    canvas.drawOval(
      const Rect.fromLTWH(25, 175, 128, 10),
      paint
        ..style = PaintingStyle.fill
        ..color = const Color(0x4430251F),
    );
    rect(57, 95, 58, 43, 12, leather);
    rect(61, 99, 50, 31, 9, const Color(0xFF9F7C59));
    rect(72, 89, 27, 12, 5, leather);
    rect(54, 136, 65, 13, 5, leather);
    rect(57, 137, 60, 4, 2, const Color(0xFFAE8B66));
    line(const Offset(45, 123), const Offset(45, 143), brass, 3);
    line(const Offset(126, 123), const Offset(126, 143), brass, 3);
    rect(39, 119, 17, 5, 2, cream);
    rect(116, 119, 17, 5, 2, cream);
    rect(91, 105, 17, 31, 2, cream);
    line(const Offset(94, 131), const Offset(105, 131), brass, 1);
    rect(81, 149, 10, 23, 2, brass);
    rect(61, 172, 51, 5, 3, brass);
    line(const Offset(112, 149), const Offset(125, 161), brass, 3);
    line(const Offset(125, 161), const Offset(107, 161), brass, 3);
    // Spa greenery beside the chair.
    line(
      const Offset(154, 154),
      const Offset(157, 91),
      const Color(0xFF8F9C7B),
      2,
    );
    for (var i = 0; i < 4; i++) {
      final y = 101.0 + i * 12;
      canvas.drawOval(
        Rect.fromLTWH(i.isEven ? 139 : 156, y, 20, 9),
        paint
          ..style = PaintingStyle.fill
          ..color = i.isEven
              ? const Color(0xFF9DA88A)
              : const Color(0xFF75846C),
      );
    }
    rect(144, 150, 26, 26, 5, const Color(0xFFD2BA98));
    rect(141, 148, 32, 5, 2, cream);
    // Small apothecary bottles.
    rect(16, 109, 8, 13, 2, const Color(0xFFAC8F64));
    rect(18, 104, 4, 5, 1, cream);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SalonPainter oldDelegate) => false;
}
