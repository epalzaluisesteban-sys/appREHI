import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data_actions.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../units.dart';
import '../widgets/common.dart';
import '../widgets/rehi_logo.dart';
import 'day_screen.dart';
import 'history_screen.dart';
import 'new_routine_screen.dart';
import 'routine_screen.dart';
import 'settings_screen.dart';
import 'workout_screen.dart';

/// Pantalla principal: muestra las rutinas creadas con sus días.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _newRoutine(BuildContext context) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const NewRoutineScreen()),
      );

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final active = store.active;

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 60,
        leading: const Padding(
          padding: EdgeInsets.fromLTRB(14, 8, 2, 8),
          child: RehiLogo(),
        ),
        title: const Text('Mis rutinas'),
        actions: [
          IconButton(
            tooltip: 'Historial',
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HistoryScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Ajustes',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          HeaderAddButton(tooltip: 'Nueva rutina', onPressed: () => _newRoutine(context)),
        ],
      ),
      body: store.routines.isEmpty
          ? EmptyState(
              icon: Icons.fitness_center,
              title: 'Aún no tienes rutinas',
              message:
                  'Crea tu primera rutina con el botón + y agrégale los días '
                  'que quieras (p. ej. Torso y Pierna).',
              action: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton.icon(
                    onPressed: () => _newRoutine(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Crear rutina'),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                    onPressed: () => restoreBackup(context),
                    icon: const Icon(Icons.settings_backup_restore),
                    label: const Text('Restaurar copia de seguridad'),
                  ),
                ],
              ),
            )
          : LayoutBuilder(
              builder: (context, c) {
                // En PC/tablet: dos columnas. En celular: una.
                final twoCols = c.maxWidth >= 900;
                const gap = 16.0;
                final cardWidth = twoCols ? (c.maxWidth - gap * 3) / 2 : c.maxWidth - gap * 2;
                return ListView(
                  padding: const EdgeInsets.all(gap),
                  children: [
                    if (active != null) ...[
                      _ActiveBanner(session: active),
                      const SizedBox(height: gap),
                    ],
                    Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        for (final r in store.routines)
                          SizedBox(width: cardWidth, child: _RoutineCard(routine: r)),
                      ],
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _ActiveBanner extends StatelessWidget {
  const _ActiveBanner({required this.session});

  final WorkoutSession session;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const WorkoutScreen()),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.timer_outlined, color: AppColors.background),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Entrenamiento en curso',
                        style: TextStyle(color: AppColors.header, fontSize: 12),
                      ),
                      Text(
                        '${session.dayName} · ${session.doneSetCount} series hechas',
                        style: TextStyle(
                          color: AppColors.background,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'Continuar',
                  style: TextStyle(color: AppColors.background, fontWeight: FontWeight.w700),
                ),
                Icon(Icons.chevron_right, color: AppColors.background),
              ],
            ),
          ),
        ),
      );
}

class _RoutineCard extends StatelessWidget {
  const _RoutineCard({required this.routine});

  final Routine routine;

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
            title: Text(
              routine.name,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            trailing: const Icon(Icons.tune),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => RoutineScreen(routineId: routine.id)),
            ),
          ),
          const Divider(),
          if (routine.days.isEmpty)
            ListTile(
              leading: const Icon(Icons.add_circle_outline, color: AppColors.muted),
              title: const Text('Sin días todavía'),
              subtitle: const Text('Toca para agregar los días de esta rutina',
                  style: TextStyle(color: AppColors.muted)),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => RoutineScreen(routineId: routine.id)),
              ),
            ),
          for (var i = 0; i < routine.days.length; i++)
            _DayTile(
              index: i,
              routine: routine,
              day: routine.days[i],
              last: store.lastSessionForDay(routine.days[i].id),
            ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _DayTile extends StatelessWidget {
  const _DayTile({
    required this.index,
    required this.routine,
    required this.day,
    required this.last,
  });

  final int index;
  final Routine routine;
  final RoutineDay day;
  final WorkoutSession? last;

  @override
  Widget build(BuildContext context) {
    final n = day.exercises.length;
    final avg = context.read<AppStore>().averageDurationSeconds(dayId: day.id);
    final info = [
      n == 0 ? 'Sin ejercicios' : '$n ejercicio${n == 1 ? '' : 's'}',
      if (last != null) 'último: ${fmtShortDate(last!.date)}',
      if (avg != null) 'promedio ${fmtDuration(avg)}',
    ].join(' · ');

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: const Color(0x33FFFFFF),
        foregroundColor: Colors.white,
        child: Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      title: Text(day.name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(info, style: const TextStyle(color: AppColors.muted)),
      trailing: IconButton(
        tooltip: 'Iniciar entrenamiento',
        icon: const Icon(Icons.play_circle_fill, size: 32),
        onPressed: n == 0 ? null : () => startWorkoutFlow(context, routine, day),
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DayScreen(routineId: routine.id, dayId: day.id),
        ),
      ),
    );
  }
}
