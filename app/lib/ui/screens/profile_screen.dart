import 'package:flutter/material.dart';

import '../../config/feature_flags.dart';
import '../../services/backend_client.dart';
import '../../services/local_store.dart';
import '../../services/model_manager.dart';
import '../../theme/tokens.dart';
import 'body_scan_screen.dart';
import 'consent_screen.dart';
import 'design_preview_screen.dart';
import 'diagnostics_screen.dart';
import 'fit_flow_preview_screen.dart';
import 'size_check_screen.dart';
import 'style_profile_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.modelManager,
    required this.consentStore,
    required this.styleStore,
    required this.backendClient,
    this.bodyStore,
    this.appearanceStore,
    this.sessionStorage = false,
  });

  final ModelManager modelManager;
  final ConsentStore consentStore;
  final StyleProfileStore styleStore;
  final BackendClient backendClient;
  final ScanRecordStore? bodyStore;
  final ScanRecordStore? appearanceStore;
  final bool sessionStorage;

  Future<void> _startBodyScan(BuildContext context) async {
    double? height;
    try {
      height = (await styleStore.load())?.heightCm;
    } catch (_) {
      // e.g. the web preview has no local file storage — say so, don't crash.
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Local storage is unavailable on this platform.',
            style: AppType.interface.copyWith(fontSize: 13),
          ),
        ),
      );
      return;
    }
    if (!context.mounted) return;
    if (height == null) {
      // A body scan without the user's real height would produce
      // uncalibrated numbers — ask for it first instead of guessing.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Enter your height in the style profile first.',
            style: AppType.interface.copyWith(fontSize: 13))),
      );
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => StyleProfileScreen(store: styleStore)),
      );
      return;
    }
    final resolvedHeight = height;
    await startScanFlow(
      context,
      consentStore: consentStore,
      scanScreen: (_) => BodyScanScreen(
        client: backendClient,
        heightCm: resolvedHeight,
        bodyStore: bodyStore,
        appearanceStore: appearanceStore,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.unit * 3),
        children: [
          Text(
            'Profile',
            style: AppType.display.copyWith(fontSize: 28, color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.unit),
          Text(
            'Accounts and sync are off. They arrive in later phases — '
            'until then, everything stays on this device.',
            style: AppType.interface.copyWith(
              fontSize: 15,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.unit * 3),
          _entry(
            context,
            title: 'Body scan',
            subtitle: 'Proportions and coloring from one photo',
            onTap: () => _startBodyScan(context),
          ),
          _entry(
            context,
            title: 'Style profile',
            subtitle: 'Height, fit, aesthetics, bans, budget',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => StyleProfileScreen(
                  store: styleStore,
                  sessionStorage: sessionStorage,
                ),
              ),
            ),
          ),
          _entry(
            context,
            title: 'Size check',
            subtitle: 'Match a real size chart to your real measurements',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SizeCheckScreen(
                  backendClient: backendClient,
                  bodyStore: bodyStore,
                  sessionStorage: sessionStorage,
                ),
              ),
            ),
          ),
          _entry(
            context,
            title: 'Diagnostics',
            subtitle: 'Developer — device, models, flags',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => DiagnosticsScreen(
                  modelManager: modelManager,
                  backendClient: backendClient,
                ),
              ),
            ),
          ),
          _entry(
            context,
            title: 'Design preview',
            subtitle: 'Developer — sample outfit card, labeled as such',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DesignPreviewScreen()),
            ),
          ),
          _entry(
            context,
            title: 'Fit flow preview',
            subtitle: 'Developer — gathering, chart states, trend slot (sample)',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const FitFlowPreviewScreen(),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.unit * 2),
          Text(
            '${AppInfo.name} ${AppInfo.version}',
            style: AppType.data.copyWith(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _entry(
    BuildContext context, {
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: AppSpacing.minTapTarget,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(
          title,
          style: AppType.interface.copyWith(color: AppColors.textPrimary),
        ),
        subtitle: Text(
          subtitle,
          style: AppType.interface.copyWith(fontSize: 12, color: AppColors.textSecondary),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        onTap: onTap,
      ),
    );
  }
}
