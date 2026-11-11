import 'dart:math';

final _rng = Random();

/// Genera un identificador único corto.
String newId() =>
    '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}'
    '${_rng.nextInt(1 << 20).toRadixString(36)}';

/// Unidad en la que el usuario ve e ingresa el peso.
/// Internamente todo se guarda en kilogramos.
enum WeightUnit {
  kg('kg'),
  lb('lb');

  const WeightUnit(this.label);
  final String label;
}

/// Ejercicio planificado dentro de un día de la rutina
/// (series, rango de repeticiones y descanso programados).
class PlannedExercise {
  PlannedExercise({
    String? id,
    required this.name,
    this.sets = 3,
    this.repsMin = 8,
    this.repsMax = 12,
    this.restSeconds = 120,
    this.notes = '',
    List<int>? warmupPercents,
    this.perSide = false,
  })  : id = id ?? newId(),
        warmupPercents = warmupPercents ?? [];

  final String id;
  String name;
  int sets;
  int repsMin;
  int repsMax;
  int restSeconds;
  String notes;

  /// Porcentaje del peso de trabajo de cada serie de aproximación.
  /// Vacía = el ejercicio no usa series de aproximación.
  List<int> warmupPercents;

  bool get hasWarmup => warmupPercents.isNotEmpty;

  /// Peso por lado (X×2): en máquinas donde se cargan discos a cada lado,
  /// durante el entrenamiento se escribe el peso de un lado y en el
  /// registro se guarda el total (el doble).
  bool perSide;

  /// Cuántas veces se multiplica el peso escrito para obtener el total.
  int get loadFactor => perSide ? 2 : 1;

  String get repsLabel => repsMin == repsMax ? '$repsMin' : '$repsMin–$repsMax';

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'sets': sets,
        'repsMin': repsMin,
        'repsMax': repsMax,
        'restSeconds': restSeconds,
        'notes': notes,
        if (hasWarmup) 'warmup': warmupPercents,
        if (perSide) 'perSide': true,
      };

  factory PlannedExercise.fromJson(Map<String, dynamic> j) => PlannedExercise(
        id: j['id'] as String,
        name: j['name'] as String,
        sets: (j['sets'] as num?)?.toInt() ?? 3,
        repsMin: (j['repsMin'] as num?)?.toInt() ?? 8,
        repsMax: (j['repsMax'] as num?)?.toInt() ?? 12,
        restSeconds: (j['restSeconds'] as num?)?.toInt() ?? 120,
        notes: j['notes'] as String? ?? '',
        // Las rutinas y copias anteriores a la 1.2.0 no traen este campo.
        warmupPercents: [
          for (final p in j['warmup'] as List? ?? const [])
            if (p is num && p > 0) p.round(),
        ],
        // Las rutinas y copias anteriores a la 1.3.0 no traen este campo.
        perSide: j['perSide'] == true,
      );

  PlannedExercise copy() => PlannedExercise.fromJson(toJson());
}

/// Un día de entrenamiento de la rutina (p. ej. "Torso A").
class RoutineDay {
  RoutineDay({String? id, required this.name, List<PlannedExercise>? exercises})
      : id = id ?? newId(),
        exercises = exercises ?? [];

  final String id;
  String name;
  final List<PlannedExercise> exercises;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'exercises': exercises.map((e) => e.toJson()).toList(),
      };

  factory RoutineDay.fromJson(Map<String, dynamic> j) => RoutineDay(
        id: j['id'] as String,
        name: j['name'] as String,
        exercises: (j['exercises'] as List? ?? [])
            .map((e) => PlannedExercise.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Rutina completa: una división (split) con sus días por semana.
class Routine {
  Routine({
    String? id,
    required this.name,
    required this.split,
    required this.daysPerWeek,
    List<RoutineDay>? days,
    DateTime? createdAt,
  })  : id = id ?? newId(),
        days = days ?? [],
        createdAt = createdAt ?? DateTime.now();

  final String id;
  String name;
  String split;
  int daysPerWeek;
  final List<RoutineDay> days;
  final DateTime createdAt;

  SplitTemplate get template => splitByKey(split);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'split': split,
        'daysPerWeek': daysPerWeek,
        'days': days.map((d) => d.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory Routine.fromJson(Map<String, dynamic> j) => Routine(
        id: j['id'] as String,
        name: j['name'] as String,
        split: j['split'] as String? ?? 'personalizada',
        daysPerWeek: (j['daysPerWeek'] as num?)?.toInt() ?? 0,
        days: (j['days'] as List? ?? [])
            .map((d) => RoutineDay.fromJson(d as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? ''),
      );
}

/// Registro de una serie: peso (en kg), repeticiones y RIR opcional.
class SetLog {
  SetLog({this.weightKg, this.reps, this.rir, this.done = false});

  double? weightKg;
  int? reps;

  /// Repeticiones en reserva (0 = fallo).
  int? rir;
  bool done;

  bool get hasData => weightKg != null && reps != null && reps! > 0;

  double get volumeKg => (weightKg ?? 0) * (reps ?? 0);

  /// 1RM estimado (fórmula de Epley).
  double get e1rmKg {
    if (!hasData) return 0;
    if (reps == 1) return weightKg!;
    return weightKg! * (1 + reps! / 30);
  }

  Map<String, dynamic> toJson() => {
        'w': weightKg,
        'r': reps,
        'rir': rir,
        'done': done,
      };

  factory SetLog.fromJson(Map<String, dynamic> j) => SetLog(
        weightKg: (j['w'] as num?)?.toDouble(),
        reps: (j['r'] as num?)?.toInt(),
        rir: (j['rir'] as num?)?.toInt(),
        done: j['done'] as bool? ?? false,
      );
}

/// Registro de un ejercicio dentro de una sesión.
class ExerciseLog {
  ExerciseLog({
    required this.exerciseId,
    required this.name,
    required this.repsMin,
    required this.repsMax,
    required this.restSeconds,
    List<SetLog>? sets,
  }) : sets = sets ?? [];

  final String exerciseId;
  final String name;
  final int repsMin;
  final int repsMax;
  int restSeconds;
  final List<SetLog> sets;

  Iterable<SetLog> get doneSets => sets.where((s) => s.done && s.hasData);

  double get bestE1rmKg =>
      doneSets.fold(0.0, (m, s) => s.e1rmKg > m ? s.e1rmKg : m);

  double get maxWeightKg =>
      doneSets.fold(0.0, (m, s) => (s.weightKg ?? 0) > m ? s.weightKg! : m);

  double get volumeKg => doneSets.fold(0.0, (t, s) => t + s.volumeKg);

  Map<String, dynamic> toJson() => {
        'exerciseId': exerciseId,
        'name': name,
        'repsMin': repsMin,
        'repsMax': repsMax,
        'restSeconds': restSeconds,
        'sets': sets.map((s) => s.toJson()).toList(),
      };

  factory ExerciseLog.fromJson(Map<String, dynamic> j) => ExerciseLog(
        exerciseId: j['exerciseId'] as String,
        name: j['name'] as String,
        repsMin: (j['repsMin'] as num?)?.toInt() ?? 0,
        repsMax: (j['repsMax'] as num?)?.toInt() ?? 0,
        restSeconds: (j['restSeconds'] as num?)?.toInt() ?? 120,
        sets: (j['sets'] as List? ?? [])
            .map((s) => SetLog.fromJson(s as Map<String, dynamic>))
            .toList(),
      );
}

/// Una sesión de entrenamiento: qué día de qué rutina se hizo y en qué fecha.
class WorkoutSession {
  WorkoutSession({
    String? id,
    required this.routineId,
    required this.routineName,
    required this.dayId,
    required this.dayName,
    required this.date,
    List<ExerciseLog>? exercises,
    this.startedAt,
    this.durationSeconds,
  })  : id = id ?? newId(),
        exercises = exercises ?? [];

  final String id;
  final String routineId;
  final String routineName;
  final String dayId;
  final String dayName;
  DateTime date;
  final List<ExerciseLog> exercises;

  /// Hora real en que se inició el entrenamiento (para el cronómetro).
  DateTime? startedAt;

  /// Cuánto duró la sesión, en segundos (null en sesiones antiguas).
  int? durationSeconds;

  int get doneSetCount =>
      exercises.fold(0, (t, e) => t + e.doneSets.length);

  double get volumeKg => exercises.fold(0.0, (t, e) => t + e.volumeKg);

  Map<String, dynamic> toJson() => {
        'id': id,
        'routineId': routineId,
        'routineName': routineName,
        'dayId': dayId,
        'dayName': dayName,
        'date': date.toIso8601String(),
        'exercises': exercises.map((e) => e.toJson()).toList(),
        'startedAt': startedAt?.toIso8601String(),
        'durationSeconds': durationSeconds,
      };

  factory WorkoutSession.fromJson(Map<String, dynamic> j) => WorkoutSession(
        id: j['id'] as String,
        routineId: j['routineId'] as String,
        routineName: j['routineName'] as String? ?? '',
        dayId: j['dayId'] as String,
        dayName: j['dayName'] as String? ?? '',
        date: DateTime.parse(j['date'] as String),
        exercises: (j['exercises'] as List? ?? [])
            .map((e) => ExerciseLog.fromJson(e as Map<String, dynamic>))
            .toList(),
        startedAt: DateTime.tryParse(j['startedAt'] as String? ?? ''),
        durationSeconds: (j['durationSeconds'] as num?)?.toInt(),
      );
}

/// Plantilla de división del entrenamiento (split).
class SplitTemplate {
  const SplitTemplate({
    required this.key,
    required this.name,
    required this.description,
    required this.daysByFrequency,
    this.groupsPerCycle,
  });

  final String key;
  final String name;
  final String description;

  /// Días por semana permitidos → nombres de cada día.
  final Map<int, List<String>> daysByFrequency;

  /// Cuántos días distintos componen un ciclo (para calcular la frecuencia
  /// por grupo muscular). `null` en rutinas personalizadas.
  final int? groupsPerCycle;

  List<int> get allowedDays => daysByFrequency.isEmpty
      ? List.generate(7, (i) => i + 1)
      : (daysByFrequency.keys.toList()..sort());

  List<String> dayNames(int days) =>
      daysByFrequency[days] ?? List.generate(days, (i) => 'Día ${i + 1}');

  /// Veces por semana que se entrena cada grupo muscular.
  int? frequencyFor(int daysPerWeek) {
    final g = groupsPerCycle;
    if (g == null || daysPerWeek == 0) return null;
    return (daysPerWeek / g).floor().clamp(1, 7);
  }
}

const splitTemplates = <SplitTemplate>[
  SplitTemplate(
    key: 'torso_pierna',
    name: 'Torso-Pierna',
    description: 'Tren superior un día, tren inferior al siguiente.',
    groupsPerCycle: 2,
    daysByFrequency: {
      2: ['Torso', 'Pierna'],
      4: ['Torso A', 'Pierna A', 'Torso B', 'Pierna B'],
    },
  ),
  SplitTemplate(
    key: 'ppl',
    name: 'Empuje-Tirón-Pierna',
    description: 'Pecho/hombro/tríceps, espalda/bíceps y pierna.',
    groupsPerCycle: 3,
    daysByFrequency: {
      3: ['Empuje', 'Tirón', 'Pierna'],
      6: ['Empuje A', 'Tirón A', 'Pierna A', 'Empuje B', 'Tirón B', 'Pierna B'],
    },
  ),
  SplitTemplate(
    key: 'full_body',
    name: 'Cuerpo completo',
    description: 'Todo el cuerpo en cada sesión.',
    groupsPerCycle: 1,
    daysByFrequency: {
      2: ['Cuerpo completo A', 'Cuerpo completo B'],
      3: ['Cuerpo completo A', 'Cuerpo completo B', 'Cuerpo completo C'],
    },
  ),
  SplitTemplate(
    key: 'personalizada',
    name: 'Personalizada',
    description: 'Tú decides cuántos días y cómo se llaman.',
    daysByFrequency: {},
  ),
];

SplitTemplate splitByKey(String key) => splitTemplates.firstWhere(
      (s) => s.key == key,
      orElse: () => splitTemplates.last,
    );

/// Sugerencias para el nombre de los ejercicios.
const commonExercises = <String>[
  'Press banca',
  'Press banca inclinado con mancuernas',
  'Aperturas en polea',
  'Fondos en paralelas',
  'Press militar',
  'Elevaciones laterales',
  'Face pull',
  'Jalón al pecho',
  'Dominadas',
  'Remo con barra',
  'Remo en polea baja',
  'Remo con mancuerna',
  'Curl de bíceps con barra',
  'Curl martillo',
  'Curl inclinado con mancuernas',
  'Extensión de tríceps en polea',
  'Press francés',
  'Sentadilla',
  'Sentadilla búlgara',
  'Prensa de piernas',
  'Peso muerto rumano',
  'Hip thrust',
  'Curl femoral',
  'Extensión de cuádriceps',
  'Zancadas',
  'Elevación de talones',
];
