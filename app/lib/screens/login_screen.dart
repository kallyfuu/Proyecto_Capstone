import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';

/// Login del almacenero (RF05).
///
/// Sin sesion iniciada, `auth.uid()` es null y el RLS bloquea todo. Por eso
/// esta pantalla no es un tramite: es la que habilita el resto de la app.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _cargando = false;
  bool _modoRegistro = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final auth = Supabase.instance.client.auth;
      final email = _emailCtrl.text.trim();
      final password = _passCtrl.text;

      if (_modoRegistro) {
        await auth.signUp(email: email, password: password);
      } else {
        await auth.signInWithPassword(email: email, password: password);
      }
      // Si sale bien no navegamos a mano: el AuthGate de main.dart escucha el
      // cambio de sesion y cambia de pantalla solo.
    } on AuthException catch (e) {
      setState(() => _error = _mensajeAmigable(e.message));
    } catch (_) {
      setState(() => _error = 'No se pudo conectar. Revisa tu internet.');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  /// Supabase responde en ingles; el almacenero no tiene por que leer eso.
  String _mensajeAmigable(String mensaje) {
    final m = mensaje.toLowerCase();
    if (m.contains('invalid login')) {
      return 'Correo o contraseña incorrectos.';
    }
    if (m.contains('already registered') || m.contains('already been')) {
      return 'Ese correo ya tiene una cuenta. Inicia sesión.';
    }
    if (m.contains('password')) {
      return 'La contraseña debe tener al menos 6 caracteres.';
    }
    return mensaje;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.storefront,
                      size: 64,
                      color: AppTheme.azulProfundo,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Fiado NFC',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.azulProfundo,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'El cuaderno de fiados, en tu celular',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textoTenue),
                    ),
                    const SizedBox(height: 36),
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Correo',
                        prefixIcon: Icon(Icons.mail_outline),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Escribe tu correo';
                        }
                        if (!v.contains('@')) return 'Correo inválido';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Contraseña',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Escribe tu contraseña';
                        }
                        if (v.length < 6) return 'Mínimo 6 caracteres';
                        return null;
                      },
                      onFieldSubmitted: (_) => _enviar(),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.moroso.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: AppTheme.moroso,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _error!,
                                style: const TextStyle(color: AppTheme.moroso),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _cargando ? null : _enviar,
                      child: _cargando
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _modoRegistro ? 'Crear cuenta' : 'Iniciar sesión',
                            ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _cargando
                          ? null
                          : () => setState(() {
                              _modoRegistro = !_modoRegistro;
                              _error = null;
                            }),
                      child: Text(
                        _modoRegistro
                            ? 'Ya tengo cuenta, iniciar sesión'
                            : 'Soy nuevo, crear una cuenta',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
