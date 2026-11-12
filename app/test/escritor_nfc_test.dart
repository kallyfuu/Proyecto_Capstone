import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:fiado_nfc/services/escritor_nfc.dart';
import 'package:fiado_nfc/utils/recordatorio.dart';

void main() {
  // Memoria util de un NTAG215, que es el llavero que usa el proyecto.
  const capacidadNtag215 = 504;

  const token = '9f8c2b41-5d3e-4a77-91b0-6c2de8f41a33';

  group('Cuerpo del registro URI', () {
    test('abrevia https:// en el byte 0x04', () {
      final cuerpo = EscritorNfc.payloadUri('https://ejemplo.cl/abc');

      expect(cuerpo.first, 0x04);
      expect(utf8.decode(cuerpo.sublist(1)), 'ejemplo.cl/abc');
    });

    test('elige el prefijo mas largo que calce, no el primero', () {
      // "https://www." y "https://" calzan los dos; gana el mas largo o se
      // escribiria "www." como texto al pedo.
      final cuerpo = EscritorNfc.payloadUri('https://www.ejemplo.cl/abc');

      expect(cuerpo.first, 0x02);
      expect(utf8.decode(cuerpo.sublist(1)), 'ejemplo.cl/abc');
    });

    test('sin prefijo conocido usa 0x00 y deja la direccion entera', () {
      final cuerpo = EscritorNfc.payloadUri('ftp://ejemplo.cl');

      expect(cuerpo.first, 0x00);
      expect(utf8.decode(cuerpo.sublist(1)), 'ftp://ejemplo.cl');
    });
  });

  group('Mensaje NDEF del llavero', () {
    test('es un unico registro URI bien formado', () {
      final mensaje = EscritorNfc.mensajeConEnlace(enlacePortal(token));

      expect(mensaje.records, hasLength(1));
      // 0x55 es 'U': el tipo que Android reconoce para abrir el navegador.
      expect(mensaje.records.single.type, [0x55]);
    });

    test('el enlace del portal entra de sobra en un NTAG215', () {
      final mensaje = EscritorNfc.mensajeConEnlace(enlacePortal(token));

      expect(mensaje.byteLength, lessThan(capacidadNtag215));
    });

    test('graba el enlace del portal y nada mas', () {
      final mensaje = EscritorNfc.mensajeConEnlace(enlacePortal(token));
      final escrito = utf8.decode(mensaje.records.single.payload.sublist(1));

      // Lo que quede en el llavero no debe permitir identificar al cliente
      // si lo pierde: solo el token, que se puede revocar.
      expect(escrito, contains(token));
      expect(escrito, isNot(contains('nombre')));
      expect(mensaje.records, hasLength(1));
    });
  });
}
