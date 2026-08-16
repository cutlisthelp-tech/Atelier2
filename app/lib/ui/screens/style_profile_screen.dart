import 'package:flutter/material.dart';

import '../../services/local_store.dart';
import '../../theme/tokens.dart';
import '../widgets/empty_state.dart';

/// Real user input only — nothing here is pre-filled or inferred.
/// Persisted locally as JSON; Phase 9 migrates to remote sync.
class StyleProfileScreen extends StatefulWidget {
  const StyleProfileScreen({
    super.key,
    required this.store,
    this.sessionStorage = false,
  });

  final StyleProfileStore store;
  final bool sessionStorage;

  /// Must stay in sync with the backend FIT_SCALE — the ranking engine and
  /// the Phase 2 garment pipeline both handle all four fit values.
  static const fitOptions = ['slim', 'regular', 'relaxed', 'oversized'];
  static const aestheticOptions = [
    'minimal',
    'classic',
    'streetwear',
    'workwear',
    'avant-garde',
    'sporty',
  ];

  @override
  State<StyleProfileScreen> createState() => _StyleProfileScreenState();
}

class _StyleProfileScreenState extends State<StyleProfileScreen> {
  final _height = TextEditingController();
  final _bannedColors = TextEditingController();
  final _bannedBrands = TextEditingController();
  final _budget = TextEditingController();
  String _fit = 'regular';
  final Set<String> _aesthetics = {};
  bool _loaded = false;
  bool _storageUnavailable = false;
  String? _savedNote;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    StyleProfile? profile;
    try {
      profile = await widget.store.load();
    } catch (_) {
      // e.g. the web preview has no local file storage — say so, don't hang.
      if (mounted) {
        setState(() {
          _storageUnavailable = true;
          _loaded = true;
        });
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      if (profile != null) {
        if (profile.heightCm != null) _height.text = profile.heightCm.toString();
        _fit = profile.fitPreference;
        _aesthetics.addAll(profile.aesthetics);
        _bannedColors.text = profile.bannedColors.join(', ');
        _bannedBrands.text = profile.bannedBrands.join(', ');
        if (profile.budgetCeiling != null) {
          _budget.text = profile.budgetCeiling.toString();
        }
      }
      _loaded = true;
    });
  }

  List<String> _split(String raw) => raw
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  Future<void> _save() async {
    final height = double.tryParse(_height.text.trim());
    if (_height.text.trim().isNotEmpty && (height == null || height < 100 || height > 250)) {
      setState(() => _savedNote = 'Height must be between 100 and 250 cm.');
      return;
    }
    final budget = double.tryParse(_budget.text.trim());
    if (_budget.text.trim().isNotEmpty && (budget == null || budget <= 0)) {
      setState(() => _savedNote = 'Budget must be a positive number.');
      return;
    }
    try {
      await widget.store.save(
        StyleProfile(
          heightCm: height,
          fitPreference: _fit,
          aesthetics: _aesthetics.toList()..sort(),
          bannedColors: _split(_bannedColors.text),
          bannedBrands: _split(_bannedBrands.text),
          budgetCeiling: budget,
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() =>
            _savedNote = 'Local storage is unavailable on this platform.');
      }
      return;
    }
    if (mounted) setState(() => _savedNote = 'Saved — on this device only.');
  }

  @override
  void dispose() {
    _height.dispose();
    _bannedColors.dispose();
    _bannedBrands.dispose();
    _budget.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Style profile', style: AppType.interface)),
      body: SafeArea(
        child: !_loaded
            ? const Center(child: Text('Loading…', style: AppType.interface))
            : _storageUnavailable
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.unit * 3),
                  child: Text(
                    'Local storage is unavailable here, so the style profile '
                    'can\u2019t be saved. Run Atelier on Android for the full '
                    'flow.',
                    textAlign: TextAlign.center,
                    style: AppType.interface.copyWith(
                      fontSize: 15,
                      height: 1.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.unit * 3),
                children: [
                  if (widget.sessionStorage) const SessionNote(),
                  _label('HEIGHT (CM)'),
                  TextField(
                    controller: _height,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: 'e.g. 178'),
                    style: AppType.data.copyWith(color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: AppSpacing.unit * 2),
                  _label('FIT PREFERENCE'),
                  SegmentedButton<String>(
                    style: const ButtonStyle(
                      minimumSize: WidgetStatePropertyAll(
                        Size(0, AppSpacing.minTapTarget),
                      ),
                    ),
                    segments: [
                      for (final fit in StyleProfileScreen.fitOptions)
                        ButtonSegment(
                          value: fit,
                          label: Text(
                            fit[0].toUpperCase() + fit.substring(1),
                          ),
                        ),
                    ],
                    selected: {_fit},
                    onSelectionChanged: (s) => setState(() {
                      _fit = s.first;
                      _savedNote = null;
                    }),
                  ),
                  const SizedBox(height: AppSpacing.unit * 2),
                  _label('AESTHETICS'),
                  Wrap(
                    spacing: AppSpacing.half,
                    runSpacing: AppSpacing.half,
                    children: [
                      for (final a in StyleProfileScreen.aestheticOptions)
                        FilterChip(
                          label: Text(a),
                          // 44pt minimum tap target (DESIGN_SYSTEM §2).
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          selected: _aesthetics.contains(a),
                          onSelected: (on) => setState(() {
                            on ? _aesthetics.add(a) : _aesthetics.remove(a);
                            _savedNote = null;
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.unit * 2),
                  _label('BANNED COLORS (COMMA-SEPARATED)'),
                  TextField(
                    controller: _bannedColors,
                    decoration: const InputDecoration(hintText: 'e.g. neon green, beige'),
                    style: AppType.interface.copyWith(color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: AppSpacing.unit * 2),
                  _label('BANNED BRANDS (COMMA-SEPARATED)'),
                  TextField(
                    controller: _bannedBrands,
                    decoration: const InputDecoration(hintText: 'Optional'),
                    style: AppType.interface.copyWith(color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: AppSpacing.unit * 2),
                  _label('BUDGET CEILING'),
                  TextField(
                    controller: _budget,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: 'Optional'),
                    style: AppType.data.copyWith(color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: AppSpacing.unit * 3),
                  if (_savedNote != null) ...[
                    Text(
                      _savedNote!,
                      style: AppType.interface.copyWith(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.unit),
                  ],
                  SizedBox(
                    height: AppSpacing.minTapTarget,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.textPrimary,
                        foregroundColor: AppColors.surfacePrimary,
                      ),
                      onPressed: _save,
                      child: Text('Save', style: AppType.interface.copyWith(fontSize: 15)),
                    ),
                  ),
                ],
              ),
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
}
