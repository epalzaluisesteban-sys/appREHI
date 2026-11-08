import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../store.dart';
import '../theme.dart';
import '../units.dart';
import '../widgets/common.dart';
import 'exercise_editor.dart';
import 'progress_screen.dart';
import 'workout_screen.dart';

/// Un día de la rutina: organizar sus ejercicios e iniciar el entrenamiento.
class DayScreen extends StatelessWidget {
  const DayScreen({super.key, required this.routineId, required this.dayId});

  final String routineId;
  final String dayId;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final routine = store.routineById(routineId);
    final day = routine?.days.where((d) => d.id == dayId).firstOrNull;
    if (routine == null || day == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Día no encontrado')));
    }

    Future<void> addExercise() async {
      final ex = await showExerciseEditor(context);
      if (ex != null) {
        day.exercises.add(ex);
        store.changed();
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(day.name),
            Text(routine.name, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Renombrar día',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              final name = await askText(context, title: 'Renombrar día', initial: day.name);
              if (name != null && name.isNotEmpty) {
                day.name = name;
                store.changed();
              }
            },
          ),
          HeaderAddButton(tooltip: 'Agregar ejercicio', onPressed: addExercise),
        ],
      ),
      body: day.exercises.isEmpty
          ? EmptyState(
              icon: Icons.playlist_add,
              title: 'Sin ejercicios',
              message: 'Agrega los ejercicios de ${day.name} con sus series, '
                  'repeticiones y descanso.',
              action: FilledButton.icon(
                onPressed: addExercise,
                icon: const Icon(Icons.add),
                label: const Text('Agregar ejercicio'),
              ),
            )
          : MaxWidth(
              child: ReorderableListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                buildDefaultDragHandles: false,
                itemCount: day.exercises.length,
                onReorderItem: (o, n) => store.reorderExercise(day, o, n),
                proxyDecorator: (child, _, _) => Material(color: Colors.transparent, child: child),
                itemBuilder: (context, i) {
                  final ex = day.exercises[i];
                  return Padding(
                    key: ValueKey(ex.id),
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
                        leading: ReorderableDragStartListener(
                          index: i,
                          child: const Padding(
                            padding: EdgeInsets.all(12),
                            child: Icon(Icons.drag_indicator, color: AppColors.muted),
                          ),
                        ),
                        title: Text(ex.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(
                          '${ex.sets} series × ${ex.repsLabel} reps · '
                          'descanso ${fmtRest(ex.restSeconds)}'
                          '${ex.notes.isEmpty ? '' : '\n${ex.notes}'}',
                          style: const TextStyle(color: AppColors.muted),
                        ),
                        onTap: () async {
                          final edited = await showExerciseEditor(context, initial: ex);
                          if (edited != null) {
                            day.exercises[day.exercises.indexOf(ex)] = edited;
                            store.changed();
                          }
                        },
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Progreso',
                              icon: const Icon(Icons.show_chart),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ProgressScreen(exerciseName: ex.name),
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Eliminar',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () async {
                                final ok = await confirm(
                                  context,
                                  title: 'Eliminar ejercicio',
                                  message: '¿Quitar "${ex.name}" de ${day.name}? '
                                      'Su historial se conserva.',
                                  ok: 'Eliminar',
                                );
                                if (ok) {
                                  day.exercises.remove(ex);
                                  store.changed();
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: day.exercises.isEmpty
          ? null
          : FloatingActionButton.extended(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.background,
              onPressed: () => startWorkoutFlow(context, routine, day),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Iniciar entrenamiento',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
    );
  }
}
