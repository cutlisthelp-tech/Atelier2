import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'config/feature_flags.dart';
import 'services/backend_client.dart';
import 'services/local_store.dart';
import 'services/model_manager.dart';
import 'theme/tokens.dart';
import 'ui/screens/discover_screen.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/profile_screen.dart';
import 'ui/screens/try_on_screen.dart';
import 'ui/screens/wardrobe_screen.dart';
import 'ui/widgets/editorial_backdrop.dart';

class AtelierApp extends StatefulWidget {
  const AtelierApp({
    super.key,
    this.modelManager,
    this.consentStore,
    this.styleStore,
    this.backendClient,
    this.keyValueStore,
  });

  final ModelManager? modelManager;
  final ConsentStore? consentStore;
  final StyleProfileStore? styleStore;
  final BackendClient? backendClient;
  final KeyValueStore? keyValueStore;

  @override
  State<AtelierApp> createState() => _AtelierAppState();
}

class _AtelierAppState extends State<AtelierApp> {
  late final ModelManager _modelManager = widget.modelManager ?? ModelManager();
  // The web preview has no app data directory: a session-only in-memory
  // store keeps the flows demonstrable there, labeled honestly in the UI.
  late final KeyValueStore _store =
      widget.keyValueStore ?? (kIsWeb ? InMemoryKeyValueStore() : FileKeyValueStore());
  static const bool _sessionStorage = kIsWeb;
  late final ConsentStore _consentStore =
      widget.consentStore ?? ConsentStore(_store);
  late final StyleProfileStore _styleStore = StyleProfileStore(_store);
  late final BackendClient _backendClient =
      widget.backendClient ?? BackendClient();
  late final ScanRecordStore _bodyStore = ScanRecordStore.body(_store);
  late final ScanRecordStore _appearanceStore = ScanRecordStore.appearance(
    _store,
  );
  late final WardrobeStore _wardrobeStore = WardrobeStore(_store);
  late final HomePlaceStore _homePlaceStore = HomePlaceStore(_store);
  int _tab = 0;

  /// One campaign scene per section; switching tabs crossfades the world
  /// instead of cutting it (assets/editorial/PROVENANCE.md).
  static const _scenes = [
    'assets/editorial/scene_03.jpg', // HOME
    'assets/editorial/scene_04.jpg', // DISCOVER
    'assets/editorial/scene_02.jpg', // TRY ON
    'assets/editorial/scene_01.jpg', // WARDROBE
    'assets/editorial/scene_02.jpg', // PROFILE
  ];

  @override
  void initState() {
    super.initState();
    _modelManager.discover();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppInfo.name,
      debugShowCheckedModeBanner: false,
      theme: buildAtelierTheme(),
      home: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        body: Stack(
          children: [
            EditorialBackdrop(scene: _scenes[_tab]),
            IndexedStack(
              index: _tab,
              children: [
                HomeScreen(
                  backendClient: _backendClient,
                  bodyStore: _bodyStore,
                  appearanceStore: _appearanceStore,
                  styleStore: _styleStore,
                  wardrobeStore: _wardrobeStore,
                  homePlaceStore: _homePlaceStore,
                  sessionStorage: _sessionStorage,
                  onOpenTab: (i) => setState(() => _tab = i),
                ),
                const DiscoverScreen(),
                TryOnScreen(backendClient: _backendClient),
                WardrobeScreen(
                  backendClient: _backendClient,
                  wardrobeStore: _wardrobeStore,
                  bodyStore: _bodyStore,
                  appearanceStore: _appearanceStore,
                  styleStore: _styleStore,
                  homePlaceStore: _homePlaceStore,
                  sessionStorage: _sessionStorage,
                  onOpenTab: (i) => setState(() => _tab = i),
                ),
                ProfileScreen(
                  modelManager: _modelManager,
                  consentStore: _consentStore,
                  styleStore: _styleStore,
                  backendClient: _backendClient,
                  bodyStore: _bodyStore,
                  appearanceStore: _appearanceStore,
                  wardrobeStore: _wardrobeStore,
                  sessionStorage: _sessionStorage,
                  onOpenTab: (i) => setState(() => _tab = i),
                ),
              ],
            ),
          ],
        ),
        bottomNavigationBar: _GlassNavBar(
          currentIndex: _tab,
          onSelect: (i) => setState(() => _tab = i),
        ),
      ),
    );
  }
}

/// Glass is reserved for a small number of primary surfaces — the nav bar is
/// one of them (docs/DESIGN_SYSTEM.md §1, §2 material spec).
class _GlassNavBar extends StatelessWidget {
  const _GlassNavBar({required this.currentIndex, required this.onSelect});

  static const _tabs = ['HOME', 'DISCOVER', 'TRY ON', 'WARDROBE', 'PROFILE'];
  static const _icons = [
    Icons.home_outlined,
    Icons.explore_outlined,
    Icons.auto_awesome_outlined,
    Icons.checkroom_outlined,
    Icons.person_outline,
  ];

  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      base: AppGlass.navBase,
      alpha: AppGlass.navAlpha,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      border: Border(top: BorderSide(color: AppColors.borderHairline)),
      child: SafeArea(
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              for (var i = 0; i < _tabs.length; i++)
                Expanded(
                  child: _NavItem(
                    label: _tabs[i],
                    icon: _icons[i],
                    selected: i == currentIndex,
                    onTap: () => onSelect(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.textPrimary : AppColors.textTertiary;
    return InkWell(
      onTap: onTap,
      splashColor: AppColors.spotlightGold.withValues(alpha: 0.08),
      highlightColor: AppColors.spotlightGold.withValues(alpha: 0.05),
      child: SizedBox(
        height: AppSpacing.minTapTarget,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              child: Icon(
                selected ? _filled(icon) : icon,
                key: ValueKey(selected),
                size: 20,
                color: color,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: AppType.caption.copyWith(
                fontSize: 8.5,
                letterSpacing: 1.4,
                color: color,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOut,
              width: selected ? 14 : 3,
              height: 2,
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.spotlightGold
                    : AppColors.fog.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _filled(IconData outlined) => switch (outlined) {
        Icons.home_outlined => Icons.home,
        Icons.explore_outlined => Icons.explore,
        Icons.auto_awesome_outlined => Icons.auto_awesome,
        Icons.checkroom_outlined => Icons.checkroom,
        Icons.person_outline => Icons.person,
        _ => outlined,
      };
}
