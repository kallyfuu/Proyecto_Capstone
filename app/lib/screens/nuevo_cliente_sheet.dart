import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_theme.dart';
import '../utils/formato.dart';

/// Dar de alta un cliente nuevo.
///
/// Solo el nombre es obligatorio: cuando llega alguien nuevo al almacen y hay
/// cola, pedirle telefono y limite de credito frena la venta. Esos datos se
/// pueden completar despues.
///
/// El `nfc_uid` queda vacio a proposito. El llavero se asocia cuando exista el
/// lector NFC; por eso la columna es nullable y el UNIQUE es compuesto
/// (negocio_id, nfc_uid), que en Postgres admite varios nulos.
class NuevoClienteSheet extends StatefulWidget {
  const NuevoClienteSheet({super.key});

  /// Devuelve true si se creo el cliente, para que la lista se refresque.
  static Future<bool> mostrar(BuildContext context) async {
    final creado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const NuevoClienteSheet(),
    );
    return creado ?? false;
  }

  @override
  State<NuevoClienteSheet> createState() => _NuevoClienteSheetState();
}

class _NuevoClienteSheetState extends State<NuevoClienteSheet> {
  final _nombreCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _limiteCtrl = TextEditingController();

  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _telefonoCtrl.dispose();
    _limiteCtrl.dispose();
    super.dispose();
  }

  int get _limite => int.tryParse(_limiteCtrl.text.replaceAll('.', '')) ?? 0;

  Future<void> _guardar() async {
    final nombre = _nombreCtrl.text.trim();

    if (nombre.isEmpty) {
      setState(() => _error = 'Escribe el nombre del cliente.');
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      final supabase = Supabase.instance.client;
      final telefono = _telefonoCtrl.text.trim();

      // `negocio_id` sale de la sesion, nunca de un campo del formulario: es
      // la misma condicion que exige el RLS para dejar pasar el INSERT.
      final creados = await supabase.from('clientes').insert({
        'negocio_id': supabase.auth.currentUser!.id,
        'nombre': nombre,
        'telefono': telefono.isEmpty ? null : telefono,
        'limite_credito': _limite,
        'estado_riesgo': 'Cumplidor',
      }).select();

      if (creados.isEmpty) {
        throw StateError('La base no devolvio el cliente creado.');
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _guardando = false;
        _error = _mensajeAmigable('$e');
      });
    }
  }

  String _mensajeAmigable(String error) {
    if (error.contains('23505')) {
      return 'Ya tienes un cliente con esos datos.';
    }
    return 'No se pudo guardar: $error';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: AppTheme.superficie,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        // Al 24 de abajo le sumamos el area segura: si no, la barra de
        // navegacion del celular se come el boton cuando el teclado esta bajo.
        // Con el teclado arriba este valor es 0 y manda el viewInsets de arriba.
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          24 + MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFDADCE0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Nuevo cliente',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            const Text(
              'Solo el nombre es obligatorio',
              style: TextStyle(color: AppTheme.textoTenue),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nombreCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                prefixIcon: Icon(Icons.person_outline),
              ),
              onChanged: (_) => setState(() => _error = null),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _telefonoCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Teléfono (opcional)',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _limiteCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Límite de crédito (opcional)',
                prefixText: '\$ ',
                prefixIcon: Icon(Icons.speed_outlined),
              ),
              onChanged: (_) => setState(() {}),
            ),
            if (_limite > 0) ...[
              const SizedBox(height: 8),
              Text(
                'Hasta ${formatoCLP(_limite)} de fiado',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textoTenue,
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(
                _error!,
                style: const TextStyle(color: AppTheme.moroso),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _guardando ? null : _guardar,
              child: _guardando
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Guardar cliente'),
            ),
          ],
        ),
      ),
    );
  }
}
