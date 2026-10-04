import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../screens/auth/login_screen.dart';
import '../../screens/bills/bill_details_screen.dart';
import '../../screens/bills/bill_form_screen.dart';
import '../../screens/bills/bills_screen.dart';
import '../../screens/budget/budget_requests_screen.dart';
import '../../screens/dashboard/dashboard_screen.dart';
import '../../screens/events/event_details_screen.dart';
import '../../screens/events/events_screen.dart';
import '../../screens/export/export_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../screens/shell/auth_gate.dart';

class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Stream<AuthState> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }
  late final StreamSubscription<AuthState> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final auth = Supabase.instance.client.auth;
  final refresh = _AuthRefresh(auth.onAuthStateChange);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final signedIn = auth.currentSession != null;
      final onLogin = state.matchedLocation == '/login';
      if (!signedIn) return onLogin ? null : '/login';
      if (onLogin) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AuthGate(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/',
                builder: (context, state) => const DashboardScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/events',
                builder: (context, state) => const EventsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/bills',
                builder: (context, state) => const BillsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/budget',
                builder: (context, state) => const BudgetRequestsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen()),
          ]),
        ],
      ),
      GoRoute(
        path: '/event/:id',
        builder: (context, state) =>
            EventDetailsScreen(eventId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/bill/:id',
        builder: (context, state) =>
            BillDetailsScreen(billId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/bill/:id/edit',
        builder: (context, state) =>
            BillFormScreen(billId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/export',
        builder: (context, state) => const ExportScreen(),
      ),
      GoRoute(
        path: '/add-bill',
        builder: (context, state) => const BillFormScreen(),
      ),
    ],
  );
});
