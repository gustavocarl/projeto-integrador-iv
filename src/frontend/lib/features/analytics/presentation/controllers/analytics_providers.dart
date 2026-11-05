import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/analytics_repository_impl.dart';
import '../../domain/entities/product_groups.dart';
import '../../domain/entities/sales_forecast.dart';

/// Forecast of the next [months]. Invalidated whenever sales change.
final salesForecastProvider = FutureProvider.autoDispose
    .family<SalesForecast, int>(
      (ref, months) => ref.read(analyticsRepositoryProvider).forecast(months),
    );

/// Product groups; null = automatic. Invalidated whenever sales change.
final productGroupsProvider = FutureProvider.autoDispose
    .family<ProductGroups, int?>(
      (ref, groups) =>
          ref.read(analyticsRepositoryProvider).productGroups(groups),
    );
