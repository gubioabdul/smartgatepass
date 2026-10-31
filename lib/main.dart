import 'package:flutter/material.dart';

import 'data/vehicle_repository.dart';
import 'services/gate_hardware.dart';
import 'ui/gate_app.dart';
import 'ui/login_screen.dart'; // Import the new screen

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
  
  bool _isLoggedIn = false; // <-- NEW Auth State

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
    // Check Auth State here
    home: !_isLoggedIn
        ? LoginScreen(onLogin: () => setState(() => _isLoggedIn = true))
        : FutureBuilder<VehicleRepository>(
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
              return GateHome(
                repository: snapshot.data!,
                reader: _reader,
                printer: _printer,
              );
            },
          ),
  );
}