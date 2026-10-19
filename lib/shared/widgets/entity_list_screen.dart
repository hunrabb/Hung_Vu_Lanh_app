import 'package:flutter/material.dart';

import '../../core/models/base_entity.dart';
import 'data_list.dart';

/// Generic page layout. Subclasses supply feature data, cards and actions.
abstract class EntityListScreen<T extends BaseEntity<String>>
    extends StatelessWidget {
  const EntityListScreen({super.key});

  List<T> items(BuildContext context);
  Widget buildItem(BuildContext context, T item);
  Widget? buildHeader(BuildContext context, List<T> items) => null;
  PreferredSizeWidget? buildAppBar(BuildContext context) => null;
  Widget? buildFloatingActionButton(BuildContext context) => null;
  Color get backgroundColor => const Color(0xFFFAF7F2);
  EdgeInsetsGeometry get listPadding =>
      const EdgeInsets.fromLTRB(20, 16, 20, 96);
  bool get useSafeArea => true;

  @override
  Widget build(BuildContext context) {
    final rows = items(context);
    final list = DataList<T>(
      items: rows,
      padding: listPadding,
      header: buildHeader(context, rows),
      itemBuilder: buildItem,
    );
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: buildAppBar(context),
      floatingActionButton: buildFloatingActionButton(context),
      body: useSafeArea ? SafeArea(child: list) : list,
    );
  }
}
