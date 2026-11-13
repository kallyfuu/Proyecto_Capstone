package cl.capstone.fiado.fiado_nfc

import android.content.ContentValues
import android.os.Build
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Guarda archivos en la carpeta Descargas del telefono.
 *
 * Desde Android 11 una app ya no puede escribir directo en Descargas: hay que
 * pedirselo al sistema a traves de MediaStore, y eso no se puede hacer desde
 * Dart. De ahi este canal.
 *
 * Se resuelve con codigo propio en vez de sumar un plugin de terceros: son
 * treinta lineas y evitan depender de un paquete mas justo antes de la
 * entrega.
 */
class MainActivity : FlutterActivity() {

    private val canal = "cl.capstone.fiado/descargas"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, canal)
            .setMethodCallHandler { llamada, respuesta ->
                if (llamada.method != "guardarEnDescargas") {
                    respuesta.notImplemented()
                    return@setMethodCallHandler
                }

                try {
                    val nombre = llamada.argument<String>("nombre")
                        ?: throw IllegalArgumentException("falta el nombre")
                    val contenido = llamada.argument<ByteArray>("contenido")
                        ?: throw IllegalArgumentException("falta el contenido")
                    val tipo = llamada.argument<String>("tipo") ?: "text/csv"

                    respuesta.success(guardar(nombre, contenido, tipo))
                } catch (e: Exception) {
                    respuesta.error("no_se_pudo_guardar", e.message, null)
                }
            }
    }

    /** Devuelve el nombre con que quedo el archivo en Descargas. */
    private fun guardar(nombre: String, contenido: ByteArray, tipo: String): String {
        // Android 9 y anteriores necesitarian permiso de escritura en disco.
        // No se pide: antes que exigir un permiso que asusta, la app vuelve
        // sola al menu de compartir, que funciona en cualquier version.
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            throw UnsupportedOperationException("Se necesita Android 10 o superior")
        }

        val resolver = contentResolver

        val valores = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, nombre)
            put(MediaStore.Downloads.MIME_TYPE, tipo)
            // Marca el archivo como "en curso" para que nadie lo abra a medio
            // escribir. Se levanta al terminar.
            put(MediaStore.Downloads.IS_PENDING, 1)
        }

        val destino = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, valores)
            ?: throw IllegalStateException("El sistema no entrego un destino en Descargas")

        resolver.openOutputStream(destino).use { salida ->
            if (salida == null) throw IllegalStateException("No se pudo escribir el archivo")
            salida.write(contenido)
        }

        valores.clear()
        valores.put(MediaStore.Downloads.IS_PENDING, 0)
        resolver.update(destino, valores, null, null)

        return nombre
    }
}
