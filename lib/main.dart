import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/dashboard_screen.dart';
import 'screens/rules_screen.dart';
import 'screens/blacklist_screen.dart';
import 'screens/logs_screen.dart';
import 'screens/ios_info_screen.dart';
import 'screens/setup_guide_dialog.dart';
import 'services/app_localizations.dart';
import 'services/native_bridge.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NotifymeeApp());
}

class NotifymeeApp extends StatelessWidget {
  const NotifymeeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appLocaleNotifier,
      builder: (context, _) {
        final langCode = appLocaleNotifier.locale.languageCode;
        final i18n = I18n(appLocaleNotifier.locale);

        return MaterialApp(
          key: ValueKey('app_$langCode'),
          locale: appLocaleNotifier.locale,
          title: i18n.appTitle,
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            scaffoldBackgroundColor: const Color(0xFFF6FAF9),
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF00796B), // Deep Teal
              brightness: Brightness.light,
              primary: const Color(0xFF00695C),
              secondary: const Color(0xFF26A69A),
              surface: const Color(0xFFF6FAF9),
            ),
            appBarTheme: const AppBarTheme(
              centerTitle: false,
              elevation: 0,
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
            ),
          ),
          home: MainNavigationScreen(key: ValueKey('nav_$langCode')),
        );
      },
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  final NativeBridge _bridge = NativeBridge();
  int _currentIndex = 0;
  DateTime? _lastBackPressTime;

  Future<void> _navigateTab(int index) async {
    if (index != 0) {
      final perm = await _bridge.checkNotificationPermission();
      if (!perm) {
        if (mounted) {
          SetupGuideDialog.showIfNeeded(context, force: true);
        }
        return;
      }
    }
    setState(() {
      _currentIndex = index;
    });
  }

  void _handleBackPress() {
    if (_currentIndex != 0) {
      setState(() {
        _currentIndex = 0;
      });
      return;
    }
    final now = DateTime.now();
    if (_lastBackPressTime == null ||
        now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
      _lastBackPressTime = now;
      final i18n = I18n.of(context);
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF004D40),
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Row(
            children: [
              const Icon(Icons.exit_to_app, color: Color(0xFF80CBC4), size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text(i18n.pressBackAgainToExit)),
            ],
          ),
        ),
      );
    } else {
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final langCode = appLocaleNotifier.locale.languageCode;
    final i18n = I18n.of(context);

    final screens = [
      DashboardScreen(
        key: ValueKey('dashboard_$langCode'),
        onNavigateTab: _navigateTab,
      ),
      RulesScreen(key: ValueKey('rules_$langCode')),
      BlacklistScreen(key: ValueKey('blacklist_$langCode')),
      LogsScreen(key: ValueKey('logs_$langCode')),
      IosInfoScreen(key: ValueKey('guide_$langCode')),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _handleBackPress();
        }
      },
      child: Scaffold(
        appBar: _currentIndex == 0
            ? AppBar(
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2F1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFB2DFDB)),
                      ),
                      child: const Icon(Icons.webhook, color: Color(0xFF00695C), size: 22),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Notifymee',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 19,
                        color: Color(0xFF0F2926),
                      ),
                    ),
                  ],
                ),
                actions: [
                  IconButton(
                    tooltip: appLocaleNotifier.isIndonesian ? 'Switch to English' : 'Ganti ke Bahasa Indonesia',
                    onPressed: () {
                      appLocaleNotifier.toggleLanguage();
                    },
                    icon: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2F1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF80CBC4)),
                      ),
                      child: Text(
                        appLocaleNotifier.isIndonesian ? 'ID | EN' : 'EN | ID',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: Color(0xFF00695C),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: i18n.btnSetupGuide,
                    icon: const Icon(Icons.settings_suggest_outlined, color: Color(0xFF00695C)),
                    onPressed: () => SetupGuideDialog.showIfNeeded(context, force: true),
                  ),
                  IconButton(
                    tooltip: i18n.tabGuide,
                    icon: const Icon(Icons.help_outline, color: Color(0xFF00695C)),
                    onPressed: () => _navigateTab(4),
                  ),
                ],
              )
            : null,
        body: IndexedStack(
          key: ValueKey('stack_${langCode}_$_currentIndex'),
          index: _currentIndex,
          children: screens,
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: _navigateTab,
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFFB2DFDB),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.dashboard_outlined),
              selectedIcon: const Icon(Icons.dashboard, color: Color(0xFF00695C)),
              label: i18n.tabDashboard,
            ),
            NavigationDestination(
              icon: const Icon(Icons.filter_alt_outlined),
              selectedIcon: const Icon(Icons.filter_alt, color: Color(0xFF00695C)),
              label: i18n.tabRules,
            ),
            NavigationDestination(
              icon: const Icon(Icons.block_outlined),
              selectedIcon: const Icon(Icons.block, color: Color(0xFF00695C)),
              label: i18n.tabBlacklist,
            ),
            NavigationDestination(
              icon: const Icon(Icons.history_outlined),
              selectedIcon: const Icon(Icons.history, color: Color(0xFF00695C)),
              label: i18n.tabLogs,
            ),
            NavigationDestination(
              icon: const Icon(Icons.menu_book_outlined),
              selectedIcon: const Icon(Icons.menu_book, color: Color(0xFF00695C)),
              label: i18n.tabGuide,
            ),
          ],
        ),
      ),
    );
  }
}
