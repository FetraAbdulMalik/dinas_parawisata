import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../theme.dart';
import 'faq_screen.dart';
import 'favorites_screen.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'map_screen.dart';
import 'profile_screen.dart';
import '../widgets/copyright_footer.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

/// Kerangka utama: AppBar hijau + menu samping + navigasi bawah 4 tab.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell>
    with SingleTickerProviderStateMixin {
  int _tab = 0;
  int? _pendingTab;
  late final AnimationController _tabTransitionController;
  late final Animation<double> _tabOpacity;
  bool _searching = false;
  final _searchCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabTransitionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    )..addListener(_applyPendingTab);
    _tabOpacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1, end: 0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0, end: 1)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 50,
      ),
    ]).animate(_tabTransitionController);
  }

  @override
  void dispose() {
    _tabTransitionController.dispose();
    _searchCtl.dispose();
    super.dispose();
  }

  void _applyPendingTab() {
    if (_tabTransitionController.value < 0.5 || _pendingTab == null) return;
    final nextTab = _pendingTab!;
    _pendingTab = null;
    if (mounted) setState(() => _tab = nextTab);
  }

  void _toggleSearch() {
    setState(() => _searching = !_searching);
    if (!_searching) {
      _searchCtl.clear();
      context.read<AppState>().setQuery('');
    }
  }

  void _goTab(int i) {
    if ((i == 1 || i == 2) && context.read<AppState>().user == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text(
                'Silakan masuk atau daftar untuk membuka Peta dan Favorit.'),
            action: SnackBarAction(
              label: 'Masuk',
              onPressed: () {
                Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LoginScreen()));
              },
            ),
          ),
        );
      return;
    }
    if (i == _tab && _pendingTab == null) return;
    _pendingTab = i;
    if (!_tabTransitionController.isAnimating) {
      _tabTransitionController.forward(from: 0);
    }
  }

  Widget _drawerItem(String label, VoidCallback onTap) => ListTile(
        dense: true,
        title: Text(label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        onTap: () {
          Navigator.of(context).pop();
          onTap();
        },
      );

  Widget _desktopNavigation() {
    return Container(
      width: 220,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Row(
              children: [
                Image.asset(
                  'assets/images/logo_guriang_garut_header.png',
                  width: 34,
                  height: 44,
                  fit: BoxFit.contain,
                  semanticLabel: 'Logo Guriang Garut',
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'GURIANG GARUT',
                    style: TextStyle(
                      fontFamily: 'serif',
                      fontSize: 14,
                      letterSpacing: 0.7,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _desktopNavItem(0, Icons.home_outlined, 'Beranda'),
          _desktopNavItem(1, Icons.location_on_outlined, 'Peta'),
          _desktopNavItem(2, Icons.favorite_border, 'Favorit'),
          _desktopNavItem(3, Icons.person_outline, 'Profil'),
          const Divider(height: 32),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('FAQ'),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const FaqScreen())),
          ),
          const Spacer(),
          const CopyrightFooter(),
        ],
      ),
    );
  }

  Widget _desktopNavItem(int index, IconData icon, String label) {
    final selected = _tab == index;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        leading: Icon(icon, color: selected ? AppColors.green : AppColors.text),
        title: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.green : AppColors.text,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        selected: selected,
        selectedTileColor: AppColors.green.withValues(alpha: 0.10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        onTap: () => _goTab(index),
      ),
    );
  }

  Widget _accountAction(AppState state, bool isWide) {
    final isSignedIn = state.user != null;
    final onPressed = isSignedIn
        ? () => _goTab(3)
        : () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const LoginScreen()));

    if (isWide && !isSignedIn) {
      return TextButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.person_outline),
        label: const Text('Masuk'),
        style: TextButton.styleFrom(foregroundColor: Colors.white),
      );
    }

    return IconButton(
      tooltip: isSignedIn ? 'Profil' : 'Masuk',
      onPressed: onPressed,
      icon: Icon(
        isSignedIn ? Icons.account_circle : Icons.account_circle_outlined,
        size: 30,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isWide = MediaQuery.sizeOf(context).width >= 900;
    final tabContent = FadeTransition(
      opacity: _tabOpacity,
      child: IndexedStack(
        index: _tab,
        children: [
          HeroMode(enabled: _tab == 0, child: const HomeScreen()),
          HeroMode(
            enabled: _tab == 1,
            child: state.user == null
                ? const SizedBox.shrink()
                : MapScreen(isActive: _tab == 1),
          ),
          HeroMode(
            enabled: _tab == 2,
            child: state.user == null
                ? const SizedBox.shrink()
                : const FavoritesScreen(),
          ),
          HeroMode(enabled: _tab == 3, child: const ProfileScreen()),
        ],
      ),
    );
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        leading: isWide
            ? null
            : Builder(
                builder: (ctx) => IconButton(
                  icon: const Icon(Icons.menu, size: 34),
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                ),
              ),
        title: _searching
            ? TextField(
                controller: _searchCtl,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                cursorColor: Colors.white,
                decoration: const InputDecoration(
                  hintText: 'search lokasi/ sejarah',
                  hintStyle: TextStyle(color: Colors.white60),
                  border: InputBorder.none,
                ),
                onChanged: (v) => context.read<AppState>().setQuery(v),
              )
            : Row(
                children: [
                  Image.asset(
                    'assets/images/logo_guriang_garut_header.png',
                    width: 34,
                    height: 44,
                    fit: BoxFit.contain,
                    semanticLabel: 'Logo Guriang Garut',
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'GURIANG GARUT',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'serif',
                        fontSize: 17,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search, size: 32),
            onPressed: _toggleSearch,
          ),
          _accountAction(state, isWide),
          const SizedBox(width: 8),
        ],
      ),
      drawer: isWide
          ? null
          : Drawer(
              backgroundColor: Colors.white.withValues(alpha: 0.95),
              child: PointerInterceptor(
                child: SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      _drawerItem('HOME', () => _goTab(0)),
                      _drawerItem('PETA BUDAYA', () => _goTab(1)),
                      _drawerItem('FAVORITE', () => _goTab(2)),
                      _drawerItem(
                          'FAQ',
                          () => Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => const FaqScreen()))),
                      const Spacer(),
                      _drawerItem('PROFILE', () => _goTab(3)),
                      const CopyrightFooter(),
                    ],
                  ),
                ),
              ),
            ),
      body: isWide
          ? Row(
              children: [
                _desktopNavigation(),
                const VerticalDivider(width: 1, thickness: 1),
                Expanded(child: tabContent),
              ],
            )
          : tabContent,
      bottomNavigationBar: isWide
          ? null
          : PointerInterceptor(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
                ),
                child: SafeArea(
                  child: SizedBox(
                    height: 64,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _navIcon(0, Icons.home_outlined, Icons.home_filled),
                        _navIcon(
                            1, Icons.location_on_outlined, Icons.location_on),
                        _navIcon(2, Icons.favorite_border, Icons.favorite),
                        _navIcon(3, Icons.person_outline, Icons.person),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _navIcon(int i, IconData off, IconData on) {
    final selected = _tab == i;
    return IconButton(
      iconSize: 34,
      onPressed: () => _goTab(i),
      icon: Icon(selected ? on : off,
          color: selected ? Colors.black : AppColors.text),
    );
  }
}
