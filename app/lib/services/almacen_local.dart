import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Guarda en el teléfono lo último que se vio y lo que falta enviar.
///
/// El negocio de barrio es justamente donde peor señal hay: una bodega, un
/// subterráneo, un local con rejas. Si la app solo sirve con internet, no
/// sirve. Acá se resuelven las dos mitades del problema: poder *ver* la deuda
/// sin señal, y poder *registrar* un fiado sin señal.
class AlmacenLocal {
  static const _claveClientes = 'cache_clientes';
  static const _claveNegocio = 'cache_negocio';
  static const _claveFecha = 'cache_fecha';
  static const _claveCola = 'cola_movimientos';

  /// Cuántos movimientos esperan ser enviados.
  ///
  /// Es un notificador para que el encabezado lo muestre sin tener que
  /// preguntar: el vendedor tiene que saber en todo momento si quedó algo
  /// colgando, porque es plata que todavía no está registrada en ninguna parte
  /// salvo su teléfono.
  static final ValueNotifier<int> pendientes = ValueNotifier(0);

  // ---------------------------------------------------------------- caché

  /// Guarda la última vista buena, para poder mostrarla cuando no haya señal.
  static Future<void> guardarClientes(
    List<Map<String, dynamic>> clientes,
    String negocio,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_claveClientes, jsonEncode(clientes));
    await prefs.setString(_claveNegocio, negocio);
    await prefs.setString(_claveFecha, DateTime.now().toIso8601String());
  }

  static Future<({List<Map<String, dynamic>> clientes, String negocio,
      DateTime? fecha})?> leerClientes() async {
    final prefs = await SharedPreferences.getInstance();
    final crudo = prefs.getString(_claveClientes);
    if (crudo == null) return null;

    try {
      final lista = (jsonDecode(crudo) as List)
          .cast<Map<String, dynamic>>()
          .toList();
      return (
        clientes: lista,
        negocio: prefs.getString(_claveNegocio) ?? 'Mi negocio',
        fecha: DateTime.tryParse(prefs.getString(_claveFecha) ?? ''),
      );
    } catch (_) {
      // Caché corrupta: vale más no mostrar nada que mostrar datos rotos.
      return null;
    }
  }

  // ------------------------------------------------------------- cola

  /// Deja un movimiento esperando a que vuelva la señal.
  static Future<void> encolar(Map<String, dynamic> movimiento) async {
    final prefs = await SharedPreferences.getInstance();
    final cola = await _leerCola(prefs);
    cola.add(movimiento);
    await prefs.setString(_claveCola, jsonEncode(cola));
    pendientes.value = cola.length;
  }

  static Future<List<Map<String, dynamic>>> colaPendiente() async {
    return _leerCola(await SharedPreferences.getInstance());
  }

  static Future<void> refrescarConteo() async {
    pendientes.value = (await colaPendiente()).length;
  }

  static Future<List<Map<String, dynamic>>> _leerCola(
    SharedPreferences prefs,
  ) async {
    final crudo = prefs.getString(_claveCola);
    if (crudo == null) return [];
    try {
      return (jsonDecode(crudo) as List).cast<Map<String, dynamic>>().toList();
    } catch (_) {
      return [];
    }
  }

  /// Intenta enviar todo lo que quedó pendiente.
  ///
  /// Devuelve cuántos movimientos se enviaron. Los que fallan quedan en la
  /// cola para el próximo intento: no se pierden ni se dan por enviados.
  ///
  /// Reenviar es seguro porque el identificador de cada movimiento lo genera
  /// el teléfono y no el servidor. Si uno alcanzó a llegar y la respuesta se
  /// perdió, el segundo intento choca con la llave primaria y se descarta en
  /// vez de duplicar el cobro.
  static Future<int> sincronizar() async {
    final prefs = await SharedPreferences.getInstance();
    final cola = await _leerCola(prefs);
    if (cola.isEmpty) return 0;

    final supabase = Supabase.instance.client;
    final quedan = <Map<String, dynamic>>[];
    var enviados = 0;

    for (final movimiento in cola) {
      try {
        await supabase.from('transacciones').insert(movimiento);
        enviados++;
      } catch (e) {
        if (_yaEstaba(e)) {
          // Ya habia llegado en un intento anterior: se da por enviado.
          enviados++;
        } else {
          quedan.add(movimiento);
        }
      }
    }

    await prefs.setString(_claveCola, jsonEncode(quedan));
    pendientes.value = quedan.length;
    return enviados;
  }

  /// El código 23505 es violación de clave única: este movimiento ya existe
  /// en la base, así que el reintento cumplió su objetivo.
  static bool _yaEstaba(Object error) => '$error'.contains('23505');

  /// Borra todo lo guardado. Se llama al cerrar sesión: los datos de un
  /// negocio no pueden quedar en el teléfono para que los vea el siguiente.
  static Future<void> limpiar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_claveClientes);
    await prefs.remove(_claveNegocio);
    await prefs.remove(_claveFecha);
    await prefs.remove(_claveCola);
    pendientes.value = 0;
  }
}

/// Aplica los movimientos que todavía no se envían sobre los saldos guardados.
///
/// Sin esto, el vendedor registra un fiado sin señal y el saldo del cliente no
/// se mueve, así que piensa que no quedó. El número que ve tiene que incluir
/// lo que él acaba de hacer, aunque el servidor todavía no se haya enterado.
List<Map<String, dynamic>> aplicarPendientes(
  List<Map<String, dynamic>> clientes,
  List<Map<String, dynamic>> cola,
) {
  if (cola.isEmpty) return clientes;

  final ajustePorCliente = <String, int>{};
  for (final movimiento in cola) {
    final id = movimiento['cliente_id']?.toString();
    final monto = (movimiento['monto'] as num?)?.toInt() ?? 0;
    if (id == null) continue;
    ajustePorCliente[id] = (ajustePorCliente[id] ?? 0) + monto;
  }

  return clientes.map((cliente) {
    final ajuste = ajustePorCliente[cliente['id']?.toString()];
    if (ajuste == null) return cliente;

    final saldo = (cliente['saldo'] as num?)?.toInt() ?? 0;
    return {...cliente, 'saldo': saldo + ajuste};
  }).toList();
}
