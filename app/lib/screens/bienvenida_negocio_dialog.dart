import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';

/// Datos del perfil del negocio y su dueño.
class DatosNegocio {
  final String nombreDueno;
  final String nombreNegocio;
  final String direccion;
  final String correo;
  final String telefono;

  const DatosNegocio({
    required this.nombreDueno,
    required this.nombreNegocio,
    required this.direccion,
    required this.correo,
    required this.telefono,
  });
}

/// Ventana emergente de bienvenida para registrar (o editar) los datos del
/// dueño y del negocio.
class BienvenidaNegocioDialog extends StatefulWidget {
  final DatosNegocio? datosIniciales;
  final bool esEdicion;

  const BienvenidaNegocioDialog({
    super.key,
    this.datosIniciales,
    this.esEdicion = false,
  });

  /// Clave en SharedPreferences por usuario para saber si ya completó el paso.
  static String _claveCompletado(String uid) => 'bienvenida_completada_$uid';
  static String _claveDueno(String uid) => 'negocio_dueno_$uid';
  static String _claveNombre(String uid) => 'negocio_nombre_$uid';
  static String _claveDireccion(String uid) => 'negocio_direccion_$uid';
  static String _claveTelefono(String uid) => 'negocio_telefono_$uid';

  /// Obtiene los datos guardados del usuario actual desde la fila de `negocios`
  /// (con respaldo en userMetadata y SharedPreferences).
  static Future<DatosNegocio?> obtenerDatosActuales({
    Map<String, dynamic>? filaNegocio,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;

    final meta = user.userMetadata ?? const <String, dynamic>{};
    final prefs = await SharedPreferences.getInstance();

    final dueno =
        (filaNegocio?['nombre_dueno'] ??
                meta['nombre_dueno'] ??
                prefs.getString(_claveDueno(user.id)) ??
                '')
            .toString()
            .trim();
    final negocio =
        (filaNegocio?['nombre_negocio'] ??
                filaNegocio?['nombre'] ??
                meta['nombre_negocio'] ??
                prefs.getString(_claveNombre(user.id)) ??
                '')
            .toString()
            .trim();
    final direccion =
        (filaNegocio?['direccion'] ??
                meta['direccion'] ??
                prefs.getString(_claveDireccion(user.id)) ??
                '')
            .toString()
            .trim();
    final telefono =
        (filaNegocio?['telefono'] ??
                meta['telefono_negocio'] ??
                prefs.getString(_claveTelefono(user.id)) ??
                '')
            .toString()
            .trim();

    return DatosNegocio(
      nombreDueno: dueno,
      nombreNegocio: negocio == 'Mi almacén' ? '' : negocio,
      direccion: direccion,
      correo: (filaNegocio?['correo'] ?? user.email ?? '').toString(),
      telefono: telefono,
    );
  }

  /// Indica si el usuario actual ya completó la ventana de bienvenida.
  static Future<bool> yaCompletoBienvenida({
    Map<String, dynamic>? filaNegocio,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return true;

    // Si en la tabla `negocios` ya tiene cargado el nombre del dueño,
    // ya completó la bienvenida.
    final duenoEnTabla =
        (filaNegocio?['nombre_dueno'] ?? '').toString().trim();
    if (duenoEnTabla.isNotEmpty) return true;

    final meta = user.userMetadata;
    if (meta != null && meta['bienvenida_completada'] == true) {
      return true;
    }

    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_claveCompletado(user.id)) ?? false;
  }

  /// Abre la ventana emergente y devuelve los [DatosNegocio] si se guardaron.
  static Future<DatosNegocio?> mostrar(
    BuildContext context, {
    DatosNegocio? datosIniciales,
    bool esEdicion = false,
  }) {
    return showDialog<DatosNegocio>(
      context: context,
      barrierDismissible: esEdicion,
      builder: (_) => BienvenidaNegocioDialog(
        datosIniciales: datosIniciales,
        esEdicion: esEdicion,
      ),
    );
  }

  @override
  State<BienvenidaNegocioDialog> createState() =>
      _BienvenidaNegocioDialogState();
}

class _BienvenidaNegocioDialogState extends State<BienvenidaNegocioDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _duenoCtrl;
  late final TextEditingController _negocioCtrl;
  late final TextEditingController _direccionCtrl;
  late final TextEditingController _correoCtrl;
  late final TextEditingController _telefonoCtrl;

  bool _guardando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final emailSesion =
        Supabase.instance.client.auth.currentUser?.email ?? '';
    final d = widget.datosIniciales;

    _duenoCtrl = TextEditingController(text: d?.nombreDueno ?? '');
    _negocioCtrl = TextEditingController(text: d?.nombreNegocio ?? '');
    _direccionCtrl = TextEditingController(text: d?.direccion ?? '');
    _correoCtrl = TextEditingController(
      text: (d?.correo.isNotEmpty ?? false) ? d!.correo : emailSesion,
    );
    _telefonoCtrl = TextEditingController(text: d?.telefono ?? '');
  }

  @override
  void dispose() {
    _duenoCtrl.dispose();
    _negocioCtrl.dispose();
    _direccionCtrl.dispose();
    _correoCtrl.dispose();
    _telefonoCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _guardando = true;
      _error = null;
    });

    final dueno = _duenoCtrl.text.trim();
    final negocio = _negocioCtrl.text.trim();
    final direccion = _direccionCtrl.text.trim();
    final correo = _correoCtrl.text.trim();
    final telefono = _telefonoCtrl.text.trim();

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) {
        throw StateError('No hay sesión activa.');
      }

      // 1. Guardamos directamente en la tabla `negocios` de Supabase.
      await supabase.from('negocios').upsert({
        'id': user.id,
        'nombre_dueno': dueno,
        'nombre_negocio': negocio,
        'direccion': direccion,
        'correo': correo,
        'telefono': telefono,
      });

      // 2. Guardamos tambien en los metadatos del usuario de Supabase Auth.
      await supabase.auth.updateUser(
        UserAttributes(
          data: {
            'nombre_dueno': dueno,
            'nombre_negocio': negocio,
            'direccion': direccion,
            'telefono_negocio': telefono,
            'bienvenida_completada': true,
          },
        ),
      );

      // 3. Guardamos copia local en SharedPreferences para respuesta inmediata.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(
        BienvenidaNegocioDialog._claveCompletado(user.id),
        true,
      );
      await prefs.setString(
        BienvenidaNegocioDialog._claveDueno(user.id),
        dueno,
      );
      await prefs.setString(
        BienvenidaNegocioDialog._claveNombre(user.id),
        negocio,
      );
      await prefs.setString(
        BienvenidaNegocioDialog._claveDireccion(user.id),
        direccion,
      );
      await prefs.setString(
        BienvenidaNegocioDialog._claveTelefono(user.id),
        telefono,
      );

      await HapticFeedback.mediumImpact();

      if (!mounted) return;
      Navigator.of(context).pop(
        DatosNegocio(
          nombreDueno: dueno,
          nombreNegocio: negocio,
          direccion: direccion,
          correo: correo,
          telefono: telefono,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = 'No se pudo guardar la información. Revisa tu conexión.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: AppTheme.bordeDe(context)),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppTheme.acentoDe(context).withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.storefront_rounded,
                      size: 30,
                      color: AppTheme.acentoDe(context),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  widget.esEdicion
                      ? 'Datos de tu negocio'
                      : '¡Bienvenido a Fiado Inteligente!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.esEdicion
                      ? 'Actualiza la información de contacto de tu almacén.'
                      : 'Cuéntanos sobre ti y tu negocio para personalizar tu cuenta.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: AppTheme.textoTenueDe(context),
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _duenoCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Nombre del dueño',
                    hintText: 'Ej. Juan Pérez',
                    prefixIcon: Icon(
                      Icons.person_outline,
                      color: AppTheme.acentoDe(context),
                    ),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Escribe el nombre del dueño'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _negocioCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Nombre del negocio',
                    hintText: 'Ej. Almacén Don Juan',
                    prefixIcon: Icon(
                      Icons.store_outlined,
                      color: AppTheme.acentoDe(context),
                    ),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Escribe el nombre del negocio'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _direccionCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Dirección',
                    hintText: 'Ej. Av. Los Pajaritos 1234',
                    prefixIcon: Icon(
                      Icons.location_on_outlined,
                      color: AppTheme.acentoDe(context),
                    ),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Escribe la dirección del negocio'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _correoCtrl,
                  readOnly: true,
                  enabled: false,
                  decoration: InputDecoration(
                    labelText: 'Correo electrónico',
                    prefixIcon: Icon(
                      Icons.mail_outline,
                      color: AppTheme.textoTenueDe(context),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _telefonoCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Teléfono de contacto',
                    hintText: 'Ej. +56 9 1234 5678',
                    prefixIcon: Icon(
                      Icons.phone_outlined,
                      color: AppTheme.acentoDe(context),
                    ),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Escribe un teléfono de contacto'
                      : null,
                  onFieldSubmitted: (_) => _guardar(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.morosoDe(context),
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: AppTheme.degradadoDe(context),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                    ),
                    onPressed: _guardando ? null : _guardar,
                    child: _guardando
                        ? SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppTheme.sobreAcentoDe(context),
                            ),
                          )
                        : Text(
                            widget.esEdicion
                                ? 'Guardar cambios'
                                : 'Guardar y comenzar',
                            style: TextStyle(
                              color: AppTheme.sobreAcentoDe(context),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
                if (widget.esEdicion) ...[
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: _guardando
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

