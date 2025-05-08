import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pamasuka/login_page.dart';
import 'package:pamasuka/app_theme.dart'; // Assuming app_theme.dart is in lib/
import 'package:pamasuka/theme_provider.dart'; // Assuming theme_provider.dart is in lib/

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

void main() async { // Added async
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky); // This might be better handled by theme or per-page
  // It's generally recommended to initialize providers at the top level.
  // SharedPreferences initialization is handled within ThemeNotifier, so no need to await here explicitly for that.
  runApp(
    ChangeNotifierProvider<ThemeNotifier>(
      create: (_) => ThemeNotifier(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Access the ThemeNotifier
    final themeNotifier = Provider.of<ThemeNotifier>(context);

    return MaterialApp(
      title: 'Samalonian',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeNotifier.themeMode, // Use themeMode from ThemeNotifier
      navigatorObservers: [routeObserver],
      home: const LoginPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

