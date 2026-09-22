import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme.dart';
import 'providers/app_provider.dart';
import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'services/auth_service.dart';
import 'services/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase & Hive storage
  await SupabaseService.instance.initialize();

  // Initialize Auth service & restore saved session
  await AuthService.instance.initialize();

  final appProvider = AppProvider();
  await appProvider.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider.value(value: appProvider),
      ],
      child: const InvoiceApp(),
    ),
  );
}

class InvoiceApp extends StatelessWidget {
  const InvoiceApp({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final auth = context.watch<AuthProvider>();

    return MaterialApp(
      title: 'Invoice Manager',
      debugShowCheckedModeBanner: false,
      themeMode: app.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: auth.isAuthenticated ? const MainShell() : const LoginScreen(),
    );
  }
}
