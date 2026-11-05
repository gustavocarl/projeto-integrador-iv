import 'package:flutter/material.dart';

import '../../domain/entities/store.dart';

/// How each part of the app is named for the admin (the same names as the main menu).
extension StoreAreaView on StoreArea {
  String get label => switch (this) {
    StoreArea.products => 'Produtos',
    StoreArea.checkout => 'Vender',
    StoreArea.imports => 'Importar',
    StoreArea.exports => 'Exportar',
    StoreArea.comparison => 'Comparar',
    StoreArea.analytics => 'Prever',
  };

  String get description => switch (this) {
    StoreArea.products => 'Cadastro de produtos, preços e estoque',
    StoreArea.checkout => 'Caixa: vender os produtos cadastrados',
    StoreArea.imports => 'Lotes de vendas: planilhas e vendas digitadas',
    StoreArea.exports => 'Planilhas de vendas geradas',
    StoreArea.comparison => 'Comparativo de meses',
    StoreArea.analytics => 'Previsão e grupos de produtos',
  };

  IconData get icon => switch (this) {
    StoreArea.products => Icons.inventory_2_outlined,
    StoreArea.checkout => Icons.point_of_sale_outlined,
    StoreArea.imports => Icons.table_chart_outlined,
    StoreArea.exports => Icons.table_view_outlined,
    StoreArea.comparison => Icons.compare_arrows_outlined,
    StoreArea.analytics => Icons.insights_outlined,
  };
}

extension StoreRoleView on StoreRole {
  String get label => switch (this) {
    StoreRole.admin => 'Admin',
    StoreRole.member => 'Usuário',
    StoreRole.pending => 'Aguardando aprovação',
  };
}

/// "Vender, Importar" / "Todas as partes" / "Nenhuma parte liberada".
String areasSummary(Set<StoreArea> areas) {
  if (areas.length == StoreArea.values.length) return 'Todas as partes';
  if (areas.isEmpty) return 'Nenhuma parte liberada';
  return [
    for (final area in StoreArea.values)
      if (areas.contains(area)) area.label,
  ].join(', ');
}
