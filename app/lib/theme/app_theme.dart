import 'package:flutter/material.dart';

/// Sistema de diseno de la app.
///
/// Decision clave: el color primario es un azul profundo, NO verde ni rojo.
/// Esos colores quedan reservados para el `estado_riesgo` del cliente
/// (Cumplidor / Atrasado / Moroso). Si el color de marca fuera verde, un boton
/// verde y un cliente "al dia" se verian igual y el semaforo dejaria de leerse.
class AppTheme {
  /// Tipografia de la app. Va empaquetada en assets/fonts, no descargada:
  /// google_fonts la baja de internet la primera vez que se abre la app y en
  /// una sala con mala senal caeria a la fuente del sistema.
  static const String fuente = 'PlusJakartaSans';

  /// Degradado de marca. Va en el circulo del NFC, la cabecera del login y
  /// el boton principal, para que el acento sea el mismo en toda la app.
  static const LinearGradient degradadoMarca = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF00D084), Color(0xFF059669)],
  );

  /// Degradado de acento para el modo oscuro.
  static const LinearGradient degradadoMenta = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF00F59B), Color(0xFF10B981)],
  );

  /// El degradado que corresponde al tema activo.
  static LinearGradient degradadoDe(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? degradadoMenta
      : degradadoMarca;

  /// Sombra de tarjeta: apenas perceptible. Una sombra negra pesada envejece
  /// la interfaz y ademas cuesta mas de dibujar en gama media.
  static List<BoxShadow> get sombraSuave => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 10,
      offset: const Offset(0, 2),
    ),
  ];

  // Marca. En claro el acento es un menta mas brillante que el del semaforo,
  // y en oscuro pasa lo mismo: asi un boton y un cliente "al dia" no terminan
  // pintados del mismo color exacto.
  static const Color azulProfundo = Color(0xFF059669);
  static const Color azulClaro = Color(0xFF00D084);

  // Semaforo de riesgo (tema claro): significan estado, nunca decoracion.
  static const Color cumplidor = Color(0xFF059669);
  static const Color atrasado = Color(0xFFF59E0B);
  static const Color moroso = Color(0xFFE11D48);

  // Semaforo de riesgo (tema oscuro): versiones aclaradas para que no
  // queden apagadas sobre fondo negro. Los iconos y textos del panel se
  // mantienen, porque compensan la limitacion para daltonismo.
  static const Color cumplidorOscuro = Color(0xFF10B981);
  static const Color atrasadoOscuro = Color(0xFFF59E0B);
  static const Color morosoOscuro = Color(0xFFEF4444);

  // Neutros (tema claro)
  static const Color fondo = Color(0xFFF8FAFC);
  static const Color superficie = Colors.white;
  static const Color textoTenue = Color(0xFF64748B);

  /// Texto principal en el tema claro.
  static const Color titanio = Color(0xFF0F172A);
  static const Color bordeClaro = Color(0xFFE8EAED);

  // Neutros (tema oscuro)
  static const Color fondoOscuro = Color(0xFF0F1218);
  /// Titanio: las tarjetas se separan del fondo por su color, no por una
  /// sombra. En oscuro una sombra no se ve, asi que la jerarquia la tiene que
  /// dar el contraste entre superficies.
  static const Color superficieOscura = Color(0xFF181E29);

  /// Fondo de los campos de texto en oscuro: un paso mas hundido que la
  /// tarjeta, para que se lea que son huecos donde se escribe.
  static const Color campoOscuro = Color(0xFF121620);
  static const Color textoTenueOscuro = Color(0xFF94A3B8);
  static const Color bordeOscuro = Color(0xFF263042);

  // Azul de acento para botones y enfoques sobre fondo oscuro.
  static const Color azulSobreOscuro = Color(0xFF10B981);
  static const Color textoSobreAzulOscuro = Color(0xFF04140E);

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
  ///
  /// Oscuro en los dos temas, porque el acento es menta en los dos. Blanco
  /// sobre el menta brillante del degradado da 1,9 a 1 y no se lee; titanio
  /// sobre ese mismo menta pasa de 9 a 1.
  static Color sobreAcentoDe(BuildContext context) =>
      _esOscuro(context) ? textoSobreAzulOscuro : titanio;

  static Color tiradorDe(BuildContext context) =>
      _esOscuro(context) ? tiradorOscuro : tiradorClaro;

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: azulProfundo,
      primary: azulProfundo,
      surface: superficie,
      onSurface: titanio,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: fuente,
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
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
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
      fontFamily: fuente,
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
        fillColor: campoOscuro,
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
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: bordeOscuro),
        ),
      ),
    );
  }
}
