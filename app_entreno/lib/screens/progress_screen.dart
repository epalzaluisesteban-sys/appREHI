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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                    child: Text(
                      switch (_metric) {
                        _Metric.e1rm =>
                          '1RM estimado (Epley) de la mejor serie de cada sesión. Permite '
                              'comparar sesiones aunque cambien las repeticiones.',
                        _Metric.maxWeight => 'Peso más alto levantado en cada sesión.',
                        _Metric.volume => 'Volumen de carga: series × repeticiones × peso.',
                      },
                      style: const TextStyle(color: AppColors.muted, fontSize: 13),
                    ),
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
