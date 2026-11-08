import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'routine_screen.dart';

/// Crear una rutina: nombre y los días que el usuario quiera agregar.
/// No se generan días automáticamente.
class NewRoutineScreen extends StatefulWidget {
  const NewRoutineScreen({super.key});

  @override
  State<NewRoutineScreen> createState() => _NewRoutineScreenState();
}

class _NewRoutineScreenState extends State<NewRoutineScreen> {
  final _name = TextEditingController();
  final List<TextEditingController> _days = [];
  String? _error;

  void _addDay() => setState(() => _days.add(TextEditingController()));

  void _removeDay(int i) => setState(() => _days.removeAt(i).dispose());

  void _create() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Escribe un nombre para la rutina');
      return;
    }
    final days = [
      for (var i = 0; i < _days.length; i++)
        RoutineDay(name: _days[i].text.trim().isEmpty ? 'Día ${i + 1}' : _days[i].text.trim()),
    ];
    final routine = Routine(
      name: name,
      split: 'personalizada',
      daysPerWeek: days.length,
      days: days,
    );
    context.read<AppStore>().addRoutine(routine);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => RoutineScreen(routineId: routine.id)),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    for (final c in _days) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Nueva rutina')),
        body: MaxWidth(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              const SectionTitle('Nombre'),
              TextField(
                controller: _name,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'p. ej. Torso-Pierna',
                  errorText: _error,
                ),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
              ),
              const SectionTitle('Días de entrenamiento'),
              if (_days.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 12),
                  child: Text(
                    'Agrega los días de esta rutina (p. ej. Torso y Pierna). '
                    'También puedes hacerlo después.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                ),
              for (var i = 0; i < _days.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextField(
                    controller: _days[i],
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Nombre del día ${i + 1}',
                      prefixIcon: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text('${i + 1}',
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      prefixIconConstraints: const BoxConstraints(minWidth: 40),
                      suffixIcon: IconButton(
                        tooltip: 'Quitar día',
                        icon: const Icon(Icons.close),
                        onPressed: () => _removeDay(i),
                      ),
                    ),
                  ),
                ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: AppColors.subtle),
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: _addDay,
                icon: const Icon(Icons.add),
                label: const Text('Agregar día'),
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: MaxWidth(
            shrinkHeight: true,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                onPressed: _create,
                icon: const Icon(Icons.check),
                label: const Text('Crear rutina', style: TextStyle(fontSize: 16)),
              ),
            ),
          ),
        ),
      );
}
