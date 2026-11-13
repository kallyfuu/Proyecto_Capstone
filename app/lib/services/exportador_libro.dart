import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/texto.dart';

/// Baja el libro de fiados completo a un archivo que se abre en Excel.
///
/// Existe por dos razones y las dos importan. La primera es que el vendedor no
/// quede preso de la app: su libro es suyo y tiene que poder sacarlo. La
/// segunda es la pregunta obvia, "y si pierde el telefono": con el respaldo
/// bajado, pierde el telefono y no el historial.
class ExportadorLibro {
  /// Separador de columnas.
  ///
  /// Punto y coma, no coma. El Excel en espanol usa el punto y coma como
  /// separador de listas: con comas, toda la fila aterriza en una sola celda
  /// y el vendedor ve un archivo inservible.
  static const String separador = ';';

  /// Marca de orden de bytes al principio del archivo.
  ///
  /// Sin esto Excel abre el CSV como si fuera ANSI y los nombres con tilde o
  /// con enie salen rotos: "Maria Gonzalez" se ve "MarÃ­a GonzÃ¡lez". Es el
  /// detalle que hace que el archivo parezca de juguete.
  static const String bom = '﻿';

  /// Arma el CSV a partir de las filas ya cruzadas con el nombre del cliente.
  ///
  /// Funcion pura y separada a proposito: asi se puede probar el formato
  /// completo sin base de datos ni telefono.
  static String generarCsv(List<Map<String, dynamic>> movimientos) {
    final lineas = <String>[
      [
        'Fecha',
        'Hora',
        'Cliente',
        'Tipo',
        'Concepto',
        'Monto',
        'Boleta',
        'Registrado sin conexion',
      ].join(separador),
    ];

    for (final m in movimientos) {
      final monto = (m['monto'] as num?)?.toInt() ?? 0;
      // El signo es lo que distingue fiado de abono en el libro mayor. En el
      // archivo se separa en una columna "Tipo" y un monto positivo, porque
      // un numero negativo en una planilla se lee como error, no como fiado.
      final esFiado = monto < 0;
      final fecha = _fechaLocal(m['fecha_local']);

      lineas.add(
        [
          _campo(_soloFecha(fecha)),
          _campo(_soloHora(fecha)),
          _campo(m['cliente'] ?? 'Cliente eliminado'),
          _campo(esFiado ? 'Fiado' : 'Abono'),
          _campo(m['concepto'] ?? ''),
          // Sin separador de miles: Excel tiene que leerlo como numero para
          // poder sumarlo, y un "37.500" se lo traga como texto.
          _campo(monto.abs().toString()),
          _campo(m['numero_boleta'] ?? ''),
          _campo(m['es_offline'] == true ? 'Si' : 'No'),
        ].join(separador),
      );
    }

    // Excel es mas tolerante con los finales de linea de Windows que al reves.
    return '$bom${lineas.join('\r\n')}\r\n';
  }

  /// Nombre del archivo, con la fecha para que no se pisen dos respaldos.
  ///
  /// Las tildes y la enie se transliteran antes de limpiar, no se descartan.
  /// Si no, "Botilleria Don Bastian" con sus tildes termina llamandose
  /// "botiller_a_don_basti_n", que es lo que el vendedor ve en su carpeta de
  /// descargas y lo que se adjunta al mandarlo por WhatsApp.
  static String nombreArchivo(String negocio, DateTime cuando) {
    final limpio = normalizar(negocio)
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final dia = '${cuando.year}-${_dos(cuando.month)}-${_dos(cuando.day)}';
    return 'libro_fiados_${limpio.isEmpty ? 'negocio' : limpio}_$dia.csv';
  }

  /// Canal hacia MainActivity.kt, que guarda en Descargas via MediaStore.
  ///
  /// Desde Android 11 una app no puede escribir directo en esa carpeta, y
  /// pedirselo al sistema no se puede hacer desde Dart.
  static const MethodChannel _canalDescargas =
      MethodChannel('cl.capstone.fiado/descargas');

  /// Trae el libro y lo deja guardado en la carpeta Descargas del telefono.
  ///
  /// Si el sistema no lo permite (Android 9 o anterior, o el usuario tiene
  /// restringido el almacenamiento) vuelve sola al menu de compartir en vez
  /// de dejar al vendedor sin respaldo.
  ///
  /// `guardadoComo` trae el nombre del archivo si quedo en Descargas, y es
  /// null si hubo que compartir. `huboLibro` distingue ese caso del de un
  /// negocio que todavia no tiene ningun movimiento: los dos dejan
  /// `guardadoComo` vacio, pero al vendedor hay que decirle cosas distintas.
  static Future<({String? guardadoComo, bool huboLibro})> descargar({
    required SupabaseClient supabase,
    String? nombreNegocio,
  }) async {
    final libro = await _prepararLibro(
      supabase: supabase,
      nombreNegocio: nombreNegocio,
    );
    if (libro == null) return (guardadoComo: null, huboLibro: false);

    try {
      final guardado = await _canalDescargas.invokeMethod<String>(
        'guardarEnDescargas',
        {
          'nombre': libro.nombre,
          'contenido': libro.bytes,
          'tipo': 'text/csv',
        },
      );
      if (guardado != null) {
        return (guardadoComo: guardado, huboLibro: true);
      }
    } on PlatformException {
      // El sistema no dejo guardar. No es motivo para quedarse sin respaldo.
    } on MissingPluginException {
      // Corriendo en una plataforma sin el canal, por ejemplo el navegador.
    }

    await _compartir(libro);
    return (guardadoComo: null, huboLibro: true);
  }

  /// Trae el libro entero y abre el menu de compartir con el archivo listo.
  ///
  /// Ninguna consulta filtra por negocio, igual que en el resto de la app: de
  /// eso se encarga el RLS del motor, que ya se probo desde fuera de la red.
  ///
  /// Devuelve cuantos movimientos salieron, o null si no habia ninguno.
  static Future<int?> exportar({
    required SupabaseClient supabase,
    String? nombreNegocio,
  }) async {
    final libro = await _prepararLibro(
      supabase: supabase,
      nombreNegocio: nombreNegocio,
    );
    if (libro == null) return null;

    await _compartir(libro);
    return libro.movimientos;
  }

  /// Trae el libro y lo deja listo para guardar o compartir.
  ///
  /// Devuelve null si el negocio todavia no tiene ningun movimiento: generar
  /// un archivo con solo el encabezado seria peor que avisar.
  static Future<_Libro?> _prepararLibro({
    required SupabaseClient supabase,
    String? nombreNegocio,
  }) async {
    // Los clientes se traen aparte y el cruce se hace aca en vez de pedirle
    // el join a PostgREST: la llave foranea de transacciones es compuesta
    // (cliente_id, negocio_id) y el join implicito se vuelve ambiguo.
    final clientes = await supabase.from('clientes').select('id, nombre');

    final nombrePorId = {
      for (final c in clientes) c['id'] as String: c['nombre'] as String?,
    };

    final filas = await supabase
        .from('transacciones')
        .select('cliente_id, monto, concepto, numero_boleta, es_offline, fecha_local')
        .order('fecha_local', ascending: false);

    if (filas.isEmpty) return null;

    final movimientos = [
      for (final f in filas)
        {...f, 'cliente': nombrePorId[f['cliente_id']] ?? 'Cliente eliminado'},
    ];

    // El nombre del negocio solo decora el archivo. Si la pantalla que llama
    // no lo tiene a mano se busca aca, y si tampoco esta no se aborta el
    // respaldo por un detalle del nombre.
    final negocio = nombreNegocio ?? await _nombreDelNegocio(supabase);

    return _Libro(
      nombre: nombreArchivo(negocio, DateTime.now()),
      bytes: Uint8List.fromList(utf8.encode(generarCsv(movimientos))),
      negocio: negocio,
      movimientos: movimientos.length,
    );
  }

  static Future<void> _compartir(_Libro libro) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            libro.bytes,
            mimeType: 'text/csv',
            name: libro.nombre,
          ),
        ],
        // XFile.fromData no lleva nombre propio al compartir: sin esto el
        // archivo llega como "file" y nadie sabe que es.
        fileNameOverrides: [libro.nombre],
        subject: 'Libro de fiados de ${libro.negocio}',
      ),
    );
  }

  static Future<String> _nombreDelNegocio(SupabaseClient supabase) async {
    try {
      final filas =
          await supabase.from('negocios').select('nombre_negocio').limit(1);
      final nombre =
          filas.isEmpty ? null : filas.first['nombre_negocio'] as String?;
      return (nombre == null || nombre.trim().isEmpty) ? 'negocio' : nombre;
    } catch (_) {
      return 'negocio';
    }
  }

  /// Escapa un valor para que un punto y coma dentro del texto no parta la
  /// fila en dos columnas.
  static String _campo(Object? valor) {
    final texto = '$valor';
    if (!texto.contains(separador) &&
        !texto.contains('"') &&
        !texto.contains('\n') &&
        !texto.contains('\r')) {
      return texto;
    }
    return '"${texto.replaceAll('"', '""')}"';
  }

  /// fecha_local viene en UTC (ver registrar_movimiento_sheet.dart). El
  /// respaldo lo lee una persona, asi que va en la hora del telefono.
  static DateTime? _fechaLocal(Object? cruda) {
    if (cruda == null) return null;
    return DateTime.tryParse('$cruda')?.toLocal();
  }

  static String _soloFecha(DateTime? f) =>
      f == null ? '' : '${_dos(f.day)}/${_dos(f.month)}/${f.year}';

  static String _soloHora(DateTime? f) =>
      f == null ? '' : '${_dos(f.hour)}:${_dos(f.minute)}';

  static String _dos(int n) => n.toString().padLeft(2, '0');
}

/// El archivo ya armado, antes de decidir si se guarda o se comparte.
class _Libro {
  const _Libro({
    required this.nombre,
    required this.bytes,
    required this.negocio,
    required this.movimientos,
  });

  final String nombre;
  final Uint8List bytes;
  final String negocio;
  final int movimientos;
}
