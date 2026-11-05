import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/sales_repository_impl.dart';
import '../../domain/entities/month_comparison.dart';

/// The two months being compared ("2026-01").
typedef MonthPair = ({String base, String target});

/// Months with sales, most recent first. Invalidated whenever sales change.
final salesMonthsProvider = FutureProvider<List<SalesMonth>>(
  (ref) => ref.read(salesRepositoryProvider).listMonths(),
);

final monthComparisonProvider = FutureProvider.autoDispose
    .family<MonthComparison, MonthPair>(
      (ref, pair) => ref
          .read(salesRepositoryProvider)
          .compareMonths(pair.base, pair.target),
    );
