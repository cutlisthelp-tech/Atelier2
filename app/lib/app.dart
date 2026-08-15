import 'dart:ui' show ImageFilter;

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

class AtelierApp extends StatefulWidget {
  const AtelierApp({
    super.key,
    this.modelManager,
    this.consentStore,
    this.styleStore,
    this.backendClient,
  });

  final ModelManager? modelManager;
  final ConsentStore? consentStore;
  final StyleProfileStore? styleStore;
  final BackendClient? backendClient;

  @override
  State<AtelierApp> createState() => _AtelierAppState();
}

class _AtelierAppState extends State<AtelierApp> {
  late final ModelManager _modelManager = widget.modelManager ?? ModelManager();
  late final KeyValueStore _store = FileKeyValueStore();
  late final ConsentStore _consentStore =
      widget.consentStore ?? ConsentStore(_store);
  late final StyleProfileStore _styleStore =
      widget.styleStore ?? StyleProfileStore(_store);
  late final BackendClient _backendClient =
      widget.backendClient ?? BackendClient();
  int _tab = 0;

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
        body: IndexedStack(
          index: _tab,
          children: [
            const HomeScreen(),
            const DiscoverScreen(),
            const TryOnScreen(),
            WardrobeScreen(backendClient: _backendClient),
            ProfileScreen(
              modelManager: _modelManager,
              consentStore: _consentStore,
              styleStore: _styleStore,
              backendClient: _backendClient,
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
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surfacePrimary.withValues(alpha: 0.66),
            border: Border(top: BorderSide(color: AppColors.borderSubtle)),
          ),
          child: SafeArea(
            child: SizedBox(
              height: 56,
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
    final color = selected ? AppColors.textPrimary : AppColors.textSecondary;
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: AppSpacing.minTapTarget,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppType.interface.copyWith(
                fontSize: 9,
                letterSpacing: 1.1,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
