import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Shared account identity; all details come from the current profile.
class ProfileIdentityCard extends StatelessWidget {
  const ProfileIdentityCard({
    super.key,
    required this.name,
    required this.subtitle,
    required this.badge,
    this.detail,
  });

  final String name, subtitle, badge;
  final String? detail;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [AppTheme.ink, Color(0xFF65503E)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFF78634D)),
    ),
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFB69A76)),
          ),
          child: CircleAvatar(
            radius: 29,
            backgroundColor: const Color(0xFFF0E3D0),
            child: Text(
              name.trim().isEmpty
                  ? '?'
                  : name.trim().characters.first.toUpperCase(),
              style: const TextStyle(
                color: AppTheme.primary,
                fontSize: 27,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          name,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFFFFF8EF),
            fontSize: 23,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFFDFD0BE), height: 1.5),
        ),
        if (detail != null) ...[
          const SizedBox(height: 8),
          Text(
            detail!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFDFD0BE),
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF74604B),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            badge,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFF3DEBC),
              fontSize: 11,
              letterSpacing: 0.7,
            ),
          ),
        ),
      ],
    ),
  );
}
