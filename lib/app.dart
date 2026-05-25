import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'providers/core_providers.dart';
import 'providers/language_provider.dart';
import 'screens/animals/add_edit_animal_screen.dart';
import 'screens/animals/animal_list_screen.dart';
import 'screens/animals/animal_profile_screen.dart';
import 'screens/animals/female_ranking_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/auth/verify_email_screen.dart';
import 'screens/backup/backup_restore_screen.dart';
import 'screens/cultures/add_edit_crop_screen.dart';
import 'screens/cultures/add_edit_field_screen.dart';
import 'screens/cultures/cultures_screen.dart';
import 'screens/cultures/field_dashboard_screen.dart';
import 'screens/finances/add_edit_expense_screen.dart';
import 'screens/finances/add_edit_sale_screen.dart';
import 'screens/finances/finances_screen.dart';
import 'screens/home/home_dashboard_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/species/add_edit_species_screen.dart';
import 'screens/species/species_grid_screen.dart';
import 'theme/app_theme.dart';
import 'l10n/l10n.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/home',
    redirect: (context, state) {
      final user = authState.value;
      final loggedIn = user != null;
      final verified = loggedIn && user.emailVerified;
      final loc = state.matchedLocation;
      final onLogin = loc == '/login';
      final onSignup = loc == '/signup';
      final onVerify = loc == '/verify-email';

      if (!loggedIn) {
        // Logged out: only the login and signup screens are reachable.
        return (onLogin || onSignup) ? null : '/login';
      }
      if (!verified) {
        // Logged in but email not verified: gate everything behind verify.
        return onVerify ? null : '/verify-email';
      }
      // Logged in and verified: keep auth screens out of reach.
      if (onLogin || onSignup || onVerify) return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (_, __) => const SignupScreen(),
      ),
      GoRoute(
        path: '/verify-email',
        builder: (_, __) => const VerifyEmailScreen(),
      ),
      // Detail routes outside the shell so they push above bottom nav
      GoRoute(
        path: '/animals/species/new',
        builder: (_, __) => const AddEditSpeciesScreen(),
      ),
      GoRoute(
        path: '/animals/species/edit/:id',
        builder: (_, state) =>
            AddEditSpeciesScreen(speciesId: state.pathParameters['id']),
      ),
      GoRoute(
        path: '/animals/species/:speciesId/new',
        builder: (_, state) {
          final extra = state.extra as Map<String, String?>?;
          return AddEditAnimalScreen(
            speciesId: state.pathParameters['speciesId']!,
            motherId: extra?['motherId'],
            fatherId: extra?['fatherId'],
            birthEventId: extra?['birthEventId'],
          );
        },
      ),
      GoRoute(
        path: '/animals/species/:speciesId/:animalId',
        builder: (_, state) => AddEditAnimalScreen(
          speciesId: state.pathParameters['speciesId']!,
          animalId: state.pathParameters['animalId'],
        ),
      ),
      GoRoute(
        path: '/animals/animal/:id',
        builder: (_, state) =>
            AnimalProfileScreen(animalId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/animals/ranking',
        builder: (_, __) => const FemaleRankingScreen(),
      ),
      GoRoute(
        path: '/cultures/field/new',
        builder: (_, __) => const AddEditFieldScreen(),
      ),
      GoRoute(
        path: '/cultures/field/:id/edit',
        builder: (_, state) =>
            AddEditFieldScreen(fieldId: state.pathParameters['id']),
      ),
      GoRoute(
        path: '/cultures/field/:id',
        builder: (_, state) =>
            FieldDashboardScreen(fieldId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/cultures/crop/new',
        builder: (_, __) => const AddEditCropScreen(),
      ),
      GoRoute(
        path: '/cultures/crop/:id',
        builder: (_, state) =>
            AddEditCropScreen(cropId: state.pathParameters['id']),
      ),
      GoRoute(
        path: '/finances/expense/new',
        builder: (_, state) {
          final extra = state.extra as Map<String, String?>?;
          return AddEditExpenseScreen(
            preselectedScope: extra?['scope'],
            preselectedAnimalId: extra?['animalId'],
            preselectedSpeciesId: extra?['speciesId'],
            preselectedCropId: extra?['cropId'],
            preselectedFieldId: extra?['fieldId'],
          );
        },
      ),
      GoRoute(
        path: '/finances/sale/new',
        builder: (_, state) {
          final extra = state.extra as Map<String, String?>?;
          return AddEditSaleScreen(
            preselectedScope: extra?['scope'],
            preselectedAnimalId: extra?['animalId'],
            preselectedSpeciesId: extra?['speciesId'],
            preselectedCropId: extra?['cropId'],
          );
        },
      ),
      GoRoute(
        path: '/settings/backup',
        builder: (_, __) => const BackupRestoreScreen(),
      ),

      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) =>
            HomeDashboardScreen(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/home',
              builder: (_, __) => const HomeTab(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/animals',
              builder: (_, __) => const SpeciesGridScreen(),
              routes: [
                GoRoute(
                  path: 'species/:id',
                  builder: (_, state) => AnimalListScreen(
                      speciesId: state.pathParameters['id']!),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/cultures',
              builder: (_, __) => const CulturesScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/finances',
              builder: (_, __) => const FinancesScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/settings',
              builder: (_, __) => const SettingsScreen(),
            ),
          ]),
        ],
      ),
    ],
  );
});

class FarmApp extends ConsumerWidget {
  const FarmApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final locale = ref.watch(languageProvider);

    return MaterialApp.router(
      title: 'مزرعتي',
      theme: AppTheme.light,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
    );
  }
}
