import 'cliente_saldo.dart';

/// Un mes del gráfico: cuánto se fió y cuánto se abonó.
class MesMovimiento {
  final DateTime mes;
  final int fiado;
  final int abonado;

  const MesMovimiento({
    required this.mes,
    required this.fiado,
    required this.abonado,
  });

  /// Para el eje: "ene", "feb"...
  String get etiqueta {
    const nombres = [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
    ];
    return nombres[mes.month - 1];
  }
}

/// Todo lo que el panel necesita mostrar, ya calculado.
///
/// Los numeros se arman aqui y no dentro de la pantalla para que la pantalla
/// solo dibuje. Asi tambien se pueden probar los calculos sin abrir la app.
class ResumenNegocio {
  final List<MesMovimiento> meses;
  final List<ClienteSaldo> clientes;

  const ResumenNegocio({required this.meses, required this.clientes});

  /// Plata en la calle: la suma de lo que deben todos los clientes.
  int get totalFiado =>
      clientes.where((c) => c.debe).fold(0, (s, c) => s + c.saldo.abs());

  int get clientesConDeuda => clientes.where((c) => c.debe).length;

  int get fiadoDelMes => meses.isEmpty ? 0 : meses.last.fiado;

  int get abonadoDelMes => meses.isEmpty ? 0 : meses.last.abonado;

  /// Cuanto de lo fiado este mes alcanzo a volver como abono.
  ///
  /// Es el numero que le dice al vendedor si esta prestando mas rapido de lo
  /// que le pagan. Sobre 100% significa que este mes recupero mas de lo que
  /// presto.
  int? get porcentajeRecuperado {
    if (fiadoDelMes == 0) return null;
    return ((abonadoDelMes / fiadoDelMes) * 100).round();
  }

  int get deudaPromedio =>
      clientesConDeuda == 0 ? 0 : (totalFiado / clientesConDeuda).round();

  /// Cuantos clientes hay en cada estado del semaforo.
  Map<String, int> get porEstado {
    final cuenta = <String, int>{'Cumplidor': 0, 'Atrasado': 0, 'Moroso': 0};
    for (final c in clientes) {
      final e = c.estadoRiesgo ?? 'Cumplidor';
      cuenta[e] = (cuenta[e] ?? 0) + 1;
    }
    return cuenta;
  }

  /// Los que mas deben, primero. Es a quienes hay que cobrarles.
  List<ClienteSaldo> get topDeudores {
    final deudores = clientes.where((c) => c.debe).toList()
      ..sort((a, b) => a.saldo.compareTo(b.saldo));
    return deudores.take(5).toList();
  }

  /// El mes con mas movimiento, para escalar las barras del grafico.
  int get maximoMensual {
    var maximo = 0;
    for (final m in meses) {
      if (m.fiado > maximo) maximo = m.fiado;
      if (m.abonado > maximo) maximo = m.abonado;
    }
    return maximo;
  }

  /// Agrupa las transacciones crudas por mes, rellenando los meses sin
  /// movimiento para que el grafico no tenga huecos.
  static List<MesMovimiento> agruparPorMes(
    List<Map<String, dynamic>> filas, {
    required DateTime hasta,
    int cuantosMeses = 6,
  }) {
    final fiadoPorMes = <String, int>{};
    final abonoPorMes = <String, int>{};

    for (final f in filas) {
      final cruda = f['fecha_local'] ?? f['synced_at'];
      if (cruda == null) continue;
      final fecha = DateTime.tryParse(cruda.toString())?.toLocal();
      if (fecha == null) continue;

      final clave = '${fecha.year}-${fecha.month}';
      final monto = (f['monto'] as num?)?.toInt() ?? 0;
      if (monto < 0) {
        fiadoPorMes[clave] = (fiadoPorMes[clave] ?? 0) + monto.abs();
      } else {
        abonoPorMes[clave] = (abonoPorMes[clave] ?? 0) + monto;
      }
    }

    final meses = <MesMovimiento>[];
    for (var i = cuantosMeses - 1; i >= 0; i--) {
      final m = DateTime(hasta.year, hasta.month - i, 1);
      final clave = '${m.year}-${m.month}';
      meses.add(MesMovimiento(
        mes: m,
        fiado: fiadoPorMes[clave] ?? 0,
        abonado: abonoPorMes[clave] ?? 0,
      ));
    }
    return meses;
  }
}
