import 'package:flutter/material.dart';

import '../../models/size.dart';
import '../../services/backend_client.dart';
import '../../services/local_store.dart';
import '../../theme/tokens.dart';
import '../widgets/atelier_button.dart';
import '../widgets/editorial_backdrop.dart';
import '../widgets/empty_state.dart';
import 'size_check_screen.dart';

/// FIT FLOW — guided fit check on the Phase 5 size engine (PRODUCT_SPEC §8).
///
/// Real Phase 1 body profile + a real size chart the user copies from a
/// product page → real recommended size + confidence + per-region breakdown,
/// or an honest §12 failure (`NO_SIZE_CHART`, `INSUFFICIENT_DATA`,
/// `LOW_CONFIDENCE`, `NETWORK_ERROR`). The engine computes; this flow only
/// collects and renders.
///
/// The gathering is a deterministic, guided flow — one step at a time, no
/// LLM provider is called or required. Converted from the labeled design
/// exploration (`design-exploration-fit-flow.html`); the sample content and
/// unwired sections were dropped in favour of the real engine call.
class FitFlowScreen extends StatefulWidget {
  const FitFlowScreen({
    super.key,
    required this.backendClient,
    this.bodyStore,
    this.sessionStorage = false,
    this.onStartScan,
  });

  final BackendClient backendClient;
  final ScanRecordStore? bodyStore;
  final bool sessionStorage;

  /// Optional route into the consent-gated body scan (wired by Profile).
  final VoidCallback? onStartScan;

  @override
  State<FitFlowScreen> createState() => _FitFlowScreenState();
}

class _Row {
  _Row(String label)
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

class _FitFlowScreenState extends State<FitFlowScreen> {
  static const _fitOptions = ['slim', 'regular', 'relaxed', 'oversized'];

  bool _loaded = false;
  bool _storageUnavailable = false;
  ScanRecord? _body;

  int _step = 0; // 0: the garment · 1: the size chart
  String _category = 'shirt';
  String _fit = 'regular';
  final List<_Row> _rows = [];
  String? _formNote;
  bool _busy = false;
  SizeOutcome? _outcome;

  @override
  void initState() {
    super.initState();
    _rows.addAll([_Row('S'), _Row('M'), _Row('L')]);
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

  void _resetOutcome() {
    if (_outcome != null) setState(() => _outcome = null);
  }

  Future<void> _submit() async {
    final body = _body;
    if (body == null || _busy) return;
    final rows = _chartRows();
    if (rows.length < 2) {
      setState(() => _formNote =
          'Enter at least two sizes with centimetre values.');
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
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Fit check',
          style: AppType.display.copyWith(
            fontSize: 22,
            letterSpacing: 0.2,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: Stack(
        children: [
          const Positioned.fill(
            child: EditorialBackdrop(
              scene: 'assets/editorial/scene_02.jpg',
              photoStrength: 0.42,
            ),
          ),
          // Fashion-tech overlay: measurement rulers + silhouette, faint —
          // ambience only, never data.
          const Positioned.fill(
            child: IgnorePointer(child: _FitTechLayer()),
          ),
          !_loaded
              ? const Center(
                  child: Text('Loading…', style: AppType.interface),
                )
              : _storageUnavailable
                  ? _hero(
                      'Local storage is unavailable here.',
                      'Your body profile can’t be read on this platform. '
                          'Run Atelier on Android for the full flow.',
                    )
                  : _body == null
                      ? _hero(
                          'Atelier hasn’t measured you yet.',
                          'Your fit starts with your real proportions — '
                              'shoulder, hip and arm, read from one real '
                              'photo. Never from a guess.',
                          actionLabel: 'Start body scan',
                          onAction: widget.onStartScan,
                        )
                      : _flow(_body!),
        ],
      ),
    );
  }

  Widget _hero(
    String title,
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.unit * 3),
        child: GlassSurface(
          padding: const EdgeInsets.all(AppSpacing.unit * 3),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'FIT INTELLIGENCE',
                style: AppType.caption.copyWith(
                  fontSize: 10,
                  letterSpacing: 2.4,
                  color: AppColors.spotlightGold,
                ),
              ),
              const SizedBox(height: AppSpacing.unit * 1.5),
              Text(
                title,
                style: AppType.headline.copyWith(
                  fontSize: 26,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.unit),
              Text(
                message,
                style: AppType.interface.copyWith(
                  fontSize: 14,
                  height: 1.55,
                  color: AppColors.textSecondary,
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: AppSpacing.unit * 3),
                AtelierButton(label: actionLabel, onPressed: onAction),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _flow(ScanRecord body) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.unit * 3,
              AppSpacing.unit * 3,
              AppSpacing.unit * 3,
              AppSpacing.unit * 1.5,
            ),
            children: [
              if (widget.sessionStorage) const SessionNote(),
              _bodyChip(body),
              const SizedBox(height: AppSpacing.unit * 2),
              Row(
                children: [
                  Text(
                    '${_step + 1} / 2',
                    style: AppType.data.copyWith(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.unit * 1.5),
                  for (var i = 0; i < 2; i++)
                    Container(
                      width: 7,
                      height: 7,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < _step
                            ? AppColors.textSecondary
                            : i == _step
                                ? AppColors.spotlightGold
                                : AppColors.fog.withValues(alpha: 0.28),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.unit * 2),
              if (_step == 0) ..._garmentStep() else ..._chartStep(),
            ],
          ),
        ),
        // Persistent primary CTA — a guided flow never hides its next
        // action below the fold.
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.unit * 3,
            AppSpacing.half,
            AppSpacing.unit * 3,
            AppSpacing.unit * 3,
          ),
          child: Column(
            children: [
              if (_step == 1 && _formNote != null) ...[
                Text(
                  _formNote!,
                  style: AppType.interface.copyWith(
                    fontSize: 13,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: AppSpacing.unit),
              ],
              AtelierButton(
                label: _step == 0 ? 'Continue' : 'Check my fit',
                loading: _step == 1 && _busy,
                onPressed: _step == 0
                    ? () => setState(() => _step = 1)
                    : (_busy ? null : _submit),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Honest context: the stored Phase 1 scan and the measurements the
  /// engine can actually score (shoulder, hip, arm). Chest and waist stay
  /// unmeasured by design.
  Widget _bodyChip(ScanRecord body) {
    final summary = _bodySummary(body.payload);
    return GlassSurface(
      borderRadius: BorderRadius.circular(AppSpacing.unit * 2),
      padding: const EdgeInsets.all(AppSpacing.unit * 2),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(AppSpacing.unit * 1.25),
            ),
            child: const Icon(
              Icons.accessibility_new_outlined,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: AppSpacing.unit * 1.5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your body scan',
                  style: AppType.interface.copyWith(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  summary,
                  style: AppType.data.copyWith(
                    fontSize: 10.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _bodySummary(Map<String, dynamic> payload) {
    try {
      final m = (payload['body'] as Map<String, dynamic>)['measurements_cm']
          as Map<String, dynamic>;
      final parts = <String>[];
      for (final key in const ['shoulder', 'hip', 'arm']) {
        final v = m[key];
        if (v is num) parts.add('$key ${v.toDouble().toStringAsFixed(1)}');
      }
      if (parts.isEmpty) return 'body profile ready';
      return '${parts.join(' · ')} cm · chest/waist not measurable';
    } catch (_) {
      return 'body profile ready';
    }
  }

  List<Widget> _garmentStep() {
    return [
      _stepLabel('Step 1 — The garment'),
      const SizedBox(height: AppSpacing.half),
      Text(
        'What is it, and how is it cut? The engine’s ease depends on the '
        'fit.',
        style: AppType.interface.copyWith(
          fontSize: 14,
          height: 1.45,
          color: AppColors.textPrimary,
        ),
      ),
      const SizedBox(height: AppSpacing.unit * 2),
      GlassSurface(
        borderRadius: BorderRadius.circular(AppSpacing.unit * 2),
        padding: const EdgeInsets.all(AppSpacing.unit * 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _fieldLabel('CATEGORY'),
            Wrap(
              spacing: AppSpacing.half,
              runSpacing: AppSpacing.half,
              children: [
                for (final c in SizeCheckScreen.categories)
                  _chip(
                    label: c,
                    selected: c == _category,
                    onTap: () => setState(() {
                      _category = c;
                      _resetOutcome();
                    }),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.unit * 2),
            _fieldLabel('FIT OF THE GARMENT'),
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
                _resetOutcome();
              }),
            ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _chartStep() {
    return [
      Row(
        children: [
          Expanded(child: _stepLabel('Step 2 — The size chart')),
          SizedBox(
            height: AppSpacing.minTapTarget,
            child: TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                        _step = 0;
                        _outcome = null;
                        _formNote = null;
                      }),
              child: Text(
                '‹ Garment',
                style: AppType.interface.copyWith(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.half),
      Text(
        'Copy the centimetre values exactly as printed on the product '
        'page. Nothing estimated, nothing filled in.',
        style: AppType.interface.copyWith(
          fontSize: 14,
          height: 1.45,
          color: AppColors.textPrimary,
        ),
      ),
      const SizedBox(height: AppSpacing.unit * 2),
      for (final r in _rows) _rowCard(r),
      SizedBox(
        height: AppSpacing.minTapTarget,
        child: AtelierButton(
          label: 'Add a size',
          variant: AtelierButtonVariant.secondary,
          fullWidth: false,
          onPressed: () => setState(() {
            _rows.add(_Row(''));
            _resetOutcome();
          }),
        ),
      ),
      const SizedBox(height: AppSpacing.unit * 2),
      if (_outcome case SizeOk(:final recommendation))
        SizeResultView(recommendation: recommendation)
      else if (_outcome case SizeFailure(:final code, :final message))
        _failure(code, message),
    ];
  }

  Widget _rowCard(_Row r) {
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
                  onChanged: (_) => _resetOutcome(),
                  style:
                      AppType.data.copyWith(color: AppColors.textPrimary),
                  decoration: const InputDecoration(labelText: 'Size'),
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => setState(() {
                  _rows.remove(r);
                  r.dispose();
                  _resetOutcome();
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
                    onChanged: (_) => _resetOutcome(),
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

  /// A 44pt-tall chip (Apple HIG minimum, DESIGN_SYSTEM §2) — the plain
  /// ChoiceChip falls short of it.
  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: AppSpacing.minTapTarget,
      child: Material(
        color: selected
            ? AppColors.textPrimary
            : AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppSpacing.unit * 2),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSpacing.unit * 2),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.unit * 1.5,
            ),
            child: Center(
              child: Text(
                label,
                style: AppType.interface.copyWith(
                  fontSize: 12,
                  color: selected
                      ? AppColors.surfacePrimary
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _stepLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: AppType.data.copyWith(
        fontSize: 11,
        letterSpacing: 1.4,
        color: AppColors.textSecondary,
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.half),
      child: Text(
        text,
        style: AppType.data.copyWith(
          fontSize: 10.5,
          letterSpacing: 1.4,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _failure(String code, String message) {
    return GlassSurface(
      padding: const EdgeInsets.all(AppSpacing.unit * 2.5),
      border: Border.all(color: AppColors.error.withValues(alpha: 0.35)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            code,
            style:
                AppType.data.copyWith(fontSize: 12, color: AppColors.error),
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

/// Faint fashion-tech overlay: vertical measurement rulers and a human
/// silhouette with gold seam ticks. Purely ambient — it carries no data and
/// never implies a measurement (No-Fake-Data doctrine).
class _FitTechLayer extends StatelessWidget {
  const _FitTechLayer();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _FitTechPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _FitTechPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final ruler = Paint()
      ..color = AppColors.fog.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    for (var x = 24.0; x < size.width; x += 48) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), ruler);
    }
    final tick = Paint()
      ..color = AppColors.fog.withValues(alpha: 0.10)
      ..strokeWidth = 1;
    for (var y = 0.0; y < size.height; y += 24) {
      canvas.drawLine(const Offset(16, 0) + Offset(0, y),
          Offset(24, y), tick);
    }
    // Silhouette, right-aligned, very faint.
    final cx = size.width * 0.82;
    final top = size.height * 0.16;
    final h = size.height * 0.6;
    final silhouette = Paint()
      ..color = AppColors.spotlightGold.withValues(alpha: 0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final path = Path()
      ..addOval(Rect.fromLTWH(cx - h * 0.05, top, h * 0.1, h * 0.12))
      ..moveTo(cx - h * 0.11, top + h * 0.16)
      ..lineTo(cx + h * 0.11, top + h * 0.16)
      ..lineTo(cx + h * 0.08, top + h * 0.5)
      ..lineTo(cx + h * 0.09, top + h * 0.95)
      ..moveTo(cx - h * 0.11, top + h * 0.16)
      ..lineTo(cx - h * 0.08, top + h * 0.5)
      ..lineTo(cx - h * 0.09, top + h * 0.95);
    canvas.drawPath(path, silhouette);
    final seam = Paint()
      ..color = AppColors.spotlightGold.withValues(alpha: 0.16)
      ..strokeWidth = 1.2;
    canvas.drawLine(
        Offset(cx - h * 0.11, top + h * 0.2),
        Offset(cx + h * 0.11, top + h * 0.2),
        seam);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
