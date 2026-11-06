import 'package:flutter/material.dart';

import '../data/vehicle_repository.dart';
import '../domain/vehicle_log.dart';
import '../services/cloud_sync_service.dart';

const ink = Color(0xFF142D39);
const teal = Color(0xFF087F78);

class AdminDashboard extends StatefulWidget {
  final VehicleRepository repository;
  final VoidCallback onLogout;

  const AdminDashboard({
    super.key,
    required this.repository,
    required this.onLogout,
  });

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  List<VehicleLog> _records = [];
  bool _loading = true;
  bool _offlineFallback = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _offlineFallback = false;
    });

    try {
      final service = CloudSyncService(repository: widget.repository);
      final records = await service.fetchAllFromCloud();
      if (mounted) {
        setState(() {
          _records = records;
          _loading = false;
        });
      }
    } catch (e) {
      // Fallback: show local SQLite records if cloud is unreachable
      try {
        final local = await widget.repository.allRecords();
        if (mounted) {
          setState(() {
            _records = local;
            _offlineFallback = true;
            _loading = false;
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _error = 'Cannot reach cloud or local storage: $e';
            _loading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _records.where((r) => r.isActive).length;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.admin_panel_settings_outlined, color: teal),
            SizedBox(width: 10),
            Flexible(
              child: Text(
                'Admin Dashboard',
                overflow: TextOverflow.ellipsis,
                style:
                    TextStyle(fontWeight: FontWeight.w800, fontSize: 22),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            tooltip: 'Refresh from cloud',
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: widget.onLogout,
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            children: [
              // === CLOUD STATUS CARD ===
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: ink,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.cloud_outlined,
                          color: Color(0xFF9CE5CD),
                          size: 18,
                        ),
                        SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'CLOUD DASHBOARD',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Color(0xFF9CE5CD),
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _loading ? '—' : '${_records.length}',
                                style: const TextStyle(
                                  color: Color(0xFFF4D57A),
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                  height: 1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'records in cloud',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _loading ? '—' : '$activeCount',
                                style: const TextStyle(
                                  color: Color(0xFF9CE5CD),
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                  height: 1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'currently inside',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              if (_offlineFallback) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.wifi_off,
                          color: Colors.orange.shade800, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Cloud unreachable. Showing cached local records.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade900,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Cloud Vehicle Records',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _loading ? null : _load,
                    child: const Text('Refresh'),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.red, size: 32),
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: ink, height: 1.5),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _load,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              else if (_records.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.inbox_outlined, color: teal, size: 28),
                      SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'No records in the cloud yet. The Guard must register and sync entries.',
                          style: TextStyle(color: ink, height: 1.5),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ..._records.map(_recordTile),
            ],
          ),
        ),
      ),
    );
  }

  Widget _recordTile(VehicleLog r) {
    final isActive = r.isActive;

    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor:
              isActive ? const Color(0xFFE4F1EC) : Colors.grey.shade200,
          foregroundColor: isActive ? teal : Colors.grey.shade700,
          child: Icon(
            isActive
                ? Icons.directions_car_outlined
                : Icons.check_circle_outline,
          ),
        ),
        title: Text(
          r.plateNumber,
          style: const TextStyle(
              fontWeight: FontWeight.w700, letterSpacing: 1),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${r.category} · ${formatTimestamp(r.entryTimestamp)}',
              style: const TextStyle(fontSize: 11),
            ),
            if (!isActive)
              Text(
                'Exit: ${formatTimestamp(r.exitTimestamp!)} · ${r.durationString}',
                style:
                    const TextStyle(fontSize: 11, color: Colors.grey),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFFE4F1EC)
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                isActive ? 'INSIDE' : 'EXITED',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: isActive ? teal : Colors.grey.shade700,
                ),
              ),
            ),
            const SizedBox(height: 4),
            const Icon(
              Icons.cloud_done,
              size: 14,
              color: Colors.green,
            ),
          ],
        ),
      ),
    );
  }
}