import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// Punto de la gráfica de progreso de un ejercicio (valores en kg).
class ProgressPoint {
  ProgressPoint(this.date, this.log);

  final DateTime date;
  final ExerciseLog log;

  double get e1rmKg => log.bestE1rmKg;
  double get maxWeightKg => log.maxWeightKg;
  double get volumeKg => log.volumeKg;
}

String _norm(String name) => name.trim().toLowerCase();

/// Estado de la app y persistencia local (funciona en móvil, escritorio y web).
class AppStore extends ChangeNotifier {
  AppStore(this._prefs);

  static const _storageKey = 'registro_entreno_v1';

  final SharedPreferences _prefs;
  Timer? _saveTimer;

  WeightUnit unit = WeightUnit.kg;

  /// Paleta de colores elegida (ver `appPalettes` en theme.dart).
  String paletteId = 'rojo';

  /// Si la alarma del descanso reproduce sonido.
  bool alarmSound = true;

  final List<Routine> routines = [];

  /// Sesiones terminadas, ordenadas por fecha (más antigua primero).
  final List<WorkoutSession> sessions = [];

  /// Entrenamiento en curso (se guarda para poder retomarlo).
  WorkoutSession? active;

  void load() {
    final raw = _prefs.getString(_storageKey);
    if (raw == null) return;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      unit = WeightUnit.values.firstWhere(
        (u) => u.name == j['unit'],
        orElse: () => WeightUnit.kg,
      );
      paletteId = j['palette'] as String? ?? 'rojo';
      alarmSound = j['alarmSound'] as bool? ?? true;
      routines
        ..clear()
        ..addAll((j['routines'] as List? ?? [])
            .map((r) => Routine.fromJson(r as Map<String, dynamic>)));
      sessions
        ..clear()
        ..addAll((j['sessions'] as List? ?? [])
            .map((s) => WorkoutSession.fromJson(s as Map<String, dynamic>)));
      _sortSessions();
      final a = j['active'];
      active = a == null ? null : WorkoutSession.fromJson(a as Map<String, dynamic>);
    } catch (e) {
      debugPrint('No se pudieron leer los datos guardados: $e');
    }
  }

  Map<String, dynamic> toJson() => {
        'unit': unit.name,
        'palette': paletteId,
        'alarmSound': alarmSound,
        'routines': routines.map((r) => r.toJson()).toList(),
        'sessions': sessions.map((s) => s.toJson()).toList(),
        'active': active?.toJson(),
      };

  /// Notifica a la interfaz y guarda de inmediato.
  void changed() {
    notifyListeners();
    _saveTimer?.cancel();
    _persist();
  }

  /// Guarda con un pequeño retraso (para cambios mientras se escribe).
  void saveSoon() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), _persist);
  }

  Future<void> _persist() => _prefs.setString(_storageKey, jsonEncode(toJson()));

  void _sortSessions() => sessions.sort((a, b) => a.date.compareTo(b.date));

  // ---------- Ajustes ----------

  void setUnit(WeightUnit u) {
    unit = u;
    changed();
  }

  void setPalette(String id) {
    paletteId = id;
    changed();
  }

  void setAlarmSound(bool on) {
    alarmSound = on;
    changed();
  }

  // ---------- Rutinas ----------

  Routine? routineById(String id) {
    for (final r in routines) {
      if (r.id == id) return r;
    }
    return null;
  }

  void addRoutine(Routine r) {
    routines.add(r);
    changed();
  }

  void deleteRoutine(Routine r) {
    routines.remove(r);
    if (active?.routineId == r.id) active = null;
    changed();
  }

  /// [newIndex] ya viene ajustado (posición final tras quitar el elemento).
  void reorderExercise(RoutineDay day, int oldIndex, int newIndex) {
    final ex = day.exercises.removeAt(oldIndex);
    day.exercises.insert(newIndex, ex);
    changed();
  }

  /// Cambia el descanso de un ejercicio en la rutina (y en la sesión activa).
  void setRest(String exerciseId, int seconds) {
    for (final r in routines) {
      for (final d in r.days) {
        for (final e in d.exercises) {
          if (e.id == exerciseId) e.restSeconds = seconds;
        }
      }
    }
    for (final e in active?.exercises ?? const <ExerciseLog>[]) {
      if (e.exerciseId == exerciseId) e.restSeconds = seconds;
    }
    changed();
  }

  /// Nombres de ejercicios ya usados, para sugerirlos.
  List<String> knownExerciseNames() {
    final seen = <String, String>{};
    for (final n in [
      ...routines.expand((r) => r.days).expand((d) => d.exercises).map((e) => e.name),
      ...commonExercises,
    ]) {
      seen.putIfAbsent(_norm(n), () => n);
    }
    return seen.values.toList();
  }

  // ---------- Entrenamientos ----------

  WorkoutSession? lastSessionForDay(String dayId) {
    for (final s in sessions.reversed) {
      if (s.dayId == dayId) return s;
    }
    return null;
  }

  /// Series de la última vez que se hizo este ejercicio (por nombre).
  List<SetLog> previousSetsFor(String exerciseName) {
    final key = _norm(exerciseName);
    for (final s in sessions.reversed) {
      for (final e in s.exercises) {
        if (_norm(e.name) == key && e.doneSets.isNotEmpty) {
          return e.doneSets.toList();
        }
      }
    }
    return const [];
  }

  /// Crea la sesión del día con las series ya programadas en la rutina.
  WorkoutSession startSession(Routine routine, RoutineDay day, {DateTime? date}) {
    final session = WorkoutSession(
      routineId: routine.id,
      routineName: routine.name,
      dayId: day.id,
      dayName: day.name,
      date: date ?? DateTime.now(),
      startedAt: DateTime.now(),
      exercises: [
        for (final e in day.exercises)
          ExerciseLog(
            exerciseId: e.id,
            name: e.name,
            repsMin: e.repsMin,
            repsMax: e.repsMax,
            restSeconds: e.restSeconds,
            sets: List.generate(e.sets, (_) => SetLog()),
          ),
      ],
    );
    active = session;
    changed();
    return session;
  }

  void setActiveDate(DateTime date) {
    final a = active;
    if (a == null) return;
    a.date = DateTime(date.year, date.month, date.day, a.date.hour, a.date.minute);
    changed();
  }

  /// Guarda la sesión activa en el historial (solo series completadas).
  /// Devuelve `false` si no había ninguna serie completada.
  bool finishActive() {
    final a = active;
    if (a == null) return false;
    final start = a.startedAt;
    if (start != null) {
      a.durationSeconds = DateTime.now().difference(start).inSeconds;
    }
    for (final e in a.exercises) {
      e.sets.removeWhere((s) => !(s.done && s.hasData));
    }
    a.exercises.removeWhere((e) => e.sets.isEmpty);
    active = null;
    final saved = a.exercises.isNotEmpty;
    if (saved) {
      sessions.add(a);
      _sortSessions();
    }
    changed();
    return saved;
  }

  void discardActive() {
    active = null;
    changed();
  }

  void deleteSession(WorkoutSession s) {
    sessions.remove(s);
    changed();
  }

  /// Corrige la duración de una sesión guardada (p. ej. si se olvidó finalizarla).
  void setSessionDuration(WorkoutSession s, int seconds) {
    s.durationSeconds = seconds;
    changed();
  }

  // ---------- Duración ----------

  /// Sesiones con duración registrada (opcionalmente solo de un día de rutina).
  Iterable<WorkoutSession> _timed({String? dayId}) => sessions.where(
        (s) => s.durationSeconds != null && (dayId == null || s.dayId == dayId),
      );

  /// Duración promedio en segundos, o null si no hay sesiones con duración.
  int? averageDurationSeconds({String? dayId}) {
    final list = _timed(dayId: dayId).toList();
    if (list.isEmpty) return null;
    final total = list.fold<int>(0, (t, s) => t + s.durationSeconds!);
    return (total / list.length).round();
  }

  int timedSessionCount({String? dayId}) => _timed(dayId: dayId).length;

  // ---------- Progreso ----------

  List<ProgressPoint> progressFor(String exerciseName) {
    final key = _norm(exerciseName);
    return [
      for (final s in sessions)
        for (final e in s.exercises)
          if (_norm(e.name) == key && e.doneSets.isNotEmpty) ProgressPoint(s.date, e),
    ];
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }
}
