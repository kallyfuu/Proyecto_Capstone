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

  const ClienteSaldo({
    required this.id,
    required this.nombre,
    required this.saldo,
    this.telefono,
    this.estadoRiesgo,
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
    );
  }

  bool get debe => saldo < 0;
}
