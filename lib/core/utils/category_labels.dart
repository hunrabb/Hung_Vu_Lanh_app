import '../models/service.dart';

String categoryLabel(ServiceCategory category) => switch (category) {
  ServiceCategory.haircut => 'Cắt tóc',
  ServiceCategory.hairWash => 'Gội đầu',
  ServiceCategory.perm => 'Uốn tóc',
  ServiceCategory.dye => 'Nhuộm tóc',
  ServiceCategory.massage => 'Massage',
  ServiceCategory.shaving => 'Cạo râu',
};

String categoryLabels(Iterable<String> ids) => ids
    .map(
      (id) => ServiceCategory.values.any((category) => category.name == id)
          ? categoryLabel(ServiceCategory.values.byName(id))
          : id,
    )
    .join(' • ');
