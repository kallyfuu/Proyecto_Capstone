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
  static const String _versionTerminos = '1.0';

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

    // Conforme a la Ley N° 21.719, el registro de un nuevo usuario responsable
    // requiere consentimiento informado y aceptación expresa de términos.
    String? fechaAceptacion;
    if (_modoRegistro) {
      final acepto = await _mostrarDialogoTerminos();
      if (acepto != true) return;
      fechaAceptacion = DateTime.now().toUtc().toIso8601String();
    }

    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final auth = Supabase.instance.client.auth;
      final email = _emailCtrl.text.trim();
      final password = _passCtrl.text;

      if (_modoRegistro) {
        final respuesta = await auth.signUp(
          email: email,
          password: password,
          data: {
            'acepto_terminos': true,
            'fecha_aceptacion_terminos': fechaAceptacion,
            'version_terminos': _versionTerminos,
          },
        );
        // Si Supabase pide confirmar el correo antes de abrir sesion,
        // el trigger SQL copia el consentimiento desde user_metadata a
        // public.negocios; avisamos con ventana emergente y volvemos al login.
        if (respuesta.session == null) {
          if (mounted) {
            setState(() => _cargando = false);
            await _mostrarDialogoConfirmacion(email);
            if (mounted) {
              setState(() {
                _modoRegistro = false;
                _entroBien = false;
                _passCtrl.clear();
              });
            }
          }
          return;
        }
        // Si la sesion se abrio de inmediato, actualizamos tambien la fila en
        // public.negocios directamente.
        if (respuesta.user != null) {
          try {
            await Supabase.instance.client
                .from('negocios')
                .update({
                  'acepto_terminos': true,
                  'fecha_aceptacion_terminos': fechaAceptacion,
                  'version_terminos': _versionTerminos,
                })
                .eq('id', respuesta.user!.id);
          } catch (_) {
            // Si la migracion SQL aun no se ha corrido, se sincroniza luego en Dashboard.
          }
        }
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

  /// Muestra solo los 2 primeros caracteres antes del @ y reemplaza el resto con 'x'.
  String _ocultarCorreo(String email) {
    final partes = email.split('@');
    if (partes.length != 2) return email;
    final usuario = partes[0];
    final dominio = partes[1];
    if (usuario.length <= 2) {
      return '${usuario}xxx@$dominio';
    }
    final visibles = usuario.substring(0, 2);
    final ocultos = 'x' * (usuario.length - 2);
    return '$visibles$ocultos@$dominio';
  }

  /// Muestra el pop-up de aceptación de Términos y Condiciones y Tratamiento
  /// de Datos Personales bajo la Ley N° 21.719 al registrar un nuevo usuario.
  Future<bool?> _mostrarDialogoTerminos() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _DialogoTerminosLey(),
    );
  }

  /// Muestra una ventana emergente avisando que debe confirmar su correo.
  Future<void> _mostrarDialogoConfirmacion(String email) {
    final correoOculto = _ocultarCorreo(email);
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppTheme.bordeDe(ctx)),
        ),
        icon: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppTheme.acentoDe(ctx).withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.mark_email_read_outlined,
            color: AppTheme.acentoDe(ctx),
            size: 28,
          ),
        ),
        title: const Text(
          'Confirma tu correo',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 19),
        ),
        content: Text(
          'Le ha llegado una confirmación a su email ($correoOculto).\n\n'
          'Confirme su dirección de email desde su bandeja de entrada para poder iniciar sesión.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            height: 1.45,
            color: AppTheme.textoTenueDe(ctx),
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          SizedBox(
            width: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppTheme.degradadoDe(ctx),
                borderRadius: BorderRadius.circular(14),
              ),
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                ),
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(
                  'Volver al login',
                  style: TextStyle(
                    color: AppTheme.sobreAcentoDe(ctx),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Supabase responde en ingles; el almacenero no tiene por que leer eso.
  String _mensajeAmigable(String mensaje) {
    final m = mensaje.toLowerCase();
    if (m.contains('email not confirmed')) {
      return 'Aún no confirmas tu correo. Revisa tu bandeja de entrada.';
    }
    if (m.contains('invalid login') ||
        m.contains('invalid credentials') ||
        m.contains('invalid_credentials')) {
      return 'Correo o contraseña incorrectos.';
    }
    if (m.contains('already registered') || m.contains('already been')) {
      return 'Ese correo ya tiene una cuenta. Inicia sesión.';
    }
    // Solo cuando el error habla DEL LARGO de la contraseña.
    //
    // Antes esta regla atrapaba cualquier mensaje que dijera "password" y lo
    // traducia a "muy corta". Eso no solo mentia: tapaba el error de verdad,
    // asi que el problema quedaba invisible.
    if (m.contains('at least') ||
        m.contains('too short') ||
        m.contains('6 characters')) {
      return 'La contraseña debe tener al menos 6 caracteres.';
    }
    if (m.contains('rate limit') || m.contains('too many')) {
      return 'Demasiados intentos seguidos. Espera un momento.';
    }
    if (m.contains('user not found')) {
      return 'No existe una cuenta con ese correo.';
    }
    // Lo que no sabemos traducir se muestra tal cual. Un mensaje raro en
    // ingles es incomodo, pero se puede diagnosticar; uno traducido mal, no.
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

/// Diálogo emergente que solicita confirmación de Términos y Condiciones
/// y explica el tratamiento de la información personal conforme a la Ley N° 21.719.
class _DialogoTerminosLey extends StatefulWidget {
  const _DialogoTerminosLey();

  @override
  State<_DialogoTerminosLey> createState() => _DialogoTerminosLeyState();
}

class _DialogoTerminosLeyState extends State<_DialogoTerminosLey> {
  bool _expandido = false;

  @override
  Widget build(BuildContext context) {
    final acento = AppTheme.acentoDe(context);
    final textoTenue = AppTheme.textoTenueDe(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: AppTheme.bordeDe(context)),
      ),
      contentPadding: const EdgeInsets.fromLTRB(22, 20, 22, 12),
      actionsPadding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
      icon: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: acento.withValues(alpha: 0.14),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.verified_user_outlined,
          color: acento,
          size: 28,
        ),
      ),
      title: Column(
        children: [
          const Text(
            'Términos y Privacidad',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 19),
          ),
          const SizedBox(height: 4),
          Text(
            'Ley N° 21.719 de Protección de Datos Personales',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: acento,
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 420,
          maxHeight: MediaQuery.sizeOf(context).height * 0.55,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: acento.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: acento.withValues(alpha: 0.22),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      color: acento,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Acepto los términos y condiciones de utilizar mi información personal para la gestión de mi cuenta y la administración del fiado.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Al registrarte, autorizas el tratamiento de tus datos para la prestación del servicio conforme a las normas de protección de datos.',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: textoTenue,
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: () => setState(() => _expandido = !_expandido),
                  icon: Icon(
                    _expandido
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: acento,
                  ),
                  label: Text(
                    _expandido
                        ? 'Ocultar información'
                        : 'Leer más: ¿dónde se ocupa mi información?',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: acento,
                    ),
                  ),
                ),
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.fondoDe(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.bordeDe(context)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _seccionDetalle(
                        context,
                        titulo: '1. ¿Dónde se almacena tu información?',
                        descripcion:
                            'Tu correo y credenciales se almacenan en una base de datos segura (Supabase). Cada almacén cuenta con políticas de aislamiento a nivel de fila (Row Level Security), impidiendo que cualquier otro negocio acceda a tus datos.',
                      ),
                      const SizedBox(height: 10),
                      _seccionDetalle(
                        context,
                        titulo: '2. ¿Para qué se ocupa?',
                        descripcion:
                            'Exclusivamente para autenticarte, sincronizar tus registros de fiados y abonos, respaldar la información de tu almacén y generar resúmenes contables.',
                      ),
                      const SizedBox(height: 10),
                      _seccionDetalle(
                        context,
                        titulo: '3. Privacidad desde el diseño (Art. 14 quáter)',
                        descripcion:
                            'Los llaveros NFC entregados a tus clientes no almacenan nombres, teléfonos ni saldos. Solo portan un identificador seguro para consultar la cuenta en el servidor.',
                      ),
                      const SizedBox(height: 10),
                      _seccionDetalle(
                        context,
                        titulo: '4. Tus derechos como titular (Derechos ARCO)',
                        descripcion:
                            'Conforme a la Ley N° 21.719, tienes derecho a acceder a tus datos, rectificarlos, solicitar su supresión (derecho al olvido) y oponerte al tratamiento.',
                      ),
                    ],
                  ),
                ),
                crossFadeState: _expandido
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 250),
              ),
            ],
          ),
        ),
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Cancelar',
                  style: TextStyle(
                    color: textoTenue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: AppTheme.degradadoDe(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(
                    'Aceptar',
                    style: TextStyle(
                      color: AppTheme.sobreAcentoDe(context),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _seccionDetalle(
    BuildContext context, {
    required String titulo,
    required String descripcion,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          descripcion,
          style: TextStyle(
            fontSize: 11.5,
            height: 1.35,
            color: AppTheme.textoTenueDe(context),
          ),
        ),
      ],
    );
  }
}
