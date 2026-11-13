# Protección de datos personales — Ley N° 21.719

Anexo técnico del proyecto **Sistema de Gestión de Fiado Inteligente con
Identificación NFC**.

Este documento deja por escrito qué datos personales trata el sistema, cómo
los protege y qué queda pendiente. No afirma que el sistema "cumple la ley":
afirma qué exigencias están cubiertas con evidencia verificable y cuáles no,
que es lo honesto a esta altura del proyecto.

---

## 1. Por qué importa esta ley aquí

La **Ley N° 21.719**, que regula la protección y el tratamiento de los datos
personales y crea la Agencia de Protección de Datos Personales, se publicó el
**13 de diciembre de 2024** y entra en vigencia el **1 de diciembre de 2026**.
Reemplaza a la Ley 19.628.

Existe un proyecto en tramitación (Boletín N° 18.623-07) que propone postergar
su entrada en vigencia al 15 de octubre de 2027. Fue aprobado en la Comisión de
Constitución del Senado, pero **mientras no se publique en el Diario Oficial la
fecha vigente sigue siendo el 1 de diciembre de 2026**.

El sistema trata datos personales de terceros: el vendedor registra el nombre,
el teléfono y la deuda de sus clientes, que no son usuarios del sistema y en
general no tienen forma de saber qué se guarda de ellos. Esa asimetría es
justamente lo que la ley busca corregir, así que no es un requisito accesorio
del proyecto.

**Roles:** el negocio que usa la aplicación es el **responsable** del
tratamiento. El cliente del almacén es el **titular** de los datos.

---

## 2. Qué datos trata el sistema

| Dato | Dónde vive | Para qué |
|---|---|---|
| Nombre del cliente | Tabla `clientes` | Identificarlo en el mostrador |
| Teléfono | Tabla `clientes`, opcional | Enviarle el recordatorio de deuda |
| Límite de crédito | Tabla `clientes` | Avisar al vendedor si lo supera |
| Fiados y abonos | Tabla `transacciones` | Llevar la cuenta |
| Identificador del llavero | Tabla `clientes` (`nfc_uid`) | Buscar al cliente con un toque |
| Token del portal | Tabla `clientes` (`token_portal`) | Dar acceso al cliente a su cuenta |

No se tratan datos sensibles en el sentido del artículo 2 letra g) de la ley:
no hay datos de salud, biométricos, origen étnico, afiliación ni situación
socioeconómica declarada. La deuda es un dato financiero del cliente frente a
ese negocio, no un perfil crediticio.

---

## 3. Exigencias cubiertas, con su evidencia

### Privacidad desde el diseño (art. 14 quáter)

El llavero NFC que se entrega al cliente **no contiene ningún dato personal**.
Lleva únicamente un enlace con un token aleatorio que el negocio puede anular.
Si el cliente pierde el llavero, quien lo encuentre no puede saber de quién es
ni cuánto debe.

> Evidencia: el test `graba el enlace del portal y nada mas`
> (`app/test/escritor_nfc_test.dart`) falla si alguna vez se intenta escribir
> otra cosa en el llavero.

Esta decisión se tomó por diseño del producto antes de considerar la ley, que
es precisamente lo que el artículo exige: medidas desde el diseño y no
añadidas después.

### Seguridad (art. 14 quinquies)

El aislamiento entre negocios **lo impone el motor de base de datos y no la
aplicación**. Un negocio no puede leer los clientes de otro aunque la consulta
venga sin filtros, porque las políticas de seguridad a nivel de fila se evalúan
en el servidor.

> Evidencia: con un token de un negocio, un `SELECT` sin `WHERE` sobre
> `v_clientes_saldo` devuelve solo sus propios clientes. El rol anónimo contra
> `public.clientes` responde `42501 permission denied`. Ambas pruebas se
> ejecutaron desde fuera de la red del proyecto.

Se cerró además un hueco de integridad con una llave foránea compuesta
`transacciones (cliente_id, negocio_id) → clientes (id, negocio_id)`, que
impide registrar un movimiento mezclando el cliente de un negocio con el
identificador de otro.

### Confidencialidad y minimización

- El llavero no transporta datos personales (ver arriba).
- El portal del cliente muestra únicamente la cuenta asociada a su token.
- El teléfono guarda una copia de la lista de clientes para poder trabajar sin
  señal, en el almacenamiento privado de la aplicación, y **esa copia se borra
  al cerrar sesión** (`AlmacenLocal.limpiar()` se ejecuta antes de
  `signOut()`).

### Derecho de acceso

El cliente tiene un portal web propio donde ve su estado de cuenta completo sin
depender de que el vendedor se lo muestre. Se abre acercando el llavero a
cualquier teléfono con NFC; no necesita instalar nada ni crear una cuenta.

### Derecho de oposición y bloqueo

El token del portal tiene un interruptor `token_activo`. Al desactivarlo, la
función `portal_estado_cuenta(token)` devuelve `null` y el enlace deja de
funcionar de inmediato, incluido el que está grabado en el llavero.

> Evidencia: probado con el rol anónimo. Con `token_activo = false` la función
> no entrega datos.

### Derecho de portabilidad

Desde el Panel del negocio se exporta el libro completo de fiados y abonos a un
archivo CSV que se abre en Excel, con la opción de guardarlo en el teléfono o
enviarlo por otro medio.

### Información al titular (art. 14)

El portal del cliente incluye un aviso que explica, en lenguaje simple, quién
trata sus datos, cuáles trata, para qué, que el llavero no lleva datos
personales, y qué puede pedirle al negocio.

> Evidencia: sección "Qué se guarda de ti y qué puedes pedir" en
> `docs/portal/index.html`.

### Calidad e integridad de los datos

El libro de transacciones es inmutable: los movimientos no se editan ni se
borran, se corrigen con un movimiento contrario. Un saldo siempre se puede
reconstruir sumando el historial.

---

## 4. Lo que falta

Se declara abiertamente, porque un anexo que solo enumera aciertos no sirve
para planificar.

| Pendiente | Qué significa | Dificultad |
|---|---|---|
| **Base de licitud registrada** | No queda constancia de por qué el negocio puede tratar los datos de cada cliente (consentimiento u otra base del art. 13). | Media |
| **Supresión y rectificación en la app** | El cliente puede pedirlos, pero el vendedor no tiene hoy un botón para borrar o corregir un cliente. | Media |
| **Procedimiento ante brechas (art. 14 sexies)** | La ley obliga a notificar a la Agencia y, cuando corresponda, a los titulares. No hay procedimiento escrito. | Baja |
| **Cifrado en reposo** | Los datos se cifran en tránsito (HTTPS). En reposo dependen de lo que provee el proveedor de base de datos; no se ha verificado ni documentado. | Media |
| **Plazo de respuesta** | La ley da 30 días corridos para responder una solicitud del titular. No hay un canal formal definido. | Baja |

---

## 5. Qué se puede defender ante una pregunta directa

**"¿Y si alguien se roba un llavero?"**
No obtiene nada: el llavero no tiene nombre ni deuda, solo un código. El
negocio lo anula con un interruptor y el código deja de servir al instante.

**"¿Y si el vendedor pierde el teléfono?"**
Los datos no viven en el teléfono, viven en el servidor. Entra con su cuenta
desde otro equipo y está todo. La copia local que la aplicación guarda para
trabajar sin señal está en el almacenamiento privado de la app y se borra al
cerrar sesión. Además puede tener un respaldo propio en un archivo.

**"¿Un negocio puede ver los clientes de otro?"**
No, y no porque la aplicación lo evite, sino porque la base de datos lo
rechaza. Se probó desde fuera de la red, con consultas sin filtros.

**"¿El identificador del llavero sirve como autenticación?"**
No, y no se usa como tal. Es un identificador de conveniencia que se puede
clonar con tarjetas del tipo "magic". Quien confirma cada transacción es el
vendedor autenticado, mirando al cliente.

---

## 6. Fuentes

- Ley N° 21.719, Biblioteca del Congreso Nacional:
  <https://www.bcn.cl/leychile/navegar?idNorma=1209272>
- Proyecto de postergación, Boletín N° 18.623-07 (en tramitación al momento de
  escribir este anexo; verificar estado en <https://tramitacion.senado.cl>).
