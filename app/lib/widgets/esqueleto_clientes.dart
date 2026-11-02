import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_theme.dart';

/// Esqueleto que se muestra mientras cargan los clientes.
///
/// Reemplaza al círculo de carga centrado. La diferencia no es estética: un
/// círculo girando no dice nada, mientras que el esqueleto ya muestra la forma
/// de lo que viene —una tarjeta grande arriba y una lista de clientes debajo—,
/// así la pantalla no salta cuando llegan los datos.
class EsqueletoClientes extends StatelessWidget {
  /// Cuántas filas de cliente dibujar. Cuatro alcanzan para llenar la pantalla
  /// sin gastar de más: lo que no se ve, no se anima.
  final int filas;

  const EsqueletoClientes({super.key, this.filas = 4});

  @override
  Widget build(BuildContext context) {
    final oscuro = Theme.of(context).brightness == Brightness.dark;

    return Shimmer.fromColors(
      baseColor: oscuro ? const Color(0xFF232A36) : const Color(0xFFE9ECF2),
      highlightColor: oscuro
          ? const Color(0xFF2E3644)
          : const Color(0xFFF6F8FB),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _bloque(alto: 132, radio: 16),
          const SizedBox(height: 20),
          _bloque(alto: 12, radio: 4, ancho: 80),
          const SizedBox(height: 12),
          for (var i = 0; i < filas; i++) ...[
            _filaCliente(),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _bloque({
    required double alto,
    required double radio,
    double? ancho,
  }) => Container(
    height: alto,
    width: ancho,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radio),
    ),
  );

  /// Una fila con la misma silueta que la tarjeta real: círculo del avatar,
  /// dos líneas de texto y el monto a la derecha.
  Widget _filaCliente() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _bloque(alto: 12, radio: 4, ancho: 130),
              const SizedBox(height: 8),
              _bloque(alto: 10, radio: 4, ancho: 70),
            ],
          ),
        ),
        _bloque(alto: 14, radio: 4, ancho: 72),
      ],
    ),
  );
}

/// Esqueleto del panel: una tarjeta grande, dos chicas y dos bloques de
/// gráfico. Misma idea que [EsqueletoClientes].
class EsqueletoPanel extends StatelessWidget {
  const EsqueletoPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final oscuro = Theme.of(context).brightness == Brightness.dark;

    Widget bloque(double alto) => Container(
      height: alto,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
    );

    return Shimmer.fromColors(
      baseColor: oscuro ? const Color(0xFF232A36) : const Color(0xFFE9ECF2),
      highlightColor: oscuro
          ? const Color(0xFF2E3644)
          : const Color(0xFFF6F8FB),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          bloque(128),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: bloque(86)),
              const SizedBox(width: 10),
              Expanded(child: bloque(86)),
            ],
          ),
          const SizedBox(height: 24),
          bloque(230),
          const SizedBox(height: 24),
          bloque(180),
        ],
      ),
    );
  }
}

/// Envuelve el contenido con el fondo correcto para que el esqueleto no se
/// vea flotando sobre un color distinto al de la pantalla real.
class FondoEsqueleto extends StatelessWidget {
  final Widget child;

  const FondoEsqueleto({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Container(
    color: AppTheme.fondoDe(context),
    child: child,
  );
}
