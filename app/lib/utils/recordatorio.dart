import '../models/cliente_saldo.dart';
import 'formato.dart';

/// Dirección pública del portal del cliente.
const String urlPortal = 'https://kallyfuu.github.io/Proyecto_Capstone/portal';

/// Enlace al estado de cuenta de un cliente.
///
/// Un solo lugar arma esta dirección porque ahora se usa en dos partes: el
/// mensaje de WhatsApp y el enlace que se graba dentro del llavero NFC. Si
/// cada una la armara por su cuenta, podrían terminar apuntando a páginas
/// distintas sin que nadie se entere.
String enlacePortal(String token) => '$urlPortal/?token=$token';

/// Deja el teléfono en el formato que espera WhatsApp: solo dígitos, con el
/// código de país adelante.
///
/// En Chile la gente anota el número de mil maneras: +56 9 1234 5678,
/// 912345678, 9 1234 5678. WhatsApp necesita 56912345678 y nada más.
String? telefonoParaWhatsApp(String? telefono) {
  if (telefono == null) return null;

  var digitos = telefono.replaceAll(RegExp(r'[^0-9]'), '');
  if (digitos.isEmpty) return null;

  // Si ya viene con el 56 del país, se respeta.
  if (digitos.startsWith('56')) return digitos;

  // Un celular chileno sin código de país son nueve dígitos y parte con 9.
  if (digitos.length == 9 && digitos.startsWith('9')) return '56$digitos';

  // Ocho dígitos: le falta el 9 del celular.
  if (digitos.length == 8) return '569$digitos';

  return digitos;
}

/// Texto del recordatorio que se le manda al cliente.
///
/// Incluye el enlace a su portal para que pueda ver el detalle por su cuenta,
/// en vez de tener que creerle al mensaje.
String mensajeRecordatorio(ClienteSaldo cliente, String negocio, String token) {
  final saldo = cliente.saldo.abs();
  final enlace = enlacePortal(token);

  if (!cliente.debe) {
    return 'Hola ${cliente.nombre}, le escribimos de $negocio. '
        'Su cuenta está al día, no tiene deudas pendientes. '
        'Puede revisarla cuando quiera acá: $enlace';
  }

  return 'Hola ${cliente.nombre}, le escribimos de $negocio. '
      'Le recordamos que tiene un saldo pendiente de ${formatoCLP(saldo)}. '
      'Puede ver el detalle de sus compras y abonos acá: $enlace';
}

/// Arma el enlace de WhatsApp listo para abrir.
///
/// Devuelve null si el cliente no tiene teléfono: mostrar el botón y que no
/// haga nada es peor que no mostrarlo.
Uri? enlaceWhatsApp(ClienteSaldo cliente, String negocio, String token) {
  final numero = telefonoParaWhatsApp(cliente.telefono);
  if (numero == null) return null;

  return Uri.https('wa.me', '/$numero', {
    'text': mensajeRecordatorio(cliente, negocio, token),
  });
}
