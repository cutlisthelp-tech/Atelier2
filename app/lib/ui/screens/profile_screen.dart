import 'package:flutter/material.dart';

import '../../config/feature_flags.dart';
import '../../services/model_manager.dart';
import '../../theme/tokens.dart';
import 'diagnostics_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.modelManager});

  final ModelManager modelManager;

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
          SizedBox(
            height: AppSpacing.minTapTarget,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Diagnostics',
                style: AppType.interface.copyWith(color: AppColors.textPrimary),
              ),
              subtitle: Text(
                'Developer — device, models, flags',
                style: AppType.interface
                    .copyWith(fontSize: 12, color: AppColors.textSecondary),
              ),
              trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DiagnosticsScreen(modelManager: modelManager),
                ),
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
}
