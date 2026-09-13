import 'package:flutter_test/flutter_test.dart';

import 'package:fiado_nfc/theme/app_theme.dart';
import 'package:fiado_nfc/utils/formato.dart';
import 'package:fiado_nfc/utils/texto.dart';

void main() {
  group('Semaforo de riesgo', () {
    test('Moroso se pinta rojo', () {
      expect(AppTheme.colorEstado('Moroso'), AppTheme.moroso);
    });

    test('Atrasado se pinta ambar', () {
      expect(AppTheme.colorEstado('Atrasado'), AppTheme.atrasado);
    });

    test('Cumplidor se pinta verde', () {
      expect(AppTheme.colorEstado('Cumplidor'), AppTheme.cumplidor);
    });

    test('Un estado desconocido o nulo no rompe la pantalla', () {
      expect(AppTheme.colorEstado(null), AppTheme.cumplidor);
      expect(AppTheme.colorEstado('cualquier cosa'), AppTheme.cumplidor);
    });
  });

  group('Plata chilena', () {
    test('Separa los miles con punto y no usa decimales', () {
      expect(formatoCLP(60500), r'$60.500');
      expect(formatoCLP(1500), r'$1.500');
      expect(formatoCLP(500), r'$500');
      expect(formatoCLP(1000000), r'$1.000.000');
    });

    test('El saldo se traduce a lenguaje de almacen', () {
      expect(textoSaldo(-3500), 'Debe \$3.500');
      expect(textoSaldo(0), 'Al día');
      expect(textoSaldo(500), 'A favor \$500');
    });
  });

  group('Busqueda de clientes', () {
    test('Encuentra aunque se escriba sin tilde', () {
      expect(normalizar('María González'), 'maria gonzalez');
      expect(normalizar('Rosa Muñoz'), 'rosa munoz');
    });

    test('No le importan las mayusculas ni los espacios de mas', () {
      expect(normalizar('  PEDRO Soto  '), 'pedro soto');
    });

    test('Un texto sin tildes queda igual', () {
      expect(normalizar('Juan Perez'), 'juan perez');
    });
  });
}
