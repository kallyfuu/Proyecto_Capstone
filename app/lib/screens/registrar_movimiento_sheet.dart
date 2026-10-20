import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'historial_movimientos_screen.dart';

import '../models/cliente_saldo.dart';
import '../services/lector_nfc.dart';
import '../theme/app_theme.dart';
import '../utils/formato.dart';

/// Registrar un fiado o un abono para un cliente, y asociar/desvincular su
/// llavero NFC.
///
/// Se abre desde la lista, con el cliente ya elegido, porque en el almacen el
/// cliente esta parado al frente: lo que falta es el monto, no a quien.
class RegistrarMovimientoSheet extends StatefulWidget {
  final ClienteSaldo cliente;

  const RegistrarMovimientoSheet({super.key, required this.cliente});

  /// Devuelve true si se guardo algo, para que la lista se refresque.
  static Future<bool> mostrar(BuildContext context, ClienteSaldo cliente) async {
    final guardado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RegistrarMovimientoSheet(cliente: cliente),
    );
    return guardado ?? false;
  }

  @override
  State<RegistrarMovimientoSheet> createState() =>
      _RegistrarMovimientoSheetState();
}

class _RegistrarMovimientoSheetState extends State<RegistrarMovimientoSheet> {
  final _montoCtrl = TextEditingController();
  final _conceptoCtrl = TextEditingController();
  final _boletaCtrl = TextEditingController();

  bool _esFiado = true;
  bool _guardando = false;
  String? _error;

  // El llavero NO sale de widget.cliente: ClienteSaldo viene de la vista
  // v_clientes_saldo, y no sabemos con certeza si esa vista expone nfc_uid.
  // Para no asumirlo, se consulta aparte directo a la tabla `clientes`,
  // que es donde de verdad vive esa columna.
  String? _nfcUid;
  int? _limiteCredito;
  bool _cargandoLlavero = true;
  bool _leyendoLlavero = false;

  @override
  void initState() {
    super.initState();
    _cargarLlavero();
  }

  @override
  void dispose() {
    _montoCtrl.dispose();
    _conceptoCtrl.dispose();
    _boletaCtrl.dispose();
    // Si cierran la hoja mientras el lector esperaba un llavero, hay que
    // cortar la sesion NFC o queda prendida gastando bateria.
    LectorNfc.cancelar();
    super.dispose();
  }

  /// Pregunta directo a la tabla `clientes` si este cliente ya tiene un
  /// llavero. Si la consulta falla, no bloqueamos el resto de la hoja: solo
  /// se muestra el boton "Asociar llavero" y, si en realidad ya tenia uno,
  /// se corrige la proxima vez que se abra esta hoja.
  Future<void> _cargarLlavero() async {
    try {
      final supabase = Supabase.instance.client;
      final fila = await supabase
          .from('clientes')
          .select('nfc_uid, limite_credito')
          .eq('id', widget.cliente.id)
          .maybeSingle();

      if (!mounted) return;
      setState(() {
        _nfcUid = fila?['nfc_uid']?.toString();
        _limiteCredito = (fila?['limite_credito'] as num?)?.toInt();
        _cargandoLlavero = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _cargandoLlavero = false);
    }
  }

  int get _monto => int.tryParse(_montoCtrl.text.replaceAll('.', '')) ?? 0;

  Future<void> _guardar() async {
    if (_monto <= 0) {
      setState(() => _error = 'Escribe un monto mayor a cero.');
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });

    try {
      final supabase = Supabase.instance.client;
      final negocioId = supabase.auth.currentUser!.id;
      final boleta = _boletaCtrl.text.trim();

      // Pedimos que nos devuelva la fila insertada: si viene vacia, la base no
      // guardo nada y hay que enterarse aqui, no descubrirlo mirando la lista.
      final guardadas = await supabase.from('transacciones').insert({
        // El id lo genera la app, no la base. Asi un reintento despues de
        // perder señal manda el MISMO id y no duplica el movimiento.
        'id': const Uuid().v4(),
        'cliente_id': widget.cliente.id,
        'negocio_id': negocioId,
        // El signo es lo que distingue fiado de abono en el libro mayor.
        'monto': _esFiado ? -_monto : _monto,
        'concepto': _conceptoCtrl.text.trim().isEmpty
            ? (_esFiado ? 'Fiado' : 'Abono')
            : _conceptoCtrl.text.trim(),
        'numero_boleta': boleta.isEmpty ? null : boleta,
        'es_offline': false,
        'fecha_local': DateTime.now().toUtc().toIso8601String(),
      }).select();

      if (guardadas.isEmpty) {
        throw StateError('La base no devolvio la fila insertada.');
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _guardando = false;
        _error = 'No se pudo guardar: $e';
      });
    }
  }

  /// Espera un llavero y lo asocia a este cliente.
  Future<void> _asociarLlavero() async {
    setState(() {
      _leyendoLlavero = true;
      _error = null;
    });

    final uid = await LectorNfc.leerUid();

    if (!mounted) return;

    if (uid == null) {
      setState(() {
        _leyendoLlavero = false;
        _error = 'No se leyó ningún llavero. Intenta de nuevo.';
      });
      return;
    }

    try {
      final supabase = Supabase.instance.client;

      await supabase
          .from('clientes')
          .update({'nfc_uid': uid})
          .eq('id', widget.cliente.id);

      if (!mounted) return;
      setState(() {
        _nfcUid = uid;
        _leyendoLlavero = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _leyendoLlavero = false;
        _error = _mensajeAmigableLlavero('$e');
      });
    }
  }

  /// Quita el llavero de este cliente (por ejemplo, si lo perdio).
  Future<void> _desvincularLlavero() async {
    // Confirmacion antes de desvincular: es una accion que puede dejar al
    // cliente sin forma de identificarse hasta que le asocien uno nuevo.
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Desvincular llavero?'),
        content: const Text(
          'El cliente no va a poder identificarse con este llavero hasta '
          'que le asocies uno nuevo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Desvincular'),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    setState(() {
      _leyendoLlavero = true;
      _error = null;
    });

    try {
      final supabase = Supabase.instance.client;

      await supabase
          .from('clientes')
          .update({'nfc_uid': null})
          .eq('id', widget.cliente.id);

      if (!mounted) return;
      setState(() {
        _nfcUid = null;
        _leyendoLlavero = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _leyendoLlavero = false;
        _error = 'No se pudo desvincular: $e';
      });
    }
  }

  /// Mismo criterio que en nuevo_cliente_sheet.dart: el codigo 23505 es
  /// Postgres diciendo "esto ya existe". Aca significa que el llavero ya
  /// esta asignado a otro cliente de este mismo negocio (la base no permite
  /// que dos clientes del mismo negocio compartan nfc_uid).
  String _mensajeAmigableLlavero(String error) {
    if (error.contains('23505')) {
      return 'Ese llavero ya está asignado a otro cliente.';
    }
    return 'No se pudo asociar: $error';
  }

  @override
  Widget build(BuildContext context) {
    final colorAccion = _esFiado
        ? AppTheme.morosoDe(context)
        : AppTheme.cumplidorDe(context);

    return Padding(
      // Sube el contenido cuando aparece el teclado.
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        // Ver nota en nuevo_cliente_sheet.dart: el area segura evita que la
        // barra de navegacion del celular tape el boton.
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          24 + MediaQuery.of(context).padding.bottom,
        ),
        // Scrollable: con el teclado abierto la hoja no alcanza a caber
        // y Flutter marcaba desbordamiento sobre el boton de guardar.
        child: SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.tiradorDe(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              widget.cliente.nombre,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              textoSaldo(widget.cliente.saldo),
              style: TextStyle(
                color: widget.cliente.debe
                    ? AppTheme.morosoDe(context)
                    : AppTheme.cumplidorDe(context),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            _seccionLimiteCredito(),
            const SizedBox(height: 16),
            _seccionLlavero(),
            const SizedBox(height: 18),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: true,
                  label: Text('Fiar'),
                  icon: Icon(Icons.add_shopping_cart),
                ),
                ButtonSegment(
                  value: false,
                  label: Text('Abonar'),
                  icon: Icon(Icons.payments_outlined),
                ),
              ],
              selected: {_esFiado},
              onSelectionChanged: _guardando
                  ? null
                  : (s) => setState(() {
                      _esFiado = s.first;
                      _error = null;
                    }),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _montoCtrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
              decoration: const InputDecoration(
                labelText: 'Monto',
                prefixText: '\$ ',
              ),
              onChanged: (_) => setState(() => _error = null),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _conceptoCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Concepto (opcional)',
                hintText: _esFiado ? 'Pan, bebidas...' : 'Abono',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _boletaCtrl,
              keyboardType: TextInputType.text,
              decoration: const InputDecoration(
                labelText: 'N° de boleta (opcional)',
                hintText: 'Ej. 12345',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(
                _error!,
                style: TextStyle(color: AppTheme.morosoDe(context)),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: colorAccion),
              onPressed: _guardando ? null : _guardar,
              child: _guardando
                  ? SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppTheme.sobreAcentoDe(context),
                      ),
                    )
                  : Text(
                      _monto > 0
                          ? '${_esFiado ? "Fiar" : "Abonar"} ${formatoCLP(_monto)}'
                          : (_esFiado ? 'Registrar fiado' : 'Registrar abono'),
                    ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _guardando
                  ? null
                  : () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              HistorialMovimientosScreen(cliente: widget.cliente),
                        ),
                      ),
              icon: const Icon(Icons.history),
              label: const Text('Ver historial'),
            ),
          ],
        ),
        ),
      ),
    );
  }

  /// Cuanto debe hoy el cliente.
  int get _deudaActual =>
      widget.cliente.saldo < 0 ? widget.cliente.saldo.abs() : 0;

  /// En cuanto quedaria la deuda si se registra este fiado.
  int get _deudaProyectada => _esFiado ? _deudaActual + _monto : _deudaActual;

  /// Cuanto se pasa del limite, o cero si no se pasa.
  int get _excedente {
    final limite = _limiteCredito ?? 0;
    if (limite <= 0) return 0;
    final exceso = _deudaProyectada - limite;
    return exceso > 0 ? exceso : 0;
  }

  /// Limite de credito del cliente y cuanto le queda disponible.
  ///
  /// Avisa cuando el fiado se pasa del limite, pero NO lo bloquea. El limite
  /// es una referencia que el propio vendedor fijo, y en un negocio de barrio
  /// el que decide si le fia igual a un cliente de años es el vendedor, no el
  /// sistema. Lo que no puede pasar es que se entere despues.
  Widget _seccionLimiteCredito() {
    final limite = _limiteCredito ?? 0;
    if (limite <= 0) return const SizedBox.shrink();

    final disponible = limite - _deudaActual;
    final usado = (_deudaProyectada / limite).clamp(0.0, 1.0);
    final seExcede = _excedente > 0;

    final color = seExcede
        ? AppTheme.morosoDe(context)
        : (usado > 0.8
              ? AppTheme.atrasadoDe(context)
              : AppTheme.cumplidorDe(context));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.speed_outlined, size: 15, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Límite ${formatoCLP(limite)}',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textoTenueDe(context),
                ),
              ),
            ),
            Text(
              disponible > 0
                  ? 'Disponible ${formatoCLP(disponible)}'
                  : 'Sin cupo',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: disponible > 0
                    ? AppTheme.textoTenueDe(context)
                    : AppTheme.morosoDe(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: usado,
            minHeight: 6,
            backgroundColor: AppTheme.bordeDe(context),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        if (seExcede) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.morosoDe(context).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 18,
                  color: AppTheme.morosoDe(context),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Con este fiado se pasa ${formatoCLP(_excedente)} '
                    'de su límite.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.morosoDe(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// Fila de la seccion de llavero: cambia segun el cliente ya tenga uno,
  /// no tenga ninguno, o estemos esperando que acerquen uno.
  Widget _seccionLlavero() {
    if (_cargandoLlavero) {
      return const Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          SizedBox(width: 12),
          Expanded(child: Text('Verificando llavero...')),
        ],
      );
    }

    if (_leyendoLlavero) {
      return const Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text('Acerca el llavero a la parte de atrás del teléfono...'),
          ),
        ],
      );
    }

    if (_nfcUid == null) {
      return OutlinedButton.icon(
        onPressed: _asociarLlavero,
        icon: const Icon(Icons.nfc),
        label: const Text('Asociar llavero'),
      );
    }

    return Row(
      children: [
        Icon(Icons.nfc, color: AppTheme.cumplidorDe(context)),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'Llavero asociado',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        TextButton(
          onPressed: _desvincularLlavero,
          child: const Text('Desvincular'),
        ),
      ],
    );
  }
}
