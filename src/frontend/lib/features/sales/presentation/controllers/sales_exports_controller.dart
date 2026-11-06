import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/controllers/auth_controller.dart';

import '../../data/repositories/sales_export_repository_impl.dart';
import '../../domain/entities/sales_export.dart';
import '../../domain/entities/sales_period.dart';

/// Generated spreadsheets (Exportações). Actions throw Failure for the screen's runSafely.
class SalesExportsController extends AsyncNotifier<List<SalesExport>> {
  @override
  Future<List<SalesExport>> build() {
    if (!ref.watch(sessionScopeProvider).hasStoreData) return Future.value([]);
    return ref.read(salesExportRepositoryProvider).list();
  }

  /// Generates and keeps the spreadsheet of [period]; it goes to the top of the list.
  Future<SalesExport> create(SalesPeriod period) async {
    final created = await ref
        .read(salesExportRepositoryProvider)
        .create(period);
    if (state.hasValue) {
      state = AsyncData([created, ...state.value!]);
    } else {
      // Still loading: the list may have been read before this one existed.
      ref.invalidateSelf();
    }
    return created;
  }

  Future<void> delete(String id) async {
    await ref.read(salesExportRepositoryProvider).delete(id);
    state = AsyncData([...?state.value?.where((e) => e.id != id)]);
  }
}

final salesExportsControllerProvider =
    AsyncNotifierProvider<SalesExportsController, List<SalesExport>>(
      SalesExportsController.new,
    );
