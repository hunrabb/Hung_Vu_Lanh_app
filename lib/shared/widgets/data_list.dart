import 'package:flutter/material.dart';

/// Reusable list UI; T is the model rendered by each item.
/// The page owns its data, permissions and item presentation.
class DataList<T> extends StatelessWidget {
  const DataList({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.header,
    this.padding = EdgeInsets.zero,
  });

  final List<T> items;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final Widget? header;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => ListView(
    padding: padding,
    children: [?header, for (final item in items) itemBuilder(context, item)],
  );
}
