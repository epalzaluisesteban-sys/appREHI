import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../units.dart';
import '../warmup.dart';
import '../widgets/common.dart';

const restPresets = [60, 90, 120, 150, 180, 240];

/// Abre el editor de un ejercicio (nuevo si [initial] es null).
Future<PlannedExercise?> showExerciseEditor(
  BuildContext context, {
  PlannedExercise? initial,
}) =>
    showModalBottomSheet<PlannedExercise>(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (_) => _ExerciseEditor(initial: initial),
    );

class _ExerciseEditor extends StatefulWidget {
  const _ExerciseEditor({this.initial});

  final PlannedExercise? initial;

  @override
  State<_ExerciseEditor> createState() => _ExerciseEditorState();
}

class _ExerciseEditorState extends State<_ExerciseEditor> {
  late final PlannedExercise _ex = widget.initial?.copy() ?? PlannedExercise(name: '');
  late final TextEditingController _notes = TextEditingController(text: _ex.notes);
  TextEditingController? _nameCtrl;
  String? _error;

  void _save() {
    final name = _nameCtrl?.text.trim() ?? '';
    if (name.isEmpty) {
      setState(() => _error = 'Escribe el nombre del ejercicio');
      return;
    }
    _ex
      ..name = name
      ..notes = _notes.text.trim();
    Navigator.pop(context, _ex);
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final names = context.read<AppStore>().knownExerciseNames();
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.initial == null ? 'Nuevo ejercicio' : 'Editar ejercicio',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            Autocomplete<String>(
              initialValue: TextEditingValue(text: _ex.name),
              optionsBuilder: (v) {
                final q = v.text.trim().toLowerCase();
                if (q.isEmpty) return const Iterable<String>.empty();
                return names.where((n) => n.toLowerCase().contains(q)).take(8);
              },
              fieldViewBuilder: (context, ctrl, focus, onSubmit) {
                _nameCtrl = ctrl;
                return TextField(
                  controller: ctrl,
                  focusNode: focus,
                  autofocus: widget.initial == null,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Ejercicio',
                    hintText: 'p. ej. Press banca',
                    errorText: _error,
                  ),
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                );
              },
            ),
            const SectionTitle('Series programadas'),
            NumberStepper(
              label: 'Series',
              value: _ex.sets,
              max: 12,
              onChanged: (v) => setState(() => _ex.sets = v),
            ),
            const SizedBox(height: 8),
            NumberStepper(
              label: 'Reps mínimas',
              value: _ex.repsMin,
              max: 50,
              onChanged: (v) => setState(() {
                _ex.repsMin = v;
                if (_ex.repsMax < v) _ex.repsMax = v;
              }),
            ),
            const SizedBox(height: 8),
            NumberStepper(
              label: 'Reps máximas',
              value: _ex.repsMax,
              max: 50,
              onChanged: (v) => setState(() {
                _ex.repsMax = v;
                if (_ex.repsMin > v) _ex.repsMin = v;
              }),
            ),
            const SectionTitle('Descanso entre series'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in restPresets)
                  ChoiceChip(
                    label: Text(fmtRest(s)),
                    selected: _ex.restSeconds == s,
                    onSelected: (_) => setState(() => _ex.restSeconds = s),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            NumberStepper(
              label: 'Personalizado',
              value: _ex.restSeconds,
              min: 15,
              max: 600,
              step: 15,
              format: fmtRest,
              onChanged: (v) => setState(() => _ex.restSeconds = v),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Sugerido: 2–3 min en compuestos (sentadilla, press, remo) '
                'y 1–2 min en aislamientos.',
                style: TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ),
            const SectionTitle('Series de aproximación (opcional)'),
            _WarmupEditor(
              percents: _ex.warmupPercents,
              onChanged: (list) => setState(() => _ex.warmupPercents = list),
            ),
            const SectionTitle('Notas (opcional)'),
            TextField(
              controller: _notes,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Técnica, agarre, tempo…'),
            ),
            const SizedBox(height: 20),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              onPressed: _save,
              child: const Text('Guardar ejercicio', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Activa las series de aproximación y configura cuántas son y su porcentaje.
class _WarmupEditor extends StatelessWidget {
  const _WarmupEditor({required this.percents, required this.onChanged});

  final List<int> percents;
  final ValueChanged<List<int>> onChanged;

  @override
  Widget build(BuildContext context) {
    final on = percents.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Calcular series de aproximación'),
          subtitle: const Text(
            'Durante el entrenamiento verás el peso de cada una, '
            'calculado con el peso más alto de tus series de trabajo.',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          value: on,
          onChanged: (v) => onChanged(v ? [...defaultWarmupPercents] : []),
        ),
        if (on) ...[
          const SizedBox(height: 4),
          NumberStepper(
            label: 'Series de aproximación',
            value: percents.length,
            max: maxWarmupSets,
            onChanged: (n) => onChanged(n > percents.length
                ? [...percents, nextWarmupPercent(percents)]
                : percents.sublist(0, n)),
          ),
          for (var i = 0; i < percents.length; i++) ...[
            const SizedBox(height: 8),
            NumberStepper(
              label: 'Aproximación ${i + 1}',
              value: percents[i],
              min: 5,
              max: 100,
              step: 5,
              format: (v) => '$v %',
              onChanged: (v) => onChanged([...percents]..[i] = v),
            ),
          ],
        ],
      ],
    );
  }
}
