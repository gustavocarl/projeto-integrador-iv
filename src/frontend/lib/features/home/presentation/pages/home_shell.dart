import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../analytics/presentation/pages/analytics_page.dart';
import '../../../auth/domain/entities/user.dart';
import '../../../notifications/presentation/widgets/notifications_button.dart';
import '../../../products/presentation/controllers/restock_providers.dart';
import '../../../store/domain/entities/store.dart';
import '../../../products/presentation/pages/products_page.dart';
import '../../../sales/presentation/pages/checkout_page.dart';
import '../../../sales/presentation/pages/month_comparison_page.dart';
import '../../../sales/presentation/pages/sales_exports_page.dart';
import '../../../sales/presentation/pages/sales_imports_page.dart';
import '../../../../shared/widgets/brand.dart';
import '../widgets/account_menu_button.dart';

/// A main menu entry.
class _Destination {
  const _Destination(
    this.area,
    this.label,
    this.title,
    this.icon,
    this.selectedIcon,
  );

  /// Shown only to users the admin gave this part of the app.
  final StoreArea area;

  /// Short name in the menu.
  final String label;

  /// App bar title.
  final String title;
  final IconData icon;
  final IconData selectedIcon;
}

/// The main menu: products, checkout, imports, exports, the month comparison and the
/// analyses (forecast and product groups). A bottom bar on phones and a side
/// rail on wider screens. Each screen keeps its state (search, cart) when switching.
/// With the restock warnings on, Produtos shows how many products must be restocked.
/// Only the parts of the app the admin gave the user appear (admins see everything).
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key, required this.user});

  final User user;

  /// Width from which the menu moves to the side.
  static const railBreakpoint = 600.0;

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  static const _destinations = [
    _Destination(
      StoreArea.products,
      'Produtos',
      'Produtos',
      Icons.inventory_2_outlined,
      Icons.inventory_2,
    ),
    _Destination(
      StoreArea.checkout,
      'Vender',
      'Venda de produtos',
      Icons.point_of_sale_outlined,
      Icons.point_of_sale,
    ),
    // Short menu labels: six must fit a 360 px phone; the app bar shows the full title.
    _Destination(
      StoreArea.imports,
      'Importar',
      'Importações de vendas',
      Icons.table_chart_outlined,
      Icons.table_chart,
    ),
    _Destination(
      StoreArea.exports,
      'Exportar',
      'Exportações de vendas',
      Icons.table_view_outlined,
      Icons.table_view,
    ),
    _Destination(
      StoreArea.comparison,
      'Comparar',
      'Comparativo de meses',
      Icons.compare_arrows_outlined,
      Icons.compare_arrows,
    ),
    _Destination(
      StoreArea.analytics,
      'Prever',
      'Previsão e grupos de produtos',
      Icons.insights_outlined,
      Icons.insights,
    ),
  ];

  StoreArea _selected = StoreArea.products;

  /// Built the first time each screen is opened, then kept.
  final _visited = <StoreArea>{};

  List<_Destination> get _visible => [
    for (final d in _destinations)
      if (widget.user.can(d.area)) d,
  ];

  void _select(List<_Destination> visible, int index) => setState(() {
    _selected = visible[index].area;
  });

  Widget _page(StoreArea area) => switch (area) {
    StoreArea.products => const ProductsPage(),
    StoreArea.checkout => const CheckoutPage(),
    StoreArea.imports => const SalesImportsPage(),
    StoreArea.exports => const SalesExportsPage(),
    StoreArea.comparison => const MonthComparisonPage(),
    StoreArea.analytics => const AnalyticsPage(),
  };

  /// The menu icon of [index]; Produtos carries the restock count.
  Widget _icon(StoreArea area, IconData icon, int restock) {
    if (area != StoreArea.products || restock == 0) return Icon(icon);
    return Tooltip(
      message: restock == 1
          ? '1 produto precisa de reposição'
          : '$restock produtos precisam de reposição',
      child: Badge.count(
        key: const Key('restockBadge'),
        count: restock,
        child: Icon(icon),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    // The admin may have taken away the open screen: fall back to the first one left.
    final index = visible.indexWhere((d) => d.area == _selected);
    final current = index >= 0 ? index : 0;
    if (visible.isNotEmpty) _visited.add(visible[current].area);

    final restock = widget.user.can(StoreArea.products)
        ? ref.watch(restockProductsProvider).length
        : 0;
    final wide = MediaQuery.sizeOf(context).width >= HomeShell.railBreakpoint;
    // The menu needs at least two entries.
    final hasMenu = visible.length >= 2;
    final body = visible.isEmpty
        ? const Center(
            child: SingleChildScrollView(
              child: EmptyState(
                key: Key('noAreas'),
                icon: Icons.lock_outline,
                title: 'Nenhuma parte do sistema liberada',
                message:
                    'Peça ao admin da loja para liberar o que você vai usar.',
              ),
            ),
          )
        : IndexedStack(
            index: current,
            children: [
              for (final d in visible)
                _visited.contains(d.area)
                    ? KeyedSubtree(key: ValueKey(d.area), child: _page(d.area))
                    : const SizedBox.shrink(),
            ],
          );

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            // On wide screens the logo sits on top of the side menu.
            if (!wide || !hasMenu) ...[
              const BrandLogo(size: 32),
              const SizedBox(width: 12),
            ],
            Flexible(
              child: Text(
                visible.isEmpty
                    ? widget.user.store?.name ?? ''
                    : visible[current].title,
              ),
            ),
          ],
        ),
        actions: [
          const NotificationsButton(),
          AccountMenuButton(user: widget.user),
          const SizedBox(width: 8),
        ],
      ),
      body: wide && hasMenu
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: current,
                  onDestinationSelected: (i) => _select(visible, i),
                  labelType: NavigationRailLabelType.all,
                  leading: const Padding(
                    padding: EdgeInsets.only(top: 8, bottom: 16),
                    child: BrandLogo(size: 44),
                  ),
                  destinations: [
                    for (final d in visible)
                      NavigationRailDestination(
                        icon: _icon(d.area, d.icon, restock),
                        selectedIcon: _icon(d.area, d.selectedIcon, restock),
                        label: Text(d.label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1, thickness: 1),
                Expanded(child: body),
              ],
            )
          : body,
      bottomNavigationBar: wide || !hasMenu
          ? null
          : NavigationBar(
              selectedIndex: current,
              onDestinationSelected: (i) => _select(visible, i),
              destinations: [
                for (final d in visible)
                  NavigationDestination(
                    icon: _icon(d.area, d.icon, restock),
                    selectedIcon: _icon(d.area, d.selectedIcon, restock),
                    label: d.label,
                  ),
              ],
            ),
    );
  }
}
