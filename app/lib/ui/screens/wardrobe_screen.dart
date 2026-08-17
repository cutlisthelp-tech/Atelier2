import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/analysis.dart';
import '../../models/recommendation.dart';
import '../../models/search.dart';
import '../../services/backend_client.dart';
import '../../services/local_store.dart';
import '../../theme/tokens.dart';
import '../widgets/atelier_button.dart';
import '../widgets/empty_state.dart';
import 'garment_scan_screen.dart';
import 'home_screen.dart';

/// WARDROBE — the full module (PRODUCT_SPEC §10): photograph or pick what
/// you own, read each piece honestly, and run "Best Outfit From My Closet"
/// through the same ranking brain as HOME — never a separate one.
class WardrobeScreen extends StatefulWidget {
  const WardrobeScreen({
    super.key,
    required this.backendClient,
    this.wardrobeStore,
    this.bodyStore,
    this.appearanceStore,
    this.styleStore,
    this.homePlaceStore,
    this.sessionStorage = false,
    this.onOpenTab,
  });

  final BackendClient backendClient;
  final WardrobeStore? wardrobeStore;
  final ScanRecordStore? bodyStore;
  final ScanRecordStore? appearanceStore;
  final StyleProfileStore? styleStore;
  final HomePlaceStore? homePlaceStore;
  final bool sessionStorage;
  final ValueChanged<int>? onOpenTab;

  @override
  State<WardrobeScreen> createState() => _WardrobeScreenState();
}

class _WardrobeScreenState extends State<WardrobeScreen> {
  static const _occasions = [
    'casual lunch', 'university', 'office', 'interview', 'wedding', 'date',
    'dinner', 'party', 'travel', 'beach', 'gym', 'shopping', 'formal',
  ];
  static const _tops = {'t-shirt', 'shirt', 'blouse', 'sweater', 'hoodie'};
  static const _bottoms = {'jeans', 'trousers', 'shorts', 'skirt'};
  static const _onePieces = {'dress', 'suit'};
  static const _shoes = {'shoes', 'sneakers', 'boots'};
  static const _filters = ['all', 'tops', 'bottoms', 'shoes', 'one-piece', 'other'];

  final ImagePicker _picker = ImagePicker();
  List<WardrobeItem>? _items;
  bool _storageUnavailable = false;
  bool _loading = true;
  String _filter = 'all';
  String _occasion = 'casual lunch';
  HomePlace? _place;
  ScanRecord? _body;
  ScanRecord? _appearance;
  StyleProfile? _style;
  bool _fetching = false;
  RecommendOutcome? _outcome;
  bool _searchBusy = false;
  SearchOutcome? _searchOutcome;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    List<Object?> results;
    try {
      results = await Future.wait([
        widget.wardrobeStore?.loadAll() ?? Future.value(<WardrobeItem>[]),
        widget.homePlaceStore?.load() ?? Future<HomePlace?>.value(null),
        widget.bodyStore?.load() ?? Future<ScanRecord?>.value(null),
        widget.appearanceStore?.load() ?? Future<ScanRecord?>.value(null),
        widget.styleStore?.load() ?? Future<StyleProfile?>.value(null),
      ]);
    } catch (_) {
      if (mounted) {
        setState(() {
          _storageUnavailable = true;
          _loading = false;
        });
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _items = results[0] as List<WardrobeItem>;
      _place = results[1] as HomePlace?;
      _body = results[2] as ScanRecord?;
      _appearance = results[3] as ScanRecord?;
      _style = results[4] as StyleProfile?;
      _loading = false;
    });
  }

  String _slot(String? category) {
    if (_tops.contains(category)) return 'tops';
    if (_bottoms.contains(category)) return 'bottoms';
    if (_onePieces.contains(category)) return 'one-piece';
    if (_shoes.contains(category)) return 'shoes';
    return 'other';
  }

  String? _category(WardrobeItem item) =>
      ((item.payload['garment'] as Map<String, dynamic>?)?['category']
              as Map<String, dynamic>?)?['value']
          as String?;

  bool get _canAssemble {
    final slots = _items!.map((i) => _slot(_category(i))).toSet();
    return (slots.contains('tops') && slots.contains('bottoms') ||
            slots.contains('one-piece')) &&
        slots.contains('shoes');
  }

  String get _gapHint {
    final slots = _items!.map((i) => _slot(_category(i))).toSet();
    final missing = <String>[];
    if (!slots.contains('shoes')) missing.add('shoes or sneakers');
    if (!(slots.contains('tops') && slots.contains('bottoms')) &&
        !slots.contains('one-piece')) {
      missing.add('a top and a bottom (or a dress)');
    }
    return 'Not enough photographed pieces for an outfit yet. Add '
        '${missing.join(' and ')}.';
  }

  List<Map<String, dynamic>> get _requestWardrobe => [
        for (final item in _items!)
          {
            'id': item.id,
            'garment': {
              for (final e
                  in (item.payload['garment'] as Map<String, dynamic>? ??
                          const <String, dynamic>{})
                      .entries)
                if (e.key != 'embedding') e.key: e.value,
            },
            'confidence': item.payload['confidence'],
            'flags': item.payload['flags'] ?? const <String>[],
          },
      ];

  Future<void> _addFrom(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 90,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final outcome = await widget.backendClient.analyzeGarment(bytes);
      if (!mounted) return;
      if (outcome is GarmentScanSuccess) {
        await widget.wardrobeStore?.add(outcome.payload);
        await _load();
      } else if (outcome is ScanFailure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${outcome.code} — ${outcome.message}',
              style: AppType.interface.copyWith(fontSize: 13),
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            source == ImageSource.camera
                ? 'No camera is available on this platform. Choose a file instead.'
                : 'Files can\u2019t be opened on this platform.',
            style: AppType.interface.copyWith(fontSize: 13),
          ),
        ),
      );
    }
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

  Future<void> _pickPlace() async {
    final picked = await showModalBottomSheet<HomePlace>(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      isScrollControlled: true,
      builder: (_) => const PlacePicker(),
    );
    if (picked != null) {
      await widget.homePlaceStore?.save(picked);
      if (mounted) setState(() => _place = picked);
    }
  }

  Future<void> _scoreCloset() async {
    final body = _body;
    final place = _place;
    if (body == null || place == null || _fetching) return;
    setState(() {
      _fetching = true;
      _outcome = null;
    });
    final outcome = await widget.backendClient.recommendOutfit(
      occasion: _occasion,
      latitude: place.latitude,
      longitude: place.longitude,
      placeLabel: place.label,
      bodyProfile: body.payload,
      colorProfile: _appearance?.payload,
      styleProfile: (_style ?? const StyleProfile()).toJson(),
      wardrobe: _requestWardrobe,
    );
    if (!mounted) return;
    setState(() {
      _fetching = false;
      _outcome = outcome;
    });
  }

  List<Map<String, dynamic>> get _indexCandidates => [
        for (final item in _items ?? const <WardrobeItem>[])
          if ((item.payload['garment'] as Map<String, dynamic>?)?['embedding']
              != null)
            {
              'id': item.id,
              'embedding':
                  (item.payload['garment'] as Map<String, dynamic>)['embedding'],
            },
      ];

  Future<void> _searchFrom(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 90,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() {
        _searchBusy = true;
        _searchOutcome = null;
      });
      final outcome = await widget.backendClient.searchSimilar(
        bytes,
        _indexCandidates,
      );
      if (!mounted) return;
      setState(() {
        _searchBusy = false;
        _searchOutcome = outcome;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _searchBusy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            source == ImageSource.camera
                ? 'No camera is available on this platform. Choose a file instead.'
                : 'Files can\u2019t be opened on this platform.',
            style: AppType.interface.copyWith(fontSize: 13),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    if (_storageUnavailable) {
      return const EmptyState(
        title: 'Local storage is unavailable here.',
        message:
            'This platform has no app data directory, so the wardrobe cannot '
            'be stored. Run Atelier on Android for the full flow.',
      );
    }
    final items = _items ?? <WardrobeItem>[];
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.unit * 3),
        children: [
          Text(
            'WARDROBE',
            style: AppType.caption.copyWith(
              fontSize: 10,
              letterSpacing: 2.4,
              color: AppColors.spotlightGold,
            ),
          ),
          const SizedBox(height: AppSpacing.unit),
          Text(
            'Wardrobe',
            style: AppType.displayXL.copyWith(
              fontSize: 38,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.half),
          Text(
            'Analysis data only — photos of your clothes never leave the '
            'capture flow and are never stored.',
            style: AppType.interface.copyWith(
              fontSize: 13,
              height: 1.5,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.unit * 2),
          if (widget.sessionStorage) const SessionNote(),
          Wrap(
            spacing: AppSpacing.unit,
            runSpacing: AppSpacing.unit,
            children: [
              AtelierButton(
                label: 'Camera',
                icon: Icons.photo_camera_outlined,
                fullWidth: false,
                onPressed: _openScanner,
              ),
              AtelierButton(
                label: 'Choose file',
                variant: AtelierButtonVariant.secondary,
                fullWidth: false,
                onPressed: () => _addFrom(ImageSource.gallery),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.unit * 2),
          if (items.isEmpty)
            GlassSurface(
              padding: const EdgeInsets.all(AppSpacing.unit * 3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your wardrobe starts here.',
                    style: AppType.headline.copyWith(
                      fontSize: 22,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.unit),
                  Text(
                    'Your wardrobe is empty. Photograph what you own and '
                    'Atelier reads each piece — category, colors, pattern, '
                    'fit, material.',
                    style: AppType.interface.copyWith(
                      fontSize: 14,
                      height: 1.55,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            )
          else ...[
            Wrap(
              spacing: AppSpacing.half,
              runSpacing: AppSpacing.half,
              children: [
                for (final f in _filters)
                  ChoiceChip(
                    label: Text(
                      f,
                      style: AppType.interface.copyWith(
                        fontSize: 12,
                        color: f == _filter
                            ? AppColors.surfacePrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    selected: f == _filter,
                    selectedColor: AppColors.textPrimary,
                    backgroundColor: AppColors.surfaceElevated,
                    side: BorderSide(color: AppColors.borderSubtle),
                    onSelected: (_) => setState(() => _filter = f),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.unit * 2),
            for (final item in items.where(
              (i) => _filter == 'all' || _slot(_category(i)) == _filter,
            ))
              _WardrobeCard(item: item, onRemove: _remove),
            const SizedBox(height: AppSpacing.unit * 3),
            Text(
              'Best outfit from my closet',
              style: AppType.display.copyWith(
                fontSize: 20,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.unit),
            if (_body == null)
              Text(
                'Run a body scan in Profile first — closet scoring is '
                'personal, never generic.',
                style: AppType.interface.copyWith(
                  fontSize: 13,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              )
            else if (!_canAssemble)
              Text(
                _gapHint,
                style: AppType.interface.copyWith(
                  fontSize: 13,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              )
            else ...[
              if (widget.sessionStorage) const SessionNote(),
              _placeRow(),
              const SizedBox(height: AppSpacing.unit * 2),
              Wrap(
                spacing: AppSpacing.half,
                runSpacing: AppSpacing.half,
                children: [
                  for (final o in _occasions)
                    ChoiceChip(
                      label: Text(
                        o,
                        style: AppType.interface.copyWith(
                          fontSize: 12,
                          color: o == _occasion
                              ? AppColors.surfacePrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      selected: o == _occasion,
                      selectedColor: AppColors.textPrimary,
                      backgroundColor: AppColors.surfaceElevated,
                      side: BorderSide(color: AppColors.borderSubtle),
                      onSelected: (_) => setState(() {
                        _occasion = o;
                        _outcome = null;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.unit * 2),
              SizedBox(
                height: AppSpacing.minTapTarget,
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.textPrimary,
                    foregroundColor: AppColors.surfacePrimary,
                  ),
                  onPressed: _fetching ? null : _scoreCloset,
                  child: Text(
                    _fetching ? 'Scoring…' : 'Score my closet',
                    style: AppType.interface.copyWith(fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.unit * 2),
              if (_outcome case RecommendSuccess(:final recommendation))
                ResultCard(
                  recommendation: recommendation,
                  onTryOn: () => widget.onOpenTab?.call(2),
                )
              else if (_outcome case RecommendFailure(:final code, :final message))
                _failure(code, message),
            ],
            const SizedBox(height: AppSpacing.unit * 3),
            Text(
              'Find this look',
              style: AppType.display.copyWith(
                fontSize: 20,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.unit),
            Text(
              'Show Atelier a screenshot or photo — it answers only from '
              'your real wardrobe index. Merchant search stays unconnected.',
              style: AppType.interface.copyWith(
                fontSize: 13,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.unit * 2),
            Wrap(
              spacing: AppSpacing.unit,
              runSpacing: AppSpacing.unit,
              children: [
                SizedBox(
                  height: AppSpacing.minTapTarget,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.borderSubtle),
                      foregroundColor: AppColors.textPrimary,
                    ),
                    onPressed: () => _searchFrom(ImageSource.camera),
                    child: Text(
                      'Camera',
                      style: AppType.interface.copyWith(fontSize: 14),
                    ),
                  ),
                ),
                SizedBox(
                  height: AppSpacing.minTapTarget,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.borderSubtle),
                      foregroundColor: AppColors.textPrimary,
                    ),
                    onPressed: () => _searchFrom(ImageSource.gallery),
                    child: Text(
                      'Choose file',
                      style: AppType.interface.copyWith(fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.unit * 2),
            if (_searchBusy)
              Text(
                'Searching the index…',
                style: AppType.data.copyWith(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            if (_searchOutcome case SearchOk(:final result))
              _searchResults(result)
            else if (_searchOutcome
                case SearchFailure(:final code, :final message))
              _failure(code, message),
          ],
        ],
      ),
    );
  }

  Widget _placeRow() {
    final place = _place;
    if (place == null) {
      return SizedBox(
        height: AppSpacing.minTapTarget,
        child: TextButton(
          onPressed: _pickPlace,
          child: Text(
            'Choose a place for real weather',
            style: AppType.interface.copyWith(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
    }
    return Row(
      children: [
        const Icon(
          Icons.location_on_outlined,
          size: 18,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: AppSpacing.unit),
        Expanded(
          child: Text(
            place.label.isEmpty
                ? '${place.latitude.toStringAsFixed(2)}, '
                      '${place.longitude.toStringAsFixed(2)}'
                : place.label,
            style: AppType.interface.copyWith(color: AppColors.textPrimary),
          ),
        ),
        SizedBox(
          height: AppSpacing.minTapTarget,
          child: TextButton(
            onPressed: _pickPlace,
            child: Text(
              'Change',
              style: AppType.interface.copyWith(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _tierLabel(String tier) => switch (tier) {
        'exact_match' => 'EXACT MATCH',
        'close_match' => 'CLOSE MATCH',
        _ => 'INSPIRED',
      };

  Widget _searchResults(SimilarSearchResult result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (result.state == 'NO_MATCH_FOUND')
          Text(
            result.message,
            style: AppType.interface.copyWith(
              fontSize: 14,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          )
        else
          for (final match in result.matches) _matchRow(match),
        const SizedBox(height: AppSpacing.unit),
        Text(
          result.catalogNote,
          style: AppType.data.copyWith(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          '${result.method} · index ${result.index}',
          style: AppType.data.copyWith(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _matchRow(SimilarMatch match) {
    final item = (_items ?? const <WardrobeItem>[])
        .where((i) => i.id == match.id)
        .toList();
    final category = item.isEmpty
        ? match.id
        : ((item.first.payload['garment'] as Map<String, dynamic>?)?['category']
                as Map<String, dynamic>?)?['value']
            as String? ??
            'Unidentified';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              category,
              style: AppType.interface.copyWith(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Text(
            '${_tierLabel(match.tier)} · ${(match.similarity * 100).round()}%',
            style: AppType.data.copyWith(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _failure(String code, String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.unit),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            code,
            style: AppType.data.copyWith(fontSize: 12, color: AppColors.error),
          ),
          const SizedBox(height: AppSpacing.half),
          Text(
            message,
            style: AppType.interface.copyWith(
              fontSize: 14,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _WardrobeCard extends StatelessWidget {
  const _WardrobeCard({required this.item, required this.onRemove});

  final WardrobeItem item;
  final Future<void> Function(WardrobeItem) onRemove;

  Map<String, dynamic> get _garment =>
      item.payload['garment'] as Map<String, dynamic>? ?? const {};

  String? get _category =>
      (_garment['category'] as Map<String, dynamic>?)?['value'] as String?;

  double get _confidence =>
      ((item.payload['confidence'] as num?) ?? 0).toDouble();

  List<Map<String, dynamic>> get _colors =>
      ((_garment['colors'] as List<dynamic>?) ?? const [])
          .cast<Map<String, dynamic>>();

  List<String> get _flags =>
      ((item.payload['flags'] as List<dynamic>?) ?? const []).cast<String>();

  Color _parseHex(String hex) {
    final value = int.tryParse(hex.replaceAll('#', ''), radix: 16);
    return value == null ? Colors.transparent : Color(0xFF000000 | value);
  }

  String _attr(String key) =>
      (_garment[key] as Map<String, dynamic>?)?['value'] as String? ??
      'Unknown';

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.unit),
      padding: const EdgeInsets.all(AppSpacing.unit * 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppSpacing.unit * 2),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _category ?? 'Unidentified',
                        style: AppType.interface.copyWith(
                          fontSize: 16,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      '${(_confidence * 100).round()}%',
                      style: AppType.data.copyWith(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.half),
                Text(
                  'fit ${_attr('fit')} · pattern ${_attr('pattern')} · '
                  'material ${_attr('material')}',
                  style: AppType.data.copyWith(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.unit),
                Wrap(
                  spacing: AppSpacing.unit,
                  children: [
                    for (final c in _colors.take(4))
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: _parseHex(c['hex'] as String? ?? ''),
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.borderSubtle),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.half),
                          Text(
                            c['name'] as String? ?? '',
                            style: AppType.interface.copyWith(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                if (_flags.contains('LOW_CONFIDENCE')) ...[
                  const SizedBox(height: AppSpacing.half),
                  Text(
                    'LOW CONFIDENCE',
                    style: AppType.data.copyWith(
                      fontSize: 10,
                      color: AppColors.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: () => onRemove(item),
            icon: const Icon(
              Icons.delete_outline,
              color: AppColors.textSecondary,
            ),
            tooltip: 'Remove from wardrobe',
          ),
        ],
      ),
    );
  }
}
