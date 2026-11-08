import 'package:flutter_test/flutter_test.dart';
import 'package:registro_entreno/models.dart';
import 'package:registro_entreno/store.dart';
import 'package:registro_entreno/units.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Unidades', () {
    test('conversión kg ↔ lb es reversible', () {
      final kg = unitToKg(135, WeightUnit.lb);
      expect(kg, closeTo(61.235, 0.001));
      expect(fmtNum(kgToUnit(kg, WeightUnit.lb)), '135');
    });

    test('formato de números', () {
      expect(fmtNum(60), '60');
      expect(fmtNum(61.25), '61.25');
      expect(fmtNum(62.5), '62.5');
      expect(fmtRest(90), '1:30');
      expect(parseNum('62,5'), 62.5);
    });
  });

  group('Plantillas de división', () {
    test('torso-pierna de 4 días tiene frecuencia 2', () {
      final t = splitByKey('torso_pierna');
      expect(t.dayNames(4), ['Torso A', 'Pierna A', 'Torso B', 'Pierna B']);
      expect(t.frequencyFor(4), 2);
    });

    test('personalizada genera días numerados', () {
      final t = splitByKey('personalizada');
      expect(t.dayNames(3), ['Día 1', 'Día 2', 'Día 3']);
      expect(t.frequencyFor(3), isNull);
    });
  });

  test('1RM estimado (Epley)', () {
    expect(SetLog(weightKg: 100, reps: 1).e1rmKg, 100);
    expect(SetLog(weightKg: 100, reps: 10).e1rmKg, closeTo(133.33, 0.01));
  });

  group('AppStore', () {
    late AppStore store;
    late Routine routine;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      store = AppStore(await SharedPreferences.getInstance());
      routine = Routine(
        name: 'Torso-Pierna',
        split: 'torso_pierna',
        daysPerWeek: 2,
        days: [
          RoutineDay(name: 'Torso', exercises: [
            PlannedExercise(name: 'Press banca', sets: 3, restSeconds: 150),
          ]),
          RoutineDay(name: 'Pierna'),
        ],
      );
      store.addRoutine(routine);
    });

    test('al iniciar se programan las series de la rutina', () {
      final s = store.startSession(routine, routine.days.first);
      expect(s.exercises.single.sets.length, 3);
      expect(s.exercises.single.restSeconds, 150);
    });

    test('finalizar guarda solo series completadas y alimenta el progreso', () {
      final s = store.startSession(routine, routine.days.first, date: DateTime(2026, 11, 2));
      final sets = s.exercises.single.sets;
      sets[0]
        ..weightKg = 60
        ..reps = 10
        ..done = true;
      sets[1]
        ..weightKg = 62.5
        ..reps = 8
        ..done = true;
      sets[2].weightKg = 65; // sin completar

      expect(store.finishActive(), isTrue);
      expect(store.active, isNull);
      expect(store.sessions.single.exercises.single.sets.length, 2);

      final pts = store.progressFor('press banca'); // no distingue mayúsculas
      expect(pts.single.maxWeightKg, 62.5);
      expect(pts.single.volumeKg, 60 * 10 + 62.5 * 8);
      expect(store.previousSetsFor('Press banca').length, 2);
    });

    test('se guarda la duración y se calcula el promedio por día', () {
      final torso = routine.days.first;
      for (final minutes in [50, 70]) {
        final s = store.startSession(routine, torso);
        s.startedAt = DateTime.now().subtract(Duration(minutes: minutes));
        s.exercises.single.sets.first
          ..weightKg = 60
          ..reps = 8
          ..done = true;
        store.finishActive();
      }
      expect(store.sessions.first.durationSeconds, closeTo(50 * 60, 2));
      expect(store.averageDurationSeconds(dayId: torso.id), closeTo(60 * 60, 2));
      expect(store.averageDurationSeconds(dayId: routine.days.last.id), isNull);
      expect(fmtDuration(3600), '1 h 00 min');
      expect(fmtDuration(45 * 60), '45 min');
      expect(fmtClock(3725), '1:02:05');

      store.setSessionDuration(store.sessions.first, 40 * 60);
      expect(store.averageDurationSeconds(), closeTo(55 * 60, 2));
    });

    test('sesión sin series completadas no se guarda', () {
      store.startSession(routine, routine.days.first);
      expect(store.finishActive(), isFalse);
      expect(store.sessions, isEmpty);
    });

    test('los datos persisten y se vuelven a cargar', () async {
      store.setUnit(WeightUnit.lb);
      store.setPalette('salvia');
      store.setAlarmSound(false);
      store.setRest(routine.days.first.exercises.first.id, 180);
      final again = AppStore(await SharedPreferences.getInstance())..load();
      expect(again.unit, WeightUnit.lb);
      expect(again.paletteId, 'salvia');
      expect(again.alarmSound, isFalse);
      expect(again.routines.single.days.first.exercises.first.restSeconds, 180);
    });
  });
}
