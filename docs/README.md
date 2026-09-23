# Portal del cliente

Página pública donde el cliente del almacén consulta su deuda sin instalar
nada y sin crear una cuenta. Corresponde al requerimiento RF04.

**Se abre así:** `.../portal/?token=<token del cliente>`

Cada cliente tiene un `token_portal` único en la base de datos. El almacenero
le comparte ese enlace, y más adelante el token irá grabado en el llavero NFC
para que baste con acercarlo al teléfono.

## Por qué es una página suelta y no parte de la app

La app Flutter es la herramienta de trabajo del almacenero: la usa todos los
días y la tiene instalada. El portal lo abre el cliente una vez cada tanto,
parado en la calle y con datos móviles.

Flutter Web descarga varios megabytes antes de mostrar el primer pixel. Esta
página es un solo archivo HTML y carga de inmediato en cualquier teléfono.
Son dos usuarios con necesidades opuestas, así que son dos piezas distintas.

## Por qué la llave de Supabase está a la vista en el código

Porque es pública por diseño y no protege nada por sí sola. Lo que protege los
datos es que el rol anónimo **no tiene acceso a las tablas**: solo puede
llamar a la función `portal_estado_cuenta`, que exige un token existente y
activo.

Está comprobado contra el servidor real:

| Petición como rol anónimo | Respuesta |
|---|---|
| `GET /rest/v1/clientes` | `401` permiso denegado |
| `GET /rest/v1/v_clientes_saldo` | `401` permiso denegado |
| `POST /rest/v1/rpc/portal_estado_cuenta` con token inválido | `200` y `null` |
| `POST /rest/v1/rpc/portal_estado_cuenta` con token válido | `200` y los datos de **ese** cliente |

Si el cliente pierde el llavero, se marca su `token_activo` en falso y el
enlace deja de entregar datos de inmediato.

## Publicación

Se sirve con GitHub Pages desde la carpeta `docs/` de la rama `main`.
No requiere servidor propio ni costo de hosting.
