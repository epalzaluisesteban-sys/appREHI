import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../units.dart';
import '../widgets/common.dart';

/// Lista de entrenamientos realizados, con su fecha, series y duración,
/// y un resumen con la duración promedio.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final list = store.sessions.reversed.toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Historial')),
      body: list.isEmpty
          ? const EmptyState(
              icon: Icons.history,
              title: 'Sin entrenamientos',
              message: 'Cuando finalices un entrenamiento aparecerá aquí con su fecha y duración.',
            )
          : MaxWidth(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (store.averageDurationSeconds() != null) ...[
                    _DurationSummary(store: store),
                    const SectionTitle('Entrenamientos'),
                  ],
                  for (final s in list) ...[
                    _SessionCard(session: s),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
    );
  }
}

/// Resumen: duración promedio general y por cada día de rutina.
class _DurationSummary extends StatelessWidget {
  const _DurationSummary({required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final avg = store.averageDurationSeconds()!;
    final count = store.timedSessionCount();

    // Un renglón por día de rutina (nombre más reciente de ese día).
    final days = <String, String>{};
    for (final s in store.sessions) {
      if (s.durationSeconds != null) days[s.dayId] = s.dayName;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Duración promedio por sesión',
                style: TextStyle(color: AppColors.muted, fontSize: 13)),
            const SizedBox(height: 4),
            Text(fmtDuration(avg),
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
            Text('Calculado con $count ${count == 1 ? 'entrenamiento' : 'entrenamientos'}',
                style: const TextStyle(color: AppColors.muted, fontSize: 13)),
            if (days.length > 1) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              for (final e in days.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(e.value, style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      Text(
                        '${fmtDuration(store.averageDurationSeconds(dayId: e.key)!)}  ',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '(${store.timedSessionCount(dayId: e.key)})',
                        style: const TextStyle(color: AppColors.muted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session});

  final WorkoutSession session;

  Future<void> _editDuration(BuildContext context) async {
    var minutes = ((session.durationSeconds ?? 3600) / 60).round().clamp(1, 600);
    final r = await showDialog<int>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setState) => AlertDialog(
          title: const Text('Duración del entrenamiento'),
          content: NumberStepper(
            label: 'Minutos',
            value: minutes,
            min: 1,
            max: 600,
            step: 5,
            onChanged: (v) => setState(() => minutes = v),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(c, minutes), child: const Text('Guardar')),
          ],
        ),
      ),
    );
    if (r != null && context.mounted) {
      context.read<AppStore>().setSessionDuration(session, r * 60);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final unit = store.unit;
    final s = session;
    final duration = s.durationSeconds;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: Colors.white,
          collapsedIconColor: AppColors.muted,
          title: Text('${s.dayName} · ${fmtDate(s.date)}',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(
            [
              if (duration != null) 'duró ${fmtDuration(duration)}',
              '${s.exercises.length} ejercicios',
              '${s.doneSetCount} series',
              fmtVolume(s.volumeKg, unit),
            ].join(' · '),
            style: const TextStyle(color: AppColors.muted),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(s.routineName, style: const TextStyle(color: AppColors.muted)),
            ),
            for (final e in s.exercises)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      e.doneSets.map((x) => '${fmtWeight(x.weightKg!, unit)}×${x.reps}').join('  ·  '),
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
            Wrap(
              alignment: WrapAlignment.end,
              children: [
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: AppColors.muted),
                  onPressed: () => _editDuration(context),
                  icon: const Icon(Icons.timer_outlined),
                  label: Text(duration == null ? 'Agregar duración' : 'Editar duración'),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: AppColors.muted),
                  onPressed: () async {
                    final ok = await confirm(
                      context,
                      title: 'Eliminar entrenamiento',
                      message: '¿Eliminar ${s.dayName} del ${fmtDate(s.date)}? '
                          'No se puede deshacer.',
                      ok: 'Eliminar',
                    );
                    if (ok) store.deleteSession(s);
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Eliminar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
