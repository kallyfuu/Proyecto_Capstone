import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Modo de tema elegido por el usuario: Automatico (sistema), Claro u Oscuro.
///
/// Vive aparte de main.dart para no mezclar la logica de guardado con el
/// arranque de la app. [modo] es un ValueNotifier: quien lo escucha (el
/// MaterialApp) se redibuja solo cuando cambia, sin tocar las pantallas.
class ModoTema {
  static const _clave = 'modo_tema';

  static final ValueNotifier<ThemeMode> modo = ValueNotifier(ThemeMode.system);

  /// Lee la eleccion guardada. Se llama una vez al abrir la app.
  /// Si falla o no hay nada guardado, se queda en "seguir al sistema".
  static Future<void> cargar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      modo.value = switch (prefs.getString(_clave)) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
    } catch (_) {
      // Sin preferencia guardada: se mantiene ThemeMode.system.
    }
  }

  /// Cambia el modo al instante y lo guarda para la proxima vez.
  static Future<void> elegir(ThemeMode nuevo) async {
    modo.value = nuevo;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_clave, nuevo.name);
    } catch (_) {
      // Si no se pudo guardar, el cambio igual vale para esta sesion.
    }
  }
}
