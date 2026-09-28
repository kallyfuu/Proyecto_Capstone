import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/cliente_saldo.dart';
import '../services/lector_nfc.dart';
import '../theme/app_theme.dart';
import '../utils/formato.dart';
import '../utils/texto.dart';
import 'registrar_movimiento_sheet.dart';

/// Posibles estados durante la lectura y procesamiento de un llavero NFC.
enum _EstadoLectura {
  /// Verificando soporte o disponibilidad inicial de hardware.
  verificando,

  /// El teléfono tiene lector NFC pero está apagado en los ajustes.
  apagado,

  /// El teléfono no tiene hardware NFC o la plataforma no lo soporta.
  noSoportado,

  /// El lector está activo esperando que acerquen el llavero.
  esperando,

  /// Leyó el UID y está buscando al cliente en la base de datos.
  buscando,

  /// Se encontró al cliente asociado al llavero.
  encontrado,

  /// El llavero fue leído pero no está registrado en ningún cliente.
  noRegistrado,

  /// Ocurrió un error inesperado de red o de base de datos.
  error,
}

/// Hoja modal para leer llaveros NFC e identificar clientes.
///
/// Permite al vendedor:
/// 1. Conocer si su celular tiene o no NFC activo.
/// 2. Ver la indicación para acercar el llavero.
/// 3. Identificar al cliente asociado con su saldo y registrar movimientos.
/// 4. Si el llavero no está registrado, asociarlo a un cliente de inmediato.
class LeerLlaveroSheet extends StatefulWidget {
  const LeerLlaveroSheet({super.key});

  /// Muestra la hoja modal y devuelve true si se registró un movimiento
  /// o se asoció un cliente, para que el dashboard recargue sus datos.
  static Future<bool> mostrar(BuildContext context) async {
    final resultado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const LeerLlaveroSheet(),
    );
    return resultado ?? false;
  }

  @override
  State<LeerLlaveroSheet> createState() => _LeerLlaveroSheetState();
}

class _LeerLlaveroSheetState extends State<LeerLlaveroSheet> {
  final _supabase = Supabase.instance.client;

  _EstadoLectura _estado = _EstadoLectura.verificando;
  String? _uidLeido;
  ClienteSaldo? _clienteEncontrado;
  String? _error;
  bool _cambioRealizado = false;

  @override
  void initState() {
    super.initState();
    _iniciarLectura();
  }

  @override
  void dispose() {
    // Si el usuario cierra la hoja sin acercar el llavero (arrastrando hacia
    // abajo, con el boton cancelar o con el boton atras de Android), cortamos
    // la sesion NFC para no dejar el lector encendido consumiendo bateria.
    LectorNfc.cancelar();
    super.dispose();
  }

  /// Revisa el hardware NFC y, si esta disponible, pone el lector en escucha.
  Future<void> _iniciarLectura() async {
    setState(() {
      _estado = _EstadoLectura.verificando;
      _error = null;
      _clienteEncontrado = null;
    });

    final estadoNfc = await LectorNfc.estado();
    if (!mounted) return;

    if (estadoNfc == EstadoNfc.apagado) {
      setState(() => _estado = _EstadoLectura.apagado);
      return;
    }

    if (estadoNfc == EstadoNfc.noSoportado) {
      setState(() => _estado = _EstadoLectura.noSoportado);
      return;
    }

    setState(() => _estado = _EstadoLectura.esperando);

    final uid = await LectorNfc.leerUid();
    if (!mounted) return;

    if (uid == null) {
      // Se cumplió el tiempo límite o no se obtuvo identificador
      if (_estado == _EstadoLectura.esperando) {
        setState(() {
          _error = 'No se detectó ningún llavero a tiempo. Intenta de nuevo.';
          _estado = _EstadoLectura.error;
        });
      }
      return;
    }

    await _buscarClientePorUid(uid);
  }

  /// Busca al cliente por su nfc_uid en la vista `v_clientes_saldo`.
  Future<void> _buscarClientePorUid(String uid) async {
    setState(() {
      _estado = _EstadoLectura.buscando;
      _uidLeido = uid;
      _error = null;
    });

    try {
      final filas = await _supabase
          .from('v_clientes_saldo')
          .select()
          .eq('nfc_uid', uid);

      if (!mounted) return;

      if (filas.isEmpty) {
        setState(() {
          _estado = _EstadoLectura.noRegistrado;
        });
      } else {
        final cliente = ClienteSaldo.desdeMapa(filas.first);
        setState(() {
          _clienteEncontrado = cliente;
          _estado = _EstadoLectura.encontrado;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error al consultar la base de datos: $e';
        _estado = _EstadoLectura.error;
      });
    }
  }

  /// Abre la hoja de registrar movimiento para el cliente encontrado.
  Future<void> _abrirMovimiento() async {
    if (_clienteEncontrado == null) return;

    final guardado = await RegistrarMovimientoSheet.mostrar(
      context,
      _clienteEncontrado!,
    );

    if (!mounted) return;

    if (guardado) {
      _cambioRealizado = true;
      Navigator.of(context).pop(true);
    }
  }

  /// Permite asociar el llavero recién leído a un cliente existente.
  Future<void> _asociarACliente() async {
    if (_uidLeido == null) return;

    // Despliega modal para seleccionar cliente
    final clienteSeleccionado = await showModalBottomSheet<ClienteSaldo>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SelectorClienteModal(supabase: _supabase),
    );

    if (clienteSeleccionado == null || !mounted) return;

    setState(() {
      _estado = _EstadoLectura.buscando;
      _error = null;
    });

    try {
      await _supabase
          .from('clientes')
          .update({'nfc_uid': _uidLeido})
          .eq('id', clienteSeleccionado.id);

      if (!mounted) return;

      // Obtenemos los datos actualizados con saldo del cliente recién vinculado
      final actualizados = await _supabase
          .from('v_clientes_saldo')
          .select()
          .eq('id', clienteSeleccionado.id);

      if (!mounted) return;

      final clienteActualizado = actualizados.isNotEmpty
          ? ClienteSaldo.desdeMapa(actualizados.first)
          : clienteSeleccionado;

      _cambioRealizado = true;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Llavero asociado a ${clienteActualizado.nombre}'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      setState(() {
        _clienteEncontrado = clienteActualizado;
        _estado = _EstadoLectura.encontrado;
      });
    } catch (e) {
      if (!mounted) return;
      final errorStr = '$e';
      setState(() {
        _estado = _EstadoLectura.noRegistrado;
        _error = errorStr.contains('23505')
            ? 'Ese llavero ya está asignado a otro cliente.'
            : 'No se pudo asociar el llavero: $errorStr';
      });
    }
  }

  void _cerrar() {
    Navigator.of(context).pop(_cambioRealizado);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: AppTheme.superficie,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          24 + MediaQuery.of(context).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFDADCE0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _construirContenido(),
          ],
        ),
      ),
    );
  }

  Widget _construirContenido() {
    switch (_estado) {
      case _EstadoLectura.verificando:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Comprobando lector NFC...',
                style: TextStyle(color: AppTheme.textoTenue),
              ),
            ],
          ),
        );

      case _EstadoLectura.apagado:
        return _vistaSinNfc(
          titulo: 'NFC desactivado',
          mensaje: 'Activa el NFC en los ajustes',
          detalle:
              'El lector de tu teléfono está apagado. Actívalo en la configuración para poder leer llaveros.',
          icono: Icons.nfc_outlined,
          colorIcono: AppTheme.atrasado,
          mostrarReintentar: true,
        );

      case _EstadoLectura.noSoportado:
        return _vistaSinNfc(
          titulo: 'Sin soporte NFC',
          mensaje: 'Este teléfono no tiene NFC',
          detalle:
              'Este dispositivo no cuenta con tecnología NFC o no está disponible en este entorno.',
          icono: Icons.phonelink_erase,
          colorIcono: AppTheme.moroso,
          mostrarReintentar: false,
          permitirSimulacion: true,
        );

      case _EstadoLectura.esperando:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.azulProfundo.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const SizedBox(
                    width: 76,
                    height: 76,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppTheme.azulProfundo,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.nfc,
                    size: 44,
                    color: AppTheme.azulProfundo,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Acerca el llavero a la parte de atrás del celular',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Mantén el llavero cerca hasta que vibre o se reconozca.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textoTenue, fontSize: 13),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: _cerrar,
              child: const Text('Cancelar'),
            ),
          ],
        );

      case _EstadoLectura.buscando:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text(
                'Buscando cliente...',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              if (_uidLeido != null) ...[
                const SizedBox(height: 6),
                Text(
                  'UID: $_uidLeido',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: AppTheme.textoTenue,
                  ),
                ),
              ],
            ],
          ),
        );

      case _EstadoLectura.encontrado:
        final c = _clienteEncontrado!;
        final color = AppTheme.colorEstado(c.estadoRiesgo);
        final inicial =
            c.nombre.trim().isEmpty ? '?' : c.nombre.trim()[0].toUpperCase();

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Text(
                    inicial,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.nombre,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
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
                            c.estadoRiesgo ?? 'Cumplidor',
                            style: TextStyle(fontSize: 13, color: color),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Text(
                  textoSaldo(c.saldo),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: c.debe ? AppTheme.moroso : AppTheme.cumplidor,
                  ),
                ),
              ],
            ),
            if (_uidLeido != null) ...[
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.fondo,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.nfc, size: 18, color: AppTheme.textoTenue),
                    const SizedBox(width: 8),
                    Text(
                      'Llavero: $_uidLeido',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: AppTheme.textoTenue,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _abrirMovimiento,
              icon: const Icon(Icons.payments_outlined),
              label: const Text('Registrar movimiento'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _cerrar,
              child: const Text('Cerrar'),
            ),
          ],
        );

      case _EstadoLectura.noRegistrado:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.atrasado.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_off_outlined,
                  size: 48,
                  color: AppTheme.atrasado,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Este llavero no está asociado a ningún cliente',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_uidLeido != null) ...[
              Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.fondo,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'UID: $_uidLeido',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            const Text(
              'Puedes vincularlo ahora mismo para que identifique a una persona en sus próximas compras.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textoTenue, fontSize: 13),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.moroso, fontSize: 13),
              ),
            ],
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: _asociarACliente,
              icon: const Icon(Icons.link),
              label: const Text('Asociar a un cliente'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _cerrar,
              child: const Text('Cerrar'),
            ),
          ],
        );

      case _EstadoLectura.error:
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.moroso.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: AppTheme.moroso,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Hubo un problema al leer',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Error desconocido',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textoTenue, fontSize: 13),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: _iniciarLectura,
              icon: const Icon(Icons.refresh),
              label: const Text('Intentar de nuevo'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _cerrar,
              child: const Text('Cerrar'),
            ),
          ],
        );
    }
  }

  Widget _vistaSinNfc({
    required String titulo,
    required String mensaje,
    required String detalle,
    required IconData icono,
    required Color colorIcono,
    required bool mostrarReintentar,
    bool permitirSimulacion = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colorIcono.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icono, size: 48, color: colorIcono),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          mensaje,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          detalle,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.textoTenue, fontSize: 13),
        ),
        const SizedBox(height: 22),
        if (mostrarReintentar) ...[
          FilledButton.icon(
            onPressed: _iniciarLectura,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
          const SizedBox(height: 8),
        ],
        // En emuladores o navegador web, permite probar el flujo completo con
        // el UID de prueba definido en LectorNfc.
        if (permitirSimulacion && (kDebugMode || kIsWeb)) ...[
          OutlinedButton.icon(
            onPressed: () => _buscarClientePorUid(LectorNfc.uidDePrueba),
            icon: const Icon(Icons.developer_mode, size: 18),
            label: const Text('Probar con llavero de prueba'),
          ),
          const SizedBox(height: 8),
        ],
        TextButton(
          onPressed: _cerrar,
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}

/// Modal auxiliar para buscar y seleccionar a cuál cliente asociar el llavero.
class _SelectorClienteModal extends StatefulWidget {
  final SupabaseClient supabase;

  const _SelectorClienteModal({required this.supabase});

  @override
  State<_SelectorClienteModal> createState() => _SelectorClienteModalState();
}

class _SelectorClienteModalState extends State<_SelectorClienteModal> {
  List<ClienteSaldo> _clientes = const [];
  String _busqueda = '';
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final filas = await widget.supabase
          .from('v_clientes_saldo')
          .select()
          .order('nombre', ascending: true);

      if (!mounted) return;

      setState(() {
        _clientes = filas.map(ClienteSaldo.desdeMapa).toList();
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

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: AppTheme.superficie,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFDADCE0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Seleccionar cliente',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Elige a quién pertenece este llavero',
            style: TextStyle(color: AppTheme.textoTenue, fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            onChanged: (v) => setState(() => _busqueda = v),
            decoration: const InputDecoration(
              hintText: 'Buscar cliente por nombre',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _construirLista(),
          ),
        ],
      ),
    );
  }

  Widget _construirLista() {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Text(
          'Error al cargar clientes: $_error',
          style: const TextStyle(color: AppTheme.moroso),
        ),
      );
    }

    final query = normalizar(_busqueda);
    final filtrados = _clientes.where((c) {
      return normalizar(c.nombre).contains(query);
    }).toList();

    if (filtrados.isEmpty) {
      return const Center(
        child: Text(
          'No se encontraron clientes',
          style: TextStyle(color: AppTheme.textoTenue),
        ),
      );
    }

    return ListView.builder(
      itemCount: filtrados.length,
      itemBuilder: (context, index) {
        final cliente = filtrados[index];
        final color = AppTheme.colorEstado(cliente.estadoRiesgo);
        final inicial = cliente.nombre.trim().isEmpty
            ? '?'
            : cliente.nombre.trim()[0].toUpperCase();

        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          leading: CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.15),
            child: Text(
              inicial,
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ),
          title: Text(
            cliente.nombre,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            textoSaldo(cliente.saldo),
            style: TextStyle(
              color: cliente.debe ? AppTheme.moroso : AppTheme.cumplidor,
              fontSize: 12,
            ),
          ),
          trailing: const Icon(Icons.arrow_forward_ios, size: 14),
          onTap: () => Navigator.of(context).pop(cliente),
        );
      },
    );
  }
}
