import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// Honest empty state — an invitation to act, never a dead end and never
/// a fake placeholder (docs/DESIGN_SYSTEM.md §6).
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.unit * 3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppType.display.copyWith(
                fontSize: 24,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.unit * 2),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppType.interface.copyWith(
                fontSize: 15,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
