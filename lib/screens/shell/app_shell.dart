import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_info.dart';
import '../../models/member_model.dart';

const _destinations = [
  (label: 'Dashboard', icon: Icons.dashboard_outlined, selected: Icons.dashboard),
  (label: 'Events', icon: Icons.event_outlined, selected: Icons.event),
  (label: 'Bills', icon: Icons.receipt_long_outlined, selected: Icons.receipt_long),
  (
    label: 'Budget',
    icon: Icons.account_balance_wallet_outlined,
    selected: Icons.account_balance_wallet
  ),
  (label: 'Profile', icon: Icons.person_outline, selected: Icons.person),
];

/// Bottom bar on phones, side rail on wide screens (web/desktop).
/// Hiding buttons here is UX only; the database enforces permissions.
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.member,
    required this.navigationShell,
  });

  final Member member;
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final index = navigationShell.currentIndex;
    void go(int i) => navigationShell.goBranch(i, initialLocation: i == index);

    final showAddBill = member.role.canAddBill && (index == 0 || index == 2);
    final fab = showAddBill
      ? FloatingActionButton.extended(
            onPressed: () => context.push('/add-bill'),
            icon: const Icon(Icons.add),
            label: const Text('Add bill'),
          )
        : null;

    final wide = MediaQuery.sizeOf(context).width >= 800;
    if (wide) {
      return Scaffold(
        floatingActionButton: fab,
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: index,
              onDestinationSelected: go,
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    Icon(Icons.account_balance_wallet_rounded,
                        color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 4),
                    Text(AppInfo.appName,
                        style: Theme.of(context).textTheme.labelSmall),
                  ],
                ),
              ),
              destinations: [
                for (final d in _destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selected),
                    label: Text(d.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: navigationShell),
          ],
        ),
      );
    }

    return Scaffold(
      body: navigationShell,
      floatingActionButton: fab,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: go,
        destinations: [
          for (final d in _destinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selected),
              label: d.label,
            ),
        ],
      ),
    );
  }
}
