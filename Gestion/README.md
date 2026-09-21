# Gestión del proyecto

Proyecto **Fiado NFC**: registro de fiado con llavero NFC para almacenes de barrio.

| | |
|---|---|
| Director del proyecto | Bastián Bustamante |
| Equipo | Bastián Bustamante, Marcelo Soto, Felipe Olavarría |
| Cliente piloto | Almacén de barrio (Botillería Don Bastián) |
| Período | 03-08-2026 al 27-11-2026 (17 semanas) |

📊 **Carta Gantt:** [`Carta_Gantt_FiadoNFC.xlsx`](Carta_Gantt_FiadoNFC.xlsx)
(GitHub no previsualiza archivos Excel; hay que descargarlo. El resumen de abajo refleja el mismo contenido.)

---

## Estado por fase

### Fase 1 — Definición y levantamiento · ✅ Completada
*Semanas 1 a 4 · 03-08 al 28-08*

| # | Tarea | Responsable | Fechas |
|---|---|---|---|
| 1.1 | Definición del problema y alcance del producto | Equipo | 03-08 → 07-08 |
| 1.1.1 | Validación del caso de uso con almacén de barrio | Bastián | 05-08 → 07-08 |
| 1.2 | Levantamiento de requerimientos funcionales (RF01 a RF05) | Equipo | 10-08 → 14-08 |
| 1.3 | Investigación de tecnología NFC y viabilidad técnica | Felipe | 10-08 → 18-08 |
| 1.4 | Diseño preliminar del modelo de datos | Bastián | 17-08 → 21-08 |
| 1.5 | Informe Fase 1 y evidencias individuales | Equipo | 17-08 → 28-08 |
| 1.6 | Configuración del repositorio GitHub y flujo de ramas | Bastián | 24-08 → 28-08 |

### Fase 2 — Base de datos y seguridad · ✅ Completada
*Semanas 5 a 6 · 31-08 al 11-09*

| # | Tarea | Responsable | Fechas |
|---|---|---|---|
| 2.1 | Corrección del esquema: aislamiento por negocio, montos en CLP entero, token de portal | Bastián | 31-08 → 02-09 |
| 2.2 | Creación de tablas, vista de saldos y alta automática del negocio | Bastián | 03-09 → 08-09 |
| 2.3 | Políticas de seguridad por fila, revocación del rol público y función del portal | Bastián | 08-09 → 10-09 |
| 2.4 | Prueba empírica de aislamiento entre negocios | Bastián | 10-09 → 11-09 |

### Fase 3 — Primera entrega funcional · ✅ Completada
*Semanas 6 a 7 · 07-09 al 14-09*

| # | Tarea | Responsable | Fechas |
|---|---|---|---|
| 3.1 | Entorno Flutter y compilación Android verificada | Bastián | 07-09 → 08-09 |
| 3.2 | Inicio de sesión del almacenero y pantalla de saldos | Bastián | 09-09 → 11-09 |
| 3.2.1 | Registro de fiados y abonos | Bastián | 10-09 → 11-09 |
| 3.2.2 | Historial de movimientos del cliente | Marcelo | 11-09 → 14-09 |
| 3.3 | Alta de clientes y buscador con carga paginada | Bastián y Felipe | 11-09 → 14-09 |
| 3.3.1 | 🏁 **Demostración funcional ante el profesor** | Equipo | 14-09 |

### Fase 4 — Llavero NFC y portal del cliente · 🔄 En curso
*Semanas 8 a 12 · 21-09 al 19-10*

| # | Tarea | Responsable | Fechas | Avance |
|---|---|---|---|---|
| 4.1 | Gestión del proyecto: carta Gantt y documentación en el repositorio | Bastián | 21-09 → 25-09 | 40% |
| 4.2 | Lectura del llavero NFC y asociación al cliente | Marcelo y Felipe | 22-09 → 09-10 | 5% |
| 4.3 | Portal web del cliente con enlace revocable | Bastián | 28-09 → 15-10 | 0% |
| 4.4 | 🏁 **Segunda demostración funcional** | Equipo | 19-10 | — |

### Fase 5 — Cierre y entrega final · ⏳ Pendiente
*Semanas 12 a 17 · 20-10 al 27-11*

| # | Tarea | Responsable | Fechas |
|---|---|---|---|
| 5.1 | Modo sin conexión y sincronización de movimientos | Bastián | 20-10 → 06-11 |
| 5.2 | Pruebas integrales y corrección de hallazgos | Equipo | 02-11 → 13-11 |
| 5.3 | Informe final y manual de usuario | Equipo | 09-11 → 20-11 |
| 5.4 | 🏁 **Presentación final** | Equipo | 23-11 → 27-11 |

---

## Cómo trabajamos

**Una rama por persona y por entrega.** Nadie escribe directo en `main`. Cada tarea sale de una rama propia y entra por un *pull request*, así el historial muestra quién hizo qué sin que haya que explicarlo.

**El merge lo hace otra persona.** Quien sube el código no es quien lo aprueba. Eso obliga a que alguien más lea el cambio antes de que entre.

**Cada entrega se verifica antes de mergear.** Se integra en local, se corre el análisis estático y los tests, y recién ahí se aprueba el pull request.

### Pull requests hasta la fecha

| PR | Aporte | Autor |
|---|---|---|
| #6 | Proyecto Flutter base y compilación Android funcionando | Bastián |
| #7 | Inicio de sesión y pantalla de saldos conectados a la base de datos | Bastián |
| #8 | Historial de movimientos del cliente | Marcelo |
| #9 | Alta de clientes y corrección de interfaz en Android | Bastián |
| #10 | Buscador de clientes con carga paginada | Felipe |
| #11 | Búsqueda sin tildes y pruebas automatizadas | Bastián |

---

## Riesgos identificados

| Riesgo | Mitigación |
|---|---|
| Los llaveros NFC no llegan a tiempo para la Fase 4 | Se puede desarrollar y demostrar la lectura con cualquier tarjeta de 13,56 MHz que ya tengamos (por ejemplo una tarjeta bip!): el código que lee el identificador es el mismo. |
| La aplicación depende de conexión a internet durante la demostración | Se demuestra con datos móviles propios y no con la red del establecimiento. Existe además una grabación de respaldo del recorrido completo. |
| El modo sin conexión (5.1) es la tarea de mayor incertidumbre | La decisión de diseño que lo habilita ya está tomada y aplicada: el identificador de cada movimiento lo genera el teléfono, de modo que un reintento no duplica el registro. |
| Carga de trabajo concentrada en un integrante | Las tareas 4.2 y 4.3 se reparten en paralelo entre los tres, con entregas independientes que no se bloquean entre sí. |

---

*Última actualización: 21-09-2026*
