---
name: flutter-premium-ui
description: Guía de diseño UI/UX y rendimiento para la app Flutter de Fiado NFC. Estilo fintech chileno (Tenpo, Mercado Pago), 60 FPS en Android de gama media. Cargar antes de tocar cualquier pantalla, tema, color, tipografía, animación o estado de carga de la app móvil.
---

# Flutter Premium UI — Fiado NFC

Rol: diseñador UI/UX senior y responsable de rendimiento. La app debe verse
profesional y correr a 60 FPS estables en teléfonos Android de gama media.

## Paleta

Material 3 (`useMaterial3: true`).

| Rol | Valor | Nota |
|---|---|---|
| Primario / marino | `#0F172A` – `#1E293B` | Seriedad bancaria |
| Fondo | `#F8FAFC` | Nunca blanco puro |
| Cumplidor | `#1E8E3E` | **No cambiar** |
| Atrasado | `#F29900` | **No cambiar** |
| Moroso | `#D93025` | **No cambiar** |

**Por qué los tres colores del semáforo no se cambian.** Se validaron con el
verificador de contraste y visión de color de la skill `dataviz`. Comparados
con la alternativa de moda (`#10B981`, `#F59E0B`, `#EF4444`):

- separación para daltonismo: **11.5** contra 8.9
- separación en visión normal: **22.1** contra 19.8
- colores bajo el contraste mínimo: **1** contra 2

Son medibles mejores y son los únicos tres colores de la app que cargan
significado. El look fintech viene de las superficies, la tipografía y el
espaciado, no de ellos.

Antes de proponer cualquier cambio a estos tres valores, correr:
`node scripts/validate_palette.js "<hex,hex,hex>" --mode light` de la skill
`dataviz`, y repetirlo con `--mode dark`.

**En modo oscuro** los pasos validados son `#2FA45C`, `#E0A020`, `#E85D52`.
No pasan todas las verificaciones —un semáforo rojo/ámbar/verde no puede
hacerlo sobre fondo oscuro, son colores vecinos— así que **los íconos y las
etiquetas de texto son obligatorios**: el color nunca puede ser la única pista.

## Tipografía

**Plus Jakarta Sans empaquetada como asset**, nunca `google_fonts`.

Ese paquete descarga la tipografía de internet la primera vez que se abre la
app. En una sala de clases con mala señal, la app cae a la fuente del sistema
y se pierde justo lo que se quería mostrar. Los `.ttf` viven en
`assets/fonts/` y se declaran en `pubspec.yaml`.

Montos en negrita, grandes, con separador de miles chileno (`$15.000`). El
formateo ya existe en `lib/utils/formato.dart`; no reimplementarlo ni agregar
`intl` para eso.

## Superficies

- Bordes redondeados `BorderRadius.circular(16)`, consistentes.
- Sombras muy tenues: `BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10)`.
  Nunca sombras negras pesadas.
- No todo es una tarjeta: borde, relleno, radio y sombra dicen "objeto
  separado". Gastarlos en cada bloque aplana la jerarquía.

## Rendimiento (anti-lag)

1. **`const` en todo lo que no dependa del estado.** Evita reconstrucciones.
2. **Cero `BackdropFilter` o `ImageFiltered` grandes.** El desenfoque gaussiano
   destruye la GPU en Android de gama media. Usar color sólido con opacidad.
3. **Listas con `ListView.builder` o `SliverList`**, con `ValueKey`. Nunca un
   `Column` dentro de un `SingleChildScrollView` para listas de clientes.
4. **Esqueletos (`shimmer`) mientras carga**, no un `CircularProgressIndicator`
   centrado. El esqueleto muestra la forma de lo que viene.
5. **Hojas inferiores** con `showModalBottomSheet`, `isScrollControlled: true`,
   bordes superiores redondeados y tirador visible.

## Háptica

Respuesta táctil sutil en los momentos que importan:

- `HapticFeedback.lightImpact()` al leer un llavero NFC.
- `HapticFeedback.mediumImpact()` al confirmar un fiado o abono.
- `HapticFeedback.selectionClick()` al cambiar de opción o de mes.

No en cada toque: la háptica que suena siempre deja de significar algo.

## Modo oscuro

Todas las pantallas responden al tema. Los colores se toman de los ayudantes
`AppTheme.morosoDe(context)`, `cumplidorDe`, `atrasadoDe`, `textoTenueDe`,
`bordeDe`, `fondoDe`, `acentoDe`, `colorEstadoDe(context, estado)`.

**Nunca** usar `AppTheme.moroso` ni un `Color(0x...)` directo dentro de un
widget. Si un color pasa a depender del `context`, quitar el `const` del
widget que lo contiene.

## Lo que no se toca

Las consultas a Supabase y la vista `v_clientes_saldo` quedan como están. Este
trabajo es de presentación, no de datos.
