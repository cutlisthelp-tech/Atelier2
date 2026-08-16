import 'package:flutter/material.dart';

import '../../models/size.dart';
import '../../services/backend_client.dart';
import '../../services/local_store.dart';
import '../../theme/tokens.dart';

/// SIZE CHECK — Phase 5 (PRODUCT_SPEC §8).
///
/// Real body measurements (Phase 1) + a real size chart the user copies from
/// a product page (centimetres per size) → recommended size + confidence +
/// per-region breakdown. The chart is the user's own data; the engine only
/// computes, never invents. Chest/waist stay honestly "not measurable".
class SizeCheckScreen extends StatefulWidget {
  const SizeCheckScreen({
    super.key,
    required this.backendClient,
    this.bodyStore,
  });

  final BackendClient backendClient;
  final ScanRecordStore? bodyStore;

  /// Categories the engine can size (tops, bottoms, one-pieces).
  static const categories = [
    't-shirt', 'shirt', 'blouse', 'sweater', 'hoodie', 'jacket', 'coat',
    'jeans', 'trousers', 'shorts', 'skirt', 'dress', 'suit',
  ];

  static const cmFields = ['chest', 'waist', 'hip', 'shoulder', 'sleeve', 'length'];

  @override
  State<SizeCheckScreen> createState() => _SizeCheckScreenState();
}

class _ChartRow {
  _ChartRow(String label)
      : label = TextEditingController(text: label),
        cms = {
          for (final f in SizeCheckScreen.cmFields) f: TextEditingController(),
        };

  final TextEditingController label;
  final Map<String, TextEditingController> cms;

  void dispose() {
    label.dispose();
    for (final c in cms.values) {
      c.dispose();
    }
  }
}

class _SizeCheckScreenState extends State<SizeCheckScreen> {
  static const _fitOptions = ['slim', 'regular', 'relaxed', 'oversized'];

  bool _loaded = false;
  bool _storageUnavailable = false;
  ScanRecord? _body;
  String _category = 'shirt';
  String _fit = 'regular';
  final _brand = TextEditingController();
  final List<_ChartRow> _rows = [];
  bool _busy = false;
  String? _formNote;
  SizeOutcome? _outcome;

  @override
  void initState() {
    super.initState();
    _rows.addAll([_ChartRow('S'), _ChartRow('M'), _ChartRow('L')]);
    _load();
  }

  Future<void> _load() async {
    try {
      _body = await widget.bodyStore?.load();
    } catch (_) {
      if (mounted) setState(() => _storageUnavailable = true);
    }
    if (mounted) setState(() => _loaded = true);
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    _brand.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _chartRows() => [
        for (final r in _rows)
          if (r.label.text.trim().isNotEmpty)
            {
              'label': r.label.text.trim(),
              for (final f in SizeCheckScreen.cmFields)
                if (double.tryParse(r.cms[f]!.text.trim()) != null)
                  '${f}_cm': double.tryParse(r.cms[f]!.text.trim()),
            },
      ];

  Future<void> _submit() async {
    final body = _body;
    if (body == null || _busy) return;
    final rows = _chartRows();
    if (rows.length < 2) {
      setState(() => _formNote = 'Enter at least two sizes with centimetre values.');
      return;
    }
    setState(() {
      _busy = true;
      _formNote = null;
      _outcome = null;
    });
    final outcome = await widget.backendClient.recommendSize(
      category: _category,
      fitType: _fit,
      bodyProfile: body.payload,
      rows: rows,
      brand: _brand.text.trim(),
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _outcome = outcome;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Size check', style: AppType.interface)),
      body: SafeArea(
        child: !_loaded
            ? const Center(child: Text('Loading…', style: AppType.interface))
            : _storageUnavailable
            ? _plain(
                'Local storage is unavailable here, so your body profile '
                'can\u2019t be read. Run Atelier on Android for the full flow.',
              )
            : _body == null
            ? _plain(
                'Atelier hasn\u2019t measured you yet. Run a body scan in '
                'Profile first — sizes come from your real shoulder, hip and '
                'arm measurements, never from a guess.',
              )
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.unit * 3),
                children: [
                  Text(
                    'Copy the centimetre values from a real product size '
                    'chart; Atelier matches them against your real '
                    'measurements.',
                    style: AppType.interface.copyWith(
                      fontSize: 14,
                      height: 1.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.unit * 2),
                  _label('CATEGORY'),
                  Wrap(
                    spacing: AppSpacing.half,
                    runSpacing: AppSpacing.half,
                    children: [
                      for (final c in SizeCheckScreen.categories)
                        ChoiceChip(
                          label: Text(
                            c,
                            style: AppType.interface.copyWith(
                              fontSize: 12,
                              color: c == _category
                                  ? AppColors.surfacePrimary
                                  : AppColors.textSecondary,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          selected: c == _category,
                          selectedColor: AppColors.textPrimary,
                          backgroundColor: AppColors.surfaceElevated,
                          side: BorderSide(color: AppColors.borderSubtle),
                          onSelected: (_) => setState(() {
                            _category = c;
                            _outcome = null;
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.unit * 2),
                  _label('FIT OF THE GARMENT'),
                  SegmentedButton<String>(
                    style: const ButtonStyle(
                      minimumSize: WidgetStatePropertyAll(
                        Size(0, AppSpacing.minTapTarget),
                      ),
                    ),
                    segments: [
                      for (final f in _fitOptions)
                        ButtonSegment(
                          value: f,
                          label: Text(f[0].toUpperCase() + f.substring(1)),
                        ),
                    ],
                    selected: {_fit},
                    onSelectionChanged: (s) => setState(() {
                      _fit = s.first;
                      _outcome = null;
                    }),
                  ),
                  const SizedBox(height: AppSpacing.unit * 2),
                  _label('BRAND (OPTIONAL)'),
                  TextField(
                    controller: _brand,
                    style: AppType.interface.copyWith(
                      color: AppColors.textPrimary,
                    ),
                    decoration: const InputDecoration(hintText: 'Label only — matching happens in cm'),
                  ),
                  const SizedBox(height: AppSpacing.unit * 2),
                  _label('SIZE CHART (CM)'),
                  for (final r in _rows) _rowCard(r),
                  const SizedBox(height: AppSpacing.unit),
                  SizedBox(
                    height: AppSpacing.minTapTarget,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.borderSubtle),
                        foregroundColor: AppColors.textPrimary,
                      ),
                      onPressed: () => setState(() => _rows.add(_ChartRow(''))),
                      child: Text(
                        'Add a size',
                        style: AppType.interface.copyWith(fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.unit * 2),
                  if (_formNote != null) ...[
                    Text(
                      _formNote!,
                      style: AppType.interface.copyWith(
                        fontSize: 13,
                        color: AppColors.error,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.unit),
                  ],
                  SizedBox(
                    height: AppSpacing.minTapTarget,
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.textPrimary,
                        foregroundColor: AppColors.surfacePrimary,
                      ),
                      onPressed: _busy ? null : _submit,
                      child: Text(
                        _busy ? 'Matching…' : 'Find my size',
                        style: AppType.interface.copyWith(fontSize: 15),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.unit * 2),
                  if (_outcome case SizeOk(:final recommendation))
                    SizeResultView(recommendation: recommendation)
                  else if (_outcome case SizeFailure(:final code, :final message))
                    _failure(code, message),
                ],
              ),
      ),
    );
  }

  Widget _rowCard(_ChartRow r) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.unit),
      padding: const EdgeInsets.all(AppSpacing.unit * 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppSpacing.unit * 2),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 64,
                child: TextField(
                  controller: r.label,
                  style: AppType.data.copyWith(color: AppColors.textPrimary),
                  decoration: const InputDecoration(labelText: 'Size'),
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => setState(() {
                  _rows.remove(r);
                  r.dispose();
                }),
                icon: const Icon(
                  Icons.delete_outline,
                  color: AppColors.textSecondary,
                ),
                tooltip: 'Remove this size',
              ),
            ],
          ),
          Wrap(
            spacing: AppSpacing.unit,
            runSpacing: AppSpacing.unit,
            children: [
              for (final f in SizeCheckScreen.cmFields)
                SizedBox(
                  width: 96,
                  child: TextField(
                    controller: r.cms[f],
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: AppType.data.copyWith(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(labelText: f),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.half),
      child: Text(
        text,
        style: AppType.data.copyWith(
          fontSize: 11,
          letterSpacing: 1.4,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _plain(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.unit * 3),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: AppType.interface.copyWith(
            fontSize: 15,
            height: 1.5,
            color: AppColors.textSecondary,
          ),
        ),
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

/// The labeled size result: recommended size, confidence, per-region
/// breakdown and every size's score — all in the Data typeface.
class SizeResultView extends StatelessWidget {
  const SizeResultView({super.key, required this.recommendation});

  final SizeRecommendation recommendation;

  @override
  Widget build(BuildContext context) {
    final r = recommendation;
    final low = r.flags.contains('LOW_CONFIDENCE');
    return Container(
      padding: const EdgeInsets.all(AppSpacing.unit * 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppSpacing.unit * 2),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                r.label,
                style: AppType.display.copyWith(
                  fontSize: 44,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: AppSpacing.unit * 2),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.unit),
                  child: Text(
                    'CONFIDENCE ${(r.confidence * 100).round()}% · '
                    '${r.fitType.toUpperCase()}${r.brand.isEmpty ? '' : ' · ${r.brand.toUpperCase()}'}',
                    style: AppType.data.copyWith(
                      fontSize: 12,
                      color: low ? AppColors.error : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (low)
            Text(
              'LOW CONFIDENCE — the chart and your measurements agree only '
              'loosely. Check the fit notes before ordering.',
              style: AppType.data.copyWith(fontSize: 11, color: AppColors.error),
            ),
          const SizedBox(height: AppSpacing.unit * 2),
          for (final region in r.regions) _regionRow(region),
          const SizedBox(height: AppSpacing.unit * 2),
          Text(
            'ALL SIZES',
            style: AppType.data.copyWith(
              fontSize: 11,
              letterSpacing: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.half),
          for (final s in r.sizes)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  SizedBox(
                    width: 48,
                    child: Text(
                      s.label,
                      style: AppType.data.copyWith(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: s.score.clamp(0.0, 1.0),
                      minHeight: 3,
                      backgroundColor: AppColors.surfacePrimary,
                      color: s.label == r.label
                          ? AppColors.textSecondary
                          : AppColors.borderSubtle,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.unit),
                  Text(
                    s.score.toStringAsFixed(2),
                    style: AppType.data.copyWith(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          if (r.note.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.unit),
            Text(
              r.note,
              style: AppType.interface.copyWith(
                fontSize: 12,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _regionRow(SizeRegion region) {
    final value = switch (region.status) {
      'matched' =>
        '${region.measuredCm!.toStringAsFixed(1)} → ${region.chartCm!.toStringAsFixed(1)} cm '
        '(${region.deltaCm! >= 0 ? '+' : ''}${region.deltaCm!.toStringAsFixed(1)})',
      'off' =>
        '${region.measuredCm!.toStringAsFixed(1)} → ${region.chartCm!.toStringAsFixed(1)} cm '
        '(${region.deltaCm! >= 0 ? '+' : ''}${region.deltaCm!.toStringAsFixed(1)}, off)',
      'not_measurable' => '— · ${region.note}',
      _ => '—',
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(
              region.region,
              style: AppType.interface.copyWith(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppType.data.copyWith(
                fontSize: 12,
                color: region.status == 'not_measurable'
                    ? AppColors.textSecondary
                    : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
