import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/cliente_saldo.dart';
import '../models/resumen_negocio.dart';
import '../theme/app_theme.dart';
import '../utils/formato.dart';

/// Panel del negocio: los números que el vendedor no puede sacar del cuaderno.
///
/// La pantalla principal responde "quién me debe". Esta responde preguntas que
/// solo se ven mirando varios meses juntos: si está prestando más rápido de lo
/// que le pagan, y qué tan sana está su cartera.
class PanelScreen extends StatefulWidget {
  const PanelScreen({super.key});

  @override
  State<PanelScreen> createState() => _PanelScreenState();
}

class _PanelScreenState extends State<PanelScreen> {
  final _supabase = Supabase.instance.client;

  ResumenNegocio? _resumen;
  bool _cargando = true;
  String? _error;
  int? _mesElegido;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final ahora = DateTime.now();
      final desde = DateTime(ahora.year, ahora.month - 5, 1);

      // Ninguna consulta filtra por negocio: lo hace el RLS del motor.
      final movimientos = await _supabase
          .from('transacciones')
          .select('monto, fecha_local, synced_at')
          .gte('fecha_local', desde.toUtc().toIso8601String());

      final filas = await _supabase.from('v_clientes_saldo').select();

      if (!mounted) return;

      setState(() {
        _resumen = ResumenNegocio(
          meses: ResumenNegocio.agruparPorMes(
            List<Map<String, dynamic>>.from(movimientos),
            hasta: ahora,
          ),
          clientes: filas.map(ClienteSaldo.desdeMapa).toList(),
        );
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
    return Scaffold(
      appBar: AppBar(title: const Text('Panel del negocio')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: _cuerpo(),
        ),
      ),
    );
  }

  Widget _cuerpo() {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'No se pudo cargar el panel:\n$_error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.moroso),
          ),
        ),
      );
    }

    final r = _resumen!;

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _filaIndicadores(r),
          const SizedBox(height: 24),
          _tituloSeccion('FIADO Y ABONOS POR MES'),
          _GraficoMensual(
            resumen: r,
            mesElegido: _mesElegido ?? r.meses.length - 1,
            onElegir: (i) => setState(() => _mesElegido = i),
          ),
          const SizedBox(height: 24),
          _tituloSeccion('ESTADO DE LA CARTERA'),
          _BarraCartera(resumen: r),
          const SizedBox(height: 24),
          if (r.topDeudores.isNotEmpty) ...[
            _tituloSeccion('QUIÉNES DEBEN MÁS'),
            _TopDeudores(resumen: r),
          ],
        ],
      ),
    );
  }

  Widget _tituloSeccion(String texto) => Padding(
    padding: const EdgeInsets.only(left: 2, bottom: 10),
    child: Text(
      texto,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: AppTheme.textoTenue.withValues(alpha: 0.9),
      ),
    ),
  );

  Widget _filaIndicadores(ResumenNegocio r) {
    final recuperado = r.porcentajeRecuperado;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _Indicador(
                etiqueta: 'En la calle',
                valor: formatoCLP(r.totalFiado),
                detalle:
                    '${r.clientesConDeuda} ${r.clientesConDeuda == 1 ? "cliente debe" : "clientes deben"}',
                destacado: true,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Indicador(
                etiqueta: 'Deuda promedio',
                valor: formatoCLP(r.deudaPromedio),
                detalle: 'por cliente que debe',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _Indicador(
                etiqueta: 'Fiado este mes',
                valor: formatoCLP(r.fiadoDelMes),
                detalle: 'salió del negocio',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Indicador(
                etiqueta: 'Abonado este mes',
                valor: formatoCLP(r.abonadoDelMes),
                detalle: recuperado == null
                    ? 'entró al negocio'
                    : 'recuperaste el $recuperado%',
                color: recuperado != null && recuperado >= 100
                    ? AppTheme.cumplidor
                    : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Una cifra con su etiqueta. No es un gráfico: cuando el dato es un solo
/// número, un número grande se lee más rápido que cualquier dibujo.
class _Indicador extends StatelessWidget {
  final String etiqueta;
  final String valor;
  final String detalle;
  final bool destacado;
  final Color? color;

  const _Indicador({
    required this.etiqueta,
    required this.valor,
    required this.detalle,
    this.destacado = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: destacado ? AppTheme.azulProfundo : AppTheme.superficie,
        borderRadius: BorderRadius.circular(14),
        border: destacado
            ? null
            : Border.all(color: const Color(0xFFE8EAED)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            etiqueta,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: destacado ? Colors.white70 : AppTheme.textoTenue,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              valor,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                height: 1.1,
                color: destacado
                    ? Colors.white
                    : (color ?? AppTheme.azulProfundo),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            detalle,
            style: TextStyle(
              fontSize: 11,
              color: destacado ? Colors.white70 : AppTheme.textoTenue,
            ),
          ),
        ],
      ),
    );
  }
}

/// Barras agrupadas: por cada mes, lo fiado y lo abonado lado a lado.
///
/// Dos series en una sola escala, nunca dos ejes. Las dos son pesos chilenos,
/// así que comparten altura y la comparación es honesta.
class _GraficoMensual extends StatelessWidget {
  final ResumenNegocio resumen;
  final int mesElegido;
  final ValueChanged<int> onElegir;

  const _GraficoMensual({
    required this.resumen,
    required this.mesElegido,
    required this.onElegir,
  });

  @override
  Widget build(BuildContext context) {
    final maximo = resumen.maximoMensual;
    final elegido = resumen.meses[mesElegido.clamp(0, resumen.meses.length - 1)];

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
      decoration: BoxDecoration(
        color: AppTheme.superficie,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EAED)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _puntoLeyenda(AppTheme.moroso, 'Fiado'),
              const SizedBox(width: 16),
              _puntoLeyenda(AppTheme.cumplidor, 'Abonos'),
              const Spacer(),
              Text(
                'Toca un mes',
                style: TextStyle(
                  fontSize: 10,
                  color: AppTheme.textoTenue.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 140,
            child: maximo == 0
                ? Center(
                    child: Text(
                      'Todavía no hay movimientos registrados',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textoTenue,
                      ),
                    ),
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var i = 0; i < resumen.meses.length; i++)
                        Expanded(
                          child: _ColumnaMes(
                            mes: resumen.meses[i],
                            maximo: maximo,
                            elegido: i == mesElegido,
                            onTap: () => onElegir(i),
                          ),
                        ),
                    ],
                  ),
          ),
          if (maximo > 0) ...[
            const Divider(height: 24),
            // El valor exacto se muestra solo del mes elegido: poner el número
            // sobre las doce barras convierte el gráfico en una tabla ilegible.
            Row(
              children: [
                Expanded(
                  child: _detalle(
                    'Fiado en ${elegido.etiqueta}',
                    formatoCLP(elegido.fiado),
                    AppTheme.moroso,
                  ),
                ),
                Expanded(
                  child: _detalle(
                    'Abonos en ${elegido.etiqueta}',
                    formatoCLP(elegido.abonado),
                    AppTheme.cumplidor,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _puntoLeyenda(Color color, String texto) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 6),
      Text(
        texto,
        style: const TextStyle(fontSize: 12, color: AppTheme.textoTenue),
      ),
    ],
  );

  Widget _detalle(String etiqueta, String valor, Color color) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            etiqueta,
            style: const TextStyle(fontSize: 11, color: AppTheme.textoTenue),
          ),
        ],
      ),
      const SizedBox(height: 2),
      Text(
        valor,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
      ),
    ],
  );
}

class _ColumnaMes extends StatelessWidget {
  final MesMovimiento mes;
  final int maximo;
  final bool elegido;
  final VoidCallback onTap;

  const _ColumnaMes({
    required this.mes,
    required this.maximo,
    required this.elegido,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const altoMaximo = 108.0;
    final altoFiado = maximo == 0 ? 0.0 : (mes.fiado / maximo) * altoMaximo;
    final altoAbono = maximo == 0 ? 0.0 : (mes.abonado / maximo) * altoMaximo;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          SizedBox(
            height: altoMaximo,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _barra(altoFiado, AppTheme.moroso),
                const SizedBox(width: 2),
                _barra(altoAbono, AppTheme.cumplidor),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            mes.etiqueta,
            style: TextStyle(
              fontSize: 11,
              fontWeight: elegido ? FontWeight.bold : FontWeight.normal,
              color: elegido ? AppTheme.azulProfundo : AppTheme.textoTenue,
            ),
          ),
          const SizedBox(height: 3),
          Container(
            height: 2,
            width: 18,
            color: elegido ? AppTheme.azulProfundo : Colors.transparent,
          ),
        ],
      ),
    );
  }

  /// Los extremos de arriba van redondeados y la base pegada al eje: así se
  /// ve de dónde parte la barra y no se puede leer una altura falsa.
  Widget _barra(double alto, Color color) => Container(
    width: 11,
    height: alto < 2 && alto > 0 ? 2 : alto,
    decoration: BoxDecoration(
      color: color,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
    ),
  );
}

/// Una sola barra dividida en los tres estados del semáforo.
///
/// Cada tramo lleva su ícono, su nombre y su número debajo: el ámbar no llega
/// al contraste mínimo sobre fondo claro, así que el color nunca puede ser la
/// única pista de qué significa cada tramo.
class _BarraCartera extends StatelessWidget {
  final ResumenNegocio resumen;

  const _BarraCartera({required this.resumen});

  @override
  Widget build(BuildContext context) {
    final cuenta = resumen.porEstado;
    final total = cuenta.values.fold(0, (a, b) => a + b);

    const estados = [
      ('Cumplidor', AppTheme.cumplidor, Icons.check_circle),
      ('Atrasado', AppTheme.atrasado, Icons.schedule),
      ('Moroso', AppTheme.moroso, Icons.error),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.superficie,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EAED)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (total == 0)
            Text(
              'Todavía no hay clientes',
              style: TextStyle(fontSize: 12, color: AppTheme.textoTenue),
            )
          else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 14,
                child: Row(
                  children: [
                    for (final (nombre, color, _) in estados)
                      if ((cuenta[nombre] ?? 0) > 0) ...[
                        Expanded(
                          flex: cuenta[nombre]!,
                          child: Container(color: color),
                        ),
                        // Separación de 2px entre tramos: sin ella dos colores
                        // vecinos se leen como uno solo.
                        const SizedBox(width: 2),
                      ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            for (final (nombre, color, icono) in estados)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(icono, size: 16, color: color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        nombre,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    Text(
                      '${cuenta[nombre] ?? 0} de $total',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// Barras horizontales con el nombre al lado: para comparar cinco cantidades
/// con etiquetas largas, horizontal se lee mejor que vertical.
class _TopDeudores extends StatelessWidget {
  final ResumenNegocio resumen;

  const _TopDeudores({required this.resumen});

  @override
  Widget build(BuildContext context) {
    final top = resumen.topDeudores;
    final mayor = top.first.saldo.abs();

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 8),
      decoration: BoxDecoration(
        color: AppTheme.superficie,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EAED)),
      ),
      child: Column(
        children: [
          for (final c in top)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          c.nombre,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        formatoCLP(c.saldo.abs()),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  LayoutBuilder(
                    builder: (context, limites) => Container(
                      height: 8,
                      width: mayor == 0
                          ? 0
                          : (c.saldo.abs() / mayor) * limites.maxWidth,
                      decoration: BoxDecoration(
                        color: AppTheme.colorEstado(c.estadoRiesgo),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
