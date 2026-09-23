import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';

/// En que condiciones esta el lector NFC del equipo.
///
/// Son tres casos distintos y la pantalla tiene que tratarlos distinto: no es
/// lo mismo "prendelo en ajustes" que "este celular no puede".
enum EstadoNfc {
  /// Hay lector y esta encendido.
  disponible,

  /// El equipo tiene NFC pero esta apagado en los ajustes.
  apagado,

  /// El equipo no tiene NFC, o estamos corriendo en el navegador.
  noSoportado,
}

/// Lectura del llavero NFC del cliente.
///
/// Solo leemos el UID: el numero de serie que trae de fabrica cada llavero.
/// No escribimos nada en el tag ni confiamos en el como autenticacion; sirve
/// para identificar al cliente rapido, y quien confirma la transaccion sigue
/// siendo el almacenero con su sesion iniciada.
class LectorNfc {
  /// UID que se devuelve cuando no hay lector.
  ///
  /// Sin esto no se podrian desarrollar las pantallas en el navegador, que es
  /// donde trabajamos casi siempre: `leerUid()` nunca devolveria nada y no
  /// habria forma de probar el flujo completo sin un celular en la mano.
  static const String uidDePrueba = '04:A2:3F:19:5C:70:80';

  static Future<EstadoNfc> estado() async {
    if (kIsWeb) return EstadoNfc.noSoportado;
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return EstadoNfc.noSoportado;
    }

    try {
      return switch (await NfcManager.instance.checkAvailability()) {
        NfcAvailability.enabled => EstadoNfc.disponible,
        NfcAvailability.disabled => EstadoNfc.apagado,
        NfcAvailability.unsupported => EstadoNfc.noSoportado,
      };
    } catch (_) {
      return EstadoNfc.noSoportado;
    }
  }

  /// Espera a que acerquen un llavero y devuelve su UID.
  ///
  /// Devuelve null si se acabo el tiempo o si el tag no entrego identificador.
  /// Si el equipo no tiene lector devuelve [uidDePrueba], para que las
  /// pantallas se puedan desarrollar y probar igual.
  static Future<String?> leerUid({
    Duration tiempoLimite = const Duration(seconds: 25),
  }) async {
    if (await estado() != EstadoNfc.disponible) {
      await Future<void>.delayed(const Duration(seconds: 1));
      return uidDePrueba;
    }

    final resultado = Completer<String?>();
    Timer? reloj;

    Future<void> terminar(String? uid) async {
      reloj?.cancel();
      await cancelar();
      if (!resultado.isCompleted) resultado.complete(uid);
    }

    try {
      await NfcManager.instance.startSession(
        // Los NTAG215 son ISO 14443, igual que la mayoria de las tarjetas de
        // proximidad que se usan en Chile.
        pollingOptions: {NfcPollingOption.iso14443},
        onDiscovered: (NfcTag tag) async => terminar(_uidDe(tag)),
      );
    } catch (_) {
      return null;
    }

    reloj = Timer(tiempoLimite, () => terminar(null));
    return resultado.future;
  }

  /// Corta la lectura. Hay que llamarla si el usuario cierra la pantalla antes
  /// de acercar el llavero, o el lector queda encendido consumiendo bateria.
  static Future<void> cancelar() async {
    try {
      await NfcManager.instance.stopSession();
    } catch (_) {
      // Si no habia sesion abierta no hay nada que cortar.
    }
  }

  static String? _uidDe(NfcTag tag) {
    final bytes = NfcTagAndroid.from(tag)?.id;
    if (bytes == null || bytes.isEmpty) return null;
    return uidEnHex(bytes);
  }

  /// Pasa los bytes del UID a texto legible: 04:A2:3F:19
  ///
  /// Guardamos el UID como texto y no como numero porque son 7 bytes, mas de
  /// lo que entra en un entero, y porque asi se puede comparar con lo que
  /// muestra cualquier lector NFC del telefono.
  static String uidEnHex(List<int> bytes) {
    return bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(':');
  }
}
