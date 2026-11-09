import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/cliente_saldo.dart';
import '../services/almacen_local.dart';
import '../widgets/esqueleto_clientes.dart';
import '../theme/app_theme.dart';
import '../theme/modo_tema.dart';
import '../utils/formato.dart';
import '../utils/texto.dart';
import 'bienvenida_negocio_dialog.dart';
import 'leer_llavero_sheet.dart';
import 'nuevo_cliente_sheet.dart';
import 'panel_screen.dart';
import 'registrar_movimiento_sheet.dart';

/// Pantalla principal: quien me debe y cuanto.
///
/// Es lo primero que necesita el almacenero cuando abre la app, asi que es lo
/// primero que ve. Los saldos salen de la vista `v_clientes_saldo`, que los
/// calcula sumando las transacciones en la base de datos.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _supabase = Supabase.instance.client;

  // El estado se guarda tal cual, no envuelto en un Future. Asi "recargar" es
  // simplemente volver a llamar a _cargar() y pisar estas variables.
  String _negocio = 'Mi almacén';
  String? _dueno;
  bool _verificoBienvenida = false;
  List<ClienteSaldo> _clientes = const [];
  String _busqueda = '';
  String? _filtroEstado;
  int _clientesVisibles = 15;
  bool _cargando = true;
  String? _error;
  bool _sinConexion = false;
  DateTime? _fechaCache;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  /// Ninguna de las dos consultas lleva `where negocio_id = ...`.
  /// Pedimos "todo" y el RLS del motor devuelve solo lo de este negocio.
  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      // Las dos consultas son independientes, asi que salen juntas en vez de
      // una despues de la otra. Con una conexion lenta eso es la diferencia
      // entre esperar una vez y esperar dos.
      //
      // Ordena la base, no la app: el que mas debe primero, que es a quien hay
      // que cobrarle. Ojo que en Dart `order` viene DESCENDENTE por defecto,
      // por eso el `ascending: true` explicito.
      final respuestas = await Future.wait([
        _supabase.from('negocios').select(),
        _supabase
            .from('v_clientes_saldo')
            .select()
            .order('saldo', ascending: true),
      ]);
      final negocios = respuestas[0];
      final filas = respuestas[1];

      if (!mounted) return;

      final fila = negocios.isEmpty ? null : negocios.first;
      final nombreBase =
          (fila?['nombre_negocio'] ?? fila?['nombre'] ?? 'Mi almacén')
              .toString();
      final datosPerfil = await BienvenidaNegocioDialog.obtenerDatosActuales(
        filaNegocio: fila,
      );

      // La ultima vista buena queda guardada para cuando no haya señal.
      await AlmacenLocal.guardarClientes(
        List<Map<String, dynamic>>.from(filas),
        nombreBase,
      );
      // Si volvio la señal, se empuja lo que haya quedado pendiente.
      final enviados = await AlmacenLocal.sincronizar();

      if (!mounted) return;

      if (enviados > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              enviados == 1
                  ? 'Se envió 1 movimiento que estaba pendiente'
                  : 'Se enviaron $enviados movimientos pendientes',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      setState(() {
        _sinConexion = false;
        _fechaCache = null;
        _clientes = filas.map(ClienteSaldo.desdeMapa).toList();
        _dueno = (datosPerfil?.nombreDueno.isNotEmpty ?? false)
            ? datosPerfil!.nombreDueno
            : null;
        _negocio = (datosPerfil?.nombreNegocio.isNotEmpty ?? false)
            ? datosPerfil!.nombreNegocio
            : nombreBase;
        _cargando = false;
      });

      if (!_verificoBienvenida) {
        _verificoBienvenida = true;
        final yaCompleto = await BienvenidaNegocioDialog.yaCompletoBienvenida(
          filaNegocio: fila,
        );
        // Si es un usuario nuevo que aun no completo su perfil de bienvenida,
        // mostramos la ventana emergente para registrar sus datos.
        if (!yaCompleto && mounted) {
          final guardados = await BienvenidaNegocioDialog.mostrar(
            context,
            datosIniciales: datosPerfil,
            esEdicion: false,
          );
          if (guardados != null && mounted) {
            setState(() {
              _dueno = guardados.nombreDueno;
              _negocio = guardados.nombreNegocio;
            });
          }
        }
      }
    } catch (e) {
      // Sin señal no se muestra una pantalla de error: se muestra lo ultimo
      // que se vio, diciendo claramente de cuando es. Un vendedor atendiendo
      // prefiere un dato de hace dos horas que una pantalla en blanco.
      final guardado = await AlmacenLocal.leerClientes();
      final cola = await AlmacenLocal.colaPendiente();
      await AlmacenLocal.refrescarConteo();
      if (!mounted) return;

      if (guardado != null) {
        final ajustados = aplicarPendientes(guardado.clientes, cola)
            .map(ClienteSaldo.desdeMapa)
            .toList();
        ajustados.sort((a, b) => a.saldo.compareTo(b.saldo));

        setState(() {
          _clientes = ajustados;
          _negocio = guardado.negocio;
          _sinConexion = true;
          _fechaCache = guardado.fecha;
          _error = null;
          _cargando = false;
        });
        return;
      }

      setState(() {
        _error = '$e';
        _cargando = false;
      });
    }
  }

  /// Hace cuanto se guardo la copia que se esta mostrando.
  String get _antiguedadCache {
    final fecha = _fechaCache;
    if (fecha == null) return 'datos guardados';

    final minutos = DateTime.now().difference(fecha).inMinutes;
    if (minutos < 1) return 'recién';
    if (minutos < 60) return 'hace $minutos min';

    final horas = minutos ~/ 60;
    if (horas < 24) return 'hace $horas ${horas == 1 ? "hora" : "horas"}';

    final dias = horas ~/ 24;
    return 'hace $dias ${dias == 1 ? "día" : "días"}';
  }

  /// Abre la ventana para ver o actualizar los datos del dueño y del negocio.
  Future<void> _editarDatosNegocio() async {
    final negocios = await _supabase.from('negocios').select();
    final fila = negocios.isEmpty ? null : negocios.first;
    final actuales = await BienvenidaNegocioDialog.obtenerDatosActuales(
      filaNegocio: fila,
    );
    if (!mounted) return;

    final guardados = await BienvenidaNegocioDialog.mostrar(
      context,
      datosIniciales: actuales,
      esEdicion: true,
    );
    if (guardados != null && mounted) {
      setState(() {
        _dueno = guardados.nombreDueno;
        _negocio = guardados.nombreNegocio;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Datos del negocio actualizados'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Abre el formulario y, si se guardo, vuelve a pedir los saldos.
  /// El saldo nuevo lo calcula la base de datos: la app no lo suma a mano.
  Future<void> _abrirMovimiento(ClienteSaldo cliente) async {
    final guardado = await RegistrarMovimientoSheet.mostrar(
      context,
      cliente,
      negocio: _negocio,
    );
    if (!guardado || !mounted) return;

    await _cargar();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Movimiento registrado'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Abre la hoja de lectura de llavero NFC para identificar al cliente.
  Future<void> _leerLlavero() async {
    final actualizado = await LeerLlaveroSheet.mostrar(context);
    if (!actualizado || !mounted) return;
    await _cargar();
  }

  /// Da de alta un cliente y vuelve a cargar la lista para que aparezca.
  Future<void> _nuevoCliente() async {
    final creado = await NuevoClienteSheet.mostrar(context);
    if (!creado || !mounted) return;

    await _cargar();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cliente agregado'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // En un celular esto no hace nada (la pantalla es mas angosta), pero en
      // un navegador maximizado evita que las tarjetas se estiren a lo ancho
      // de todo el monitor y la lista quede ilegible.
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                _encabezado(),
                Expanded(child: _cuerpo()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Nombre de pila para el saludo, usando el nombre del dueño si ya lo guardó
  /// o sacado del correo de la sesion como respaldo.
  String get _nombreVendedor {
    if (_dueno != null && _dueno!.trim().isNotEmpty) {
      return _dueno!.trim();
    }
    final correo = _supabase.auth.currentUser?.email ?? '';
    final antes = correo.split('@').first.split(RegExp(r'[._-]')).first;
    if (antes.isEmpty) return 'vendedor';
    return antes[0].toUpperCase() + antes.substring(1);
  }

  Widget _botonRedondo({
    required IconData icono,
    required String tooltip,
    VoidCallback? onTap,
    Widget? reemplazo,
  }) {
    return Container(
      width: 38,
      height: 38,
      margin: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        color: AppTheme.textoTenueDe(context).withValues(alpha: 0.10),
        shape: BoxShape.circle,
      ),
      child:
          reemplazo ??
          IconButton(
            tooltip: tooltip,
            padding: EdgeInsets.zero,
            iconSize: 19,
            icon: Icon(icono),
            onPressed: onTap,
          ),
    );
  }

  Widget _encabezado() {
    final conectado = _error == null && !_sinConexion;
    final colorEstado = conectado
        ? AppTheme.cumplidorDe(context)
        : AppTheme.morosoDe(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.cumplidorDe(context).withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  _nombreVendedor[0],
                  style: TextStyle(
                    color: AppTheme.cumplidorDe(context),
                    fontWeight: FontWeight.w700,
                    fontSize: 19,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hola, $_nombreVendedor',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppTheme.textoTenueDe(context),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      _negocio,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
              _botonRedondo(
                icono: Icons.person_add_alt_1_outlined,
                tooltip: 'Nuevo cliente',
                onTap: _nuevoCliente,
              ),
              _botonRedondo(
                icono: Icons.insights_outlined,
                tooltip: 'Panel del negocio',
                onTap: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const PanelScreen())),
              ),
              _botonRedondo(
                icono: Icons.more_horiz,
                tooltip: 'Más opciones',
                reemplazo: ValueListenableBuilder<ThemeMode>(
                  valueListenable: ModoTema.modo,
                  builder: (context, modo, _) => PopupMenuButton<String>(
                    tooltip: 'Más opciones',
                    padding: EdgeInsets.zero,
                    iconSize: 19,
                    icon: const Icon(Icons.more_horiz),
                    onSelected: (v) {
                      switch (v) {
                        case 'negocio':
                          _editarDatosNegocio();
                        case 'clientes':
                          _mostrarListaClientes();
                        case 'salir':
                          AlmacenLocal.limpiar().then(
                            (_) => _supabase.auth.signOut(),
                          );
                        case 'sistema':
                          ModoTema.elegir(ThemeMode.system);
                        case 'claro':
                          ModoTema.elegir(ThemeMode.light);
                        case 'oscuro':
                          ModoTema.elegir(ThemeMode.dark);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'negocio',
                        child: Text('Datos del negocio'),
                      ),
                      const PopupMenuItem(
                        value: 'clientes',
                        child: Text('Lista de clientes'),
                      ),
                      const PopupMenuDivider(),
                      CheckedPopupMenuItem(
                        value: 'sistema',
                        checked: modo == ThemeMode.system,
                        child: const Text('Tema automático'),
                      ),
                      CheckedPopupMenuItem(
                        value: 'claro',
                        checked: modo == ThemeMode.light,
                        child: const Text('Tema claro'),
                      ),
                      CheckedPopupMenuItem(
                        value: 'oscuro',
                        checked: modo == ThemeMode.dark,
                        child: const Text('Tema oscuro'),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'salir',
                        child: Text('Cerrar sesión'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Dice lo que de verdad sabemos: si la ultima consulta respondio.
          // No decimos "listo para trabajar sin conexion" porque todavia no
          // es cierto, y una interfaz que promete lo que no hace se cae sola
          // en la primera pregunta.
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: colorEstado.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: colorEstado,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      conectado
                          ? 'En línea'
                          : 'Sin conexión · $_antiguedadCache',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: colorEstado,
                      ),
                    ),
                  ],
                ),
              ),
              // Lo que falta enviar tiene que estar a la vista: es plata que
              // todavia no esta registrada en ninguna parte salvo este
              // telefono.
              ValueListenableBuilder<int>(
                valueListenable: AlmacenLocal.pendientes,
                builder: (context, cuantos, _) {
                  if (cuantos == 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.atrasadoDe(
                          context,
                        ).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.cloud_upload_outlined,
                            size: 12,
                            color: AppTheme.atrasadoDe(context),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            cuantos == 1
                                ? '1 sin enviar'
                                : '$cuantos sin enviar',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.atrasadoDe(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cuerpo() {
    if (_cargando && _clientes.isEmpty) {
      return const FondoEsqueleto(child: EsqueletoClientes());
    }

    if (_error != null) {
      return _mensajeCentrado(
        icono: Icons.cloud_off,
        color: AppTheme.morosoDe(context),
        titulo: 'No se pudo cargar',
        detalle: _error!,
      );
    }

    final totalFiado = _clientes
        .where((c) => c.debe)
        .fold<int>(0, (suma, c) => suma + c.saldo.abs());
    final cuantosDeben = _clientes.where((c) => c.debe).length;
    final totalClientes = _clientes.length;

    // El circulo del NFC sigue siendo el protagonista, pero deja ver el
    // principio de la lista. Si ocupa toda la pantalla, el vendedor no sabe
    // quien le debe sin tocar nada, que es justo lo que la app vino a
    // resolver.
    final busqueda = normalizar(_busqueda);
    final clientesFiltrados = _clientes.where((cliente) {
      if (!normalizar(cliente.nombre).contains(busqueda)) return false;
      if (_filtroEstado == null) return true;
      return (cliente.estadoRiesgo ?? 'Cumplidor') == _filtroEstado;
    }).toList();
    final clientesVisibles = clientesFiltrados.take(_clientesVisibles).toList();
    final animarEntrada = busqueda.isEmpty && _filtroEstado == null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final anchoMax = constraints.maxWidth * 0.62;
        final altoMax = constraints.maxHeight * 0.30;
        final menor = anchoMax < altoMax ? anchoMax : altoMax;
        final diametro = menor.clamp(170.0, 230.0).toDouble();

        return RefreshIndicator(
          onRefresh: _cargar,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
            children: [
              // RepaintBoundary aisla el pulso en su propia capa: sin el, cada
              // cuadro de la respiracion repinta toda la lista de abajo.
              RepaintBoundary(
                child: SizedBox(
                  height: diametro * 1.08,
                  child: Center(
                    child: _botonCircularNfc(diametro)
                        .animate(onPlay: (c) => c.repeat(reverse: true))
                        .scale(
                          begin: const Offset(1, 1),
                          end: const Offset(1.035, 1.035),
                          duration: 1600.ms,
                          curve: Curves.easeInOut,
                        ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _tarjetaResumen(totalFiado, cuantosDeben, totalClientes),
              if (_clientes.isEmpty)
                _mensajeCentrado(
                  icono: Icons.people_outline,
                  color: AppTheme.textoTenueDe(context),
                  titulo: 'Todavía no hay clientes',
                  detalle:
                      'Agrega el primero y podrás empezar a registrarle fiados.',
                  accion: FilledButton.icon(
                    onPressed: _nuevoCliente,
                    icon: const Icon(Icons.person_add_alt),
                    label: const Text('Agregar cliente'),
                  ),
                )
              else ...[
                const SizedBox(height: 18),
                TextField(
                  onChanged: (v) => setState(() {
                    _busqueda = v;
                    _clientesVisibles = 15;
                  }),
                  decoration: const InputDecoration(
                    hintText: 'Buscar cliente por nombre',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 12),
                _chipsDeEstado(
                  filtroActivo: _filtroEstado,
                  onCambiarFiltro: (nuevo) => setState(() {
                    _filtroEstado = nuevo;
                    _clientesVisibles = 15;
                  }),
                ),
                const SizedBox(height: 16),
                if (clientesFiltrados.isEmpty)
                  _mensajeListaVacia()
                else ...[
                  for (final (i, cliente) in clientesVisibles.indexed)
                    if (animarEntrada)
                      _filaCliente(cliente)
                          .animate()
                          .fadeIn(delay: (50 * i).ms, duration: 260.ms)
                          .slideY(
                            begin: 0.12,
                            end: 0,
                            delay: (50 * i).ms,
                            duration: 260.ms,
                            curve: Curves.easeOutCubic,
                          )
                    else
                      _filaCliente(cliente),
                  if (clientesVisibles.length < clientesFiltrados.length)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: OutlinedButton.icon(
                        onPressed: () =>
                            setState(() => _clientesVisibles += 15),
                        icon: const Icon(Icons.expand_more),
                        label: const Text('Cargar más'),
                      ),
                    ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }

  /// Chips para filtrar por estado del semaforo, con el conteo de cada uno.
  ///
  /// Filtra en memoria sobre los clientes ya cargados: no vuelve a consultar
  /// la base, asi que responde al instante.
  Widget _chipsDeEstado({
    required String? filtroActivo,
    required ValueChanged<String?> onCambiarFiltro,
  }) {
    final conteo = <String, int>{'Cumplidor': 0, 'Atrasado': 0, 'Moroso': 0};
    for (final c in _clientes) {
      final e = c.estadoRiesgo ?? 'Cumplidor';
      conteo[e] = (conteo[e] ?? 0) + 1;
    }

    final opciones = <(String?, String, int, Color)>[
      (null, 'Todos', _clientes.length, AppTheme.acentoDe(context)),
      ('Moroso', 'Morosos', conteo['Moroso']!, AppTheme.morosoDe(context)),
      (
        'Atrasado',
        'Atrasados',
        conteo['Atrasado']!,
        AppTheme.atrasadoDe(context),
      ),
      (
        'Cumplidor',
        'Al día',
        conteo['Cumplidor']!,
        AppTheme.cumplidorDe(context),
      ),
    ];

    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: opciones.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (valor, etiqueta, cuantos, color) = opciones[i];
          final activo = filtroActivo == valor;

          return GestureDetector(
            onTap: () => onCambiarFiltro(valor),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: activo
                    ? color.withValues(alpha: 0.16)
                    : AppTheme.textoTenueDe(context).withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: activo ? color : Colors.transparent,
                  width: 1.2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (valor != null) ...[
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                  ],
                  Text(
                    '$etiqueta ($cuantos)',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
                      color: activo ? color : AppTheme.textoTenueDe(context),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _mensajeListaVacia() {
    return Padding(
      padding: EdgeInsets.only(top: 48),
      child: Center(
        child: Text(
          'No hay clientes con ese nombre',
          style: TextStyle(color: AppTheme.textoTenueDe(context)),
        ),
      ),
    );
  }

  /// Botón circular grande que ocupa casi toda la pantalla para leer NFC.
  Widget _botonCircularNfc(double diametro) {
    return Center(
      child: Container(
        width: diametro,
        height: diametro,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppTheme.degradadoDe(context),
          boxShadow: [
            BoxShadow(
              color: AppTheme.acentoDe(context).withValues(alpha: 0.32),
              blurRadius: 26,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _leerLlavero,
            splashColor: Colors.white.withValues(alpha: 0.2),
            highlightColor: Colors.white.withValues(alpha: 0.1),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(diametro * 0.06),
                  decoration: BoxDecoration(
                    color: AppTheme.sobreAcentoDe(context)
                        .withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.nfc,
                    size: diametro * 0.28,
                    color: AppTheme.sobreAcentoDe(context),
                  ),
                ),
                SizedBox(height: diametro * 0.07),
                Text(
                  'Leer NFC',
                  style: TextStyle(
                    fontSize: diametro * 0.125,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.sobreAcentoDe(context),
                    letterSpacing: 0.8,
                  ),
                ),
                SizedBox(height: diametro * 0.02),
                Text(
                  'Toca para escanear',
                  style: TextStyle(
                    fontSize: diametro * 0.05,
                    color: AppTheme.sobreAcentoDe(context)
                        .withValues(alpha: 0.78),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Tarjeta con el total fiado en el footer, tocable para desplegar clientes.
  Widget _tarjetaResumen(int totalFiado, int cuantosDeben, int totalClientes) {
    final palabraClientes = totalClientes == 1 ? 'cliente' : 'clientes';
    final superficie = Theme.of(context).colorScheme.surface;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: superficie,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.bordeDe(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _mostrarListaClientes,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Column(
              children: [
                Text(
                  'Total fiado',
                  style: TextStyle(
                    color: AppTheme.textoTenueDe(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  formatoCLP(totalFiado),
                  style: TextStyle(
                    color: AppTheme.acentoDe(context),
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      cuantosDeben == 0
                          ? 'Nadie te debe. $totalClientes $palabraClientes al día.'
                          : '$cuantosDeben de $totalClientes $palabraClientes con deuda',
                      style: TextStyle(
                        color: AppTheme.textoTenueDe(context),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: AppTheme.textoTenueDe(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Despliega la lista, búsqueda y filtros de clientes en un modal inferior.
  void _mostrarListaClientes() {
    String busquedaModal = '';
    String? filtroEstadoModal;
    int clientesVisiblesModal = 15;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final busquedaNorm = normalizar(busquedaModal);
            final clientesFiltrados = _clientes.where((cliente) {
              if (!normalizar(cliente.nombre).contains(busquedaNorm)) return false;
              if (filtroEstadoModal == null) return true;
              return (cliente.estadoRiesgo ?? 'Cumplidor') == filtroEstadoModal;
            }).toList();
            final clientesVisibles = clientesFiltrados
                .take(clientesVisiblesModal)
                .toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.85,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (_, scrollController) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: AppTheme.manijaDe(context),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Clientes',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              Navigator.pop(ctx);
                              await _nuevoCliente();
                            },
                            icon: const Icon(Icons.person_add_alt),
                            label: const Text('Nuevo'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        onChanged: (v) {
                          setSheetState(() {
                            busquedaModal = v;
                            clientesVisiblesModal = 15;
                          });
                        },
                        decoration: const InputDecoration(
                          hintText: 'Buscar cliente por nombre',
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _chipsDeEstado(
                        filtroActivo: filtroEstadoModal,
                        onCambiarFiltro: (nuevo) {
                          setSheetState(() {
                            filtroEstadoModal = nuevo;
                            clientesVisiblesModal = 15;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: clientesFiltrados.isEmpty
                            ? _mensajeListaVacia()
                            : ListView.builder(
                                controller: scrollController,
                                itemCount:
                                    clientesVisibles.length +
                                    (clientesVisibles.length <
                                            clientesFiltrados.length
                                        ? 1
                                        : 0),
                                itemBuilder: (context, index) {
                                  if (index < clientesVisibles.length) {
                                    final c = clientesVisibles[index];
                                    return _filaCliente(
                                      c,
                                      onActualizado: () => setSheetState(() {}),
                                    );
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.only(
                                      top: 4,
                                      bottom: 16,
                                    ),
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        setSheetState(() {
                                          clientesVisiblesModal += 15;
                                        });
                                      },
                                      icon: const Icon(Icons.expand_more),
                                      label: const Text('Cargar más'),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _filaCliente(ClienteSaldo cliente, {VoidCallback? onActualizado}) {
    final color = AppTheme.colorEstadoDe(context, cliente.estadoRiesgo);
    final estado = cliente.estadoRiesgo ?? 'Cumplidor';
    final cupo = cliente.cupoUsado;
    final nombre = cliente.nombre.trim();
    final inicial = nombre.isEmpty ? '?' : nombre[0].toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.bordeDe(context)),
        boxShadow: AppTheme.sombraSuave,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          await _abrirMovimiento(cliente);
          onActualizado?.call();
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Row(
            children: [
              // Avatar con la inicial sobre el color de su estado, suave.
              // Da identidad a cada fila sin agregar una foto que nadie va a
              // cargar en un negocio de barrio.
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  inicial,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 19,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Insignia del semaforo: lleva el texto del estado, no
                    // solo el color. El ambar queda bajo el contraste minimo
                    // sobre fondo claro, asi que el color nunca puede ser la
                    // unica pista de que significa.
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            estado,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Cuanto del cupo que le fijo el vendedor lleva
                    // ocupado. Solo aparece si tiene limite definido: una
                    // barra vacia haria creer que no le queda cupo cuando en
                    // realidad nadie le puso uno.
                    if (cupo != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: cupo,
                                minHeight: 4,
                                backgroundColor: AppTheme.textoTenueDe(context)
                                    .withValues(alpha: 0.15),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  color,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Cupo ${(cupo * 100).round()}%',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textoTenueDe(context),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    textoSaldo(cliente.saldo),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: cliente.debe
                          ? AppTheme.morosoDe(context)
                          : AppTheme.cumplidorDe(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: AppTheme.textoTenueDe(context),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mensajeCentrado({
    required IconData icono,
    required Color color,
    required String titulo,
    required String detalle,
    Widget? accion,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icono, size: 56, color: color),
            const SizedBox(height: 16),
            Text(
              titulo,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              detalle,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textoTenueDe(context)),
            ),
            if (accion != null) ...[const SizedBox(height: 24), accion],
          ],
        ),
      ),
    );
  }
}
