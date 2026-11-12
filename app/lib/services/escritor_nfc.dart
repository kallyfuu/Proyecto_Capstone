import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:nfc_manager/ndef_record.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';

import 'lector_nfc.dart';

/// Como termino el intento de grabar el llavero.
///
/// Son casos distintos a proposito: al vendedor no le sirve un "fallo". Si el
/// llavero esta protegido hay que darle otro, si se acabo el tiempo basta con
/// reintentar, y si no hay lector el problema es el telefono y no el llavero.
enum ResultadoGrabado {
  /// Quedo grabado.
  ok,

  /// El telefono no tiene NFC, o esta apagado.
  sinLector,

  /// El llavero no acepta NDEF ni se puede formatear. Tag incompatible.
  noGrabable,

  /// El llavero quedo bloqueado como solo-lectura y ya no acepta cambios.
  protegido,

  /// El enlace no entra en la memoria del llavero.
  sinEspacio,

  /// Nadie acerco un llavero dentro del tiempo de espera.
  tiempoAgotado,

  /// El vendedor se arrepintio y cerro la pantalla antes de acercar nada.
  cancelado,

  /// Fallo la escritura, casi siempre porque retiraron el llavero a medias.
  error,
}

/// Graba el enlace del portal dentro del llavero del cliente.
///
/// El llavero queda con un registro NDEF de tipo URI. Cuando el cliente lo
/// acerca a CUALQUIER celular con NFC, Android le abre el portal con su estado
/// de cuenta: no necesita tener la app instalada ni cuenta en ningun lado.
///
/// Esto convive con [LectorNfc] y no lo reemplaza. La app del vendedor sigue
/// identificando al cliente por el UID de fabrica, que no se puede reescribir;
/// el NDEF es para el celular del cliente. Son dos usos del mismo llavero.
///
/// Lo unico que viaja en el llavero es el enlace con el token. Ni el nombre
/// del cliente ni su deuda: si pierde el llavero, quien lo encuentre no sabe
/// de quien es, y el token se revoca con `token_activo = false`.
class EscritorNfc {
  /// Prefijos que el estandar NDEF abrevia en un solo byte.
  ///
  /// Guardar "https://" como texto gasta ocho bytes; como prefijo gasta uno.
  /// En un NTAG215 sobra espacio, pero el lector de Android espera este
  /// formato y conviene emitir lo que todos los telefonos saben leer.
  static const Map<int, String> _prefijos = {
    0x01: 'http://www.',
    0x02: 'https://www.',
    0x03: 'http://',
    0x04: 'https://',
  };

  /// Arma el cuerpo de un registro URI: el byte del prefijo y luego el resto.
  ///
  /// Funcion pura y separada a proposito, para poder probar el formato sin
  /// tener un celular y un llavero en la mano.
  static Uint8List payloadUri(String url) {
    var codigo = 0x00;
    var resto = url;

    for (final entrada in _prefijos.entries) {
      final largoActual = _prefijos[codigo]?.length ?? 0;
      if (url.startsWith(entrada.value) &&
          entrada.value.length > largoActual) {
        codigo = entrada.key;
        resto = url.substring(entrada.value.length);
      }
    }

    return Uint8List.fromList([codigo, ...utf8.encode(resto)]);
  }

  /// Mensaje NDEF de un solo registro con el enlace.
  static NdefMessage mensajeConEnlace(String url) {
    return NdefMessage(
      records: [
        NdefRecord(
          typeNameFormat: TypeNameFormat.wellKnown,
          // 'U' de URI, como lo nombra el estandar NDEF.
          type: Uint8List.fromList([0x55]),
          identifier: Uint8List(0),
          payload: payloadUri(url),
        ),
      ],
    );
  }

  /// Grabado que esta esperando un llavero ahora mismo.
  ///
  /// Se guarda para que [cancelar] pueda resolverlo en el acto. Sin esto, al
  /// cerrar la pantalla el dialogo quedaria girando hasta que venciera el
  /// tiempo de espera, aunque el lector ya estuviera apagado.
  static Completer<ResultadoGrabado>? _enCurso;

  /// Espera a que acerquen un llavero y le graba [url].
  static Future<ResultadoGrabado> grabarEnlace({
    required String url,
    Duration tiempoLimite = const Duration(seconds: 25),
  }) async {
    if (await LectorNfc.estado() != EstadoNfc.disponible) {
      return ResultadoGrabado.sinLector;
    }

    final mensaje = mensajeConEnlace(url);
    final resultado = Completer<ResultadoGrabado>();
    _enCurso = resultado;
    Timer? reloj;

    Future<void> terminar(ResultadoGrabado valor) async {
      reloj?.cancel();
      await LectorNfc.cancelar();
      if (identical(_enCurso, resultado)) _enCurso = null;
      if (!resultado.isCompleted) resultado.complete(valor);
    }

    try {
      await NfcManager.instance.startSession(
        pollingOptions: {NfcPollingOption.iso14443},
        onDiscovered: (NfcTag tag) async {
          await terminar(await _escribirEn(tag, mensaje));
        },
      );
    } catch (_) {
      return ResultadoGrabado.error;
    }

    reloj = Timer(tiempoLimite, () => terminar(ResultadoGrabado.tiempoAgotado));
    return resultado.future;
  }

  /// Corta la espera si el vendedor cierra la pantalla antes de acercar nada.
  ///
  /// Resuelve el grabado pendiente de inmediato: quien lo estaba esperando
  /// recibe [ResultadoGrabado.cancelado] y puede cerrar su dialogo, en vez de
  /// quedarse girando hasta que venza el tiempo de espera.
  static Future<void> cancelar() async {
    final pendiente = _enCurso;
    _enCurso = null;
    await LectorNfc.cancelar();
    if (pendiente != null && !pendiente.isCompleted) {
      pendiente.complete(ResultadoGrabado.cancelado);
    }
  }

  static Future<ResultadoGrabado> _escribirEn(
    NfcTag tag,
    NdefMessage mensaje,
  ) async {
    final ndef = NdefAndroid.from(tag);

    // Un llavero recien sacado del paquete puede venir sin estructura NDEF.
    // No es un error: hay que formatearlo, y el formateo ya deja el primer
    // mensaje escrito, asi que no hace falta un segundo toque.
    if (ndef == null) {
      final formateable = NdefFormatableAndroid.from(tag);
      if (formateable == null) return ResultadoGrabado.noGrabable;
      try {
        await formateable.format(mensaje);
        await HapticFeedback.mediumImpact();
        return ResultadoGrabado.ok;
      } catch (_) {
        return ResultadoGrabado.error;
      }
    }

    if (!ndef.isWritable) return ResultadoGrabado.protegido;
    if (mensaje.byteLength > ndef.maxSize) return ResultadoGrabado.sinEspacio;

    try {
      await ndef.writeNdefMessage(mensaje);
      // El vendedor tiene el telefono contra el llavero y no le mira la
      // pantalla: el golpecito le avisa que ya quedo.
      await HapticFeedback.mediumImpact();
      return ResultadoGrabado.ok;
    } catch (_) {
      return ResultadoGrabado.error;
    }
  }
}
