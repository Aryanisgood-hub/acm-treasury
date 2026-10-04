import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors/app_error.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/error_view.dart';
import '../../widgets/loading_widget.dart';
import '../auth/no_access_screen.dart';
import 'app_shell.dart';

/// Loads the member profile before showing the app, so every screen below
/// can rely on a known role.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final member = ref.watch(currentMemberProvider);
    return member.when(
      loading: () => const Scaffold(body: LoadingWidget()),
      error: (e, _) => Scaffold(
        body: ErrorView(
          message: friendlyError(e),
          onRetry: () => ref.invalidate(currentMemberProvider),
        ),
      ),
      data: (m) => m == null
          ? const NoAccessScreen()
          : AppShell(member: m, navigationShell: navigationShell),
    );
  }
}
