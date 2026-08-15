import 'package:flutter/material.dart';

import '../../models/recommendation.dart';
import '../../services/backend_client.dart';
import '../../services/local_store.dart';
import '../../theme/tokens.dart';

/// HOME — "Your Best Look" (DESIGN_SYSTEM §5). Real profiles + real wardrobe
/// + real weather go to the backend; everything rendered comes from the
/// response, never from placeholder values.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.backendClient,
    required this.bodyStore,
    required this.appearanceStore,
    required this.styleStore,
    required this.wardrobeStore,
    required this.homePlaceStore,
    this.onOpenTab,
  });

  final BackendClient backendClient;
  final ScanRecordStore bodyStore;
  final ScanRecordStore appearanceStore;
  final StyleProfileStore styleStore;
  final WardrobeStore wardrobeStore;
  final HomePlaceStore homePlaceStore;
  final ValueChanged<int>? onOpenTab;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _occasions = [
    'casual lunch',
    'university',
    'office',
    'interview',
    'wedding',
    'date',
    'dinner',
    'party',
    'travel',
    'beach',
    'gym',
    'shopping',
    'formal',
  ];
  static const _tops = {'t-shirt', 'shirt', 'blouse', 'sweater', 'hoodie'};
  static const _bottoms = {'jeans', 'trousers', 'shorts', 'skirt'};
  static const _onePieces = {'dress', 'suit'};
  static const _shoes = {'shoes', 'sneakers', 'boots'};

  bool _loading = true;
  bool _storageUnavailable = false;
  ScanRecord? _body;
  ScanRecord? _appearance;
  List<WardrobeItem> _wardrobe = [];
  HomePlace? _place;
  StyleProfile? _style;
  String _occasion = 'casual lunch';
  bool _fetching = false;
  RecommendOutcome? _outcome;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    List<Object?> results;
    try {
      results = await Future.wait([
        widget.bodyStore.load(),
        widget.appearanceStore.load(),
        widget.wardrobeStore.loadAll(),
        widget.homePlaceStore.load(),
        widget.styleStore.load(),
      ]);
    } catch (_) {
      // e.g. the web preview has no local file storage — say so, don't crash.
      if (mounted) {
        setState(() {
          _loading = false;
          _storageUnavailable = true;
        });
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _body = results[0] as ScanRecord?;
      _appearance = results[1] as ScanRecord?;
      _wardrobe = results[2] as List<WardrobeItem>;
      _place = results[3] as HomePlace?;
      _style = results[4] as StyleProfile?;
      _loading = false;
    });
  }

  Set<String> get _categories => _wardrobe
      .map(
        (i) =>
            ((i.payload['garment'] as Map<String, dynamic>?)?['category']
                    as Map<String, dynamic>?)?['value']
                as String?,
      )
      .nonNulls
      .toSet();

  bool get _canAssemble {
    final c = _categories;
    final separated =
        c.intersection(_tops).isNotEmpty &&
        c.intersection(_bottoms).isNotEmpty &&
        c.intersection(_shoes).isNotEmpty;
    final onePiece =
        c.intersection(_onePieces).isNotEmpty &&
        c.intersection(_shoes).isNotEmpty;
    return separated || onePiece;
  }

  List<Map<String, dynamic>> get _requestWardrobe => [
    for (final item in _wardrobe)
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

  Future<void> _pickPlace() async {
    final picked = await showModalBottomSheet<HomePlace>(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      isScrollControlled: true,
      builder: (_) => const _PlacePicker(),
    );
    if (picked != null) {
      await widget.homePlaceStore.save(picked);
      if (mounted) setState(() => _place = picked);
    }
  }

  Future<void> _recommend() async {
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

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.unit * 3),
        children: [
          Text(
            'Your Best Look',
            style: AppType.display.copyWith(
              fontSize: 28,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.unit * 2),
          if (_storageUnavailable)
            _prerequisite(
              'Local storage is unavailable here.',
              'This platform has no app data directory, so profiles and the '
                  'wardrobe can\u2019t be stored. Run Atelier on Android for '
                  'the full flow.',
              '',
              () {},
            )
          else if (_body == null)
            _prerequisite(
              'Atelier hasn\u2019t met you yet.',
              'Run a body scan in Profile — proportions and coloring come '
                  'from one real photo.',
              'Open Profile',
              () => widget.onOpenTab?.call(4),
            )
          else if (!_canAssemble)
            _prerequisite(
              'Your wardrobe can\u2019t form an outfit yet.',
              'Photograph a top, a bottom, and shoes (or a dress and shoes) '
                  'in the Wardrobe tab.',
              'Open Wardrobe',
              () => widget.onOpenTab?.call(3),
            )
          else if (_place == null)
            _prerequisite(
              'Where should the outfit work?',
              'Pick your city so real local weather can score the pieces.',
              'Choose a place',
              _pickPlace,
            )
          else ...[
            _placeRow(),
            const SizedBox(height: AppSpacing.unit * 2),
            Wrap(
              spacing: AppSpacing.unit,
              runSpacing: AppSpacing.unit,
              children: [
                for (final o in _occasions)
                  ChoiceChip(
                    label: Text(
                      o,
                      style: AppType.interface.copyWith(
                        fontSize: 13,
                        color: o == _occasion
                            ? AppColors.surfacePrimary
                            : AppColors.textSecondary,
                      ),
                    ),
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
            const SizedBox(height: AppSpacing.unit * 3),
            if (_fetching)
              const _SkeletonCard()
            else ...[
              SizedBox(
                height: AppSpacing.minTapTarget,
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accentSignature,
                    foregroundColor: AppColors.surfacePrimary,
                  ),
                  onPressed: _recommend,
                  child: Text(
                    'Score my best outfit',
                    style: AppType.interface.copyWith(fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.unit * 2),
              if (_outcome case RecommendSuccess(:final recommendation))
                ResultCard(recommendation: recommendation)
              else if (_outcome case RecommendFailure(
                :final code,
                :final message,
              ))
                _failure(code, message),
            ],
          ],
        ],
      ),
    );
  }

  Widget _prerequisite(
    String title,
    String message,
    String actionLabel,
    VoidCallback onAction,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.unit * 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppType.display.copyWith(
              fontSize: 20,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.unit),
          Text(
            message,
            style: AppType.interface.copyWith(
              fontSize: 15,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.unit * 2),
          if (actionLabel.isNotEmpty)
            SizedBox(
              height: AppSpacing.minTapTarget,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.textPrimary,
                  foregroundColor: AppColors.surfacePrimary,
                ),
                onPressed: onAction,
                child: Text(
                  actionLabel,
                  style: AppType.interface.copyWith(fontSize: 15),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _placeRow() {
    final place = _place!;
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
        TextButton(
          onPressed: _pickPlace,
          child: Text(
            'Change',
            style: AppType.interface.copyWith(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
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

/// Glass is reserved for primary surfaces (DESIGN_SYSTEM §1) — the Best
/// Outfit card is one of them.
class ResultCard extends StatelessWidget {
  const ResultCard({super.key, required this.recommendation});

  final OutfitRecommendation recommendation;

  String get _contextLine {
    final w = recommendation.weather;
    final weather = w.state == 'ok'
        ? '${w.temperatureC?.toStringAsFixed(1)}\u00B0C '
              '${w.weatherLabel ?? ''}'
        : 'Weather unreachable \u2014 scored without it';
    final place = recommendation.placeLabel.isEmpty
        ? ''
        : ' \u00B7 ${recommendation.placeLabel}';
    return '${recommendation.occasion}$place \u00B7 $weather';
  }

  @override
  Widget build(BuildContext context) {
    final best = recommendation.outfits.first;
    final alternatives = recommendation.outfits.skip(1).toList();
    return GlassSurface(
      borderRadius: BorderRadius.circular(AppSpacing.unit * 2),
      padding: const EdgeInsets.all(AppSpacing.unit * 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ScoreRing(score: best.score),
              const SizedBox(width: AppSpacing.unit * 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Personal Match',
                      style: AppType.display.copyWith(
                        fontSize: 20,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.half),
                    Text(
                      _contextLine,
                      style: AppType.interface.copyWith(
                        fontSize: 13,
                        height: 1.4,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.unit * 2),
          for (final g in best.garments) _PieceRow(garment: g),
          const SizedBox(height: AppSpacing.unit),
          Material(
            type: MaterialType.transparency,
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: AppSpacing.unit),
              title: Text(
                'Why it works',
                style: AppType.interface.copyWith(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
              children: [
                for (final line in best.why)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.half),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '\u2022 ',
                          style: AppType.interface.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            line,
                            style: AppType.interface.copyWith(
                              fontSize: 13,
                              height: 1.4,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (alternatives.isNotEmpty) ...[
            Text(
              'Alternatives',
              style: AppType.interface.copyWith(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.unit),
            SizedBox(
              height: 64,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: alternatives.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: AppSpacing.unit),
                itemBuilder: (_, i) =>
                    _AlternativeTile(outfit: alternatives[i]),
              ),
            ),
            const SizedBox(height: AppSpacing.unit),
          ],
          Material(
            type: MaterialType.transparency,
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(
                'How the score is built',
                style: AppType.interface.copyWith(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
              children: [
                for (final f in recommendation.factors)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.half),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            f.name.replaceAll('_', ' '),
                            style: AppType.interface.copyWith(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        Text(
                          f.active
                              ? '${f.contribution.toStringAsFixed(1)} '
                                    '/ ${f.effectiveWeight.toStringAsFixed(0)}'
                              : 'inactive \u2014 ${f.inactiveReason ?? ''}',
                          style: AppType.data.copyWith(
                            fontSize: 12,
                            color: f.active
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.unit),
          Row(
            children: [
              Expanded(
                child: _actionButton(
                  'TRY ON',
                  () =>
                      _showNote(context, 'Try-on arrives next \u2014 Phase 4.'),
                ),
              ),
              const SizedBox(width: AppSpacing.unit),
              Expanded(
                child: _actionButton(
                  'SHOP THIS LOOK',
                  () => _showNote(
                    context,
                    '${recommendation.shoppingState}\n'
                    '${recommendation.shoppingMessage}',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionButton(String label, VoidCallback onTap) {
    return SizedBox(
      height: AppSpacing.minTapTarget,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: AppColors.borderSubtle),
          foregroundColor: AppColors.textPrimary,
        ),
        onPressed: onTap,
        child: Text(
          label,
          style: AppType.interface.copyWith(fontSize: 12, letterSpacing: 1.2),
        ),
      ),
    );
  }

  void _showNote(BuildContext context, String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, style: AppType.interface.copyWith(fontSize: 13)),
      ),
    );
  }
}

class _PieceRow extends StatelessWidget {
  const _PieceRow({required this.garment});

  final GarmentRef garment;

  Color _parseHex(String hex) {
    final value = int.tryParse(hex.replaceAll('#', ''), radix: 16);
    return value == null ? Colors.transparent : Color(0xFF000000 | value);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.half),
      child: Row(
        children: [
          for (final c in garment.colors.take(3))
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.half),
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: _parseHex(c.hex),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.borderSubtle),
                ),
              ),
            ),
          const SizedBox(width: AppSpacing.half),
          Expanded(
            child: Text(
              garment.category,
              style: AppType.interface.copyWith(color: AppColors.textPrimary),
            ),
          ),
          if (garment.fit != null)
            Text(
              garment.fit!,
              style: AppType.data.copyWith(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}

class _AlternativeTile extends StatelessWidget {
  const _AlternativeTile({required this.outfit});

  final ScoredOutfit outfit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(AppSpacing.unit),
      decoration: BoxDecoration(
        color: AppColors.surfacePrimary.withValues(alpha: 0.5),
        border: Border.all(color: AppColors.borderSubtle),
        borderRadius: BorderRadius.circular(AppSpacing.unit),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            outfit.strategy.replaceAll('_', ' '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.interface.copyWith(
              fontSize: 12,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          Text(
            outfit.score.toStringAsFixed(1),
            style: AppType.data.copyWith(
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreRing extends StatelessWidget {
  const _ScoreRing({required this.score});

  final double score;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 72,
      child: CustomPaint(
        painter: _ScoreRingPainter(fraction: (score / 100).clamp(0.0, 1.0)),
        child: Center(
          child: Text(
            score.toStringAsFixed(0),
            style: AppType.data.copyWith(
              fontSize: 22,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _ScoreRingPainter extends CustomPainter {
  const _ScoreRingPainter({required this.fraction});

  final double fraction;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..color = AppColors.borderSubtle;
    canvas.drawCircle(center, radius, track);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = AppColors.accentSignature;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.5708,
      6.2832 * fraction,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_ScoreRingPainter oldDelegate) =>
      oldDelegate.fraction != fraction;
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.unit * 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated.withValues(alpha: 0.4),
        border: Border.all(color: AppColors.borderSubtle),
        borderRadius: BorderRadius.circular(AppSpacing.unit * 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: AppColors.surfacePrimary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.unit * 2),
              Expanded(
                child: Column(
                  children: [
                    _bar(width: 0.7),
                    const SizedBox(height: AppSpacing.unit),
                    _bar(width: 1.0),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.unit * 2),
          _bar(width: 0.9),
          const SizedBox(height: AppSpacing.unit),
          _bar(width: 0.8),
          const SizedBox(height: AppSpacing.unit),
          _bar(width: 0.6),
          const SizedBox(height: AppSpacing.unit * 2),
          Text(
            'Scoring against real weather and your profiles\u2026',
            style: AppType.interface.copyWith(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bar({required double width}) {
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: width,
      child: Container(
        height: 12,
        decoration: BoxDecoration(
          color: AppColors.surfacePrimary,
          borderRadius: BorderRadius.circular(AppSpacing.half),
        ),
      ),
    );
  }
}

/// Bundled city presets are reference coordinates only — picking one is an
/// explicit user choice, and manual lat/lon is validated before saving.
class _PlacePicker extends StatefulWidget {
  const _PlacePicker();

  @override
  State<_PlacePicker> createState() => _PlacePickerState();
}

class _PlacePickerState extends State<_PlacePicker> {
  static const _presets = [
    HomePlace(label: 'Casablanca', latitude: 33.5731, longitude: -7.5898),
    HomePlace(label: 'Rabat', latitude: 34.0209, longitude: -6.8416),
    HomePlace(label: 'Paris', latitude: 48.8566, longitude: 2.3522),
    HomePlace(label: 'London', latitude: 51.5074, longitude: -0.1278),
    HomePlace(label: 'New York', latitude: 40.7128, longitude: -74.006),
    HomePlace(label: 'Dubai', latitude: 25.2048, longitude: 55.2708),
  ];

  final _label = TextEditingController();
  final _lat = TextEditingController();
  final _lon = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _label.dispose();
    _lat.dispose();
    _lon.dispose();
    super.dispose();
  }

  void _submitManual() {
    final lat = double.tryParse(_lat.text.trim());
    final lon = double.tryParse(_lon.text.trim());
    if (lat == null || lat < -90 || lat > 90) {
      setState(() => _error = 'Latitude must be a number between -90 and 90.');
      return;
    }
    if (lon == null || lon < -180 || lon > 180) {
      setState(
        () => _error = 'Longitude must be a number between -180 and 180.',
      );
      return;
    }
    Navigator.of(
      context,
    ).pop(HomePlace(label: _label.text.trim(), latitude: lat, longitude: lon));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.unit * 3,
        AppSpacing.unit * 3,
        AppSpacing.unit * 3,
        MediaQuery.of(context).viewInsets.bottom + AppSpacing.unit * 3,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose a place',
            style: AppType.display.copyWith(
              fontSize: 20,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.unit * 2),
          Wrap(
            spacing: AppSpacing.unit,
            runSpacing: AppSpacing.unit,
            children: [
              for (final p in _presets)
                ActionChip(
                  label: Text(
                    p.label,
                    style: AppType.interface.copyWith(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  backgroundColor: AppColors.surfacePrimary,
                  side: BorderSide(color: AppColors.borderSubtle),
                  onPressed: () => Navigator.of(context).pop(p),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.unit * 2),
          Text(
            'Or enter coordinates',
            style: AppType.interface.copyWith(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.unit),
          TextField(
            controller: _label,
            decoration: const InputDecoration(labelText: 'Label (optional)'),
          ),
          const SizedBox(height: AppSpacing.unit),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _lat,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Latitude'),
                ),
              ),
              const SizedBox(width: AppSpacing.unit),
              Expanded(
                child: TextField(
                  controller: _lon,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Longitude'),
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.unit),
            Text(
              _error!,
              style: AppType.interface.copyWith(
                fontSize: 13,
                color: AppColors.error,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.unit * 2),
          SizedBox(
            height: AppSpacing.minTapTarget,
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.textPrimary,
                foregroundColor: AppColors.surfacePrimary,
              ),
              onPressed: _submitManual,
              child: Text(
                'Use these coordinates',
                style: AppType.interface.copyWith(fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
