import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'theme/app_theme.dart';
import 'theme/modo_tema.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.anonKey,
  );

  // Recupera el modo de tema que el usuario eligio la ultima vez.
  await ModoTema.cargar();

  runApp(const FiadoApp());
}

class FiadoApp extends StatelessWidget {
  const FiadoApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Se redibuja solo cuando el usuario cambia el modo desde el boton del
    // dashboard. Por defecto sigue al sistema (ThemeMode.system).
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ModoTema.modo,
      builder: (context, modo, _) => MaterialApp(
        title: 'Fiado NFC',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: modo,
        home: const AuthGate(),
      ),
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
