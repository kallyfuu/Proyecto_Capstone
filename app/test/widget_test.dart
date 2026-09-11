import 'package:flutter_test/flutter_test.dart';

import 'package:fiado_nfc/theme/app_theme.dart';

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
}
