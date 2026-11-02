import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
  bool _verClave = false;
  bool _entroBien = false;
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
      // cambio de sesion y cambia de pantalla solo. Antes de que eso pase,
      // dejamos el boton en verde con el visto para que la transicion no se
      // sienta un corte seco.
      if (mounted) setState(() => _entroBien = true);
      await Future<void>.delayed(const Duration(milliseconds: 550));
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
      backgroundColor: AppTheme.fondoDe(context),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              // Entrada suave, una sola vez. No se repite: una animacion que
              // vuelve a correr cada vez que algo cambia marea y cuesta cuadros.
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 30, 24, 26),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppTheme.bordeDe(context)),
                      boxShadow: AppTheme.sombraSuave,
                    ),
                    child:
                  Form(
                    key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppTheme.acentoDe(context),
                              AppTheme.azulClaro,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.acentoDe(
                                context,
                              ).withValues(alpha: 0.28),
                              blurRadius: 22,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.nfc_rounded,
                          size: 40,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'Fiado Inteligente',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 29,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.6,
                        color: AppTheme.acentoDe(context),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Gestión de fiado con NFC',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.textoTenueDe(context),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 34),
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
                      obscureText: !_verClave,
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: _verClave ? 'Ocultar' : 'Mostrar',
                          icon: Icon(
                            _verClave
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 20,
                          ),
                          onPressed: () =>
                              setState(() => _verClave = !_verClave),
                        ),
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
                          color: AppTheme.morosoDe(context).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: AppTheme.morosoDe(context),
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _error!,
                                style: TextStyle(color: AppTheme.morosoDe(context)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    // El boton cuenta en que va: espera, exito o listo para
                    // pulsar. El verde con el visto dura un instante antes de
                    // que el AuthGate cambie de pantalla, para que el salto al
                    // panel no se sienta seco.
                    FilledButton(
                      style: _entroBien
                          ? FilledButton.styleFrom(
                              backgroundColor: AppTheme.cumplidorDe(context),
                            )
                          : null,
                      onPressed: (_cargando || _entroBien) ? null : _enviar,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: _entroBien
                            ? Icon(
                                Icons.check_rounded,
                                key: const ValueKey('ok'),
                                color: AppTheme.sobreAcentoDe(context),
                              ).animate().scale(
                                begin: const Offset(0.4, 0.4),
                                end: const Offset(1, 1),
                                duration: 260.ms,
                                curve: Curves.easeOutBack,
                              )
                            : _cargando
                            ? SizedBox(
                                key: const ValueKey('cargando'),
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: AppTheme.sobreAcentoDe(context),
                                ),
                              )
                            : Text(
                                _modoRegistro
                                    ? 'Crear cuenta'
                                    : 'Iniciar sesión',
                                key: const ValueKey('texto'),
                              ),
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
                  const SizedBox(height: 20),
                  Text(
                    'Sistema de Fiado Inteligente  •  Versión 1.0',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppTheme.textoTenueDe(
                        context,
                      ).withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ).animate().fadeIn(duration: 450.ms).slideY(
                begin: 0.08,
                end: 0,
                duration: 450.ms,
                curve: Curves.easeOutCubic,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
