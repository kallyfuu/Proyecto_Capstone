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
      body: Column(
        children: [
          _cabeceraCurva(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 26, 22, 26),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    children: [
                      Form(key: _formKey, child: _formulario(context)),
                      const SizedBox(height: 22),
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
                    begin: 0.06,
                    end: 0,
                    duration: 450.ms,
                    curve: Curves.easeOutCubic,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Cabecera con degradado y esquinas inferiores redondeadas.
  ///
  /// Reemplaza a la tarjeta flotando en blanco: el bloque de color le da piso
  /// a la pantalla y hace que el formulario se vea montado sobre algo, no
  /// suelto en el vacio.
  Widget _cabeceraCurva(BuildContext context) {
    final alto = MediaQuery.of(context).size.height;

    return Container(
      width: double.infinity,
      // Un tercio de la pantalla, con topes para que no se coma el formulario
      // en telefonos bajos ni quede una franja perdida en los altos.
      height: (alto * 0.33).clamp(220.0, 300.0),
      decoration: BoxDecoration(
        gradient: AppTheme.degradadoDe(context),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.22),
                    blurRadius: 26,
                  ),
                ],
              ),
              child: Icon(
                Icons.nfc_rounded,
                size: 38,
                color: AppTheme.sobreAcentoDe(context),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Fiado Inteligente',
              style: TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.6,
                color: AppTheme.sobreAcentoDe(context),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Gestión de fiado con NFC',
              style: TextStyle(
                fontSize: 13.5,
                color: AppTheme.sobreAcentoDe(
                  context,
                ).withValues(alpha: 0.82),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _formulario(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: InputDecoration(
            labelText: 'Correo',
            prefixIcon: Icon(
              Icons.mail_outline,
              color: AppTheme.acentoDe(context),
            ),
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Escribe tu correo';
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
            prefixIcon: Icon(
              Icons.lock_outline,
              color: AppTheme.acentoDe(context),
            ),
            suffixIcon: IconButton(
              tooltip: _verClave ? 'Ocultar' : 'Mostrar',
              icon: Icon(
                _verClave
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
              ),
              onPressed: () => setState(() => _verClave = !_verClave),
            ),
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Escribe tu contraseña';
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
              color: AppTheme.morosoDe(context).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
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
        // El boton cuenta en que va: espera, exito o listo para pulsar. El
        // verde con el visto dura un instante antes de que el AuthGate cambie
        // de pantalla, para que el salto no se sienta seco.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: _entroBien ? null : AppTheme.degradadoDe(context),
            color: _entroBien ? AppTheme.cumplidorDe(context) : null,
            borderRadius: BorderRadius.circular(16),
          ),
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
            ),
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
                      _modoRegistro ? 'Crear cuenta' : 'Iniciar sesión',
                      key: const ValueKey('texto'),
                      style: TextStyle(
                        color: AppTheme.sobreAcentoDe(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _cargando || _entroBien
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
    );
  }
}
