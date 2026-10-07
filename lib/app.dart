import 'core/security/access_scope.dart';
import 'features/branches/data/mock_branch_repository.dart';
import 'features/branches/application/branch_provider.dart';

import 'package:flutter/material.dart';

import 'core/models/app_user.dart';
import 'core/network/api_client.dart';
import 'core/network/token_store.dart';
import 'features/auth/data/api_auth_repository.dart';
import 'features/boss/data/api_pending_staff_repository.dart';
import 'features/boss/application/pending_staff_provider.dart';
import 'features/workspace/application/workspace_provider.dart';
import 'features/workspace/data/workspace_repository.dart';
import 'features/booking/application/api_appointment_provider.dart';
import 'features/booking/data/api_booking_repository.dart';
import 'features/reports/data/report_repository.dart';
import 'features/reports/application/report_provider.dart';

import 'package:provider/provider.dart';

import 'core/routing/app_router.dart';
import 'core/routing/app_routes.dart';
import 'features/auth/application/auth_controller.dart';
import 'features/auth/data/mock_auth_repository.dart';
import 'features/catalog/application/service_provider.dart';
import 'features/catalog/data/mock_service_repository.dart';
import 'features/users/application/user_provider.dart';
import 'features/users/data/mock_user_repository.dart';
import 'features/settings/application/shop_settings_provider.dart';
import 'features/booking/application/appointment_provider.dart';
import 'features/booking/data/mock_appointment_repository.dart';

class BarbershopApp extends StatelessWidget {
  const BarbershopApp({super.key, this.useMock = false, this.networkClient});
  final bool useMock;
  final ApiClient? networkClient;

  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      if (!useMock) ...[
        Provider(
          create: (_) =>
              networkClient?.tokens ?? TokenStore(SecureTokenPersistence()),
        ),
        Provider(
          create: (c) =>
              networkClient ?? ApiClient(tokens: c.read<TokenStore>()),
          dispose: (_, client) => client.close(),
        ),
        Provider(create: (c) => ApiAuthRepository(c.read<ApiClient>())),
      ],
      Provider(create: (_) => MockBranchRepository()),
      Provider(create: (_) => MockAppointmentRepository()),
      ChangeNotifierProvider(create: (_) => MockUserRepository()),
      Provider(
        create: (context) =>
            MockAuthRepository(users: context.read<MockUserRepository>()),
      ),
      ChangeNotifierProvider(
        create: (context) => useMock
            ? AuthController(context.read<MockAuthRepository>())
            : (AuthController(
                null,
                apiRepository: context.read<ApiAuthRepository>(),
              )..restoreSession()),
      ),
      if (!useMock)
        ChangeNotifierProvider(
          lazy: false,
          create: (c) => PendingStaffProvider(
            ApiPendingStaffRepository(c.read<ApiClient>()),
            c.read<AuthController>(),
          ),
        ),
      if (!useMock)
        ChangeNotifierProvider(
          lazy: false,
          create: (c) => WorkspaceProvider(
            WorkspaceRepository(c.read<ApiClient>()),
            c.read<AuthController>(),
          ),
        ),
      if (!useMock)
        ChangeNotifierProvider(
          lazy: false,
          create: (c) => ApiAppointmentProvider(
            ApiBookingRepository(c.read<ApiClient>()),
            c.read<AuthController>(),
          ),
        ),
      if (!useMock)
        ChangeNotifierProvider(
          lazy: false,
          create: (c) => ReportProvider(
            ReportRepository(c.read<ApiClient>()),
            c.read<AuthController>(),
            c.read<ApiAppointmentProvider>(),
          ),
        ),
      ChangeNotifierProvider(
        create: (context) => AccessScope(
          () => context.read<AuthController>().currentUser,
          changes: context.read<AuthController>(),
        ),
      ),
      ChangeNotifierProvider(
        create: (context) => ServiceProvider(
          MockServiceRepository(),
          access: context.read<AccessScope>(),
        ),
      ),
      ChangeNotifierProvider(
        create: (context) => UserProvider(
          context.read<MockUserRepository>(),
          auth: context.read<MockAuthRepository>(),
          branchName: (id) =>
              context.read<MockBranchRepository>().getById(id)?.name,
          hasAppointments: (id) => context
              .read<MockAppointmentRepository>()
              .getAll()
              .any((a) => a.staffId == id),
          branchExists: (id) =>
              context.read<MockBranchRepository>().getById(id) != null,
          access: context.read<AccessScope>(),
          canReadCustomer: (id, actor) =>
              context.read<MockAppointmentRepository>().getAll().any(
                (a) =>
                    a.customerId == id &&
                    a.branchId == actor.branchId &&
                    (actor.role == UserRole.manager || a.staffId == actor.id),
              ),
        ),
      ),
      ChangeNotifierProvider(
        create: (context) => ShopSettingsProvider(
          access: context.read<AccessScope>(),
          branchExists: (id) =>
              context.read<MockBranchRepository>().getById(id) != null,
        ),
      ),
      ChangeNotifierProvider(
        create: (context) {
          return AppointmentProvider(
            context.read<MockAppointmentRepository>(),
            access: context.read<AccessScope>(),
            services: context.read<ServiceProvider>(),
            users: context.read<UserProvider>(),
            shopSettings: context.read<ShopSettingsProvider>(),
          );
        },
      ),
      ChangeNotifierProvider(
        create: (context) => BranchProvider(
          context.read<MockBranchRepository>(),
          access: context.read<AccessScope>(),
          users: context.read<MockUserRepository>(),
          appointments: context.read<MockAppointmentRepository>(),
          settings: context.read<ShopSettingsProvider>(),
        ),
      ),
    ],
    child: const _AppNavigator(),
  );
}

class _AppNavigator extends StatefulWidget {
  const _AppNavigator();
  @override
  State<_AppNavigator> createState() => _AppNavigatorState();
}

class _AppNavigatorState extends State<_AppNavigator> {
  final _navigator = GlobalKey<NavigatorState>();
  AuthController? _auth;
  bool _hadSession = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthController>();
    if (identical(auth, _auth)) return;
    _auth?.removeListener(_sessionChanged);
    _auth = auth;
    _hadSession = auth.isAuthenticated;
    auth.addListener(_sessionChanged);
  }

  void _sessionChanged() {
    final expired = _hadSession && !_auth!.isAuthenticated;
    _hadSession = _auth!.isAuthenticated;
    if (expired && _auth!.isRemote) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_auth!.isAuthenticated && !_auth!.isLoading) {
          _navigator.currentState?.pushNamedAndRemoveUntil(
            AppRoutes.login,
            (_) => false,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _auth?.removeListener(_sessionChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: _navigator,
    title: 'Barbershop & Spa',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
    initialRoute: AppRoutes.login,
    onGenerateRoute: AppRouter.generateRoute,
  );
}
