# fiado_nfc

App Flutter del Proyecto Capstone: registro de fiado (deuda de almacén) con lectura NFC.

## Requisitos

| Herramienta | Version usada | Ruta en el equipo de Bastian |
|---|---|---|
| Flutter SDK | canal stable | `C:\src\flutter` |
| Android SDK | platform 36, build-tools 36.1.0 | `C:\Users\Public\Android` |
| Android NDK | 28.2.13676358 | `C:\Users\Public\Android\ndk\28.2.13676358` |
| JDK | 17 | el que trae Android Studio |

> **Ojo con la ruta del SDK.** No lo instalen bajo `C:\Users\<usuario>\...` si el nombre de usuario
> tiene tilde o espacios (ej: `Bastián`): Gradle y el NDK fallan con rutas asi. Por eso el SDK vive
> en `C:\Users\Public\Android` y el repo en `C:\dev\Proyecto_Capstone`.

## Primera vez que compilas

`android/local.properties` **no esta en el repo** (cada uno tiene sus rutas). Se genera solo la
primera vez que corres `flutter build` o `flutter run`, pero si no aparece, crealo a mano:

```properties
sdk.dir=C:\ruta\a\tu\Android\Sdk
flutter.sdk=C:\ruta\a\tu\flutter
```

Despues:

```bash
flutter pub get
flutter build apk --debug
```

El APK queda en `build/app/outputs/flutter-apk/app-debug.apk`.

## Problema conocido: el NDK no se instala solo

Si el build se cae con esto:

```
Package ndk not found.
Package 28.2.13676358 not found.
> Process 'command '...\cmdline-tools\latest\bin\sdkmanager.bat''
  finished with non-zero exit value -1073740791
```

**Causa:** el plugin Gradle de Flutter instala el NDK ejecutando
`sdkmanager --install "ndk;28.2.13676358"`, pero desde `cmdline-tools 23.0.0` el `sdkmanager` fue
reemplazado por el nuevo "Android CLI", que nombra los paquetes con `/` en vez de `;`. Lee `ndk` y
`28.2.13676358` como dos paquetes distintos, no encuentra ninguno y crashea.

**Solucion:** instalar el NDK a mano con la sintaxis nueva (ajusta `--sdk_root` a tu ruta):

```bash
cd <TU_ANDROID_SDK>/cmdline-tools/latest/bin
./sdkmanager.bat --sdk_root="C:\Users\Public\Android" --install "ndk/28.2.13676358"
```

Son ~700 MB de descarga que se descomprimen a ~2.1 GB, asi que anda por unos 10 minutos.

**El comando va a terminar con error `-1073740791` igual que antes: es normal.** El CLI crashea al
cerrar, *despues* de dejar todo instalado. Verifica que quedo bien mirando que exista este archivo:

```
<TU_ANDROID_SDK>\ndk\28.2.13676358\source.properties
```

con `Pkg.Revision = 28.2.13676358` adentro. Si esta, ya podes compilar: Flutter detecta el NDK
instalado y ni siquiera vuelve a llamar al `sdkmanager`.

## Estructura

```
lib/main.dart          punto de entrada
android/               proyecto Android (Gradle Kotlin DSL)
test/                  tests de widgets
```
