import 'package:flutter/material.dart';

import '../../../core/theme/salon_assets.dart';

class BookingBanner extends StatelessWidget {
  const BookingBanner({super.key, required this.onBook, this.walkIn = false});
  final VoidCallback onBook;
  final bool walkIn;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(24),
    child: Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            SalonAssets.interior,
            fit: BoxFit.cover,
            alignment: const Alignment(0.7, 0),
            excludeFromSemantics: true,
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF30251F).withValues(alpha: 0.94),
                  const Color(0xFF30251F).withValues(alpha: 0.45),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'BARBERSHOP & SPA',
                style: TextStyle(
                  color: Color(0xFFE5CAA1),
                  fontSize: 10,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                walkIn
                    ? 'Đón khách,\nchăm sóc tận tâm.'
                    : 'Hẹn một ngày\nchăm chút bản thân.',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 27,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                walkIn
                    ? 'Chọn dịch vụ và giờ trống cho khách tại tiệm.'
                    : 'Chọn cơ sở, dịch vụ và chuyên viên bạn yêu thích.',
                style: const TextStyle(
                  color: Color(0xFFE7DED2),
                  height: 1.5,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onBook,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE5CAA1),
                  foregroundColor: const Color(0xFF30251F),
                ),
                icon: const Icon(Icons.calendar_month_outlined, size: 18),
                label: Text(walkIn ? 'Chọn lịch cho khách' : 'Đặt lịch ngay'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
