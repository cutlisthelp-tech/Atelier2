import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../config/feature_flags.dart';
import '../../services/backend_client.dart';
import '../../services/model_manager.dart';
import '../../theme/tokens.dart';

/// Developer/QA screen — docs/DESIGN_SYSTEM.md §5.
/// Every value is real; anything unavailable is stated plainly.
class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key, required this.modelManager, this.backendClient});

  final ModelManager modelManager;
  final BackendClient? backendClient;

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  static const _backendUrl = String.fromEnvironment('BACKEND_URL');

  Map<String, String> _device = const {};
  String _backend = 'Checking…';
  Map<String, String> _backendModels = const {};

  @override
  void initState() {
    super.initState();
    _loadDevice();
    _probeBackend();
    _probeBackendModels();
  }

  Future<void> _loadDevice() async {
    final plugin = DeviceInfoPlugin();
    final rows = <String, String>{};
    if (Platform.isAndroid) {
      final info = await plugin.androidInfo;
      rows['Device'] = '${info.manufacturer} ${info.model}';
      rows['OS'] = 'Android ${info.version.release} (SDK ${info.version.sdkInt})';
      rows['RAM'] = '${info.physicalRamSize} MB';
      rows['ABIs'] = info.supportedAbis.join(', ');
    } else {
      rows['Device'] = Platform.operatingSystem;
      rows['OS'] = Platform.operatingSystemVersion;
    }
    if (mounted) setState(() => _device = rows);
  }

  Future<void> _probeBackend() async {
    if (_backendUrl.isEmpty) {
      if (mounted) setState(() => _backend = 'Backend URL not configured.');
      return;
    }
    try {
      final resp = await http
          .get(Uri.parse('$_backendUrl/health'))
          .timeout(const Duration(seconds: 3));
      if (mounted) {
        setState(() => _backend = 'HTTP ${resp.statusCode} — ${resp.body}');
      }
    } catch (e) {
      if (mounted) setState(() => _backend = 'Unreachable: $e');
    }
  }

  Future<void> _probeBackendModels() async {
    final client = widget.backendClient;
    if (client == null) {
      if (mounted) {
        setState(() => _backendModels = const {'Status': 'No backend client.'});
      }
      return;
    }
    if (!client.isConfigured) {
      if (mounted) {
        setState(() =>
            _backendModels = const {'Status': 'Backend URL not configured.'});
      }
      return;
    }
    try {
      final models = await client.fetchModels();
      if (mounted) {
        setState(() => _backendModels = {
              for (final m in models)
                m.name: m.installed
                    ? 'installed${m.loaded ? ' · loaded' : ''}'
                    : 'missing',
            });
      }
    } catch (e) {
      if (mounted) setState(() => _backendModels = {'Status': 'Unreachable: $e'});
    }
  }

  @override
  Widget build(BuildContext context) {
    final manager = widget.modelManager;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.surfacePrimary,
        title: Text('Diagnostics', style: AppType.interface),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.unit * 3),
        children: [
          _Section(title: 'Device', rows: _device),
          _Section(
            title: 'Models',
            rows: manager.hasModels
                ? {
                    for (final s in manager.report())
                      s.entry.name: s.state.name.toUpperCase(),
                  }
                : const {'Status': 'No models registered.'},
          ),
          _Section(
            title: 'Feature flags',
            rows: {for (final e in FeatureFlags.all.entries) e.key: '${e.value}'},
          ),
          _Section(title: 'Backend', rows: {'Health': _backend}),
          _Section(title: 'Backend models', rows: _backendModels),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.rows});

  final String title;
  final Map<String, String> rows;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.unit * 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppType.interface.copyWith(
              fontSize: 13,
              letterSpacing: 1.2,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.unit),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            padding: const EdgeInsets.all(AppSpacing.unit * 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final row in rows.entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.half),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            row.key,
                            style: AppType.interface
                                .copyWith(color: AppColors.textSecondary),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            row.value,
                            textAlign: TextAlign.end,
                            style: AppType.data.copyWith(
                              fontSize: 12,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
