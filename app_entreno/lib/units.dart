import 'package:intl/intl.dart';

import 'models.dart';

const kgPerLb = 0.45359237;

double kgToUnit(double kg, WeightUnit u) => u == WeightUnit.kg ? kg : kg / kgPerLb;

double unitToKg(double value, WeightUnit u) =>
    u == WeightUnit.kg ? value : value * kgPerLb;

/// Número con hasta 2 decimales y sin ceros sobrantes: 60 → "60", 61.25 → "61.25".
String fmtNum(double v) {
  final r = (v * 100).round() / 100;
  if (r == r.roundToDouble()) return r.toInt().toString();
  var s = r.toStringAsFixed(2);
  if (s.endsWith('0')) s = s.substring(0, s.length - 1);
  return s;
}

String fmtWeight(double kg, WeightUnit u) => '${fmtNum(kgToUnit(kg, u))} ${u.label}';

/// Valor de peso para mostrar en un campo de texto (sin unidad).
String weightField(double? kg, WeightUnit u) => kg == null ? '' : fmtNum(kgToUnit(kg, u));

String fmtVolume(double kg, WeightUnit u) =>
    '${NumberFormat.decimalPattern('es').format(kgToUnit(kg, u).round())} ${u.label}';

/// Duración legible: "45 min", "1 h 05 min", "menos de 1 min".
String fmtDuration(int seconds) {
  final m = (seconds / 60).round();
  if (m < 1) return 'menos de 1 min';
  if (m < 60) return '$m min';
  return '${m ~/ 60} h ${(m % 60).toString().padLeft(2, '0')} min';
}

/// Cronómetro: "12:05" o "1:02:05".
String fmtClock(int seconds) {
  final h = seconds ~/ 3600, m = (seconds % 3600) ~/ 60, s = seconds % 60;
  final mm = m.toString().padLeft(2, '0'), ss = s.toString().padLeft(2, '0');
  return h > 0 ? '$h:$mm:$ss' : '$m:$ss';
}

String fmtRest(int seconds) =>
    '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

double? parseNum(String s) {
  final t = s.trim().replaceAll(',', '.');
  if (t.isEmpty) return null;
  return double.tryParse(t);
}

String fmtDate(DateTime d) => DateFormat("EEE d 'de' MMM yyyy", 'es').format(d);

String fmtShortDate(DateTime d) => DateFormat('d MMM', 'es').format(d);
