import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'data/vehicle_repository.dart';
import 'services/gate_hardware.dart';
import 'ui/admin_dashboard.dart';
import 'ui/gate_app.dart';
import 'ui/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (reads android/app/google-services.json)
  try {
    await Firebase.initializeApp();
    debugPrint('✅ Firebase initialized successfully.');
  } catch (e) {
    debugPrint('❌ Firebase initialization failed: $e');
    debugPrint('Cloud sync will not be available. Local features still work.');
  }

  runApp(const SmartGatePassApp());
}

class SmartGatePassApp extends StatefulWidget {
  const SmartGatePassApp({
    super.key,
    this.repository,
    this.plateReader,
    this.printer,
  });
  final VehicleRepository? repository;
  final PlateReader? plateReader;
  final PassPrinter? printer;

  @override
  State<SmartGatePassApp> createState() => _SmartGatePassAppState();
}

class _SmartGatePassAppState extends State<SmartGatePassApp> {
  late Future<VehicleRepository> _repository;
  late final PlateReader _reader = widget.plateReader ?? CameraPlateReader();
  late final PassPrinter _printer = widget.printer ?? BluetoothPassPrinter();

  String? _currentRole; // null = not logged in, 'admin' or 'guard'

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _repository = widget.repository != null
        ? Future.value(widget.repository)
        : SqliteVehicleRepository.open();
  }

  void _logout() {
    setState(() => _currentRole = null);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'SmartGatePass',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF087F78),
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xFFF4F6F5),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF4F6F5),
        foregroundColor: Color(0xFF142D39),
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    ),
    home: FutureBuilder<VehicleRepository>(
      future: _repository,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.storage_rounded, size: 48),
                      const SizedBox(height: 16),
                      const Text(
                        'Records could not be opened',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Check available phone storage, then retry. Existing records have not been reset.',
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: () => setState(_load),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final repository = snapshot.data!;

        // Route by role
        if (_currentRole == null) {
          return LoginScreen(
            repository: repository,
            onLogin: (role) => setState(() => _currentRole = role),
          );
        }

        if (_currentRole == 'admin') {
          return AdminDashboard(
            repository: repository,
            onLogout: _logout,
          );
        }

        // Default: Guard
        return GateHome(
          repository: repository,
          reader: _reader,
          printer: _printer,
        );
      },
    ),
  );
}