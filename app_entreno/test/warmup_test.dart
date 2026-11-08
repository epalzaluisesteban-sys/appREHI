import 'package:flutter_test/flutter_test.dart';
import 'package:registro_entreno/models.dart';
import 'package:registro_entreno/store.dart';
import 'package:registro_entreno/warmup.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Copia de seguridad tal como la genera la versión 1.1.0 (sin aproximaciones).
const _backupV110 = '''
{
 "app": "REHI",
 "format": 1,
 "exportedAt": "2026-11-08T10:00:00.000",
 "data": {
  "unit": "kg",
  "palette": "azul",
  "alarmSound": true,
  "routines": [
   {
    "id": "r1",
    "name": "Torso-Pierna",
    "split": "torso_pierna",
    "daysPerWeek": 4,
    "days": [
     {
      "id": "d1",
      "name": "Torso A",
      "exercises": [
       {"id": "e1", "name": "Press banca", "sets": 3, "repsMin": 6, "repsMax": 8,
        "restSeconds": 180, "notes": "agarre medio"},
       {"id": "e2", "name": "Remo con barra", "sets": 3, "repsMin": 8, "repsMax": 12,
        "restSeconds": 120, "notes": ""}
      ]
     }
    ],
    "createdAt": "2026-11-01T09:00:00.000"
   }
  ],
  "sessions": [
   {
    "id": "s1", "routineId": "r1", "routineName": "Torso-Pierna",
    "dayId": "d1", "dayName": "Torso A", "date": "2026-11-05T18:00:00.000",
    "exercises": [
     {"exerciseId": "e1", "name": "Press banca", "repsMin": 6, "repsMax": 8,
      "restSeconds": 180,
      "sets": [{"w": 90, "r": 8, "rir": 2, "done": true}, {"w": 90, "r": 7, "rir": 1, "done": true}]}
    ],
    "startedAt": "2026-11-05T18:00:00.000",
    "durationSeconds": 3600
   }
  ],
  "active": null,
  "lastBackupAt": "2026-11-08T10:00:00.000"
 }
}
''';

Future<AppStore> _newStore() async {
  SharedPreferences.setMockInitialValues({});
  return AppStore(await SharedPreferences.getInstance());
}

void main() {
  group('Cálculo de aproximaciones', () {
    test('porcentajes del peso de trabajo, redondeados', () {
      expect(warmupWeights(90, [20, 40, 50], WeightUnit.kg), [18, 36, 45]);
      expect(warmupWeights(100, defaultWarmupPercents, WeightUnit.kg), [40, 60, 80]);
      // 100 kg ≈ 220.5 lb
      expect(warmupWeights(100, [50], WeightUnit.lb), [110]);
    });

    test('usa el peso más alto escrito hoy o, si no hay, el de la vez anterior', () {
      final previous = [SetLog(weightKg: 80, reps: 8), SetLog(weightKg: 85, reps: 6)];
      expect(warmupBaseKg([SetLog(), SetLog()], previous), 85);
      expect(warmupBaseKg([SetLog(weightKg: 90), SetLog(weightKg: 92.5)], previous), 92.5);
      expect(warmupBaseKg([SetLog()], const []), isNull);
    });

    test('series nuevas suben de a 10 % sin pasar de 95 %', () {
      expect(nextWarmupPercent(const []), 50);
      expect(nextWarmupPercent(const [40, 60, 80]), 90);
      expect(nextWarmupPercent(const [90]), 95);
    });
  });

  group('Copias de seguridad', () {
    test('una copia de la 1.1.0 se restaura igual que antes', () async {
      final store = await _newStore();
      store.restoreBackup(AppStore.readBackup(_backupV110));

      final r = store.routines.single;
      expect(r.days.single.exercises.map((e) => e.name), ['Press banca', 'Remo con barra']);
      expect(r.days.single.exercises.first.notes, 'agarre medio');
      expect(r.days.single.exercises.every((e) => !e.hasWarmup), isTrue);
      expect(store.sessions.single.exercises.single.maxWeightKg, 90);
      expect(store.sessions.single.durationSeconds, 3600);
      expect(store.paletteId, 'azul');

      // Sin aproximaciones configuradas, los datos se guardan exactamente igual.
      final ex = (AppStore.readBackup(_backupV110).data['routines'] as List).first['days'][0]
          ['exercises'][0] as Map<String, dynamic>;
      expect(r.days.single.exercises.first.toJson(), ex);
    });

    test('las aproximaciones configuradas viajan en la copia', () async {
      final store = await _newStore();
      store.restoreBackup(AppStore.readBackup(_backupV110));
      store.routines.single.days.single.exercises.first.warmupPercents = [20, 40, 50];
      final raw = store.exportBackup();

      final other = await _newStore();
      other.restoreBackup(AppStore.readBackup(raw));
      final exs = other.routines.single.days.single.exercises;
      expect(exs.first.warmupPercents, [20, 40, 50]);
      expect(exs.last.hasWarmup, isFalse);
    });
  });
}
