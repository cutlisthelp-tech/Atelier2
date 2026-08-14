import 'package:flutter/material.dart';

import '../../services/local_store.dart';
import '../../theme/tokens.dart';

/// Explicit biometric opt-in before the first scan (BUILD_PLAN §5).
/// Plain language, no dark patterns, and the scan entry stays blocked
/// until consent is granted.
class ConsentScreen extends StatelessWidget {
  const ConsentScreen({super.key, required this.consentStore});

  final ConsentStore consentStore;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.unit * 3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.unit * 2),
              Text(
                'Before your first scan',
                style: AppType.display.copyWith(
                  fontSize: 28,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.unit * 3),
              _clause(
                'Your photo is sent to the Atelier analysis service to read '
                'body proportions and coloring. It is processed in memory, '
                'never stored, never logged.',
              ),
              _clause(
                'Measurements come from real landmark detection with a shown '
                'confidence value — never from guesswork.',
              ),
              _clause(
                'You can stop at any time. Nothing about your body leaves '
                'this flow without this consent.',
              ),
              const Spacer(),
              SizedBox(
                height: AppSpacing.minTapTarget,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.textPrimary,
                    foregroundColor: AppColors.surfacePrimary,
                  ),
                  onPressed: () async {
                    await consentStore.grant();
                    if (context.mounted) Navigator.of(context).pop(true);
                  },
                  child: Text(
                    'I understand — enable scanning',
                    style: AppType.interface.copyWith(fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.unit),
              SizedBox(
                height: AppSpacing.minTapTarget,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(
                    'Not now',
                    style: AppType.interface.copyWith(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _clause(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.unit * 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.unit * 1.5),
          Expanded(
            child: Text(
              text,
              style: AppType.interface.copyWith(
                fontSize: 15,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Entry point shared by every scan surface: consent first, scan second.
Future<void> startScanFlow(
  BuildContext context, {
  required ConsentStore consentStore,
  required Widget Function(BuildContext) scanScreen,
}) async {
  final alreadyGranted = await consentStore.isGranted;
  if (!context.mounted) return;
  if (!alreadyGranted) {
    final granted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ConsentScreen(consentStore: consentStore),
      ),
    );
    if (granted != true || !context.mounted) return;
  }
  await Navigator.of(context).push(MaterialPageRoute(builder: scanScreen));
}
