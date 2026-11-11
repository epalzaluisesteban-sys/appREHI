import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../units.dart';
import '../widgets/common.dart';

enum _Metric {
  e1rm('1RM estimado'),
  maxWeight('Peso máximo'),
  volume('Volumen');

  const _Metric(this.label);
  final String label;
}

/// Gráfica de progreso de un ejercicio a lo largo de las sesiones.
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key, required this.exerciseName});

  final String exerciseName;

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  _Metric _metric = _Metric.e1rm;

  double _valueKg(ProgressPoint p) => switch (_metric) {
        _Metric.e1rm => p.e1rmKg,
        _Metric.maxWeight => p.maxWeightKg,
        _Metric.volume => p.volumeKg,
      };

  String _fmt(double kg, WeightUnit u) =>
      _metric == _Metric.volume ? fmtVolume(kg, u) : fmtWeight(kg, u);

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final unit = store.unit;
    final points = store.progressFor(widget.exerciseName);

    return Scaffold(
      appBar: AppBar(title: Text(widget.exerciseName)),
      body: points.isEmpty
          ? const EmptyState(
              icon: Icons.show_chart,
              title: 'Aún no hay registros',
              message: 'Completa un entrenamiento con este ejercicio y aquí verás '
                  'cómo progresas sesión a sesión.',
            )
          : MaxWidth(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  SegmentedButton<_Metric>(
                    showSelectedIcon: false,
                    segments: [
                      for (final m in _Metric.values)
                        ButtonSegment(value: m, label: Text(m.label)),
                    ],
                    selected: {_metric},
                    onSelectionChanged: (s) => setState(() => _metric = s.first),
                  ),
                  const SizedBox(height: 12),
                  _Stats(points: points, value: _valueKg, fmt: (v) => _fmt(v, unit)),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 20, 20, 8),
                      child: SizedBox(
                        height: 260,
                        child: _Chart(
                          points: points,
                          values: [for (final p in points) kgToUnit(_valueKg(p), unit)],
                          unit: unit,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _ChartHelpButton(
                    metric: _metric,
                    verdict: chartVerdict([for (final p in points) _valueKg(p)]),
                  ),
                  const SectionTitle('Historial'),
                  for (final p in points.reversed) ...[
                    Card(
                      child: ListTile(
                        title: Text(fmtDate(p.date),
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(
                          p.log.doneSets
                              .map((s) =>
                                  '${fmtWeight(s.weightKg!, unit)} × ${s.reps}${s.rir == null ? '' : ' (RIR ${s.rir})'}')
                              .join('\n'),
                          style: const TextStyle(color: AppColors.muted, height: 1.5),
                        ),
                        trailing: Text(
                          _fmt(_valueKg(p), unit),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
    );
  }
}

/// Cómo va la gráfica comparando la última sesión con la mejor marca.
enum Trend { good, normal, warning, tooFew }

/// Lectura rápida de la gráfica a partir de sus valores (de la sesión más
/// antigua a la más reciente).
({Trend trend, String text}) chartVerdict(List<double> values) {
  if (values.length < 3) {
    return (
      trend: Trend.tooFew,
      text: 'Con menos de 3 sesiones todavía no se ve una tendencia. '
          'Sigue registrando este ejercicio.',
    );
  }
  final best = values.reduce(max);
  final last = values.last;
  if (best <= 0) return (trend: Trend.tooFew, text: 'Aún no hay datos suficientes.');
  // Sesiones desde la última vez que se alcanzó la mejor marca.
  final since = values.length - 1 - values.lastIndexWhere((v) => v >= best - 0.001);
  final gap = (best - last) / best * 100;
  final gapText = '${gap.toStringAsFixed(gap < 10 ? 1 : 0)} %';
  if (since == 0) {
    return (trend: Trend.good, text: 'Tu última sesión es tu mejor marca. ¡Vas bien!');
  }
  if (since >= 3) {
    return (
      trend: Trend.warning,
      text: 'Llevas $since sesiones sin superar tu mejor marca y estás $gapText '
          'por debajo. Revisa la parte «Ojo, revisa» de abajo.',
    );
  }
  if (gap <= 3) {
    return (
      trend: Trend.normal,
      text: 'Estás a $gapText de tu mejor marca: dentro de lo normal.',
    );
  }
  return (
    trend: Trend.normal,
    text: 'Estás $gapText por debajo de tu mejor marca. Un día flojo es normal; '
        'si sigue así 2 o 3 sesiones más, revisa la parte «Ojo, revisa».',
  );
}

/// Ventana flotante con la explicación de la gráfica: cómo leerla y qué
/// números indican que vas bien o que conviene revisar algo.
class _ChartHelp extends StatelessWidget {
  const _ChartHelp({required this.metric, required this.verdict});

  final _Metric metric;
  final ({Trend trend, String text}) verdict;

  static const _body = TextStyle(color: AppColors.muted, fontSize: 14, height: 1.4);

  Widget _section(IconData icon, String title, List<String> lines) => Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            for (final l in lines)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 26),
                child: Text(l, style: _body),
              ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final (what, good, normal, warn) = switch (metric) {
      _Metric.e1rm => (
          [
            'Es el peso que, en teoría, podrías levantar una sola vez. Se calcula con '
                'tu mejor serie de cada sesión: peso × (1 + reps ÷ 30). Por ejemplo, '
                '80 kg × 10 reps ≈ 107 kg.',
            'Sirve para comparar sesiones aunque cambies el peso o las repeticiones: '
                'hacer 1 repetición más con el mismo peso también lo sube.',
            'Es más fiable en series de 12 repeticiones o menos.',
          ],
          [
            'La línea sube en general a lo largo de las semanas, aunque tenga algunos '
                'dientes hacia abajo.',
            '«Cambio» en positivo (+). Si llevas poco tiempo entrenando es normal subir '
                'casi cada semana; con más experiencia, +1 a 2 % al mes ya es buen progreso.',
            '«Última» igual a «Mejor» o muy cerca (menos de 3 % por debajo).',
          ],
          [
            'Una bajada suelta de hasta 5 % por un mal día, poco sueño o cansancio.',
            'Una semana de descarga planificada con menos peso.',
          ],
          [
            'La línea está plana o baja 3 sesiones seguidas o más (3 a 4 semanas) sin '
                'que lo hayas planeado.',
            '«Cambio» en negativo (−), o «Última» más de 5 a 10 % por debajo de «Mejor».',
            'Causas habituales: fatiga acumulada, poco descanso, sueño o comida, o el '
                'mismo estímulo demasiado tiempo. Prueba una semana de descarga, revisa '
                'tu RIR (quedarte a 0–3 repeticiones del fallo) o cambia el rango de reps.',
          ],
        ),
      _Metric.maxWeight => (
          [
            'Es el peso más alto que usaste en una serie completada de cada sesión.',
            'No toma en cuenta las repeticiones: si sumas reps con el mismo peso, esta '
                'línea se queda plana aunque estés progresando (míralo en «1RM estimado»).',
          ],
          [
            'Escalones hacia arriba: mantienes el peso unas sesiones mientras sumas '
                'repeticiones y luego lo subes.',
            'Progresión doble: cuando llegas al tope de tu rango de reps en todas las '
                'series, sube el peso la siguiente sesión.',
            '«Cambio» en positivo (+).',
          ],
          [
            'Quedarte plano 2 o 3 sesiones mientras las repeticiones suben.',
            'Bajar el peso a propósito para hacer más repeticiones o en una descarga.',
          ],
          [
            'El peso baja sesión tras sesión sin que lo hayas decidido.',
            'Llevas 4 sesiones o más con el mismo peso y las repeticiones tampoco suben.',
          ],
        ),
      _Metric.volume => (
          [
            'Es la suma de peso × repeticiones de todas las series completadas en la '
                'sesión. Ejemplo: 3 series de 10 reps con 60 kg = 1800 kg.',
            'Sube si haces más series, más repeticiones o más peso.',
          ],
          [
            'Se mantiene estable o sube poco a poco: de 5 a 10 % entre semanas es sano.',
            '«Cambio» en positivo (+) a lo largo de un bloque de entrenamiento.',
          ],
          [
            'Cambia de nivel cuando quitas o agregas series a propósito.',
            'Baja en una semana de descarga.',
          ],
          [
            'Cae más de 10 a 15 % dos o tres sesiones seguidas sin haber quitado series: '
                'suele ser fatiga.',
            'Saltos de más de 20 % de una sesión a otra por agregar muchas series de golpe: '
                'puede costarte recuperarte.',
          ],
        ),
    };

    final verdictIcon = switch (verdict.trend) {
      Trend.good => Icons.trending_up,
      Trend.normal => Icons.trending_flat,
      Trend.warning => Icons.trending_down,
      Trend.tooFew => Icons.hourglass_empty,
    };

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
              child: Row(
                children: [
                  const Icon(Icons.help_outline, color: Colors.white),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('¿Cómo leer esta gráfica?',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0x33FFFFFF)),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _content(verdictIcon, what, good, normal, warn),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _content(
    IconData verdictIcon,
    List<String> what,
    List<String> good,
    List<String> normal,
    List<String> warn,
  ) =>
      [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(verdictIcon, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text.rich(
                    TextSpan(children: [
                      const TextSpan(
                          text: 'Tu lectura ahora: ',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                      TextSpan(text: verdict.text),
                    ]),
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          _section(Icons.visibility_outlined, 'Cómo se lee', const [
            'Cada punto es una sesión en la que hiciste este ejercicio: la más antigua '
                'a la izquierda y la más reciente a la derecha.',
            'Mientras más alto el punto, mayor el valor. Toca un punto para ver el número '
                'exacto y la fecha.',
            'Arriba de la gráfica: «Mejor» es tu marca más alta, «Última» la de tu sesión '
                'más reciente y «Cambio» cuánto subió (+) o bajó (−) la última sesión '
                'respecto de la primera.',
            'Fíjate en la tendencia de varias semanas, no en un solo punto.',
            'En ejercicios con peso por lado (×2) se usa siempre el total de los dos lados.',
          ]),
          _section(Icons.straighten, 'Qué mide: ${metric.label}', what),
          _section(Icons.trending_up, 'Vas bien', good),
          _section(Icons.trending_flat, 'Normal, no te preocupes', normal),
          _section(Icons.trending_down, 'Ojo, revisa', warn),
      ];
}

/// Botón con el ícono «?» debajo de la gráfica: abre la explicación en una
/// ventana flotante.
class _ChartHelpButton extends StatelessWidget {
  const _ChartHelpButton({required this.metric, required this.verdict});

  final _Metric metric;
  final ({Trend trend, String text}) verdict;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          leading: const Icon(Icons.help_outline, color: Colors.white, size: 28),
          title: const Text('¿Cómo leer esta gráfica?',
              style: TextStyle(fontWeight: FontWeight.w800)),
          subtitle: const Text('Qué significan los números y cuándo vas bien',
              style: TextStyle(color: AppColors.muted, fontSize: 13)),
          trailing: const Icon(Icons.open_in_new, color: AppColors.muted, size: 20),
          onTap: () => showDialog<void>(
            context: context,
            builder: (_) => _ChartHelp(metric: metric, verdict: verdict),
          ),
        ),
      );
}

class _Stats extends StatelessWidget {
  const _Stats({required this.points, required this.value, required this.fmt});

  final List<ProgressPoint> points;
  final double Function(ProgressPoint) value;
  final String Function(double) fmt;

  @override
  Widget build(BuildContext context) {
    final first = value(points.first);
    final last = value(points.last);
    final best = points.map(value).reduce(max);
    final change = first == 0 ? 0.0 : (last - first) / first * 100;
    final changeText = points.length < 2
        ? '—'
        : '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)} %';

    Widget tile(String label, String v) => Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
              child: Column(
                children: [
                  Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                  const SizedBox(height: 4),
                  FittedBox(
                    child: Text(v,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ),
          ),
        );

    return Row(
      children: [
        tile('Mejor', fmt(best)),
        const SizedBox(width: 8),
        tile('Última', fmt(last)),
        const SizedBox(width: 8),
        tile('Cambio', changeText),
      ],
    );
  }
}

class _Chart extends StatelessWidget {
  const _Chart({required this.points, required this.values, required this.unit});

  final List<ProgressPoint> points;
  final List<double> values;
  final WeightUnit unit;

  @override
  Widget build(BuildContext context) {
    var lo = values.reduce(min);
    var hi = values.reduce(max);
    final pad = max((hi - lo) * 0.15, hi * 0.05);
    lo = max(0, lo - pad);
    hi = hi + pad;
    if (hi <= lo) hi = lo + 1;
    final n = values.length;
    final labelEvery = max(1, (n / 5).ceil());

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: max(1, n - 1).toDouble(),
        minY: lo,
        maxY: hi,
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: Color(0x22FFFFFF), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 48,
              getTitlesWidget: (v, meta) {
                if (v == meta.min || v == meta.max) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(fmtNum(v.roundToDouble()),
                      textAlign: TextAlign.right,
                      style: const TextStyle(color: AppColors.muted, fontSize: 11)),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              reservedSize: 28,
              getTitlesWidget: (v, meta) {
                final i = v.round();
                if (v != i.toDouble() || i < 0 || i >= n || i % labelEvery != 0) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(fmtShortDate(points[i].date),
                      style: const TextStyle(color: AppColors.muted, fontSize: 11)),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => Colors.white,
            getTooltipItems: (spots) => [
              for (final s in spots)
                LineTooltipItem(
                  '${fmtNum(s.y)} ${unit.label}\n${fmtShortDate(points[s.x.round()].date)}',
                  TextStyle(color: AppColors.background, fontWeight: FontWeight.w700),
                ),
            ],
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [for (var i = 0; i < n; i++) FlSpot(i.toDouble(), values[i])],
            isCurved: n > 2,
            preventCurveOverShooting: true,
            color: Colors.white,
            barWidth: 3,
            dotData: FlDotData(
              getDotPainter: (spot, _, _, _) => FlDotCirclePainter(
                radius: 4,
                color: Colors.white,
                strokeWidth: 2,
                strokeColor: AppColors.header,
              ),
            ),
            belowBarData: BarAreaData(show: true, color: const Color(0x22FFFFFF)),
          ),
        ],
      ),
    );
  }
}
