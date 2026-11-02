/// Una fila de la vista `v_clientes_saldo`.
///
/// El saldo lo calcula la base de datos sumando las transacciones, no la app.
/// Asi el numero es el mismo mires desde donde mires: celular, portal web o
/// consulta SQL. Negativo = el cliente debe.
class ClienteSaldo {
  final String id;
  final String nombre;
  final int saldo;
  final String? telefono;
  final String? estadoRiesgo;
  final int? limiteCredito;
  final String? tokenPortal;

  const ClienteSaldo({
    required this.id,
    required this.nombre,
    required this.saldo,
    this.telefono,
    this.estadoRiesgo,
    this.limiteCredito,
    this.tokenPortal,
  });

  /// Lee los campos con tolerancia: si la vista todavia no expone alguna
  /// columna, la pantalla igual se dibuja en vez de reventar.
  factory ClienteSaldo.desdeMapa(Map<String, dynamic> fila) {
    return ClienteSaldo(
      id: fila['id'].toString(),
      nombre: (fila['nombre'] ?? 'Sin nombre').toString(),
      saldo: (fila['saldo'] as num?)?.toInt() ?? 0,
      telefono: fila['telefono']?.toString(),
      estadoRiesgo: fila['estado_riesgo']?.toString(),
      limiteCredito: (fila['limite_credito'] as num?)?.toInt(),
      tokenPortal: fila['token_portal']?.toString(),
    );
  }

  bool get debe => saldo < 0;

  /// Que porcion del cupo tiene ocupada, entre 0 y 1.
  ///
  /// Devuelve null cuando el cliente no tiene limite definido: mostrar una
  /// barra vacia en ese caso haria creer que no le queda cupo, cuando en
  /// realidad nadie le puso uno.
  double? get cupoUsado {
    final limite = limiteCredito ?? 0;
    if (limite <= 0 || !debe) return null;
    return (saldo.abs() / limite).clamp(0.0, 1.0);
  }
}
