import 'package:flutter_test/flutter_test.dart';

import 'package:fiado_nfc/services/almacen_local.dart';

void main() {
  group('Saldos con movimientos sin enviar', () {
    final clientes = [
      {'id': 'a', 'nombre': 'Pedro', 'saldo': -37500},
      {'id': 'b', 'nombre': 'María', 'saldo': -29000},
      {'id': 'c', 'nombre': 'Rosa', 'saldo': 0},
    ];

    test('Un fiado sin enviar ya aparece en el saldo', () {
      // Si el saldo no se moviera, el vendedor pensaria que el fiado no quedo
      // registrado y lo anotaria dos veces.
      final r = aplicarPendientes(clientes, [
        {'cliente_id': 'a', 'monto': -5000},
      ]);
      expect(r.firstWhere((c) => c['id'] == 'a')['saldo'], -42500);
    });

    test('Un abono sin enviar baja la deuda', () {
      final r = aplicarPendientes(clientes, [
        {'cliente_id': 'b', 'monto': 9000},
      ]);
      expect(r.firstWhere((c) => c['id'] == 'b')['saldo'], -20000);
    });

    test('Varios movimientos del mismo cliente se suman', () {
      final r = aplicarPendientes(clientes, [
        {'cliente_id': 'a', 'monto': -5000},
        {'cliente_id': 'a', 'monto': -3000},
        {'cliente_id': 'a', 'monto': 2000},
      ]);
      expect(r.firstWhere((c) => c['id'] == 'a')['saldo'], -43500);
    });

    test('A los clientes sin movimientos pendientes no los toca', () {
      final r = aplicarPendientes(clientes, [
        {'cliente_id': 'a', 'monto': -5000},
      ]);
      expect(r.firstWhere((c) => c['id'] == 'b')['saldo'], -29000);
      expect(r.firstWhere((c) => c['id'] == 'c')['saldo'], 0);
    });

    test('Sin cola devuelve la lista tal cual', () {
      expect(aplicarPendientes(clientes, const []), same(clientes));
    });

    test('Un movimiento de un cliente que no esta en la lista no rompe', () {
      // Puede pasar si el cliente se creo en otro telefono.
      final r = aplicarPendientes(clientes, [
        {'cliente_id': 'zzz', 'monto': -1000},
      ]);
      expect(r.length, 3);
    });

    test('Un movimiento sin cliente_id se ignora', () {
      final r = aplicarPendientes(clientes, [
        {'monto': -1000},
      ]);
      expect(r.firstWhere((c) => c['id'] == 'a')['saldo'], -37500);
    });
  });
}
