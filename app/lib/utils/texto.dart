/// Deja un texto listo para comparar: sin mayusculas, sin tildes y sin espacios
/// sobrantes.
///
/// Hace falta porque en Chile los nombres llevan tilde y la n con virgulilla
/// (Maria Gonzalez, Munoz, Nunez), pero nadie los escribe asi cuando busca
/// apurado en el mostrador. Sin esto, buscar "maria" no encontraria a "Maria".
String normalizar(String texto) {
  const con = 'áàäâãéèëêíìïîóòöôõúùüûñç';
  const sin = 'aaaaaeeeeiiiiooooouuuunc';

  var resultado = texto.toLowerCase();
  for (var i = 0; i < con.length; i++) {
    resultado = resultado.replaceAll(con[i], sin[i]);
  }
  return resultado.trim();
}
