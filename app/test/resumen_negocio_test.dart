import 'package:flutter_test/flutter_test.dart';

import 'package:fiado_nfc/models/cliente_saldo.dart';
import 'package:fiado_nfc/models/resumen_negocio.dart';

ClienteSaldo cliente(String nombre, int saldo, [String? estado]) =>
    ClienteSaldo(
      id: nombre,
      nombre: nombre,
      saldo: saldo,
      estadoRiesgo: estado,
    );

void main() {
  group('Agrupar movimientos por mes', () {
    test('Separa los fiados de los abonos del mismo mes', () {
      final meses = ResumenNegocio.agruparPorMes(
        [
          {'monto': -5000, 'fecha_local': '2026-10-03T12:00:00Z'},
          {'monto': -3000, 'fecha_local': '2026-10-10T12:00:00Z'},
          {'monto': 2000, 'fecha_local': '2026-10-15T12:00:00Z'},
        ],
        hasta: DateTime(2026, 10, 18),
        cuantosMeses: 1,
      );

      expect(meses.single.fiado, 8000);
      expect(meses.single.abonado, 2000);
    });

    test('Rellena con cero los meses sin movimiento', () {
      final meses = ResumenNegocio.agruparPorMes(
        [
          {'monto': -5000, 'fecha_local': '2026-10-03T12:00:00Z'},
        ],
        hasta: DateTime(2026, 10, 18),
        cuantosMeses: 3,
      );

      // Agosto y septiembre no tienen movimientos, pero el grafico igual
      // necesita sus columnas para que se note el hueco.
      expect(meses.length, 3);
      expect(meses[0].fiado, 0);
      expect(meses[1].fiado, 0);
      expect(meses[2].fiado, 5000);
    });

    test('Una fila sin fecha no rompe el calculo', () {
      final meses = ResumenNegocio.agruparPorMes(
        [
          {'monto': -5000},
          {'monto': -1000, 'fecha_local': 'cualquier cosa'},
          {'monto': -2000, 'fecha_local': '2026-10-03T12:00:00Z'},
        ],
        hasta: DateTime(2026, 10, 18),
        cuantosMeses: 1,
      );

      expect(meses.single.fiado, 2000);
    });

    test('La etiqueta del mes sale en castellano y abreviada', () {
      final meses = ResumenNegocio.agruparPorMes(
        const [],
        hasta: DateTime(2026, 10, 18),
        cuantosMeses: 2,
      );
      expect(meses.map((m) => m.etiqueta).toList(), ['sep', 'oct']);
    });
  });

  group('Indicadores del negocio', () {
    final r = ResumenNegocio(
      meses: ResumenNegocio.agruparPorMes(
        [
          {'monto': -10000, 'fecha_local': '2026-10-05T12:00:00Z'},
          {'monto': 4000, 'fecha_local': '2026-10-06T12:00:00Z'},
        ],
        hasta: DateTime(2026, 10, 18),
        cuantosMeses: 1,
      ),
      clientes: [
        cliente('Pedro', -45000, 'Moroso'),
        cliente('María', -12000, 'Atrasado'),
        cliente('Juan', -3000, 'Cumplidor'),
        cliente('Rosa', 0, 'Cumplidor'),
      ],
    );

    test('El total en la calle solo suma a los que deben', () {
      expect(r.totalFiado, 60000);
      expect(r.clientesConDeuda, 3);
    });

    test('La deuda promedio se reparte entre los que deben, no entre todos', () {
      expect(r.deudaPromedio, 20000);
    });

    test('El semaforo cuenta a cada cliente en su estado', () {
      expect(r.porEstado, {'Cumplidor': 2, 'Atrasado': 1, 'Moroso': 1});
    });

    test('Los que mas deben van primero y son a lo mas cinco', () {
      expect(r.topDeudores.map((c) => c.nombre).toList(),
          ['Pedro', 'María', 'Juan']);
    });

    test('El porcentaje recuperado compara abonos contra fiado del mes', () {
      expect(r.porcentajeRecuperado, 40);
    });

    test('Sin fiados en el mes no se calcula un porcentaje imposible', () {
      final vacio = ResumenNegocio(
        meses: ResumenNegocio.agruparPorMes(
          const [],
          hasta: DateTime(2026, 10, 18),
          cuantosMeses: 1,
        ),
        clientes: const [],
      );
      expect(vacio.porcentajeRecuperado, isNull);
      expect(vacio.deudaPromedio, 0);
    });
  });
}
