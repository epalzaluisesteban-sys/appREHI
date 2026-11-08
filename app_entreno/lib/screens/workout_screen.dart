import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../units.dart';
import '../warmup.dart';
import '../widgets/common.dart';
import '../widgets/rest_timer.dart';
import 'exercise_editor.dart' show restPresets;
import 'progress_screen.dart';

/// Inicia (o retoma) el entrenamiento de un día y abre la pantalla de registro.
Future<void> startWorkoutFlow(BuildContext context, Routine routine, RoutineDay day) async {
  final store = context.read<AppStore>();
  final active = store.active;
  if (active != null && active.dayId != day.id) {
    final discard = await confirm(
      context,
      title: 'Entrenamiento en curso',
      message: 'Tienes "${active.dayName}" sin terminar. '
          '¿Descartarlo y empezar ${day.name}?',
      ok: 'Descartar y empezar',
    );
    if (!discard) return;
  }
  if (store.active?.dayId != day.id) store.startSession(routine, day);
  if (context.mounted) {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkoutScreen()));
  }
}

/// Registro del entrenamiento: peso, repeticiones y RIR por serie,
/// con temporizador de descanso al completar cada serie.
class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  late final _timer = RestTimer(
    soundEnabled: () => mounted && context.read<AppStore>().alarmSound,
  );

  @override
  void dispose() {
    _timer.dispose();
    super.dispose();
  }

  Future<void> _pickDate(WorkoutSession s) async {
    final d = await showDatePicker(
      context: context,
      initialDate: s.date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      helpText: 'Día del entrenamiento',
    );
    if (d != null && mounted) context.read<AppStore>().setActiveDate(d);
  }

  Future<void> _finish(WorkoutSession s) async {
    final store = context.read<AppStore>();
    final done = s.doneSetCount;
    final start = s.startedAt;
    final elapsed = start == null ? null : DateTime.now().difference(start).inSeconds;
    final avg = store.averageDurationSeconds(dayId: s.dayId);
    final timeInfo = elapsed == null
        ? ''
        : '\n\nDuración: ${fmtDuration(elapsed)}'
            '${avg == null ? '' : ' (tu promedio en ${s.dayName}: ${fmtDuration(avg)})'}.';
    final ok = await confirm(
      context,
      title: 'Finalizar entrenamiento',
      message: done == 0
          ? 'No has completado ninguna serie. Marca las series con ✓ para guardarlas.'
          : 'Se guardarán $done series completadas de ${s.dayName} '
              '(${fmtDate(s.date)}). Las series sin marcar no se guardan.$timeInfo',
      ok: done == 0 ? 'Salir sin guardar' : 'Guardar',
    );
    if (!ok || !mounted) return;
    var saved = false;
    if (done > 0) {
      saved = store.finishActive();
    } else {
      store.discardActive();
    }
    _timer.stop();
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    if (saved) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Entrenamiento guardado 💪')),
      );
    }
  }

  void _onSetDone(WorkoutSession s, int exIndex, ExerciseLog log) {
    final allDone = log.sets.every((x) => x.done);
    final next = exIndex + 1 < s.exercises.length ? s.exercises[exIndex + 1].name : null;
    final label = allDone
        ? (next == null ? '${log.name} terminado' : 'Siguiente: $next')
        : log.name;
    _timer.start(log.restSeconds, label);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final s = store.active;
    if (s == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('No hay un entrenamiento en curso')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.dayName),
            Text(s.routineName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: AppColors.muted)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(onPressed: () => _finish(s), child: const Text('Finalizar')),
          ),
        ],
      ),
      body: MaxWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.event, size: 18),
                  label: Text(fmtDate(s.date)),
                  tooltip: 'Cambiar el día del entrenamiento',
                  onPressed: () => _pickDate(s),
                ),
                if (s.startedAt != null)
                  Chip(
                    avatar: const Icon(Icons.timer_outlined, size: 18),
                    label: _ElapsedClock(start: s.startedAt!),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < s.exercises.length; i++) ...[
              _ExerciseCard(
                key: ValueKey('${s.exercises[i].exerciseId}-${store.unit.name}'),
                log: s.exercises[i],
                unit: store.unit,
                previous: store.previousSetsFor(s.exercises[i].name),
                warmupPercents: store
                        .plannedExercise(s.routineId, s.exercises[i].exerciseId)
                        ?.warmupPercents ??
                    const [],
                onSetDone: () => _onSetDone(s, i, s.exercises[i]),
              ),
              const SizedBox(height: 12),
            ],
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: AppColors.muted),
              onPressed: () async {
                final ok = await confirm(
                  context,
                  title: 'Descartar entrenamiento',
                  message: 'Se perderán las series registradas hoy.',
                  ok: 'Descartar',
                );
                if (ok && context.mounted) {
                  store.discardActive();
                  Navigator.pop(context);
                }
              },
              icon: const Icon(Icons.delete_outline),
              label: const Text('Descartar entrenamiento'),
            ),
          ],
        ),
      ),
      bottomNavigationBar: RestTimerBar(timer: _timer),
    );
  }
}

class _ExerciseCard extends StatefulWidget {
  const _ExerciseCard({
    super.key,
    required this.log,
    required this.unit,
    required this.previous,
    required this.warmupPercents,
    required this.onSetDone,
  });

  final ExerciseLog log;
  final WeightUnit unit;
  final List<SetLog> previous;
  final List<int> warmupPercents;
  final VoidCallback onSetDone;

  @override
  State<_ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends State<_ExerciseCard> {
  ExerciseLog get log => widget.log;
  WeightUnit get unit => widget.unit;
  List<SetLog> get previous => widget.previous;
  VoidCallback get onSetDone => widget.onSetDone;

  Future<void> _editRest(BuildContext context) async {
    var value = log.restSeconds;
    final r = await showDialog<int>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setState) => AlertDialog(
          title: Text('Descanso · ${log.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in restPresets)
                    ChoiceChip(
                      label: Text(fmtRest(p)),
                      selected: value == p,
                      onSelected: (_) => setState(() => value = p),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              NumberStepper(
                label: 'Tiempo',
                value: value,
                min: 15,
                max: 600,
                step: 15,
                format: fmtRest,
                onChanged: (v) => setState(() => value = v),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(c, value), child: const Text('Guardar')),
          ],
        ),
      ),
    );
    if (r != null && context.mounted) context.read<AppStore>().setRest(log.exerciseId, r);
  }

  /// Valor a usar si el usuario marca la serie sin escribir nada:
  /// la misma serie de la sesión anterior o, si no hay, la serie previa de hoy.
  SetLog? _fallbackFor(int i) {
    if (i < previous.length) return previous[i];
    if (previous.isNotEmpty) return previous.last;
    if (i > 0 && log.sets[i - 1].hasData) return log.sets[i - 1];
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final done = log.sets.where((x) => x.done).length;
    const headStyle = TextStyle(color: AppColors.subtle, fontSize: 12, fontWeight: FontWeight.w600);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(log.name,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                      Text(
                        'Objetivo: ${log.repsMin == log.repsMax ? log.repsMin : '${log.repsMin}–${log.repsMax}'} reps · '
                        '$done/${log.sets.length} series',
                        style: const TextStyle(color: AppColors.muted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  onPressed: () => _editRest(context),
                  icon: const Icon(Icons.timer_outlined, size: 18),
                  label: Text(fmtRest(log.restSeconds)),
                ),
                IconButton(
                  tooltip: 'Progreso',
                  icon: const Icon(Icons.show_chart),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ProgressScreen(exerciseName: log.name)),
                  ),
                ),
              ],
            ),
            if (widget.warmupPercents.isNotEmpty)
              _WarmupLine(
                baseKg: warmupBaseKg(log.sets, previous),
                percents: widget.warmupPercents,
                unit: unit,
              ),
            const SizedBox(height: 6),
            Row(
              children: [
                _head('Serie', _Col.set, headStyle),
                Expanded(child: _head('Anterior', null, headStyle, align: TextAlign.left)),
                _head(unit.label, _Col.weight, headStyle),
                const SizedBox(width: _Col.gap),
                _head('Reps', _Col.reps, headStyle),
                const SizedBox(width: _Col.gap),
                _head('RIR', _Col.rir, headStyle),
                const SizedBox(width: _Col.check),
              ],
            ),
            for (var i = 0; i < log.sets.length; i++)
              _SetRow(
                key: ValueKey('${log.exerciseId}-$i'),
                index: i,
                set: log.sets[i],
                unit: unit,
                previous: i < previous.length ? previous[i] : null,
                fallback: () => _fallbackFor(i),
                onDone: onSetDone,
                // Recalcula las aproximaciones mientras se escribe el peso.
                onWeightChanged:
                    widget.warmupPercents.isEmpty ? null : () => setState(() {}),
              ),
            Row(
              children: [
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  onPressed: () {
                    log.sets.add(SetLog());
                    store.changed();
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Serie'),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: AppColors.muted),
                  onPressed: log.sets.length > 1 && !log.sets.last.done
                      ? () {
                          log.sets.removeLast();
                          store.changed();
                        }
                      : null,
                  icon: const Icon(Icons.remove, size: 18),
                  label: const Text('Quitar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SetRow extends StatefulWidget {
  const _SetRow({
    super.key,
    required this.index,
    required this.set,
    required this.unit,
    required this.previous,
    required this.fallback,
    required this.onDone,
    this.onWeightChanged,
  });

  final int index;
  final SetLog set;
  final WeightUnit unit;
  final SetLog? previous;
  final SetLog? Function() fallback;
  final VoidCallback onDone;
  final VoidCallback? onWeightChanged;

  @override
  State<_SetRow> createState() => _SetRowState();
}

class _SetRowState extends State<_SetRow> {
  late final _w = TextEditingController(text: weightField(widget.set.weightKg, widget.unit));
  late final _r = TextEditingController(text: widget.set.reps?.toString() ?? '');
  late final _rir = TextEditingController(text: widget.set.rir?.toString() ?? '');

  @override
  void dispose() {
    _w.dispose();
    _r.dispose();
    _rir.dispose();
    super.dispose();
  }

  void _toggle() {
    final store = context.read<AppStore>();
    final s = widget.set;
    if (s.done) {
      setState(() => s.done = false);
      store.changed();
      return;
    }
    final fb = widget.fallback();
    if (s.weightKg == null && fb?.weightKg != null) {
      s.weightKg = fb!.weightKg;
      _w.text = weightField(s.weightKg, widget.unit);
    }
    if (s.reps == null && fb?.reps != null) {
      s.reps = fb!.reps;
      _r.text = '${s.reps}';
    }
    if (!s.hasData) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe el peso y las repeticiones de la serie')),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    HapticFeedback.lightImpact();
    setState(() => s.done = true);
    store.changed();
    widget.onDone();
  }

  InputDecoration _dec(String? hint) => InputDecoration(
        hintText: hint,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      );

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final s = widget.set;
    final p = widget.previous;
    final fb = widget.fallback();
    final prevText = p == null || !p.hasData
        ? '—'
        : '${fmtNum(kgToUnit(p.weightKg!, widget.unit))}×${p.reps}'
            '${p.rir == null ? '' : ' @${p.rir}'}';
    const fieldStyle = TextStyle(fontWeight: FontWeight.w700, color: Colors.white);

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: s.done ? AppColors.doneRow : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          SizedBox(
            width: _Col.set,
            child: Text('${widget.index + 1}',
                textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          Expanded(
            child: Text(prevText,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.muted, fontSize: 13)),
          ),
          SizedBox(
            width: _Col.weight,
            child: TextField(
              controller: _w,
              enabled: !s.done,
              textAlign: TextAlign.center,
              style: fieldStyle,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
              decoration: _dec(fb?.weightKg == null ? null : weightField(fb!.weightKg, widget.unit)),
              onChanged: (v) {
                final n = parseNum(v);
                s.weightKg = n == null ? null : unitToKg(n, widget.unit);
                store.saveSoon();
                widget.onWeightChanged?.call();
              },
            ),
          ),
          const SizedBox(width: _Col.gap),
          SizedBox(
            width: _Col.reps,
            child: TextField(
              controller: _r,
              enabled: !s.done,
              textAlign: TextAlign.center,
              style: fieldStyle,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: _dec(fb?.reps?.toString()),
              onChanged: (v) {
                s.reps = int.tryParse(v);
                store.saveSoon();
              },
            ),
          ),
          const SizedBox(width: _Col.gap),
          SizedBox(
            width: _Col.rir,
            child: TextField(
              controller: _rir,
              enabled: !s.done,
              textAlign: TextAlign.center,
              style: fieldStyle,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(1),
              ],
              decoration: _dec('–'),
              onChanged: (v) {
                s.rir = int.tryParse(v);
                store.saveSoon();
              },
            ),
          ),
          SizedBox(
            width: _Col.check,
            child: IconButton(
              tooltip: s.done ? 'Desmarcar serie' : 'Completar serie',
              onPressed: _toggle,
              icon: Icon(
                s.done ? Icons.check_circle : Icons.check_circle_outline,
                color: s.done ? Colors.white : AppColors.muted,
                size: 28,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pesos de las series de aproximación: "Aproximación  17 · 36 · 45 kg".
class _WarmupLine extends StatelessWidget {
  const _WarmupLine({required this.baseKg, required this.percents, required this.unit});

  final double? baseKg;
  final List<int> percents;
  final WeightUnit unit;

  @override
  Widget build(BuildContext context) {
    final base = baseKg;
    return Container(
      margin: const EdgeInsets.only(top: 8, right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.trending_up, size: 18, color: AppColors.muted),
          const SizedBox(width: 8),
          const Text('Aproximación',
              style: TextStyle(color: AppColors.muted, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(width: 10),
          Expanded(
            child: base == null
                ? const Text('escribe el peso de trabajo',
                    style: TextStyle(color: AppColors.muted, fontSize: 13))
                : Text(
                    '${warmupWeights(base, percents, unit).join(' · ')} ${unit.label}',
                    semanticsLabel: 'Series de aproximación: '
                        '${warmupWeights(base, percents, unit).join(', ')} ${unit.label}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Anchos de las columnas de la tabla de series (encabezado y filas).
abstract final class _Col {
  static const double set = 40;
  static const double weight = 64;
  static const double reps = 50;
  static const double rir = 42;
  static const double check = 44;
  static const double gap = 4;
}

/// Título de columna en una sola línea (se reduce si no cabe, nunca se parte).
Widget _head(String text, double? width, TextStyle style, {TextAlign align = TextAlign.center}) {
  final t = FittedBox(
    fit: BoxFit.scaleDown,
    alignment: align == TextAlign.left ? Alignment.centerLeft : Alignment.center,
    child: Text(text, style: style, maxLines: 1, softWrap: false),
  );
  return width == null ? t : SizedBox(width: width, child: t);
}

/// Tiempo transcurrido desde que empezó el entrenamiento, actualizado cada segundo.
class _ElapsedClock extends StatefulWidget {
  const _ElapsedClock({required this.start});

  final DateTime start;

  @override
  State<_ElapsedClock> createState() => _ElapsedClockState();
}

class _ElapsedClockState extends State<_ElapsedClock> {
  late final Timer _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));

  @override
  void initState() {
    super.initState();
    _tick;
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text(
        fmtClock(DateTime.now().difference(widget.start).inSeconds.clamp(0, 359999)),
        semanticsLabel: 'Tiempo de entrenamiento',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      );
}
