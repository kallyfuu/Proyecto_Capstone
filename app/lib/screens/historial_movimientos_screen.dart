import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/cliente_saldo.dart';
import '../theme/app_theme.dart';
import '../utils/formato.dart';

/// Un movimiento individual del historial (una fila de `transacciones`).
///
/// No es un modelo compartido como `ClienteSaldo` porque, por ahora, solo lo
/// usa esta pantalla. Si otra pantalla necesita transacciones más adelante,
/// esto se puede mover a `models/`.
class _Movimiento {
  final String concepto;
  final int monto;
  final DateTime fecha;

  const _Movimiento({
    required this.concepto,
    required this.monto,
    required this.fecha,
  });

  factory _Movimiento.desdeMapa(Map<String, dynamic> mapa) {
    return _Movimiento(
      concepto: (mapa['concepto'] ?? '').toString(),
      monto: (mapa['monto'] as num).toInt(),
      // fecha_local se guarda en UTC (ver registrar_movimiento_sheet.dart);
      // toLocal() la pasa a la hora del dispositivo para mostrarla.
      fecha: DateTime.parse(mapa['fecha_local'] as String).toLocal(),
    );
  }

  /// Igual que en el resto de la app: negativo = fiado, positivo = abono.
  bool get esFiado => monto < 0;
}

/// Historial de movimientos de un cliente: qué le fiaron y qué ha abonado.
///
/// Se abre desde el formulario de registrar movimiento, con el cliente ya
/// elegido (misma idea que `RegistrarMovimientoSheet`).
class HistorialMovimientosScreen extends StatefulWidget {
  final ClienteSaldo cliente;

  const HistorialMovimientosScreen({super.key, required this.cliente});

  @override
  State<HistorialMovimientosScreen> createState() =>
      _HistorialMovimientosScreenState();
}

class _HistorialMovimientosScreenState
    extends State<HistorialMovimientosScreen> {
  final _supabase = Supabase.instance.client;

  List<_Movimiento> _movimientos = const [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      // Igual que en el dashboard: no filtramos por negocio_id a mano, el RLS
      // ya se encarga de que solo veamos lo que nos corresponde.
      final filas = await _supabase
          .from('transacciones')
          .select()
          .eq('cliente_id', widget.cliente.id)
          .order('fecha_local', ascending: false);

      if (!mounted) return;

      setState(() {
        _movimientos = filas.map(_Movimiento.desdeMapa).toList();
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.cliente.nombre),
      ),
      body: _cuerpo(),
    );
  }

  Widget _cuerpo() {
    if (_cargando && _movimientos.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _mensajeCentrado(
        icono: Icons.cloud_off,
        color: AppTheme.moroso,
        titulo: 'No se pudo cargar',
        detalle: _error!,
      );
    }

    if (_movimientos.isEmpty) {
      return _mensajeCentrado(
        icono: Icons.receipt_long_outlined,
        color: AppTheme.textoTenue,
        titulo: 'Todavía no hay movimientos',
        detalle: 'Cuando registres un fiado o abono, aparecerá acá.',
      );
    }

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        itemCount: _movimientos.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) => _filaMovimiento(_movimientos[i]),
      ),
    );
  }

  Widget _filaMovimiento(_Movimiento mov) {
    final color = mov.esFiado ? AppTheme.moroso : AppTheme.cumplidor;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(
              mov.esFiado ? Icons.add_shopping_cart : Icons.payments_outlined,
              color: color,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mov.concepto,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _formatoFecha(mov.fecha),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textoTenue,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${mov.esFiado ? '-' : '+'}${formatoCLP(mov.monto.abs())}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mensajeCentrado({
    required IconData icono,
    required Color color,
    required String titulo,
    required String detalle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icono, size: 56, color: color),
            const SizedBox(height: 16),
            Text(
              titulo,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              detalle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textoTenue),
            ),
          ],
        ),
      ),
    );
  }

  /// Formato simple dd/mm/aaaa hh:mm, sin depender del paquete `intl`
  /// (el proyecto no lo tiene agregado todavía en pubspec.yaml).
  String _formatoFecha(DateTime fecha) {
    String dosDigitos(int n) => n.toString().padLeft(2, '0');
    final dia = dosDigitos(fecha.day);
    final mes = dosDigitos(fecha.month);
    final hora = dosDigitos(fecha.hour);
    final min = dosDigitos(fecha.minute);
    return '$dia/$mes/${fecha.year} $hora:$min';
  }
}
