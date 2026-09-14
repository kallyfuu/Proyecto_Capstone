import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/cliente_saldo.dart';
import '../theme/app_theme.dart';
import '../utils/formato.dart';
import 'nuevo_cliente_sheet.dart';
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
  List<ClienteSaldo> _clientes = const [];
  String _busqueda = '';
  int _clientesVisibles = 15;
  bool _cargando = true;
  String? _error;

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
      final negocios = await _supabase.from('negocios').select();

      // Ordena la base, no la app: el que mas debe primero, que es a quien hay
      // que cobrarle. Ojo que en Dart `order` viene DESCENDENTE por defecto,
      // por eso el `ascending: true` explicito.
      final filas = await _supabase
          .from('v_clientes_saldo')
          .select()
          .order('saldo', ascending: true);

      if (!mounted) return;

      final fila = negocios.isEmpty ? null : negocios.first;

      setState(() {
        _clientes = filas.map(ClienteSaldo.desdeMapa).toList();
        _negocio =
            (fila?['nombre_negocio'] ?? fila?['nombre'] ?? 'Mi almacén')
                .toString();
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _cargando = false;
      });
    }
  }

  /// Abre el formulario y, si se guardo, vuelve a pedir los saldos.
  /// El saldo nuevo lo calcula la base de datos: la app no lo suma a mano.
  Future<void> _abrirMovimiento(ClienteSaldo cliente) async {
    final guardado = await RegistrarMovimientoSheet.mostrar(context, cliente);
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

  /// Muestra el modal para escanear tarjeta o llavero NFC.
  void _leerNfc() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.azulProfundo.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.nfc,
                  size: 56,
                  color: AppTheme.azulProfundo,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Listo para escanear',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Acerca la tarjeta o llavero NFC al dispositivo para identificar al cliente.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textoTenue, fontSize: 14),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_negocio),
        actions: [
          IconButton(
            tooltip: 'Lista de clientes',
            icon: const Icon(Icons.people_outline),
            onPressed: _mostrarListaClientes,
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () => _supabase.auth.signOut(),
          ),
        ],
      ),
      body: _cuerpo(),
    );
  }

  Widget _cuerpo() {
    if (_cargando && _clientes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _mensajeCentrado(
        icono: Icons.cloud_off,
        color: AppTheme.moroso,
        titulo: 'No se pudo cargar',
        detalle: _error!,
      );
    }

    final totalFiado = _clientes.where((c) => c.debe).fold<int>(
          0,
          (suma, c) => suma + c.saldo.abs(),
        );
    final cuantosDeben = _clientes.where((c) => c.debe).length;
    final totalClientes = _clientes.length;

    return RefreshIndicator(
      onRefresh: _cargar,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final diametro = (constraints.maxWidth * 0.80).clamp(240.0, 320.0);

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 48,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _botonCircularNfc(diametro),
                  _tarjetaResumen(totalFiado, cuantosDeben, totalClientes),
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
      padding: const EdgeInsets.only(top: 48),
      child: Center(
        child: Text(
          'No hay clientes con ese nombre',
          style: const TextStyle(color: AppTheme.textoTenue),
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
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.azulClaro, AppTheme.azulProfundo],
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.azulProfundo.withValues(alpha: 0.35),
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
            onTap: _leerNfc,
            splashColor: Colors.white.withValues(alpha: 0.2),
            highlightColor: Colors.white.withValues(alpha: 0.1),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.nfc,
                    size: 72,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Leer NFC',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Toca para escanear',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Tarjeta con el total fiado, tocable para ver el detalle de clientes.
  Widget _tarjetaResumen(int totalFiado, int cuantosDeben, int totalClientes) {
    final palabraClientes = totalClientes == 1 ? 'cliente' : 'clientes';

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 380),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8EAED)),
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
                const Text(
                  'Total fiado',
                  style: TextStyle(
                    color: AppTheme.textoTenue,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  formatoCLP(totalFiado),
                  style: const TextStyle(
                    color: AppTheme.azulProfundo,
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
                      style: const TextStyle(
                        color: AppTheme.textoTenue,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: AppTheme.textoTenue,
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

  /// Despliega la lista y búsqueda de clientes en un modal inferior.
  void _mostrarListaClientes() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final clientesFiltrados = _clientes.where((cliente) {
              final nombre = cliente.nombre.toLowerCase();
              return nombre.contains(_busqueda.trim().toLowerCase());
            }).toList();
            final clientesVisibles =
                clientesFiltrados.take(_clientesVisibles).toList();

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
                            color: Colors.grey[300],
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
                          setState(() => _busqueda = v);
                          setSheetState(() => _busqueda = v);
                        },
                        decoration: const InputDecoration(
                          hintText: 'Buscar cliente por nombre',
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: clientesFiltrados.isEmpty
                            ? _mensajeListaVacia()
                            : ListView.builder(
                                controller: scrollController,
                                itemCount: clientesVisibles.length +
                                    (clientesVisibles.length <
                                            clientesFiltrados.length
                                        ? 1
                                        : 0),
                                itemBuilder: (context, index) {
                                  if (index < clientesVisibles.length) {
                                    final c = clientesVisibles[index];
                                    return _filaCliente(c);
                                  }
                                  return Padding(
                                    padding: const EdgeInsets.only(
                                        top: 4, bottom: 16),
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        setState(
                                            () => _clientesVisibles += 15);
                                        setSheetState(
                                            () => _clientesVisibles += 15);
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

  Widget _filaCliente(ClienteSaldo cliente) {
    final color = AppTheme.colorEstado(cliente.estadoRiesgo);
    final inicial = cliente.nombre.trim().isEmpty
        ? '?'
        : cliente.nombre.trim()[0].toUpperCase();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _abrirMovimiento(cliente),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: color.withValues(alpha: 0.14),
                child: Text(
                  inicial,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cliente.nombre,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          cliente.estadoRiesgo ?? 'Cumplidor',
                          style: TextStyle(fontSize: 12, color: color),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                textoSaldo(cliente.saldo),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: cliente.debe ? AppTheme.moroso : AppTheme.cumplidor,
                ),
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
              style: const TextStyle(color: AppTheme.textoTenue),
            ),
            if (accion != null) ...[
              const SizedBox(height: 24),
              accion,
            ],
          ],
        ),
      ),
    );
  }
}
