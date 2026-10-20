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

  // Semaforo de riesgo (tema claro): significan estado, nunca decoracion.
  static const Color cumplidor = Color(0xFF1E8E3E);
  static const Color atrasado = Color(0xFFF29900);
  static const Color moroso = Color(0xFFD93025);

  // Semaforo de riesgo (tema oscuro): versiones aclaradas para que no
  // queden apagadas sobre fondo negro. Los iconos y textos del panel se
  // mantienen, porque compensan la limitacion para daltonismo.
  static const Color cumplidorOscuro = Color(0xFF2FA45C);
  static const Color atrasadoOscuro = Color(0xFFE0A020);
  static const Color morosoOscuro = Color(0xFFE85D52);

  // Neutros (tema claro)
  static const Color fondo = Color(0xFFF6F7F9);
  static const Color superficie = Colors.white;
  static const Color textoTenue = Color(0xFF5F6368);
  static const Color bordeClaro = Color(0xFFE8EAED);

  // Neutros (tema oscuro)
  static const Color fondoOscuro = Color(0xFF121417);
  static const Color superficieOscura = Color(0xFF1C1F24);
  static const Color textoTenueOscuro = Color(0xFF9AA0A6);
  static const Color bordeOscuro = Color(0xFF3C4043);

  // Azul de acento para botones y enfoques sobre fondo oscuro.
  static const Color azulSobreOscuro = Color(0xFF8AB4F8);
  static const Color textoSobreAzulOscuro = Color(0xFF0B1B36);

  // Manija (la rayita) de las hojas inferiores.
  static const Color tiradorClaro = Color(0xFFDADCE0);
  static const Color tiradorOscuro = Color(0xFF5F6368);

  /// Color del semaforo segun el estado que guarda la base de datos.
  ///
  /// El parametro [brillo] es opcional: si no se entrega, devuelve el color
  /// del tema claro, asi el codigo existente sigue funcionando igual.
  static Color colorEstado(
    String? estado, [
    Brightness brillo = Brightness.light,
  ]) {
    final oscuro = brillo == Brightness.dark;
    switch (estado) {
      case 'Moroso':
        return oscuro ? morosoOscuro : moroso;
      case 'Atrasado':
        return oscuro ? atrasadoOscuro : atrasado;
      default:
        return oscuro ? cumplidorOscuro : cumplidor;
    }
  }

  /// Igual que [colorEstado], pero toma el brillo del tema activo.
  /// Usar esta version dentro de los widgets.
  static Color colorEstadoDe(BuildContext context, String? estado) {
    return colorEstado(estado, Theme.of(context).brightness);
  }

  // Ayudantes que eligen el color segun el tema activo (claro u oscuro).
  // Se usan en las pantallas en vez de los colores fijos de arriba.
  static bool _esOscuro(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color cumplidorDe(BuildContext context) =>
      _esOscuro(context) ? cumplidorOscuro : cumplidor;

  static Color atrasadoDe(BuildContext context) =>
      _esOscuro(context) ? atrasadoOscuro : atrasado;

  static Color morosoDe(BuildContext context) =>
      _esOscuro(context) ? morosoOscuro : moroso;

  static Color textoTenueDe(BuildContext context) =>
      _esOscuro(context) ? textoTenueOscuro : textoTenue;

  static Color fondoDe(BuildContext context) =>
      _esOscuro(context) ? fondoOscuro : fondo;

  static Color bordeDe(BuildContext context) =>
      _esOscuro(context) ? bordeOscuro : bordeClaro;

  /// Color de la manija gris que se ve arriba de las hojas inferiores.
  static Color manijaDe(BuildContext context) =>
      _esOscuro(context) ? const Color(0xFF5F6368) : const Color(0xFFDADCE0);

  /// Azul de acento: azul profundo en claro, azul aclarado en oscuro.
  /// Sirve para textos, botones e indicadores de seleccion.
  static Color acentoDe(BuildContext context) =>
      _esOscuro(context) ? azulSobreOscuro : azulProfundo;

  /// Color del texto o icono que va encima de [acentoDe].
  static Color sobreAcentoDe(BuildContext context) =>
      _esOscuro(context) ? textoSobreAzulOscuro : Colors.white;

  static Color tiradorDe(BuildContext context) =>
      _esOscuro(context) ? tiradorOscuro : tiradorClaro;

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

  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: azulClaro,
      brightness: Brightness.dark,
      primary: azulSobreOscuro,
      onPrimary: textoSobreAzulOscuro,
      surface: superficieOscura,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: fondoOscuro,
      appBarTheme: const AppBarTheme(
        backgroundColor: superficieOscura,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: superficieOscura,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: bordeOscuro),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: bordeOscuro),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: azulSobreOscuro, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: azulSobreOscuro,
          foregroundColor: textoSobreAzulOscuro,
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
        color: superficieOscura,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: bordeOscuro),
        ),
      ),
    );
  }
}
