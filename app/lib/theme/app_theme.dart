import 'package:flutter/material.dart';

/// Sistema de diseno de la app.
///
/// Decision clave: el color primario es un azul profundo, NO verde ni rojo.
/// Esos colores quedan reservados para el `estado_riesgo` del cliente
/// (Cumplidor / Atrasado / Moroso). Si el color de marca fuera verde, un boton
/// verde y un cliente "al dia" se verian igual y el semaforo dejaria de leerse.
class AppTheme {
  // Marca
  static const Color azulProfundo = Color(0xFF1B3B6F);
  static const Color azulClaro = Color(0xFF2E5EAA);

  // Semaforo de riesgo: significan estado, nunca decoracion.
  static const Color cumplidor = Color(0xFF1E8E3E);
  static const Color atrasado = Color(0xFFF29900);
  static const Color moroso = Color(0xFFD93025);

  // Neutros
  static const Color fondo = Color(0xFFF6F7F9);
  static const Color superficie = Colors.white;
  static const Color textoTenue = Color(0xFF5F6368);

  /// Color del semaforo segun el estado que guarda la base de datos.
  static Color colorEstado(String? estado) {
    switch (estado) {
      case 'Moroso':
        return moroso;
      case 'Atrasado':
        return atrasado;
      default:
        return cumplidor;
    }
  }

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: azulProfundo,
      primary: azulProfundo,
      surface: superficie,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: fondo,
      appBarTheme: const AppBarTheme(
        backgroundColor: azulProfundo,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: superficie,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDADCE0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDADCE0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: azulProfundo, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: azulProfundo,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: superficie,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFE8EAED)),
        ),
      ),
    );
  }
}
