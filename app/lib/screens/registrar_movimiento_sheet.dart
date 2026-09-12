import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'historial_movimientos_screen.dart';

import '../models/cliente_saldo.dart';
import '../theme/app_theme.dart';
import '../utils/formato.dart';

/// Registrar un fiado o un abono para un cliente.
///
/// Se abre desde la lista, con el cliente ya elegido, porque en el almacen el
/// cliente esta parado al frente: lo que falta es el monto, no a quien.
class RegistrarMovimientoSheet extends StatefulWidget {
  final ClienteSaldo cliente;

  const RegistrarMovimientoSheet({super.key, required this.cliente});

  /// Devuelve true si se guardo algo, para que la lista se refresque.
  static Future<bool> mostrar(BuildContext context, ClienteSaldo cliente) async {
    final guardado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RegistrarMovimientoSheet(cliente: cliente),
    );
    return guardado ?? false;
  }

  @override
  State<RegistrarMovimientoSheet> createState() =>
      _RegistrarMovimientoSheetState();
}

class _RegistrarMovimientoSheetState extends State<RegistrarMovimientoSheet> {
  final _montoCtrl = TextEditingController();
  final _conceptoCtrl = TextEditingController();

  bool _esFiado = true;
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _montoCtrl.dispose();
    _conceptoCtrl.dispose();
    super.dispose();
  }

  int get _monto => int.tryParse(_montoCtrl.text.replaceAll('.', '')) ?? 0;

  Future<void> _guardar() async {
    if (_monto <= 0) {
      setState(() => _error = 'Escribe un monto mayor a cero.');
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      final supabase = Supabase.instance.client;
      final negocioId = supabase.auth.currentUser!.id;

      // Pedimos que nos devuelva la fila insertada: si viene vacia, la base no
      // guardo nada y hay que enterarse aqui, no descubrirlo mirando la lista.
      final guardadas = await supabase.from('transacciones').insert({
        // El id lo genera la app, no la base. Asi un reintento despues de
        // perder señal manda el MISMO id y no duplica el movimiento.
        'id': const Uuid().v4(),
        'cliente_id': widget.cliente.id,
        'negocio_id': negocioId,
        // El signo es lo que distingue fiado de abono en el libro mayor.
        'monto': _esFiado ? -_monto : _monto,
        'concepto': _conceptoCtrl.text.trim().isEmpty
            ? (_esFiado ? 'Fiado' : 'Abono')
            : _conceptoCtrl.text.trim(),
        'es_offline': false,
        'fecha_local': DateTime.now().toUtc().toIso8601String(),
      }).select();

      if (guardadas.isEmpty) {
        throw StateError('La base no devolvio la fila insertada.');
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _guardando = false;
        _error = 'No se pudo guardar: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorAccion = _esFiado ? AppTheme.moroso : AppTheme.cumplidor;

    return Padding(
      // Sube el contenido cuando aparece el teclado.
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: AppTheme.superficie,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
            Text(
              widget.cliente.nombre,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              textoSaldo(widget.cliente.saldo),
              style: TextStyle(
                color: widget.cliente.debe
                    ? AppTheme.moroso
                    : AppTheme.cumplidor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: true,
                  label: Text('Fiar'),
                  icon: Icon(Icons.add_shopping_cart),
                ),
                ButtonSegment(
                  value: false,
                  label: Text('Abonar'),
                  icon: Icon(Icons.payments_outlined),
                ),
              ],
              selected: {_esFiado},
              onSelectionChanged: _guardando
                  ? null
                  : (s) => setState(() {
                      _esFiado = s.first;
                      _error = null;
                    }),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _montoCtrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
              decoration: const InputDecoration(
                labelText: 'Monto',
                prefixText: '\$ ',
              ),
              onChanged: (_) => setState(() => _error = null),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _conceptoCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Concepto (opcional)',
                hintText: _esFiado ? 'Pan, bebidas...' : 'Abono',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(
                _error!,
                style: const TextStyle(color: AppTheme.moroso),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: colorAccion),
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
                  : Text(
                      _monto > 0
                          ? '${_esFiado ? "Fiar" : "Abonar"} ${formatoCLP(_monto)}'
                          : (_esFiado ? 'Registrar fiado' : 'Registrar abono'),
                    ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _guardando
                  ? null
                  : () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              HistorialMovimientosScreen(cliente: widget.cliente),
                        ),
                      ),
              icon: const Icon(Icons.history),
              label: const Text('Ver historial'),
            ),
          ],
        ),
      ),
    );
  }
}
