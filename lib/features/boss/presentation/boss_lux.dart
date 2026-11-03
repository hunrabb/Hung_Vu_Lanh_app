import 'package:flutter/material.dart';

/// Design tokens and small building blocks for the redesigned Boss screens.
///
/// The palette is the one the approved Boss Overview uses. Overview still has
/// its own private copy; it can be migrated here in a later, approved step.
abstract final class BossLux {
  static const primary = Color(0xFF594333);
  static const secondary = Color(0xFFA88B55);
  static const background = Color(0xFFF8F6F2);
  static const surface = Colors.white;
  static const text = Color(0xFF302B27);
  // Darkened from the brand #898178 so secondary text reaches WCAG AA.
  static const muted = Color(0xFF70685F);
  static const border = Color(0xFFE8E2D9);
  static const tint = Color(0xFFF3EDE2);
  static const positive = Color(0xFF3E6B4A);
  static const negative = Color(0xFF9A3D32);
  static const radius = 16.0;
  static const shadow = [
    BoxShadow(color: Color(0x0F302B27), blurRadius: 18, offset: Offset(0, 6)),
  ];
  static const figures = [FontFeature.tabularFigures()];
}

/// Rounded white surface with the soft shadow used across Boss screens.
class LuxCard extends StatelessWidget {
  const LuxCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: BossLux.surface,
      borderRadius: BorderRadius.circular(BossLux.radius),
      border: Border.all(color: BossLux.border),
      boxShadow: BossLux.shadow,
    ),
    child: child,
  );
}

/// Pill showing an appointment status; colours keep AA contrast.
class LuxStatusChip extends StatelessWidget {
  const LuxStatusChip({super.key, required this.status, required this.label});
  final String status, label;
  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      'completed' => (const Color(0xFFE4EEE6), BossLux.positive),
      'cancelled' => (const Color(0xFFF5E3E0), BossLux.negative),
      'pending' => (const Color(0xFFFBF0D9), const Color(0xFF86590B)),
      'noShow' => (const Color(0xFFECE8E2), const Color(0xFF5F5850)),
      _ => (BossLux.tint, BossLux.primary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

/// Single-select filter pill (a lighter alternative to [ChoiceChip]).
class LuxFilterPill extends StatelessWidget {
  const LuxFilterPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: label,
    excludeSemantics: true,
    child: Material(
      color: selected ? BossLux.primary : BossLux.surface,
      shape: StadiumBorder(
        side: BorderSide(color: selected ? BossLux.primary : BossLux.border),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Center(
              widthFactor: 1,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : BossLux.text,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Style for the white, hairline-bordered buttons that sit beside filters.
ButtonStyle luxOutlinedStyle() => OutlinedButton.styleFrom(
  foregroundColor: BossLux.primary,
  backgroundColor: BossLux.surface,
  minimumSize: const Size(48, 48),
  side: const BorderSide(color: BossLux.border),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  padding: const EdgeInsets.symmetric(horizontal: 14),
);

/// Branch selector: "Toàn chuỗi" plus the names the report provider loaded.
class LuxBranchFilter extends StatelessWidget {
  const LuxBranchFilter({
    super.key,
    required this.value,
    required this.names,
    required this.onChanged,
  });
  final String? value;
  final Map<String, String> names;
  final ValueChanged<String?> onChanged;
  @override
  Widget build(BuildContext context) {
    OutlineInputBorder outline(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: width),
        );
    return DropdownButtonFormField<String>(
      key: ValueKey(value),
      initialValue: value,
      isExpanded: true,
      icon: const Icon(Icons.expand_more, color: BossLux.muted),
      style: DefaultTextStyle.of(context).style.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: BossLux.text,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: BossLux.surface,
        prefixIcon: const Icon(
          Icons.storefront_outlined,
          size: 20,
          color: BossLux.primary,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border: outline(BossLux.border),
        enabledBorder: outline(BossLux.border),
        focusedBorder: outline(BossLux.primary, 1.5),
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('Toàn chuỗi')),
        for (final b in names.entries)
          DropdownMenuItem(
            value: b.key,
            child: Text(b.value, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: onChanged,
    );
  }
}

/// Centered icon + message for empty and inline-error states.
class LuxNote extends StatelessWidget {
  const LuxNote({
    super.key,
    required this.icon,
    required this.text,
    this.hint,
    this.action,
    this.onAction,
  });
  final IconData icon;
  final String text;
  final String? hint, action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: SizedBox(
      width: double.infinity,
      child: Column(
        children: [
          Icon(icon, size: 32, color: BossLux.muted),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: BossLux.text,
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(
              hint!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, color: BossLux.muted),
            ),
          ],
          if (action != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(foregroundColor: BossLux.primary),
              child: Text(action!),
            ),
        ],
      ),
    ),
  );
}

class LuxErrorCard extends StatelessWidget {
  const LuxErrorCard({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFFBF1EF),
      borderRadius: BorderRadius.circular(BossLux.radius),
      border: Border.all(color: const Color(0xFFEBCFCA)),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline, color: BossLux.negative),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(fontSize: 14, color: BossLux.text),
          ),
        ),
        TextButton(
          onPressed: onRetry,
          style: TextButton.styleFrom(foregroundColor: BossLux.negative),
          child: const Text('Thử lại'),
        ),
      ],
    ),
  );
}

/// Static placeholder block shown while a report loads for the first time.
class LuxSkeleton extends StatelessWidget {
  const LuxSkeleton({super.key, required this.height});
  final double height;
  @override
  Widget build(BuildContext context) => Container(
    height: height,
    decoration: BoxDecoration(
      color: const Color(0xFFEFEAE1),
      borderRadius: BorderRadius.circular(BossLux.radius),
    ),
  );
}
