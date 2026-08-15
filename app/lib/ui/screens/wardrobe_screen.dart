import 'package:flutter/material.dart';

import '../../services/backend_client.dart';
import '../../services/local_store.dart';
import '../../theme/tokens.dart';
import '../widgets/empty_state.dart';
import 'garment_scan_screen.dart';

/// Phase 3 borrows minimal wardrobe persistence: each saved item is the
/// garment analysis JSON only — user captures are never written to disk
/// (BUILD_PLAN §5). Phase 7 owns the full Wardrobe module.
class WardrobeScreen extends StatefulWidget {
  const WardrobeScreen({
    super.key,
    required this.backendClient,
    this.wardrobeStore,
  });

  final BackendClient backendClient;
  final WardrobeStore? wardrobeStore;

  @override
  State<WardrobeScreen> createState() => _WardrobeScreenState();
}

class _WardrobeScreenState extends State<WardrobeScreen> {
  List<WardrobeItem>? _items;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await widget.wardrobeStore?.loadAll() ?? <WardrobeItem>[];
    if (mounted) setState(() => _items = items);
  }

  Future<void> _openScanner() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GarmentScanScreen(
          client: widget.backendClient,
          wardrobeStore: widget.wardrobeStore,
        ),
      ),
    );
    await _load();
  }

  Future<void> _remove(WardrobeItem item) async {
    await widget.wardrobeStore?.remove(item.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    if (items == null) {
      return const SizedBox.shrink();
    }
    if (items.isEmpty) {
      return EmptyState(
        title: 'Your wardrobe is empty.',
        message:
            'Photograph what you own and Atelier reads each piece — category, '
            'colors, pattern, fit, material. Saved pieces power the HOME '
            'outfit recommendation.',
        actionLabel: 'Photograph a garment',
        onAction: _openScanner,
      );
    }
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.unit * 3),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Wardrobe',
                  style: AppType.display.copyWith(
                      fontSize: 28, color: AppColors.textPrimary),
                ),
              ),
              SizedBox(
                height: AppSpacing.minTapTarget,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.textPrimary,
                    foregroundColor: AppColors.surfacePrimary,
                  ),
                  onPressed: _openScanner,
                  icon: const Icon(Icons.photo_camera_outlined, size: 18),
                  label: Text(
                    'Add',
                    style: AppType.interface.copyWith(fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.unit),
          Text(
            'Analysis data only — photos of your clothes never leave the '
            'capture flow and are never stored.',
            style: AppType.interface.copyWith(
              fontSize: 13,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.unit * 2),
          for (final item in items) _WardrobeRow(item: item, onRemove: _remove),
        ],
      ),
    );
  }
}

class _WardrobeRow extends StatelessWidget {
  const _WardrobeRow({required this.item, required this.onRemove});

  final WardrobeItem item;
  final Future<void> Function(WardrobeItem) onRemove;

  Map<String, dynamic> get _garment =>
      item.payload['garment'] as Map<String, dynamic>? ?? const {};

  String get _category =>
      (_garment['category'] as Map<String, dynamic>?)?['value'] as String? ??
      'Unidentified';

  double get _confidence =>
      ((item.payload['confidence'] as num?) ?? 0).toDouble();

  List<Map<String, dynamic>> get _colors =>
      ((_garment['colors'] as List<dynamic>?) ?? const [])
          .cast<Map<String, dynamic>>();

  Color _parseHex(String hex) {
    final value = int.tryParse(hex.replaceAll('#', ''), radix: 16);
    return value == null ? Colors.transparent : Color(0xFF000000 | value);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.unit),
      child: Row(
        children: [
          if (_colors.isNotEmpty)
            for (final c in _colors.take(4))
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.unit),
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: _parseHex(c['hex'] as String? ?? ''),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                ),
              ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _category,
                  style: AppType.interface.copyWith(
                      color: AppColors.textPrimary),
                ),
                Text(
                  '${(_confidence * 100).round()}% confident',
                  style: AppType.data.copyWith(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => onRemove(item),
            icon: const Icon(Icons.delete_outline,
                color: AppColors.textSecondary),
            tooltip: 'Remove from wardrobe',
          ),
        ],
      ),
    );
  }
}
