import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/rehi_logo.dart';
import '../widgets/rest_timer.dart' show AlarmSound;

/// Muestra el logo con los colores de una paleta, para elegirla.
class _PaletteOption extends StatelessWidget {
  const _PaletteOption({required this.palette, required this.selected, required this.onTap});

  final AppPalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        label: 'Color ${palette.name}',
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            width: 92,
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
            decoration: BoxDecoration(
              color: selected ? const Color(0x33FFFFFF) : AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? Colors.white : Colors.transparent,
                width: 2,
              ),
            ),
            child: Column(
              children: [
                RehiLogo(size: 52, palette: palette),
                const SizedBox(height: 6),
                Text(
                  palette.name,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: MaxWidth(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SectionTitle('Color de la app'),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final p in appPalettes)
                  _PaletteOption(
                    palette: p,
                    selected: p.id == store.paletteId,
                    onTap: () => store.setPalette(p.id),
                  ),
              ],
            ),
            const SectionTitle('Alarma del descanso'),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Sonido de alarma'),
                    subtitle: const Text('Suena al terminar el descanso',
                        style: TextStyle(color: AppColors.muted)),
                    value: store.alarmSound,
                    onChanged: store.setAlarmSound,
                  ),
                  ListTile(
                    leading: const Icon(Icons.volume_up_outlined),
                    title: const Text('Probar sonido'),
                    onTap: AlarmSound.play,
                  ),
                ],
              ),
            ),
            const SectionTitle('Unidad de peso'),
            SegmentedButton<WeightUnit>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: WeightUnit.kg, label: Text('Kilogramos (kg)')),
                ButtonSegment(value: WeightUnit.lb, label: Text('Libras (lb)')),
              ],
              selected: {store.unit},
              onSelectionChanged: (s) => store.setUnit(s.first),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 10, 4, 0),
              child: Text(
                'Puedes cambiarla cuando quieras: todo tu historial y tus gráficas '
                'se convierten automáticamente (1 kg = 2.205 lb).',
                style: TextStyle(color: AppColors.muted),
              ),
            ),
            const SectionTitle('Guía rápida de hipertrofia'),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Tip('Frecuencia', 'Entrena cada músculo unas 2 veces por semana (p. ej. torso-pierna de 4 días).'),
                    _Tip('Volumen', 'Unas 10–20 series efectivas por músculo a la semana.'),
                    _Tip('Esfuerzo', 'Termina las series a 0–3 repeticiones del fallo (RIR 0–3).'),
                    _Tip('Descanso', '2–3 min en compuestos, 1–2 min en aislamientos.'),
                    _Tip('Progresión', 'Llega al tope del rango de reps y entonces sube el peso.'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  const _Tip(this.title, this.text);

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text.rich(
          TextSpan(children: [
            TextSpan(text: '$title: ', style: const TextStyle(fontWeight: FontWeight.w700)),
            TextSpan(text: text, style: const TextStyle(color: AppColors.muted)),
          ]),
        ),
      );
}
