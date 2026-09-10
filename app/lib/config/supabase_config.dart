/// Credenciales publicas del proyecto Supabase.
///
/// La llave `anonKey` es PUBLICA por diseno: viaja dentro del APK y cualquiera
/// puede extraerla. Lo que protege los datos no es esconder esta llave, sino el
/// Row Level Security del motor de base de datos, que ya esta activo y probado.
///
/// La llave `service_role` NO va aqui ni en ningun otro archivo de la app:
/// esa se salta el RLS por completo.
class SupabaseConfig {
  static const String url = 'https://dezaopfumergwdbxazvi.supabase.co';
  static const String anonKey = 'sb_publishable_abjzoT6PmovXzo7moem2Yw_22kvYoYT';
}
