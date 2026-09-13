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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_negocio),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () => _supabase.auth.signOut(),
          ),
        ],
      ),
      body: _cuerpo(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _nuevoCliente,
        backgroundColor: AppTheme.azulProfundo,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Nuevo cliente'),
      ),
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

    if (_clientes.isEmpty) {
      return _mensajeCentrado(
        icono: Icons.people_outline,
        color: AppTheme.textoTenue,
        titulo: 'Todavía no hay clientes',
        detalle: 'Agrega el primero y podrás empezar a registrarle fiados.',
        accion: FilledButton.icon(
          onPressed: _nuevoCliente,
          icon: const Icon(Icons.person_add_alt),
          label: const Text('Agregar cliente'),
        ),
      );
    }

    final clientesFiltrados = _clientes.where((cliente) {
      final nombre = cliente.nombre.toLowerCase();
      return nombre.contains(_busqueda.trim().toLowerCase());
    }).toList();

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _tarjetaResumen(
            _clientes.where((c) => c.debe).fold<int>(
              0,
              (suma, c) => suma + c.saldo.abs(),
            ),
            _clientes.where((c) => c.debe).length,
            _clientes.length,
          ),
          const SizedBox(height: 16),
          TextField(
            onChanged: (v) => setState(() => _busqueda = v),
            decoration: const InputDecoration(
              hintText: 'Buscar cliente por nombre',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 20),
          if (clientesFiltrados.isEmpty)
            _mensajeListaVacia()
          else ...[
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'CLIENTES',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: AppTheme.textoTenue.withValues(alpha: 0.9),
                ),
              ),
            ),
            for (final cliente in clientesFiltrados) _filaCliente(cliente),
          ],
        ],
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

  /// El numero que le importa al almacenero: cuanta plata tiene en la calle.
  Widget _tarjetaResumen(int totalFiado, int cuantosDeben, int totalClientes) {
    final palabraClientes = totalClientes == 1 ? 'cliente' : 'clientes';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.azulProfundo, AppTheme.azulClaro],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Total fiado',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            formatoCLP(totalFiado),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 38,
              fontWeight: FontWeight.bold,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            cuantosDeben == 0
                ? 'Nadie te debe. $totalClientes $palabraClientes al día.'
                : '$cuantosDeben de $totalClientes $palabraClientes con deuda',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
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
