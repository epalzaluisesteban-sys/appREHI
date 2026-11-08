import 'models.dart';
import 'units.dart';

/// Máximo de series de aproximación por ejercicio.
const maxWarmupSets = 5;

/// Porcentajes sugeridos al activar las series de aproximación.
const defaultWarmupPercents = [40, 60, 80];

/// Porcentaje para una serie nueva que se agrega después de [previous].
int nextWarmupPercent(List<int> previous) =>
    previous.isEmpty ? 50 : (previous.last + 10).clamp(5, 95);

/// Peso de trabajo con el que se calculan las aproximaciones (en kg):
/// el peso más alto escrito hoy en las series del ejercicio o, si aún no
/// hay ninguno, el más alto de la última vez que se hizo.
double? warmupBaseKg(List<SetLog> today, List<SetLog> previous) {
  double? best(Iterable<double?> ws) {
    double? m;
    for (final w in ws) {
      if (w != null && w > 0 && (m == null || w > m)) m = w;
    }
    return m;
  }

  return best(today.map((s) => s.weightKg)) ?? best(previous.map((s) => s.weightKg));
}

/// Peso de cada serie de aproximación, en la unidad del usuario y
/// redondeado a números enteros (son pesos aproximados).
List<int> warmupWeights(double baseKg, List<int> percents, WeightUnit unit) {
  final base = kgToUnit(baseKg, unit);
  return [for (final p in percents) (base * p / 100).round()];
}
