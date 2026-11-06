import 'package:flutter/material.dart';
import 'screens/dashboard_screen.dart';
import 'screens/rules_screen.dart';
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
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF00796B), // Deep Teal
              brightness: Brightness.light,
              primary: const Color(0xFF00695C),
              surface: const Color(0xFFFBFBFD),
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
      LogsScreen(key: ValueKey('logs_$langCode')),
      IosInfoScreen(key: ValueKey('guide_$langCode')),
    ];

    return Scaffold(
      appBar: _currentIndex == 0
          ? AppBar(
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.webhook, color: Colors.teal, size: 22),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Notifymee',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
                  ),
                ],
              ),
              actions: [
                // Language Switcher (ID / EN)
                IconButton(
                  tooltip: appLocaleNotifier.isIndonesian ? 'Switch to English' : 'Ganti ke Bahasa Indonesia',
                  onPressed: () {
                    appLocaleNotifier.toggleLanguage();
                  },
                  icon: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.teal.shade300),
                    ),
                    child: Text(
                      appLocaleNotifier.isIndonesian ? 'ID | EN' : 'EN | ID',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.teal),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: i18n.btnSetupGuide,
                  icon: const Icon(Icons.settings_suggest_outlined),
                  onPressed: () => SetupGuideDialog.showIfNeeded(context, force: true),
                ),
                IconButton(
                  tooltip: i18n.tabGuide,
                  icon: const Icon(Icons.help_outline),
                  onPressed: () => _navigateTab(3),
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
        indicatorColor: Colors.teal.shade100,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.dashboard_outlined),
            selectedIcon: const Icon(Icons.dashboard, color: Colors.teal),
            label: i18n.tabDashboard,
          ),
          NavigationDestination(
            icon: const Icon(Icons.filter_alt_outlined),
            selectedIcon: const Icon(Icons.filter_alt, color: Colors.teal),
            label: i18n.tabRules,
          ),
          NavigationDestination(
            icon: const Icon(Icons.history_outlined),
            selectedIcon: const Icon(Icons.history, color: Colors.teal),
            label: i18n.tabLogs,
          ),
          NavigationDestination(
            icon: const Icon(Icons.menu_book_outlined),
            selectedIcon: const Icon(Icons.menu_book, color: Colors.teal),
            label: i18n.tabGuide,
          ),
        ],
      ),
    );
  }
}
