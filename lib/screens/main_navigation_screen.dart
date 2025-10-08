import 'package:flutter/material.dart';
import 'package:bottom_navy_bar/bottom_navy_bar.dart';
import '../theme/app_colors.dart';
import 'home_screen.dart';
import 'search_screen.dart';
import 'watchlist_screen.dart';
import 'settings_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  // Lista de telas para o IndexedStack
  static const List<Widget> _screens = [
    HomeScreen(),
    SearchScreen(),
    WatchlistScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _currentIndex != 0) {
          setState(() => _currentIndex = 0);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: IndexedStack(index: _currentIndex, children: _screens),
        bottomNavigationBar: BottomNavyBar(
          backgroundColor: AppColors.surface,
          selectedIndex: _currentIndex,
          showElevation: true,
          onItemSelected: (index) {
            setState(() => _currentIndex = index);
          },
          items: [
            BottomNavyBarItem(
              icon: const Icon(Icons.home),
              title: const Text('Home'),
              activeColor: AppColors.primary,
              inactiveColor: Colors.grey,
              textAlign: TextAlign.center,
            ),
            BottomNavyBarItem(
              icon: const Icon(Icons.search),
              title: const Text('Pesquisa'),
              activeColor: AppColors.primary,
              inactiveColor: Colors.grey,
              textAlign: TextAlign.center,
            ),
            BottomNavyBarItem(
              icon: const Icon(Icons.bookmark),
              title: const Text('Watchlist'),
              activeColor: AppColors.primary,
              inactiveColor: Colors.grey,
              textAlign: TextAlign.center,
            ),
            BottomNavyBarItem(
              icon: const Icon(Icons.settings),
              title: const Text('Settings'),
              activeColor: AppColors.primary,
              inactiveColor: Colors.grey,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
