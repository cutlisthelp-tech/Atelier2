import 'package:flutter/material.dart';

import '../../models/recommendation.dart';
import '../../theme/tokens.dart';
import 'home_screen.dart';

/// Developer-only design exploration: the Fit Intelligence Flow.
///
/// Renders the three explored screens — guided measurement gathering,
/// read-only size-chart capture from a product link, and the best-outfit
/// trend slot — so layout, hierarchy, voice and honest states can be judged.
///
/// Provider-agnostic by construction: gathering runs on a static,
/// deterministic question list, so no LLM provider (Gemini or otherwise)
/// is called or required. The trend slot renders its honest inactive state.
/// Everything is labeled sample content; nothing here is wired to a backend.
class FitFlowPreviewScreen extends StatelessWidget {
  const FitFlowPreviewScreen({super.key});

  // Compact sample so the real ResultCard renders beneath the trend slot.
  // Labeled in the banner above: not scored from any real profile.
  static final OutfitRecommendation _sample =
      OutfitRecommendation.fromJson(const {
    'context': {
      'occasion': 'dinner',
      'place_label': 'Casablanca',
      'weather': {
        'state': 'ok',
        'temperature_c': 22.3,
        'precipitation_mm': 0.0,
        'weather_code': 2,
        'weather_label': 'partly cloudy',
        'wind_kmh': 5.0,
        'observed_at': '2026-08-15T18:00',
      },
    },
    'factors': [
      {
        'name': 'body_fit',
        'base_weight': 18.0,
        'effective_weight': 20.0,
        'active': true,
        'inactive_reason': null,
        'score': 0.8,
        'contribution': 16.0,
      },
      {
        'name': 'trend',
        'base_weight': 6.0,
        'effective_weight': 0.0,
        'active': false,
        'inactive_reason': 'no trend feed is connected',
        'score': 0.0,
        'contribution': 0.0,
      },
    ],
    'outfits': [
      {
        'strategy': 'best_match',
        'score': 71.1,
        'garments': [
          {
            'id': 'sample-jacket',
            'category': 'jacket',
            'colors': [
              {'name': 'charcoal', 'hex': '#2f3234', 'share': 0.62},
            ],
            'fit': 'regular',
            'material': 'wool',
            'pattern': null,
          },
          {
            'id': 'sample-jeans',
            'category': 'jeans',
            'colors': [
              {'name': 'blue', 'hex': '#3a5a8c', 'share': 0.66},
            ],
            'fit': 'slim',
            'material': 'denim',
            'pattern': null,
          },
        ],
        'why': [
          'Shoulders match your scan — no gap, no pull.',
          'Warm layer for a cool evening.',
        ],
      },
    ],
    'excluded': {
      'hard_filters': <dynamic>[],
      'unplaceable': <dynamic>[],
      'filters_note': 'No hard filters applied.',
    },
    'shopping': {
      'state': 'CATALOG_NOT_CONNECTED',
      'message': 'No merchant catalog is connected.',
    },
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.surfacePrimary,
        title: Text('Fit flow preview', style: AppType.interface),
      ),
      body: Stack(
        children: [
          // Content behind the glass — blur needs something to blur
          // (DESIGN_SYSTEM §1 honest materiality).
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.graphite,
                    AppColors.ink,
                    AppColors.ink,
                  ],
                  stops: [0.0, 0.55, 1.0],
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 90,
                    right: -60,
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.spotlightGold
                            .withValues(alpha: 0.28),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 620,
                    left: -80,
                    child: Container(
                      width: 260,
                      height: 260,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.fog.withValues(alpha: 0.14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          ListView(
            padding: const EdgeInsets.all(AppSpacing.unit * 3),
            children: [
              _banner(),
              const SizedBox(height: AppSpacing.unit * 3),
              _sectionLabel('Screen 1 — Fit check · guided gathering'),
              _principle(
                'Conversational intelligence, visual surface: the next '
                'question is chosen for this garment, but the input stays '
                'structured. No chat thread. Here the list is deterministic '
                '— no LLM provider is called or required.',
              ),
              const SizedBox(height: AppSpacing.unit * 2),
              const _GatheringDemo(),
              const SizedBox(height: AppSpacing.unit * 4),
              _sectionLabel('Screen 2 — Size chart from a product link'),
              _principle(
                'Read-only extraction: only values printed on the page may '
                'surface, with provenance. A missing chart is an honest '
                'NO_SIZE_CHART — never an estimated table.',
              ),
              const SizedBox(height: AppSpacing.unit * 2),
              _stateCaption('STATE: CHART FOUND — VALUES WITH PROVENANCE'),
              const SizedBox(height: AppSpacing.unit),
              _chartFound(),
              const SizedBox(height: AppSpacing.unit * 3),
              _stateCaption('STATE: NOT FOUND — NO_SIZE_CHART (§12)'),
              const SizedBox(height: AppSpacing.unit),
              _chartMissing(),
              const SizedBox(height: AppSpacing.unit * 4),
              _sectionLabel('Screen 3 — Best outfit · trend slot'),
              _principle(
                'Trends come from an indexed source fetched like weather — '
                'never a live web search per request. Until a source exists, '
                'the slot renders honestly inactive.',
              ),
              const SizedBox(height: AppSpacing.unit * 2),
              ResultCard(recommendation: _sample),
              const SizedBox(height: AppSpacing.unit * 2),
              _stateCaption('TREND SLOT — SOURCE NOT CONNECTED (DEFAULT)'),
              const SizedBox(height: AppSpacing.unit),
              const _TrendSlot(connected: false),
              const SizedBox(height: AppSpacing.unit * 3),
              _stateCaption('TREND SLOT — SOURCE CONNECTED (SAMPLE ONLY)'),
              const SizedBox(height: AppSpacing.unit),
              const _TrendSlot(connected: true),
              const SizedBox(height: AppSpacing.unit * 3),
            ],
          ),
        ],
      ),
    );
  }

  Widget _banner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.unit * 2),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(AppSpacing.unit),
      ),
      child: Text(
        'SAMPLE DATA — developer design exploration. No backend, no LLM '
        'provider, no real measurements: this screen exists to judge '
        'layout, voice and the honest states. Gathering runs on a '
        'deterministic question list; an LLM (Gemini or otherwise) is an '
        'optional later addition behind the keyless policy — the flow '
        'never requires one.',
        style: AppType.interface.copyWith(
          fontSize: 13,
          height: 1.5,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.unit),
      child: Text(
        text.toUpperCase(),
        style: AppType.data.copyWith(
          fontSize: 11,
          letterSpacing: 1.4,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _principle(String text) {
    return Text(
      text,
      style: AppType.interface.copyWith(
        fontSize: 13,
        height: 1.5,
        color: AppColors.textSecondary,
      ),
    );
  }

  Widget _stateCaption(String text) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: AppType.data.copyWith(
        fontSize: 10.5,
        letterSpacing: 1.2,
        color: AppColors.textSecondary,
      ),
    );
  }

  Widget _chartFound() {
    return GlassSurface(
      borderRadius: BorderRadius.circular(AppSpacing.unit * 2),
      padding: const EdgeInsets.all(AppSpacing.unit * 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.unit * 1.5,
              vertical: AppSpacing.unit * 1.5,
            ),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.fog.withValues(alpha: 0.25)),
              borderRadius: BorderRadius.circular(AppSpacing.unit * 1.5),
            ),
            child: Text(
              'https://shop.example/products/wool-jacket',
              style: AppType.data.copyWith(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.unit * 1.5),
          SizedBox(
            height: AppSpacing.minTapTarget,
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: BorderSide(
                  color: AppColors.fog.withValues(alpha: 0.35),
                ),
              ),
              onPressed: () {}, // preview only — nothing is wired
              child: Text(
                'Read size chart',
                style: AppType.interface.copyWith(fontSize: 15),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.unit * 2),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.unit * 1.5,
              vertical: AppSpacing.half,
            ),
            decoration: BoxDecoration(
              border: Border.all(
                color: AppColors.spotlightGold.withValues(alpha: 0.4),
              ),
              borderRadius: BorderRadius.circular(AppSpacing.unit * 3),
            ),
            child: Text(
              'READ FROM PAGE · TODAY',
              style: AppType.data.copyWith(
                fontSize: 10,
                letterSpacing: 1.2,
                color: AppColors.spotlightGold,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.unit * 2),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(1),
              1: FlexColumnWidth(1.4),
              2: FlexColumnWidth(1.4),
            },
            children: [
              TableRow(
                children: [
                  _chartHeader('Size'),
                  _chartHeader('Chest (cm)'),
                  _chartHeader('Length (cm)'),
                ],
              ),
              _chartRow(['S', '52', '68']),
              _chartRow(['M', '54', '70']),
              _chartRow(['L', '56', '72']),
            ],
          ),
          const SizedBox(height: AppSpacing.unit * 2),
          Text(
            'As printed on the page. Nothing estimated, nothing filled in.',
            style: AppType.interface.copyWith(
              fontSize: 12.5,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.unit * 2),
          _goldButton('Use this chart'),
          const SizedBox(height: AppSpacing.unit),
          Center(
            child: Text(
              'Not the right chart? Paste another link',
              style: AppType.interface.copyWith(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chartHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.half),
      child: Text(
        text.toUpperCase(),
        style: AppType.data.copyWith(
          fontSize: 10,
          letterSpacing: 1.0,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  TableRow _chartRow(List<String> cells) {
    return TableRow(
      children: [
        for (final c in cells)
          Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.half,
              bottom: AppSpacing.half,
            ),
            child: Text(
              c,
              style: AppType.data.copyWith(
                fontSize: 12,
                color: AppColors.textPrimary,
              ),
            ),
          ),
      ],
    );
  }

  Widget _chartMissing() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.unit * 2.5),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated.withValues(alpha: 0.4),
        border: Border.all(color: AppColors.borderSubtle),
        borderRadius: BorderRadius.circular(AppSpacing.unit * 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No size chart on this page.',
            style: AppType.interface.copyWith(
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.unit),
          Text(
            'We read the page and found no measurement table. We never '
            'guess numbers that aren’t written down.',
            style: AppType.interface.copyWith(
              fontSize: 13,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.unit * 2),
          _goldButton('Measure it yourself'),
          const SizedBox(height: AppSpacing.unit),
          SizedBox(
            height: AppSpacing.minTapTarget,
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: BorderSide(
                  color: AppColors.fog.withValues(alpha: 0.35),
                ),
              ),
              onPressed: () {}, // preview only — nothing is wired
              child: Text(
                'Skip fit check',
                style: AppType.interface.copyWith(fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _goldButton(String label) {
    return SizedBox(
      height: AppSpacing.minTapTarget,
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accentSignature,
          foregroundColor: AppColors.surfacePrimary,
        ),
        onPressed: () {}, // preview only — nothing is wired
        child: Text(label, style: AppType.interface.copyWith(fontSize: 15)),
      ),
    );
  }
}

/// One question at a time, structured input, deterministic order.
/// Skipping records an honest null — listed later, never scored.
class _GatheringDemo extends StatefulWidget {
  const _GatheringDemo();

  @override
  State<_GatheringDemo> createState() => _GatheringDemoState();
}

class _GatherQuestion {
  const _GatherQuestion({
    required this.label,
    required this.unit,
    required this.guidance,
    required this.sampleValue,
  });

  final String label;
  final String unit;
  final String guidance;
  final String sampleValue;
}

class _GatheringDemoState extends State<_GatheringDemo> {
  static const _questions = [
    _GatherQuestion(
      label: 'Your height',
      unit: 'cm',
      guidance:
          'Start simple — your height calibrates every proportion that '
          'follows.',
      sampleValue: '178',
    ),
    _GatherQuestion(
      label: 'Shoulder width',
      unit: 'cm',
      guidance:
          'Jackets live or die by the shoulders. Measure across the back, '
          'seam to seam.',
      sampleValue: '44.5',
    ),
    _GatherQuestion(
      label: 'Garment chest',
      unit: 'cm',
      guidance:
          'Across the chest, a hand-width below the armhole — flat, not '
          'stretched.',
      sampleValue: '54',
    ),
    _GatherQuestion(
      label: 'Body length',
      unit: 'cm',
      guidance: 'From the highest shoulder point down to the hem.',
      sampleValue: '70',
    ),
  ];

  final Map<String, double?> _answers = {};
  late final TextEditingController _controller =
      TextEditingController(text: _questions[0].sampleValue);
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _done => _index >= _questions.length;

  void _advance(double? value) {
    setState(() {
      _answers[_questions[_index].label] = value;
      _index++;
      if (!_done) {
        _controller.text = _questions[_index].sampleValue;
      }
    });
  }

  void _restart() {
    setState(() {
      _answers.clear();
      _index = 0;
      _controller.text = _questions[0].sampleValue;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GlassSurface(
          borderRadius: BorderRadius.circular(AppSpacing.unit * 2),
          padding: const EdgeInsets.all(AppSpacing.unit * 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius:
                          BorderRadius.circular(AppSpacing.unit * 1.25),
                    ),
                    child: const Icon(
                      Icons.checkroom_outlined,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.unit * 1.5),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Detected: Jacket',
                          style: AppType.interface.copyWith(
                            fontSize: 13,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'category 0.83 · sample',
                          style: AppType.data.copyWith(
                            fontSize: 10.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _done
                        ? 'done'
                        : '${_index + 1} / ${_questions.length}',
                    style: AppType.data.copyWith(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.unit * 2),
              if (!_done) ..._questionView(_questions[_index]) else ..._summaryView(),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.unit),
        Text(
          'Measured by you. Guidance adapts to the garment in the real '
          'flow. Fit is computed by the size engine — never by the '
          'assistant.',
          textAlign: TextAlign.center,
          style: AppType.interface.copyWith(
            fontSize: 11,
            height: 1.4,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  List<Widget> _questionView(_GatherQuestion q) {
    return [
      Text(
        'GUIDANCE — DETERMINISTIC LIST · NO LLM CALL',
        style: AppType.data.copyWith(
          fontSize: 10,
          letterSpacing: 1.2,
          color: AppColors.spotlightGold,
        ),
      ),
      const SizedBox(height: AppSpacing.half),
      Text(
        q.guidance,
        style: AppType.interface.copyWith(
          fontSize: 14,
          height: 1.45,
          color: AppColors.textPrimary,
        ),
      ),
      const SizedBox(height: AppSpacing.unit * 2),
      Text(
        q.label.toUpperCase(),
        style: AppType.data.copyWith(
          fontSize: 10.5,
          letterSpacing: 1.4,
          color: AppColors.textSecondary,
        ),
      ),
      const SizedBox(height: AppSpacing.unit),
      SizedBox(
        height: 64,
        child: CustomPaint(
          size: const Size(double.infinity, 64),
          painter: _MeasureDiagramPainter(),
        ),
      ),
      const SizedBox(height: AppSpacing.unit),
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: AppType.data.copyWith(
                fontSize: 30,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: AppColors.fog.withValues(alpha: 0.25),
                  ),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.spotlightGold),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.unit),
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.half),
            child: Text(
              q.unit,
              style: AppType.data.copyWith(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.unit * 2),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < _questions.length; i++)
            Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < _index
                    ? AppColors.textSecondary
                    : i == _index
                        ? AppColors.spotlightGold
                        : AppColors.fog.withValues(alpha: 0.28),
              ),
            ),
        ],
      ),
      const SizedBox(height: AppSpacing.unit * 2),
      SizedBox(
        height: AppSpacing.minTapTarget,
        width: double.infinity,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accentSignature,
            foregroundColor: AppColors.surfacePrimary,
          ),
          onPressed: () =>
              _advance(double.tryParse(_controller.text.trim())),
          child: Text('Continue', style: AppType.interface.copyWith(fontSize: 15)),
        ),
      ),
      const SizedBox(height: AppSpacing.unit),
      SizedBox(
        height: AppSpacing.minTapTarget,
        width: double.infinity,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            side: BorderSide(color: AppColors.fog.withValues(alpha: 0.35)),
          ),
          onPressed: () => _advance(null),
          child: Text(
            "I don't have this number",
            style: AppType.interface.copyWith(fontSize: 15),
          ),
        ),
      ),
    ];
  }

  List<Widget> _summaryView() {
    final measured = _answers.values.where((v) => v != null).length;
    final skipped = _answers.length - measured;
    return [
      Text(
        'GATHERING COMPLETE',
        style: AppType.data.copyWith(
          fontSize: 10.5,
          letterSpacing: 1.4,
          color: AppColors.textSecondary,
        ),
      ),
      const SizedBox(height: AppSpacing.half),
      Text(
        '$measured measured · $skipped skipped',
        style: AppType.data.copyWith(
          fontSize: 13,
          color: AppColors.textPrimary,
        ),
      ),
      const SizedBox(height: AppSpacing.unit * 1.5),
      for (final q in _questions)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.unit),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  q.label,
                  style: AppType.interface.copyWith(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Text(
                _answers[q.label]?.toStringAsFixed(1) ??
                    'not provided · not scored',
                style: AppType.data.copyWith(
                  fontSize: 12,
                  color: _answers[q.label] == null
                      ? AppColors.textSecondary
                      : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      Text(
        'From here the deterministic size engine (PRODUCT_SPEC §8) computes '
        'size + confidence. Skipped regions are listed, never scored — the '
        'assistant never calculates numbers.',
        style: AppType.interface.copyWith(
          fontSize: 12.5,
          height: 1.5,
          color: AppColors.textSecondary,
        ),
      ),
      const SizedBox(height: AppSpacing.unit * 2),
      SizedBox(
        height: AppSpacing.minTapTarget,
        width: double.infinity,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            side: BorderSide(color: AppColors.fog.withValues(alpha: 0.35)),
          ),
          onPressed: _restart,
          child: Text('Start over', style: AppType.interface.copyWith(fontSize: 15)),
        ),
      ),
    ];
  }
}

/// Where-to-measure schematic: jacket outline (fog) with a gold seam-to-seam
/// line. Purely illustrative — the same shape for every garment question.
class _MeasureDiagramPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final fog = Paint()
      ..color = AppColors.fog.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final gold = Paint()
      ..color = AppColors.spotlightGold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final w = size.width;
    final h = size.height;
    final outline = Path()
      ..moveTo(w * 0.35, h * 0.12)
      ..lineTo(w * 0.18, h * 0.32)
      ..lineTo(w * 0.24, h * 0.66)
      ..lineTo(w * 0.34, h * 0.54)
      ..lineTo(w * 0.34, h * 0.92)
      ..lineTo(w * 0.66, h * 0.92)
      ..lineTo(w * 0.66, h * 0.54)
      ..lineTo(w * 0.76, h * 0.66)
      ..lineTo(w * 0.82, h * 0.32)
      ..lineTo(w * 0.65, h * 0.12)
      ..lineTo(w * 0.58, h * 0.20)
      ..lineTo(w * 0.42, h * 0.20)
      ..close();
    canvas.drawPath(outline, fog);
    final y = h * 0.26;
    canvas.drawLine(Offset(w * 0.35, y), Offset(w * 0.65, y), gold);
    canvas.drawLine(Offset(w * 0.35, y - 5), Offset(w * 0.35, y + 5), gold);
    canvas.drawLine(Offset(w * 0.65, y - 5), Offset(w * 0.65, y + 5), gold);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// The HOME trend slot: renders the indexed-source state or the honest
/// inactive one. Inactive is the real default until a trend source exists.
class _TrendSlot extends StatelessWidget {
  const _TrendSlot({required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      borderRadius: BorderRadius.circular(AppSpacing.unit * 2),
      padding: const EdgeInsets.all(AppSpacing.unit * 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'STYLE RIGHT NOW',
                style: AppType.data.copyWith(
                  fontSize: 10.5,
                  letterSpacing: 1.4,
                  color: AppColors.textSecondary,
                ),
              ),
              if (connected) ...[
                const SizedBox(width: AppSpacing.unit),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.unit,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppColors.spotlightGold.withValues(alpha: 0.4),
                    ),
                    borderRadius: BorderRadius.circular(AppSpacing.unit * 3),
                  ),
                  child: Text(
                    'SAMPLE',
                    style: AppType.data.copyWith(
                      fontSize: 9,
                      letterSpacing: 1.0,
                      color: AppColors.spotlightGold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.unit * 1.5),
          if (connected) ...[
            Text(
              'Relaxed tailoring is having a moment — this look leans into '
              'it.',
              style: AppType.interface.copyWith(
                fontSize: 13.5,
                height: 1.45,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.unit),
            Text(
              'SOURCE: TREND_FEED (name TBD) · REFRESHED WEEKLY · effect '
              'appears as a real factor in How the score is built',
              style: AppType.data.copyWith(
                fontSize: 10,
                height: 1.5,
                letterSpacing: 0.6,
                color: AppColors.textSecondary,
              ),
            ),
          ] else ...[
            Text(
              'Trend context isn’t connected yet.',
              style: AppType.interface.copyWith(
                fontSize: 13.5,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.unit),
            Text(
              'SCORED ON FIT · WEATHER · OCCASION · YOUR STYLE PROFILE — '
              'NOTHING GUESSED',
              style: AppType.data.copyWith(
                fontSize: 10,
                height: 1.5,
                letterSpacing: 0.6,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
