import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/app_sidebar.dart';

class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  final Dio _dio = Dio(BaseOptions(baseUrl: 'https://lms2.yuktaa.com/api/v2'));
  bool _isLoading = true;
  Map<String, dynamic>? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchDiagnostics();
  }

  Future<void> _fetchDiagnostics() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final response = await _dio.get(
        '/admin/diagnostics',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (mounted) {
        setState(() {
          _data = response.data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load diagnostics: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      appBar: isDesktop ? null : AppBar(title: const Text('System Diagnostics')),
      drawer: isDesktop ? null : const AppSidebar(role: 'admin'),
      body: Row(
        children: [
          if (isDesktop)
            const SizedBox(
              width: 250,
              child: AppSidebar(role: 'admin'),
            ),
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchDiagnostics,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final db = _data?['database'] ?? {};
    final sys = _data?['system'] ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'System Health Diagnostics',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          const Text(
            'Real-time status of Oracle database and application server.',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          
          // Database diagnostics card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.dns, color: Colors.blue, size: 28),
                      const SizedBox(width: 12),
                      const Text(
                        'Oracle ADB Connection Pool',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      Chip(
                        label: Text(
                          db['status'] == 'connected' ? 'CONNECTED' : 'DISCONNECTED',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        backgroundColor: db['status'] == 'connected' ? Colors.green : Colors.red,
                      )
                    ],
                  ),
                  const Divider(height: 32),
                  _buildMetricRow('Opened Connections', '${db['opened_connections'] ?? 0}'),
                  const SizedBox(height: 12),
                  _buildMetricRow('Busy Connections', '${db['busy_connections'] ?? 0}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Server diagnostics card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.monitor, color: Colors.orange, size: 28),
                      SizedBox(width: 12),
                      Text(
                        'Application Server Performance',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  _buildMetricRow('CPU Usage', '${sys['cpu_usage_percent'] ?? 0}%'),
                  const SizedBox(height: 12),
                  _buildMetricRow('Memory Usage', '${sys['memory_usage_percent'] ?? 0}%'),
                  const SizedBox(height: 12),
                  _buildMetricRow('Memory Available', '${sys['memory_available_mb'] ?? 0} MB'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 16, color: Colors.grey)),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
      ],
    );
  }
}
