import 'package:flutter/material.dart';

class CustomButton extends StatelessWidget {
  const CustomButton({super.key, required this.label, required this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFFCDAE7F),
        foregroundColor: const Color(0xFF30251F),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: Theme.of(context).textTheme.labelLarge
            ?.copyWith(fontSize: 17, fontWeight: FontWeight.w700),
      ),
      onPressed: onPressed,
      icon: const Icon(Icons.calendar_month),
      label: Text(label),
    ),
  );
}
