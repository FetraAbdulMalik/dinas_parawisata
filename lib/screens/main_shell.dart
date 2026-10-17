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

/// Kerangka utama: AppBar hijau + menu samping + navigasi bawah 4 tab.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;
  bool _searching = false;
  final _searchCtl = TextEditingController();

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
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
    setState(() => _tab = i);
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

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        leading: Builder(
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
                    'assets/images/logo_guriang_garut.png',
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
          const SizedBox(width: 8),
        ],
      ),
      drawer: Drawer(
        backgroundColor: Colors.white.withValues(alpha: 0.8),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.only(right: 16, bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Image.asset(
                      'assets/images/logo_kabupaten_garut_transparent.png',
                      width: 34,
                      height: 34,
                      fit: BoxFit.contain,
                      semanticLabel: 'Lambang Kabupaten Garut',
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 100,
                      height: 38,
                      child: Image.asset(
                        'assets/images/logo_disparbud_garut_transparent.png',
                        fit: BoxFit.contain,
                        semanticLabel: 'Logo Disparbud Garut',
                      ),
                    ),
                  ],
                ),
              ),
              _drawerItem('HOME', () => _goTab(0)),
              _drawerItem('PETA BUDAYA', () => _goTab(1)),
              _drawerItem('FAVORITE', () => _goTab(2)),
              _drawerItem(
                  'FAQ',
                  () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const FaqScreen()))),
              const Spacer(),
              _drawerItem('PROFILE', () => _goTab(3)),
              const CopyrightFooter(),
            ],
          ),
        ),
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          const HomeScreen(),
          state.user == null ? const SizedBox.shrink() : const MapScreen(),
          state.user == null
              ? const SizedBox.shrink()
              : const FavoritesScreen(),
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: Container(
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
                _navIcon(1, Icons.location_on_outlined, Icons.location_on),
                _navIcon(2, Icons.favorite_border, Icons.favorite),
                _navIcon(3, Icons.person_outline, Icons.person),
              ],
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
