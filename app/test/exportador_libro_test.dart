import 'package:flutter_test/flutter_test.dart';

import 'package:fiado_nfc/services/exportador_libro.dart';

void main() {
  // Un fiado y un abono del mismo cliente, con tilde en el nombre a proposito.
  final movimientos = <Map<String, dynamic>>[
    {
      'cliente': 'María González',
      'monto': -37500,
      'concepto': 'Mercadería',
      'numero_boleta': '1234',
      'es_offline': false,
      'fecha_local': '2026-11-12T01:35:43.000Z',
    },
    {
      'cliente': 'Pedro Soto',
      'monto': 10000,
      'concepto': 'Abono',
      'numero_boleta': null,
      'es_offline': true,
      'fecha_local': '2026-11-12T02:00:00.000Z',
    },
  ];

  group('Formato que Excel sabe abrir', () {
    test('parte con la marca de bytes para que las tildes no se rompan', () {
      final csv = ExportadorLibro.generarCsv(movimientos);

      // Sin esto, "María González" se ve "MarÃ­a GonzÃ¡lez" en Excel.
      expect(csv.codeUnitAt(0), 0xFEFF);
      expect(csv, contains('María González'));
    });

    test('separa con punto y coma, no con coma', () {
      final csv = ExportadorLibro.generarCsv(movimientos);
      final encabezado = csv.replaceFirst('﻿', '').split('\r\n').first;

      // El Excel en espanol parte por punto y coma. Con comas, toda la fila
      // cae en una sola celda.
      expect(encabezado.split(';'), hasLength(8));
      expect(encabezado, startsWith('Fecha;Hora;Cliente'));
    });

    test('el monto va positivo y sin separador de miles', () {
      final csv = ExportadorLibro.generarCsv(movimientos);
      final fiado = csv.split('\r\n')[1].split(';');

      // Un negativo en una planilla se lee como error, y un "37.500" Excel lo
      // toma como texto y despues no se puede sumar.
      expect(fiado[3], 'Fiado');
      expect(fiado[5], '37500');
    });
  });

  group('Contenido del libro', () {
    test('el signo del monto decide si es fiado o abono', () {
      final filas = ExportadorLibro.generarCsv(movimientos).split('\r\n');

      expect(filas[1], contains('Fiado'));
      expect(filas[2], contains('Abono'));
    });

    test('marca los movimientos registrados sin conexion', () {
      final filas = ExportadorLibro.generarCsv(movimientos).split('\r\n');

      expect(filas[1].split(';').last, 'No');
      expect(filas[2].split(';').last, 'Si');
    });

    test('un punto y coma dentro del concepto no parte la fila', () {
      final csv = ExportadorLibro.generarCsv([
        {
          'cliente': 'Ana Ríos',
          'monto': -5000,
          'concepto': 'Pan; leche; huevos',
          'es_offline': false,
          'fecha_local': '2026-11-12T01:00:00.000Z',
        },
      ]);
      final fila = csv.split('\r\n')[1];

      expect(fila, contains('"Pan; leche; huevos"'));
      // Ocho columnas pese a los punto y coma del texto.
      expect(_columnas(fila), 8);
    });

    test('un cliente borrado no deja la fila sin dueno', () {
      final csv = ExportadorLibro.generarCsv([
        {
          'cliente': null,
          'monto': -1000,
          'es_offline': false,
          'fecha_local': '2026-11-12T01:00:00.000Z',
        },
      ]);

      expect(csv, contains('Cliente eliminado'));
    });

    test('la fecha sale en hora local, no en UTC', () {
      final csv = ExportadorLibro.generarCsv(movimientos);
      final hora = csv.split('\r\n')[1].split(';')[1];

      final esperada = DateTime.parse('2026-11-12T01:35:43.000Z').toLocal();
      final hh = esperada.hour.toString().padLeft(2, '0');
      final mm = esperada.minute.toString().padLeft(2, '0');
      expect(hora, '$hh:$mm');
    });
  });

  group('Nombre del archivo', () {
    test('lleva la fecha para que dos respaldos no se pisen', () {
      final nombre = ExportadorLibro.nombreArchivo(
        'El Sol',
        DateTime(2026, 11, 12),
      );

      expect(nombre, 'libro_fiados_el_sol_2026-11-12.csv');
    });

    test('las tildes y la ñ se transliteran, no se comen', () {
      // Caso real: el negocio se llama "Botillería Don Bastián" y el archivo
      // salía "botiller_a_don_basti_n", con un guion bajo por cada tilde.
      final nombre = ExportadorLibro.nombreArchivo(
        'Botillería Don Bastián',
        DateTime(2026, 11, 12),
      );

      expect(nombre, 'libro_fiados_botilleria_don_bastian_2026-11-12.csv');
      expect(nombre, isNot(contains('_a_')));
    });

    test('un nombre con ñ no pierde la letra', () {
      final nombre = ExportadorLibro.nombreArchivo(
        'El Peñón',
        DateTime(2026, 3, 9),
      );

      expect(nombre, 'libro_fiados_el_penon_2026-03-09.csv');
    });

    test('un negocio sin letras usables no deja el nombre colgando', () {
      final nombre = ExportadorLibro.nombreArchivo('***', DateTime(2026, 1, 5));

      expect(nombre, 'libro_fiados_negocio_2026-01-05.csv');
    });
  });
}

/// Cuenta columnas respetando las comillas, como lo hace Excel.
int _columnas(String fila) {
  var columnas = 1;
  var dentroDeComillas = false;
  for (final c in fila.split('')) {
    if (c == '"') dentroDeComillas = !dentroDeComillas;
    if (c == ';' && !dentroDeComillas) columnas++;
  }
  return columnas;
}
