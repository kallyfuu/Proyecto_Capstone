/// Formato de plata chilena.
///
/// El CLP no tiene decimales y separa los miles con punto: $12.500.
/// Por eso los montos viajan como INTEGER desde la base de datos.
String formatoCLP(int monto) {
  final digitos = monto.abs().toString();
  final buffer = StringBuffer();

  for (var i = 0; i < digitos.length; i++) {
    if (i > 0 && (digitos.length - i) % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(digitos[i]);
  }

  return '${monto < 0 ? '-' : ''}\$$buffer';
}

/// Como se le muestra el saldo al almacenero.
///
/// En la base, saldo negativo = deuda. Pero al almacenero no le sirve leer
/// "-3.500": le sirve leer "Debe $3.500". Traducimos el signo a lenguaje comun.
String textoSaldo(int saldo) {
  if (saldo < 0) return 'Debe ${formatoCLP(saldo.abs())}';
  if (saldo == 0) return 'Al día';
  return 'A favor ${formatoCLP(saldo)}';
}
