import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'day_screen.dart';

/// Administrar una rutina: renombrar, eliminar y gestionar sus días.
class RoutineScreen extends StatelessWidget {
  const RoutineScreen({super.key, required this.routineId});

  final String routineId;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final routine = store.routineById(routineId);
    if (routine == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Rutina no encontrada')));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(routine.name),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'rename') {
                final name = await askText(context, title: 'Renombrar rutina', initial: routine.name);
                if (name != null && name.isNotEmpty) {
                  routine.name = name;
                  store.changed();
                }
              } else if (v == 'delete') {
                final ok = await confirm(
                  context,
                  title: 'Eliminar rutina',
                  message: '¿Eliminar "${routine.name}"? El historial de entrenamientos se conserva.',
                  ok: 'Eliminar',
                );
                if (ok && context.mounted) {
                  store.deleteRoutine(routine);
                  Navigator.pop(context);
                }
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'rename', child: Text('Renombrar')),
              PopupMenuItem(value: 'delete', child: Text('Eliminar rutina')),
            ],
          ),
        ],
      ),
      body: MaxWidth(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SectionTitle('Días'),
            if (routine.days.isEmpty)
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 12),
                child: Text(
                  'Esta rutina aún no tiene días. Agrega el primero (p. ej. Torso).',
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
            for (var i = 0; i < routine.days.length; i++) ...[
              _DayCard(routine: routine, day: routine.days[i], index: i),
              const SizedBox(height: 10),
            ],
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: AppColors.subtle),
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: () async {
                final name = await askText(
                  context,
                  title: 'Nuevo día',
                  label: 'Nombre del día (p. ej. Torso)',
                );
                if (name != null && name.isNotEmpty) {
                  routine.days.add(RoutineDay(name: name));
                  routine.daysPerWeek = routine.days.length;
                  store.changed();
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Agregar día'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({required this.routine, required this.day, required this.index});

  final Routine routine;
  final RoutineDay day;
  final int index;

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final names = day.exercises.map((e) => e.name).join(', ');
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
        leading: CircleAvatar(
          backgroundColor: const Color(0x33FFFFFF),
          foregroundColor: Colors.white,
          child: Text('${index + 1}'),
        ),
        title: Text(day.name, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          names.isEmpty ? 'Toca para agregar ejercicios' : names,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppColors.muted),
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DayScreen(routineId: routine.id, dayId: day.id)),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (v) async {
            if (v == 'rename') {
              final name = await askText(context, title: 'Renombrar día', initial: day.name);
              if (name != null && name.isNotEmpty) {
                day.name = name;
                store.changed();
              }
            } else if (v == 'delete') {
              final ok = await confirm(
                context,
                title: 'Eliminar día',
                message: '¿Eliminar "${day.name}" y sus ejercicios?',
                ok: 'Eliminar',
              );
              if (ok) {
                routine.days.remove(day);
                routine.daysPerWeek = routine.days.length;
                store.changed();
              }
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'rename', child: Text('Renombrar')),
            PopupMenuItem(value: 'delete', child: Text('Eliminar')),
          ],
        ),
      ),
    );
  }
}
