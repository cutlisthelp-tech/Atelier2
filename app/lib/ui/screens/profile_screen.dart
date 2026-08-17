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
import 'fit_flow_screen.dart';
import 'size_check_screen.dart';
import 'style_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.modelManager,
    required this.consentStore,
    required this.styleStore,
    required this.backendClient,
    this.bodyStore,
    this.appearanceStore,
    this.wardrobeStore,
    this.sessionStorage = false,
    this.onOpenTab,
  });

  final ModelManager modelManager;
  final ConsentStore consentStore;
  final StyleProfileStore styleStore;
  final BackendClient backendClient;
  final ScanRecordStore? bodyStore;
  final ScanRecordStore? appearanceStore;
  final WardrobeStore? wardrobeStore;
  final bool sessionStorage;
  final ValueChanged<int>? onOpenTab;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  ScanRecord? _body;
  ScanRecord? _appearance;
  StyleProfile? _style;
  int _wardrobeCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait<Object?>([
        widget.bodyStore?.load() ?? Future<ScanRecord?>.value(null),
        widget.appearanceStore?.load() ?? Future<ScanRecord?>.value(null),
        widget.styleStore.load(),
        widget.wardrobeStore?.loadAll() ??
            Future<List<WardrobeItem>>.value(const []),
      ]);
      if (!mounted) return;
      setState(() {
        _body = results[0] as ScanRecord?;
        _appearance = results[1] as ScanRecord?;
        _style = results[2] as StyleProfile?;
        _wardrobeCount = (results[3] as List<WardrobeItem>?)?.length ?? 0;
      });
    } catch (_) {
      if (mounted) setState(() {});
    }
  }

  /// Profile completeness from real stores only — never decorated.
  int get _done => [
        _body != null,
        _appearance != null,
        _style?.heightCm != null,
        _body != null, // fit engine input
        _style?.heightCm != null, // size calibration
        _wardrobeCount > 0,
      ].where((b) => b).length;

  Future<void> _startBodyScan(BuildContext context) async {
    double? height;
    try {
      height = (await widget.styleStore.load())?.heightCm;
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
        MaterialPageRoute(builder: (_) => StyleProfileScreen(store: widget.styleStore)),
      );
      return;
    }
    final resolvedHeight = height;
    await startScanFlow(
      context,
      consentStore: widget.consentStore,
      scanScreen: (_) => BodyScanScreen(
        client: widget.backendClient,
        heightCm: resolvedHeight,
        bodyStore: widget.bodyStore,
        appearanceStore: widget.appearanceStore,
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.unit * 3),
        children: [
          _header(),
          const SizedBox(height: AppSpacing.unit * 3),
          _grid(),
          const SizedBox(height: AppSpacing.unit * 3),
          Text(
            'Accounts and sync are off. They arrive in later phases — '
            'until then, everything stays on this device.',
            style: AppType.interface.copyWith(
              fontSize: 13,
              height: 1.5,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.unit * 2),
          _devEntry(
            'Diagnostics',
            'Developer — device, models, flags',
            () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => DiagnosticsScreen(
                  modelManager: widget.modelManager,
                  backendClient: widget.backendClient,
                ),
              ),
            ),
          ),
          _devEntry(
            'Design preview',
            'Developer — sample outfit card, labeled as such',
            () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DesignPreviewScreen()),
            ),
          ),
          const SizedBox(height: AppSpacing.unit * 2),
          Text(
            '${AppInfo.name} ${AppInfo.version}',
            style: AppType.data.copyWith(fontSize: 11, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.goldHairline),
            gradient: RadialGradient(
              colors: [
                AppColors.graphite.withValues(alpha: 0.9),
                AppColors.inkDeep.withValues(alpha: 0.9),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.inkDeep.withValues(alpha: 0.5),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.person_outline,
            color: AppColors.spotlightGold,
            size: 28,
          ),
        ),
        const SizedBox(width: AppSpacing.unit * 2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'YOUR FASHION PROFILE',
                style: AppType.caption.copyWith(
                  fontSize: 10,
                  letterSpacing: 2.4,
                  color: AppColors.spotlightGold,
                ),
              ),
              const SizedBox(height: AppSpacing.half),
              Text(
                'Built from you.',
                style: AppType.headline.copyWith(
                  fontSize: 26,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                'Real scans and real choices — never guessed.',
                style: AppType.interface.copyWith(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${_done.toString().padLeft(2, '0')} / 06',
              style: AppType.display.copyWith(
                fontSize: 30,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              'COMPLETE',
              style: AppType.caption.copyWith(
                fontSize: 9,
                letterSpacing: 2,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _grid() {
    final tiles = [
      _Tile(
        icon: Icons.accessibility_new_outlined,
        title: 'BODY',
        action: 'Body scan',
        status: _body == null ? 'not scanned' : 'real proportions',
        done: _body != null,
        onTap: () => _startBodyScan(context),
      ),
      _Tile(
        icon: Icons.face_outlined,
        title: 'APPEARANCE',
        action: 'Appearance read',
        status: _appearance == null ? 'awaiting scan' : 'coloring read',
        done: _appearance != null,
        onTap: () => _startBodyScan(context),
      ),
      _Tile(
        icon: Icons.tune_outlined,
        title: 'STYLE',
        action: 'Style profile',
        status: _style?.heightCm == null
            ? 'not set'
            : 'height ${_style!.heightCm!.toStringAsFixed(0)} cm',
        done: _style?.heightCm != null,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => StyleProfileScreen(
              store: widget.styleStore,
              sessionStorage: widget.sessionStorage,
            ),
          ),
        ),
      ),
      _Tile(
        icon: Icons.straighten_outlined,
        title: 'FIT',
        action: 'Fit check',
        status: _body == null ? 'needs scan' : 'engine ready',
        done: _body != null,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => FitFlowScreen(
              backendClient: widget.backendClient,
              bodyStore: widget.bodyStore,
              sessionStorage: widget.sessionStorage,
              onStartScan: () => _startBodyScan(context),
            ),
          ),
        ),
      ),
      _Tile(
        icon: Icons.format_size_outlined,
        title: 'SIZE',
        action: 'Size check',
        status: _style?.heightCm == null ? 'needs height' : 'calibrated',
        done: _style?.heightCm != null,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SizeCheckScreen(
              backendClient: widget.backendClient,
              bodyStore: widget.bodyStore,
              sessionStorage: widget.sessionStorage,
            ),
          ),
        ),
      ),
      _Tile(
        icon: Icons.checkroom_outlined,
        title: 'WARDROBE',
        action: 'Wardrobe',
        status: _wardrobeCount == 0
            ? 'empty'
            : '$_wardrobeCount ${_wardrobeCount == 1 ? 'piece' : 'pieces'}',
        done: _wardrobeCount > 0,
        onTap: () => widget.onOpenTab?.call(3),
      ),
    ];
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: AppSpacing.unit,
      crossAxisSpacing: AppSpacing.unit,
      childAspectRatio: 1.45,
      children: tiles,
    );
  }

  Widget _devEntry(String title, String subtitle, VoidCallback onTap) {
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
          style: AppType.interface.copyWith(fontSize: 12, color: AppColors.textTertiary),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textTertiary),
        onTap: onTap,
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.action,
    required this.status,
    required this.done,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String action;
  final String status;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      padding: const EdgeInsets.all(AppSpacing.unit * 1.5),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          onTap: onTap,
          splashColor: AppColors.spotlightGold.withValues(alpha: 0.07),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.half),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      icon,
                      size: 16,
                      color: done
                          ? AppColors.spotlightGold
                          : AppColors.textTertiary,
                    ),
                    const SizedBox(width: AppSpacing.half),
                    Expanded(
                      child: Text(
                        title,
                        style: AppType.caption.copyWith(
                          fontSize: 9.5,
                          letterSpacing: 2,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: done
                            ? AppColors.spotlightGold
                            : AppColors.fog.withValues(alpha: 0.2),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.data.copyWith(
                    fontSize: 11,
                    color: done
                        ? AppColors.textPrimary
                        : AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  action,
                  style: AppType.interface.copyWith(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
