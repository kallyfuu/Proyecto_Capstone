import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.anonKey,
  );

  runApp(const FiadoApp());
}

class FiadoApp extends StatelessWidget {
  const FiadoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fiado NFC',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const AuthGate(),
    );
  }
}

/// Decide que pantalla mostrar segun haya sesion o no.
///
/// Escucha el flujo de autenticacion de Supabase, asi que ni el login ni el
/// boton de cerrar sesion necesitan navegar a mano: cambian la sesion y esta
/// pantalla reacciona sola. Ademas Supabase restaura la sesion guardada al
/// abrir la app, asi que el almacenero no tiene que loguearse cada vez.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final sesion =
            snapshot.data?.session ?? Supabase.instance.client.auth.currentSession;

        if (snapshot.connectionState == ConnectionState.waiting &&
            sesion == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return sesion == null ? const LoginScreen() : const DashboardScreen();
      },
    );
  }
}
