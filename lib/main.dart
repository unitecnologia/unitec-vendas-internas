import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'app_state.dart';
import 'config.dart';
import 'log/app_log.dart';
import 'ui/brand.dart';
import 'screens/connect_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/waiting_approval_screen.dart';

Future<void> _aplicarModoTela() async {
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: [SystemUiOverlay.top]);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _aplicarModoTela();
  await WakelockPlus.enable();
  await AppLog.instance.load();
  final config = await AppConfig.load();
  final state = AppState(config);
  await state.initialize();
  runApp(UnitecVendasInternasApp(state: state));
}

class UnitecVendasInternasApp extends StatefulWidget {
  const UnitecVendasInternasApp({super.key, required this.state});

  final AppState state;

  @override
  State<UnitecVendasInternasApp> createState() => _UnitecVendasInternasAppState();
}

class _UnitecVendasInternasAppState extends State<UnitecVendasInternasApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _aplicarModoTela();
      WakelockPlus.enable();
      if (widget.state.isLoggedIn) widget.state.sync.syncNow();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: widget.state,
      child: MaterialApp(
        title: 'Unitec Vendas Internas',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: Brand.blue, useMaterial3: true),
        home: const _Root(),
      ),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (!state.isConnected) return const ConnectScreen();
    if (!state.isApproved) return const WaitingApprovalScreen();
    if (!state.isLoggedIn) return const LoginScreen();
    return const HomeScreen();
  }
}
