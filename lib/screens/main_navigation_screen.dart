import 'package:flutter/material.dart';
import 'package:bottom_navy_bar/bottom_navy_bar.dart';
import '../theme/app_colors.dart';
import 'home_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  // GlobalKeys para manter o estado de cada navegador
  final List<GlobalKey<NavigatorState>> _navigatorKeys = [
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
    GlobalKey<NavigatorState>(),
  ];

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // Permite voltar dentro da aba atual antes de sair do app
        final isFirstRouteInCurrentTab = !await _navigatorKeys[_currentIndex]
            .currentState!
            .maybePop();

        if (isFirstRouteInCurrentTab) {
          // Se não é a aba Home, vai para Home
          if (_currentIndex != 0) {
            setState(() => _currentIndex = 0);
            return;
          }
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            _buildOffstageNavigator(0),
            _buildOffstageNavigator(1),
            _buildOffstageNavigator(2),
          ],
        ),
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

  Widget _buildOffstageNavigator(int index) {
    return Offstage(
      offstage: _currentIndex != index,
      child: Navigator(
        key: _navigatorKeys[index],
        onGenerateRoute: (routeSettings) {
          return MaterialPageRoute(builder: (context) => _getScreen(index));
        },
      ),
    );
  }

  Widget _getScreen(int index) {
    switch (index) {
      case 0:
        return const HomeScreen();
      case 1:
        return const SearchScreen();
      case 2:
        return const SettingsScreen();
      default:
        return const HomeScreen();
    }
  }
}
